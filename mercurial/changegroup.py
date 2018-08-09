# changegroup.py - Mercurial changegroup manipulation functions
#
#  Copyright 2006 Matt Mackall <mpm@selenic.com>
#
# This software may be used and distributed according to the terms of the
# GNU General Public License version 2 or any later version.

from __future__ import absolute_import

import os
import struct
import weakref

from .i18n import _
from .node import (
    hex,
    nullid,
    nullrev,
    short,
)

from .thirdparty import (
    attr,
)

from . import (
    dagop,
    error,
    match as matchmod,
    mdiff,
    phases,
    pycompat,
    repository,
    revlog,
    util,
)

from .utils import (
    stringutil,
)

_CHANGEGROUPV1_DELTA_HEADER = struct.Struct("20s20s20s20s")
_CHANGEGROUPV2_DELTA_HEADER = struct.Struct("20s20s20s20s20s")
_CHANGEGROUPV3_DELTA_HEADER = struct.Struct(">20s20s20s20s20sH")

LFS_REQUIREMENT = 'lfs'

readexactly = util.readexactly

def getchunk(stream):
    """return the next chunk from stream as a string"""
    d = readexactly(stream, 4)
    l = struct.unpack(">l", d)[0]
    if l <= 4:
        if l:
            raise error.Abort(_("invalid chunk length %d") % l)
        return ""
    return readexactly(stream, l - 4)

def chunkheader(length):
    """return a changegroup chunk header (string)"""
    return struct.pack(">l", length + 4)

def closechunk():
    """return a changegroup chunk header (string) for a zero-length chunk"""
    return struct.pack(">l", 0)

def _fileheader(path):
    """Obtain a changegroup chunk header for a named path."""
    return chunkheader(len(path)) + path

def writechunks(ui, chunks, filename, vfs=None):
    """Write chunks to a file and return its filename.

    The stream is assumed to be a bundle file.
    Existing files will not be overwritten.
    If no filename is specified, a temporary file is created.
    """
    fh = None
    cleanup = None
    try:
        if filename:
            if vfs:
                fh = vfs.open(filename, "wb")
            else:
                # Increase default buffer size because default is usually
                # small (4k is common on Linux).
                fh = open(filename, "wb", 131072)
        else:
            fd, filename = pycompat.mkstemp(prefix="hg-bundle-", suffix=".hg")
            fh = os.fdopen(fd, r"wb")
        cleanup = filename
        for c in chunks:
            fh.write(c)
        cleanup = None
        return filename
    finally:
        if fh is not None:
            fh.close()
        if cleanup is not None:
            if filename and vfs:
                vfs.unlink(cleanup)
            else:
                os.unlink(cleanup)

class cg1unpacker(object):
    """Unpacker for cg1 changegroup streams.

    A changegroup unpacker handles the framing of the revision data in
    the wire format. Most consumers will want to use the apply()
    method to add the changes from the changegroup to a repository.

    If you're forwarding a changegroup unmodified to another consumer,
    use getchunks(), which returns an iterator of changegroup
    chunks. This is mostly useful for cases where you need to know the
    data stream has ended by observing the end of the changegroup.

    deltachunk() is useful only if you're applying delta data. Most
    consumers should prefer apply() instead.

    A few other public methods exist. Those are used only for
    bundlerepo and some debug commands - their use is discouraged.
    """
    deltaheader = _CHANGEGROUPV1_DELTA_HEADER
    deltaheadersize = deltaheader.size
    version = '01'
    _grouplistcount = 1 # One list of files after the manifests

    def __init__(self, fh, alg, extras=None):
        if alg is None:
            alg = 'UN'
        if alg not in util.compengines.supportedbundletypes:
            raise error.Abort(_('unknown stream compression type: %s')
                             % alg)
        if alg == 'BZ':
            alg = '_truncatedBZ'

        compengine = util.compengines.forbundletype(alg)
        self._stream = compengine.decompressorreader(fh)
        self._type = alg
        self.extras = extras or {}
        self.callback = None

    # These methods (compressed, read, seek, tell) all appear to only
    # be used by bundlerepo, but it's a little hard to tell.
    def compressed(self):
        return self._type is not None and self._type != 'UN'
    def read(self, l):
        return self._stream.read(l)
    def seek(self, pos):
        return self._stream.seek(pos)
    def tell(self):
        return self._stream.tell()
    def close(self):
        return self._stream.close()

    def _chunklength(self):
        d = readexactly(self._stream, 4)
        l = struct.unpack(">l", d)[0]
        if l <= 4:
            if l:
                raise error.Abort(_("invalid chunk length %d") % l)
            return 0
        if self.callback:
            self.callback()
        return l - 4

    def changelogheader(self):
        """v10 does not have a changelog header chunk"""
        return {}

    def manifestheader(self):
        """v10 does not have a manifest header chunk"""
        return {}

    def filelogheader(self):
        """return the header of the filelogs chunk, v10 only has the filename"""
        l = self._chunklength()
        if not l:
            return {}
        fname = readexactly(self._stream, l)
        return {'filename': fname}

    def _deltaheader(self, headertuple, prevnode):
        node, p1, p2, cs = headertuple
        if prevnode is None:
            deltabase = p1
        else:
            deltabase = prevnode
        flags = 0
        return node, p1, p2, deltabase, cs, flags

    def deltachunk(self, prevnode):
        l = self._chunklength()
        if not l:
            return {}
        headerdata = readexactly(self._stream, self.deltaheadersize)
        header = self.deltaheader.unpack(headerdata)
        delta = readexactly(self._stream, l - self.deltaheadersize)
        node, p1, p2, deltabase, cs, flags = self._deltaheader(header, prevnode)
        return (node, p1, p2, cs, deltabase, delta, flags)

    def getchunks(self):
        """returns all the chunks contains in the bundle

        Used when you need to forward the binary stream to a file or another
        network API. To do so, it parse the changegroup data, otherwise it will
        block in case of sshrepo because it don't know the end of the stream.
        """
        # For changegroup 1 and 2, we expect 3 parts: changelog, manifestlog,
        # and a list of filelogs. For changegroup 3, we expect 4 parts:
        # changelog, manifestlog, a list of tree manifestlogs, and a list of
        # filelogs.
        #
        # Changelog and manifestlog parts are terminated with empty chunks. The
        # tree and file parts are a list of entry sections. Each entry section
        # is a series of chunks terminating in an empty chunk. The list of these
        # entry sections is terminated in yet another empty chunk, so we know
        # we've reached the end of the tree/file list when we reach an empty
        # chunk that was proceeded by no non-empty chunks.

        parts = 0
        while parts < 2 + self._grouplistcount:
            noentries = True
            while True:
                chunk = getchunk(self)
                if not chunk:
                    # The first two empty chunks represent the end of the
                    # changelog and the manifestlog portions. The remaining
                    # empty chunks represent either A) the end of individual
                    # tree or file entries in the file list, or B) the end of
                    # the entire list. It's the end of the entire list if there
                    # were no entries (i.e. noentries is True).
                    if parts < 2:
                        parts += 1
                    elif noentries:
                        parts += 1
                    break
                noentries = False
                yield chunkheader(len(chunk))
                pos = 0
                while pos < len(chunk):
                    next = pos + 2**20
                    yield chunk[pos:next]
                    pos = next
            yield closechunk()

    def _unpackmanifests(self, repo, revmap, trp, prog):
        self.callback = prog.increment
        # no need to check for empty manifest group here:
        # if the result of the merge of 1 and 2 is the same in 3 and 4,
        # no new manifest will be created and the manifest group will
        # be empty during the pull
        self.manifestheader()
        deltas = self.deltaiter()
        repo.manifestlog.addgroup(deltas, revmap, trp)
        prog.complete()
        self.callback = None

    def apply(self, repo, tr, srctype, url, targetphase=phases.draft,
              expectedtotal=None):
        """Add the changegroup returned by source.read() to this repo.
        srctype is a string like 'push', 'pull', or 'unbundle'.  url is
        the URL of the repo where this changegroup is coming from.

        Return an integer summarizing the change to this repo:
        - nothing changed or no source: 0
        - more heads than before: 1+added heads (2..n)
        - fewer heads than before: -1-removed heads (-2..-n)
        - number of heads stays the same: 1
        """
        repo = repo.unfiltered()
        def csmap(x):
            repo.ui.debug("add changeset %s\n" % short(x))
            return len(cl)

        def revmap(x):
            return cl.rev(x)

        changesets = files = revisions = 0

        try:
            # The transaction may already carry source information. In this
            # case we use the top level data. We overwrite the argument
            # because we need to use the top level value (if they exist)
            # in this function.
            srctype = tr.hookargs.setdefault('source', srctype)
            url = tr.hookargs.setdefault('url', url)
            repo.hook('prechangegroup',
                      throw=True, **pycompat.strkwargs(tr.hookargs))

            # write changelog data to temp files so concurrent readers
            # will not see an inconsistent view
            cl = repo.changelog
            cl.delayupdate(tr)
            oldheads = set(cl.heads())

            trp = weakref.proxy(tr)
            # pull off the changeset group
            repo.ui.status(_("adding changesets\n"))
            clstart = len(cl)
            progress = repo.ui.makeprogress(_('changesets'), unit=_('chunks'),
                                            total=expectedtotal)
            self.callback = progress.increment

            efiles = set()
            def onchangelog(cl, node):
                efiles.update(cl.readfiles(node))

            self.changelogheader()
            deltas = self.deltaiter()
            cgnodes = cl.addgroup(deltas, csmap, trp, addrevisioncb=onchangelog)
            efiles = len(efiles)

            if not cgnodes:
                repo.ui.develwarn('applied empty changegroup',
                                  config='warn-empty-changegroup')
            clend = len(cl)
            changesets = clend - clstart
            progress.complete()
            self.callback = None

            # pull off the manifest group
            repo.ui.status(_("adding manifests\n"))
            # We know that we'll never have more manifests than we had
            # changesets.
            progress = repo.ui.makeprogress(_('manifests'), unit=_('chunks'),
                                            total=changesets)
            self._unpackmanifests(repo, revmap, trp, progress)

            needfiles = {}
            if repo.ui.configbool('server', 'validate'):
                cl = repo.changelog
                ml = repo.manifestlog
                # validate incoming csets have their manifests
                for cset in pycompat.xrange(clstart, clend):
                    mfnode = cl.changelogrevision(cset).manifest
                    mfest = ml[mfnode].readdelta()
                    # store file cgnodes we must see
                    for f, n in mfest.iteritems():
                        needfiles.setdefault(f, set()).add(n)

            # process the files
            repo.ui.status(_("adding file changes\n"))
            newrevs, newfiles = _addchangegroupfiles(
                repo, self, revmap, trp, efiles, needfiles)
            revisions += newrevs
            files += newfiles

            deltaheads = 0
            if oldheads:
                heads = cl.heads()
                deltaheads = len(heads) - len(oldheads)
                for h in heads:
                    if h not in oldheads and repo[h].closesbranch():
                        deltaheads -= 1
            htext = ""
            if deltaheads:
                htext = _(" (%+d heads)") % deltaheads

            repo.ui.status(_("added %d changesets"
                             " with %d changes to %d files%s\n")
                             % (changesets, revisions, files, htext))
            repo.invalidatevolatilesets()

            if changesets > 0:
                if 'node' not in tr.hookargs:
                    tr.hookargs['node'] = hex(cl.node(clstart))
                    tr.hookargs['node_last'] = hex(cl.node(clend - 1))
                    hookargs = dict(tr.hookargs)
                else:
                    hookargs = dict(tr.hookargs)
                    hookargs['node'] = hex(cl.node(clstart))
                    hookargs['node_last'] = hex(cl.node(clend - 1))
                repo.hook('pretxnchangegroup',
                          throw=True, **pycompat.strkwargs(hookargs))

            added = [cl.node(r) for r in pycompat.xrange(clstart, clend)]
            phaseall = None
            if srctype in ('push', 'serve'):
                # Old servers can not push the boundary themselves.
                # New servers won't push the boundary if changeset already
                # exists locally as secret
                #
                # We should not use added here but the list of all change in
                # the bundle
                if repo.publishing():
                    targetphase = phaseall = phases.public
                else:
                    # closer target phase computation

                    # Those changesets have been pushed from the
                    # outside, their phases are going to be pushed
                    # alongside. Therefor `targetphase` is
                    # ignored.
                    targetphase = phaseall = phases.draft
            if added:
                phases.registernew(repo, tr, targetphase, added)
            if phaseall is not None:
                phases.advanceboundary(repo, tr, phaseall, cgnodes)

            if changesets > 0:

                def runhooks():
                    # These hooks run when the lock releases, not when the
                    # transaction closes. So it's possible for the changelog
                    # to have changed since we last saw it.
                    if clstart >= len(repo):
                        return

                    repo.hook("changegroup", **pycompat.strkwargs(hookargs))

                    for n in added:
                        args = hookargs.copy()
                        args['node'] = hex(n)
                        del args['node_last']
                        repo.hook("incoming", **pycompat.strkwargs(args))

                    newheads = [h for h in repo.heads()
                                if h not in oldheads]
                    repo.ui.log("incoming",
                                "%d incoming changes - new heads: %s\n",
                                len(added),
                                ', '.join([hex(c[:6]) for c in newheads]))

                tr.addpostclose('changegroup-runhooks-%020i' % clstart,
                                lambda tr: repo._afterlock(runhooks))
        finally:
            repo.ui.flush()
        # never return 0 here:
        if deltaheads < 0:
            ret = deltaheads - 1
        else:
            ret = deltaheads + 1
        return ret

    def deltaiter(self):
        """
        returns an iterator of the deltas in this changegroup

        Useful for passing to the underlying storage system to be stored.
        """
        chain = None
        for chunkdata in iter(lambda: self.deltachunk(chain), {}):
            # Chunkdata: (node, p1, p2, cs, deltabase, delta, flags)
            yield chunkdata
            chain = chunkdata[0]

class cg2unpacker(cg1unpacker):
    """Unpacker for cg2 streams.

    cg2 streams add support for generaldelta, so the delta header
    format is slightly different. All other features about the data
    remain the same.
    """
    deltaheader = _CHANGEGROUPV2_DELTA_HEADER
    deltaheadersize = deltaheader.size
    version = '02'

    def _deltaheader(self, headertuple, prevnode):
        node, p1, p2, deltabase, cs = headertuple
        flags = 0
        return node, p1, p2, deltabase, cs, flags

class cg3unpacker(cg2unpacker):
    """Unpacker for cg3 streams.

    cg3 streams add support for exchanging treemanifests and revlog
    flags. It adds the revlog flags to the delta header and an empty chunk
    separating manifests and files.
    """
    deltaheader = _CHANGEGROUPV3_DELTA_HEADER
    deltaheadersize = deltaheader.size
    version = '03'
    _grouplistcount = 2 # One list of manifests and one list of files

    def _deltaheader(self, headertuple, prevnode):
        node, p1, p2, deltabase, cs, flags = headertuple
        return node, p1, p2, deltabase, cs, flags

    def _unpackmanifests(self, repo, revmap, trp, prog):
        super(cg3unpacker, self)._unpackmanifests(repo, revmap, trp, prog)
        for chunkdata in iter(self.filelogheader, {}):
            # If we get here, there are directory manifests in the changegroup
            d = chunkdata["filename"]
            repo.ui.debug("adding %s revisions\n" % d)
            dirlog = repo.manifestlog._revlog.dirlog(d)
            deltas = self.deltaiter()
            if not dirlog.addgroup(deltas, revmap, trp):
                raise error.Abort(_("received dir revlog group is empty"))

class headerlessfixup(object):
    def __init__(self, fh, h):
        self._h = h
        self._fh = fh
    def read(self, n):
        if self._h:
            d, self._h = self._h[:n], self._h[n:]
            if len(d) < n:
                d += readexactly(self._fh, n - len(d))
            return d
        return readexactly(self._fh, n)

@attr.s(slots=True, frozen=True)
class revisiondeltarequest(object):
    """Describes a request to construct a revision delta.

    Instances are converted into ``revisiondelta`` later.
    """
    # Revision whose delta will be generated.
    node = attr.ib()

    # Linknode value.
    linknode = attr.ib()

    # Parent revisions to record in ``revisiondelta`` instance.
    p1node = attr.ib()
    p2node = attr.ib()

    # Base revision that delta should be generated against. If nullid,
    # the full revision data should be populated. If None, the delta
    # may be generated against any base revision that is an ancestor of
    # this revision. If any other value, the delta should be produced
    # against that revision.
    basenode = attr.ib()

    # Whether this should be marked as an ellipsis revision.
    ellipsis = attr.ib(default=False)

@attr.s(slots=True, frozen=True)
class revisiondelta(object):
    """Describes a delta entry in a changegroup.

    Captured data is sufficient to serialize the delta into multiple
    formats.

    ``revision`` and ``delta`` are mutually exclusive.
    """
    # 20 byte node of this revision.
    node = attr.ib()
    # 20 byte nodes of parent revisions.
    p1node = attr.ib()
    p2node = attr.ib()
    # 20 byte node of node this delta is against.
    basenode = attr.ib()
    # 20 byte node of changeset revision this delta is associated with.
    linknode = attr.ib()
    # 2 bytes of flags to apply to revision data.
    flags = attr.ib()
    # Size of base revision this delta is against. May be None if
    # basenode is nullid.
    baserevisionsize = attr.ib()
    # Raw fulltext revision data.
    revision = attr.ib()
    # Delta between the basenode and node.
    delta = attr.ib()

def _revisiondeltatochunks(delta, headerfn):
    """Serialize a revisiondelta to changegroup chunks."""

    # The captured revision delta may be encoded as a delta against
    # a base revision or as a full revision. The changegroup format
    # requires that everything on the wire be deltas. So for full
    # revisions, we need to invent a header that says to rewrite
    # data.

    if delta.delta is not None:
        prefix, data = b'', delta.delta
    elif delta.basenode == nullid:
        data = delta.revision
        prefix = mdiff.trivialdiffheader(len(data))
    else:
        data = delta.revision
        prefix = mdiff.replacediffheader(delta.baserevisionsize,
                                         len(data))

    meta = headerfn(delta)

    yield chunkheader(len(meta) + len(prefix) + len(data))
    yield meta
    if prefix:
        yield prefix
    yield data

def _sortnodesnormal(store, nodes, reorder):
    """Sort nodes for changegroup generation and turn into revnums."""
    # for generaldelta revlogs, we linearize the revs; this will both be
    # much quicker and generate a much smaller bundle
    if (store._generaldelta and reorder is None) or reorder:
        revs = set(store.rev(n) for n in nodes)
        return dagop.linearize(revs, store.parentrevs)
    else:
        return sorted([store.rev(n) for n in nodes])

def _sortnodesellipsis(store, nodes, cl, lookup):
    """Sort nodes for changegroup generation and turn into revnums."""
    # Ellipses serving mode.
    #
    # In a perfect world, we'd generate better ellipsis-ified graphs
    # for non-changelog revlogs. In practice, we haven't started doing
    # that yet, so the resulting DAGs for the manifestlog and filelogs
    # are actually full of bogus parentage on all the ellipsis
    # nodes. This has the side effect that, while the contents are
    # correct, the individual DAGs might be completely out of whack in
    # a case like 882681bc3166 and its ancestors (back about 10
    # revisions or so) in the main hg repo.
    #
    # The one invariant we *know* holds is that the new (potentially
    # bogus) DAG shape will be valid if we order the nodes in the
    # order that they're introduced in dramatis personae by the
    # changelog, so what we do is we sort the non-changelog histories
    # by the order in which they are used by the changelog.
    key = lambda n: cl.rev(lookup(n))
    return [store.rev(n) for n in sorted(nodes, key=key)]

def _handlerevisiondeltarequest(store, request, prevnode):
    """Obtain a revisiondelta from a revisiondeltarequest"""

    node = request.node
    rev = store.rev(node)

    # Requesting a full revision.
    if request.basenode == nullid:
        baserev = nullrev
    # Requesting an explicit revision.
    elif request.basenode is not None:
        baserev = store.rev(request.basenode)
    # Allowing us to choose.
    else:
        p1, p2 = store.parentrevs(rev)
        dp = store.deltaparent(rev)

        if dp == nullrev and store.storedeltachains:
            # Avoid sending full revisions when delta parent is null. Pick prev
            # in that case. It's tempting to pick p1 in this case, as p1 will
            # be smaller in the common case. However, computing a delta against
            # p1 may require resolving the raw text of p1, which could be
            # expensive. The revlog caches should have prev cached, meaning
            # less CPU for changegroup generation. There is likely room to add
            # a flag and/or config option to control this behavior.
            baserev = store.rev(prevnode)
        elif dp == nullrev:
            # revlog is configured to use full snapshot for a reason,
            # stick to full snapshot.
            baserev = nullrev
        elif dp not in (p1, p2, store.rev(prevnode)):
            # Pick prev when we can't be sure remote has the base revision.
            baserev = store.rev(prevnode)
        else:
            baserev = dp

        if baserev != nullrev and not store.candelta(baserev, rev):
            baserev = nullrev

    revision = None
    delta = None
    baserevisionsize = None

    if store.iscensored(baserev) or store.iscensored(rev):
        try:
            revision = store.revision(node, raw=True)
        except error.CensoredNodeError as e:
            revision = e.tombstone

        if baserev != nullrev:
            baserevisionsize = store.rawsize(baserev)

    elif baserev == nullrev:
        revision = store.revision(node, raw=True)
    else:
        delta = store.revdiff(baserev, rev)

    extraflags = revlog.REVIDX_ELLIPSIS if request.ellipsis else 0

    return revisiondelta(
        node=node,
        p1node=request.p1node,
        p2node=request.p2node,
        linknode=request.linknode,
        basenode=store.node(baserev),
        flags=store.flags(rev) | extraflags,
        baserevisionsize=baserevisionsize,
        revision=revision,
        delta=delta,
    )

def _makenarrowdeltarequest(cl, store, ischangelog, rev, node, linkrev,
                            linknode, clrevtolocalrev, fullclnodes,
                            precomputedellipsis):
    linkparents = precomputedellipsis[linkrev]
    def local(clrev):
        """Turn a changelog revnum into a local revnum.

        The ellipsis dag is stored as revnums on the changelog,
        but when we're producing ellipsis entries for
        non-changelog revlogs, we need to turn those numbers into
        something local. This does that for us, and during the
        changelog sending phase will also expand the stored
        mappings as needed.
        """
        if clrev == nullrev:
            return nullrev

        if ischangelog:
            return clrev

        # Walk the ellipsis-ized changelog breadth-first looking for a
        # change that has been linked from the current revlog.
        #
        # For a flat manifest revlog only a single step should be necessary
        # as all relevant changelog entries are relevant to the flat
        # manifest.
        #
        # For a filelog or tree manifest dirlog however not every changelog
        # entry will have been relevant, so we need to skip some changelog
        # nodes even after ellipsis-izing.
        walk = [clrev]
        while walk:
            p = walk[0]
            walk = walk[1:]
            if p in clrevtolocalrev:
                return clrevtolocalrev[p]
            elif p in fullclnodes:
                walk.extend([pp for pp in cl.parentrevs(p)
                                if pp != nullrev])
            elif p in precomputedellipsis:
                walk.extend([pp for pp in precomputedellipsis[p]
                                if pp != nullrev])
            else:
                # In this case, we've got an ellipsis with parents
                # outside the current bundle (likely an
                # incremental pull). We "know" that we can use the
                # value of this same revlog at whatever revision
                # is pointed to by linknode. "Know" is in scare
                # quotes because I haven't done enough examination
                # of edge cases to convince myself this is really
                # a fact - it works for all the (admittedly
                # thorough) cases in our testsuite, but I would be
                # somewhat unsurprised to find a case in the wild
                # where this breaks down a bit. That said, I don't
                # know if it would hurt anything.
                for i in pycompat.xrange(rev, 0, -1):
                    if store.linkrev(i) == clrev:
                        return i
                # We failed to resolve a parent for this node, so
                # we crash the changegroup construction.
                raise error.Abort(
                    'unable to resolve parent while packing %r %r'
                    ' for changeset %r' % (store.indexfile, rev, clrev))

        return nullrev

    if not linkparents or (
        store.parentrevs(rev) == (nullrev, nullrev)):
        p1, p2 = nullrev, nullrev
    elif len(linkparents) == 1:
        p1, = sorted(local(p) for p in linkparents)
        p2 = nullrev
    else:
        p1, p2 = sorted(local(p) for p in linkparents)

    p1node, p2node = store.node(p1), store.node(p2)

    # TODO: try and actually send deltas for ellipsis data blocks
    return revisiondeltarequest(
        node=node,
        p1node=p1node,
        p2node=p2node,
        linknode=linknode,
        basenode=nullid,
        ellipsis=True,
    )

def deltagroup(repo, store, nodes, ischangelog, lookup, forcedeltaparentprev,
               allowreorder,
               units=None,
               ellipses=False, clrevtolocalrev=None, fullclnodes=None,
               precomputedellipsis=None):
    """Calculate deltas for a set of revisions.

    Is a generator of ``revisiondelta`` instances.

    If units is not None, progress detail will be generated, units specifies
    the type of revlog that is touched (changelog, manifest, etc.).
    """
    if not nodes:
        return

    # We perform two passes over the revisions whose data we will emit.
    #
    # In the first pass, we obtain information about the deltas that will
    # be generated. This involves computing linknodes and adjusting the
    # request to take shallow fetching into account. The end result of
    # this pass is a list of "request" objects stating which deltas
    # to obtain.
    #
    # The second pass is simply resolving the requested deltas.

    cl = repo.changelog

    if ischangelog:
        # Changelog doesn't benefit from reordering revisions. So send
        # out revisions in store order.
        # TODO the API would be cleaner if this were controlled by the
        # store producing the deltas.
        revs = sorted(cl.rev(n) for n in nodes)
    elif ellipses:
        revs = _sortnodesellipsis(store, nodes, cl, lookup)
    else:
        revs = _sortnodesnormal(store, nodes, allowreorder)

    # In the first pass, collect info about the deltas we'll be
    # generating.
    requests = []

    # Add the parent of the first rev.
    revs.insert(0, store.parentrevs(revs[0])[0])

    for i in pycompat.xrange(len(revs) - 1):
        prev = revs[i]
        curr = revs[i + 1]

        node = store.node(curr)
        linknode = lookup(node)
        p1node, p2node = store.parents(node)

        if ellipses:
            linkrev = cl.rev(linknode)
            clrevtolocalrev[linkrev] = curr

            # This is a node to send in full, because the changeset it
            # corresponds to was a full changeset.
            if linknode in fullclnodes:
                requests.append(revisiondeltarequest(
                    node=node,
                    p1node=p1node,
                    p2node=p2node,
                    linknode=linknode,
                    basenode=None,
                ))

            elif linkrev not in precomputedellipsis:
                pass
            else:
                requests.append(_makenarrowdeltarequest(
                    cl, store, ischangelog, curr, node, linkrev, linknode,
                    clrevtolocalrev, fullclnodes,
                    precomputedellipsis))
        else:
            requests.append(revisiondeltarequest(
                node=node,
                p1node=p1node,
                p2node=p2node,
                linknode=linknode,
                basenode=store.node(prev) if forcedeltaparentprev else None,
            ))

    # We expect the first pass to be fast, so we only engage the progress
    # meter for constructing the revision deltas.
    progress = None
    if units is not None:
        progress = repo.ui.makeprogress(_('bundling'), unit=units,
                                        total=len(requests))

    prevnode = store.node(revs[0])
    for i, request in enumerate(requests):
        if progress:
            progress.update(i + 1)

        delta = _handlerevisiondeltarequest(store, request, prevnode)

        yield delta

        prevnode = request.node

    if progress:
        progress.complete()

class cgpacker(object):
    def __init__(self, repo, filematcher, version, allowreorder,
                 builddeltaheader, manifestsend,
                 forcedeltaparentprev=False,
                 bundlecaps=None, ellipses=False,
                 shallow=False, ellipsisroots=None, fullnodes=None):
        """Given a source repo, construct a bundler.

        filematcher is a matcher that matches on files to include in the
        changegroup. Used to facilitate sparse changegroups.

        allowreorder controls whether reordering of revisions is allowed.
        This value is used when ``bundle.reorder`` is ``auto`` or isn't
        set.

        forcedeltaparentprev indicates whether delta parents must be against
        the previous revision in a delta group. This should only be used for
        compatibility with changegroup version 1.

        builddeltaheader is a callable that constructs the header for a group
        delta.

        manifestsend is a chunk to send after manifests have been fully emitted.

        ellipses indicates whether ellipsis serving mode is enabled.

        bundlecaps is optional and can be used to specify the set of
        capabilities which can be used to build the bundle. While bundlecaps is
        unused in core Mercurial, extensions rely on this feature to communicate
        capabilities to customize the changegroup packer.

        shallow indicates whether shallow data might be sent. The packer may
        need to pack file contents not introduced by the changes being packed.

        fullnodes is the set of changelog nodes which should not be ellipsis
        nodes. We store this rather than the set of nodes that should be
        ellipsis because for very large histories we expect this to be
        significantly smaller.
        """
        assert filematcher
        self._filematcher = filematcher

        self.version = version
        self._forcedeltaparentprev = forcedeltaparentprev
        self._builddeltaheader = builddeltaheader
        self._manifestsend = manifestsend
        self._ellipses = ellipses

        # Set of capabilities we can use to build the bundle.
        if bundlecaps is None:
            bundlecaps = set()
        self._bundlecaps = bundlecaps
        self._isshallow = shallow
        self._fullclnodes = fullnodes

        # Maps ellipsis revs to their roots at the changelog level.
        self._precomputedellipsis = ellipsisroots

        # experimental config: bundle.reorder
        reorder = repo.ui.config('bundle', 'reorder')
        if reorder == 'auto':
            self._reorder = allowreorder
        else:
            self._reorder = stringutil.parsebool(reorder)

        self._repo = repo

        if self._repo.ui.verbose and not self._repo.ui.debugflag:
            self._verbosenote = self._repo.ui.note
        else:
            self._verbosenote = lambda s: None

    def generate(self, commonrevs, clnodes, fastpathlinkrev, source):
        """Yield a sequence of changegroup byte chunks."""

        repo = self._repo
        cl = repo.changelog

        self._verbosenote(_('uncompressed size of bundle content:\n'))
        size = 0

        clstate, deltas = self._generatechangelog(cl, clnodes)
        for delta in deltas:
            for chunk in _revisiondeltatochunks(delta, self._builddeltaheader):
                size += len(chunk)
                yield chunk

        close = closechunk()
        size += len(close)
        yield closechunk()

        self._verbosenote(_('%8.i (changelog)\n') % size)

        clrevorder = clstate['clrevorder']
        mfs = clstate['mfs']
        changedfiles = clstate['changedfiles']

        # We need to make sure that the linkrev in the changegroup refers to
        # the first changeset that introduced the manifest or file revision.
        # The fastpath is usually safer than the slowpath, because the filelogs
        # are walked in revlog order.
        #
        # When taking the slowpath with reorder=None and the manifest revlog
        # uses generaldelta, the manifest may be walked in the "wrong" order.
        # Without 'clrevorder', we would get an incorrect linkrev (see fix in
        # cc0ff93d0c0c).
        #
        # When taking the fastpath, we are only vulnerable to reordering
        # of the changelog itself. The changelog never uses generaldelta, so
        # it is only reordered when reorder=True. To handle this case, we
        # simply take the slowpath, which already has the 'clrevorder' logic.
        # This was also fixed in cc0ff93d0c0c.
        fastpathlinkrev = fastpathlinkrev and not self._reorder
        # Treemanifests don't work correctly with fastpathlinkrev
        # either, because we don't discover which directory nodes to
        # send along with files. This could probably be fixed.
        fastpathlinkrev = fastpathlinkrev and (
            'treemanifest' not in repo.requirements)

        fnodes = {}  # needed file nodes

        size = 0
        it = self.generatemanifests(
            commonrevs, clrevorder, fastpathlinkrev, mfs, fnodes, source,
            clstate['clrevtomanifestrev'])

        for dir, deltas in it:
            if dir:
                assert self.version == b'03'
                chunk = _fileheader(dir)
                size += len(chunk)
                yield chunk

            for delta in deltas:
                chunks = _revisiondeltatochunks(delta, self._builddeltaheader)
                for chunk in chunks:
                    size += len(chunk)
                    yield chunk

            close = closechunk()
            size += len(close)
            yield close

        self._verbosenote(_('%8.i (manifests)\n') % size)
        yield self._manifestsend

        mfdicts = None
        if self._ellipses and self._isshallow:
            mfdicts = [(self._repo.manifestlog[n].read(), lr)
                       for (n, lr) in mfs.iteritems()]

        mfs.clear()
        clrevs = set(cl.rev(x) for x in clnodes)

        it = self.generatefiles(changedfiles, commonrevs,
                                source, mfdicts, fastpathlinkrev,
                                fnodes, clrevs)

        for path, deltas in it:
            h = _fileheader(path)
            size = len(h)
            yield h

            for delta in deltas:
                chunks = _revisiondeltatochunks(delta, self._builddeltaheader)
                for chunk in chunks:
                    size += len(chunk)
                    yield chunk

            close = closechunk()
            size += len(close)
            yield close

            self._verbosenote(_('%8.i  %s\n') % (size, path))

        yield closechunk()

        if clnodes:
            repo.hook('outgoing', node=hex(clnodes[0]), source=source)

    def _generatechangelog(self, cl, nodes):
        """Generate data for changelog chunks.

        Returns a 2-tuple of a dict containing state and an iterable of
        byte chunks. The state will not be fully populated until the
        chunk stream has been fully consumed.
        """
        clrevorder = {}
        mfs = {} # needed manifests
        mfl = self._repo.manifestlog
        # TODO violates storage abstraction.
        mfrevlog = mfl._revlog
        changedfiles = set()
        clrevtomanifestrev = {}

        # Callback for the changelog, used to collect changed files and
        # manifest nodes.
        # Returns the linkrev node (identity in the changelog case).
        def lookupcl(x):
            c = cl.read(x)
            clrevorder[x] = len(clrevorder)

            if self._ellipses:
                # Only update mfs if x is going to be sent. Otherwise we
                # end up with bogus linkrevs specified for manifests and
                # we skip some manifest nodes that we should otherwise
                # have sent.
                if (x in self._fullclnodes
                    or cl.rev(x) in self._precomputedellipsis):
                    n = c[0]
                    # Record the first changeset introducing this manifest
                    # version.
                    mfs.setdefault(n, x)
                    # Set this narrow-specific dict so we have the lowest
                    # manifest revnum to look up for this cl revnum. (Part of
                    # mapping changelog ellipsis parents to manifest ellipsis
                    # parents)
                    clrevtomanifestrev.setdefault(cl.rev(x), mfrevlog.rev(n))
                # We can't trust the changed files list in the changeset if the
                # client requested a shallow clone.
                if self._isshallow:
                    changedfiles.update(mfl[c[0]].read().keys())
                else:
                    changedfiles.update(c[3])
            else:

                n = c[0]
                # record the first changeset introducing this manifest version
                mfs.setdefault(n, x)
                # Record a complete list of potentially-changed files in
                # this manifest.
                changedfiles.update(c[3])

            return x

        state = {
            'clrevorder': clrevorder,
            'mfs': mfs,
            'changedfiles': changedfiles,
            'clrevtomanifestrev': clrevtomanifestrev,
        }

        gen = deltagroup(
            self._repo, cl, nodes, True, lookupcl,
            self._forcedeltaparentprev,
            # Reorder settings are currently ignored for changelog.
            True,
            ellipses=self._ellipses,
            units=_('changesets'),
            clrevtolocalrev={},
            fullclnodes=self._fullclnodes,
            precomputedellipsis=self._precomputedellipsis)

        return state, gen

    def generatemanifests(self, commonrevs, clrevorder, fastpathlinkrev, mfs,
                          fnodes, source, clrevtolocalrev):
        """Returns an iterator of changegroup chunks containing manifests.

        `source` is unused here, but is used by extensions like remotefilelog to
        change what is sent based in pulls vs pushes, etc.
        """
        repo = self._repo
        mfl = repo.manifestlog
        dirlog = mfl._revlog.dirlog
        tmfnodes = {'': mfs}

        # Callback for the manifest, used to collect linkrevs for filelog
        # revisions.
        # Returns the linkrev node (collected in lookupcl).
        def makelookupmflinknode(dir, nodes):
            if fastpathlinkrev:
                assert not dir
                return mfs.__getitem__

            def lookupmflinknode(x):
                """Callback for looking up the linknode for manifests.

                Returns the linkrev node for the specified manifest.

                SIDE EFFECT:

                1) fclnodes gets populated with the list of relevant
                   file nodes if we're not using fastpathlinkrev
                2) When treemanifests are in use, collects treemanifest nodes
                   to send

                Note that this means manifests must be completely sent to
                the client before you can trust the list of files and
                treemanifests to send.
                """
                clnode = nodes[x]
                mdata = mfl.get(dir, x).readfast(shallow=True)
                for p, n, fl in mdata.iterentries():
                    if fl == 't': # subdirectory manifest
                        subdir = dir + p + '/'
                        tmfclnodes = tmfnodes.setdefault(subdir, {})
                        tmfclnode = tmfclnodes.setdefault(n, clnode)
                        if clrevorder[clnode] < clrevorder[tmfclnode]:
                            tmfclnodes[n] = clnode
                    else:
                        f = dir + p
                        fclnodes = fnodes.setdefault(f, {})
                        fclnode = fclnodes.setdefault(n, clnode)
                        if clrevorder[clnode] < clrevorder[fclnode]:
                            fclnodes[n] = clnode
                return clnode
            return lookupmflinknode

        while tmfnodes:
            dir, nodes = tmfnodes.popitem()
            store = dirlog(dir)

            if not self._filematcher.visitdir(store._dir[:-1] or '.'):
                prunednodes = []
            else:
                frev, flr = store.rev, store.linkrev
                prunednodes = [n for n in nodes
                               if flr(frev(n)) not in commonrevs]

            if dir and not prunednodes:
                continue

            lookupfn = makelookupmflinknode(dir, nodes)

            deltas = deltagroup(
                self._repo, store, prunednodes, False, lookupfn,
                self._forcedeltaparentprev, self._reorder,
                ellipses=self._ellipses,
                units=_('manifests'),
                clrevtolocalrev=clrevtolocalrev,
                fullclnodes=self._fullclnodes,
                precomputedellipsis=self._precomputedellipsis)

            yield dir, deltas

    # The 'source' parameter is useful for extensions
    def generatefiles(self, changedfiles, commonrevs, source,
                      mfdicts, fastpathlinkrev, fnodes, clrevs):
        changedfiles = list(filter(self._filematcher, changedfiles))

        if not fastpathlinkrev:
            def normallinknodes(unused, fname):
                return fnodes.get(fname, {})
        else:
            cln = self._repo.changelog.node

            def normallinknodes(store, fname):
                flinkrev = store.linkrev
                fnode = store.node
                revs = ((r, flinkrev(r)) for r in store)
                return dict((fnode(r), cln(lr))
                            for r, lr in revs if lr in clrevs)

        clrevtolocalrev = {}

        if self._isshallow:
            # In a shallow clone, the linknodes callback needs to also include
            # those file nodes that are in the manifests we sent but weren't
            # introduced by those manifests.
            commonctxs = [self._repo[c] for c in commonrevs]
            clrev = self._repo.changelog.rev

            # Defining this function has a side-effect of overriding the
            # function of the same name that was passed in as an argument.
            # TODO have caller pass in appropriate function.
            def linknodes(flog, fname):
                for c in commonctxs:
                    try:
                        fnode = c.filenode(fname)
                        clrevtolocalrev[c.rev()] = flog.rev(fnode)
                    except error.ManifestLookupError:
                        pass
                links = normallinknodes(flog, fname)
                if len(links) != len(mfdicts):
                    for mf, lr in mfdicts:
                        fnode = mf.get(fname, None)
                        if fnode in links:
                            links[fnode] = min(links[fnode], lr, key=clrev)
                        elif fnode:
                            links[fnode] = lr
                return links
        else:
            linknodes = normallinknodes

        repo = self._repo
        progress = repo.ui.makeprogress(_('bundling'), unit=_('files'),
                                        total=len(changedfiles))
        for i, fname in enumerate(sorted(changedfiles)):
            filerevlog = repo.file(fname)
            if not filerevlog:
                raise error.Abort(_("empty or missing file data for %s") %
                                  fname)

            clrevtolocalrev.clear()

            linkrevnodes = linknodes(filerevlog, fname)
            # Lookup for filenodes, we collected the linkrev nodes above in the
            # fastpath case and with lookupmf in the slowpath case.
            def lookupfilelog(x):
                return linkrevnodes[x]

            frev, flr = filerevlog.rev, filerevlog.linkrev
            filenodes = [n for n in linkrevnodes
                         if flr(frev(n)) not in commonrevs]

            if not filenodes:
                continue

            progress.update(i + 1, item=fname)

            deltas = deltagroup(
                self._repo, filerevlog, filenodes, False, lookupfilelog,
                self._forcedeltaparentprev, self._reorder,
                ellipses=self._ellipses,
                clrevtolocalrev=clrevtolocalrev,
                fullclnodes=self._fullclnodes,
                precomputedellipsis=self._precomputedellipsis)

            yield fname, deltas

        progress.complete()

def _makecg1packer(repo, filematcher, bundlecaps, ellipses=False,
                   shallow=False, ellipsisroots=None, fullnodes=None):
    builddeltaheader = lambda d: _CHANGEGROUPV1_DELTA_HEADER.pack(
        d.node, d.p1node, d.p2node, d.linknode)

    return cgpacker(repo, filematcher, b'01',
                    allowreorder=None,
                    builddeltaheader=builddeltaheader,
                    manifestsend=b'',
                    forcedeltaparentprev=True,
                    bundlecaps=bundlecaps,
                    ellipses=ellipses,
                    shallow=shallow,
                    ellipsisroots=ellipsisroots,
                    fullnodes=fullnodes)

def _makecg2packer(repo, filematcher, bundlecaps, ellipses=False,
                   shallow=False, ellipsisroots=None, fullnodes=None):
    builddeltaheader = lambda d: _CHANGEGROUPV2_DELTA_HEADER.pack(
        d.node, d.p1node, d.p2node, d.basenode, d.linknode)

    # Since generaldelta is directly supported by cg2, reordering
    # generally doesn't help, so we disable it by default (treating
    # bundle.reorder=auto just like bundle.reorder=False).
    return cgpacker(repo, filematcher, b'02',
                    allowreorder=False,
                    builddeltaheader=builddeltaheader,
                    manifestsend=b'',
                    bundlecaps=bundlecaps,
                    ellipses=ellipses,
                    shallow=shallow,
                    ellipsisroots=ellipsisroots,
                    fullnodes=fullnodes)

def _makecg3packer(repo, filematcher, bundlecaps, ellipses=False,
                   shallow=False, ellipsisroots=None, fullnodes=None):
    builddeltaheader = lambda d: _CHANGEGROUPV3_DELTA_HEADER.pack(
        d.node, d.p1node, d.p2node, d.basenode, d.linknode, d.flags)

    return cgpacker(repo, filematcher, b'03',
                    allowreorder=False,
                    builddeltaheader=builddeltaheader,
                    manifestsend=closechunk(),
                    bundlecaps=bundlecaps,
                    ellipses=ellipses,
                    shallow=shallow,
                    ellipsisroots=ellipsisroots,
                    fullnodes=fullnodes)

_packermap = {'01': (_makecg1packer, cg1unpacker),
             # cg2 adds support for exchanging generaldelta
             '02': (_makecg2packer, cg2unpacker),
             # cg3 adds support for exchanging revlog flags and treemanifests
             '03': (_makecg3packer, cg3unpacker),
}

def allsupportedversions(repo):
    versions = set(_packermap.keys())
    if not (repo.ui.configbool('experimental', 'changegroup3') or
            repo.ui.configbool('experimental', 'treemanifest') or
            'treemanifest' in repo.requirements):
        versions.discard('03')
    return versions

# Changegroup versions that can be applied to the repo
def supportedincomingversions(repo):
    return allsupportedversions(repo)

# Changegroup versions that can be created from the repo
def supportedoutgoingversions(repo):
    versions = allsupportedversions(repo)
    if 'treemanifest' in repo.requirements:
        # Versions 01 and 02 support only flat manifests and it's just too
        # expensive to convert between the flat manifest and tree manifest on
        # the fly. Since tree manifests are hashed differently, all of history
        # would have to be converted. Instead, we simply don't even pretend to
        # support versions 01 and 02.
        versions.discard('01')
        versions.discard('02')
    if repository.NARROW_REQUIREMENT in repo.requirements:
        # Versions 01 and 02 don't support revlog flags, and we need to
        # support that for stripping and unbundling to work.
        versions.discard('01')
        versions.discard('02')
    if LFS_REQUIREMENT in repo.requirements:
        # Versions 01 and 02 don't support revlog flags, and we need to
        # mark LFS entries with REVIDX_EXTSTORED.
        versions.discard('01')
        versions.discard('02')

    return versions

def localversion(repo):
    # Finds the best version to use for bundles that are meant to be used
    # locally, such as those from strip and shelve, and temporary bundles.
    return max(supportedoutgoingversions(repo))

def safeversion(repo):
    # Finds the smallest version that it's safe to assume clients of the repo
    # will support. For example, all hg versions that support generaldelta also
    # support changegroup 02.
    versions = supportedoutgoingversions(repo)
    if 'generaldelta' in repo.requirements:
        versions.discard('01')
    assert versions
    return min(versions)

def getbundler(version, repo, bundlecaps=None, filematcher=None,
               ellipses=False, shallow=False, ellipsisroots=None,
               fullnodes=None):
    assert version in supportedoutgoingversions(repo)

    if filematcher is None:
        filematcher = matchmod.alwaysmatcher(repo.root, '')

    if version == '01' and not filematcher.always():
        raise error.ProgrammingError('version 01 changegroups do not support '
                                     'sparse file matchers')

    if ellipses and version in (b'01', b'02'):
        raise error.Abort(
            _('ellipsis nodes require at least cg3 on client and server, '
              'but negotiated version %s') % version)

    # Requested files could include files not in the local store. So
    # filter those out.
    filematcher = matchmod.intersectmatchers(repo.narrowmatch(),
                                             filematcher)

    fn = _packermap[version][0]
    return fn(repo, filematcher, bundlecaps, ellipses=ellipses,
              shallow=shallow, ellipsisroots=ellipsisroots,
              fullnodes=fullnodes)

def getunbundler(version, fh, alg, extras=None):
    return _packermap[version][1](fh, alg, extras=extras)

def _changegroupinfo(repo, nodes, source):
    if repo.ui.verbose or source == 'bundle':
        repo.ui.status(_("%d changesets found\n") % len(nodes))
    if repo.ui.debugflag:
        repo.ui.debug("list of changesets:\n")
        for node in nodes:
            repo.ui.debug("%s\n" % hex(node))

def makechangegroup(repo, outgoing, version, source, fastpath=False,
                    bundlecaps=None):
    cgstream = makestream(repo, outgoing, version, source,
                          fastpath=fastpath, bundlecaps=bundlecaps)
    return getunbundler(version, util.chunkbuffer(cgstream), None,
                        {'clcount': len(outgoing.missing) })

def makestream(repo, outgoing, version, source, fastpath=False,
               bundlecaps=None, filematcher=None):
    bundler = getbundler(version, repo, bundlecaps=bundlecaps,
                         filematcher=filematcher)

    repo = repo.unfiltered()
    commonrevs = outgoing.common
    csets = outgoing.missing
    heads = outgoing.missingheads
    # We go through the fast path if we get told to, or if all (unfiltered
    # heads have been requested (since we then know there all linkrevs will
    # be pulled by the client).
    heads.sort()
    fastpathlinkrev = fastpath or (
            repo.filtername is None and heads == sorted(repo.heads()))

    repo.hook('preoutgoing', throw=True, source=source)
    _changegroupinfo(repo, csets, source)
    return bundler.generate(commonrevs, csets, fastpathlinkrev, source)

def _addchangegroupfiles(repo, source, revmap, trp, expectedfiles, needfiles):
    revisions = 0
    files = 0
    progress = repo.ui.makeprogress(_('files'), unit=_('files'),
                                    total=expectedfiles)
    for chunkdata in iter(source.filelogheader, {}):
        files += 1
        f = chunkdata["filename"]
        repo.ui.debug("adding %s revisions\n" % f)
        progress.increment()
        fl = repo.file(f)
        o = len(fl)
        try:
            deltas = source.deltaiter()
            if not fl.addgroup(deltas, revmap, trp):
                raise error.Abort(_("received file revlog group is empty"))
        except error.CensoredBaseError as e:
            raise error.Abort(_("received delta base is censored: %s") % e)
        revisions += len(fl) - o
        if f in needfiles:
            needs = needfiles[f]
            for new in pycompat.xrange(o, len(fl)):
                n = fl.node(new)
                if n in needs:
                    needs.remove(n)
                else:
                    raise error.Abort(
                        _("received spurious file revlog entry"))
            if not needs:
                del needfiles[f]
    progress.complete()

    for f, needs in needfiles.iteritems():
        fl = repo.file(f)
        for n in needs:
            try:
                fl.rev(n)
            except error.LookupError:
                raise error.Abort(
                    _('missing file data for %s:%s - run hg verify') %
                    (f, hex(n)))

    return revisions, files
