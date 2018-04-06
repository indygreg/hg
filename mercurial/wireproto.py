# wireproto.py - generic wire protocol support functions
#
# Copyright 2005-2010 Matt Mackall <mpm@selenic.com>
#
# This software may be used and distributed according to the terms of the
# GNU General Public License version 2 or any later version.

from __future__ import absolute_import

import hashlib
import os
import tempfile

from .i18n import _
from .node import (
    bin,
    hex,
    nullid,
)

from . import (
    bundle2,
    changegroup as changegroupmod,
    discovery,
    encoding,
    error,
    exchange,
    peer,
    pushkey as pushkeymod,
    pycompat,
    repository,
    streamclone,
    util,
    wireprototypes,
)

from .utils import (
    procutil,
    stringutil,
)

urlerr = util.urlerr
urlreq = util.urlreq

bundle2requiredmain = _('incompatible Mercurial client; bundle2 required')
bundle2requiredhint = _('see https://www.mercurial-scm.org/wiki/'
                        'IncompatibleClient')
bundle2required = '%s\n(%s)\n' % (bundle2requiredmain, bundle2requiredhint)

class remoteiterbatcher(peer.iterbatcher):
    def __init__(self, remote):
        super(remoteiterbatcher, self).__init__()
        self._remote = remote

    def __getattr__(self, name):
        # Validate this method is batchable, since submit() only supports
        # batchable methods.
        fn = getattr(self._remote, name)
        if not getattr(fn, 'batchable', None):
            raise error.ProgrammingError('Attempted to batch a non-batchable '
                                         'call to %r' % name)

        return super(remoteiterbatcher, self).__getattr__(name)

    def submit(self):
        """Break the batch request into many patch calls and pipeline them.

        This is mostly valuable over http where request sizes can be
        limited, but can be used in other places as well.
        """
        # 2-tuple of (command, arguments) that represents what will be
        # sent over the wire.
        requests = []

        # 4-tuple of (command, final future, @batchable generator, remote
        # future).
        results = []

        for command, args, opts, finalfuture in self.calls:
            mtd = getattr(self._remote, command)
            batchable = mtd.batchable(mtd.__self__, *args, **opts)

            commandargs, fremote = next(batchable)
            assert fremote
            requests.append((command, commandargs))
            results.append((command, finalfuture, batchable, fremote))

        if requests:
            self._resultiter = self._remote._submitbatch(requests)

        self._results = results

    def results(self):
        for command, finalfuture, batchable, remotefuture in self._results:
            # Get the raw result, set it in the remote future, feed it
            # back into the @batchable generator so it can be decoded, and
            # set the result on the final future to this value.
            remoteresult = next(self._resultiter)
            remotefuture.set(remoteresult)
            finalfuture.set(next(batchable))

            # Verify our @batchable generators only emit 2 values.
            try:
                next(batchable)
            except StopIteration:
                pass
            else:
                raise error.ProgrammingError('%s @batchable generator emitted '
                                             'unexpected value count' % command)

            yield finalfuture.value

# Forward a couple of names from peer to make wireproto interactions
# slightly more sensible.
batchable = peer.batchable
future = peer.future

# list of nodes encoding / decoding

def decodelist(l, sep=' '):
    if l:
        return [bin(v) for v in  l.split(sep)]
    return []

def encodelist(l, sep=' '):
    try:
        return sep.join(map(hex, l))
    except TypeError:
        raise

# batched call argument encoding

def escapearg(plain):
    return (plain
            .replace(':', ':c')
            .replace(',', ':o')
            .replace(';', ':s')
            .replace('=', ':e'))

def unescapearg(escaped):
    return (escaped
            .replace(':e', '=')
            .replace(':s', ';')
            .replace(':o', ',')
            .replace(':c', ':'))

def encodebatchcmds(req):
    """Return a ``cmds`` argument value for the ``batch`` command."""
    cmds = []
    for op, argsdict in req:
        # Old servers didn't properly unescape argument names. So prevent
        # the sending of argument names that may not be decoded properly by
        # servers.
        assert all(escapearg(k) == k for k in argsdict)

        args = ','.join('%s=%s' % (escapearg(k), escapearg(v))
                        for k, v in argsdict.iteritems())
        cmds.append('%s %s' % (op, args))

    return ';'.join(cmds)

def clientcompressionsupport(proto):
    """Returns a list of compression methods supported by the client.

    Returns a list of the compression methods supported by the client
    according to the protocol capabilities. If no such capability has
    been announced, fallback to the default of zlib and uncompressed.
    """
    for cap in proto.getprotocaps():
        if cap.startswith('comp='):
            return cap[5:].split(',')
    return ['zlib', 'none']

# mapping of options accepted by getbundle and their types
#
# Meant to be extended by extensions. It is extensions responsibility to ensure
# such options are properly processed in exchange.getbundle.
#
# supported types are:
#
# :nodes: list of binary nodes
# :csv:   list of comma-separated values
# :scsv:  list of comma-separated values return as set
# :plain: string with no transformation needed.
gboptsmap = {'heads':  'nodes',
             'bookmarks': 'boolean',
             'common': 'nodes',
             'obsmarkers': 'boolean',
             'phases': 'boolean',
             'bundlecaps': 'scsv',
             'listkeys': 'csv',
             'cg': 'boolean',
             'cbattempted': 'boolean',
             'stream': 'boolean',
}

# client side

class wirepeer(repository.legacypeer):
    """Client-side interface for communicating with a peer repository.

    Methods commonly call wire protocol commands of the same name.

    See also httppeer.py and sshpeer.py for protocol-specific
    implementations of this interface.
    """
    # Begin of ipeercommands interface.

    def iterbatch(self):
        return remoteiterbatcher(self)

    @batchable
    def lookup(self, key):
        self.requirecap('lookup', _('look up remote revision'))
        f = future()
        yield {'key': encoding.fromlocal(key)}, f
        d = f.value
        success, data = d[:-1].split(" ", 1)
        if int(success):
            yield bin(data)
        else:
            self._abort(error.RepoError(data))

    @batchable
    def heads(self):
        f = future()
        yield {}, f
        d = f.value
        try:
            yield decodelist(d[:-1])
        except ValueError:
            self._abort(error.ResponseError(_("unexpected response:"), d))

    @batchable
    def known(self, nodes):
        f = future()
        yield {'nodes': encodelist(nodes)}, f
        d = f.value
        try:
            yield [bool(int(b)) for b in d]
        except ValueError:
            self._abort(error.ResponseError(_("unexpected response:"), d))

    @batchable
    def branchmap(self):
        f = future()
        yield {}, f
        d = f.value
        try:
            branchmap = {}
            for branchpart in d.splitlines():
                branchname, branchheads = branchpart.split(' ', 1)
                branchname = encoding.tolocal(urlreq.unquote(branchname))
                branchheads = decodelist(branchheads)
                branchmap[branchname] = branchheads
            yield branchmap
        except TypeError:
            self._abort(error.ResponseError(_("unexpected response:"), d))

    @batchable
    def listkeys(self, namespace):
        if not self.capable('pushkey'):
            yield {}, None
        f = future()
        self.ui.debug('preparing listkeys for "%s"\n' % namespace)
        yield {'namespace': encoding.fromlocal(namespace)}, f
        d = f.value
        self.ui.debug('received listkey for "%s": %i bytes\n'
                      % (namespace, len(d)))
        yield pushkeymod.decodekeys(d)

    @batchable
    def pushkey(self, namespace, key, old, new):
        if not self.capable('pushkey'):
            yield False, None
        f = future()
        self.ui.debug('preparing pushkey for "%s:%s"\n' % (namespace, key))
        yield {'namespace': encoding.fromlocal(namespace),
               'key': encoding.fromlocal(key),
               'old': encoding.fromlocal(old),
               'new': encoding.fromlocal(new)}, f
        d = f.value
        d, output = d.split('\n', 1)
        try:
            d = bool(int(d))
        except ValueError:
            raise error.ResponseError(
                _('push failed (unexpected response):'), d)
        for l in output.splitlines(True):
            self.ui.status(_('remote: '), l)
        yield d

    def stream_out(self):
        return self._callstream('stream_out')

    def getbundle(self, source, **kwargs):
        kwargs = pycompat.byteskwargs(kwargs)
        self.requirecap('getbundle', _('look up remote changes'))
        opts = {}
        bundlecaps = kwargs.get('bundlecaps') or set()
        for key, value in kwargs.iteritems():
            if value is None:
                continue
            keytype = gboptsmap.get(key)
            if keytype is None:
                raise error.ProgrammingError(
                    'Unexpectedly None keytype for key %s' % key)
            elif keytype == 'nodes':
                value = encodelist(value)
            elif keytype == 'csv':
                value = ','.join(value)
            elif keytype == 'scsv':
                value = ','.join(sorted(value))
            elif keytype == 'boolean':
                value = '%i' % bool(value)
            elif keytype != 'plain':
                raise KeyError('unknown getbundle option type %s'
                               % keytype)
            opts[key] = value
        f = self._callcompressable("getbundle", **pycompat.strkwargs(opts))
        if any((cap.startswith('HG2') for cap in bundlecaps)):
            return bundle2.getunbundler(self.ui, f)
        else:
            return changegroupmod.cg1unpacker(f, 'UN')

    def unbundle(self, cg, heads, url):
        '''Send cg (a readable file-like object representing the
        changegroup to push, typically a chunkbuffer object) to the
        remote server as a bundle.

        When pushing a bundle10 stream, return an integer indicating the
        result of the push (see changegroup.apply()).

        When pushing a bundle20 stream, return a bundle20 stream.

        `url` is the url the client thinks it's pushing to, which is
        visible to hooks.
        '''

        if heads != ['force'] and self.capable('unbundlehash'):
            heads = encodelist(['hashed',
                                hashlib.sha1(''.join(sorted(heads))).digest()])
        else:
            heads = encodelist(heads)

        if util.safehasattr(cg, 'deltaheader'):
            # this a bundle10, do the old style call sequence
            ret, output = self._callpush("unbundle", cg, heads=heads)
            if ret == "":
                raise error.ResponseError(
                    _('push failed:'), output)
            try:
                ret = int(ret)
            except ValueError:
                raise error.ResponseError(
                    _('push failed (unexpected response):'), ret)

            for l in output.splitlines(True):
                self.ui.status(_('remote: '), l)
        else:
            # bundle2 push. Send a stream, fetch a stream.
            stream = self._calltwowaystream('unbundle', cg, heads=heads)
            ret = bundle2.getunbundler(self.ui, stream)
        return ret

    # End of ipeercommands interface.

    # Begin of ipeerlegacycommands interface.

    def branches(self, nodes):
        n = encodelist(nodes)
        d = self._call("branches", nodes=n)
        try:
            br = [tuple(decodelist(b)) for b in d.splitlines()]
            return br
        except ValueError:
            self._abort(error.ResponseError(_("unexpected response:"), d))

    def between(self, pairs):
        batch = 8 # avoid giant requests
        r = []
        for i in xrange(0, len(pairs), batch):
            n = " ".join([encodelist(p, '-') for p in pairs[i:i + batch]])
            d = self._call("between", pairs=n)
            try:
                r.extend(l and decodelist(l) or [] for l in d.splitlines())
            except ValueError:
                self._abort(error.ResponseError(_("unexpected response:"), d))
        return r

    def changegroup(self, nodes, kind):
        n = encodelist(nodes)
        f = self._callcompressable("changegroup", roots=n)
        return changegroupmod.cg1unpacker(f, 'UN')

    def changegroupsubset(self, bases, heads, kind):
        self.requirecap('changegroupsubset', _('look up remote changes'))
        bases = encodelist(bases)
        heads = encodelist(heads)
        f = self._callcompressable("changegroupsubset",
                                   bases=bases, heads=heads)
        return changegroupmod.cg1unpacker(f, 'UN')

    # End of ipeerlegacycommands interface.

    def _submitbatch(self, req):
        """run batch request <req> on the server

        Returns an iterator of the raw responses from the server.
        """
        ui = self.ui
        if ui.debugflag and ui.configbool('devel', 'debug.peer-request'):
            ui.debug('devel-peer-request: batched-content\n')
            for op, args in req:
                msg = 'devel-peer-request:    - %s (%d arguments)\n'
                ui.debug(msg % (op, len(args)))

        rsp = self._callstream("batch", cmds=encodebatchcmds(req))
        chunk = rsp.read(1024)
        work = [chunk]
        while chunk:
            while ';' not in chunk and chunk:
                chunk = rsp.read(1024)
                work.append(chunk)
            merged = ''.join(work)
            while ';' in merged:
                one, merged = merged.split(';', 1)
                yield unescapearg(one)
            chunk = rsp.read(1024)
            work = [merged, chunk]
        yield unescapearg(''.join(work))

    def _submitone(self, op, args):
        return self._call(op, **pycompat.strkwargs(args))

    def debugwireargs(self, one, two, three=None, four=None, five=None):
        # don't pass optional arguments left at their default value
        opts = {}
        if three is not None:
            opts[r'three'] = three
        if four is not None:
            opts[r'four'] = four
        return self._call('debugwireargs', one=one, two=two, **opts)

    def _call(self, cmd, **args):
        """execute <cmd> on the server

        The command is expected to return a simple string.

        returns the server reply as a string."""
        raise NotImplementedError()

    def _callstream(self, cmd, **args):
        """execute <cmd> on the server

        The command is expected to return a stream. Note that if the
        command doesn't return a stream, _callstream behaves
        differently for ssh and http peers.

        returns the server reply as a file like object.
        """
        raise NotImplementedError()

    def _callcompressable(self, cmd, **args):
        """execute <cmd> on the server

        The command is expected to return a stream.

        The stream may have been compressed in some implementations. This
        function takes care of the decompression. This is the only difference
        with _callstream.

        returns the server reply as a file like object.
        """
        raise NotImplementedError()

    def _callpush(self, cmd, fp, **args):
        """execute a <cmd> on server

        The command is expected to be related to a push. Push has a special
        return method.

        returns the server reply as a (ret, output) tuple. ret is either
        empty (error) or a stringified int.
        """
        raise NotImplementedError()

    def _calltwowaystream(self, cmd, fp, **args):
        """execute <cmd> on server

        The command will send a stream to the server and get a stream in reply.
        """
        raise NotImplementedError()

    def _abort(self, exception):
        """clearly abort the wire protocol connection and raise the exception
        """
        raise NotImplementedError()

# server side

# wire protocol command can either return a string or one of these classes.

def getdispatchrepo(repo, proto, command):
    """Obtain the repo used for processing wire protocol commands.

    The intent of this function is to serve as a monkeypatch point for
    extensions that need commands to operate on different repo views under
    specialized circumstances.
    """
    return repo.filtered('served')

def dispatch(repo, proto, command):
    repo = getdispatchrepo(repo, proto, command)

    transportversion = wireprototypes.TRANSPORTS[proto.name]['version']
    commandtable = commandsv2 if transportversion == 2 else commands
    func, spec = commandtable[command]

    args = proto.getargs(spec)
    return func(repo, proto, *args)

def options(cmd, keys, others):
    opts = {}
    for k in keys:
        if k in others:
            opts[k] = others[k]
            del others[k]
    if others:
        procutil.stderr.write("warning: %s ignored unexpected arguments %s\n"
                              % (cmd, ",".join(others)))
    return opts

def bundle1allowed(repo, action):
    """Whether a bundle1 operation is allowed from the server.

    Priority is:

    1. server.bundle1gd.<action> (if generaldelta active)
    2. server.bundle1.<action>
    3. server.bundle1gd (if generaldelta active)
    4. server.bundle1
    """
    ui = repo.ui
    gd = 'generaldelta' in repo.requirements

    if gd:
        v = ui.configbool('server', 'bundle1gd.%s' % action)
        if v is not None:
            return v

    v = ui.configbool('server', 'bundle1.%s' % action)
    if v is not None:
        return v

    if gd:
        v = ui.configbool('server', 'bundle1gd')
        if v is not None:
            return v

    return ui.configbool('server', 'bundle1')

def supportedcompengines(ui, role):
    """Obtain the list of supported compression engines for a request."""
    assert role in (util.CLIENTROLE, util.SERVERROLE)

    compengines = util.compengines.supportedwireengines(role)

    # Allow config to override default list and ordering.
    if role == util.SERVERROLE:
        configengines = ui.configlist('server', 'compressionengines')
        config = 'server.compressionengines'
    else:
        # This is currently implemented mainly to facilitate testing. In most
        # cases, the server should be in charge of choosing a compression engine
        # because a server has the most to lose from a sub-optimal choice. (e.g.
        # CPU DoS due to an expensive engine or a network DoS due to poor
        # compression ratio).
        configengines = ui.configlist('experimental',
                                      'clientcompressionengines')
        config = 'experimental.clientcompressionengines'

    # No explicit config. Filter out the ones that aren't supposed to be
    # advertised and return default ordering.
    if not configengines:
        attr = 'serverpriority' if role == util.SERVERROLE else 'clientpriority'
        return [e for e in compengines
                if getattr(e.wireprotosupport(), attr) > 0]

    # If compression engines are listed in the config, assume there is a good
    # reason for it (like server operators wanting to achieve specific
    # performance characteristics). So fail fast if the config references
    # unusable compression engines.
    validnames = set(e.name() for e in compengines)
    invalidnames = set(e for e in configengines if e not in validnames)
    if invalidnames:
        raise error.Abort(_('invalid compression engine defined in %s: %s') %
                          (config, ', '.join(sorted(invalidnames))))

    compengines = [e for e in compengines if e.name() in configengines]
    compengines = sorted(compengines,
                         key=lambda e: configengines.index(e.name()))

    if not compengines:
        raise error.Abort(_('%s config option does not specify any known '
                            'compression engines') % config,
                          hint=_('usable compression engines: %s') %
                          ', '.sorted(validnames))

    return compengines

class commandentry(object):
    """Represents a declared wire protocol command."""
    def __init__(self, func, args='', transports=None,
                 permission='push'):
        self.func = func
        self.args = args
        self.transports = transports or set()
        self.permission = permission

    def _merge(self, func, args):
        """Merge this instance with an incoming 2-tuple.

        This is called when a caller using the old 2-tuple API attempts
        to replace an instance. The incoming values are merged with
        data not captured by the 2-tuple and a new instance containing
        the union of the two objects is returned.
        """
        return commandentry(func, args=args, transports=set(self.transports),
                            permission=self.permission)

    # Old code treats instances as 2-tuples. So expose that interface.
    def __iter__(self):
        yield self.func
        yield self.args

    def __getitem__(self, i):
        if i == 0:
            return self.func
        elif i == 1:
            return self.args
        else:
            raise IndexError('can only access elements 0 and 1')

class commanddict(dict):
    """Container for registered wire protocol commands.

    It behaves like a dict. But __setitem__ is overwritten to allow silent
    coercion of values from 2-tuples for API compatibility.
    """
    def __setitem__(self, k, v):
        if isinstance(v, commandentry):
            pass
        # Cast 2-tuples to commandentry instances.
        elif isinstance(v, tuple):
            if len(v) != 2:
                raise ValueError('command tuples must have exactly 2 elements')

            # It is common for extensions to wrap wire protocol commands via
            # e.g. ``wireproto.commands[x] = (newfn, args)``. Because callers
            # doing this aren't aware of the new API that uses objects to store
            # command entries, we automatically merge old state with new.
            if k in self:
                v = self[k]._merge(v[0], v[1])
            else:
                # Use default values from @wireprotocommand.
                v = commandentry(v[0], args=v[1],
                                 transports=set(wireprototypes.TRANSPORTS),
                                 permission='push')
        else:
            raise ValueError('command entries must be commandentry instances '
                             'or 2-tuples')

        return super(commanddict, self).__setitem__(k, v)

    def commandavailable(self, command, proto):
        """Determine if a command is available for the requested protocol."""
        assert proto.name in wireprototypes.TRANSPORTS

        entry = self.get(command)

        if not entry:
            return False

        if proto.name not in entry.transports:
            return False

        return True

# Constants specifying which transports a wire protocol command should be
# available on. For use with @wireprotocommand.
POLICY_ALL = 'all'
POLICY_V1_ONLY = 'v1-only'
POLICY_V2_ONLY = 'v2-only'

# For version 1 transports.
commands = commanddict()

# For version 2 transports.
commandsv2 = commanddict()

def wireprotocommand(name, args='', transportpolicy=POLICY_ALL,
                     permission='push'):
    """Decorator to declare a wire protocol command.

    ``name`` is the name of the wire protocol command being provided.

    ``args`` is a space-delimited list of named arguments that the command
    accepts. ``*`` is a special value that says to accept all arguments.

    ``transportpolicy`` is a POLICY_* constant denoting which transports
    this wire protocol command should be exposed to. By default, commands
    are exposed to all wire protocol transports.

    ``permission`` defines the permission type needed to run this command.
    Can be ``push`` or ``pull``. These roughly map to read-write and read-only,
    respectively. Default is to assume command requires ``push`` permissions
    because otherwise commands not declaring their permissions could modify
    a repository that is supposed to be read-only.
    """
    if transportpolicy == POLICY_ALL:
        transports = set(wireprototypes.TRANSPORTS)
        transportversions = {1, 2}
    elif transportpolicy == POLICY_V1_ONLY:
        transports = {k for k, v in wireprototypes.TRANSPORTS.items()
                      if v['version'] == 1}
        transportversions = {1}
    elif transportpolicy == POLICY_V2_ONLY:
        transports = {k for k, v in wireprototypes.TRANSPORTS.items()
                      if v['version'] == 2}
        transportversions = {2}
    else:
        raise error.ProgrammingError('invalid transport policy value: %s' %
                                     transportpolicy)

    # Because SSHv2 is a mirror of SSHv1, we allow "batch" commands through to
    # SSHv2.
    # TODO undo this hack when SSH is using the unified frame protocol.
    if name == b'batch':
        transports.add(wireprototypes.SSHV2)

    if permission not in ('push', 'pull'):
        raise error.ProgrammingError('invalid wire protocol permission; '
                                     'got %s; expected "push" or "pull"' %
                                     permission)

    def register(func):
        if 1 in transportversions:
            if name in commands:
                raise error.ProgrammingError('%s command already registered '
                                             'for version 1' % name)
            commands[name] = commandentry(func, args=args,
                                          transports=transports,
                                          permission=permission)
        if 2 in transportversions:
            if name in commandsv2:
                raise error.ProgrammingError('%s command already registered '
                                             'for version 2' % name)
            commandsv2[name] = commandentry(func, args=args,
                                            transports=transports,
                                            permission=permission)

        return func
    return register

# TODO define a more appropriate permissions type to use for this.
@wireprotocommand('batch', 'cmds *', permission='pull',
                  transportpolicy=POLICY_V1_ONLY)
def batch(repo, proto, cmds, others):
    repo = repo.filtered("served")
    res = []
    for pair in cmds.split(';'):
        op, args = pair.split(' ', 1)
        vals = {}
        for a in args.split(','):
            if a:
                n, v = a.split('=')
                vals[unescapearg(n)] = unescapearg(v)
        func, spec = commands[op]

        # Validate that client has permissions to perform this command.
        perm = commands[op].permission
        assert perm in ('push', 'pull')
        proto.checkperm(perm)

        if spec:
            keys = spec.split()
            data = {}
            for k in keys:
                if k == '*':
                    star = {}
                    for key in vals.keys():
                        if key not in keys:
                            star[key] = vals[key]
                    data['*'] = star
                else:
                    data[k] = vals[k]
            result = func(repo, proto, *[data[k] for k in keys])
        else:
            result = func(repo, proto)
        if isinstance(result, wireprototypes.ooberror):
            return result

        # For now, all batchable commands must return bytesresponse or
        # raw bytes (for backwards compatibility).
        assert isinstance(result, (wireprototypes.bytesresponse, bytes))
        if isinstance(result, wireprototypes.bytesresponse):
            result = result.data
        res.append(escapearg(result))

    return wireprototypes.bytesresponse(';'.join(res))

@wireprotocommand('between', 'pairs', transportpolicy=POLICY_V1_ONLY,
                  permission='pull')
def between(repo, proto, pairs):
    pairs = [decodelist(p, '-') for p in pairs.split(" ")]
    r = []
    for b in repo.between(pairs):
        r.append(encodelist(b) + "\n")

    return wireprototypes.bytesresponse(''.join(r))

@wireprotocommand('branchmap', permission='pull')
def branchmap(repo, proto):
    branchmap = repo.branchmap()
    heads = []
    for branch, nodes in branchmap.iteritems():
        branchname = urlreq.quote(encoding.fromlocal(branch))
        branchnodes = encodelist(nodes)
        heads.append('%s %s' % (branchname, branchnodes))

    return wireprototypes.bytesresponse('\n'.join(heads))

@wireprotocommand('branches', 'nodes', transportpolicy=POLICY_V1_ONLY,
                  permission='pull')
def branches(repo, proto, nodes):
    nodes = decodelist(nodes)
    r = []
    for b in repo.branches(nodes):
        r.append(encodelist(b) + "\n")

    return wireprototypes.bytesresponse(''.join(r))

@wireprotocommand('clonebundles', '', permission='pull')
def clonebundles(repo, proto):
    """Server command for returning info for available bundles to seed clones.

    Clients will parse this response and determine what bundle to fetch.

    Extensions may wrap this command to filter or dynamically emit data
    depending on the request. e.g. you could advertise URLs for the closest
    data center given the client's IP address.
    """
    return wireprototypes.bytesresponse(
        repo.vfs.tryread('clonebundles.manifest'))

wireprotocaps = ['lookup', 'branchmap', 'pushkey',
                 'known', 'getbundle', 'unbundlehash']

def _capabilities(repo, proto):
    """return a list of capabilities for a repo

    This function exists to allow extensions to easily wrap capabilities
    computation

    - returns a lists: easy to alter
    - change done here will be propagated to both `capabilities` and `hello`
      command without any other action needed.
    """
    # copy to prevent modification of the global list
    caps = list(wireprotocaps)

    # Command of same name as capability isn't exposed to version 1 of
    # transports. So conditionally add it.
    if commands.commandavailable('changegroupsubset', proto):
        caps.append('changegroupsubset')

    if streamclone.allowservergeneration(repo):
        if repo.ui.configbool('server', 'preferuncompressed'):
            caps.append('stream-preferred')
        requiredformats = repo.requirements & repo.supportedformats
        # if our local revlogs are just revlogv1, add 'stream' cap
        if not requiredformats - {'revlogv1'}:
            caps.append('stream')
        # otherwise, add 'streamreqs' detailing our local revlog format
        else:
            caps.append('streamreqs=%s' % ','.join(sorted(requiredformats)))
    if repo.ui.configbool('experimental', 'bundle2-advertise'):
        capsblob = bundle2.encodecaps(bundle2.getrepocaps(repo, role='server'))
        caps.append('bundle2=' + urlreq.quote(capsblob))
    caps.append('unbundle=%s' % ','.join(bundle2.bundlepriority))

    return proto.addcapabilities(repo, caps)

# If you are writing an extension and consider wrapping this function. Wrap
# `_capabilities` instead.
@wireprotocommand('capabilities', permission='pull')
def capabilities(repo, proto):
    return wireprototypes.bytesresponse(' '.join(_capabilities(repo, proto)))

@wireprotocommand('changegroup', 'roots', transportpolicy=POLICY_V1_ONLY,
                  permission='pull')
def changegroup(repo, proto, roots):
    nodes = decodelist(roots)
    outgoing = discovery.outgoing(repo, missingroots=nodes,
                                  missingheads=repo.heads())
    cg = changegroupmod.makechangegroup(repo, outgoing, '01', 'serve')
    gen = iter(lambda: cg.read(32768), '')
    return wireprototypes.streamres(gen=gen)

@wireprotocommand('changegroupsubset', 'bases heads',
                  transportpolicy=POLICY_V1_ONLY,
                  permission='pull')
def changegroupsubset(repo, proto, bases, heads):
    bases = decodelist(bases)
    heads = decodelist(heads)
    outgoing = discovery.outgoing(repo, missingroots=bases,
                                  missingheads=heads)
    cg = changegroupmod.makechangegroup(repo, outgoing, '01', 'serve')
    gen = iter(lambda: cg.read(32768), '')
    return wireprototypes.streamres(gen=gen)

@wireprotocommand('debugwireargs', 'one two *',
                  permission='pull')
def debugwireargs(repo, proto, one, two, others):
    # only accept optional args from the known set
    opts = options('debugwireargs', ['three', 'four'], others)
    return wireprototypes.bytesresponse(repo.debugwireargs(
        one, two, **pycompat.strkwargs(opts)))

@wireprotocommand('getbundle', '*', permission='pull')
def getbundle(repo, proto, others):
    opts = options('getbundle', gboptsmap.keys(), others)
    for k, v in opts.iteritems():
        keytype = gboptsmap[k]
        if keytype == 'nodes':
            opts[k] = decodelist(v)
        elif keytype == 'csv':
            opts[k] = list(v.split(','))
        elif keytype == 'scsv':
            opts[k] = set(v.split(','))
        elif keytype == 'boolean':
            # Client should serialize False as '0', which is a non-empty string
            # so it evaluates as a True bool.
            if v == '0':
                opts[k] = False
            else:
                opts[k] = bool(v)
        elif keytype != 'plain':
            raise KeyError('unknown getbundle option type %s'
                           % keytype)

    if not bundle1allowed(repo, 'pull'):
        if not exchange.bundle2requested(opts.get('bundlecaps')):
            if proto.name == 'http-v1':
                return wireprototypes.ooberror(bundle2required)
            raise error.Abort(bundle2requiredmain,
                              hint=bundle2requiredhint)

    prefercompressed = True

    try:
        if repo.ui.configbool('server', 'disablefullbundle'):
            # Check to see if this is a full clone.
            clheads = set(repo.changelog.heads())
            changegroup = opts.get('cg', True)
            heads = set(opts.get('heads', set()))
            common = set(opts.get('common', set()))
            common.discard(nullid)
            if changegroup and not common and clheads == heads:
                raise error.Abort(
                    _('server has pull-based clones disabled'),
                    hint=_('remove --pull if specified or upgrade Mercurial'))

        info, chunks = exchange.getbundlechunks(repo, 'serve',
                                                **pycompat.strkwargs(opts))
        prefercompressed = info.get('prefercompressed', True)
    except error.Abort as exc:
        # cleanly forward Abort error to the client
        if not exchange.bundle2requested(opts.get('bundlecaps')):
            if proto.name == 'http-v1':
                return wireprototypes.ooberror(pycompat.bytestr(exc) + '\n')
            raise # cannot do better for bundle1 + ssh
        # bundle2 request expect a bundle2 reply
        bundler = bundle2.bundle20(repo.ui)
        manargs = [('message', pycompat.bytestr(exc))]
        advargs = []
        if exc.hint is not None:
            advargs.append(('hint', exc.hint))
        bundler.addpart(bundle2.bundlepart('error:abort',
                                           manargs, advargs))
        chunks = bundler.getchunks()
        prefercompressed = False

    return wireprototypes.streamres(
        gen=chunks, prefer_uncompressed=not prefercompressed)

@wireprotocommand('heads', permission='pull')
def heads(repo, proto):
    h = repo.heads()
    return wireprototypes.bytesresponse(encodelist(h) + '\n')

@wireprotocommand('hello', permission='pull')
def hello(repo, proto):
    """Called as part of SSH handshake to obtain server info.

    Returns a list of lines describing interesting things about the
    server, in an RFC822-like format.

    Currently, the only one defined is ``capabilities``, which consists of a
    line of space separated tokens describing server abilities:

        capabilities: <token0> <token1> <token2>
    """
    caps = capabilities(repo, proto).data
    return wireprototypes.bytesresponse('capabilities: %s\n' % caps)

@wireprotocommand('listkeys', 'namespace', permission='pull')
def listkeys(repo, proto, namespace):
    d = sorted(repo.listkeys(encoding.tolocal(namespace)).items())
    return wireprototypes.bytesresponse(pushkeymod.encodekeys(d))

@wireprotocommand('lookup', 'key', permission='pull')
def lookup(repo, proto, key):
    try:
        k = encoding.tolocal(key)
        n = repo.lookup(k)
        r = hex(n)
        success = 1
    except Exception as inst:
        r = stringutil.forcebytestr(inst)
        success = 0
    return wireprototypes.bytesresponse('%d %s\n' % (success, r))

@wireprotocommand('known', 'nodes *', permission='pull')
def known(repo, proto, nodes, others):
    v = ''.join(b and '1' or '0' for b in repo.known(decodelist(nodes)))
    return wireprototypes.bytesresponse(v)

@wireprotocommand('protocaps', 'caps', permission='pull',
                  transportpolicy=POLICY_V1_ONLY)
def protocaps(repo, proto, caps):
    if proto.name == wireprototypes.SSHV1:
        proto._protocaps = set(caps.split(' '))
    return wireprototypes.bytesresponse('OK')

@wireprotocommand('pushkey', 'namespace key old new', permission='push')
def pushkey(repo, proto, namespace, key, old, new):
    # compatibility with pre-1.8 clients which were accidentally
    # sending raw binary nodes rather than utf-8-encoded hex
    if len(new) == 20 and stringutil.escapestr(new) != new:
        # looks like it could be a binary node
        try:
            new.decode('utf-8')
            new = encoding.tolocal(new) # but cleanly decodes as UTF-8
        except UnicodeDecodeError:
            pass # binary, leave unmodified
    else:
        new = encoding.tolocal(new) # normal path

    with proto.mayberedirectstdio() as output:
        r = repo.pushkey(encoding.tolocal(namespace), encoding.tolocal(key),
                         encoding.tolocal(old), new) or False

    output = output.getvalue() if output else ''
    return wireprototypes.bytesresponse('%d\n%s' % (int(r), output))

@wireprotocommand('stream_out', permission='pull')
def stream(repo, proto):
    '''If the server supports streaming clone, it advertises the "stream"
    capability with a value representing the version and flags of the repo
    it is serving. Client checks to see if it understands the format.
    '''
    return wireprototypes.streamreslegacy(
        streamclone.generatev1wireproto(repo))

@wireprotocommand('unbundle', 'heads', permission='push')
def unbundle(repo, proto, heads):
    their_heads = decodelist(heads)

    with proto.mayberedirectstdio() as output:
        try:
            exchange.check_heads(repo, their_heads, 'preparing changes')

            # write bundle data to temporary file because it can be big
            fd, tempname = tempfile.mkstemp(prefix='hg-unbundle-')
            fp = os.fdopen(fd, r'wb+')
            r = 0
            try:
                proto.forwardpayload(fp)
                fp.seek(0)
                gen = exchange.readbundle(repo.ui, fp, None)
                if (isinstance(gen, changegroupmod.cg1unpacker)
                    and not bundle1allowed(repo, 'push')):
                    if proto.name == 'http-v1':
                        # need to special case http because stderr do not get to
                        # the http client on failed push so we need to abuse
                        # some other error type to make sure the message get to
                        # the user.
                        return wireprototypes.ooberror(bundle2required)
                    raise error.Abort(bundle2requiredmain,
                                      hint=bundle2requiredhint)

                r = exchange.unbundle(repo, gen, their_heads, 'serve',
                                      proto.client())
                if util.safehasattr(r, 'addpart'):
                    # The return looks streamable, we are in the bundle2 case
                    # and should return a stream.
                    return wireprototypes.streamreslegacy(gen=r.getchunks())
                return wireprototypes.pushres(
                    r, output.getvalue() if output else '')

            finally:
                fp.close()
                os.unlink(tempname)

        except (error.BundleValueError, error.Abort, error.PushRaced) as exc:
            # handle non-bundle2 case first
            if not getattr(exc, 'duringunbundle2', False):
                try:
                    raise
                except error.Abort:
                    # The old code we moved used procutil.stderr directly.
                    # We did not change it to minimise code change.
                    # This need to be moved to something proper.
                    # Feel free to do it.
                    procutil.stderr.write("abort: %s\n" % exc)
                    if exc.hint is not None:
                        procutil.stderr.write("(%s)\n" % exc.hint)
                    procutil.stderr.flush()
                    return wireprototypes.pushres(
                        0, output.getvalue() if output else '')
                except error.PushRaced:
                    return wireprototypes.pusherr(
                        pycompat.bytestr(exc),
                        output.getvalue() if output else '')

            bundler = bundle2.bundle20(repo.ui)
            for out in getattr(exc, '_bundle2salvagedoutput', ()):
                bundler.addpart(out)
            try:
                try:
                    raise
                except error.PushkeyFailed as exc:
                    # check client caps
                    remotecaps = getattr(exc, '_replycaps', None)
                    if (remotecaps is not None
                            and 'pushkey' not in remotecaps.get('error', ())):
                        # no support remote side, fallback to Abort handler.
                        raise
                    part = bundler.newpart('error:pushkey')
                    part.addparam('in-reply-to', exc.partid)
                    if exc.namespace is not None:
                        part.addparam('namespace', exc.namespace,
                                      mandatory=False)
                    if exc.key is not None:
                        part.addparam('key', exc.key, mandatory=False)
                    if exc.new is not None:
                        part.addparam('new', exc.new, mandatory=False)
                    if exc.old is not None:
                        part.addparam('old', exc.old, mandatory=False)
                    if exc.ret is not None:
                        part.addparam('ret', exc.ret, mandatory=False)
            except error.BundleValueError as exc:
                errpart = bundler.newpart('error:unsupportedcontent')
                if exc.parttype is not None:
                    errpart.addparam('parttype', exc.parttype)
                if exc.params:
                    errpart.addparam('params', '\0'.join(exc.params))
            except error.Abort as exc:
                manargs = [('message', stringutil.forcebytestr(exc))]
                advargs = []
                if exc.hint is not None:
                    advargs.append(('hint', exc.hint))
                bundler.addpart(bundle2.bundlepart('error:abort',
                                                   manargs, advargs))
            except error.PushRaced as exc:
                bundler.newpart('error:pushraced',
                                [('message', stringutil.forcebytestr(exc))])
            return wireprototypes.streamreslegacy(gen=bundler.getchunks())
