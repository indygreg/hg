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
    merge,
)

def setup():
    def _checkcollision(orig, repo, wmf, actions):
        narrowmatch = repo.narrowmatch()
        if not narrowmatch.always():
            wmf = wmf.matches(narrowmatch)
            if actions:
                narrowactions = {}
                for m, actionsfortype in actions.iteritems():
                    narrowactions[m] = []
                    for (f, args, msg) in actionsfortype:
                        if narrowmatch(f):
                            narrowactions[m].append((f, args, msg))
                actions = narrowactions
        return orig(repo, wmf, actions)

    extensions.wrapfunction(merge, '_checkcollision', _checkcollision)

    def _computenonoverlap(orig, repo, *args, **kwargs):
        u1, u2 = orig(repo, *args, **kwargs)
        narrowmatch = repo.narrowmatch()
        if narrowmatch.always():
            return u1, u2

        u1 = [f for f in u1 if narrowmatch(f)]
        u2 = [f for f in u2 if narrowmatch(f)]
        return u1, u2
    extensions.wrapfunction(copies, '_computenonoverlap', _computenonoverlap)
