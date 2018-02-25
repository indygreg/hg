# Copyright 21 May 2005 - (c) 2005 Jake Edge <jake@edge2.net>
# Copyright 2005-2007 Matt Mackall <mpm@selenic.com>
#
# This software may be used and distributed according to the terms of the
# GNU General Public License version 2 or any later version.

from __future__ import absolute_import

import contextlib
import struct
import sys
import threading

from .i18n import _
from . import (
    encoding,
    error,
    hook,
    pycompat,
    util,
    wireproto,
    wireprototypes,
)

stringio = util.stringio

urlerr = util.urlerr
urlreq = util.urlreq

HTTP_OK = 200

HGTYPE = 'application/mercurial-0.1'
HGTYPE2 = 'application/mercurial-0.2'
HGERRTYPE = 'application/hg-error'

# Names of the SSH protocol implementations.
SSHV1 = 'ssh-v1'
# This is advertised over the wire. Incremental the counter at the end
# to reflect BC breakages.
SSHV2 = 'exp-ssh-v2-0001'

def decodevaluefromheaders(req, headerprefix):
    """Decode a long value from multiple HTTP request headers.

    Returns the value as a bytes, not a str.
    """
    chunks = []
    i = 1
    prefix = headerprefix.upper().replace(r'-', r'_')
    while True:
        v = req.env.get(r'HTTP_%s_%d' % (prefix, i))
        if v is None:
            break
        chunks.append(pycompat.bytesurl(v))
        i += 1

    return ''.join(chunks)

class httpv1protocolhandler(wireprototypes.baseprotocolhandler):
    def __init__(self, req, ui):
        self._req = req
        self._ui = ui

    @property
    def name(self):
        return 'http-v1'

    def getargs(self, args):
        knownargs = self._args()
        data = {}
        keys = args.split()
        for k in keys:
            if k == '*':
                star = {}
                for key in knownargs.keys():
                    if key != 'cmd' and key not in keys:
                        star[key] = knownargs[key][0]
                data['*'] = star
            else:
                data[k] = knownargs[k][0]
        return [data[k] for k in keys]

    def _args(self):
        args = util.rapply(pycompat.bytesurl, self._req.form.copy())
        postlen = int(self._req.env.get(r'HTTP_X_HGARGS_POST', 0))
        if postlen:
            args.update(urlreq.parseqs(
                self._req.read(postlen), keep_blank_values=True))
            return args

        argvalue = decodevaluefromheaders(self._req, r'X-HgArg')
        args.update(urlreq.parseqs(argvalue, keep_blank_values=True))
        return args

    def forwardpayload(self, fp):
        if r'HTTP_CONTENT_LENGTH' in self._req.env:
            length = int(self._req.env[r'HTTP_CONTENT_LENGTH'])
        else:
            length = int(self._req.env[r'CONTENT_LENGTH'])
        # If httppostargs is used, we need to read Content-Length
        # minus the amount that was consumed by args.
        length -= int(self._req.env.get(r'HTTP_X_HGARGS_POST', 0))
        for s in util.filechunkiter(self._req, limit=length):
            fp.write(s)

    @contextlib.contextmanager
    def mayberedirectstdio(self):
        oldout = self._ui.fout
        olderr = self._ui.ferr

        out = util.stringio()

        try:
            self._ui.fout = out
            self._ui.ferr = out
            yield out
        finally:
            self._ui.fout = oldout
            self._ui.ferr = olderr

    def client(self):
        return 'remote:%s:%s:%s' % (
            self._req.env.get('wsgi.url_scheme') or 'http',
            urlreq.quote(self._req.env.get('REMOTE_HOST', '')),
            urlreq.quote(self._req.env.get('REMOTE_USER', '')))

# This method exists mostly so that extensions like remotefilelog can
# disable a kludgey legacy method only over http. As of early 2018,
# there are no other known users, so with any luck we can discard this
# hook if remotefilelog becomes a first-party extension.
def iscmd(cmd):
    return cmd in wireproto.commands

def parsehttprequest(repo, req, query):
    """Parse the HTTP request for a wire protocol request.

    If the current request appears to be a wire protocol request, this
    function returns a dict with details about that request, including
    an ``abstractprotocolserver`` instance suitable for handling the
    request. Otherwise, ``None`` is returned.

    ``req`` is a ``wsgirequest`` instance.
    """
    # HTTP version 1 wire protocol requests are denoted by a "cmd" query
    # string parameter. If it isn't present, this isn't a wire protocol
    # request.
    if r'cmd' not in req.form:
        return None

    cmd = pycompat.sysbytes(req.form[r'cmd'][0])

    # The "cmd" request parameter is used by both the wire protocol and hgweb.
    # While not all wire protocol commands are available for all transports,
    # if we see a "cmd" value that resembles a known wire protocol command, we
    # route it to a protocol handler. This is better than routing possible
    # wire protocol requests to hgweb because it prevents hgweb from using
    # known wire protocol commands and it is less confusing for machine
    # clients.
    if not iscmd(cmd):
        return None

    proto = httpv1protocolhandler(req, repo.ui)

    return {
        'cmd': cmd,
        'proto': proto,
        'dispatch': lambda: _callhttp(repo, req, proto, cmd),
        'handleerror': lambda ex: _handlehttperror(ex, req, cmd),
    }

def _httpresponsetype(ui, req, prefer_uncompressed):
    """Determine the appropriate response type and compression settings.

    Returns a tuple of (mediatype, compengine, engineopts).
    """
    # Determine the response media type and compression engine based
    # on the request parameters.
    protocaps = decodevaluefromheaders(req, r'X-HgProto').split(' ')

    if '0.2' in protocaps:
        # All clients are expected to support uncompressed data.
        if prefer_uncompressed:
            return HGTYPE2, util._noopengine(), {}

        # Default as defined by wire protocol spec.
        compformats = ['zlib', 'none']
        for cap in protocaps:
            if cap.startswith('comp='):
                compformats = cap[5:].split(',')
                break

        # Now find an agreed upon compression format.
        for engine in wireproto.supportedcompengines(ui, util.SERVERROLE):
            if engine.wireprotosupport().name in compformats:
                opts = {}
                level = ui.configint('server', '%slevel' % engine.name())
                if level is not None:
                    opts['level'] = level

                return HGTYPE2, engine, opts

        # No mutually supported compression format. Fall back to the
        # legacy protocol.

    # Don't allow untrusted settings because disabling compression or
    # setting a very high compression level could lead to flooding
    # the server's network or CPU.
    opts = {'level': ui.configint('server', 'zliblevel')}
    return HGTYPE, util.compengines['zlib'], opts

def _callhttp(repo, req, proto, cmd):
    def genversion2(gen, engine, engineopts):
        # application/mercurial-0.2 always sends a payload header
        # identifying the compression engine.
        name = engine.wireprotosupport().name
        assert 0 < len(name) < 256
        yield struct.pack('B', len(name))
        yield name

        for chunk in gen:
            yield chunk

    rsp = wireproto.dispatch(repo, proto, cmd)

    if not wireproto.commands.commandavailable(cmd, proto):
        req.respond(HTTP_OK, HGERRTYPE,
                    body=_('requested wire protocol command is not available '
                           'over HTTP'))
        return []

    if isinstance(rsp, bytes):
        req.respond(HTTP_OK, HGTYPE, body=rsp)
        return []
    elif isinstance(rsp, wireprototypes.bytesresponse):
        req.respond(HTTP_OK, HGTYPE, body=rsp.data)
        return []
    elif isinstance(rsp, wireprototypes.streamreslegacy):
        gen = rsp.gen
        req.respond(HTTP_OK, HGTYPE)
        return gen
    elif isinstance(rsp, wireprototypes.streamres):
        gen = rsp.gen

        # This code for compression should not be streamres specific. It
        # is here because we only compress streamres at the moment.
        mediatype, engine, engineopts = _httpresponsetype(
            repo.ui, req, rsp.prefer_uncompressed)
        gen = engine.compressstream(gen, engineopts)

        if mediatype == HGTYPE2:
            gen = genversion2(gen, engine, engineopts)

        req.respond(HTTP_OK, mediatype)
        return gen
    elif isinstance(rsp, wireprototypes.pushres):
        rsp = '%d\n%s' % (rsp.res, rsp.output)
        req.respond(HTTP_OK, HGTYPE, body=rsp)
        return []
    elif isinstance(rsp, wireprototypes.pusherr):
        # This is the httplib workaround documented in _handlehttperror().
        req.drain()

        rsp = '0\n%s\n' % rsp.res
        req.respond(HTTP_OK, HGTYPE, body=rsp)
        return []
    elif isinstance(rsp, wireprototypes.ooberror):
        rsp = rsp.message
        req.respond(HTTP_OK, HGERRTYPE, body=rsp)
        return []
    raise error.ProgrammingError('hgweb.protocol internal failure', rsp)

def _handlehttperror(e, req, cmd):
    """Called when an ErrorResponse is raised during HTTP request processing."""

    # Clients using Python's httplib are stateful: the HTTP client
    # won't process an HTTP response until all request data is
    # sent to the server. The intent of this code is to ensure
    # we always read HTTP request data from the client, thus
    # ensuring httplib transitions to a state that allows it to read
    # the HTTP response. In other words, it helps prevent deadlocks
    # on clients using httplib.

    if (req.env[r'REQUEST_METHOD'] == r'POST' and
        # But not if Expect: 100-continue is being used.
        (req.env.get('HTTP_EXPECT',
                     '').lower() != '100-continue') or
        # Or the non-httplib HTTP library is being advertised by
        # the client.
        req.env.get('X-HgHttp2', '')):
        req.drain()
    else:
        req.headers.append((r'Connection', r'Close'))

    # TODO This response body assumes the failed command was
    # "unbundle." That assumption is not always valid.
    req.respond(e, HGTYPE, body='0\n%s\n' % pycompat.bytestr(e))

    return ''

def _sshv1respondbytes(fout, value):
    """Send a bytes response for protocol version 1."""
    fout.write('%d\n' % len(value))
    fout.write(value)
    fout.flush()

def _sshv1respondstream(fout, source):
    write = fout.write
    for chunk in source.gen:
        write(chunk)
    fout.flush()

def _sshv1respondooberror(fout, ferr, rsp):
    ferr.write(b'%s\n-\n' % rsp)
    ferr.flush()
    fout.write(b'\n')
    fout.flush()

class sshv1protocolhandler(wireprototypes.baseprotocolhandler):
    """Handler for requests services via version 1 of SSH protocol."""
    def __init__(self, ui, fin, fout):
        self._ui = ui
        self._fin = fin
        self._fout = fout

    @property
    def name(self):
        return SSHV1

    def getargs(self, args):
        data = {}
        keys = args.split()
        for n in xrange(len(keys)):
            argline = self._fin.readline()[:-1]
            arg, l = argline.split()
            if arg not in keys:
                raise error.Abort(_("unexpected parameter %r") % arg)
            if arg == '*':
                star = {}
                for k in xrange(int(l)):
                    argline = self._fin.readline()[:-1]
                    arg, l = argline.split()
                    val = self._fin.read(int(l))
                    star[arg] = val
                data['*'] = star
            else:
                val = self._fin.read(int(l))
                data[arg] = val
        return [data[k] for k in keys]

    def forwardpayload(self, fpout):
        # We initially send an empty response. This tells the client it is
        # OK to start sending data. If a client sees any other response, it
        # interprets it as an error.
        _sshv1respondbytes(self._fout, b'')

        # The file is in the form:
        #
        # <chunk size>\n<chunk>
        # ...
        # 0\n
        count = int(self._fin.readline())
        while count:
            fpout.write(self._fin.read(count))
            count = int(self._fin.readline())

    @contextlib.contextmanager
    def mayberedirectstdio(self):
        yield None

    def client(self):
        client = encoding.environ.get('SSH_CLIENT', '').split(' ', 1)[0]
        return 'remote:ssh:' + client

class sshv2protocolhandler(sshv1protocolhandler):
    """Protocol handler for version 2 of the SSH protocol."""

def _runsshserver(ui, repo, fin, fout, ev):
    # This function operates like a state machine of sorts. The following
    # states are defined:
    #
    # protov1-serving
    #    Server is in protocol version 1 serving mode. Commands arrive on
    #    new lines. These commands are processed in this state, one command
    #    after the other.
    #
    # protov2-serving
    #    Server is in protocol version 2 serving mode.
    #
    # upgrade-initial
    #    The server is going to process an upgrade request.
    #
    # upgrade-v2-filter-legacy-handshake
    #    The protocol is being upgraded to version 2. The server is expecting
    #    the legacy handshake from version 1.
    #
    # upgrade-v2-finish
    #    The upgrade to version 2 of the protocol is imminent.
    #
    # shutdown
    #    The server is shutting down, possibly in reaction to a client event.
    #
    # And here are their transitions:
    #
    # protov1-serving -> shutdown
    #    When server receives an empty request or encounters another
    #    error.
    #
    # protov1-serving -> upgrade-initial
    #    An upgrade request line was seen.
    #
    # upgrade-initial -> upgrade-v2-filter-legacy-handshake
    #    Upgrade to version 2 in progress. Server is expecting to
    #    process a legacy handshake.
    #
    # upgrade-v2-filter-legacy-handshake -> shutdown
    #    Client did not fulfill upgrade handshake requirements.
    #
    # upgrade-v2-filter-legacy-handshake -> upgrade-v2-finish
    #    Client fulfilled version 2 upgrade requirements. Finishing that
    #    upgrade.
    #
    # upgrade-v2-finish -> protov2-serving
    #    Protocol upgrade to version 2 complete. Server can now speak protocol
    #    version 2.
    #
    # protov2-serving -> protov1-serving
    #    Ths happens by default since protocol version 2 is the same as
    #    version 1 except for the handshake.

    state = 'protov1-serving'
    proto = sshv1protocolhandler(ui, fin, fout)
    protoswitched = False

    while not ev.is_set():
        if state == 'protov1-serving':
            # Commands are issued on new lines.
            request = fin.readline()[:-1]

            # Empty lines signal to terminate the connection.
            if not request:
                state = 'shutdown'
                continue

            # It looks like a protocol upgrade request. Transition state to
            # handle it.
            if request.startswith(b'upgrade '):
                if protoswitched:
                    _sshv1respondooberror(fout, ui.ferr,
                                          b'cannot upgrade protocols multiple '
                                          b'times')
                    state = 'shutdown'
                    continue

                state = 'upgrade-initial'
                continue

            available = wireproto.commands.commandavailable(request, proto)

            # This command isn't available. Send an empty response and go
            # back to waiting for a new command.
            if not available:
                _sshv1respondbytes(fout, b'')
                continue

            rsp = wireproto.dispatch(repo, proto, request)

            if isinstance(rsp, bytes):
                _sshv1respondbytes(fout, rsp)
            elif isinstance(rsp, wireprototypes.bytesresponse):
                _sshv1respondbytes(fout, rsp.data)
            elif isinstance(rsp, wireprototypes.streamres):
                _sshv1respondstream(fout, rsp)
            elif isinstance(rsp, wireprototypes.streamreslegacy):
                _sshv1respondstream(fout, rsp)
            elif isinstance(rsp, wireprototypes.pushres):
                _sshv1respondbytes(fout, b'')
                _sshv1respondbytes(fout, b'%d' % rsp.res)
            elif isinstance(rsp, wireprototypes.pusherr):
                _sshv1respondbytes(fout, rsp.res)
            elif isinstance(rsp, wireprototypes.ooberror):
                _sshv1respondooberror(fout, ui.ferr, rsp.message)
            else:
                raise error.ProgrammingError('unhandled response type from '
                                             'wire protocol command: %s' % rsp)

        # For now, protocol version 2 serving just goes back to version 1.
        elif state == 'protov2-serving':
            state = 'protov1-serving'
            continue

        elif state == 'upgrade-initial':
            # We should never transition into this state if we've switched
            # protocols.
            assert not protoswitched
            assert proto.name == SSHV1

            # Expected: upgrade <token> <capabilities>
            # If we get something else, the request is malformed. It could be
            # from a future client that has altered the upgrade line content.
            # We treat this as an unknown command.
            try:
                token, caps = request.split(b' ')[1:]
            except ValueError:
                _sshv1respondbytes(fout, b'')
                state = 'protov1-serving'
                continue

            # Send empty response if we don't support upgrading protocols.
            if not ui.configbool('experimental', 'sshserver.support-v2'):
                _sshv1respondbytes(fout, b'')
                state = 'protov1-serving'
                continue

            try:
                caps = urlreq.parseqs(caps)
            except ValueError:
                _sshv1respondbytes(fout, b'')
                state = 'protov1-serving'
                continue

            # We don't see an upgrade request to protocol version 2. Ignore
            # the upgrade request.
            wantedprotos = caps.get(b'proto', [b''])[0]
            if SSHV2 not in wantedprotos:
                _sshv1respondbytes(fout, b'')
                state = 'protov1-serving'
                continue

            # It looks like we can honor this upgrade request to protocol 2.
            # Filter the rest of the handshake protocol request lines.
            state = 'upgrade-v2-filter-legacy-handshake'
            continue

        elif state == 'upgrade-v2-filter-legacy-handshake':
            # Client should have sent legacy handshake after an ``upgrade``
            # request. Expected lines:
            #
            #    hello
            #    between
            #    pairs 81
            #    0000...-0000...

            ok = True
            for line in (b'hello', b'between', b'pairs 81'):
                request = fin.readline()[:-1]

                if request != line:
                    _sshv1respondooberror(fout, ui.ferr,
                                          b'malformed handshake protocol: '
                                          b'missing %s' % line)
                    ok = False
                    state = 'shutdown'
                    break

            if not ok:
                continue

            request = fin.read(81)
            if request != b'%s-%s' % (b'0' * 40, b'0' * 40):
                _sshv1respondooberror(fout, ui.ferr,
                                      b'malformed handshake protocol: '
                                      b'missing between argument value')
                state = 'shutdown'
                continue

            state = 'upgrade-v2-finish'
            continue

        elif state == 'upgrade-v2-finish':
            # Send the upgrade response.
            fout.write(b'upgraded %s %s\n' % (token, SSHV2))
            servercaps = wireproto.capabilities(repo, proto)
            rsp = b'capabilities: %s' % servercaps.data
            fout.write(b'%d\n%s\n' % (len(rsp), rsp))
            fout.flush()

            proto = sshv2protocolhandler(ui, fin, fout)
            protoswitched = True

            state = 'protov2-serving'
            continue

        elif state == 'shutdown':
            break

        else:
            raise error.ProgrammingError('unhandled ssh server state: %s' %
                                         state)

class sshserver(object):
    def __init__(self, ui, repo, logfh=None):
        self._ui = ui
        self._repo = repo
        self._fin = ui.fin
        self._fout = ui.fout

        # Log write I/O to stdout and stderr if configured.
        if logfh:
            self._fout = util.makeloggingfileobject(
                logfh, self._fout, 'o', logdata=True)
            ui.ferr = util.makeloggingfileobject(
                logfh, ui.ferr, 'e', logdata=True)

        hook.redirect(True)
        ui.fout = repo.ui.fout = ui.ferr

        # Prevent insertion/deletion of CRs
        util.setbinary(self._fin)
        util.setbinary(self._fout)

    def serve_forever(self):
        self.serveuntil(threading.Event())
        sys.exit(0)

    def serveuntil(self, ev):
        """Serve until a threading.Event is set."""
        _runsshserver(self._ui, self._repo, self._fin, self._fout, ev)
