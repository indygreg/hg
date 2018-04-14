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
    error,
    util,
    wireprotoframing,
)

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
        self._responses[rid] = {
            'cbor': False,
            'b': util.bytesio(),
        }

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
            response['b'].write(meta['data'])

            if meta['cbor']:
                response['cbor'] = True

            if meta['eos']:
                if meta['cbor']:
                    # If CBOR, decode every object.
                    b = response['b']

                    size = b.tell()
                    b.seek(0)

                    decoder = cbor.CBORDecoder(b)

                    result = []
                    while b.tell() < size:
                        result.append(decoder.decode())
                else:
                    result = [response['b'].getvalue()]

                self._futures[frame.requestid].set_result(result)

                del self._requests[frame.requestid]
                del self._futures[frame.requestid]

        else:
            raise error.ProgrammingError(
                'unhandled action from clientreactor: %s' % action)
