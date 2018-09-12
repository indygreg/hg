# exchangev2.py - repository exchange for wire protocol version 2
#
# Copyright 2018 Gregory Szorc <gregory.szorc@gmail.com>
#
# This software may be used and distributed according to the terms of the
# GNU General Public License version 2 or any later version.

from __future__ import absolute_import

import weakref

from .i18n import _
from .node import (
    nullid,
    short,
)
from . import (
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
            b'noderange': [sorted(common), sorted(remoteheads)],
            b'fields': {b'parents', b'phase', b'revision'},
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

    def linkrev(node):
        repo.ui.debug('add changeset %s\n' % short(node))
        # Linkrev for changelog is always self.
        return len(cl)

    def onchangeset(cl, node):
        progress.increment()

    nodesbyphase = {phase: set() for phase in phases.phasenames}

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

            # Some entries might only be metadata only updates.
            if b'revisionsize' not in cset:
                continue

            data = next(objs)

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
    }
