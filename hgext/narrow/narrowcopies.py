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
)

def setup(repo):
    def _computeforwardmissing(orig, a, b, match=None):
        missing = orig(a, b, match)
        narrowmatch = repo.narrowmatch()
        if narrowmatch.always():
            return missing
        missing = [f for f in missing if narrowmatch(f)]
        return missing

    def _checkcopies(orig, srcctx, dstctx, f, base, tca, remotebase, limit,
                     data):
        narrowmatch = repo.narrowmatch()
        if not narrowmatch(f):
            return
        orig(srcctx, dstctx, f, base, tca, remotebase, limit, data)

    extensions.wrapfunction(copies, '_computeforwardmissing',
                            _computeforwardmissing)
    extensions.wrapfunction(copies, '_checkcopies', _checkcopies)
