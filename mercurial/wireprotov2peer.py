# wireprotov2peer.py - client side code for wire protocol version 2
#
# Copyright 2018 Gregory Szorc <gregory.szorc@gmail.com>
#
# This software may be used and distributed according to the terms of the
# GNU General Public License version 2 or any later version.

from __future__ import absolute_import

import threading

from .i18n import _
from . import (
    encoding,
    error,
    wireprotoframing,
)
from .utils import (
    cborutil,
)

def formatrichmessage(atoms):
    """Format an encoded message from the framing protocol."""

    chunks = []

    for atom in atoms:
        msg = _(atom[b'msg'])

        if b'args' in atom:
            msg = msg % tuple(atom[b'args'])

        chunks.append(msg)

    return b''.join(chunks)

class commandresponse(object):
    """Represents the response to a command request.

    Instances track the state of the command and hold its results.

    An external entity is required to update the state of the object when
    events occur.
    """

    def __init__(self, requestid, command):
        self.requestid = requestid
        self.command = command

        # Whether all remote input related to this command has been
        # received.
        self._inputcomplete = False

        # We have a lock that is acquired when important object state is
        # mutated. This is to prevent race conditions between 1 thread
        # sending us new data and another consuming it.
        self._lock = threading.RLock()

        # An event is set when state of the object changes. This event
        # is waited on by the generator emitting objects.
        self._serviceable = threading.Event()

        self._pendingevents = []
        self._decoder = cborutil.bufferingdecoder()
        self._seeninitial = False

    def _oninputcomplete(self):
        with self._lock:
            self._inputcomplete = True
            self._serviceable.set()

    def _onresponsedata(self, data):
        available, readcount, wanted = self._decoder.decode(data)

        if not available:
            return

        with self._lock:
            for o in self._decoder.getavailable():
                if not self._seeninitial:
                    self._handleinitial(o)
                    continue

                self._pendingevents.append(o)

            self._serviceable.set()

    def _handleinitial(self, o):
        self._seeninitial = True
        if o[b'status'] == 'ok':
            return

        atoms = [{'msg': o[b'error'][b'message']}]
        if b'args' in o[b'error']:
            atoms[0]['args'] = o[b'error'][b'args']

        raise error.RepoError(formatrichmessage(atoms))

    def objects(self):
        """Obtained decoded objects from this response.

        This is a generator of data structures that were decoded from the
        command response.

        Obtaining the next member of the generator may block due to waiting
        on external data to become available.

        If the server encountered an error in the middle of serving the data
        or if another error occurred, an exception may be raised when
        advancing the generator.
        """
        while True:
            # TODO this can infinite loop if self._inputcomplete is never
            # set. We likely want to tie the lifetime of this object/state
            # to that of the background thread receiving frames and updating
            # our state.
            self._serviceable.wait(1.0)

            with self._lock:
                self._serviceable.clear()

                # Make copies because objects could be mutated during
                # iteration.
                stop = self._inputcomplete
                pending = list(self._pendingevents)
                self._pendingevents[:] = []

            for o in pending:
                yield o

            if stop:
                break

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
        # TODO we need some kind of lifetime on response instances otherwise
        # objects() may deadlock.
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

            if frame.requestid in self._responses:
                self._responses[frame.requestid]._oninputcomplete()

            if frame.requestid in self._futures:
                self._futures[frame.requestid].set_exception(e)
                del self._futures[frame.requestid]
            else:
                raise e

            return

        if frame.requestid not in self._requests:
            raise error.ProgrammingError(
                'received frame for unknown request; this is either a bug in '
                'the clientreactor not screening for this or this instance was '
                'never told about this request: %r' % frame)

        response = self._responses[frame.requestid]

        if action == 'responsedata':
            # Any failures processing this frame should bubble up to the
            # future tracking the request.
            try:
                self._processresponsedata(frame, meta, response)
            except BaseException as e:
                self._futures[frame.requestid].set_exception(e)
                del self._futures[frame.requestid]
                response._oninputcomplete()
        else:
            raise error.ProgrammingError(
                'unhandled action from clientreactor: %s' % action)

    def _processresponsedata(self, frame, meta, response):
        # This can raise. The caller can handle it.
        response._onresponsedata(meta['data'])

        if meta['eos']:
            response._oninputcomplete()
            del self._requests[frame.requestid]

        # If the command has a decoder, we wait until all input has been
        # received before resolving the future. Otherwise we resolve the
        # future immediately.
        if frame.requestid not in self._futures:
            return

        if response.command not in COMMAND_DECODERS:
            self._futures[frame.requestid].set_result(response.objects())
            del self._futures[frame.requestid]
        elif response._inputcomplete:
            decoded = COMMAND_DECODERS[response.command](response.objects())
            self._futures[frame.requestid].set_result(decoded)
            del self._futures[frame.requestid]

def decodebranchmap(objs):
    # Response should be a single CBOR map of branch name to array of nodes.
    bm = next(objs)

    return {encoding.tolocal(k): v for k, v in bm.items()}

def decodeheads(objs):
    # Array of node bytestrings.
    return next(objs)

def decodeknown(objs):
    # Bytestring where each byte is a 0 or 1.
    raw = next(objs)

    return [True if c == '1' else False for c in raw]

def decodelistkeys(objs):
    # Map with bytestring keys and values.
    return next(objs)

def decodelookup(objs):
    return next(objs)

def decodepushkey(objs):
    return next(objs)

COMMAND_DECODERS = {
    'branchmap': decodebranchmap,
    'heads': decodeheads,
    'known': decodeknown,
    'listkeys': decodelistkeys,
    'lookup': decodelookup,
    'pushkey': decodepushkey,
}
