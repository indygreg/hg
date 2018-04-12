# wireprotoframing.py - unified framing protocol for wire protocol
#
# Copyright 2018 Gregory Szorc <gregory.szorc@gmail.com>
#
# This software may be used and distributed according to the terms of the
# GNU General Public License version 2 or any later version.

# This file contains functionality to support the unified frame-based wire
# protocol. For details about the protocol, see
# `hg help internals.wireprotocol`.

from __future__ import absolute_import

import collections
import struct

from .i18n import _
from .thirdparty import (
    attr,
    cbor,
)
from . import (
    encoding,
    error,
    util,
)
from .utils import (
    stringutil,
)

FRAME_HEADER_SIZE = 8
DEFAULT_MAX_FRAME_SIZE = 32768

STREAM_FLAG_BEGIN_STREAM = 0x01
STREAM_FLAG_END_STREAM = 0x02
STREAM_FLAG_ENCODING_APPLIED = 0x04

STREAM_FLAGS = {
    b'stream-begin': STREAM_FLAG_BEGIN_STREAM,
    b'stream-end': STREAM_FLAG_END_STREAM,
    b'encoded': STREAM_FLAG_ENCODING_APPLIED,
}

FRAME_TYPE_COMMAND_REQUEST = 0x01
FRAME_TYPE_COMMAND_DATA = 0x03
FRAME_TYPE_BYTES_RESPONSE = 0x04
FRAME_TYPE_ERROR_RESPONSE = 0x05
FRAME_TYPE_TEXT_OUTPUT = 0x06
FRAME_TYPE_PROGRESS = 0x07
FRAME_TYPE_STREAM_SETTINGS = 0x08

FRAME_TYPES = {
    b'command-request': FRAME_TYPE_COMMAND_REQUEST,
    b'command-data': FRAME_TYPE_COMMAND_DATA,
    b'bytes-response': FRAME_TYPE_BYTES_RESPONSE,
    b'error-response': FRAME_TYPE_ERROR_RESPONSE,
    b'text-output': FRAME_TYPE_TEXT_OUTPUT,
    b'progress': FRAME_TYPE_PROGRESS,
    b'stream-settings': FRAME_TYPE_STREAM_SETTINGS,
}

FLAG_COMMAND_REQUEST_NEW = 0x01
FLAG_COMMAND_REQUEST_CONTINUATION = 0x02
FLAG_COMMAND_REQUEST_MORE_FRAMES = 0x04
FLAG_COMMAND_REQUEST_EXPECT_DATA = 0x08

FLAGS_COMMAND_REQUEST = {
    b'new': FLAG_COMMAND_REQUEST_NEW,
    b'continuation': FLAG_COMMAND_REQUEST_CONTINUATION,
    b'more': FLAG_COMMAND_REQUEST_MORE_FRAMES,
    b'have-data': FLAG_COMMAND_REQUEST_EXPECT_DATA,
}

FLAG_COMMAND_DATA_CONTINUATION = 0x01
FLAG_COMMAND_DATA_EOS = 0x02

FLAGS_COMMAND_DATA = {
    b'continuation': FLAG_COMMAND_DATA_CONTINUATION,
    b'eos': FLAG_COMMAND_DATA_EOS,
}

FLAG_BYTES_RESPONSE_CONTINUATION = 0x01
FLAG_BYTES_RESPONSE_EOS = 0x02
FLAG_BYTES_RESPONSE_CBOR = 0x04

FLAGS_BYTES_RESPONSE = {
    b'continuation': FLAG_BYTES_RESPONSE_CONTINUATION,
    b'eos': FLAG_BYTES_RESPONSE_EOS,
    b'cbor': FLAG_BYTES_RESPONSE_CBOR,
}

FLAG_ERROR_RESPONSE_PROTOCOL = 0x01
FLAG_ERROR_RESPONSE_APPLICATION = 0x02

FLAGS_ERROR_RESPONSE = {
    b'protocol': FLAG_ERROR_RESPONSE_PROTOCOL,
    b'application': FLAG_ERROR_RESPONSE_APPLICATION,
}

# Maps frame types to their available flags.
FRAME_TYPE_FLAGS = {
    FRAME_TYPE_COMMAND_REQUEST: FLAGS_COMMAND_REQUEST,
    FRAME_TYPE_COMMAND_DATA: FLAGS_COMMAND_DATA,
    FRAME_TYPE_BYTES_RESPONSE: FLAGS_BYTES_RESPONSE,
    FRAME_TYPE_ERROR_RESPONSE: FLAGS_ERROR_RESPONSE,
    FRAME_TYPE_TEXT_OUTPUT: {},
    FRAME_TYPE_PROGRESS: {},
    FRAME_TYPE_STREAM_SETTINGS: {},
}

ARGUMENT_RECORD_HEADER = struct.Struct(r'<HH')

def humanflags(mapping, value):
    """Convert a numeric flags value to a human value, using a mapping table."""
    namemap = {v: k for k, v in mapping.iteritems()}
    flags = []
    val = 1
    while value >= val:
        if value & val:
            flags.append(namemap.get(val, '<unknown 0x%02x>' % val))
        val <<= 1

    return b'|'.join(flags)

@attr.s(slots=True)
class frameheader(object):
    """Represents the data in a frame header."""

    length = attr.ib()
    requestid = attr.ib()
    streamid = attr.ib()
    streamflags = attr.ib()
    typeid = attr.ib()
    flags = attr.ib()

@attr.s(slots=True, repr=False)
class frame(object):
    """Represents a parsed frame."""

    requestid = attr.ib()
    streamid = attr.ib()
    streamflags = attr.ib()
    typeid = attr.ib()
    flags = attr.ib()
    payload = attr.ib()

    @encoding.strmethod
    def __repr__(self):
        typename = '<unknown 0x%02x>' % self.typeid
        for name, value in FRAME_TYPES.iteritems():
            if value == self.typeid:
                typename = name
                break

        return ('frame(size=%d; request=%d; stream=%d; streamflags=%s; '
                'type=%s; flags=%s)' % (
            len(self.payload), self.requestid, self.streamid,
            humanflags(STREAM_FLAGS, self.streamflags), typename,
            humanflags(FRAME_TYPE_FLAGS.get(self.typeid, {}), self.flags)))

def makeframe(requestid, streamid, streamflags, typeid, flags, payload):
    """Assemble a frame into a byte array."""
    # TODO assert size of payload.
    frame = bytearray(FRAME_HEADER_SIZE + len(payload))

    # 24 bits length
    # 16 bits request id
    # 8 bits stream id
    # 8 bits stream flags
    # 4 bits type
    # 4 bits flags

    l = struct.pack(r'<I', len(payload))
    frame[0:3] = l[0:3]
    struct.pack_into(r'<HBB', frame, 3, requestid, streamid, streamflags)
    frame[7] = (typeid << 4) | flags
    frame[8:] = payload

    return frame

def makeframefromhumanstring(s):
    """Create a frame from a human readable string

    Strings have the form:

        <request-id> <stream-id> <stream-flags> <type> <flags> <payload>

    This can be used by user-facing applications and tests for creating
    frames easily without having to type out a bunch of constants.

    Request ID and stream IDs are integers.

    Stream flags, frame type, and flags can be specified by integer or
    named constant.

    Flags can be delimited by `|` to bitwise OR them together.

    If the payload begins with ``cbor:``, the following string will be
    evaluated as Python literal and the resulting object will be fed into
    a CBOR encoder. Otherwise, the payload is interpreted as a Python
    byte string literal.
    """
    fields = s.split(b' ', 5)
    requestid, streamid, streamflags, frametype, frameflags, payload = fields

    requestid = int(requestid)
    streamid = int(streamid)

    finalstreamflags = 0
    for flag in streamflags.split(b'|'):
        if flag in STREAM_FLAGS:
            finalstreamflags |= STREAM_FLAGS[flag]
        else:
            finalstreamflags |= int(flag)

    if frametype in FRAME_TYPES:
        frametype = FRAME_TYPES[frametype]
    else:
        frametype = int(frametype)

    finalflags = 0
    validflags = FRAME_TYPE_FLAGS[frametype]
    for flag in frameflags.split(b'|'):
        if flag in validflags:
            finalflags |= validflags[flag]
        else:
            finalflags |= int(flag)

    if payload.startswith(b'cbor:'):
        payload = cbor.dumps(stringutil.evalpythonliteral(payload[5:]),
                             canonical=True)

    else:
        payload = stringutil.unescapestr(payload)

    return makeframe(requestid=requestid, streamid=streamid,
                     streamflags=finalstreamflags, typeid=frametype,
                     flags=finalflags, payload=payload)

def parseheader(data):
    """Parse a unified framing protocol frame header from a buffer.

    The header is expected to be in the buffer at offset 0 and the
    buffer is expected to be large enough to hold a full header.
    """
    # 24 bits payload length (little endian)
    # 16 bits request ID
    # 8 bits stream ID
    # 8 bits stream flags
    # 4 bits frame type
    # 4 bits frame flags
    # ... payload
    framelength = data[0] + 256 * data[1] + 16384 * data[2]
    requestid, streamid, streamflags = struct.unpack_from(r'<HBB', data, 3)
    typeflags = data[7]

    frametype = (typeflags & 0xf0) >> 4
    frameflags = typeflags & 0x0f

    return frameheader(framelength, requestid, streamid, streamflags,
                       frametype, frameflags)

def readframe(fh):
    """Read a unified framing protocol frame from a file object.

    Returns a 3-tuple of (type, flags, payload) for the decoded frame or
    None if no frame is available. May raise if a malformed frame is
    seen.
    """
    header = bytearray(FRAME_HEADER_SIZE)

    readcount = fh.readinto(header)

    if readcount == 0:
        return None

    if readcount != FRAME_HEADER_SIZE:
        raise error.Abort(_('received incomplete frame: got %d bytes: %s') %
                          (readcount, header))

    h = parseheader(header)

    payload = fh.read(h.length)
    if len(payload) != h.length:
        raise error.Abort(_('frame length error: expected %d; got %d') %
                          (h.length, len(payload)))

    return frame(h.requestid, h.streamid, h.streamflags, h.typeid, h.flags,
                 payload)

def createcommandframes(stream, requestid, cmd, args, datafh=None,
                        maxframesize=DEFAULT_MAX_FRAME_SIZE):
    """Create frames necessary to transmit a request to run a command.

    This is a generator of bytearrays. Each item represents a frame
    ready to be sent over the wire to a peer.
    """
    data = {b'name': cmd}
    if args:
        data[b'args'] = args

    data = cbor.dumps(data, canonical=True)

    offset = 0

    while True:
        flags = 0

        # Must set new or continuation flag.
        if not offset:
            flags |= FLAG_COMMAND_REQUEST_NEW
        else:
            flags |= FLAG_COMMAND_REQUEST_CONTINUATION

        # Data frames is set on all frames.
        if datafh:
            flags |= FLAG_COMMAND_REQUEST_EXPECT_DATA

        payload = data[offset:offset + maxframesize]
        offset += len(payload)

        if len(payload) == maxframesize and offset < len(data):
            flags |= FLAG_COMMAND_REQUEST_MORE_FRAMES

        yield stream.makeframe(requestid=requestid,
                               typeid=FRAME_TYPE_COMMAND_REQUEST,
                               flags=flags,
                               payload=payload)

        if not (flags & FLAG_COMMAND_REQUEST_MORE_FRAMES):
            break

    if datafh:
        while True:
            data = datafh.read(DEFAULT_MAX_FRAME_SIZE)

            done = False
            if len(data) == DEFAULT_MAX_FRAME_SIZE:
                flags = FLAG_COMMAND_DATA_CONTINUATION
            else:
                flags = FLAG_COMMAND_DATA_EOS
                assert datafh.read(1) == b''
                done = True

            yield stream.makeframe(requestid=requestid,
                                   typeid=FRAME_TYPE_COMMAND_DATA,
                                   flags=flags,
                                   payload=data)

            if done:
                break

def createbytesresponseframesfrombytes(stream, requestid, data, iscbor=False,
                                       maxframesize=DEFAULT_MAX_FRAME_SIZE):
    """Create a raw frame to send a bytes response from static bytes input.

    Returns a generator of bytearrays.
    """

    # Simple case of a single frame.
    if len(data) <= maxframesize:
        flags = FLAG_BYTES_RESPONSE_EOS
        if iscbor:
            flags |= FLAG_BYTES_RESPONSE_CBOR

        yield stream.makeframe(requestid=requestid,
                               typeid=FRAME_TYPE_BYTES_RESPONSE,
                               flags=flags,
                               payload=data)
        return

    offset = 0
    while True:
        chunk = data[offset:offset + maxframesize]
        offset += len(chunk)
        done = offset == len(data)

        if done:
            flags = FLAG_BYTES_RESPONSE_EOS
        else:
            flags = FLAG_BYTES_RESPONSE_CONTINUATION

        if iscbor:
            flags |= FLAG_BYTES_RESPONSE_CBOR

        yield stream.makeframe(requestid=requestid,
                               typeid=FRAME_TYPE_BYTES_RESPONSE,
                               flags=flags,
                               payload=chunk)

        if done:
            break

def createerrorframe(stream, requestid, msg, protocol=False, application=False):
    # TODO properly handle frame size limits.
    assert len(msg) <= DEFAULT_MAX_FRAME_SIZE

    flags = 0
    if protocol:
        flags |= FLAG_ERROR_RESPONSE_PROTOCOL
    if application:
        flags |= FLAG_ERROR_RESPONSE_APPLICATION

    yield stream.makeframe(requestid=requestid,
                           typeid=FRAME_TYPE_ERROR_RESPONSE,
                           flags=flags,
                           payload=msg)

def createtextoutputframe(stream, requestid, atoms,
                          maxframesize=DEFAULT_MAX_FRAME_SIZE):
    """Create a text output frame to render text to people.

    ``atoms`` is a 3-tuple of (formatting string, args, labels).

    The formatting string contains ``%s`` tokens to be replaced by the
    corresponding indexed entry in ``args``. ``labels`` is an iterable of
    formatters to be applied at rendering time. In terms of the ``ui``
    class, each atom corresponds to a ``ui.write()``.
    """
    atomdicts = []

    for (formatting, args, labels) in atoms:
        # TODO look for localstr, other types here?

        if not isinstance(formatting, bytes):
            raise ValueError('must use bytes formatting strings')
        for arg in args:
            if not isinstance(arg, bytes):
                raise ValueError('must use bytes for arguments')
        for label in labels:
            if not isinstance(label, bytes):
                raise ValueError('must use bytes for labels')

        # Formatting string must be ASCII.
        formatting = formatting.decode(r'ascii', r'replace').encode(r'ascii')

        # Arguments must be UTF-8.
        args = [a.decode(r'utf-8', r'replace').encode(r'utf-8') for a in args]

        # Labels must be ASCII.
        labels = [l.decode(r'ascii', r'strict').encode(r'ascii')
                  for l in labels]

        atom = {b'msg': formatting}
        if args:
            atom[b'args'] = args
        if labels:
            atom[b'labels'] = labels

        atomdicts.append(atom)

    payload = cbor.dumps(atomdicts, canonical=True)

    if len(payload) > maxframesize:
        raise ValueError('cannot encode data in a single frame')

    yield stream.makeframe(requestid=requestid,
                           typeid=FRAME_TYPE_TEXT_OUTPUT,
                           flags=0,
                           payload=payload)

class stream(object):
    """Represents a logical unidirectional series of frames."""

    def __init__(self, streamid, active=False):
        self.streamid = streamid
        self._active = active

    def makeframe(self, requestid, typeid, flags, payload):
        """Create a frame to be sent out over this stream.

        Only returns the frame instance. Does not actually send it.
        """
        streamflags = 0
        if not self._active:
            streamflags |= STREAM_FLAG_BEGIN_STREAM
            self._active = True

        return makeframe(requestid, self.streamid, streamflags, typeid, flags,
                         payload)

def ensureserverstream(stream):
    if stream.streamid % 2:
        raise error.ProgrammingError('server should only write to even '
                                     'numbered streams; %d is not even' %
                                     stream.streamid)

class serverreactor(object):
    """Holds state of a server handling frame-based protocol requests.

    This class is the "brain" of the unified frame-based protocol server
    component. While the protocol is stateless from the perspective of
    requests/commands, something needs to track which frames have been
    received, what frames to expect, etc. This class is that thing.

    Instances are modeled as a state machine of sorts. Instances are also
    reactionary to external events. The point of this class is to encapsulate
    the state of the connection and the exchange of frames, not to perform
    work. Instead, callers tell this class when something occurs, like a
    frame arriving. If that activity is worthy of a follow-up action (say
    *run a command*), the return value of that handler will say so.

    I/O and CPU intensive operations are purposefully delegated outside of
    this class.

    Consumers are expected to tell instances when events occur. They do so by
    calling the various ``on*`` methods. These methods return a 2-tuple
    describing any follow-up action(s) to take. The first element is the
    name of an action to perform. The second is a data structure (usually
    a dict) specific to that action that contains more information. e.g.
    if the server wants to send frames back to the client, the data structure
    will contain a reference to those frames.

    Valid actions that consumers can be instructed to take are:

    sendframes
       Indicates that frames should be sent to the client. The ``framegen``
       key contains a generator of frames that should be sent. The server
       assumes that all frames are sent to the client.

    error
       Indicates that an error occurred. Consumer should probably abort.

    runcommand
       Indicates that the consumer should run a wire protocol command. Details
       of the command to run are given in the data structure.

    wantframe
       Indicates that nothing of interest happened and the server is waiting on
       more frames from the client before anything interesting can be done.

    noop
       Indicates no additional action is required.

    Known Issues
    ------------

    There are no limits to the number of partially received commands or their
    size. A malicious client could stream command request data and exhaust the
    server's memory.

    Partially received commands are not acted upon when end of input is
    reached. Should the server error if it receives a partial request?
    Should the client send a message to abort a partially transmitted request
    to facilitate graceful shutdown?

    Active requests that haven't been responded to aren't tracked. This means
    that if we receive a command and instruct its dispatch, another command
    with its request ID can come in over the wire and there will be a race
    between who responds to what.
    """

    def __init__(self, deferoutput=False):
        """Construct a new server reactor.

        ``deferoutput`` can be used to indicate that no output frames should be
        instructed to be sent until input has been exhausted. In this mode,
        events that would normally generate output frames (such as a command
        response being ready) will instead defer instructing the consumer to
        send those frames. This is useful for half-duplex transports where the
        sender cannot receive until all data has been transmitted.
        """
        self._deferoutput = deferoutput
        self._state = 'idle'
        self._nextoutgoingstreamid = 2
        self._bufferedframegens = []
        # stream id -> stream instance for all active streams from the client.
        self._incomingstreams = {}
        self._outgoingstreams = {}
        # request id -> dict of commands that are actively being received.
        self._receivingcommands = {}
        # Request IDs that have been received and are actively being processed.
        # Once all output for a request has been sent, it is removed from this
        # set.
        self._activecommands = set()

    def onframerecv(self, frame):
        """Process a frame that has been received off the wire.

        Returns a dict with an ``action`` key that details what action,
        if any, the consumer should take next.
        """
        if not frame.streamid % 2:
            self._state = 'errored'
            return self._makeerrorresult(
                _('received frame with even numbered stream ID: %d') %
                  frame.streamid)

        if frame.streamid not in self._incomingstreams:
            if not frame.streamflags & STREAM_FLAG_BEGIN_STREAM:
                self._state = 'errored'
                return self._makeerrorresult(
                    _('received frame on unknown inactive stream without '
                      'beginning of stream flag set'))

            self._incomingstreams[frame.streamid] = stream(frame.streamid)

        if frame.streamflags & STREAM_FLAG_ENCODING_APPLIED:
            # TODO handle decoding frames
            self._state = 'errored'
            raise error.ProgrammingError('support for decoding stream payloads '
                                         'not yet implemented')

        if frame.streamflags & STREAM_FLAG_END_STREAM:
            del self._incomingstreams[frame.streamid]

        handlers = {
            'idle': self._onframeidle,
            'command-receiving': self._onframecommandreceiving,
            'errored': self._onframeerrored,
        }

        meth = handlers.get(self._state)
        if not meth:
            raise error.ProgrammingError('unhandled state: %s' % self._state)

        return meth(frame)

    def onbytesresponseready(self, stream, requestid, data, iscbor=False):
        """Signal that a bytes response is ready to be sent to the client.

        The raw bytes response is passed as an argument.
        """
        ensureserverstream(stream)

        def sendframes():
            for frame in createbytesresponseframesfrombytes(stream, requestid,
                                                            data,
                                                            iscbor=iscbor):
                yield frame

            self._activecommands.remove(requestid)

        result = sendframes()

        if self._deferoutput:
            self._bufferedframegens.append(result)
            return 'noop', {}
        else:
            return 'sendframes', {
                'framegen': result,
            }

    def oninputeof(self):
        """Signals that end of input has been received.

        No more frames will be received. All pending activity should be
        completed.
        """
        # TODO should we do anything about in-flight commands?

        if not self._deferoutput or not self._bufferedframegens:
            return 'noop', {}

        # If we buffered all our responses, emit those.
        def makegen():
            for gen in self._bufferedframegens:
                for frame in gen:
                    yield frame

        return 'sendframes', {
            'framegen': makegen(),
        }

    def onapplicationerror(self, stream, requestid, msg):
        ensureserverstream(stream)

        return 'sendframes', {
            'framegen': createerrorframe(stream, requestid, msg,
                                         application=True),
        }

    def makeoutputstream(self):
        """Create a stream to be used for sending data to the client."""
        streamid = self._nextoutgoingstreamid
        self._nextoutgoingstreamid += 2

        s = stream(streamid)
        self._outgoingstreams[streamid] = s

        return s

    def _makeerrorresult(self, msg):
        return 'error', {
            'message': msg,
        }

    def _makeruncommandresult(self, requestid):
        entry = self._receivingcommands[requestid]

        if not entry['requestdone']:
            self._state = 'errored'
            raise error.ProgrammingError('should not be called without '
                                         'requestdone set')

        del self._receivingcommands[requestid]

        if self._receivingcommands:
            self._state = 'command-receiving'
        else:
            self._state = 'idle'

        # Decode the payloads as CBOR.
        entry['payload'].seek(0)
        request = cbor.load(entry['payload'])

        if b'name' not in request:
            self._state = 'errored'
            return self._makeerrorresult(
                _('command request missing "name" field'))

        if b'args' not in request:
            request[b'args'] = {}

        assert requestid not in self._activecommands
        self._activecommands.add(requestid)

        return 'runcommand', {
            'requestid': requestid,
            'command': request[b'name'],
            'args': request[b'args'],
            'data': entry['data'].getvalue() if entry['data'] else None,
        }

    def _makewantframeresult(self):
        return 'wantframe', {
            'state': self._state,
        }

    def _validatecommandrequestframe(self, frame):
        new = frame.flags & FLAG_COMMAND_REQUEST_NEW
        continuation = frame.flags & FLAG_COMMAND_REQUEST_CONTINUATION

        if new and continuation:
            self._state = 'errored'
            return self._makeerrorresult(
                _('received command request frame with both new and '
                  'continuation flags set'))

        if not new and not continuation:
            self._state = 'errored'
            return self._makeerrorresult(
                _('received command request frame with neither new nor '
                  'continuation flags set'))

    def _onframeidle(self, frame):
        # The only frame type that should be received in this state is a
        # command request.
        if frame.typeid != FRAME_TYPE_COMMAND_REQUEST:
            self._state = 'errored'
            return self._makeerrorresult(
                _('expected command request frame; got %d') % frame.typeid)

        res = self._validatecommandrequestframe(frame)
        if res:
            return res

        if frame.requestid in self._receivingcommands:
            self._state = 'errored'
            return self._makeerrorresult(
                _('request with ID %d already received') % frame.requestid)

        if frame.requestid in self._activecommands:
            self._state = 'errored'
            return self._makeerrorresult(
                _('request with ID %d is already active') % frame.requestid)

        new = frame.flags & FLAG_COMMAND_REQUEST_NEW
        moreframes = frame.flags & FLAG_COMMAND_REQUEST_MORE_FRAMES
        expectingdata = frame.flags & FLAG_COMMAND_REQUEST_EXPECT_DATA

        if not new:
            self._state = 'errored'
            return self._makeerrorresult(
                _('received command request frame without new flag set'))

        payload = util.bytesio()
        payload.write(frame.payload)

        self._receivingcommands[frame.requestid] = {
            'payload': payload,
            'data': None,
            'requestdone': not moreframes,
            'expectingdata': bool(expectingdata),
        }

        # This is the final frame for this request. Dispatch it.
        if not moreframes and not expectingdata:
            return self._makeruncommandresult(frame.requestid)

        assert moreframes or expectingdata
        self._state = 'command-receiving'
        return self._makewantframeresult()

    def _onframecommandreceiving(self, frame):
        if frame.typeid == FRAME_TYPE_COMMAND_REQUEST:
            # Process new command requests as such.
            if frame.flags & FLAG_COMMAND_REQUEST_NEW:
                return self._onframeidle(frame)

            res = self._validatecommandrequestframe(frame)
            if res:
                return res

        # All other frames should be related to a command that is currently
        # receiving but is not active.
        if frame.requestid in self._activecommands:
            self._state = 'errored'
            return self._makeerrorresult(
                _('received frame for request that is still active: %d') %
                frame.requestid)

        if frame.requestid not in self._receivingcommands:
            self._state = 'errored'
            return self._makeerrorresult(
                _('received frame for request that is not receiving: %d') %
                  frame.requestid)

        entry = self._receivingcommands[frame.requestid]

        if frame.typeid == FRAME_TYPE_COMMAND_REQUEST:
            moreframes = frame.flags & FLAG_COMMAND_REQUEST_MORE_FRAMES
            expectingdata = bool(frame.flags & FLAG_COMMAND_REQUEST_EXPECT_DATA)

            if entry['requestdone']:
                self._state = 'errored'
                return self._makeerrorresult(
                    _('received command request frame when request frames '
                      'were supposedly done'))

            if expectingdata != entry['expectingdata']:
                self._state = 'errored'
                return self._makeerrorresult(
                    _('mismatch between expect data flag and previous frame'))

            entry['payload'].write(frame.payload)

            if not moreframes:
                entry['requestdone'] = True

            if not moreframes and not expectingdata:
                return self._makeruncommandresult(frame.requestid)

            return self._makewantframeresult()

        elif frame.typeid == FRAME_TYPE_COMMAND_DATA:
            if not entry['expectingdata']:
                self._state = 'errored'
                return self._makeerrorresult(_(
                    'received command data frame for request that is not '
                    'expecting data: %d') % frame.requestid)

            if entry['data'] is None:
                entry['data'] = util.bytesio()

            return self._handlecommanddataframe(frame, entry)
        else:
            self._state = 'errored'
            return self._makeerrorresult(_(
                'received unexpected frame type: %d') % frame.typeid)

    def _handlecommanddataframe(self, frame, entry):
        assert frame.typeid == FRAME_TYPE_COMMAND_DATA

        # TODO support streaming data instead of buffering it.
        entry['data'].write(frame.payload)

        if frame.flags & FLAG_COMMAND_DATA_CONTINUATION:
            return self._makewantframeresult()
        elif frame.flags & FLAG_COMMAND_DATA_EOS:
            entry['data'].seek(0)
            return self._makeruncommandresult(frame.requestid)
        else:
            self._state = 'errored'
            return self._makeerrorresult(_('command data frame without '
                                           'flags'))

    def _onframeerrored(self, frame):
        return self._makeerrorresult(_('server already errored'))

class commandrequest(object):
    """Represents a request to run a command."""

    def __init__(self, requestid, name, args, datafh=None):
        self.requestid = requestid
        self.name = name
        self.args = args
        self.datafh = datafh
        self.state = 'pending'

class clientreactor(object):
    """Holds state of a client issuing frame-based protocol requests.

    This is like ``serverreactor`` but for client-side state.

    Each instance is bound to the lifetime of a connection. For persistent
    connection transports using e.g. TCP sockets and speaking the raw
    framing protocol, there will be a single instance for the lifetime of
    the TCP socket. For transports where there are multiple discrete
    interactions (say tunneled within in HTTP request), there will be a
    separate instance for each distinct interaction.
    """
    def __init__(self, hasmultiplesend=False, buffersends=True):
        """Create a new instance.

        ``hasmultiplesend`` indicates whether multiple sends are supported
        by the transport. When True, it is possible to send commands immediately
        instead of buffering until the caller signals an intent to finish a
        send operation.

        ``buffercommands`` indicates whether sends should be buffered until the
        last request has been issued.
        """
        self._hasmultiplesend = hasmultiplesend
        self._buffersends = buffersends

        self._canissuecommands = True
        self._cansend = True

        self._nextrequestid = 1
        # We only support a single outgoing stream for now.
        self._outgoingstream = stream(1)
        self._pendingrequests = collections.deque()
        self._activerequests = {}
        self._incomingstreams = {}

    def callcommand(self, name, args, datafh=None):
        """Request that a command be executed.

        Receives the command name, a dict of arguments to pass to the command,
        and an optional file object containing the raw data for the command.

        Returns a 3-tuple of (request, action, action data).
        """
        if not self._canissuecommands:
            raise error.ProgrammingError('cannot issue new commands')

        requestid = self._nextrequestid
        self._nextrequestid += 2

        request = commandrequest(requestid, name, args, datafh=datafh)

        if self._buffersends:
            self._pendingrequests.append(request)
            return request, 'noop', {}
        else:
            if not self._cansend:
                raise error.ProgrammingError('sends cannot be performed on '
                                             'this instance')

            if not self._hasmultiplesend:
                self._cansend = False
                self._canissuecommands = False

            return request, 'sendframes', {
                'framegen': self._makecommandframes(request),
            }

    def flushcommands(self):
        """Request that all queued commands be sent.

        If any commands are buffered, this will instruct the caller to send
        them over the wire. If no commands are buffered it instructs the client
        to no-op.

        If instances aren't configured for multiple sends, no new command
        requests are allowed after this is called.
        """
        if not self._pendingrequests:
            return 'noop', {}

        if not self._cansend:
            raise error.ProgrammingError('sends cannot be performed on this '
                                         'instance')

        # If the instance only allows sending once, mark that we have fired
        # our one shot.
        if not self._hasmultiplesend:
            self._canissuecommands = False
            self._cansend = False

        def makeframes():
            while self._pendingrequests:
                request = self._pendingrequests.popleft()
                for frame in self._makecommandframes(request):
                    yield frame

        return 'sendframes', {
            'framegen': makeframes(),
        }

    def _makecommandframes(self, request):
        """Emit frames to issue a command request.

        As a side-effect, update request accounting to reflect its changed
        state.
        """
        self._activerequests[request.requestid] = request
        request.state = 'sending'

        res = createcommandframes(self._outgoingstream,
                                  request.requestid,
                                  request.name,
                                  request.args,
                                  request.datafh)

        for frame in res:
            yield frame

        request.state = 'sent'

    def onframerecv(self, frame):
        """Process a frame that has been received off the wire.

        Returns a 2-tuple of (action, meta) describing further action the
        caller needs to take as a result of receiving this frame.
        """
        if frame.streamid % 2:
            return 'error', {
                'message': (
                    _('received frame with odd numbered stream ID: %d') %
                    frame.streamid),
            }

        if frame.streamid not in self._incomingstreams:
            if not frame.streamflags & STREAM_FLAG_BEGIN_STREAM:
                return 'error', {
                    'message': _('received frame on unknown stream '
                                 'without beginning of stream flag set'),
                }

        if frame.streamflags & STREAM_FLAG_ENCODING_APPLIED:
            raise error.ProgrammingError('support for decoding stream '
                                         'payloads not yet implemneted')

        if frame.streamflags & STREAM_FLAG_END_STREAM:
            del self._incomingstreams[frame.streamid]

        if frame.requestid not in self._activerequests:
            return 'error', {
                'message': (_('received frame for inactive request ID: %d') %
                            frame.requestid),
            }

        request = self._activerequests[frame.requestid]
        request.state = 'receiving'

        handlers = {
            FRAME_TYPE_BYTES_RESPONSE: self._onbytesresponseframe,
        }

        meth = handlers.get(frame.typeid)
        if not meth:
            raise error.ProgrammingError('unhandled frame type: %d' %
                                         frame.typeid)

        return meth(request, frame)

    def _onbytesresponseframe(self, request, frame):
        if frame.flags & FLAG_BYTES_RESPONSE_EOS:
            request.state = 'received'
            del self._activerequests[request.requestid]

        return 'responsedata', {
            'request': request,
            'expectmore': frame.flags & FLAG_BYTES_RESPONSE_CONTINUATION,
            'eos': frame.flags & FLAG_BYTES_RESPONSE_EOS,
            'cbor': frame.flags & FLAG_BYTES_RESPONSE_CBOR,
            'data': frame.payload,
        }
