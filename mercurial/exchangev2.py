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

    pullheads = pullop.heads or remoteheads
    _fetchchangesets(repo, tr, remote, common, fetch, pullheads)

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
    if not fetch:
        return

    # TODO consider adding a step here where we obtain the DAG shape first
    # (or ask the server to slice changesets into chunks for us) so that
    # we can perform multiple fetches in batches. This will facilitate
    # resuming interrupted clones, higher server-side cache hit rates due
    # to smaller segments, etc.
    with remote.commandexecutor() as e:
        objs = e.callcommand(b'changesetdata', {
            b'noderange': [sorted(common), sorted(remoteheads)],
            b'fields': {b'parents', b'revision'},
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

    # addgroup() expects a 7-tuple describing revisions. This normalizes
    # the wire data to that format.
    def iterrevisions():
        for cset in objs:
            assert b'revisionsize' in cset
            data = next(objs)

            yield (
                cset[b'node'],
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
    }
