# exchangev2.py - repository exchange for wire protocol version 2
#
# Copyright 2018 Gregory Szorc <gregory.szorc@gmail.com>
#
# This software may be used and distributed according to the terms of the
# GNU General Public License version 2 or any later version.

from __future__ import absolute_import

import collections
import weakref

from .i18n import _
from .node import (
    nullid,
    short,
)
from . import (
    bookmarks,
    error,
    mdiff,
    phases,
    pycompat,
    setdiscovery,
)

def pull(pullop):
    """Pull using wire protocol version 2."""
    repo = pullop.repo
    remote = pullop.remote
    tr = pullop.trmanager.transaction()

    # Figure out what needs to be fetched.
    common, fetch, remoteheads = _pullchangesetdiscovery(
        repo, remote, pullop.heads, abortwhenunrelated=pullop.force)

    # And fetch the data.
    pullheads = pullop.heads or remoteheads
    csetres = _fetchchangesets(repo, tr, remote, common, fetch, pullheads)

    # New revisions are written to the changelog. But all other updates
    # are deferred. Do those now.

    # Ensure all new changesets are draft by default. If the repo is
    # publishing, the phase will be adjusted by the loop below.
    if csetres['added']:
        phases.registernew(repo, tr, phases.draft, csetres['added'])

    # And adjust the phase of all changesets accordingly.
    for phase in phases.phasenames:
        if phase == b'secret' or not csetres['nodesbyphase'][phase]:
            continue

        phases.advanceboundary(repo, tr, phases.phasenames.index(phase),
                               csetres['nodesbyphase'][phase])

    # Write bookmark updates.
    bookmarks.updatefromremote(repo.ui, repo, csetres['bookmarks'],
                               remote.url(), pullop.gettransaction,
                               explicit=pullop.explicitbookmarks)

    manres = _fetchmanifests(repo, tr, remote, csetres['manifestnodes'])

    # Find all file nodes referenced by added manifests and fetch those
    # revisions.
    fnodes = _derivefilesfrommanifests(repo, manres['added'])
    _fetchfilesfromcsets(repo, tr, remote, fnodes, csetres['added'],
                         manres['linkrevs'])

def _pullchangesetdiscovery(repo, remote, heads, abortwhenunrelated=True):
    """Determine which changesets need to be pulled."""

    if heads:
        knownnode = repo.changelog.hasnode
        if all(knownnode(head) for head in heads):
            return heads, False, heads

    # TODO wire protocol version 2 is capable of more efficient discovery
    # than setdiscovery. Consider implementing something better.
    common, fetch, remoteheads = setdiscovery.findcommonheads(
        repo.ui, repo, remote, abortwhenunrelated=abortwhenunrelated)

    common = set(common)
    remoteheads = set(remoteheads)

    # If a remote head is filtered locally, put it back in the common set.
    # See the comment in exchange._pulldiscoverychangegroup() for more.

    if fetch and remoteheads:
        nodemap = repo.unfiltered().changelog.nodemap

        common |= {head for head in remoteheads if head in nodemap}

        if set(remoteheads).issubset(common):
            fetch = []

    common.discard(nullid)

    return common, fetch, remoteheads

def _fetchchangesets(repo, tr, remote, common, fetch, remoteheads):
    # TODO consider adding a step here where we obtain the DAG shape first
    # (or ask the server to slice changesets into chunks for us) so that
    # we can perform multiple fetches in batches. This will facilitate
    # resuming interrupted clones, higher server-side cache hit rates due
    # to smaller segments, etc.
    with remote.commandexecutor() as e:
        objs = e.callcommand(b'changesetdata', {
            b'revisions': [{
                b'type': b'changesetdagrange',
                b'roots': sorted(common),
                b'heads': sorted(remoteheads),
            }],
            b'fields': {b'bookmarks', b'parents', b'phase', b'revision'},
        }).result()

        # The context manager waits on all response data when exiting. So
        # we need to remain in the context manager in order to stream data.
        return _processchangesetdata(repo, tr, objs)

def _processchangesetdata(repo, tr, objs):
    repo.hook('prechangegroup', throw=True,
              **pycompat.strkwargs(tr.hookargs))

    urepo = repo.unfiltered()
    cl = urepo.changelog

    cl.delayupdate(tr)

    # The first emitted object is a header describing the data that
    # follows.
    meta = next(objs)

    progress = repo.ui.makeprogress(_('changesets'),
                                    unit=_('chunks'),
                                    total=meta.get(b'totalitems'))

    manifestnodes = {}

    def linkrev(node):
        repo.ui.debug('add changeset %s\n' % short(node))
        # Linkrev for changelog is always self.
        return len(cl)

    def onchangeset(cl, node):
        progress.increment()

        revision = cl.changelogrevision(node)

        # We need to preserve the mapping of changelog revision to node
        # so we can set the linkrev accordingly when manifests are added.
        manifestnodes[cl.rev(node)] = revision.manifest

    nodesbyphase = {phase: set() for phase in phases.phasenames}
    remotebookmarks = {}

    # addgroup() expects a 7-tuple describing revisions. This normalizes
    # the wire data to that format.
    #
    # This loop also aggregates non-revision metadata, such as phase
    # data.
    def iterrevisions():
        for cset in objs:
            node = cset[b'node']

            if b'phase' in cset:
                nodesbyphase[cset[b'phase']].add(node)

            for mark in cset.get(b'bookmarks', []):
                remotebookmarks[mark] = node

            # TODO add mechanism for extensions to examine records so they
            # can siphon off custom data fields.

            extrafields = {}

            for field, size in cset.get(b'fieldsfollowing', []):
                extrafields[field] = next(objs)

            # Some entries might only be metadata only updates.
            if b'revision' not in extrafields:
                continue

            data = extrafields[b'revision']

            yield (
                node,
                cset[b'parents'][0],
                cset[b'parents'][1],
                # Linknode is always itself for changesets.
                cset[b'node'],
                # We always send full revisions. So delta base is not set.
                nullid,
                mdiff.trivialdiffheader(len(data)) + data,
                # Flags not yet supported.
                0,
            )

    added = cl.addgroup(iterrevisions(), linkrev, weakref.proxy(tr),
                        addrevisioncb=onchangeset)

    progress.complete()

    return {
        'added': added,
        'nodesbyphase': nodesbyphase,
        'bookmarks': remotebookmarks,
        'manifestnodes': manifestnodes,
    }

def _fetchmanifests(repo, tr, remote, manifestnodes):
    rootmanifest = repo.manifestlog.getstorage(b'')

    # Some manifests can be shared between changesets. Filter out revisions
    # we already know about.
    fetchnodes = []
    linkrevs = {}
    seen = set()

    for clrev, node in sorted(manifestnodes.iteritems()):
        if node in seen:
            continue

        try:
            rootmanifest.rev(node)
        except error.LookupError:
            fetchnodes.append(node)
            linkrevs[node] = clrev

        seen.add(node)

    # TODO handle tree manifests

    # addgroup() expects 7-tuple describing revisions. This normalizes
    # the wire data to that format.
    def iterrevisions(objs, progress):
        for manifest in objs:
            node = manifest[b'node']

            extrafields = {}

            for field, size in manifest.get(b'fieldsfollowing', []):
                extrafields[field] = next(objs)

            if b'delta' in extrafields:
                basenode = manifest[b'deltabasenode']
                delta = extrafields[b'delta']
            elif b'revision' in extrafields:
                basenode = nullid
                revision = extrafields[b'revision']
                delta = mdiff.trivialdiffheader(len(revision)) + revision
            else:
                continue

            yield (
                node,
                manifest[b'parents'][0],
                manifest[b'parents'][1],
                # The value passed in is passed to the lookup function passed
                # to addgroup(). We already have a map of manifest node to
                # changelog revision number. So we just pass in the
                # manifest node here and use linkrevs.__getitem__ as the
                # resolution function.
                node,
                basenode,
                delta,
                # Flags not yet supported.
                0
            )

            progress.increment()

    progress = repo.ui.makeprogress(_('manifests'), unit=_('chunks'),
                                    total=len(fetchnodes))

    commandmeta = remote.apidescriptor[b'commands'][b'manifestdata']
    batchsize = commandmeta.get(b'recommendedbatchsize', 10000)
    # TODO make size configurable on client?

    # We send commands 1 at a time to the remote. This is not the most
    # efficient because we incur a round trip at the end of each batch.
    # However, the existing frame-based reactor keeps consuming server
    # data in the background. And this results in response data buffering
    # in memory. This can consume gigabytes of memory.
    # TODO send multiple commands in a request once background buffering
    # issues are resolved.

    added = []

    for i in pycompat.xrange(0, len(fetchnodes), batchsize):
        batch = [node for node in fetchnodes[i:i + batchsize]]
        if not batch:
            continue

        with remote.commandexecutor() as e:
            objs = e.callcommand(b'manifestdata', {
                b'tree': b'',
                b'nodes': batch,
                b'fields': {b'parents', b'revision'},
                b'haveparents': True,
            }).result()

            # Chomp off header object.
            next(objs)

            added.extend(rootmanifest.addgroup(
                iterrevisions(objs, progress),
                linkrevs.__getitem__,
                weakref.proxy(tr)))

    progress.complete()

    return {
        'added': added,
        'linkrevs': linkrevs,
    }

def _derivefilesfrommanifests(repo, manifestnodes):
    """Determine what file nodes are relevant given a set of manifest nodes.

    Returns a dict mapping file paths to dicts of file node to first manifest
    node.
    """
    ml = repo.manifestlog
    fnodes = collections.defaultdict(dict)

    progress = repo.ui.makeprogress(
        _('scanning manifests'), total=len(manifestnodes))

    with progress:
        for manifestnode in manifestnodes:
            m = ml.get(b'', manifestnode)

            # TODO this will pull in unwanted nodes because it takes the storage
            # delta into consideration. What we really want is something that
            # takes the delta between the manifest's parents. And ideally we
            # would ignore file nodes that are known locally. For now, ignore
            # both these limitations. This will result in incremental fetches
            # requesting data we already have. So this is far from ideal.
            md = m.readfast()

            for path, fnode in md.items():
                fnodes[path].setdefault(fnode, manifestnode)

            progress.increment()

    return fnodes

def _fetchfiles(repo, tr, remote, fnodes, linkrevs):
    """Fetch file data from explicit file revisions."""
    def iterrevisions(objs, progress):
        for filerevision in objs:
            node = filerevision[b'node']

            extrafields = {}

            for field, size in filerevision.get(b'fieldsfollowing', []):
                extrafields[field] = next(objs)

            if b'delta' in extrafields:
                basenode = filerevision[b'deltabasenode']
                delta = extrafields[b'delta']
            elif b'revision' in extrafields:
                basenode = nullid
                revision = extrafields[b'revision']
                delta = mdiff.trivialdiffheader(len(revision)) + revision
            else:
                continue

            yield (
                node,
                filerevision[b'parents'][0],
                filerevision[b'parents'][1],
                node,
                basenode,
                delta,
                # Flags not yet supported.
                0,
            )

            progress.increment()

    progress = repo.ui.makeprogress(
        _('files'), unit=_('chunks'),
         total=sum(len(v) for v in fnodes.itervalues()))

    # TODO make batch size configurable
    batchsize = 10000
    fnodeslist = [x for x in sorted(fnodes.items())]

    for i in pycompat.xrange(0, len(fnodeslist), batchsize):
        batch = [x for x in fnodeslist[i:i + batchsize]]
        if not batch:
            continue

        with remote.commandexecutor() as e:
            fs = []
            locallinkrevs = {}

            for path, nodes in batch:
                fs.append((path, e.callcommand(b'filedata', {
                    b'path': path,
                    b'nodes': sorted(nodes),
                    b'fields': {b'parents', b'revision'},
                    b'haveparents': True,
                })))

                locallinkrevs[path] = {
                    node: linkrevs[manifestnode]
                    for node, manifestnode in nodes.iteritems()}

            for path, f in fs:
                objs = f.result()

                # Chomp off header objects.
                next(objs)

                store = repo.file(path)
                store.addgroup(
                    iterrevisions(objs, progress),
                    locallinkrevs[path].__getitem__,
                    weakref.proxy(tr))

def _fetchfilesfromcsets(repo, tr, remote, fnodes, csets, manlinkrevs):
    """Fetch file data from explicit changeset revisions."""

    def iterrevisions(objs, remaining, progress):
        while remaining:
            filerevision = next(objs)

            node = filerevision[b'node']

            extrafields = {}

            for field, size in filerevision.get(b'fieldsfollowing', []):
                extrafields[field] = next(objs)

            if b'delta' in extrafields:
                basenode = filerevision[b'deltabasenode']
                delta = extrafields[b'delta']
            elif b'revision' in extrafields:
                basenode = nullid
                revision = extrafields[b'revision']
                delta = mdiff.trivialdiffheader(len(revision)) + revision
            else:
                continue

            yield (
                node,
                filerevision[b'parents'][0],
                filerevision[b'parents'][1],
                node,
                basenode,
                delta,
                # Flags not yet supported.
                0,
            )

            progress.increment()
            remaining -= 1

    progress = repo.ui.makeprogress(
        _('files'), unit=_('chunks'),
        total=sum(len(v) for v in fnodes.itervalues()))

    commandmeta = remote.apidescriptor[b'commands'][b'filesdata']
    batchsize = commandmeta.get(b'recommendedbatchsize', 50000)

    for i in pycompat.xrange(0, len(csets), batchsize):
        batch = [x for x in csets[i:i + batchsize]]
        if not batch:
            continue

        with remote.commandexecutor() as e:
            args = {
                b'revisions': [{
                    b'type': b'changesetexplicit',
                    b'nodes': batch,
                }],
                b'fields': {b'parents', b'revision'},
                b'haveparents': True,
            }

            objs = e.callcommand(b'filesdata', args).result()

            # First object is an overall header.
            overall = next(objs)

            # We have overall['totalpaths'] segments.
            for i in pycompat.xrange(overall[b'totalpaths']):
                header = next(objs)

                path = header[b'path']
                store = repo.file(path)

                linkrevs = {
                    fnode: manlinkrevs[mnode]
                    for fnode, mnode in fnodes[path].iteritems()}

                store.addgroup(iterrevisions(objs, header[b'totalitems'],
                                             progress),
                               linkrevs.__getitem__,
                               weakref.proxy(tr))
