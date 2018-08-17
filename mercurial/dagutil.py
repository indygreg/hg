# dagutil.py - dag utilities for mercurial
#
# Copyright 2010 Benoit Boissinot <bboissin@gmail.com>
# and Peter Arrenbrecht <peter@arrenbrecht.ch>
#
# This software may be used and distributed according to the terms of the
# GNU General Public License version 2 or any later version.

from __future__ import absolute_import

from .node import nullrev

class revlogdag(object):
    '''dag interface to a revlog'''

    def __init__(self, revlog):
        self._revlog = revlog

    def parents(self, ix):
        rlog = self._revlog
        idx = rlog.index
        revdata = idx[ix]
        prev = revdata[5]
        if prev != nullrev:
            prev2 = revdata[6]
            if prev2 == nullrev:
                return [prev]
            return [prev, prev2]
        prev2 = revdata[6]
        if prev2 != nullrev:
            return [prev2]
        return []

    def headsetofconnecteds(self, ixs):
        if not ixs:
            return set()
        rlog = self._revlog
        idx = rlog.index
        headrevs = set(ixs)
        for rev in ixs:
            revdata = idx[rev]
            for i in [5, 6]:
                prev = revdata[i]
                if prev != nullrev:
                    headrevs.discard(prev)
        assert headrevs
        return headrevs

    def linearize(self, ixs):
        '''linearize and topologically sort a list of revisions

        The linearization process tries to create long runs of revs where
        a child rev comes immediately after its first parent. This is done by
        visiting the heads of the given revs in inverse topological order,
        and for each visited rev, visiting its second parent, then its first
        parent, then adding the rev itself to the output list.
        '''
        sorted = []
        visit = list(self.headsetofconnecteds(ixs))
        visit.sort(reverse=True)
        finished = set()

        while visit:
            cur = visit.pop()
            if cur < 0:
                cur = -cur - 1
                if cur not in finished:
                    sorted.append(cur)
                    finished.add(cur)
            else:
                visit.append(-cur - 1)
                visit += [p for p in self.parents(cur)
                          if p in ixs and p not in finished]
        assert len(sorted) == len(ixs)
        return sorted
