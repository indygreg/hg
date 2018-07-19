# narrowdirstate.py - extensions to mercurial dirstate to support narrow clones
#
# Copyright 2017 Google, Inc.
#
# This software may be used and distributed according to the terms of the
# GNU General Public License version 2 or any later version.

from __future__ import absolute_import

from mercurial.i18n import _
from mercurial import (
    error,
    match as matchmod,
    narrowspec,
    util as hgutil,
)

def wrapdirstate(repo, dirstate):
    """Add narrow spec dirstate ignore, block changes outside narrow spec."""

    def _editfunc(fn):
        def _wrapper(self, *args):
            dirstate = repo.dirstate
            narrowmatch = repo.narrowmatch()
            for f in args:
                if f is not None and not narrowmatch(f) and f not in dirstate:
                    raise error.Abort(_("cannot track '%s' - it is outside " +
                        "the narrow clone") % f)
            return fn(self, *args)
        return _wrapper

    def _narrowbackupname(backupname):
        assert 'dirstate' in backupname
        return backupname.replace('dirstate', narrowspec.FILENAME)

    class narrowdirstate(dirstate.__class__):
        def walk(self, match, subrepos, unknown, ignored, full=True,
                 narrowonly=True):
            if narrowonly:
                # hack to not exclude explicitly-specified paths so that they
                # can be warned later on e.g. dirstate.add()
                em = matchmod.exact(match._root, match._cwd, match.files())
                nm = matchmod.unionmatcher([repo.narrowmatch(), em])
                match = matchmod.intersectmatchers(match, nm)
            return super(narrowdirstate, self).walk(match, subrepos, unknown,
                                                    ignored, full)

        # Prevent adding/editing/copying/deleting files that are outside the
        # sparse checkout
        @_editfunc
        def normal(self, *args):
            return super(narrowdirstate, self).normal(*args)

        @_editfunc
        def add(self, *args):
            return super(narrowdirstate, self).add(*args)

        @_editfunc
        def normallookup(self, *args):
            return super(narrowdirstate, self).normallookup(*args)

        @_editfunc
        def copy(self, *args):
            return super(narrowdirstate, self).copy(*args)

        @_editfunc
        def remove(self, *args):
            return super(narrowdirstate, self).remove(*args)

        @_editfunc
        def merge(self, *args):
            return super(narrowdirstate, self).merge(*args)

        def rebuild(self, parent, allfiles, changedfiles=None):
            if changedfiles is None:
                # Rebuilding entire dirstate, let's filter allfiles to match the
                # narrowspec.
                allfiles = [f for f in allfiles if repo.narrowmatch()(f)]
            super(narrowdirstate, self).rebuild(parent, allfiles, changedfiles)

        def restorebackup(self, tr, backupname):
            self._opener.rename(_narrowbackupname(backupname),
                                narrowspec.FILENAME, checkambig=True)
            super(narrowdirstate, self).restorebackup(tr, backupname)

        def savebackup(self, tr, backupname):
            super(narrowdirstate, self).savebackup(tr, backupname)

            narrowbackupname = _narrowbackupname(backupname)
            self._opener.tryunlink(narrowbackupname)
            hgutil.copyfile(self._opener.join(narrowspec.FILENAME),
                            self._opener.join(narrowbackupname), hardlink=True)

        def clearbackup(self, tr, backupname):
            super(narrowdirstate, self).clearbackup(tr, backupname)
            self._opener.unlink(_narrowbackupname(backupname))

    dirstate.__class__ = narrowdirstate
    return dirstate
