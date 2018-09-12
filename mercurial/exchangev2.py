# exchangev2.py - repository exchange for wire protocol version 2
#
# Copyright 2018 Gregory Szorc <gregory.szorc@gmail.com>
#
# This software may be used and distributed according to the terms of the
# GNU General Public License version 2 or any later version.

from __future__ import absolute_import

from .node import (
    nullid,
)
from . import (
    setdiscovery,
)

def pull(pullop):
    """Pull using wire protocol version 2."""
    repo = pullop.repo
    remote = pullop.remote

    # Figure out what needs to be fetched.
    common, fetch, remoteheads = _pullchangesetdiscovery(
        repo, remote, pullop.heads, abortwhenunrelated=pullop.force)

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
