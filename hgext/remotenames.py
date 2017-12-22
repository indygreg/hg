# remotenames.py - extension to display remotenames
#
# Copyright 2017 Augie Fackler <raf@durin42.com>
# Copyright 2017 Sean Farley <sean@farley.io>
#
# This software may be used and distributed according to the terms of the
# GNU General Public License version 2 or any later version.

""" showing remotebookmarks and remotebranches in UI """

from __future__ import absolute_import

from mercurial import (
    logexchange,
)

# Note for extension authors: ONLY specify testedwith = 'ships-with-hg-core' for
# extensions which SHIP WITH MERCURIAL. Non-mainline extensions should
# be specifying the version(s) of Mercurial they are tested with, or
# leave the attribute unspecified.
testedwith = 'ships-with-hg-core'

class remotenames(dict):
    """
    This class encapsulates all the remotenames state. It also contains
    methods to access that state in convenient ways.
    """

    def __init__(self, repo, *args):
        dict.__init__(self, *args)
        self._repo = repo
        self['bookmarks'] = {}
        self['branches'] = {}
        self.loadnames()
        self._loadednames = True

    def loadnames(self):
        """ loads the remotenames information from the remotenames file """
        for rtype in ('bookmarks', 'branches'):
            for node, rpath, name in logexchange.readremotenamefile(self._repo,
                                                                    rtype):
                rname = rpath + '/' + name
                self[rtype][rname] = [node]

    def clearnames(self):
        """ Clear all remote names state """
        self['bookmarks'] = {}
        self['branches'] = {}
        self._invalidatecache()
        self._loadednames = False

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
