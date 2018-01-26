# narrowdirstate.py - extensions to mercurial dirstate to support narrow clones
#
# Copyright 2017 Google, Inc.
#
# This software may be used and distributed according to the terms of the
# GNU General Public License version 2 or any later version.

from __future__ import absolute_import

from mercurial.i18n import _
from mercurial import (
    dirstate,
    error,
    extensions,
    match as matchmod,
    narrowspec,
    util as hgutil,
)

def setup(repo):
    """Add narrow spec dirstate ignore, block changes outside narrow spec."""

    def walk(orig, self, match, subrepos, unknown, ignored, full=True,
             narrowonly=True):
        if narrowonly:
            # hack to not exclude explicitly-specified paths so that they can
            # be warned later on e.g. dirstate.add()
            em = matchmod.exact(match._root, match._cwd, match.files())
            nm = matchmod.unionmatcher([repo.narrowmatch(), em])
            match = matchmod.intersectmatchers(match, nm)
        return orig(self, match, subrepos, unknown, ignored, full)

    extensions.wrapfunction(dirstate.dirstate, 'walk', walk)

    # Prevent adding files that are outside the sparse checkout
    editfuncs = ['normal', 'add', 'normallookup', 'copy', 'remove', 'merge']
    for func in editfuncs:
        def _wrapper(orig, self, *args):
            dirstate = repo.dirstate
            narrowmatch = repo.narrowmatch()
            for f in args:
                if f is not None and not narrowmatch(f) and f not in dirstate:
                    raise error.Abort(_("cannot track '%s' - it is outside " +
                        "the narrow clone") % f)
            return orig(self, *args)
        extensions.wrapfunction(dirstate.dirstate, func, _wrapper)

    def filterrebuild(orig, self, parent, allfiles, changedfiles=None):
        if changedfiles is None:
            # Rebuilding entire dirstate, let's filter allfiles to match the
            # narrowspec.
            allfiles = [f for f in allfiles if repo.narrowmatch()(f)]
        orig(self, parent, allfiles, changedfiles)

    extensions.wrapfunction(dirstate.dirstate, 'rebuild', filterrebuild)

    def _narrowbackupname(backupname):
        assert 'dirstate' in backupname
        return backupname.replace('dirstate', narrowspec.FILENAME)

    def restorebackup(orig, self, tr, backupname):
        self._opener.rename(_narrowbackupname(backupname), narrowspec.FILENAME,
                            checkambig=True)
        orig(self, tr, backupname)

    extensions.wrapfunction(dirstate.dirstate, 'restorebackup', restorebackup)

    def savebackup(orig, self, tr, backupname):
        orig(self, tr, backupname)

        narrowbackupname = _narrowbackupname(backupname)
        self._opener.tryunlink(narrowbackupname)
        hgutil.copyfile(self._opener.join(narrowspec.FILENAME),
                        self._opener.join(narrowbackupname), hardlink=True)

    extensions.wrapfunction(dirstate.dirstate, 'savebackup', savebackup)

    def clearbackup(orig, self, tr, backupname):
        orig(self, tr, backupname)
        self._opener.unlink(_narrowbackupname(backupname))

    extensions.wrapfunction(dirstate.dirstate, 'clearbackup', clearbackup)
