# Copyright 21 May 2005 - (c) 2005 Jake Edge <jake@edge2.net>
# Copyright 2005-2007 Matt Mackall <mpm@selenic.com>
#
# This software may be used and distributed according to the terms of the
# GNU General Public License version 2 or any later version.

from __future__ import absolute_import

import contextlib

from .i18n import _
from .node import (
    hex,
    nullid,
    nullrev,
)
from . import (
    changegroup,
    dagop,
    discovery,
    encoding,
    error,
    pycompat,
    streamclone,
    util,
    wireprotoframing,
    wireprototypes,
)
from .utils import (
    interfaceutil,
)

FRAMINGTYPE = b'application/mercurial-exp-framing-0005'

HTTP_WIREPROTO_V2 = wireprototypes.HTTP_WIREPROTO_V2

COMMANDS = wireprototypes.commanddict()

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

    if command not in COMMANDS and command not in extracommands:
        res.status = b'404 Not Found'
        res.headers[b'Content-Type'] = b'text/plain'
        res.setbodybytes(_('unknown wire protocol command: %s\n') % command)
        return

    repo = rctx.repo
    ui = repo.ui

    proto = httpv2protocolhandler(req, ui)

    if (not COMMANDS.commandavailable(command, proto)
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
        if not COMMANDS.commandavailable(command['command'], proto):
            # TODO proper error mechanism
            res.status = b'200 OK'
            res.headers[b'Content-Type'] = b'text/plain'
            res.setbodybytes(_('wire protocol command not available: %s') %
                             command['command'])
            return True

        # TODO don't use assert here, since it may be elided by -O.
        assert authedperm in (b'ro', b'rw')
        wirecommand = COMMANDS[command['command']]
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

    res.status = b'200 OK'
    res.headers[b'Content-Type'] = FRAMINGTYPE

    try:
        objs = dispatch(repo, proto, command['command'])

        action, meta = reactor.oncommandresponsereadyobjects(
            outstream, command['requestid'], objs)

    except error.WireprotoCommandError as e:
        action, meta = reactor.oncommanderror(
            outstream, command['requestid'], e.message, e.messageargs)

    except Exception as e:
        action, meta = reactor.onservererror(
            outstream, command['requestid'],
            _('exception when invoking command: %s') % e)

    if action == 'sendframes':
        res.setbodygen(meta['framegen'])
        return True
    elif action == 'noop':
        return False
    else:
        raise error.ProgrammingError('unhandled event from reactor: %s' %
                                     action)

def getdispatchrepo(repo, proto, command):
    return repo.filtered('served')

def dispatch(repo, proto, command):
    repo = getdispatchrepo(repo, proto, command)

    func, spec = COMMANDS[command]
    args = proto.getargs(spec)

    return func(repo, proto, **args)

@interfaceutil.implementer(wireprototypes.baseprotocolhandler)
class httpv2protocolhandler(object):
    def __init__(self, req, ui, args=None):
        self._req = req
        self._ui = ui
        self._args = args

    @property
    def name(self):
        return HTTP_WIREPROTO_V2

    def getargs(self, args):
        # First look for args that were passed but aren't registered on this
        # command.
        extra = set(self._args) - set(args)
        if extra:
            raise error.WireprotoCommandError(
                'unsupported argument to command: %s' %
                ', '.join(sorted(extra)))

        # And look for required arguments that are missing.
        missing = {a for a in args if args[a]['required']} - set(self._args)

        if missing:
            raise error.WireprotoCommandError(
                'missing required arguments: %s' % ', '.join(sorted(missing)))

        # Now derive the arguments to pass to the command, taking into
        # account the arguments specified by the client.
        data = {}
        for k, meta in sorted(args.items()):
            # This argument wasn't passed by the client.
            if k not in self._args:
                data[k] = meta['default']()
                continue

            v = self._args[k]

            # Sets may be expressed as lists. Silently normalize.
            if meta['type'] == 'set' and isinstance(v, list):
                v = set(v)

            # TODO consider more/stronger type validation.

            data[k] = v

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
    for engine in wireprototypes.supportedcompengines(repo.ui, util.SERVERROLE):
        compression.append({
            b'name': engine.wireprotosupport().name,
        })

    caps = {
        'commands': {},
        'compression': compression,
        'framingmediatypes': [FRAMINGTYPE],
    }

    # TODO expose available changesetdata fields.

    for command, entry in COMMANDS.items():
        args = {arg: meta['example'] for arg, meta in entry.args.items()}

        caps['commands'][command] = {
            'args': args,
            'permissions': [entry.permission],
        }

    if streamclone.allowservergeneration(repo):
        caps['rawrepoformats'] = sorted(repo.requirements &
                                        repo.supportedformats)

    return proto.addcapabilities(repo, caps)

def builddeltarequests(store, nodes, haveparents):
    """Build a series of revision delta requests against a backend store.

    Returns a list of revision numbers in the order they should be sent
    and a list of ``irevisiondeltarequest`` instances to be made against
    the backend store.
    """
    # We sort and send nodes in DAG order because this is optimal for
    # storage emission.
    # TODO we may want a better storage API here - one where we can throw
    # a list of nodes and delta preconditions over a figurative wall and
    # have the storage backend figure it out for us.
    revs = dagop.linearize({store.rev(n) for n in nodes}, store.parentrevs)

    requests = []
    seenrevs = set()

    for rev in revs:
        node = store.node(rev)
        parentnodes = store.parents(node)
        parentrevs = [store.rev(n) for n in parentnodes]
        deltabaserev = store.deltaparent(rev)
        deltabasenode = store.node(deltabaserev)

        # The choice of whether to send a fulltext revision or a delta and
        # what delta to send is governed by a few factors.
        #
        # To send a delta, we need to ensure the receiver is capable of
        # decoding it. And that requires the receiver to have the base
        # revision the delta is against.
        #
        # We can only guarantee the receiver has the base revision if
        # a) we've already sent the revision as part of this group
        # b) the receiver has indicated they already have the revision.
        # And the mechanism for "b" is the client indicating they have
        # parent revisions. So this means we can only send the delta if
        # it is sent before or it is against a delta and the receiver says
        # they have a parent.

        # We can send storage delta if it is against a revision we've sent
        # in this group.
        if deltabaserev != nullrev and deltabaserev in seenrevs:
            basenode = deltabasenode

        # We can send storage delta if it is against a parent revision and
        # the receiver indicates they have the parents.
        elif (deltabaserev != nullrev and deltabaserev in parentrevs
              and haveparents):
            basenode = deltabasenode

        # Otherwise the storage delta isn't appropriate. Fall back to
        # using another delta, if possible.

        # Use p1 if we've emitted it or receiver says they have it.
        elif parentrevs[0] != nullrev and (
            parentrevs[0] in seenrevs or haveparents):
            basenode = parentnodes[0]

        # Use p2 if we've emitted it or receiver says they have it.
        elif parentrevs[1] != nullrev and (
            parentrevs[1] in seenrevs or haveparents):
            basenode = parentnodes[1]

        # Nothing appropriate to delta against. Send the full revision.
        else:
            basenode = nullid

        requests.append(changegroup.revisiondeltarequest(
            node=node,
            p1node=parentnodes[0],
            p2node=parentnodes[1],
            # Receiver deals with linknode resolution.
            linknode=nullid,
            basenode=basenode,
        ))

        seenrevs.add(rev)

    return revs, requests

def wireprotocommand(name, args=None, permission='push'):
    """Decorator to declare a wire protocol command.

    ``name`` is the name of the wire protocol command being provided.

    ``args`` is a dict defining arguments accepted by the command. Keys are
    the argument name. Values are dicts with the following keys:

       ``type``
          The argument data type. Must be one of the following string
          literals: ``bytes``, ``int``, ``list``, ``dict``, ``set``,
          or ``bool``.

       ``default``
          A callable returning the default value for this argument. If not
          specified, ``None`` will be the default value.

       ``required``
          Bool indicating whether the argument is required.

       ``example``
          An example value for this argument.

    ``permission`` defines the permission type needed to run this command.
    Can be ``push`` or ``pull``. These roughly map to read-write and read-only,
    respectively. Default is to assume command requires ``push`` permissions
    because otherwise commands not declaring their permissions could modify
    a repository that is supposed to be read-only.

    Wire protocol commands are generators of objects to be serialized and
    sent to the client.

    If a command raises an uncaught exception, this will be translated into
    a command error.
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

    for arg, meta in args.items():
        if arg == '*':
            raise error.ProgrammingError('* argument name not allowed on '
                                         'version 2 commands')

        if not isinstance(meta, dict):
            raise error.ProgrammingError('arguments for version 2 commands '
                                         'must declare metadata as a dict')

        if 'type' not in meta:
            raise error.ProgrammingError('%s argument for command %s does not '
                                         'declare type field' % (arg, name))

        if meta['type'] not in ('bytes', 'int', 'list', 'dict', 'set', 'bool'):
            raise error.ProgrammingError('%s argument for command %s has '
                                         'illegal type: %s' % (arg, name,
                                                               meta['type']))

        if 'example' not in meta:
            raise error.ProgrammingError('%s argument for command %s does not '
                                         'declare example field' % (arg, name))

        if 'default' in meta and meta.get('required'):
            raise error.ProgrammingError('%s argument for command %s is marked '
                                         'as required but has a default value' %
                                         (arg, name))

        meta.setdefault('default', lambda: None)
        meta.setdefault('required', False)

    def register(func):
        if name in COMMANDS:
            raise error.ProgrammingError('%s command already registered '
                                         'for version 2' % name)

        COMMANDS[name] = wireprototypes.commandentry(
            func, args=args, transports=transports, permission=permission)

        return func

    return register

@wireprotocommand('branchmap', permission='pull')
def branchmapv2(repo, proto):
    yield {encoding.fromlocal(k): v
           for k, v in repo.branchmap().iteritems()}

@wireprotocommand('capabilities', permission='pull')
def capabilitiesv2(repo, proto):
    yield _capabilitiesv2(repo, proto)

@wireprotocommand(
    'changesetdata',
    args={
        'noderange': {
            'type': 'list',
            'example': [[b'0123456...'], [b'abcdef...']],
        },
        'nodes': {
            'type': 'list',
            'example': [b'0123456...'],
        },
        'fields': {
            'type': 'set',
            'default': set,
            'example': {b'parents', b'revision'},
        },
    },
    permission='pull')
def changesetdata(repo, proto, noderange, nodes, fields):
    # TODO look for unknown fields and abort when they can't be serviced.

    if noderange is None and nodes is None:
        raise error.WireprotoCommandError(
            'noderange or nodes must be defined')

    if noderange is not None:
        if len(noderange) != 2:
            raise error.WireprotoCommandError(
                'noderange must consist of 2 elements')

        if not noderange[1]:
            raise error.WireprotoCommandError(
                'heads in noderange request cannot be empty')

    cl = repo.changelog
    hasnode = cl.hasnode

    seen = set()
    outgoing = []

    if nodes is not None:
        outgoing.extend(n for n in nodes if hasnode(n))
        seen |= set(outgoing)

    if noderange is not None:
        if noderange[0]:
            common = [n for n in noderange[0] if hasnode(n)]
        else:
            common = [nullid]

        for n in discovery.outgoing(repo, common, noderange[1]).missing:
            if n not in seen:
                outgoing.append(n)
            # Don't need to add to seen here because this is the final
            # source of nodes and there should be no duplicates in this
            # list.

    seen.clear()
    publishing = repo.publishing()

    if outgoing:
        repo.hook('preoutgoing', throw=True, source='serve')

    yield {
        b'totalitems': len(outgoing),
    }

    # The phases of nodes already transferred to the client may have changed
    # since the client last requested data. We send phase-only records
    # for these revisions, if requested.
    if b'phase' in fields and noderange is not None:
        # TODO skip nodes whose phase will be reflected by a node in the
        # outgoing set. This is purely an optimization to reduce data
        # size.
        for node in noderange[0]:
            yield {
                b'node': node,
                b'phase': b'public' if publishing else repo[node].phasestr()
            }

    nodebookmarks = {}
    for mark, node in repo._bookmarks.items():
        nodebookmarks.setdefault(node, set()).add(mark)

    # It is already topologically sorted by revision number.
    for node in outgoing:
        d = {
            b'node': node,
        }

        if b'parents' in fields:
            d[b'parents'] = cl.parents(node)

        if b'phase' in fields:
            if publishing:
                d[b'phase'] = b'public'
            else:
                ctx = repo[node]
                d[b'phase'] = ctx.phasestr()

        if b'bookmarks' in fields and node in nodebookmarks:
            d[b'bookmarks'] = sorted(nodebookmarks[node])
            del nodebookmarks[node]

        revisiondata = None

        if b'revision' in fields:
            revisiondata = cl.revision(node, raw=True)
            d[b'revisionsize'] = len(revisiondata)

        # TODO make it possible for extensions to wrap a function or register
        # a handler to service custom fields.

        yield d

        if revisiondata is not None:
            yield revisiondata

    # If requested, send bookmarks from nodes that didn't have revision
    # data sent so receiver is aware of any bookmark updates.
    if b'bookmarks' in fields:
        for node, marks in sorted(nodebookmarks.iteritems()):
            yield {
                b'node': node,
                b'bookmarks': sorted(marks),
            }

class FileAccessError(Exception):
    """Represents an error accessing a specific file."""

    def __init__(self, path, msg, args):
        self.path = path
        self.msg = msg
        self.args = args

def getfilestore(repo, proto, path):
    """Obtain a file storage object for use with wire protocol.

    Exists as a standalone function so extensions can monkeypatch to add
    access control.
    """
    # This seems to work even if the file doesn't exist. So catch
    # "empty" files and return an error.
    fl = repo.file(path)

    if not len(fl):
        raise FileAccessError(path, 'unknown file: %s', (path,))

    return fl

@wireprotocommand(
    'filedata',
    args={
        'haveparents': {
            'type': 'bool',
            'default': lambda: False,
            'example': True,
        },
        'nodes': {
            'type': 'list',
            'required': True,
            'example': [b'0123456...'],
        },
        'fields': {
            'type': 'set',
            'default': set,
            'example': {b'parents', b'revision'},
        },
        'path': {
            'type': 'bytes',
            'required': True,
            'example': b'foo.txt',
        }
    },
    permission='pull')
def filedata(repo, proto, haveparents, nodes, fields, path):
    try:
        # Extensions may wish to access the protocol handler.
        store = getfilestore(repo, proto, path)
    except FileAccessError as e:
        raise error.WireprotoCommandError(e.msg, e.args)

    # Validate requested nodes.
    for node in nodes:
        try:
            store.rev(node)
        except error.LookupError:
            raise error.WireprotoCommandError('unknown file node: %s',
                                              (hex(node),))

    revs, requests = builddeltarequests(store, nodes, haveparents)

    yield {
        b'totalitems': len(revs),
    }

    if b'revision' in fields:
        deltas = store.emitrevisiondeltas(requests)
    else:
        deltas = None

    for rev in revs:
        node = store.node(rev)

        if deltas is not None:
            delta = next(deltas)
        else:
            delta = None

        d = {
            b'node': node,
        }

        if b'parents' in fields:
            d[b'parents'] = store.parents(node)

        if b'revision' in fields:
            assert delta is not None
            assert delta.flags == 0
            assert d[b'node'] == delta.node

            if delta.revision is not None:
                revisiondata = delta.revision
                d[b'revisionsize'] = len(revisiondata)
            else:
                d[b'deltabasenode'] = delta.basenode
                revisiondata = delta.delta
                d[b'deltasize'] = len(revisiondata)
        else:
            revisiondata = None

        yield d

        if revisiondata is not None:
            yield revisiondata

    if deltas is not None:
        try:
            next(deltas)
            raise error.ProgrammingError('should not have more deltas')
        except GeneratorExit:
            pass

@wireprotocommand(
    'heads',
    args={
        'publiconly': {
            'type': 'bool',
            'default': lambda: False,
            'example': False,
        },
    },
    permission='pull')
def headsv2(repo, proto, publiconly):
    if publiconly:
        repo = repo.filtered('immutable')

    yield repo.heads()

@wireprotocommand(
    'known',
    args={
        'nodes': {
            'type': 'list',
            'default': list,
            'example': [b'deadbeef'],
        },
    },
    permission='pull')
def knownv2(repo, proto, nodes):
    result = b''.join(b'1' if n else b'0' for n in repo.known(nodes))
    yield result

@wireprotocommand(
    'listkeys',
    args={
        'namespace': {
            'type': 'bytes',
            'required': True,
            'example': b'ns',
        },
    },
    permission='pull')
def listkeysv2(repo, proto, namespace):
    keys = repo.listkeys(encoding.tolocal(namespace))
    keys = {encoding.fromlocal(k): encoding.fromlocal(v)
            for k, v in keys.iteritems()}

    yield keys

@wireprotocommand(
    'lookup',
    args={
        'key': {
            'type': 'bytes',
            'required': True,
            'example': b'foo',
        },
    },
    permission='pull')
def lookupv2(repo, proto, key):
    key = encoding.tolocal(key)

    # TODO handle exception.
    node = repo.lookup(key)

    yield node

@wireprotocommand(
    'manifestdata',
    args={
        'nodes': {
            'type': 'list',
            'required': True,
            'example': [b'0123456...'],
        },
        'haveparents': {
            'type': 'bool',
            'default': lambda: False,
            'example': True,
        },
        'fields': {
            'type': 'set',
            'default': set,
            'example': {b'parents', b'revision'},
        },
        'tree': {
            'type': 'bytes',
            'required': True,
            'example': b'',
        },
    },
    permission='pull')
def manifestdata(repo, proto, haveparents, nodes, fields, tree):
    store = repo.manifestlog.getstorage(tree)

    # Validate the node is known and abort on unknown revisions.
    for node in nodes:
        try:
            store.rev(node)
        except error.LookupError:
            raise error.WireprotoCommandError(
                'unknown node: %s', (node,))

    revs, requests = builddeltarequests(store, nodes, haveparents)

    yield {
        b'totalitems': len(revs),
    }

    if b'revision' in fields:
        deltas = store.emitrevisiondeltas(requests)
    else:
        deltas = None

    for rev in revs:
        node = store.node(rev)

        if deltas is not None:
            delta = next(deltas)
        else:
            delta = None

        d = {
            b'node': node,
        }

        if b'parents' in fields:
            d[b'parents'] = store.parents(node)

        if b'revision' in fields:
            assert delta is not None
            assert delta.flags == 0
            assert d[b'node'] == delta.node

            if delta.revision is not None:
                revisiondata = delta.revision
                d[b'revisionsize'] = len(revisiondata)
            else:
                d[b'deltabasenode'] = delta.basenode
                revisiondata = delta.delta
                d[b'deltasize'] = len(revisiondata)
        else:
            revisiondata = None

        yield d

        if revisiondata is not None:
            yield revisiondata

    if deltas is not None:
        try:
            next(deltas)
            raise error.ProgrammingError('should not have more deltas')
        except GeneratorExit:
            pass

@wireprotocommand(
    'pushkey',
    args={
        'namespace': {
            'type': 'bytes',
            'required': True,
            'example': b'ns',
        },
        'key': {
            'type': 'bytes',
            'required': True,
            'example': b'key',
        },
        'old': {
            'type': 'bytes',
            'required': True,
            'example': b'old',
        },
        'new': {
            'type': 'bytes',
            'required': True,
            'example': 'new',
        },
    },
    permission='push')
def pushkeyv2(repo, proto, namespace, key, old, new):
    # TODO handle ui output redirection
    yield repo.pushkey(encoding.tolocal(namespace),
                       encoding.tolocal(key),
                       encoding.tolocal(old),
                       encoding.tolocal(new))
