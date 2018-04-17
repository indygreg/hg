# Copyright 21 May 2005 - (c) 2005 Jake Edge <jake@edge2.net>
# Copyright 2005-2007 Matt Mackall <mpm@selenic.com>
#
# This software may be used and distributed according to the terms of the
# GNU General Public License version 2 or any later version.

from __future__ import absolute_import

import contextlib

from .i18n import _
from .thirdparty import (
    cbor,
)
from .thirdparty.zope import (
    interface as zi,
)
from . import (
    encoding,
    error,
    pycompat,
    streamclone,
    util,
    wireproto,
    wireprotoframing,
    wireprototypes,
)

FRAMINGTYPE = b'application/mercurial-exp-framing-0005'

HTTP_WIREPROTO_V2 = wireprototypes.HTTP_WIREPROTO_V2

def handlehttpv2request(rctx, req, res, checkperm, urlparts):
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

    # Extra commands that we handle that aren't really wire protocol
    # commands. Think extra hard before making this hackery available to
    # extension.
    extracommands = {'multirequest'}

    if command not in wireproto.commandsv2 and command not in extracommands:
        res.status = b'404 Not Found'
        res.headers[b'Content-Type'] = b'text/plain'
        res.setbodybytes(_('unknown wire protocol command: %s\n') % command)
        return

    repo = rctx.repo
    ui = repo.ui

    proto = httpv2protocolhandler(req, ui)

    if (not wireproto.commandsv2.commandavailable(command, proto)
        and command not in extracommands):
        res.status = b'404 Not Found'
        res.headers[b'Content-Type'] = b'text/plain'
        res.setbodybytes(_('invalid wire protocol command: %s') % command)
        return

    # TODO consider cases where proxies may add additional Accept headers.
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

        states.append(b'received: %d %d %d %s' % (frame.typeid, frame.flags,
                                                  frame.requestid,
                                                  frame.payload))

        action, meta = reactor.onframerecv(frame)
        states.append(json.dumps((action, meta), sort_keys=True,
                                 separators=(', ', ': ')))

    action, meta = reactor.oninputeof()
    meta['action'] = action
    states.append(json.dumps(meta, sort_keys=True, separators=(', ',': ')))

    res.status = b'200 OK'
    res.headers[b'Content-Type'] = b'text/plain'
    res.setbodybytes(b'\n'.join(states))

def _processhttpv2request(ui, repo, req, res, authedperm, reqcommand, proto):
    """Post-validation handler for HTTPv2 requests.

    Called when the HTTP request contains unified frame-based protocol
    frames for evaluation.
    """
    # TODO Some HTTP clients are full duplex and can receive data before
    # the entire request is transmitted. Figure out a way to indicate support
    # for that so we can opt into full duplex mode.
    reactor = wireprotoframing.serverreactor(deferoutput=True)
    seencommand = False

    outstream = reactor.makeoutputstream()

    while True:
        frame = wireprotoframing.readframe(req.bodyfh)
        if not frame:
            break

        action, meta = reactor.onframerecv(frame)

        if action == 'wantframe':
            # Need more data before we can do anything.
            continue
        elif action == 'runcommand':
            sentoutput = _httpv2runcommand(ui, repo, req, res, authedperm,
                                           reqcommand, reactor, outstream,
                                           meta, issubsequent=seencommand)

            if sentoutput:
                return

            seencommand = True

        elif action == 'error':
            # TODO define proper error mechanism.
            res.status = b'200 OK'
            res.headers[b'Content-Type'] = b'text/plain'
            res.setbodybytes(meta['message'] + b'\n')
            return
        else:
            raise error.ProgrammingError(
                'unhandled action from frame processor: %s' % action)

    action, meta = reactor.oninputeof()
    if action == 'sendframes':
        # We assume we haven't started sending the response yet. If we're
        # wrong, the response type will raise an exception.
        res.status = b'200 OK'
        res.headers[b'Content-Type'] = FRAMINGTYPE
        res.setbodygen(meta['framegen'])
    elif action == 'noop':
        pass
    else:
        raise error.ProgrammingError('unhandled action from frame processor: %s'
                                     % action)

def _httpv2runcommand(ui, repo, req, res, authedperm, reqcommand, reactor,
                      outstream, command, issubsequent):
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
    # Our rule for this is we only allow one command per HTTP request and
    # that command must match the command in the URL. However, we make
    # an exception for the ``multirequest`` URL. This URL is allowed to
    # execute multiple commands. We double check permissions of each command
    # as it is invoked to ensure there is no privilege escalation.
    # TODO consider allowing multiple commands to regular command URLs
    # iff each command is the same.

    proto = httpv2protocolhandler(req, ui, args=command['args'])

    if reqcommand == b'multirequest':
        if not wireproto.commandsv2.commandavailable(command['command'], proto):
            # TODO proper error mechanism
            res.status = b'200 OK'
            res.headers[b'Content-Type'] = b'text/plain'
            res.setbodybytes(_('wire protocol command not available: %s') %
                             command['command'])
            return True

        # TODO don't use assert here, since it may be elided by -O.
        assert authedperm in (b'ro', b'rw')
        wirecommand = wireproto.commandsv2[command['command']]
        assert wirecommand.permission in ('push', 'pull')

        if authedperm == b'ro' and wirecommand.permission != 'pull':
            # TODO proper error mechanism
            res.status = b'403 Forbidden'
            res.headers[b'Content-Type'] = b'text/plain'
            res.setbodybytes(_('insufficient permissions to execute '
                               'command: %s') % command['command'])
            return True

        # TODO should we also call checkperm() here? Maybe not if we're going
        # to overhaul that API. The granted scope from the URL check should
        # be good enough.

    else:
        # Don't allow multiple commands outside of ``multirequest`` URL.
        if issubsequent:
            # TODO proper error mechanism
            res.status = b'200 OK'
            res.headers[b'Content-Type'] = b'text/plain'
            res.setbodybytes(_('multiple commands cannot be issued to this '
                               'URL'))
            return True

        if reqcommand != command['command']:
            # TODO define proper error mechanism
            res.status = b'200 OK'
            res.headers[b'Content-Type'] = b'text/plain'
            res.setbodybytes(_('command in frame must match command in URL'))
            return True

    rsp = wireproto.dispatch(repo, proto, command['command'])

    res.status = b'200 OK'
    res.headers[b'Content-Type'] = FRAMINGTYPE

    if isinstance(rsp, wireprototypes.cborresponse):
        encoded = cbor.dumps(rsp.value, canonical=True)
        action, meta = reactor.oncommandresponseready(outstream,
                                                      command['requestid'],
                                                      encoded)
    elif isinstance(rsp, wireprototypes.v2streamingresponse):
        action, meta = reactor.oncommandresponsereadygen(outstream,
                                                         command['requestid'],
                                                         rsp.gen)
    elif isinstance(rsp, wireprototypes.v2errorresponse):
        action, meta = reactor.oncommanderror(outstream,
                                              command['requestid'],
                                              rsp.message,
                                              rsp.args)
    else:
        action, meta = reactor.onservererror(
            _('unhandled response type from wire proto command'))

    if action == 'sendframes':
        res.setbodygen(meta['framegen'])
        return True
    elif action == 'noop':
        return False
    else:
        raise error.ProgrammingError('unhandled event from reactor: %s' %
                                     action)

@zi.implementer(wireprototypes.baseprotocolhandler)
class httpv2protocolhandler(object):
    def __init__(self, req, ui, args=None):
        self._req = req
        self._ui = ui
        self._args = args

    @property
    def name(self):
        return HTTP_WIREPROTO_V2

    def getargs(self, args):
        data = {}
        for k, typ in args.items():
            if k == '*':
                raise NotImplementedError('do not support * args')
            elif k in self._args:
                # TODO consider validating value types.
                data[k] = self._args[k]

        return data

    def getprotocaps(self):
        # Protocol capabilities are currently not implemented for HTTP V2.
        return set()

    def getpayload(self):
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

def httpv2apidescriptor(req, repo):
    proto = httpv2protocolhandler(req, repo.ui)

    return _capabilitiesv2(repo, proto)

def _capabilitiesv2(repo, proto):
    """Obtain the set of capabilities for version 2 transports.

    These capabilities are distinct from the capabilities for version 1
    transports.
    """
    compression = []
    for engine in wireproto.supportedcompengines(repo.ui, util.SERVERROLE):
        compression.append({
            b'name': engine.wireprotosupport().name,
        })

    caps = {
        'commands': {},
        'compression': compression,
        'framingmediatypes': [FRAMINGTYPE],
    }

    for command, entry in wireproto.commandsv2.items():
        caps['commands'][command] = {
            'args': entry.args,
            'permissions': [entry.permission],
        }

    if streamclone.allowservergeneration(repo):
        caps['rawrepoformats'] = sorted(repo.requirements &
                                        repo.supportedformats)

    return proto.addcapabilities(repo, caps)

def wireprotocommand(name, args=None, permission='push'):
    """Decorator to declare a wire protocol command.

    ``name`` is the name of the wire protocol command being provided.

    ``args`` is a dict of argument names to example values.

    ``permission`` defines the permission type needed to run this command.
    Can be ``push`` or ``pull``. These roughly map to read-write and read-only,
    respectively. Default is to assume command requires ``push`` permissions
    because otherwise commands not declaring their permissions could modify
    a repository that is supposed to be read-only.
    """
    transports = {k for k, v in wireprototypes.TRANSPORTS.items()
                  if v['version'] == 2}

    if permission not in ('push', 'pull'):
        raise error.ProgrammingError('invalid wire protocol permission; '
                                     'got %s; expected "push" or "pull"' %
                                     permission)

    if args is None:
        args = {}

    if not isinstance(args, dict):
        raise error.ProgrammingError('arguments for version 2 commands '
                                     'must be declared as dicts')

    def register(func):
        if name in wireproto.commandsv2:
            raise error.ProgrammingError('%s command already registered '
                                         'for version 2' % name)

        wireproto.commandsv2[name] = wireproto.commandentry(
            func, args=args, transports=transports, permission=permission)

        return func

    return register

@wireprotocommand('branchmap', permission='pull')
def branchmapv2(repo, proto):
    branchmap = {encoding.fromlocal(k): v
                 for k, v in repo.branchmap().iteritems()}

    return wireprototypes.cborresponse(branchmap)

@wireprotocommand('capabilities', permission='pull')
def capabilitiesv2(repo, proto):
    caps = _capabilitiesv2(repo, proto)

    return wireprototypes.cborresponse(caps)

@wireprotocommand('heads',
                  args={
                      'publiconly': False,
                  },
                  permission='pull')
def headsv2(repo, proto, publiconly=False):
    if publiconly:
        repo = repo.filtered('immutable')

    return wireprototypes.cborresponse(repo.heads())

@wireprotocommand('known',
                  args={
                      'nodes': [b'deadbeef'],
                  },
                  permission='pull')
def knownv2(repo, proto, nodes=None):
    nodes = nodes or []
    result = b''.join(b'1' if n else b'0' for n in repo.known(nodes))
    return wireprototypes.cborresponse(result)

@wireprotocommand('listkeys',
                  args={
                      'namespace': b'ns',
                  },
                  permission='pull')
def listkeysv2(repo, proto, namespace=None):
    keys = repo.listkeys(encoding.tolocal(namespace))
    keys = {encoding.fromlocal(k): encoding.fromlocal(v)
            for k, v in keys.iteritems()}

    return wireprototypes.cborresponse(keys)

@wireprotocommand('lookup',
                  args={
                      'key': b'foo',
                  },
                  permission='pull')
def lookupv2(repo, proto, key):
    key = encoding.tolocal(key)

    # TODO handle exception.
    node = repo.lookup(key)

    return wireprototypes.cborresponse(node)

@wireprotocommand('pushkey',
                  args={
                      'namespace': b'ns',
                      'key': b'key',
                      'old': b'old',
                      'new': b'new',
                  },
                  permission='push')
def pushkeyv2(repo, proto, namespace, key, old, new):
    # TODO handle ui output redirection
    r = repo.pushkey(encoding.tolocal(namespace),
                     encoding.tolocal(key),
                     encoding.tolocal(old),
                     encoding.tolocal(new))

    return wireprototypes.cborresponse(r)
