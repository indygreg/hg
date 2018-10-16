# perf.py - performance test routines
'''helper extension to measure performance'''

# "historical portability" policy of perf.py:
#
# We have to do:
# - make perf.py "loadable" with as wide Mercurial version as possible
#   This doesn't mean that perf commands work correctly with that Mercurial.
#   BTW, perf.py itself has been available since 1.1 (or eb240755386d).
# - make historical perf command work correctly with as wide Mercurial
#   version as possible
#
# We have to do, if possible with reasonable cost:
# - make recent perf command for historical feature work correctly
#   with early Mercurial
#
# We don't have to do:
# - make perf command for recent feature work correctly with early
#   Mercurial

from __future__ import absolute_import
import contextlib
import functools
import gc
import os
import random
import struct
import sys
import threading
import time
from mercurial import (
    changegroup,
    cmdutil,
    commands,
    copies,
    error,
    extensions,
    mdiff,
    merge,
    revlog,
    util,
)

# for "historical portability":
# try to import modules separately (in dict order), and ignore
# failure, because these aren't available with early Mercurial
try:
    from mercurial import branchmap # since 2.5 (or bcee63733aad)
except ImportError:
    pass
try:
    from mercurial import obsolete # since 2.3 (or ad0d6c2b3279)
except ImportError:
    pass
try:
    from mercurial import registrar # since 3.7 (or 37d50250b696)
    dir(registrar) # forcibly load it
except ImportError:
    registrar = None
try:
    from mercurial import repoview # since 2.5 (or 3a6ddacb7198)
except ImportError:
    pass
try:
    from mercurial import scmutil # since 1.9 (or 8b252e826c68)
except ImportError:
    pass

def identity(a):
    return a

try:
    from mercurial import pycompat
    getargspec = pycompat.getargspec  # added to module after 4.5
    _byteskwargs = pycompat.byteskwargs  # since 4.1 (or fbc3f73dc802)
    _sysstr = pycompat.sysstr         # since 4.0 (or 2219f4f82ede)
    _xrange = pycompat.xrange         # since 4.8 (or 7eba8f83129b)
    fsencode = pycompat.fsencode      # since 3.9 (or f4a5e0e86a7e)
    if pycompat.ispy3:
        _maxint = sys.maxsize  # per py3 docs for replacing maxint
    else:
        _maxint = sys.maxint
except (ImportError, AttributeError):
    import inspect
    getargspec = inspect.getargspec
    _byteskwargs = identity
    fsencode = identity               # no py3 support
    _maxint = sys.maxint              # no py3 support
    _sysstr = lambda x: x             # no py3 support
    _xrange = xrange

try:
    # 4.7+
    queue = pycompat.queue.Queue
except (AttributeError, ImportError):
    # <4.7.
    try:
        queue = pycompat.queue
    except (AttributeError, ImportError):
        queue = util.queue

try:
    from mercurial import logcmdutil
    makelogtemplater = logcmdutil.maketemplater
except (AttributeError, ImportError):
    try:
        makelogtemplater = cmdutil.makelogtemplater
    except (AttributeError, ImportError):
        makelogtemplater = None

# for "historical portability":
# define util.safehasattr forcibly, because util.safehasattr has been
# available since 1.9.3 (or 94b200a11cf7)
_undefined = object()
def safehasattr(thing, attr):
    return getattr(thing, _sysstr(attr), _undefined) is not _undefined
setattr(util, 'safehasattr', safehasattr)

# for "historical portability":
# define util.timer forcibly, because util.timer has been available
# since ae5d60bb70c9
if safehasattr(time, 'perf_counter'):
    util.timer = time.perf_counter
elif os.name == b'nt':
    util.timer = time.clock
else:
    util.timer = time.time

# for "historical portability":
# use locally defined empty option list, if formatteropts isn't
# available, because commands.formatteropts has been available since
# 3.2 (or 7a7eed5176a4), even though formatting itself has been
# available since 2.2 (or ae5f92e154d3)
formatteropts = getattr(cmdutil, "formatteropts",
                        getattr(commands, "formatteropts", []))

# for "historical portability":
# use locally defined option list, if debugrevlogopts isn't available,
# because commands.debugrevlogopts has been available since 3.7 (or
# 5606f7d0d063), even though cmdutil.openrevlog() has been available
# since 1.9 (or a79fea6b3e77).
revlogopts = getattr(cmdutil, "debugrevlogopts",
                     getattr(commands, "debugrevlogopts", [
        (b'c', b'changelog', False, (b'open changelog')),
        (b'm', b'manifest', False, (b'open manifest')),
        (b'', b'dir', False, (b'open directory manifest')),
        ]))

cmdtable = {}

# for "historical portability":
# define parsealiases locally, because cmdutil.parsealiases has been
# available since 1.5 (or 6252852b4332)
def parsealiases(cmd):
    return cmd.split(b"|")

if safehasattr(registrar, 'command'):
    command = registrar.command(cmdtable)
elif safehasattr(cmdutil, 'command'):
    command = cmdutil.command(cmdtable)
    if b'norepo' not in getargspec(command).args:
        # for "historical portability":
        # wrap original cmdutil.command, because "norepo" option has
        # been available since 3.1 (or 75a96326cecb)
        _command = command
        def command(name, options=(), synopsis=None, norepo=False):
            if norepo:
                commands.norepo += b' %s' % b' '.join(parsealiases(name))
            return _command(name, list(options), synopsis)
else:
    # for "historical portability":
    # define "@command" annotation locally, because cmdutil.command
    # has been available since 1.9 (or 2daa5179e73f)
    def command(name, options=(), synopsis=None, norepo=False):
        def decorator(func):
            if synopsis:
                cmdtable[name] = func, list(options), synopsis
            else:
                cmdtable[name] = func, list(options)
            if norepo:
                commands.norepo += b' %s' % b' '.join(parsealiases(name))
            return func
        return decorator

try:
    import mercurial.registrar
    import mercurial.configitems
    configtable = {}
    configitem = mercurial.registrar.configitem(configtable)
    configitem(b'perf', b'presleep',
        default=mercurial.configitems.dynamicdefault,
    )
    configitem(b'perf', b'stub',
        default=mercurial.configitems.dynamicdefault,
    )
    configitem(b'perf', b'parentscount',
        default=mercurial.configitems.dynamicdefault,
    )
    configitem(b'perf', b'all-timing',
        default=mercurial.configitems.dynamicdefault,
    )
except (ImportError, AttributeError):
    pass

def getlen(ui):
    if ui.configbool(b"perf", b"stub", False):
        return lambda x: 1
    return len

def gettimer(ui, opts=None):
    """return a timer function and formatter: (timer, formatter)

    This function exists to gather the creation of formatter in a single
    place instead of duplicating it in all performance commands."""

    # enforce an idle period before execution to counteract power management
    # experimental config: perf.presleep
    time.sleep(getint(ui, b"perf", b"presleep", 1))

    if opts is None:
        opts = {}
    # redirect all to stderr unless buffer api is in use
    if not ui._buffers:
        ui = ui.copy()
        uifout = safeattrsetter(ui, b'fout', ignoremissing=True)
        if uifout:
            # for "historical portability":
            # ui.fout/ferr have been available since 1.9 (or 4e1ccd4c2b6d)
            uifout.set(ui.ferr)

    # get a formatter
    uiformatter = getattr(ui, 'formatter', None)
    if uiformatter:
        fm = uiformatter(b'perf', opts)
    else:
        # for "historical portability":
        # define formatter locally, because ui.formatter has been
        # available since 2.2 (or ae5f92e154d3)
        from mercurial import node
        class defaultformatter(object):
            """Minimized composition of baseformatter and plainformatter
            """
            def __init__(self, ui, topic, opts):
                self._ui = ui
                if ui.debugflag:
                    self.hexfunc = node.hex
                else:
                    self.hexfunc = node.short
            def __nonzero__(self):
                return False
            __bool__ = __nonzero__
            def startitem(self):
                pass
            def data(self, **data):
                pass
            def write(self, fields, deftext, *fielddata, **opts):
                self._ui.write(deftext % fielddata, **opts)
            def condwrite(self, cond, fields, deftext, *fielddata, **opts):
                if cond:
                    self._ui.write(deftext % fielddata, **opts)
            def plain(self, text, **opts):
                self._ui.write(text, **opts)
            def end(self):
                pass
        fm = defaultformatter(ui, b'perf', opts)

    # stub function, runs code only once instead of in a loop
    # experimental config: perf.stub
    if ui.configbool(b"perf", b"stub", False):
        return functools.partial(stub_timer, fm), fm

    # experimental config: perf.all-timing
    displayall = ui.configbool(b"perf", b"all-timing", False)
    return functools.partial(_timer, fm, displayall=displayall), fm

def stub_timer(fm, func, title=None):
    func()

@contextlib.contextmanager
def timeone():
    r = []
    ostart = os.times()
    cstart = util.timer()
    yield r
    cstop = util.timer()
    ostop = os.times()
    a, b = ostart, ostop
    r.append((cstop - cstart, b[0] - a[0], b[1]-a[1]))

def _timer(fm, func, title=None, displayall=False):
    gc.collect()
    results = []
    begin = util.timer()
    count = 0
    while True:
        with timeone() as item:
            r = func()
        count += 1
        results.append(item[0])
        cstop = util.timer()
        if cstop - begin > 3 and count >= 100:
            break
        if cstop - begin > 10 and count >= 3:
            break

    formatone(fm, results, title=title, result=r,
              displayall=displayall)

def formatone(fm, timings, title=None, result=None, displayall=False):

    count = len(timings)

    fm.startitem()

    if title:
        fm.write(b'title', b'! %s\n', title)
    if result:
        fm.write(b'result', b'! result: %s\n', result)
    def display(role, entry):
        prefix = b''
        if role != b'best':
            prefix = b'%s.' % role
        fm.plain(b'!')
        fm.write(prefix + b'wall', b' wall %f', entry[0])
        fm.write(prefix + b'comb', b' comb %f', entry[1] + entry[2])
        fm.write(prefix + b'user', b' user %f', entry[1])
        fm.write(prefix + b'sys',  b' sys %f', entry[2])
        fm.write(prefix + b'count',  b' (%s of %%d)' % role, count)
        fm.plain(b'\n')
    timings.sort()
    min_val = timings[0]
    display(b'best', min_val)
    if displayall:
        max_val = timings[-1]
        display(b'max', max_val)
        avg = tuple([sum(x) / count for x in zip(*timings)])
        display(b'avg', avg)
        median = timings[len(timings) // 2]
        display(b'median', median)

# utilities for historical portability

def getint(ui, section, name, default):
    # for "historical portability":
    # ui.configint has been available since 1.9 (or fa2b596db182)
    v = ui.config(section, name, None)
    if v is None:
        return default
    try:
        return int(v)
    except ValueError:
        raise error.ConfigError((b"%s.%s is not an integer ('%s')")
                                % (section, name, v))

def safeattrsetter(obj, name, ignoremissing=False):
    """Ensure that 'obj' has 'name' attribute before subsequent setattr

    This function is aborted, if 'obj' doesn't have 'name' attribute
    at runtime. This avoids overlooking removal of an attribute, which
    breaks assumption of performance measurement, in the future.

    This function returns the object to (1) assign a new value, and
    (2) restore an original value to the attribute.

    If 'ignoremissing' is true, missing 'name' attribute doesn't cause
    abortion, and this function returns None. This is useful to
    examine an attribute, which isn't ensured in all Mercurial
    versions.
    """
    if not util.safehasattr(obj, name):
        if ignoremissing:
            return None
        raise error.Abort((b"missing attribute %s of %s might break assumption"
                           b" of performance measurement") % (name, obj))

    origvalue = getattr(obj, _sysstr(name))
    class attrutil(object):
        def set(self, newvalue):
            setattr(obj, _sysstr(name), newvalue)
        def restore(self):
            setattr(obj, _sysstr(name), origvalue)

    return attrutil()

# utilities to examine each internal API changes

def getbranchmapsubsettable():
    # for "historical portability":
    # subsettable is defined in:
    # - branchmap since 2.9 (or 175c6fd8cacc)
    # - repoview since 2.5 (or 59a9f18d4587)
    for mod in (branchmap, repoview):
        subsettable = getattr(mod, 'subsettable', None)
        if subsettable:
            return subsettable

    # bisecting in bcee63733aad::59a9f18d4587 can reach here (both
    # branchmap and repoview modules exist, but subsettable attribute
    # doesn't)
    raise error.Abort((b"perfbranchmap not available with this Mercurial"),
                      hint=b"use 2.5 or later")

def getsvfs(repo):
    """Return appropriate object to access files under .hg/store
    """
    # for "historical portability":
    # repo.svfs has been available since 2.3 (or 7034365089bf)
    svfs = getattr(repo, 'svfs', None)
    if svfs:
        return svfs
    else:
        return getattr(repo, 'sopener')

def getvfs(repo):
    """Return appropriate object to access files under .hg
    """
    # for "historical portability":
    # repo.vfs has been available since 2.3 (or 7034365089bf)
    vfs = getattr(repo, 'vfs', None)
    if vfs:
        return vfs
    else:
        return getattr(repo, 'opener')

def repocleartagscachefunc(repo):
    """Return the function to clear tags cache according to repo internal API
    """
    if util.safehasattr(repo, b'_tagscache'): # since 2.0 (or 9dca7653b525)
        # in this case, setattr(repo, '_tagscache', None) or so isn't
        # correct way to clear tags cache, because existing code paths
        # expect _tagscache to be a structured object.
        def clearcache():
            # _tagscache has been filteredpropertycache since 2.5 (or
            # 98c867ac1330), and delattr() can't work in such case
            if b'_tagscache' in vars(repo):
                del repo.__dict__[b'_tagscache']
        return clearcache

    repotags = safeattrsetter(repo, b'_tags', ignoremissing=True)
    if repotags: # since 1.4 (or 5614a628d173)
        return lambda : repotags.set(None)

    repotagscache = safeattrsetter(repo, b'tagscache', ignoremissing=True)
    if repotagscache: # since 0.6 (or d7df759d0e97)
        return lambda : repotagscache.set(None)

    # Mercurial earlier than 0.6 (or d7df759d0e97) logically reaches
    # this point, but it isn't so problematic, because:
    # - repo.tags of such Mercurial isn't "callable", and repo.tags()
    #   in perftags() causes failure soon
    # - perf.py itself has been available since 1.1 (or eb240755386d)
    raise error.Abort((b"tags API of this hg command is unknown"))

# utilities to clear cache

def clearfilecache(repo, attrname):
    unfi = repo.unfiltered()
    if attrname in vars(unfi):
        delattr(unfi, attrname)
    unfi._filecache.pop(attrname, None)

# perf commands

@command(b'perfwalk', formatteropts)
def perfwalk(ui, repo, *pats, **opts):
    opts = _byteskwargs(opts)
    timer, fm = gettimer(ui, opts)
    m = scmutil.match(repo[None], pats, {})
    timer(lambda: len(list(repo.dirstate.walk(m, subrepos=[], unknown=True,
                                              ignored=False))))
    fm.end()

@command(b'perfannotate', formatteropts)
def perfannotate(ui, repo, f, **opts):
    opts = _byteskwargs(opts)
    timer, fm = gettimer(ui, opts)
    fc = repo[b'.'][f]
    timer(lambda: len(fc.annotate(True)))
    fm.end()

@command(b'perfstatus',
         [(b'u', b'unknown', False,
           b'ask status to look for unknown files')] + formatteropts)
def perfstatus(ui, repo, **opts):
    opts = _byteskwargs(opts)
    #m = match.always(repo.root, repo.getcwd())
    #timer(lambda: sum(map(len, repo.dirstate.status(m, [], False, False,
    #                                                False))))
    timer, fm = gettimer(ui, opts)
    timer(lambda: sum(map(len, repo.status(unknown=opts[b'unknown']))))
    fm.end()

@command(b'perfaddremove', formatteropts)
def perfaddremove(ui, repo, **opts):
    opts = _byteskwargs(opts)
    timer, fm = gettimer(ui, opts)
    try:
        oldquiet = repo.ui.quiet
        repo.ui.quiet = True
        matcher = scmutil.match(repo[None])
        opts[b'dry_run'] = True
        timer(lambda: scmutil.addremove(repo, matcher, b"", opts))
    finally:
        repo.ui.quiet = oldquiet
        fm.end()

def clearcaches(cl):
    # behave somewhat consistently across internal API changes
    if util.safehasattr(cl, b'clearcaches'):
        cl.clearcaches()
    elif util.safehasattr(cl, b'_nodecache'):
        from mercurial.node import nullid, nullrev
        cl._nodecache = {nullid: nullrev}
        cl._nodepos = None

@command(b'perfheads', formatteropts)
def perfheads(ui, repo, **opts):
    opts = _byteskwargs(opts)
    timer, fm = gettimer(ui, opts)
    cl = repo.changelog
    def d():
        len(cl.headrevs())
        clearcaches(cl)
    timer(d)
    fm.end()

@command(b'perftags', formatteropts)
def perftags(ui, repo, **opts):
    import mercurial.changelog
    import mercurial.manifest

    opts = _byteskwargs(opts)
    timer, fm = gettimer(ui, opts)
    svfs = getsvfs(repo)
    repocleartagscache = repocleartagscachefunc(repo)
    def t():
        repo.changelog = mercurial.changelog.changelog(svfs)
        rootmanifest = mercurial.manifest.manifestrevlog(svfs)
        repo.manifestlog = mercurial.manifest.manifestlog(svfs, repo,
                                                          rootmanifest)
        repocleartagscache()
        return len(repo.tags())
    timer(t)
    fm.end()

@command(b'perfancestors', formatteropts)
def perfancestors(ui, repo, **opts):
    opts = _byteskwargs(opts)
    timer, fm = gettimer(ui, opts)
    heads = repo.changelog.headrevs()
    def d():
        for a in repo.changelog.ancestors(heads):
            pass
    timer(d)
    fm.end()

@command(b'perfancestorset', formatteropts)
def perfancestorset(ui, repo, revset, **opts):
    opts = _byteskwargs(opts)
    timer, fm = gettimer(ui, opts)
    revs = repo.revs(revset)
    heads = repo.changelog.headrevs()
    def d():
        s = repo.changelog.ancestors(heads)
        for rev in revs:
            rev in s
    timer(d)
    fm.end()

@command(b'perfbookmarks', formatteropts)
def perfbookmarks(ui, repo, **opts):
    """benchmark parsing bookmarks from disk to memory"""
    opts = _byteskwargs(opts)
    timer, fm = gettimer(ui, opts)
    def d():
        clearfilecache(repo, b'_bookmarks')
        repo._bookmarks
    timer(d)
    fm.end()

@command(b'perfbundleread', formatteropts, b'BUNDLE')
def perfbundleread(ui, repo, bundlepath, **opts):
    """Benchmark reading of bundle files.

    This command is meant to isolate the I/O part of bundle reading as
    much as possible.
    """
    from mercurial import (
        bundle2,
        exchange,
        streamclone,
    )

    opts = _byteskwargs(opts)

    def makebench(fn):
        def run():
            with open(bundlepath, b'rb') as fh:
                bundle = exchange.readbundle(ui, fh, bundlepath)
                fn(bundle)

        return run

    def makereadnbytes(size):
        def run():
            with open(bundlepath, b'rb') as fh:
                bundle = exchange.readbundle(ui, fh, bundlepath)
                while bundle.read(size):
                    pass

        return run

    def makestdioread(size):
        def run():
            with open(bundlepath, b'rb') as fh:
                while fh.read(size):
                    pass

        return run

    # bundle1

    def deltaiter(bundle):
        for delta in bundle.deltaiter():
            pass

    def iterchunks(bundle):
        for chunk in bundle.getchunks():
            pass

    # bundle2

    def forwardchunks(bundle):
        for chunk in bundle._forwardchunks():
            pass

    def iterparts(bundle):
        for part in bundle.iterparts():
            pass

    def iterpartsseekable(bundle):
        for part in bundle.iterparts(seekable=True):
            pass

    def seek(bundle):
        for part in bundle.iterparts(seekable=True):
            part.seek(0, os.SEEK_END)

    def makepartreadnbytes(size):
        def run():
            with open(bundlepath, b'rb') as fh:
                bundle = exchange.readbundle(ui, fh, bundlepath)
                for part in bundle.iterparts():
                    while part.read(size):
                        pass

        return run

    benches = [
        (makestdioread(8192), b'read(8k)'),
        (makestdioread(16384), b'read(16k)'),
        (makestdioread(32768), b'read(32k)'),
        (makestdioread(131072), b'read(128k)'),
    ]

    with open(bundlepath, b'rb') as fh:
        bundle = exchange.readbundle(ui, fh, bundlepath)

        if isinstance(bundle, changegroup.cg1unpacker):
            benches.extend([
                (makebench(deltaiter), b'cg1 deltaiter()'),
                (makebench(iterchunks), b'cg1 getchunks()'),
                (makereadnbytes(8192), b'cg1 read(8k)'),
                (makereadnbytes(16384), b'cg1 read(16k)'),
                (makereadnbytes(32768), b'cg1 read(32k)'),
                (makereadnbytes(131072), b'cg1 read(128k)'),
            ])
        elif isinstance(bundle, bundle2.unbundle20):
            benches.extend([
                (makebench(forwardchunks), b'bundle2 forwardchunks()'),
                (makebench(iterparts), b'bundle2 iterparts()'),
                (makebench(iterpartsseekable), b'bundle2 iterparts() seekable'),
                (makebench(seek), b'bundle2 part seek()'),
                (makepartreadnbytes(8192), b'bundle2 part read(8k)'),
                (makepartreadnbytes(16384), b'bundle2 part read(16k)'),
                (makepartreadnbytes(32768), b'bundle2 part read(32k)'),
                (makepartreadnbytes(131072), b'bundle2 part read(128k)'),
            ])
        elif isinstance(bundle, streamclone.streamcloneapplier):
            raise error.Abort(b'stream clone bundles not supported')
        else:
            raise error.Abort(b'unhandled bundle type: %s' % type(bundle))

    for fn, title in benches:
        timer, fm = gettimer(ui, opts)
        timer(fn, title=title)
        fm.end()

@command(b'perfchangegroupchangelog', formatteropts +
         [(b'', b'version', b'02', b'changegroup version'),
          (b'r', b'rev', b'', b'revisions to add to changegroup')])
def perfchangegroupchangelog(ui, repo, version=b'02', rev=None, **opts):
    """Benchmark producing a changelog group for a changegroup.

    This measures the time spent processing the changelog during a
    bundle operation. This occurs during `hg bundle` and on a server
    processing a `getbundle` wire protocol request (handles clones
    and pull requests).

    By default, all revisions are added to the changegroup.
    """
    opts = _byteskwargs(opts)
    cl = repo.changelog
    nodes = [cl.lookup(r) for r in repo.revs(rev or b'all()')]
    bundler = changegroup.getbundler(version, repo)

    def d():
        state, chunks = bundler._generatechangelog(cl, nodes)
        for chunk in chunks:
            pass

    timer, fm = gettimer(ui, opts)

    # Terminal printing can interfere with timing. So disable it.
    with ui.configoverride({(b'progress', b'disable'): True}):
        timer(d)

    fm.end()

@command(b'perfdirs', formatteropts)
def perfdirs(ui, repo, **opts):
    opts = _byteskwargs(opts)
    timer, fm = gettimer(ui, opts)
    dirstate = repo.dirstate
    b'a' in dirstate
    def d():
        dirstate.hasdir(b'a')
        del dirstate._map._dirs
    timer(d)
    fm.end()

@command(b'perfdirstate', formatteropts)
def perfdirstate(ui, repo, **opts):
    opts = _byteskwargs(opts)
    timer, fm = gettimer(ui, opts)
    b"a" in repo.dirstate
    def d():
        repo.dirstate.invalidate()
        b"a" in repo.dirstate
    timer(d)
    fm.end()

@command(b'perfdirstatedirs', formatteropts)
def perfdirstatedirs(ui, repo, **opts):
    opts = _byteskwargs(opts)
    timer, fm = gettimer(ui, opts)
    b"a" in repo.dirstate
    def d():
        repo.dirstate.hasdir(b"a")
        del repo.dirstate._map._dirs
    timer(d)
    fm.end()

@command(b'perfdirstatefoldmap', formatteropts)
def perfdirstatefoldmap(ui, repo, **opts):
    opts = _byteskwargs(opts)
    timer, fm = gettimer(ui, opts)
    dirstate = repo.dirstate
    b'a' in dirstate
    def d():
        dirstate._map.filefoldmap.get(b'a')
        del dirstate._map.filefoldmap
    timer(d)
    fm.end()

@command(b'perfdirfoldmap', formatteropts)
def perfdirfoldmap(ui, repo, **opts):
    opts = _byteskwargs(opts)
    timer, fm = gettimer(ui, opts)
    dirstate = repo.dirstate
    b'a' in dirstate
    def d():
        dirstate._map.dirfoldmap.get(b'a')
        del dirstate._map.dirfoldmap
        del dirstate._map._dirs
    timer(d)
    fm.end()

@command(b'perfdirstatewrite', formatteropts)
def perfdirstatewrite(ui, repo, **opts):
    opts = _byteskwargs(opts)
    timer, fm = gettimer(ui, opts)
    ds = repo.dirstate
    b"a" in ds
    def d():
        ds._dirty = True
        ds.write(repo.currenttransaction())
    timer(d)
    fm.end()

@command(b'perfmergecalculate',
         [(b'r', b'rev', b'.', b'rev to merge against')] + formatteropts)
def perfmergecalculate(ui, repo, rev, **opts):
    opts = _byteskwargs(opts)
    timer, fm = gettimer(ui, opts)
    wctx = repo[None]
    rctx = scmutil.revsingle(repo, rev, rev)
    ancestor = wctx.ancestor(rctx)
    # we don't want working dir files to be stat'd in the benchmark, so prime
    # that cache
    wctx.dirty()
    def d():
        # acceptremote is True because we don't want prompts in the middle of
        # our benchmark
        merge.calculateupdates(repo, wctx, rctx, [ancestor], False, False,
                               acceptremote=True, followcopies=True)
    timer(d)
    fm.end()

@command(b'perfpathcopies', [], b"REV REV")
def perfpathcopies(ui, repo, rev1, rev2, **opts):
    opts = _byteskwargs(opts)
    timer, fm = gettimer(ui, opts)
    ctx1 = scmutil.revsingle(repo, rev1, rev1)
    ctx2 = scmutil.revsingle(repo, rev2, rev2)
    def d():
        copies.pathcopies(ctx1, ctx2)
    timer(d)
    fm.end()

@command(b'perfphases',
         [(b'', b'full', False, b'include file reading time too'),
          ], b"")
def perfphases(ui, repo, **opts):
    """benchmark phasesets computation"""
    opts = _byteskwargs(opts)
    timer, fm = gettimer(ui, opts)
    _phases = repo._phasecache
    full = opts.get(b'full')
    def d():
        phases = _phases
        if full:
            clearfilecache(repo, b'_phasecache')
            phases = repo._phasecache
        phases.invalidate()
        phases.loadphaserevs(repo)
    timer(d)
    fm.end()

@command(b'perfphasesremote',
         [], b"[DEST]")
def perfphasesremote(ui, repo, dest=None, **opts):
    """benchmark time needed to analyse phases of the remote server"""
    from mercurial.node import (
        bin,
    )
    from mercurial import (
        exchange,
        hg,
        phases,
    )
    opts = _byteskwargs(opts)
    timer, fm = gettimer(ui, opts)

    path = ui.paths.getpath(dest, default=(b'default-push', b'default'))
    if not path:
        raise error.Abort((b'default repository not configured!'),
                          hint=(b"see 'hg help config.paths'"))
    dest = path.pushloc or path.loc
    branches = (path.branch, opts.get(b'branch') or [])
    ui.status((b'analysing phase of %s\n') % util.hidepassword(dest))
    revs, checkout = hg.addbranchrevs(repo, repo, branches, opts.get(b'rev'))
    other = hg.peer(repo, opts, dest)

    # easier to perform discovery through the operation
    op = exchange.pushoperation(repo, other)
    exchange._pushdiscoverychangeset(op)

    remotesubset = op.fallbackheads

    with other.commandexecutor() as e:
        remotephases = e.callcommand(b'listkeys',
                       {b'namespace': b'phases'}).result()
    del other
    publishing = remotephases.get(b'publishing', False)
    if publishing:
        ui.status((b'publishing: yes\n'))
    else:
        ui.status((b'publishing: no\n'))

    nodemap = repo.changelog.nodemap
    nonpublishroots = 0
    for nhex, phase in remotephases.iteritems():
        if nhex == b'publishing': # ignore data related to publish option
            continue
        node = bin(nhex)
        if node in nodemap and int(phase):
            nonpublishroots += 1
    ui.status((b'number of roots: %d\n') % len(remotephases))
    ui.status((b'number of known non public roots: %d\n') % nonpublishroots)
    def d():
        phases.remotephasessummary(repo,
                                   remotesubset,
                                   remotephases)
    timer(d)
    fm.end()

@command(b'perfmanifest',[
            (b'm', b'manifest-rev', False, b'Look up a manifest node revision'),
            (b'', b'clear-disk', False, b'clear on-disk caches too'),
         ] + formatteropts, b'REV|NODE')
def perfmanifest(ui, repo, rev, manifest_rev=False, clear_disk=False, **opts):
    """benchmark the time to read a manifest from disk and return a usable
    dict-like object

    Manifest caches are cleared before retrieval."""
    opts = _byteskwargs(opts)
    timer, fm = gettimer(ui, opts)
    if not manifest_rev:
        ctx = scmutil.revsingle(repo, rev, rev)
        t = ctx.manifestnode()
    else:
        from mercurial.node import bin

        if len(rev) == 40:
            t = bin(rev)
        else:
            try:
                rev = int(rev)

                if util.safehasattr(repo.manifestlog, b'getstorage'):
                    t = repo.manifestlog.getstorage(b'').node(rev)
                else:
                    t = repo.manifestlog._revlog.lookup(rev)
            except ValueError:
                raise error.Abort(b'manifest revision must be integer or full '
                                  b'node')
    def d():
        repo.manifestlog.clearcaches(clear_persisted_data=clear_disk)
        repo.manifestlog[t].read()
    timer(d)
    fm.end()

@command(b'perfchangeset', formatteropts)
def perfchangeset(ui, repo, rev, **opts):
    opts = _byteskwargs(opts)
    timer, fm = gettimer(ui, opts)
    n = scmutil.revsingle(repo, rev).node()
    def d():
        repo.changelog.read(n)
        #repo.changelog._cache = None
    timer(d)
    fm.end()

@command(b'perfindex', formatteropts)
def perfindex(ui, repo, **opts):
    import mercurial.revlog
    opts = _byteskwargs(opts)
    timer, fm = gettimer(ui, opts)
    mercurial.revlog._prereadsize = 2**24 # disable lazy parser in old hg
    n = repo[b"tip"].node()
    svfs = getsvfs(repo)
    def d():
        cl = mercurial.revlog.revlog(svfs, b"00changelog.i")
        cl.rev(n)
    timer(d)
    fm.end()

@command(b'perfstartup', formatteropts)
def perfstartup(ui, repo, **opts):
    opts = _byteskwargs(opts)
    timer, fm = gettimer(ui, opts)
    def d():
        if os.name != r'nt':
            os.system(b"HGRCPATH= %s version -q > /dev/null" %
                      fsencode(sys.argv[0]))
        else:
            os.environ[r'HGRCPATH'] = r' '
            os.system(r"%s version -q > NUL" % sys.argv[0])
    timer(d)
    fm.end()

@command(b'perfparents', formatteropts)
def perfparents(ui, repo, **opts):
    opts = _byteskwargs(opts)
    timer, fm = gettimer(ui, opts)
    # control the number of commits perfparents iterates over
    # experimental config: perf.parentscount
    count = getint(ui, b"perf", b"parentscount", 1000)
    if len(repo.changelog) < count:
        raise error.Abort(b"repo needs %d commits for this test" % count)
    repo = repo.unfiltered()
    nl = [repo.changelog.node(i) for i in _xrange(count)]
    def d():
        for n in nl:
            repo.changelog.parents(n)
    timer(d)
    fm.end()

@command(b'perfctxfiles', formatteropts)
def perfctxfiles(ui, repo, x, **opts):
    opts = _byteskwargs(opts)
    x = int(x)
    timer, fm = gettimer(ui, opts)
    def d():
        len(repo[x].files())
    timer(d)
    fm.end()

@command(b'perfrawfiles', formatteropts)
def perfrawfiles(ui, repo, x, **opts):
    opts = _byteskwargs(opts)
    x = int(x)
    timer, fm = gettimer(ui, opts)
    cl = repo.changelog
    def d():
        len(cl.read(x)[3])
    timer(d)
    fm.end()

@command(b'perflookup', formatteropts)
def perflookup(ui, repo, rev, **opts):
    opts = _byteskwargs(opts)
    timer, fm = gettimer(ui, opts)
    timer(lambda: len(repo.lookup(rev)))
    fm.end()

@command(b'perflinelogedits',
         [(b'n', b'edits', 10000, b'number of edits'),
          (b'', b'max-hunk-lines', 10, b'max lines in a hunk'),
          ], norepo=True)
def perflinelogedits(ui, **opts):
    from mercurial import linelog

    opts = _byteskwargs(opts)

    edits = opts[b'edits']
    maxhunklines = opts[b'max_hunk_lines']

    maxb1 = 100000
    random.seed(0)
    randint = random.randint
    currentlines = 0
    arglist = []
    for rev in _xrange(edits):
        a1 = randint(0, currentlines)
        a2 = randint(a1, min(currentlines, a1 + maxhunklines))
        b1 = randint(0, maxb1)
        b2 = randint(b1, b1 + maxhunklines)
        currentlines += (b2 - b1) - (a2 - a1)
        arglist.append((rev, a1, a2, b1, b2))

    def d():
        ll = linelog.linelog()
        for args in arglist:
            ll.replacelines(*args)

    timer, fm = gettimer(ui, opts)
    timer(d)
    fm.end()

@command(b'perfrevrange', formatteropts)
def perfrevrange(ui, repo, *specs, **opts):
    opts = _byteskwargs(opts)
    timer, fm = gettimer(ui, opts)
    revrange = scmutil.revrange
    timer(lambda: len(revrange(repo, specs)))
    fm.end()

@command(b'perfnodelookup', formatteropts)
def perfnodelookup(ui, repo, rev, **opts):
    opts = _byteskwargs(opts)
    timer, fm = gettimer(ui, opts)
    import mercurial.revlog
    mercurial.revlog._prereadsize = 2**24 # disable lazy parser in old hg
    n = scmutil.revsingle(repo, rev).node()
    cl = mercurial.revlog.revlog(getsvfs(repo), b"00changelog.i")
    def d():
        cl.rev(n)
        clearcaches(cl)
    timer(d)
    fm.end()

@command(b'perflog',
         [(b'', b'rename', False, b'ask log to follow renames')
         ] + formatteropts)
def perflog(ui, repo, rev=None, **opts):
    opts = _byteskwargs(opts)
    if rev is None:
        rev=[]
    timer, fm = gettimer(ui, opts)
    ui.pushbuffer()
    timer(lambda: commands.log(ui, repo, rev=rev, date=b'', user=b'',
                               copies=opts.get(b'rename')))
    ui.popbuffer()
    fm.end()

@command(b'perfmoonwalk', formatteropts)
def perfmoonwalk(ui, repo, **opts):
    """benchmark walking the changelog backwards

    This also loads the changelog data for each revision in the changelog.
    """
    opts = _byteskwargs(opts)
    timer, fm = gettimer(ui, opts)
    def moonwalk():
        for i in repo.changelog.revs(start=(len(repo) - 1), stop=-1):
            ctx = repo[i]
            ctx.branch() # read changelog data (in addition to the index)
    timer(moonwalk)
    fm.end()

@command(b'perftemplating',
         [(b'r', b'rev', [], b'revisions to run the template on'),
          ] + formatteropts)
def perftemplating(ui, repo, testedtemplate=None, **opts):
    """test the rendering time of a given template"""
    if makelogtemplater is None:
        raise error.Abort((b"perftemplating not available with this Mercurial"),
                          hint=b"use 4.3 or later")

    opts = _byteskwargs(opts)

    nullui = ui.copy()
    nullui.fout = open(os.devnull, r'wb')
    nullui.disablepager()
    revs = opts.get(b'rev')
    if not revs:
        revs = [b'all()']
    revs = list(scmutil.revrange(repo, revs))

    defaulttemplate = (b'{date|shortdate} [{rev}:{node|short}]'
                       b' {author|person}: {desc|firstline}\n')
    if testedtemplate is None:
        testedtemplate = defaulttemplate
    displayer = makelogtemplater(nullui, repo, testedtemplate)
    def format():
        for r in revs:
            ctx = repo[r]
            displayer.show(ctx)
            displayer.flush(ctx)

    timer, fm = gettimer(ui, opts)
    timer(format)
    fm.end()

@command(b'perfcca', formatteropts)
def perfcca(ui, repo, **opts):
    opts = _byteskwargs(opts)
    timer, fm = gettimer(ui, opts)
    timer(lambda: scmutil.casecollisionauditor(ui, False, repo.dirstate))
    fm.end()

@command(b'perffncacheload', formatteropts)
def perffncacheload(ui, repo, **opts):
    opts = _byteskwargs(opts)
    timer, fm = gettimer(ui, opts)
    s = repo.store
    def d():
        s.fncache._load()
    timer(d)
    fm.end()

@command(b'perffncachewrite', formatteropts)
def perffncachewrite(ui, repo, **opts):
    opts = _byteskwargs(opts)
    timer, fm = gettimer(ui, opts)
    s = repo.store
    lock = repo.lock()
    s.fncache._load()
    tr = repo.transaction(b'perffncachewrite')
    tr.addbackup(b'fncache')
    def d():
        s.fncache._dirty = True
        s.fncache.write(tr)
    timer(d)
    tr.close()
    lock.release()
    fm.end()

@command(b'perffncacheencode', formatteropts)
def perffncacheencode(ui, repo, **opts):
    opts = _byteskwargs(opts)
    timer, fm = gettimer(ui, opts)
    s = repo.store
    s.fncache._load()
    def d():
        for p in s.fncache.entries:
            s.encode(p)
    timer(d)
    fm.end()

def _bdiffworker(q, blocks, xdiff, ready, done):
    while not done.is_set():
        pair = q.get()
        while pair is not None:
            if xdiff:
                mdiff.bdiff.xdiffblocks(*pair)
            elif blocks:
                mdiff.bdiff.blocks(*pair)
            else:
                mdiff.textdiff(*pair)
            q.task_done()
            pair = q.get()
        q.task_done() # for the None one
        with ready:
            ready.wait()

def _manifestrevision(repo, mnode):
    ml = repo.manifestlog

    if util.safehasattr(ml, b'getstorage'):
        store = ml.getstorage(b'')
    else:
        store = ml._revlog

    return store.revision(mnode)

@command(b'perfbdiff', revlogopts + formatteropts + [
    (b'', b'count', 1, b'number of revisions to test (when using --startrev)'),
    (b'', b'alldata', False, b'test bdiffs for all associated revisions'),
    (b'', b'threads', 0, b'number of thread to use (disable with 0)'),
    (b'', b'blocks', False, b'test computing diffs into blocks'),
    (b'', b'xdiff', False, b'use xdiff algorithm'),
    ],

    b'-c|-m|FILE REV')
def perfbdiff(ui, repo, file_, rev=None, count=None, threads=0, **opts):
    """benchmark a bdiff between revisions

    By default, benchmark a bdiff between its delta parent and itself.

    With ``--count``, benchmark bdiffs between delta parents and self for N
    revisions starting at the specified revision.

    With ``--alldata``, assume the requested revision is a changeset and
    measure bdiffs for all changes related to that changeset (manifest
    and filelogs).
    """
    opts = _byteskwargs(opts)

    if opts[b'xdiff'] and not opts[b'blocks']:
        raise error.CommandError(b'perfbdiff', b'--xdiff requires --blocks')

    if opts[b'alldata']:
        opts[b'changelog'] = True

    if opts.get(b'changelog') or opts.get(b'manifest'):
        file_, rev = None, file_
    elif rev is None:
        raise error.CommandError(b'perfbdiff', b'invalid arguments')

    blocks = opts[b'blocks']
    xdiff = opts[b'xdiff']
    textpairs = []

    r = cmdutil.openrevlog(repo, b'perfbdiff', file_, opts)

    startrev = r.rev(r.lookup(rev))
    for rev in range(startrev, min(startrev + count, len(r) - 1)):
        if opts[b'alldata']:
            # Load revisions associated with changeset.
            ctx = repo[rev]
            mtext = _manifestrevision(repo, ctx.manifestnode())
            for pctx in ctx.parents():
                pman = _manifestrevision(repo, pctx.manifestnode())
                textpairs.append((pman, mtext))

            # Load filelog revisions by iterating manifest delta.
            man = ctx.manifest()
            pman = ctx.p1().manifest()
            for filename, change in pman.diff(man).items():
                fctx = repo.file(filename)
                f1 = fctx.revision(change[0][0] or -1)
                f2 = fctx.revision(change[1][0] or -1)
                textpairs.append((f1, f2))
        else:
            dp = r.deltaparent(rev)
            textpairs.append((r.revision(dp), r.revision(rev)))

    withthreads = threads > 0
    if not withthreads:
        def d():
            for pair in textpairs:
                if xdiff:
                    mdiff.bdiff.xdiffblocks(*pair)
                elif blocks:
                    mdiff.bdiff.blocks(*pair)
                else:
                    mdiff.textdiff(*pair)
    else:
        q = queue()
        for i in _xrange(threads):
            q.put(None)
        ready = threading.Condition()
        done = threading.Event()
        for i in _xrange(threads):
            threading.Thread(target=_bdiffworker,
                             args=(q, blocks, xdiff, ready, done)).start()
        q.join()
        def d():
            for pair in textpairs:
                q.put(pair)
            for i in _xrange(threads):
                q.put(None)
            with ready:
                ready.notify_all()
            q.join()
    timer, fm = gettimer(ui, opts)
    timer(d)
    fm.end()

    if withthreads:
        done.set()
        for i in _xrange(threads):
            q.put(None)
        with ready:
            ready.notify_all()

@command(b'perfunidiff', revlogopts + formatteropts + [
    (b'', b'count', 1, b'number of revisions to test (when using --startrev)'),
    (b'', b'alldata', False, b'test unidiffs for all associated revisions'),
    ], b'-c|-m|FILE REV')
def perfunidiff(ui, repo, file_, rev=None, count=None, **opts):
    """benchmark a unified diff between revisions

    This doesn't include any copy tracing - it's just a unified diff
    of the texts.

    By default, benchmark a diff between its delta parent and itself.

    With ``--count``, benchmark diffs between delta parents and self for N
    revisions starting at the specified revision.

    With ``--alldata``, assume the requested revision is a changeset and
    measure diffs for all changes related to that changeset (manifest
    and filelogs).
    """
    opts = _byteskwargs(opts)
    if opts[b'alldata']:
        opts[b'changelog'] = True

    if opts.get(b'changelog') or opts.get(b'manifest'):
        file_, rev = None, file_
    elif rev is None:
        raise error.CommandError(b'perfunidiff', b'invalid arguments')

    textpairs = []

    r = cmdutil.openrevlog(repo, b'perfunidiff', file_, opts)

    startrev = r.rev(r.lookup(rev))
    for rev in range(startrev, min(startrev + count, len(r) - 1)):
        if opts[b'alldata']:
            # Load revisions associated with changeset.
            ctx = repo[rev]
            mtext = _manifestrevision(repo, ctx.manifestnode())
            for pctx in ctx.parents():
                pman = _manifestrevision(repo, pctx.manifestnode())
                textpairs.append((pman, mtext))

            # Load filelog revisions by iterating manifest delta.
            man = ctx.manifest()
            pman = ctx.p1().manifest()
            for filename, change in pman.diff(man).items():
                fctx = repo.file(filename)
                f1 = fctx.revision(change[0][0] or -1)
                f2 = fctx.revision(change[1][0] or -1)
                textpairs.append((f1, f2))
        else:
            dp = r.deltaparent(rev)
            textpairs.append((r.revision(dp), r.revision(rev)))

    def d():
        for left, right in textpairs:
            # The date strings don't matter, so we pass empty strings.
            headerlines, hunks = mdiff.unidiff(
                left, b'', right, b'', b'left', b'right', binary=False)
            # consume iterators in roughly the way patch.py does
            b'\n'.join(headerlines)
            b''.join(sum((list(hlines) for hrange, hlines in hunks), []))
    timer, fm = gettimer(ui, opts)
    timer(d)
    fm.end()

@command(b'perfdiffwd', formatteropts)
def perfdiffwd(ui, repo, **opts):
    """Profile diff of working directory changes"""
    opts = _byteskwargs(opts)
    timer, fm = gettimer(ui, opts)
    options = {
        'w': 'ignore_all_space',
        'b': 'ignore_space_change',
        'B': 'ignore_blank_lines',
        }

    for diffopt in ('', 'w', 'b', 'B', 'wB'):
        opts = dict((options[c], b'1') for c in diffopt)
        def d():
            ui.pushbuffer()
            commands.diff(ui, repo, **opts)
            ui.popbuffer()
        diffopt = diffopt.encode('ascii')
        title = b'diffopts: %s' % (diffopt and (b'-' + diffopt) or b'none')
        timer(d, title)
    fm.end()

@command(b'perfrevlogindex', revlogopts + formatteropts,
         b'-c|-m|FILE')
def perfrevlogindex(ui, repo, file_=None, **opts):
    """Benchmark operations against a revlog index.

    This tests constructing a revlog instance, reading index data,
    parsing index data, and performing various operations related to
    index data.
    """

    opts = _byteskwargs(opts)

    rl = cmdutil.openrevlog(repo, b'perfrevlogindex', file_, opts)

    opener = getattr(rl, 'opener')  # trick linter
    indexfile = rl.indexfile
    data = opener.read(indexfile)

    header = struct.unpack(b'>I', data[0:4])[0]
    version = header & 0xFFFF
    if version == 1:
        revlogio = revlog.revlogio()
        inline = header & (1 << 16)
    else:
        raise error.Abort((b'unsupported revlog version: %d') % version)

    rllen = len(rl)

    node0 = rl.node(0)
    node25 = rl.node(rllen // 4)
    node50 = rl.node(rllen // 2)
    node75 = rl.node(rllen // 4 * 3)
    node100 = rl.node(rllen - 1)

    allrevs = range(rllen)
    allrevsrev = list(reversed(allrevs))
    allnodes = [rl.node(rev) for rev in range(rllen)]
    allnodesrev = list(reversed(allnodes))

    def constructor():
        revlog.revlog(opener, indexfile)

    def read():
        with opener(indexfile) as fh:
            fh.read()

    def parseindex():
        revlogio.parseindex(data, inline)

    def getentry(revornode):
        index = revlogio.parseindex(data, inline)[0]
        index[revornode]

    def getentries(revs, count=1):
        index = revlogio.parseindex(data, inline)[0]

        for i in range(count):
            for rev in revs:
                index[rev]

    def resolvenode(node):
        nodemap = revlogio.parseindex(data, inline)[1]
        # This only works for the C code.
        if nodemap is None:
            return

        try:
            nodemap[node]
        except error.RevlogError:
            pass

    def resolvenodes(nodes, count=1):
        nodemap = revlogio.parseindex(data, inline)[1]
        if nodemap is None:
            return

        for i in range(count):
            for node in nodes:
                try:
                    nodemap[node]
                except error.RevlogError:
                    pass

    benches = [
        (constructor, b'revlog constructor'),
        (read, b'read'),
        (parseindex, b'create index object'),
        (lambda: getentry(0), b'retrieve index entry for rev 0'),
        (lambda: resolvenode(b'a' * 20), b'look up missing node'),
        (lambda: resolvenode(node0), b'look up node at rev 0'),
        (lambda: resolvenode(node25), b'look up node at 1/4 len'),
        (lambda: resolvenode(node50), b'look up node at 1/2 len'),
        (lambda: resolvenode(node75), b'look up node at 3/4 len'),
        (lambda: resolvenode(node100), b'look up node at tip'),
        # 2x variation is to measure caching impact.
        (lambda: resolvenodes(allnodes),
         b'look up all nodes (forward)'),
        (lambda: resolvenodes(allnodes, 2),
         b'look up all nodes 2x (forward)'),
        (lambda: resolvenodes(allnodesrev),
         b'look up all nodes (reverse)'),
        (lambda: resolvenodes(allnodesrev, 2),
         b'look up all nodes 2x (reverse)'),
        (lambda: getentries(allrevs),
         b'retrieve all index entries (forward)'),
        (lambda: getentries(allrevs, 2),
         b'retrieve all index entries 2x (forward)'),
        (lambda: getentries(allrevsrev),
         b'retrieve all index entries (reverse)'),
        (lambda: getentries(allrevsrev, 2),
         b'retrieve all index entries 2x (reverse)'),
    ]

    for fn, title in benches:
        timer, fm = gettimer(ui, opts)
        timer(fn, title=title)
        fm.end()

@command(b'perfrevlogrevisions', revlogopts + formatteropts +
         [(b'd', b'dist', 100, b'distance between the revisions'),
          (b's', b'startrev', 0, b'revision to start reading at'),
          (b'', b'reverse', False, b'read in reverse')],
         b'-c|-m|FILE')
def perfrevlogrevisions(ui, repo, file_=None, startrev=0, reverse=False,
                        **opts):
    """Benchmark reading a series of revisions from a revlog.

    By default, we read every ``-d/--dist`` revision from 0 to tip of
    the specified revlog.

    The start revision can be defined via ``-s/--startrev``.
    """
    opts = _byteskwargs(opts)

    rl = cmdutil.openrevlog(repo, b'perfrevlogrevisions', file_, opts)
    rllen = getlen(ui)(rl)

    if startrev < 0:
        startrev = rllen + startrev

    def d():
        rl.clearcaches()

        beginrev = startrev
        endrev = rllen
        dist = opts[b'dist']

        if reverse:
            beginrev, endrev = endrev, beginrev
            dist = -1 * dist

        for x in _xrange(beginrev, endrev, dist):
            # Old revisions don't support passing int.
            n = rl.node(x)
            rl.revision(n)

    timer, fm = gettimer(ui, opts)
    timer(d)
    fm.end()

@command(b'perfrevlogchunks', revlogopts + formatteropts +
         [(b'e', b'engines', b'', b'compression engines to use'),
          (b's', b'startrev', 0, b'revision to start at')],
         b'-c|-m|FILE')
def perfrevlogchunks(ui, repo, file_=None, engines=None, startrev=0, **opts):
    """Benchmark operations on revlog chunks.

    Logically, each revlog is a collection of fulltext revisions. However,
    stored within each revlog are "chunks" of possibly compressed data. This
    data needs to be read and decompressed or compressed and written.

    This command measures the time it takes to read+decompress and recompress
    chunks in a revlog. It effectively isolates I/O and compression performance.
    For measurements of higher-level operations like resolving revisions,
    see ``perfrevlogrevisions`` and ``perfrevlogrevision``.
    """
    opts = _byteskwargs(opts)

    rl = cmdutil.openrevlog(repo, b'perfrevlogchunks', file_, opts)

    # _chunkraw was renamed to _getsegmentforrevs.
    try:
        segmentforrevs = rl._getsegmentforrevs
    except AttributeError:
        segmentforrevs = rl._chunkraw

    # Verify engines argument.
    if engines:
        engines = set(e.strip() for e in engines.split(b','))
        for engine in engines:
            try:
                util.compressionengines[engine]
            except KeyError:
                raise error.Abort(b'unknown compression engine: %s' % engine)
    else:
        engines = []
        for e in util.compengines:
            engine = util.compengines[e]
            try:
                if engine.available():
                    engine.revlogcompressor().compress(b'dummy')
                    engines.append(e)
            except NotImplementedError:
                pass

    revs = list(rl.revs(startrev, len(rl) - 1))

    def rlfh(rl):
        if rl._inline:
            return getsvfs(repo)(rl.indexfile)
        else:
            return getsvfs(repo)(rl.datafile)

    def doread():
        rl.clearcaches()
        for rev in revs:
            segmentforrevs(rev, rev)

    def doreadcachedfh():
        rl.clearcaches()
        fh = rlfh(rl)
        for rev in revs:
            segmentforrevs(rev, rev, df=fh)

    def doreadbatch():
        rl.clearcaches()
        segmentforrevs(revs[0], revs[-1])

    def doreadbatchcachedfh():
        rl.clearcaches()
        fh = rlfh(rl)
        segmentforrevs(revs[0], revs[-1], df=fh)

    def dochunk():
        rl.clearcaches()
        fh = rlfh(rl)
        for rev in revs:
            rl._chunk(rev, df=fh)

    chunks = [None]

    def dochunkbatch():
        rl.clearcaches()
        fh = rlfh(rl)
        # Save chunks as a side-effect.
        chunks[0] = rl._chunks(revs, df=fh)

    def docompress(compressor):
        rl.clearcaches()

        try:
            # Swap in the requested compression engine.
            oldcompressor = rl._compressor
            rl._compressor = compressor
            for chunk in chunks[0]:
                rl.compress(chunk)
        finally:
            rl._compressor = oldcompressor

    benches = [
        (lambda: doread(), b'read'),
        (lambda: doreadcachedfh(), b'read w/ reused fd'),
        (lambda: doreadbatch(), b'read batch'),
        (lambda: doreadbatchcachedfh(), b'read batch w/ reused fd'),
        (lambda: dochunk(), b'chunk'),
        (lambda: dochunkbatch(), b'chunk batch'),
    ]

    for engine in sorted(engines):
        compressor = util.compengines[engine].revlogcompressor()
        benches.append((functools.partial(docompress, compressor),
                        b'compress w/ %s' % engine))

    for fn, title in benches:
        timer, fm = gettimer(ui, opts)
        timer(fn, title=title)
        fm.end()

@command(b'perfrevlogrevision', revlogopts + formatteropts +
         [(b'', b'cache', False, b'use caches instead of clearing')],
         b'-c|-m|FILE REV')
def perfrevlogrevision(ui, repo, file_, rev=None, cache=None, **opts):
    """Benchmark obtaining a revlog revision.

    Obtaining a revlog revision consists of roughly the following steps:

    1. Compute the delta chain
    2. Obtain the raw chunks for that delta chain
    3. Decompress each raw chunk
    4. Apply binary patches to obtain fulltext
    5. Verify hash of fulltext

    This command measures the time spent in each of these phases.
    """
    opts = _byteskwargs(opts)

    if opts.get(b'changelog') or opts.get(b'manifest'):
        file_, rev = None, file_
    elif rev is None:
        raise error.CommandError(b'perfrevlogrevision', b'invalid arguments')

    r = cmdutil.openrevlog(repo, b'perfrevlogrevision', file_, opts)

    # _chunkraw was renamed to _getsegmentforrevs.
    try:
        segmentforrevs = r._getsegmentforrevs
    except AttributeError:
        segmentforrevs = r._chunkraw

    node = r.lookup(rev)
    rev = r.rev(node)

    def getrawchunks(data, chain):
        start = r.start
        length = r.length
        inline = r._inline
        iosize = r._io.size
        buffer = util.buffer
        offset = start(chain[0])

        chunks = []
        ladd = chunks.append

        for rev in chain:
            chunkstart = start(rev)
            if inline:
                chunkstart += (rev + 1) * iosize
            chunklength = length(rev)
            ladd(buffer(data, chunkstart - offset, chunklength))

        return chunks

    def dodeltachain(rev):
        if not cache:
            r.clearcaches()
        r._deltachain(rev)

    def doread(chain):
        if not cache:
            r.clearcaches()
        segmentforrevs(chain[0], chain[-1])

    def dorawchunks(data, chain):
        if not cache:
            r.clearcaches()
        getrawchunks(data, chain)

    def dodecompress(chunks):
        decomp = r.decompress
        for chunk in chunks:
            decomp(chunk)

    def dopatch(text, bins):
        if not cache:
            r.clearcaches()
        mdiff.patches(text, bins)

    def dohash(text):
        if not cache:
            r.clearcaches()
        r.checkhash(text, node, rev=rev)

    def dorevision():
        if not cache:
            r.clearcaches()
        r.revision(node)

    chain = r._deltachain(rev)[0]
    data = segmentforrevs(chain[0], chain[-1])[1]
    rawchunks = getrawchunks(data, chain)
    bins = r._chunks(chain)
    text = bytes(bins[0])
    bins = bins[1:]
    text = mdiff.patches(text, bins)

    benches = [
        (lambda: dorevision(), b'full'),
        (lambda: dodeltachain(rev), b'deltachain'),
        (lambda: doread(chain), b'read'),
        (lambda: dorawchunks(data, chain), b'rawchunks'),
        (lambda: dodecompress(rawchunks), b'decompress'),
        (lambda: dopatch(text, bins), b'patch'),
        (lambda: dohash(text), b'hash'),
    ]

    for fn, title in benches:
        timer, fm = gettimer(ui, opts)
        timer(fn, title=title)
        fm.end()

@command(b'perfrevset',
         [(b'C', b'clear', False, b'clear volatile cache between each call.'),
          (b'', b'contexts', False, b'obtain changectx for each revision')]
         + formatteropts, b"REVSET")
def perfrevset(ui, repo, expr, clear=False, contexts=False, **opts):
    """benchmark the execution time of a revset

    Use the --clean option if need to evaluate the impact of build volatile
    revisions set cache on the revset execution. Volatile cache hold filtered
    and obsolete related cache."""
    opts = _byteskwargs(opts)

    timer, fm = gettimer(ui, opts)
    def d():
        if clear:
            repo.invalidatevolatilesets()
        if contexts:
            for ctx in repo.set(expr): pass
        else:
            for r in repo.revs(expr): pass
    timer(d)
    fm.end()

@command(b'perfvolatilesets',
         [(b'', b'clear-obsstore', False, b'drop obsstore between each call.'),
          ] + formatteropts)
def perfvolatilesets(ui, repo, *names, **opts):
    """benchmark the computation of various volatile set

    Volatile set computes element related to filtering and obsolescence."""
    opts = _byteskwargs(opts)
    timer, fm = gettimer(ui, opts)
    repo = repo.unfiltered()

    def getobs(name):
        def d():
            repo.invalidatevolatilesets()
            if opts[b'clear_obsstore']:
                clearfilecache(repo, b'obsstore')
            obsolete.getrevs(repo, name)
        return d

    allobs = sorted(obsolete.cachefuncs)
    if names:
        allobs = [n for n in allobs if n in names]

    for name in allobs:
        timer(getobs(name), title=name)

    def getfiltered(name):
        def d():
            repo.invalidatevolatilesets()
            if opts[b'clear_obsstore']:
                clearfilecache(repo, b'obsstore')
            repoview.filterrevs(repo, name)
        return d

    allfilter = sorted(repoview.filtertable)
    if names:
        allfilter = [n for n in allfilter if n in names]

    for name in allfilter:
        timer(getfiltered(name), title=name)
    fm.end()

@command(b'perfbranchmap',
         [(b'f', b'full', False,
           b'Includes build time of subset'),
          (b'', b'clear-revbranch', False,
           b'purge the revbranch cache between computation'),
          ] + formatteropts)
def perfbranchmap(ui, repo, *filternames, **opts):
    """benchmark the update of a branchmap

    This benchmarks the full repo.branchmap() call with read and write disabled
    """
    opts = _byteskwargs(opts)
    full = opts.get(b"full", False)
    clear_revbranch = opts.get(b"clear_revbranch", False)
    timer, fm = gettimer(ui, opts)
    def getbranchmap(filtername):
        """generate a benchmark function for the filtername"""
        if filtername is None:
            view = repo
        else:
            view = repo.filtered(filtername)
        def d():
            if clear_revbranch:
                repo.revbranchcache()._clear()
            if full:
                view._branchcaches.clear()
            else:
                view._branchcaches.pop(filtername, None)
            view.branchmap()
        return d
    # add filter in smaller subset to bigger subset
    possiblefilters = set(repoview.filtertable)
    if filternames:
        possiblefilters &= set(filternames)
    subsettable = getbranchmapsubsettable()
    allfilters = []
    while possiblefilters:
        for name in possiblefilters:
            subset = subsettable.get(name)
            if subset not in possiblefilters:
                break
        else:
            assert False, b'subset cycle %s!' % possiblefilters
        allfilters.append(name)
        possiblefilters.remove(name)

    # warm the cache
    if not full:
        for name in allfilters:
            repo.filtered(name).branchmap()
    if not filternames or b'unfiltered' in filternames:
        # add unfiltered
        allfilters.append(None)

    branchcacheread = safeattrsetter(branchmap, b'read')
    branchcachewrite = safeattrsetter(branchmap.branchcache, b'write')
    branchcacheread.set(lambda repo: None)
    branchcachewrite.set(lambda bc, repo: None)
    try:
        for name in allfilters:
            printname = name
            if name is None:
                printname = b'unfiltered'
            timer(getbranchmap(name), title=str(printname))
    finally:
        branchcacheread.restore()
        branchcachewrite.restore()
    fm.end()

@command(b'perfbranchmapload', [
     (b'f', b'filter', b'', b'Specify repoview filter'),
     (b'', b'list', False, b'List brachmap filter caches'),
    ] + formatteropts)
def perfbranchmapread(ui, repo, filter=b'', list=False, **opts):
    """benchmark reading the branchmap"""
    opts = _byteskwargs(opts)

    if list:
        for name, kind, st in repo.cachevfs.readdir(stat=True):
            if name.startswith(b'branch2'):
                filtername = name.partition(b'-')[2] or b'unfiltered'
                ui.status(b'%s - %s\n'
                          % (filtername, util.bytecount(st.st_size)))
        return
    if filter:
        repo = repoview.repoview(repo, filter)
    else:
        repo = repo.unfiltered()
    # try once without timer, the filter may not be cached
    if branchmap.read(repo) is None:
        raise error.Abort(b'No brachmap cached for %s repo'
                          % (filter or b'unfiltered'))
    timer, fm = gettimer(ui, opts)
    timer(lambda: branchmap.read(repo) and None)
    fm.end()

@command(b'perfloadmarkers')
def perfloadmarkers(ui, repo):
    """benchmark the time to parse the on-disk markers for a repo

    Result is the number of markers in the repo."""
    timer, fm = gettimer(ui)
    svfs = getsvfs(repo)
    timer(lambda: len(obsolete.obsstore(svfs)))
    fm.end()

@command(b'perflrucachedict', formatteropts +
    [(b'', b'costlimit', 0, b'maximum total cost of items in cache'),
     (b'', b'mincost', 0, b'smallest cost of items in cache'),
     (b'', b'maxcost', 100, b'maximum cost of items in cache'),
     (b'', b'size', 4, b'size of cache'),
     (b'', b'gets', 10000, b'number of key lookups'),
     (b'', b'sets', 10000, b'number of key sets'),
     (b'', b'mixed', 10000, b'number of mixed mode operations'),
     (b'', b'mixedgetfreq', 50, b'frequency of get vs set ops in mixed mode')],
    norepo=True)
def perflrucache(ui, mincost=0, maxcost=100, costlimit=0, size=4,
                 gets=10000, sets=10000, mixed=10000, mixedgetfreq=50, **opts):
    opts = _byteskwargs(opts)

    def doinit():
        for i in _xrange(10000):
            util.lrucachedict(size)

    costrange = list(range(mincost, maxcost + 1))

    values = []
    for i in _xrange(size):
        values.append(random.randint(0, _maxint))

    # Get mode fills the cache and tests raw lookup performance with no
    # eviction.
    getseq = []
    for i in _xrange(gets):
        getseq.append(random.choice(values))

    def dogets():
        d = util.lrucachedict(size)
        for v in values:
            d[v] = v
        for key in getseq:
            value = d[key]
            value # silence pyflakes warning

    def dogetscost():
        d = util.lrucachedict(size, maxcost=costlimit)
        for i, v in enumerate(values):
            d.insert(v, v, cost=costs[i])
        for key in getseq:
            try:
                value = d[key]
                value # silence pyflakes warning
            except KeyError:
                pass

    # Set mode tests insertion speed with cache eviction.
    setseq = []
    costs = []
    for i in _xrange(sets):
        setseq.append(random.randint(0, _maxint))
        costs.append(random.choice(costrange))

    def doinserts():
        d = util.lrucachedict(size)
        for v in setseq:
            d.insert(v, v)

    def doinsertscost():
        d = util.lrucachedict(size, maxcost=costlimit)
        for i, v in enumerate(setseq):
            d.insert(v, v, cost=costs[i])

    def dosets():
        d = util.lrucachedict(size)
        for v in setseq:
            d[v] = v

    # Mixed mode randomly performs gets and sets with eviction.
    mixedops = []
    for i in _xrange(mixed):
        r = random.randint(0, 100)
        if r < mixedgetfreq:
            op = 0
        else:
            op = 1

        mixedops.append((op,
                         random.randint(0, size * 2),
                         random.choice(costrange)))

    def domixed():
        d = util.lrucachedict(size)

        for op, v, cost in mixedops:
            if op == 0:
                try:
                    d[v]
                except KeyError:
                    pass
            else:
                d[v] = v

    def domixedcost():
        d = util.lrucachedict(size, maxcost=costlimit)

        for op, v, cost in mixedops:
            if op == 0:
                try:
                    d[v]
                except KeyError:
                    pass
            else:
                d.insert(v, v, cost=cost)

    benches = [
        (doinit, b'init'),
    ]

    if costlimit:
        benches.extend([
            (dogetscost, b'gets w/ cost limit'),
            (doinsertscost, b'inserts w/ cost limit'),
            (domixedcost, b'mixed w/ cost limit'),
        ])
    else:
        benches.extend([
            (dogets, b'gets'),
            (doinserts, b'inserts'),
            (dosets, b'sets'),
            (domixed, b'mixed')
        ])

    for fn, title in benches:
        timer, fm = gettimer(ui, opts)
        timer(fn, title=title)
        fm.end()

@command(b'perfwrite', formatteropts)
def perfwrite(ui, repo, **opts):
    """microbenchmark ui.write
    """
    opts = _byteskwargs(opts)

    timer, fm = gettimer(ui, opts)
    def write():
        for i in range(100000):
            ui.write((b'Testing write performance\n'))
    timer(write)
    fm.end()

def uisetup(ui):
    if (util.safehasattr(cmdutil, b'openrevlog') and
        not util.safehasattr(commands, b'debugrevlogopts')):
        # for "historical portability":
        # In this case, Mercurial should be 1.9 (or a79fea6b3e77) -
        # 3.7 (or 5606f7d0d063). Therefore, '--dir' option for
        # openrevlog() should cause failure, because it has been
        # available since 3.5 (or 49c583ca48c4).
        def openrevlog(orig, repo, cmd, file_, opts):
            if opts.get(b'dir') and not util.safehasattr(repo, b'dirlog'):
                raise error.Abort(b"This version doesn't support --dir option",
                                  hint=b"use 3.5 or later")
            return orig(repo, cmd, file_, opts)
        extensions.wrapfunction(cmdutil, b'openrevlog', openrevlog)
