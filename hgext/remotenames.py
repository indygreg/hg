# remotenames.py - extension to display remotenames
#
# Copyright 2017 Augie Fackler <raf@durin42.com>
# Copyright 2017 Sean Farley <sean@farley.io>
#
# This software may be used and distributed according to the terms of the
# GNU General Public License version 2 or any later version.

""" showing remotebookmarks and remotebranches in UI """

from __future__ import absolute_import

import UserDict

from mercurial.node import (
    bin,
)
from mercurial import (
    logexchange,
)

# Note for extension authors: ONLY specify testedwith = 'ships-with-hg-core' for
# extensions which SHIP WITH MERCURIAL. Non-mainline extensions should
# be specifying the version(s) of Mercurial they are tested with, or
# leave the attribute unspecified.
testedwith = 'ships-with-hg-core'

class lazyremotenamedict(UserDict.DictMixin):
    """
    Read-only dict-like Class to lazily resolve remotename entries

    We are doing that because remotenames startup was slow.
    We lazily read the remotenames file once to figure out the potential entries
    and store them in self.potentialentries. Then when asked to resolve an
    entry, if it is not in self.potentialentries, then it isn't there, if it
    is in self.potentialentries we resolve it and store the result in
    self.cache. We cannot be lazy is when asked all the entries (keys).
    """
    def __init__(self, kind, repo):
        self.cache = {}
        self.potentialentries = {}
        self._kind = kind # bookmarks or branches
        self._repo = repo
        self.loaded = False

    def _load(self):
        """ Read the remotenames file, store entries matching selected kind """
        self.loaded = True
        repo = self._repo
        for node, rpath, rname in logexchange.readremotenamefile(repo,
                                                                self._kind):
            name = rpath + '/' + rname
            self.potentialentries[name] = (node, rpath, name)

    def _resolvedata(self, potentialentry):
        """ Check that the node for potentialentry exists and return it """
        if not potentialentry in self.potentialentries:
            return None
        node, remote, name = self.potentialentries[potentialentry]
        repo = self._repo
        binnode = bin(node)
        # if the node doesn't exist, skip it
        try:
            repo.changelog.rev(binnode)
        except LookupError:
            return None
        # Skip closed branches
        if (self._kind == 'branches' and repo[binnode].closesbranch()):
            return None
        return [binnode]

    def __getitem__(self, key):
        if not self.loaded:
            self._load()
        val = self._fetchandcache(key)
        if val is not None:
            return val
        else:
            raise KeyError()

    def _fetchandcache(self, key):
        if key in self.cache:
            return self.cache[key]
        val = self._resolvedata(key)
        if val is not None:
            self.cache[key] = val
            return val
        else:
            return None

    def keys(self):
        """ Get a list of bookmark or branch names """
        if not self.loaded:
            self._load()
        return self.potentialentries.keys()

    def iteritems(self):
        """ Iterate over (name, node) tuples """

        if not self.loaded:
            self._load()

        for k, vtup in self.potentialentries.iteritems():
            yield (k, [bin(vtup[0])])

class remotenames(dict):
    """
    This class encapsulates all the remotenames state. It also contains
    methods to access that state in convenient ways. Remotenames are lazy
    loaded. Whenever client code needs to ensure the freshest copy of
    remotenames, use the `clearnames` method to force an eventual load.
    """

    def __init__(self, repo, *args):
        dict.__init__(self, *args)
        self._repo = repo
        self.clearnames()

    def clearnames(self):
        """ Clear all remote names state """
        self['bookmarks'] = lazyremotenamedict("bookmarks", self._repo)
        self['branches'] = lazyremotenamedict("branches", self._repo)
        self._invalidatecache()

    def _invalidatecache(self):
        self._nodetobmarks = None
        self._nodetobranch = None

    def bmarktonodes(self):
        return self['bookmarks']

    def nodetobmarks(self):
        if not self._nodetobmarks:
            bmarktonodes = self.bmarktonodes()
            self._nodetobmarks = {}
            for name, node in bmarktonodes.iteritems():
                self._nodetobmarks.setdefault(node[0], []).append(name)
        return self._nodetobmarks

    def branchtonodes(self):
        return self['branches']

    def nodetobranch(self):
        if not self._nodetobranch:
            branchtonodes = self.branchtonodes()
            self._nodetobranch = {}
            for name, nodes in branchtonodes.iteritems():
                for node in nodes:
                    self._nodetobranch.setdefault(node, []).append(name)
        return self._nodetobranch
