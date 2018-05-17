# narrowmerge.py - extensions to mercurial merge module to support narrow clones
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

def setup():
    def _computenonoverlap(orig, repo, *args, **kwargs):
        u1, u2 = orig(repo, *args, **kwargs)
        narrowmatch = repo.narrowmatch()
        if narrowmatch.always():
            return u1, u2

        u1 = [f for f in u1 if narrowmatch(f)]
        u2 = [f for f in u2 if narrowmatch(f)]
        return u1, u2
    extensions.wrapfunction(copies, '_computenonoverlap', _computenonoverlap)
