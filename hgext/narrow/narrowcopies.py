# narrowcopies.py - extensions to mercurial copies module to support narrow
# clones
#
# Copyright 2017 Google, Inc.
#
# This software may be used and distributed according to the terms of the
# GNU General Public License version 2 or any later version.

from __future__ import absolute_import

from mercurial import (
    copies,
    extensions,
    util,
)

def setup(repo):
    def _computeforwardmissing(orig, a, b, match=None):
        missing = orig(a, b, match)
        if util.safehasattr(repo, 'narrowmatch'):
            narrowmatch = repo.narrowmatch()
            missing = filter(narrowmatch, missing)
        return missing

    def _checkcopies(orig, srcctx, dstctx, f, base, tca, remotebase, limit,
                     data):
        if util.safehasattr(repo, 'narrowmatch'):
            narrowmatch = repo.narrowmatch()
            if not narrowmatch(f):
                return
        orig(srcctx, dstctx, f, base, tca, remotebase, limit, data)

    extensions.wrapfunction(copies, '_computeforwardmissing',
                            _computeforwardmissing)
    extensions.wrapfunction(copies, '_checkcopies', _checkcopies)
