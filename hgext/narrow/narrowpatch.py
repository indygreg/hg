# narrowpatch.py - extensions to mercurial patch module to support narrow clones
#
# Copyright 2017 Google, Inc.
#
# This software may be used and distributed according to the terms of the
# GNU General Public License version 2 or any later version.

from __future__ import absolute_import

from mercurial import (
    extensions,
    patch,
    util,
)

def setup(repo):
    def _filepairs(orig, *args):
        """Only includes files within the narrow spec in the diff."""
        if util.safehasattr(repo, 'narrowmatch'):
            narrowmatch = repo.narrowmatch()
            for x in orig(*args):
                f1, f2, copyop = x
                if ((not f1 or narrowmatch(f1)) and
                    (not f2 or narrowmatch(f2))):
                    yield x
        else:
            for x in orig(*args):
                yield x

    def trydiff(orig, repo, revs, ctx1, ctx2, modified, added, removed,
                copy, getfilectx, *args, **kwargs):
        if util.safehasattr(repo, 'narrowmatch'):
            narrowmatch = repo.narrowmatch()
            modified = [f for f in modified if narrowmatch(f)]
            added = [f for f in added if narrowmatch(f)]
            removed = [f for f in removed if narrowmatch(f)]
            copy = {k: v for k, v in copy.iteritems() if narrowmatch(k)}
        return orig(repo, revs, ctx1, ctx2, modified, added, removed, copy,
                    getfilectx, *args, **kwargs)

    extensions.wrapfunction(patch, '_filepairs', _filepairs)
    extensions.wrapfunction(patch, 'trydiff', trydiff)
