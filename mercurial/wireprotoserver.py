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
    wireprotoframing,
    wireprototypes,
)

stringio = util.stringio

urlerr = util.urlerr
urlreq = util.urlreq

HTTP_OK = 200

HGTYPE = 'application/mercurial-0.1'
HGTYPE2 = 'application/mercurial-0.2'
HGERRTYPE = 'application/hg-error'
FRAMINGTYPE = b'application/mercurial-exp-framing-0001'

HTTPV2 = wireprototypes.HTTPV2
SSHV1 = wireprototypes.SSHV1
SSHV2 = wireprototypes.SSHV2

def decodevaluefromheaders(req, headerprefix):
    """Decode a long value from multiple HTTP request headers.

    Returns the value as a bytes, not a str.
    """
    chunks = []
    i = 1
    while True:
        v = req.headers.get(b'%s-%d' % (headerprefix, i))
        if v is None:
            break
        chunks.append(pycompat.bytesurl(v))
        i += 1

    return ''.join(chunks)

class httpv1protocolhandler(wireprototypes.baseprotocolhandler):
    def __init__(self, req, ui, checkperm):
        self._req = req
        self._ui = ui
        self._checkperm = checkperm

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
        args = self._req.qsparams.asdictoflists()
        postlen = int(self._req.headers.get(b'X-HgArgs-Post', 0))
        if postlen:
            args.update(urlreq.parseqs(
                self._req.bodyfh.read(postlen), keep_blank_values=True))
            return args

        argvalue = decodevaluefromheaders(self._req, b'X-HgArg')
        args.update(urlreq.parseqs(argvalue, keep_blank_values=True))
        return args

    def forwardpayload(self, fp):
        # Existing clients *always* send Content-Length.
        length = int(self._req.headers[b'Content-Length'])

        # If httppostargs is used, we need to read Content-Length
        # minus the amount that was consumed by args.
        length -= int(self._req.headers.get(b'X-HgArgs-Post', 0))
        for s in util.filechunkiter(self._req.bodyfh, limit=length):
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
            self._req.urlscheme,
            urlreq.quote(self._req.remotehost or ''),
            urlreq.quote(self._req.remoteuser or ''))

    def addcapabilities(self, repo, caps):
        caps.append(b'batch')

        caps.append('httpheader=%d' %
                    repo.ui.configint('server', 'maxhttpheaderlen'))
        if repo.ui.configbool('experimental', 'httppostargs'):
            caps.append('httppostargs')

        # FUTURE advertise 0.2rx once support is implemented
        # FUTURE advertise minrx and mintx after consulting config option
        caps.append('httpmediatype=0.1rx,0.1tx,0.2tx')

        compengines = wireproto.supportedcompengines(repo.ui, util.SERVERROLE)
        if compengines:
            comptypes = ','.join(urlreq.quote(e.wireprotosupport().name)
                                 for e in compengines)
            caps.append('compression=%s' % comptypes)

        return caps

    def checkperm(self, perm):
        return self._checkperm(perm)

# This method exists mostly so that extensions like remotefilelog can
# disable a kludgey legacy method only over http. As of early 2018,
# there are no other known users, so with any luck we can discard this
# hook if remotefilelog becomes a first-party extension.
def iscmd(cmd):
    return cmd in wireproto.commands

def handlewsgirequest(rctx, req, res, checkperm):
    """Possibly process a wire protocol request.

    If the current request is a wire protocol request, the request is
    processed by this function.

    ``req`` is a ``parsedrequest`` instance.
    ``res`` is a ``wsgiresponse`` instance.

    Returns a bool indicating if the request was serviced. If set, the caller
    should stop processing the request, as a response has already been issued.
    """
    # Avoid cycle involving hg module.
    from .hgweb import common as hgwebcommon

    repo = rctx.repo

    # HTTP version 1 wire protocol requests are denoted by a "cmd" query
    # string parameter. If it isn't present, this isn't a wire protocol
    # request.
    if 'cmd' not in req.qsparams:
        return False

    cmd = req.qsparams['cmd']

    # The "cmd" request parameter is used by both the wire protocol and hgweb.
    # While not all wire protocol commands are available for all transports,
    # if we see a "cmd" value that resembles a known wire protocol command, we
    # route it to a protocol handler. This is better than routing possible
    # wire protocol requests to hgweb because it prevents hgweb from using
    # known wire protocol commands and it is less confusing for machine
    # clients.
    if not iscmd(cmd):
        return False

    # The "cmd" query string argument is only valid on the root path of the
    # repo. e.g. ``/?cmd=foo``, ``/repo?cmd=foo``. URL paths within the repo
    # like ``/blah?cmd=foo`` are not allowed. So don't recognize the request
    # in this case. We send an HTTP 404 for backwards compatibility reasons.
    if req.dispatchpath:
        res.status = hgwebcommon.statusmessage(404)
        res.headers['Content-Type'] = HGTYPE
        # TODO This is not a good response to issue for this request. This
        # is mostly for BC for now.
        res.setbodybytes('0\n%s\n' % b'Not Found')
        return True

    proto = httpv1protocolhandler(req, repo.ui,
                                  lambda perm: checkperm(rctx, req, perm))

    # The permissions checker should be the only thing that can raise an
    # ErrorResponse. It is kind of a layer violation to catch an hgweb
    # exception here. So consider refactoring into a exception type that
    # is associated with the wire protocol.
    try:
        _callhttp(repo, req, res, proto, cmd)
    except hgwebcommon.ErrorResponse as e:
        for k, v in e.headers:
            res.headers[k] = v
        res.status = hgwebcommon.statusmessage(e.code, pycompat.bytestr(e))
        # TODO This response body assumes the failed command was
        # "unbundle." That assumption is not always valid.
        res.setbodybytes('0\n%s\n' % pycompat.bytestr(e))

    return True

def handlewsgiapirequest(rctx, req, res, checkperm):
    """Handle requests to /api/*."""
    assert req.dispatchparts[0] == b'api'

    repo = rctx.repo

    # This whole URL space is experimental for now. But we want to
    # reserve the URL space. So, 404 all URLs if the feature isn't enabled.
    if not repo.ui.configbool('experimental', 'web.apiserver'):
        res.status = b'404 Not Found'
        res.headers[b'Content-Type'] = b'text/plain'
        res.setbodybytes(_('Experimental API server endpoint not enabled'))
        return

    # The URL space is /api/<protocol>/*. The structure of URLs under varies
    # by <protocol>.

    # Registered APIs are made available via config options of the name of
    # the protocol.
    availableapis = set()
    for k, v in API_HANDLERS.items():
        section, option = v['config']
        if repo.ui.configbool(section, option):
            availableapis.add(k)

    # Requests to /api/ list available APIs.
    if req.dispatchparts == [b'api']:
        res.status = b'200 OK'
        res.headers[b'Content-Type'] = b'text/plain'
        lines = [_('APIs can be accessed at /api/<name>, where <name> can be '
                   'one of the following:\n')]
        if availableapis:
            lines.extend(sorted(availableapis))
        else:
            lines.append(_('(no available APIs)\n'))
        res.setbodybytes(b'\n'.join(lines))
        return

    proto = req.dispatchparts[1]

    if proto not in API_HANDLERS:
        res.status = b'404 Not Found'
        res.headers[b'Content-Type'] = b'text/plain'
        res.setbodybytes(_('Unknown API: %s\nKnown APIs: %s') % (
            proto, b', '.join(sorted(availableapis))))
        return

    if proto not in availableapis:
        res.status = b'404 Not Found'
        res.headers[b'Content-Type'] = b'text/plain'
        res.setbodybytes(_('API %s not enabled\n') % proto)
        return

    API_HANDLERS[proto]['handler'](rctx, req, res, checkperm,
                                   req.dispatchparts[2:])

def _handlehttpv2request(rctx, req, res, checkperm, urlparts):
    from .hgweb import common as hgwebcommon

    # URL space looks like: <permissions>/<command>, where <permission> can
    # be ``ro`` or ``rw`` to signal read-only or read-write, respectively.

    # Root URL does nothing meaningful... yet.
    if not urlparts:
        res.status = b'200 OK'
        res.headers[b'Content-Type'] = b'text/plain'
        res.setbodybytes(_('HTTP version 2 API handler'))
        return

    if len(urlparts) == 1:
        res.status = b'404 Not Found'
        res.headers[b'Content-Type'] = b'text/plain'
        res.setbodybytes(_('do not know how to process %s\n') %
                         req.dispatchpath)
        return

    permission, command = urlparts[0:2]

    if permission not in (b'ro', b'rw'):
        res.status = b'404 Not Found'
        res.headers[b'Content-Type'] = b'text/plain'
        res.setbodybytes(_('unknown permission: %s') % permission)
        return

    if req.method != 'POST':
        res.status = b'405 Method Not Allowed'
        res.headers[b'Allow'] = b'POST'
        res.setbodybytes(_('commands require POST requests'))
        return

    # At some point we'll want to use our own API instead of recycling the
    # behavior of version 1 of the wire protocol...
    # TODO return reasonable responses - not responses that overload the
    # HTTP status line message for error reporting.
    try:
        checkperm(rctx, req, 'pull' if permission == b'ro' else 'push')
    except hgwebcommon.ErrorResponse as e:
        res.status = hgwebcommon.statusmessage(e.code, pycompat.bytestr(e))
        for k, v in e.headers:
            res.headers[k] = v
        res.setbodybytes('permission denied')
        return

    # We have a special endpoint to reflect the request back at the client.
    if command == b'debugreflect':
        _processhttpv2reflectrequest(rctx.repo.ui, rctx.repo, req, res)
        return

    if command not in wireproto.commands:
        res.status = b'404 Not Found'
        res.headers[b'Content-Type'] = b'text/plain'
        res.setbodybytes(_('unknown wire protocol command: %s\n') % command)
        return

    repo = rctx.repo
    ui = repo.ui

    proto = httpv2protocolhandler(req, ui)

    if not wireproto.commands.commandavailable(command, proto):
        res.status = b'404 Not Found'
        res.headers[b'Content-Type'] = b'text/plain'
        res.setbodybytes(_('invalid wire protocol command: %s') % command)
        return

    if req.headers.get(b'Accept') != FRAMINGTYPE:
        res.status = b'406 Not Acceptable'
        res.headers[b'Content-Type'] = b'text/plain'
        res.setbodybytes(_('client MUST specify Accept header with value: %s\n')
                           % FRAMINGTYPE)
        return

    if req.headers.get(b'Content-Type') != FRAMINGTYPE:
        res.status = b'415 Unsupported Media Type'
        # TODO we should send a response with appropriate media type,
        # since client does Accept it.
        res.headers[b'Content-Type'] = b'text/plain'
        res.setbodybytes(_('client MUST send Content-Type header with '
                           'value: %s\n') % FRAMINGTYPE)
        return

    _processhttpv2request(ui, repo, req, res, permission, command, proto)

def _processhttpv2reflectrequest(ui, repo, req, res):
    """Reads unified frame protocol request and dumps out state to client.

    This special endpoint can be used to help debug the wire protocol.

    Instead of routing the request through the normal dispatch mechanism,
    we instead read all frames, decode them, and feed them into our state
    tracker. We then dump the log of all that activity back out to the
    client.
    """
    import json

    # Reflection APIs have a history of being abused, accidentally disclosing
    # sensitive data, etc. So we have a config knob.
    if not ui.configbool('experimental', 'web.api.debugreflect'):
        res.status = b'404 Not Found'
        res.headers[b'Content-Type'] = b'text/plain'
        res.setbodybytes(_('debugreflect service not available'))
        return

    # We assume we have a unified framing protocol request body.

    reactor = wireprotoframing.serverreactor()
    states = []

    while True:
        frame = wireprotoframing.readframe(req.bodyfh)

        if not frame:
            states.append(b'received: <no frame>')
            break

        frametype, frameflags, payload = frame
        states.append(b'received: %d %d %s' % (frametype, frameflags, payload))

        action, meta = reactor.onframerecv(frametype, frameflags, payload)
        states.append(json.dumps((action, meta), sort_keys=True,
                                 separators=(', ', ': ')))

    res.status = b'200 OK'
    res.headers[b'Content-Type'] = b'text/plain'
    res.setbodybytes(b'\n'.join(states))

def _processhttpv2request(ui, repo, req, res, authedperm, reqcommand, proto):
    """Post-validation handler for HTTPv2 requests.

    Called when the HTTP request contains unified frame-based protocol
    frames for evaluation.
    """
    reactor = wireprotoframing.serverreactor()
    seencommand = False

    while True:
        frame = wireprotoframing.readframe(req.bodyfh)
        if not frame:
            break

        action, meta = reactor.onframerecv(*frame)

        if action == 'wantframe':
            # Need more data before we can do anything.
            continue
        elif action == 'runcommand':
            # We currently only support running a single command per
            # HTTP request.
            if seencommand:
                # TODO define proper error mechanism.
                res.status = b'200 OK'
                res.headers[b'Content-Type'] = b'text/plain'
                res.setbodybytes(_('support for multiple commands per request '
                                   'not yet implemented'))
                return

            _httpv2runcommand(ui, repo, req, res, authedperm, reqcommand,
                              reactor, meta)

        elif action == 'error':
            # TODO define proper error mechanism.
            res.status = b'200 OK'
            res.headers[b'Content-Type'] = b'text/plain'
            res.setbodybytes(meta['message'] + b'\n')
            return
        else:
            raise error.ProgrammingError(
                'unhandled action from frame processor: %s' % action)

def _httpv2runcommand(ui, repo, req, res, authedperm, reqcommand, reactor,
                      command):
    """Dispatch a wire protocol command made from HTTPv2 requests.

    The authenticated permission (``authedperm``) along with the original
    command from the URL (``reqcommand``) are passed in.
    """
    # We already validated that the session has permissions to perform the
    # actions in ``authedperm``. In the unified frame protocol, the canonical
    # command to run is expressed in a frame. However, the URL also requested
    # to run a specific command. We need to be careful that the command we
    # run doesn't have permissions requirements greater than what was granted
    # by ``authedperm``.
    #
    # For now, this is no big deal, as we only allow a single command per
    # request and that command must match the command in the URL. But when
    # things change, we need to watch out...
    if reqcommand != command['command']:
        # TODO define proper error mechanism
        res.status = b'200 OK'
        res.headers[b'Content-Type'] = b'text/plain'
        res.setbodybytes(_('command in frame must match command in URL'))
        return

    # TODO once we get rid of the command==URL restriction, we'll need to
    # revalidate command validity and auth here. checkperm,
    # wireproto.commands.commandavailable(), etc.

    proto = httpv2protocolhandler(req, ui, args=command['args'])
    assert wireproto.commands.commandavailable(command['command'], proto)
    wirecommand = wireproto.commands[command['command']]

    assert authedperm in (b'ro', b'rw')
    assert wirecommand.permission in ('push', 'pull')

    # We already checked this as part of the URL==command check, but
    # permissions are important, so do it again.
    if authedperm == b'ro':
        assert wirecommand.permission == 'pull'
    elif authedperm == b'rw':
        # We are allowed to access read-only commands under the rw URL.
        assert wirecommand.permission in ('push', 'pull')

    rsp = wireproto.dispatch(repo, proto, command['command'])

    res.status = b'200 OK'
    res.headers[b'Content-Type'] = FRAMINGTYPE

    if isinstance(rsp, wireprototypes.bytesresponse):
        action, meta = reactor.onbytesresponseready(rsp.data)
    else:
        action, meta = reactor.onapplicationerror(
            _('unhandled response type from wire proto command'))

    if action == 'sendframes':
        res.setbodygen(meta['framegen'])
    else:
        raise error.ProgrammingError('unhandled event from reactor: %s' %
                                     action)

# Maps API name to metadata so custom API can be registered.
API_HANDLERS = {
    HTTPV2: {
        'config': ('experimental', 'web.api.http-v2'),
        'handler': _handlehttpv2request,
    },
}

class httpv2protocolhandler(wireprototypes.baseprotocolhandler):
    def __init__(self, req, ui, args=None):
        self._req = req
        self._ui = ui
        self._args = args

    @property
    def name(self):
        return HTTPV2

    def getargs(self, args):
        data = {}
        for k in args.split():
            if k == '*':
                raise NotImplementedError('do not support * args')
            else:
                data[k] = self._args[k]

        return [data[k] for k in args.split()]

    def forwardpayload(self, fp):
        raise NotImplementedError

    @contextlib.contextmanager
    def mayberedirectstdio(self):
        raise NotImplementedError

    def client(self):
        raise NotImplementedError

    def addcapabilities(self, repo, caps):
        return caps

    def checkperm(self, perm):
        raise NotImplementedError

def _httpresponsetype(ui, req, prefer_uncompressed):
    """Determine the appropriate response type and compression settings.

    Returns a tuple of (mediatype, compengine, engineopts).
    """
    # Determine the response media type and compression engine based
    # on the request parameters.
    protocaps = decodevaluefromheaders(req, 'X-HgProto').split(' ')

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

def _callhttp(repo, req, res, proto, cmd):
    # Avoid cycle involving hg module.
    from .hgweb import common as hgwebcommon

    def genversion2(gen, engine, engineopts):
        # application/mercurial-0.2 always sends a payload header
        # identifying the compression engine.
        name = engine.wireprotosupport().name
        assert 0 < len(name) < 256
        yield struct.pack('B', len(name))
        yield name

        for chunk in gen:
            yield chunk

    def setresponse(code, contenttype, bodybytes=None, bodygen=None):
        if code == HTTP_OK:
            res.status = '200 Script output follows'
        else:
            res.status = hgwebcommon.statusmessage(code)

        res.headers['Content-Type'] = contenttype

        if bodybytes is not None:
            res.setbodybytes(bodybytes)
        if bodygen is not None:
            res.setbodygen(bodygen)

    if not wireproto.commands.commandavailable(cmd, proto):
        setresponse(HTTP_OK, HGERRTYPE,
                    _('requested wire protocol command is not available over '
                      'HTTP'))
        return

    proto.checkperm(wireproto.commands[cmd].permission)

    rsp = wireproto.dispatch(repo, proto, cmd)

    if isinstance(rsp, bytes):
        setresponse(HTTP_OK, HGTYPE, bodybytes=rsp)
    elif isinstance(rsp, wireprototypes.bytesresponse):
        setresponse(HTTP_OK, HGTYPE, bodybytes=rsp.data)
    elif isinstance(rsp, wireprototypes.streamreslegacy):
        setresponse(HTTP_OK, HGTYPE, bodygen=rsp.gen)
    elif isinstance(rsp, wireprototypes.streamres):
        gen = rsp.gen

        # This code for compression should not be streamres specific. It
        # is here because we only compress streamres at the moment.
        mediatype, engine, engineopts = _httpresponsetype(
            repo.ui, req, rsp.prefer_uncompressed)
        gen = engine.compressstream(gen, engineopts)

        if mediatype == HGTYPE2:
            gen = genversion2(gen, engine, engineopts)

        setresponse(HTTP_OK, mediatype, bodygen=gen)
    elif isinstance(rsp, wireprototypes.pushres):
        rsp = '%d\n%s' % (rsp.res, rsp.output)
        setresponse(HTTP_OK, HGTYPE, bodybytes=rsp)
    elif isinstance(rsp, wireprototypes.pusherr):
        rsp = '0\n%s\n' % rsp.res
        res.drain = True
        setresponse(HTTP_OK, HGTYPE, bodybytes=rsp)
    elif isinstance(rsp, wireprototypes.ooberror):
        setresponse(HTTP_OK, HGERRTYPE, bodybytes=rsp.message)
    else:
        raise error.ProgrammingError('hgweb.protocol internal failure', rsp)

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
        return wireprototypes.SSHV1

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

    def addcapabilities(self, repo, caps):
        caps.append(b'batch')
        return caps

    def checkperm(self, perm):
        pass

class sshv2protocolhandler(sshv1protocolhandler):
    """Protocol handler for version 2 of the SSH protocol."""

    @property
    def name(self):
        return wireprototypes.SSHV2

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
            assert proto.name == wireprototypes.SSHV1

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
