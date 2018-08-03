# narrowrepo.py - repository which supports narrow revlogs, lazy loading
#
# Copyright 2017 Google, Inc.
#
# This software may be used and distributed according to the terms of the
# GNU General Public License version 2 or any later version.

from __future__ import absolute_import

from mercurial import (
    hg,
    narrowspec,
    repository,
)

from . import (
    narrowdirstate,
    narrowrevlog,
)

def wrappostshare(orig, sourcerepo, destrepo, **kwargs):
    orig(sourcerepo, destrepo, **kwargs)
    if repository.NARROW_REQUIREMENT in sourcerepo.requirements:
        with destrepo.wlock():
            with destrepo.vfs('shared', 'a') as fp:
                fp.write(narrowspec.FILENAME + '\n')

def unsharenarrowspec(orig, ui, repo, repopath):
    if (repository.NARROW_REQUIREMENT in repo.requirements
        and repo.path == repopath and repo.shared()):
        srcrepo = hg.sharedreposource(repo)
        with srcrepo.vfs(narrowspec.FILENAME) as f:
            spec = f.read()
        with repo.vfs(narrowspec.FILENAME, 'w') as f:
            f.write(spec)
    return orig(ui, repo, repopath)

def wraprepo(repo):
    """Enables narrow clone functionality on a single local repository."""

    class narrowrepository(repo.__class__):

        def file(self, f):
            fl = super(narrowrepository, self).file(f)
            narrowrevlog.makenarrowfilelog(fl, self.narrowmatch())
            return fl

        def _makedirstate(self):
            dirstate = super(narrowrepository, self)._makedirstate()
            return narrowdirstate.wrapdirstate(self, dirstate)

    repo.__class__ = narrowrepository
