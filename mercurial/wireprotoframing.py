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

FRAME_TYPES = {
    b'command-name': FRAME_TYPE_COMMAND_NAME,
    b'command-argument': FRAME_TYPE_COMMAND_ARGUMENT,
    b'command-data': FRAME_TYPE_COMMAND_DATA,
    b'bytes-response': FRAME_TYPE_BYTES_RESPONSE,
    b'error-response': FRAME_TYPE_ERROR_RESPONSE,
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
}

ARGUMENT_FRAME_HEADER = struct.Struct(r'<HH')

def makeframe(requestid, frametype, frameflags, payload):
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
    frame[5] = (frametype << 4) | frameflags
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

    return makeframe(requestid, frametype, finalflags, payload)

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

    return requestid, frametype, frameflags, framelength

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

    requestid, frametype, frameflags, framelength = parseheader(header)

    payload = fh.read(framelength)
    if len(payload) != framelength:
        raise error.Abort(_('frame length error: expected %d; got %d') %
                          (framelength, len(payload)))

    return requestid, frametype, frameflags, payload

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

    yield makeframe(requestid, FRAME_TYPE_COMMAND_NAME, flags, cmd)

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
        yield makeframe(requestid, FRAME_TYPE_COMMAND_ARGUMENT, flags, payload)

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

            yield makeframe(requestid, FRAME_TYPE_COMMAND_DATA, flags, data)

            if done:
                break

def createbytesresponseframesfrombytes(requestid, data,
                                       maxframesize=DEFAULT_MAX_FRAME_SIZE):
    """Create a raw frame to send a bytes response from static bytes input.

    Returns a generator of bytearrays.
    """

    # Simple case of a single frame.
    if len(data) <= maxframesize:
        yield makeframe(requestid, FRAME_TYPE_BYTES_RESPONSE,
                        FLAG_BYTES_RESPONSE_EOS, data)
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

        yield makeframe(requestid, FRAME_TYPE_BYTES_RESPONSE, flags, chunk)

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

    yield makeframe(requestid, FRAME_TYPE_ERROR_RESPONSE, flags, msg)

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
        self._activerequestid = None
        self._activecommand = None
        self._activeargs = None
        self._activedata = None
        self._expectingargs = None
        self._expectingdata = None
        self._activeargname = None
        self._activeargchunks = None

    def onframerecv(self, requestid, frametype, frameflags, payload):
        """Process a frame that has been received off the wire.

        Returns a dict with an ``action`` key that details what action,
        if any, the consumer should take next.
        """
        handlers = {
            'idle': self._onframeidle,
            'command-receiving-args': self._onframereceivingargs,
            'command-receiving-data': self._onframereceivingdata,
            'errored': self._onframeerrored,
        }

        meth = handlers.get(self._state)
        if not meth:
            raise error.ProgrammingError('unhandled state: %s' % self._state)

        return meth(requestid, frametype, frameflags, payload)

    def onbytesresponseready(self, requestid, data):
        """Signal that a bytes response is ready to be sent to the client.

        The raw bytes response is passed as an argument.
        """
        framegen = createbytesresponseframesfrombytes(requestid, data)

        if self._deferoutput:
            self._bufferedframegens.append(framegen)
            return 'noop', {}
        else:
            return 'sendframes', {
                'framegen': framegen,
            }

    def oninputeof(self):
        """Signals that end of input has been received.

        No more frames will be received. All pending activity should be
        completed.
        """
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

    def _makeruncommandresult(self):
        return 'runcommand', {
            'requestid': self._activerequestid,
            'command': self._activecommand,
            'args': self._activeargs,
            'data': self._activedata.getvalue() if self._activedata else None,
        }

    def _makewantframeresult(self):
        return 'wantframe', {
            'state': self._state,
        }

    def _onframeidle(self, requestid, frametype, frameflags, payload):
        # The only frame type that should be received in this state is a
        # command request.
        if frametype != FRAME_TYPE_COMMAND_NAME:
            self._state = 'errored'
            return self._makeerrorresult(
                _('expected command frame; got %d') % frametype)

        self._activerequestid = requestid
        self._activecommand = payload
        self._activeargs = {}
        self._activedata = None

        if frameflags & FLAG_COMMAND_NAME_EOS:
            return self._makeruncommandresult()

        self._expectingargs = bool(frameflags & FLAG_COMMAND_NAME_HAVE_ARGS)
        self._expectingdata = bool(frameflags & FLAG_COMMAND_NAME_HAVE_DATA)

        if self._expectingargs:
            self._state = 'command-receiving-args'
            return self._makewantframeresult()
        elif self._expectingdata:
            self._activedata = util.bytesio()
            self._state = 'command-receiving-data'
            return self._makewantframeresult()
        else:
            self._state = 'errored'
            return self._makeerrorresult(_('missing frame flags on '
                                           'command frame'))

    def _onframereceivingargs(self, requestid, frametype, frameflags, payload):
        if frametype != FRAME_TYPE_COMMAND_ARGUMENT:
            self._state = 'errored'
            return self._makeerrorresult(_('expected command argument '
                                           'frame; got %d') % frametype)

        offset = 0
        namesize, valuesize = ARGUMENT_FRAME_HEADER.unpack_from(payload)
        offset += ARGUMENT_FRAME_HEADER.size

        # The argument name MUST fit inside the frame.
        argname = bytes(payload[offset:offset + namesize])
        offset += namesize

        if len(argname) != namesize:
            self._state = 'errored'
            return self._makeerrorresult(_('malformed argument frame: '
                                           'partial argument name'))

        argvalue = bytes(payload[offset:])

        # Argument value spans multiple frames. Record our active state
        # and wait for the next frame.
        if frameflags & FLAG_COMMAND_ARGUMENT_CONTINUATION:
            raise error.ProgrammingError('not yet implemented')
            self._activeargname = argname
            self._activeargchunks = [argvalue]
            self._state = 'command-arg-continuation'
            return self._makewantframeresult()

        # Common case: the argument value is completely contained in this
        # frame.

        if len(argvalue) != valuesize:
            self._state = 'errored'
            return self._makeerrorresult(_('malformed argument frame: '
                                           'partial argument value'))

        self._activeargs[argname] = argvalue

        if frameflags & FLAG_COMMAND_ARGUMENT_EOA:
            if self._expectingdata:
                self._state = 'command-receiving-data'
                self._activedata = util.bytesio()
                # TODO signal request to run a command once we don't
                # buffer data frames.
                return self._makewantframeresult()
            else:
                self._state = 'waiting'
                return self._makeruncommandresult()
        else:
            return self._makewantframeresult()

    def _onframereceivingdata(self, requestid, frametype, frameflags, payload):
        if frametype != FRAME_TYPE_COMMAND_DATA:
            self._state = 'errored'
            return self._makeerrorresult(_('expected command data frame; '
                                           'got %d') % frametype)

        # TODO support streaming data instead of buffering it.
        self._activedata.write(payload)

        if frameflags & FLAG_COMMAND_DATA_CONTINUATION:
            return self._makewantframeresult()
        elif frameflags & FLAG_COMMAND_DATA_EOS:
            self._activedata.seek(0)
            self._state = 'idle'
            return self._makeruncommandresult()
        else:
            self._state = 'errored'
            return self._makeerrorresult(_('command data frame without '
                                           'flags'))

    def _onframeerrored(self, requestid, frametype, frameflags, payload):
        return self._makeerrorresult(_('server already errored'))
