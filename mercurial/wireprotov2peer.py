# wireprotov2peer.py - client side code for wire protocol version 2
#
# Copyright 2018 Gregory Szorc <gregory.szorc@gmail.com>
#
# This software may be used and distributed according to the terms of the
# GNU General Public License version 2 or any later version.

from __future__ import absolute_import

from .i18n import _
from .thirdparty import (
    cbor,
)
from . import (
    encoding,
    error,
    util,
    wireprotoframing,
)

class commandresponse(object):
    """Represents the response to a command request."""

    def __init__(self, requestid, command):
        self.requestid = requestid
        self.command = command

        self.b = util.bytesio()

    def cborobjects(self):
        """Obtain decoded CBOR objects from this response."""
        size = self.b.tell()
        self.b.seek(0)

        decoder = cbor.CBORDecoder(self.b)

        while self.b.tell() < size:
            yield decoder.decode()

class clienthandler(object):
    """Object to handle higher-level client activities.

    The ``clientreactor`` is used to hold low-level state about the frame-based
    protocol, such as which requests and streams are active. This type is used
    for higher-level operations, such as reading frames from a socket, exposing
    and managing a higher-level primitive for representing command responses,
    etc. This class is what peers should probably use to bridge wire activity
    with the higher-level peer API.
    """

    def __init__(self, ui, clientreactor):
        self._ui = ui
        self._reactor = clientreactor
        self._requests = {}
        self._futures = {}
        self._responses = {}

    def callcommand(self, command, args, f):
        """Register a request to call a command.

        Returns an iterable of frames that should be sent over the wire.
        """
        request, action, meta = self._reactor.callcommand(command, args)

        if action != 'noop':
            raise error.ProgrammingError('%s not yet supported' % action)

        rid = request.requestid
        self._requests[rid] = request
        self._futures[rid] = f
        self._responses[rid] = commandresponse(rid, command)

        return iter(())

    def flushcommands(self):
        """Flush all queued commands.

        Returns an iterable of frames that should be sent over the wire.
        """
        action, meta = self._reactor.flushcommands()

        if action != 'sendframes':
            raise error.ProgrammingError('%s not yet supported' % action)

        return meta['framegen']

    def readframe(self, fh):
        """Attempt to read and process a frame.

        Returns None if no frame was read. Presumably this means EOF.
        """
        frame = wireprotoframing.readframe(fh)
        if frame is None:
            # TODO tell reactor?
            return

        self._ui.note(_('received %r\n') % frame)
        self._processframe(frame)

        return True

    def _processframe(self, frame):
        """Process a single read frame."""

        action, meta = self._reactor.onframerecv(frame)

        if action == 'error':
            e = error.RepoError(meta['message'])

            if frame.requestid in self._futures:
                self._futures[frame.requestid].set_exception(e)
            else:
                raise e

        if frame.requestid not in self._requests:
            raise error.ProgrammingError(
                'received frame for unknown request; this is either a bug in '
                'the clientreactor not screening for this or this instance was '
                'never told about this request: %r' % frame)

        response = self._responses[frame.requestid]

        if action == 'responsedata':
            response.b.write(meta['data'])

            if meta['eos']:
                # If the command has a decoder, resolve the future to the
                # decoded value. Otherwise resolve to the rich response object.
                decoder = COMMAND_DECODERS.get(response.command)

                result = decoder(response) if decoder else response

                self._futures[frame.requestid].set_result(result)

                del self._requests[frame.requestid]
                del self._futures[frame.requestid]

        else:
            raise error.ProgrammingError(
                'unhandled action from clientreactor: %s' % action)

def decodebranchmap(resp):
    # Response should be a single CBOR map of branch name to array of nodes.
    bm = next(resp.cborobjects())

    return {encoding.tolocal(k): v for k, v in bm.items()}

def decodeheads(resp):
    # Array of node bytestrings.
    return next(resp.cborobjects())

def decodeknown(resp):
    # Bytestring where each byte is a 0 or 1.
    raw = next(resp.cborobjects())

    return [True if c == '1' else False for c in raw]

def decodelistkeys(resp):
    # Map with bytestring keys and values.
    return next(resp.cborobjects())

def decodelookup(resp):
    return next(resp.cborobjects())

def decodepushkey(resp):
    return next(resp.cborobjects())

COMMAND_DECODERS = {
    'branchmap': decodebranchmap,
    'heads': decodeheads,
    'known': decodeknown,
    'listkeys': decodelistkeys,
    'lookup': decodelookup,
    'pushkey': decodepushkey,
}
