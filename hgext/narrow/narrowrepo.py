# narrowrepo.py - repository which supports narrow revlogs, lazy loading
#
# Copyright 2017 Google, Inc.
#
# This software may be used and distributed according to the terms of the
# GNU General Public License version 2 or any later version.

from __future__ import absolute_import

from mercurial import (
    bundlerepo,
    localrepo,
    match as matchmod,
    scmutil,
)

from .. import (
    share,
)

from . import (
    narrowrevlog,
    narrowspec,
)

REQUIREMENT = 'narrowhg'

def wrappostshare(orig, sourcerepo, destrepo, **kwargs):
    orig(sourcerepo, destrepo, **kwargs)
    if REQUIREMENT in sourcerepo.requirements:
        with destrepo.wlock():
            with destrepo.vfs('shared', 'a') as fp:
                fp.write(narrowspec.FILENAME + '\n')

def unsharenarrowspec(orig, ui, repo, repopath):
    if (REQUIREMENT in repo.requirements
        and repo.path == repopath and repo.shared()):
        srcrepo = share._getsrcrepo(repo)
        with srcrepo.vfs(narrowspec.FILENAME) as f:
            spec = f.read()
        with repo.vfs(narrowspec.FILENAME, 'w') as f:
            f.write(spec)
    return orig(ui, repo, repopath)

def wraprepo(repo, opts_narrow):
    """Enables narrow clone functionality on a single local repository."""

    cacheprop = localrepo.storecache
    if isinstance(repo, bundlerepo.bundlerepository):
        # We have to use a different caching property decorator for
        # bundlerepo because storecache blows up in strange ways on a
        # bundlerepo. Fortunately, there's no risk of data changing in
        # a bundlerepo.
        cacheprop = lambda name: localrepo.unfilteredpropertycache

    class narrowrepository(repo.__class__):

        def _constructmanifest(self):
            manifest = super(narrowrepository, self)._constructmanifest()
            narrowrevlog.makenarrowmanifestrevlog(manifest, repo)
            return manifest

        @cacheprop('00manifest.i')
        def manifestlog(self):
            mfl = super(narrowrepository, self).manifestlog
            narrowrevlog.makenarrowmanifestlog(mfl, self)
            return mfl

        def file(self, f):
            fl = super(narrowrepository, self).file(f)
            narrowrevlog.makenarrowfilelog(fl, self.narrowmatch())
            return fl

        @localrepo.repofilecache(narrowspec.FILENAME)
        def narrowpats(self):
            return narrowspec.load(self)

        @localrepo.repofilecache(narrowspec.FILENAME)
        def _narrowmatch(self):
            include, exclude = self.narrowpats
            if not opts_narrow and not include and not exclude:
                return matchmod.always(self.root, '')
            return narrowspec.match(self.root, include=include, exclude=exclude)

        # TODO(martinvonz): make this property-like instead?
        def narrowmatch(self):
            return self._narrowmatch

        def setnarrowpats(self, newincludes, newexcludes):
            narrowspec.save(self, newincludes, newexcludes)
            self.invalidate(clearfilecache=True)

        # I'm not sure this is the right place to do this filter.
        # context._manifestmatches() would probably be better, or perhaps
        # move it to a later place, in case some of the callers do want to know
        # which directories changed. This seems to work for now, though.
        def status(self, *args, **kwargs):
            s = super(narrowrepository, self).status(*args, **kwargs)
            narrowmatch = self.narrowmatch()
            modified = filter(narrowmatch, s.modified)
            added = filter(narrowmatch, s.added)
            removed = filter(narrowmatch, s.removed)
            deleted = filter(narrowmatch, s.deleted)
            unknown = filter(narrowmatch, s.unknown)
            ignored = filter(narrowmatch, s.ignored)
            clean = filter(narrowmatch, s.clean)
            return scmutil.status(modified, added, removed, deleted, unknown,
                                  ignored, clean)

    repo.__class__ = narrowrepository
