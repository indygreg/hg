# shallowbundle.py - bundle10 implementation for use with shallow repositories
#
# Copyright 2013 Facebook, Inc.
#
# This software may be used and distributed according to the terms of the
# GNU General Public License version 2 or any later version.
from __future__ import absolute_import

from mercurial.i18n import _
from mercurial.node import bin, hex, nullid
from mercurial import (
    bundlerepo,
    changegroup,
    error,
    match,
    mdiff,
    pycompat,
)
from . import (
    constants,
    remotefilelog,
    shallowutil,
)

NoFiles = 0
LocalFiles = 1
AllFiles = 2

def shallowgroup(cls, self, nodelist, rlog, lookup, units=None, reorder=None):
    if not isinstance(rlog, remotefilelog.remotefilelog):
        for c in super(cls, self).group(nodelist, rlog, lookup,
                                        units=units):
            yield c
        return

    if len(nodelist) == 0:
        yield self.close()
        return

    nodelist = shallowutil.sortnodes(nodelist, rlog.parents)

    # add the parent of the first rev
    p = rlog.parents(nodelist[0])[0]
    nodelist.insert(0, p)

    # build deltas
    for i in pycompat.xrange(len(nodelist) - 1):
        prev, curr = nodelist[i], nodelist[i + 1]
        linknode = lookup(curr)
        for c in self.nodechunk(rlog, curr, prev, linknode):
            yield c

    yield self.close()

class shallowcg1packer(changegroup.cgpacker):
    def generate(self, commonrevs, clnodes, fastpathlinkrev, source):
        if constants.SHALLOWREPO_REQUIREMENT in self._repo.requirements:
            fastpathlinkrev = False

        return super(shallowcg1packer, self).generate(commonrevs, clnodes,
            fastpathlinkrev, source)

    def group(self, nodelist, rlog, lookup, units=None, reorder=None):
        return shallowgroup(shallowcg1packer, self, nodelist, rlog, lookup,
                            units=units)

    def generatefiles(self, changedfiles, *args):
        try:
            linknodes, commonrevs, source = args
        except ValueError:
            commonrevs, source, mfdicts, fastpathlinkrev, fnodes, clrevs = args
        if constants.SHALLOWREPO_REQUIREMENT in self._repo.requirements:
            repo = self._repo
            if isinstance(repo, bundlerepo.bundlerepository):
                # If the bundle contains filelogs, we can't pull from it, since
                # bundlerepo is heavily tied to revlogs. Instead require that
                # the user use unbundle instead.
                # Force load the filelog data.
                bundlerepo.bundlerepository.file(repo, 'foo')
                if repo._cgfilespos:
                    raise error.Abort("cannot pull from full bundles",
                                      hint="use `hg unbundle` instead")
                return []
            filestosend = self.shouldaddfilegroups(source)
            if filestosend == NoFiles:
                changedfiles = list([f for f in changedfiles
                                     if not repo.shallowmatch(f)])

        return super(shallowcg1packer, self).generatefiles(
            changedfiles, *args)

    def shouldaddfilegroups(self, source):
        repo = self._repo
        if not constants.SHALLOWREPO_REQUIREMENT in repo.requirements:
            return AllFiles

        if source == "push" or source == "bundle":
            return AllFiles

        caps = self._bundlecaps or []
        if source == "serve" or source == "pull":
            if constants.BUNDLE2_CAPABLITY in caps:
                return LocalFiles
            else:
                # Serving to a full repo requires us to serve everything
                repo.ui.warn(_("pulling from a shallow repo\n"))
                return AllFiles

        return NoFiles

    def prune(self, rlog, missing, commonrevs):
        if not isinstance(rlog, remotefilelog.remotefilelog):
            return super(shallowcg1packer, self).prune(rlog, missing,
                commonrevs)

        repo = self._repo
        results = []
        for fnode in missing:
            fctx = repo.filectx(rlog.filename, fileid=fnode)
            if fctx.linkrev() not in commonrevs:
                results.append(fnode)
        return results

    def nodechunk(self, revlog, node, prevnode, linknode):
        prefix = ''
        if prevnode == nullid:
            delta = revlog.revision(node, raw=True)
            prefix = mdiff.trivialdiffheader(len(delta))
        else:
            # Actually uses remotefilelog.revdiff which works on nodes, not revs
            delta = revlog.revdiff(prevnode, node)
        p1, p2 = revlog.parents(node)
        flags = revlog.flags(node)
        meta = self.builddeltaheader(node, p1, p2, prevnode, linknode, flags)
        meta += prefix
        l = len(meta) + len(delta)
        yield changegroup.chunkheader(l)
        yield meta
        yield delta

def makechangegroup(orig, repo, outgoing, version, source, *args, **kwargs):
    if not constants.SHALLOWREPO_REQUIREMENT in repo.requirements:
        return orig(repo, outgoing, version, source, *args, **kwargs)

    original = repo.shallowmatch
    try:
        # if serving, only send files the clients has patterns for
        if source == 'serve':
            bundlecaps = kwargs.get('bundlecaps')
            includepattern = None
            excludepattern = None
            for cap in (bundlecaps or []):
                if cap.startswith("includepattern="):
                    raw = cap[len("includepattern="):]
                    if raw:
                        includepattern = raw.split('\0')
                elif cap.startswith("excludepattern="):
                    raw = cap[len("excludepattern="):]
                    if raw:
                        excludepattern = raw.split('\0')
            if includepattern or excludepattern:
                repo.shallowmatch = match.match(repo.root, '', None,
                    includepattern, excludepattern)
            else:
                repo.shallowmatch = match.always(repo.root, '')
        return orig(repo, outgoing, version, source, *args, **kwargs)
    finally:
        repo.shallowmatch = original

def addchangegroupfiles(orig, repo, source, revmap, trp, expectedfiles, *args):
    if not constants.SHALLOWREPO_REQUIREMENT in repo.requirements:
        return orig(repo, source, revmap, trp, expectedfiles, *args)

    files = 0
    newfiles = 0
    visited = set()
    revisiondatas = {}
    queue = []

    # Normal Mercurial processes each file one at a time, adding all
    # the new revisions for that file at once. In remotefilelog a file
    # revision may depend on a different file's revision (in the case
    # of a rename/copy), so we must lay all revisions down across all
    # files in topological order.

    # read all the file chunks but don't add them
    while True:
        chunkdata = source.filelogheader()
        if not chunkdata:
            break
        files += 1
        f = chunkdata["filename"]
        repo.ui.debug("adding %s revisions\n" % f)
        repo.ui.progress(_('files'), files, total=expectedfiles)

        if not repo.shallowmatch(f):
            fl = repo.file(f)
            deltas = source.deltaiter()
            fl.addgroup(deltas, revmap, trp)
            continue

        chain = None
        while True:
            # returns: (node, p1, p2, cs, deltabase, delta, flags) or None
            revisiondata = source.deltachunk(chain)
            if not revisiondata:
                break

            chain = revisiondata[0]

            revisiondatas[(f, chain)] = revisiondata
            queue.append((f, chain))

            if f not in visited:
                newfiles += 1
                visited.add(f)

        if chain is None:
            raise error.Abort(_("received file revlog group is empty"))

    processed = set()
    def available(f, node, depf, depnode):
        if depnode != nullid and (depf, depnode) not in processed:
            if not (depf, depnode) in revisiondatas:
                # It's not in the changegroup, assume it's already
                # in the repo
                return True
            # re-add self to queue
            queue.insert(0, (f, node))
            # add dependency in front
            queue.insert(0, (depf, depnode))
            return False
        return True

    skipcount = 0

    # Prefetch the non-bundled revisions that we will need
    prefetchfiles = []
    for f, node in queue:
        revisiondata = revisiondatas[(f, node)]
        # revisiondata: (node, p1, p2, cs, deltabase, delta, flags)
        dependents = [revisiondata[1], revisiondata[2], revisiondata[4]]

        for dependent in dependents:
            if dependent == nullid or (f, dependent) in revisiondatas:
                continue
            prefetchfiles.append((f, hex(dependent)))

    repo.fileservice.prefetch(prefetchfiles)

    # Apply the revisions in topological order such that a revision
    # is only written once it's deltabase and parents have been written.
    while queue:
        f, node = queue.pop(0)
        if (f, node) in processed:
            continue

        skipcount += 1
        if skipcount > len(queue) + 1:
            raise error.Abort(_("circular node dependency"))

        fl = repo.file(f)

        revisiondata = revisiondatas[(f, node)]
        # revisiondata: (node, p1, p2, cs, deltabase, delta, flags)
        node, p1, p2, linknode, deltabase, delta, flags = revisiondata

        if not available(f, node, f, deltabase):
            continue

        base = fl.revision(deltabase, raw=True)
        text = mdiff.patch(base, delta)
        if isinstance(text, buffer):
            text = str(text)

        meta, text = shallowutil.parsemeta(text)
        if 'copy' in meta:
            copyfrom = meta['copy']
            copynode = bin(meta['copyrev'])
            if not available(f, node, copyfrom, copynode):
                continue

        for p in [p1, p2]:
            if p != nullid:
                if not available(f, node, f, p):
                    continue

        fl.add(text, meta, trp, linknode, p1, p2)
        processed.add((f, node))
        skipcount = 0

    repo.ui.progress(_('files'), None)

    return len(revisiondatas), newfiles
