# sshprotoext.py - Extension to test behavior of SSH protocol
#
# Copyright 2018 Gregory Szorc <gregory.szorc@gmail.com>
#
# This software may be used and distributed according to the terms of the
# GNU General Public License version 2 or any later version.

# This extension replaces the SSH server started via `hg serve --stdio`.
# The server behaves differently depending on environment variables.

from __future__ import absolute_import

from mercurial import (
    error,
    registrar,
    sshpeer,
    wireproto,
    wireprotoserver,
)

configtable = {}
configitem = registrar.configitem(configtable)

configitem('sshpeer', 'mode', default=None)
configitem('sshpeer', 'handshake-mode', default=None)

class bannerserver(wireprotoserver.sshserver):
    """Server that sends a banner to stdout."""
    def serve_forever(self):
        for i in range(10):
            self._fout.write(b'banner: line %d\n' % i)

        super(bannerserver, self).serve_forever()

class prehelloserver(wireprotoserver.sshserver):
    """Tests behavior when connecting to <0.9.1 servers.

    The ``hello`` wire protocol command was introduced in Mercurial
    0.9.1. Modern clients send the ``hello`` command when connecting
    to SSH servers. This mock server tests behavior of the handshake
    when ``hello`` is not supported.
    """
    def serve_forever(self):
        l = self._fin.readline()
        assert l == b'hello\n'
        # Respond to unknown commands with an empty reply.
        self._sendresponse(b'')
        l = self._fin.readline()
        assert l == b'between\n'
        rsp = wireproto.dispatch(self._repo, self, b'between')
        self._handlers[rsp.__class__](self, rsp)

        super(prehelloserver, self).serve_forever()

class extrahandshakecommandspeer(sshpeer.sshpeer):
    """An ssh peer that sends extra commands as part of initial handshake."""
    def _validaterepo(self):
        mode = self._ui.config(b'sshpeer', b'handshake-mode')
        if mode == b'pre-no-args':
            self._callstream(b'no-args')
            return super(extrahandshakecommandspeer, self)._validaterepo()
        elif mode == b'pre-multiple-no-args':
            self._callstream(b'unknown1')
            self._callstream(b'unknown2')
            self._callstream(b'unknown3')
            return super(extrahandshakecommandspeer, self)._validaterepo()
        else:
            raise error.ProgrammingError(b'unknown HANDSHAKECOMMANDMODE: %s' %
                                         mode)

def registercommands():
    def dummycommand(repo, proto):
        raise error.ProgrammingError('this should never be called')

    wireproto.wireprotocommand(b'no-args', b'')(dummycommand)
    wireproto.wireprotocommand(b'unknown1', b'')(dummycommand)
    wireproto.wireprotocommand(b'unknown2', b'')(dummycommand)
    wireproto.wireprotocommand(b'unknown3', b'')(dummycommand)

def extsetup(ui):
    # It's easier for tests to define the server behavior via environment
    # variables than config options. This is because `hg serve --stdio`
    # has to be invoked with a certain form for security reasons and
    # `dummyssh` can't just add `--config` flags to the command line.
    servermode = ui.environ.get(b'SSHSERVERMODE')

    if servermode == b'banner':
        wireprotoserver.sshserver = bannerserver
    elif servermode == b'no-hello':
        wireprotoserver.sshserver = prehelloserver
    elif servermode:
        raise error.ProgrammingError(b'unknown server mode: %s' % servermode)

    peermode = ui.config(b'sshpeer', b'mode')

    if peermode == b'extra-handshake-commands':
        sshpeer.sshpeer = extrahandshakecommandspeer
        registercommands()
    elif peermode:
        raise error.ProgrammingError(b'unknown peer mode: %s' % peermode)
