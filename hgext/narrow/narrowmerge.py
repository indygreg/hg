# narrowmerge.py - extensions to mercurial merge module to support narrow clones
#
# Copyright 2017 Google, Inc.
#
# This software may be used and distributed according to the terms of the
# GNU General Public License version 2 or any later version.

from __future__ import absolute_import

from mercurial.i18n import _
from mercurial import (
    copies,
    error,
    extensions,
    merge,
)

def setup():
    def _manifestmerge(orig, repo, wctx, p2, pa, branchmerge, *args, **kwargs):
        """Filter updates to only lay out files that match the narrow spec."""
        actions, diverge, renamedelete = orig(
            repo, wctx, p2, pa, branchmerge, *args, **kwargs)

        narrowmatch = repo.narrowmatch()
        if narrowmatch.always():
            return actions, diverge, renamedelete

        nooptypes = set(['k']) # TODO: handle with nonconflicttypes
        nonconflicttypes = set('a am c cm f g r e'.split())
        # We mutate the items in the dict during iteration, so iterate
        # over a copy.
        for f, action in list(actions.items()):
            if narrowmatch(f):
                pass
            elif not branchmerge:
                del actions[f] # just updating, ignore changes outside clone
            elif action[0] in nooptypes:
                del actions[f] # merge does not affect file
            elif action[0] in nonconflicttypes:
                raise error.Abort(_('merge affects file \'%s\' outside narrow, '
                                    'which is not yet supported') % f,
                                  hint=_('merging in the other direction '
                                         'may work'))
            else:
                raise error.Abort(_('conflict in file \'%s\' is outside '
                                    'narrow clone') % f)

        return actions, diverge, renamedelete

    extensions.wrapfunction(merge, 'manifestmerge', _manifestmerge)

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
