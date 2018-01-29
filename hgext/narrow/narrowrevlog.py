# narrowrevlog.py - revlog storing irrelevant nodes as "ellipsis" nodes
#
# Copyright 2017 Google, Inc.
#
# This software may be used and distributed according to the terms of the
# GNU General Public License version 2 or any later version.

from __future__ import absolute_import

from mercurial import (
   manifest,
   revlog,
   util,
)

ELLIPSIS_NODE_FLAG = 1 << 14
revlog.REVIDX_KNOWN_FLAGS |= ELLIPSIS_NODE_FLAG
if (util.safehasattr(revlog, 'REVIDX_FLAGS_ORDER') and
    ELLIPSIS_NODE_FLAG not in revlog.REVIDX_FLAGS_ORDER):
        revlog.REVIDX_FLAGS_ORDER.append(ELLIPSIS_NODE_FLAG)

def readtransform(self, text):
    return text, False

def writetransform(self, text):
    return text, False

def rawtransform(self, text):
    return False

if util.safehasattr(revlog, 'addflagprocessor'):
    revlog.addflagprocessor(ELLIPSIS_NODE_FLAG,
                            (readtransform, writetransform, rawtransform))

def setup():
    # We just wanted to add the flag processor, which is done at module
    # load time.
    pass

class excludeddir(manifest.treemanifest):
    def __init__(self, dir, node):
        super(excludeddir, self).__init__(dir)
        self._node = node
        # Add an empty file, which will be included by iterators and such,
        # appearing as the directory itself (i.e. something like "dir/")
        self._files[''] = node
        self._flags[''] = 't'

    # Manifests outside the narrowspec should never be modified, so avoid
    # copying. This makes a noticeable difference when there are very many
    # directories outside the narrowspec. Also, it makes sense for the copy to
    # be of the same type as the original, which would not happen with the
    # super type's copy().
    def copy(self):
        return self

class excludeddirmanifestctx(manifest.treemanifestctx):
    def __init__(self, dir, node):
        self._dir = dir
        self._node = node

    def read(self):
        return excludeddir(self._dir, self._node)

    def write(self, *args):
        raise AssertionError('Attempt to write manifest from excluded dir %s' %
                             self._dir)

class excludedmanifestrevlog(manifest.manifestrevlog):
    def __init__(self, dir):
        self._dir = dir

    def __len__(self):
        raise AssertionError('Attempt to get length of excluded dir %s' %
                             self._dir)

    def rev(self, node):
        raise AssertionError('Attempt to get rev from excluded dir %s' %
                             self._dir)

    def linkrev(self, node):
        raise AssertionError('Attempt to get linkrev from excluded dir %s' %
                             self._dir)

    def node(self, rev):
        raise AssertionError('Attempt to get node from excluded dir %s' %
                             self._dir)

    def add(self, *args, **kwargs):
        # We should never write entries in dirlogs outside the narrow clone.
        # However, the method still gets called from writesubtree() in
        # _addtree(), so we need to handle it. We should possibly make that
        # avoid calling add() with a clean manifest (_dirty is always False
        # in excludeddir instances).
        pass

def makenarrowmanifestrevlog(mfrevlog, repo):
    if util.safehasattr(mfrevlog, '_narrowed'):
        return

    class narrowmanifestrevlog(mfrevlog.__class__):
        # This function is called via debug{revlog,index,data}, but also during
        # at least some push operations. This will be used to wrap/exclude the
        # child directories when using treemanifests.
        def dirlog(self, dir):
            if dir and not dir.endswith('/'):
                dir = dir + '/'
            if not repo.narrowmatch().visitdir(dir[:-1] or '.'):
                return excludedmanifestrevlog(dir)
            result = super(narrowmanifestrevlog, self).dirlog(dir)
            makenarrowmanifestrevlog(result, repo)
            return result

    mfrevlog.__class__ = narrowmanifestrevlog
    mfrevlog._narrowed = True

def makenarrowmanifestlog(mfl, repo):
    class narrowmanifestlog(mfl.__class__):
        def get(self, dir, node, verify=True):
            if not repo.narrowmatch().visitdir(dir[:-1] or '.'):
                return excludeddirmanifestctx(dir, node)
            return super(narrowmanifestlog, self).get(dir, node, verify=verify)
    mfl.__class__ = narrowmanifestlog

def makenarrowfilelog(fl, narrowmatch):
    class narrowfilelog(fl.__class__):
        def renamed(self, node):
            m = super(narrowfilelog, self).renamed(node)
            if m and not narrowmatch(m[0]):
                return None
            return m

        def size(self, rev):
            # We take advantage of the fact that remotefilelog
            # lacks a node() method to just skip the
            # rename-checking logic when on remotefilelog. This
            # might be incorrect on other non-revlog-based storage
            # engines, but for now this seems to be fine.
            if util.safehasattr(self, 'node'):
                node = self.node(rev)
                # Because renamed() is overridden above to
                # sometimes return None even if there is metadata
                # in the revlog, size can be incorrect for
                # copies/renames, so we need to make sure we call
                # the super class's implementation of renamed()
                # for the purpose of size calculation.
                if super(narrowfilelog, self).renamed(node):
                    return len(self.read(node))
            return super(narrowfilelog, self).size(rev)

        def cmp(self, node, text):
            different = super(narrowfilelog, self).cmp(node, text)
            if different:
                # Similar to size() above, if the file was copied from
                # a file outside the narrowspec, the super class's
                # would have returned True because we tricked it into
                # thinking that the file was not renamed.
                if super(narrowfilelog, self).renamed(node):
                    t2 = self.read(node)
                    return t2 != text
            return different

    fl.__class__ = narrowfilelog
