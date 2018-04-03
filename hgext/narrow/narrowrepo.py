# narrowrepo.py - repository which supports narrow revlogs, lazy loading
#
# Copyright 2017 Google, Inc.
#
# This software may be used and distributed according to the terms of the
# GNU General Public License version 2 or any later version.

from __future__ import absolute_import

from mercurial import (
    bundlerepo,
    changegroup,
    hg,
    localrepo,
    narrowspec,
    scmutil,
)

from . import (
    narrowrevlog,
)

def wrappostshare(orig, sourcerepo, destrepo, **kwargs):
    orig(sourcerepo, destrepo, **kwargs)
    if changegroup.NARROW_REQUIREMENT in sourcerepo.requirements:
        with destrepo.wlock():
            with destrepo.vfs('shared', 'a') as fp:
                fp.write(narrowspec.FILENAME + '\n')

def unsharenarrowspec(orig, ui, repo, repopath):
    if (changegroup.NARROW_REQUIREMENT in repo.requirements
        and repo.path == repopath and repo.shared()):
        srcrepo = hg.sharedreposource(repo)
        with srcrepo.vfs(narrowspec.FILENAME) as f:
            spec = f.read()
        with repo.vfs(narrowspec.FILENAME, 'w') as f:
            f.write(spec)
    return orig(ui, repo, repopath)

def wraprepo(repo):
    """Enables narrow clone functionality on a single local repository."""

    cacheprop = localrepo.storecache
    if isinstance(repo, bundlerepo.bundlerepository):
        # We have to use a different caching property decorator for
        # bundlerepo because storecache blows up in strange ways on a
        # bundlerepo. Fortunately, there's no risk of data changing in
        # a bundlerepo.
        cacheprop = lambda name: localrepo.unfilteredpropertycache

    class narrowrepository(repo.__class__):

        def file(self, f):
            fl = super(narrowrepository, self).file(f)
            narrowrevlog.makenarrowfilelog(fl, self.narrowmatch())
            return fl

        # I'm not sure this is the right place to do this filter.
        # context._manifestmatches() would probably be better, or perhaps
        # move it to a later place, in case some of the callers do want to know
        # which directories changed. This seems to work for now, though.
        def status(self, *args, **kwargs):
            s = super(narrowrepository, self).status(*args, **kwargs)
            narrowmatch = self.narrowmatch()
            modified = list(filter(narrowmatch, s.modified))
            added = list(filter(narrowmatch, s.added))
            removed = list(filter(narrowmatch, s.removed))
            deleted = list(filter(narrowmatch, s.deleted))
            unknown = list(filter(narrowmatch, s.unknown))
            ignored = list(filter(narrowmatch, s.ignored))
            clean = list(filter(narrowmatch, s.clean))
            return scmutil.status(modified, added, removed, deleted, unknown,
                                  ignored, clean)

    repo.__class__ = narrowrepository
