# narrowtemplates.py - added template keywords for narrow clones
#
# Copyright 2017 Google, Inc.
#
# This software may be used and distributed according to the terms of the
# GNU General Public License version 2 or any later version.

from __future__ import absolute_import

from mercurial import (
    revset,
    templatekw,
    util,
)

from . import narrowrevlog

def _isellipsis(repo, rev):
    if repo.changelog.flags(rev) & narrowrevlog.ELLIPSIS_NODE_FLAG:
        return True
    return False

def ellipsis(repo, ctx, templ, **args):
    """:ellipsis: String. 'ellipsis' if the change is an ellipsis node,
    else ''."""
    if _isellipsis(repo, ctx.rev()):
        return 'ellipsis'
    return ''

def outsidenarrow(repo, ctx, templ, **args):
    """:outsidenarrow: String. 'outsidenarrow' if the change affects no
    tracked files, else ''."""
    if util.safehasattr(repo, 'narrowmatch'):
        m = repo.narrowmatch()
        if not any(m(f) for f in ctx.files()):
            return 'outsidenarrow'
    return ''

def ellipsisrevset(repo, subset, x):
    """``ellipsis()``
    Changesets that are ellipsis nodes.
    """
    return subset.filter(lambda r: _isellipsis(repo, r))

def setup():
    templatekw.keywords['ellipsis'] = ellipsis
    templatekw.keywords['outsidenarrow'] = outsidenarrow

    revset.symbols['ellipsis'] = ellipsisrevset
    revset.safesymbols.add('ellipsis')