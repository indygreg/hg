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

import struct

from .i18n import _
from .thirdparty import (
    attr,
)
from . import (
    error,
    util,
)

FRAME_HEADER_SIZE = 6
DEFAULT_MAX_FRAME_SIZE = 32768

FRAME_TYPE_COMMAND_NAME = 0x01
FRAME_TYPE_COMMAND_ARGUMENT = 0x02
FRAME_TYPE_COMMAND_DATA = 0x03
FRAME_TYPE_BYTES_RESPONSE = 0x04
FRAME_TYPE_ERROR_RESPONSE = 0x05
FRAME_TYPE_TEXT_OUTPUT = 0x06

FRAME_TYPES = {
    b'command-name': FRAME_TYPE_COMMAND_NAME,
    b'command-argument': FRAME_TYPE_COMMAND_ARGUMENT,
    b'command-data': FRAME_TYPE_COMMAND_DATA,
    b'bytes-response': FRAME_TYPE_BYTES_RESPONSE,
    b'error-response': FRAME_TYPE_ERROR_RESPONSE,
    b'text-output': FRAME_TYPE_TEXT_OUTPUT,
}

FLAG_COMMAND_NAME_EOS = 0x01
FLAG_COMMAND_NAME_HAVE_ARGS = 0x02
FLAG_COMMAND_NAME_HAVE_DATA = 0x04

FLAGS_COMMAND = {
    b'eos': FLAG_COMMAND_NAME_EOS,
    b'have-args': FLAG_COMMAND_NAME_HAVE_ARGS,
    b'have-data': FLAG_COMMAND_NAME_HAVE_DATA,
}

FLAG_COMMAND_ARGUMENT_CONTINUATION = 0x01
FLAG_COMMAND_ARGUMENT_EOA = 0x02

FLAGS_COMMAND_ARGUMENT = {
    b'continuation': FLAG_COMMAND_ARGUMENT_CONTINUATION,
    b'eoa': FLAG_COMMAND_ARGUMENT_EOA,
}

FLAG_COMMAND_DATA_CONTINUATION = 0x01
FLAG_COMMAND_DATA_EOS = 0x02

FLAGS_COMMAND_DATA = {
    b'continuation': FLAG_COMMAND_DATA_CONTINUATION,
    b'eos': FLAG_COMMAND_DATA_EOS,
}

FLAG_BYTES_RESPONSE_CONTINUATION = 0x01
FLAG_BYTES_RESPONSE_EOS = 0x02

FLAGS_BYTES_RESPONSE = {
    b'continuation': FLAG_BYTES_RESPONSE_CONTINUATION,
    b'eos': FLAG_BYTES_RESPONSE_EOS,
}

FLAG_ERROR_RESPONSE_PROTOCOL = 0x01
FLAG_ERROR_RESPONSE_APPLICATION = 0x02

FLAGS_ERROR_RESPONSE = {
    b'protocol': FLAG_ERROR_RESPONSE_PROTOCOL,
    b'application': FLAG_ERROR_RESPONSE_APPLICATION,
}

# Maps frame types to their available flags.
FRAME_TYPE_FLAGS = {
    FRAME_TYPE_COMMAND_NAME: FLAGS_COMMAND,
    FRAME_TYPE_COMMAND_ARGUMENT: FLAGS_COMMAND_ARGUMENT,
    FRAME_TYPE_COMMAND_DATA: FLAGS_COMMAND_DATA,
    FRAME_TYPE_BYTES_RESPONSE: FLAGS_BYTES_RESPONSE,
    FRAME_TYPE_ERROR_RESPONSE: FLAGS_ERROR_RESPONSE,
    FRAME_TYPE_TEXT_OUTPUT: {},
}

ARGUMENT_FRAME_HEADER = struct.Struct(r'<HH')

@attr.s(slots=True)
class frameheader(object):
    """Represents the data in a frame header."""

    length = attr.ib()
    requestid = attr.ib()
    typeid = attr.ib()
    flags = attr.ib()

@attr.s(slots=True)
class frame(object):
    """Represents a parsed frame."""

    requestid = attr.ib()
    typeid = attr.ib()
    flags = attr.ib()
    payload = attr.ib()

def makeframe(requestid, typeid, flags, payload):
    """Assemble a frame into a byte array."""
    # TODO assert size of payload.
    frame = bytearray(FRAME_HEADER_SIZE + len(payload))

    # 24 bits length
    # 16 bits request id
    # 4 bits type
    # 4 bits flags

    l = struct.pack(r'<I', len(payload))
    frame[0:3] = l[0:3]
    struct.pack_into(r'<H', frame, 3, requestid)
    frame[5] = (typeid << 4) | flags
    frame[6:] = payload

    return frame

def makeframefromhumanstring(s):
    """Create a frame from a human readable string

    Strings have the form:

        <request-id> <type> <flags> <payload>

    This can be used by user-facing applications and tests for creating
    frames easily without having to type out a bunch of constants.

    Request ID is an integer.

    Frame type and flags can be specified by integer or named constant.

    Flags can be delimited by `|` to bitwise OR them together.
    """
    requestid, frametype, frameflags, payload = s.split(b' ', 3)

    requestid = int(requestid)

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

    payload = util.unescapestr(payload)

    return makeframe(requestid=requestid, typeid=frametype,
                     flags=finalflags, payload=payload)

def parseheader(data):
    """Parse a unified framing protocol frame header from a buffer.

    The header is expected to be in the buffer at offset 0 and the
    buffer is expected to be large enough to hold a full header.
    """
    # 24 bits payload length (little endian)
    # 4 bits frame type
    # 4 bits frame flags
    # ... payload
    framelength = data[0] + 256 * data[1] + 16384 * data[2]
    requestid = struct.unpack_from(r'<H', data, 3)[0]
    typeflags = data[5]

    frametype = (typeflags & 0xf0) >> 4
    frameflags = typeflags & 0x0f

    return frameheader(framelength, requestid, frametype, frameflags)

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

    return frame(h.requestid, h.typeid, h.flags, payload)

def createcommandframes(requestid, cmd, args, datafh=None):
    """Create frames necessary to transmit a request to run a command.

    This is a generator of bytearrays. Each item represents a frame
    ready to be sent over the wire to a peer.
    """
    flags = 0
    if args:
        flags |= FLAG_COMMAND_NAME_HAVE_ARGS
    if datafh:
        flags |= FLAG_COMMAND_NAME_HAVE_DATA

    if not flags:
        flags |= FLAG_COMMAND_NAME_EOS

    yield makeframe(requestid=requestid, typeid=FRAME_TYPE_COMMAND_NAME,
                    flags=flags, payload=cmd)

    for i, k in enumerate(sorted(args)):
        v = args[k]
        last = i == len(args) - 1

        # TODO handle splitting of argument values across frames.
        payload = bytearray(ARGUMENT_FRAME_HEADER.size + len(k) + len(v))
        offset = 0
        ARGUMENT_FRAME_HEADER.pack_into(payload, offset, len(k), len(v))
        offset += ARGUMENT_FRAME_HEADER.size
        payload[offset:offset + len(k)] = k
        offset += len(k)
        payload[offset:offset + len(v)] = v

        flags = FLAG_COMMAND_ARGUMENT_EOA if last else 0
        yield makeframe(requestid=requestid,
                        typeid=FRAME_TYPE_COMMAND_ARGUMENT,
                        flags=flags,
                        payload=payload)

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

            yield makeframe(requestid=requestid,
                            typeid=FRAME_TYPE_COMMAND_DATA,
                            flags=flags,
                            payload=data)

            if done:
                break

def createbytesresponseframesfrombytes(requestid, data,
                                       maxframesize=DEFAULT_MAX_FRAME_SIZE):
    """Create a raw frame to send a bytes response from static bytes input.

    Returns a generator of bytearrays.
    """

    # Simple case of a single frame.
    if len(data) <= maxframesize:
        yield makeframe(requestid=requestid,
                        typeid=FRAME_TYPE_BYTES_RESPONSE,
                        flags=FLAG_BYTES_RESPONSE_EOS,
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

        yield makeframe(requestid=requestid,
                        typeid=FRAME_TYPE_BYTES_RESPONSE,
                        flags=flags,
                        payload=chunk)

        if done:
            break

def createerrorframe(requestid, msg, protocol=False, application=False):
    # TODO properly handle frame size limits.
    assert len(msg) <= DEFAULT_MAX_FRAME_SIZE

    flags = 0
    if protocol:
        flags |= FLAG_ERROR_RESPONSE_PROTOCOL
    if application:
        flags |= FLAG_ERROR_RESPONSE_APPLICATION

    yield makeframe(requestid=requestid,
                    typeid=FRAME_TYPE_ERROR_RESPONSE,
                    flags=flags,
                    payload=msg)

def createtextoutputframe(requestid, atoms):
    """Create a text output frame to render text to people.

    ``atoms`` is a 3-tuple of (formatting string, args, labels).

    The formatting string contains ``%s`` tokens to be replaced by the
    corresponding indexed entry in ``args``. ``labels`` is an iterable of
    formatters to be applied at rendering time. In terms of the ``ui``
    class, each atom corresponds to a ``ui.write()``.
    """
    bytesleft = DEFAULT_MAX_FRAME_SIZE
    atomchunks = []

    for (formatting, args, labels) in atoms:
        if len(args) > 255:
            raise ValueError('cannot use more than 255 formatting arguments')
        if len(labels) > 255:
            raise ValueError('cannot use more than 255 labels')

        # TODO look for localstr, other types here?

        if not isinstance(formatting, bytes):
            raise ValueError('must use bytes formatting strings')
        for arg in args:
            if not isinstance(arg, bytes):
                raise ValueError('must use bytes for arguments')
        for label in labels:
            if not isinstance(label, bytes):
                raise ValueError('must use bytes for labels')

        # Formatting string must be UTF-8.
        formatting = formatting.decode(r'utf-8', r'replace').encode(r'utf-8')

        # Arguments must be UTF-8.
        args = [a.decode(r'utf-8', r'replace').encode(r'utf-8') for a in args]

        # Labels must be ASCII.
        labels = [l.decode(r'ascii', r'strict').encode(r'ascii')
                  for l in labels]

        if len(formatting) > 65535:
            raise ValueError('formatting string cannot be longer than 64k')

        if any(len(a) > 65535 for a in args):
            raise ValueError('argument string cannot be longer than 64k')

        if any(len(l) > 255 for l in labels):
            raise ValueError('label string cannot be longer than 255 bytes')

        chunks = [
            struct.pack(r'<H', len(formatting)),
            struct.pack(r'<BB', len(labels), len(args)),
            struct.pack(r'<' + r'B' * len(labels), *map(len, labels)),
            struct.pack(r'<' + r'H' * len(args), *map(len, args)),
        ]
        chunks.append(formatting)
        chunks.extend(labels)
        chunks.extend(args)

        atom = b''.join(chunks)
        atomchunks.append(atom)
        bytesleft -= len(atom)

    if bytesleft < 0:
        raise ValueError('cannot encode data in a single frame')

    yield makeframe(requestid=requestid,
                    typeid=FRAME_TYPE_TEXT_OUTPUT,
                    flags=0,
                    payload=b''.join(atomchunks))

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
        self._bufferedframegens = []
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
        handlers = {
            'idle': self._onframeidle,
            'command-receiving': self._onframecommandreceiving,
            'errored': self._onframeerrored,
        }

        meth = handlers.get(self._state)
        if not meth:
            raise error.ProgrammingError('unhandled state: %s' % self._state)

        return meth(frame)

    def onbytesresponseready(self, requestid, data):
        """Signal that a bytes response is ready to be sent to the client.

        The raw bytes response is passed as an argument.
        """
        def sendframes():
            for frame in createbytesresponseframesfrombytes(requestid, data):
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

    def onapplicationerror(self, requestid, msg):
        return 'sendframes', {
            'framegen': createerrorframe(requestid, msg, application=True),
        }

    def _makeerrorresult(self, msg):
        return 'error', {
            'message': msg,
        }

    def _makeruncommandresult(self, requestid):
        entry = self._receivingcommands[requestid]
        del self._receivingcommands[requestid]

        if self._receivingcommands:
            self._state = 'command-receiving'
        else:
            self._state = 'idle'

        assert requestid not in self._activecommands
        self._activecommands.add(requestid)

        return 'runcommand', {
            'requestid': requestid,
            'command': entry['command'],
            'args': entry['args'],
            'data': entry['data'].getvalue() if entry['data'] else None,
        }

    def _makewantframeresult(self):
        return 'wantframe', {
            'state': self._state,
        }

    def _onframeidle(self, frame):
        # The only frame type that should be received in this state is a
        # command request.
        if frame.typeid != FRAME_TYPE_COMMAND_NAME:
            self._state = 'errored'
            return self._makeerrorresult(
                _('expected command frame; got %d') % frame.typeid)

        if frame.requestid in self._receivingcommands:
            self._state = 'errored'
            return self._makeerrorresult(
                _('request with ID %d already received') % frame.requestid)

        if frame.requestid in self._activecommands:
            self._state = 'errored'
            return self._makeerrorresult((
                _('request with ID %d is already active') % frame.requestid))

        expectingargs = bool(frame.flags & FLAG_COMMAND_NAME_HAVE_ARGS)
        expectingdata = bool(frame.flags & FLAG_COMMAND_NAME_HAVE_DATA)

        self._receivingcommands[frame.requestid] = {
            'command': frame.payload,
            'args': {},
            'data': None,
            'expectingargs': expectingargs,
            'expectingdata': expectingdata,
        }

        if frame.flags & FLAG_COMMAND_NAME_EOS:
            return self._makeruncommandresult(frame.requestid)

        if expectingargs or expectingdata:
            self._state = 'command-receiving'
            return self._makewantframeresult()
        else:
            self._state = 'errored'
            return self._makeerrorresult(_('missing frame flags on '
                                           'command frame'))

    def _onframecommandreceiving(self, frame):
        # It could be a new command request. Process it as such.
        if frame.typeid == FRAME_TYPE_COMMAND_NAME:
            return self._onframeidle(frame)

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

        if frame.typeid == FRAME_TYPE_COMMAND_ARGUMENT:
            if not entry['expectingargs']:
                self._state = 'errored'
                return self._makeerrorresult(_(
                    'received command argument frame for request that is not '
                    'expecting arguments: %d') % frame.requestid)

            return self._handlecommandargsframe(frame, entry)

        elif frame.typeid == FRAME_TYPE_COMMAND_DATA:
            if not entry['expectingdata']:
                self._state = 'errored'
                return self._makeerrorresult(_(
                    'received command data frame for request that is not '
                    'expecting data: %d') % frame.requestid)

            if entry['data'] is None:
                entry['data'] = util.bytesio()

            return self._handlecommanddataframe(frame, entry)

    def _handlecommandargsframe(self, frame, entry):
        # The frame and state of command should have already been validated.
        assert frame.typeid == FRAME_TYPE_COMMAND_ARGUMENT

        offset = 0
        namesize, valuesize = ARGUMENT_FRAME_HEADER.unpack_from(frame.payload)
        offset += ARGUMENT_FRAME_HEADER.size

        # The argument name MUST fit inside the frame.
        argname = bytes(frame.payload[offset:offset + namesize])
        offset += namesize

        if len(argname) != namesize:
            self._state = 'errored'
            return self._makeerrorresult(_('malformed argument frame: '
                                           'partial argument name'))

        argvalue = bytes(frame.payload[offset:])

        # Argument value spans multiple frames. Record our active state
        # and wait for the next frame.
        if frame.flags & FLAG_COMMAND_ARGUMENT_CONTINUATION:
            raise error.ProgrammingError('not yet implemented')

        # Common case: the argument value is completely contained in this
        # frame.

        if len(argvalue) != valuesize:
            self._state = 'errored'
            return self._makeerrorresult(_('malformed argument frame: '
                                           'partial argument value'))

        entry['args'][argname] = argvalue

        if frame.flags & FLAG_COMMAND_ARGUMENT_EOA:
            if entry['expectingdata']:
                # TODO signal request to run a command once we don't
                # buffer data frames.
                return self._makewantframeresult()
            else:
                return self._makeruncommandresult(frame.requestid)
        else:
            return self._makewantframeresult()

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
