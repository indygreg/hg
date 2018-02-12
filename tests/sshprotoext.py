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
    extensions,
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
        wireprotoserver._sshv1respondbytes(self._fout, b'')
        l = self._fin.readline()
        assert l == b'between\n'
        rsp = wireproto.dispatch(self._repo, self._proto, b'between')
        wireprotoserver._sshv1respondbytes(self._fout, rsp.data)

        super(prehelloserver, self).serve_forever()

class upgradev2server(wireprotoserver.sshserver):
    """Tests behavior for clients that issue upgrade to version 2."""
    def serve_forever(self):
        name = wireprotoserver.SSHV2
        l = self._fin.readline()
        assert l.startswith(b'upgrade ')
        token, caps = l[:-1].split(b' ')[1:]
        assert caps == b'proto=%s' % name

        # Filter hello and between requests.
        l = self._fin.readline()
        assert l == b'hello\n'
        l = self._fin.readline()
        assert l == b'between\n'
        l = self._fin.readline()
        assert l == b'pairs 81\n'
        self._fin.read(81)

        # Send the upgrade response.
        self._fout.write(b'upgraded %s %s\n' % (token, name))
        servercaps = wireproto.capabilities(self._repo, self._proto)
        rsp = b'capabilities: %s' % servercaps.data
        self._fout.write(b'%d\n' % len(rsp))
        self._fout.write(rsp)
        self._fout.write(b'\n')
        self._fout.flush()

        super(upgradev2server, self).serve_forever()

def performhandshake(orig, ui, stdin, stdout, stderr):
    """Wrapped version of sshpeer._performhandshake to send extra commands."""
    mode = ui.config(b'sshpeer', b'handshake-mode')
    if mode == b'pre-no-args':
        ui.debug(b'sending no-args command\n')
        stdin.write(b'no-args\n')
        stdin.flush()
        return orig(ui, stdin, stdout, stderr)
    elif mode == b'pre-multiple-no-args':
        ui.debug(b'sending unknown1 command\n')
        stdin.write(b'unknown1\n')
        ui.debug(b'sending unknown2 command\n')
        stdin.write(b'unknown2\n')
        ui.debug(b'sending unknown3 command\n')
        stdin.write(b'unknown3\n')
        stdin.flush()
        return orig(ui, stdin, stdout, stderr)
    else:
        raise error.ProgrammingError(b'unknown HANDSHAKECOMMANDMODE: %s' %
                                     mode)

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
    elif servermode == b'upgradev2':
        wireprotoserver.sshserver = upgradev2server
    elif servermode:
        raise error.ProgrammingError(b'unknown server mode: %s' % servermode)

    peermode = ui.config(b'sshpeer', b'mode')

    if peermode == b'extra-handshake-commands':
        extensions.wrapfunction(sshpeer, '_performhandshake', performhandshake)
    elif peermode:
        raise error.ProgrammingError(b'unknown peer mode: %s' % peermode)
