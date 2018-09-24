# filelog.py - file history class for mercurial
#
# Copyright 2005-2007 Matt Mackall <mpm@selenic.com>
#
# This software may be used and distributed according to the terms of the
# GNU General Public License version 2 or any later version.

from __future__ import absolute_import

from . import (
    error,
    repository,
    revlog,
)
from .utils import (
    interfaceutil,
)

@interfaceutil.implementer(repository.ifilestorage)
class filelog(object):
    def __init__(self, opener, path):
        self._revlog = revlog.revlog(opener,
                                     '/'.join(('data', path + '.i')),
                                     censorable=True)
        # Full name of the user visible file, relative to the repository root.
        # Used by LFS.
        self._revlog.filename = path
        # Used by changegroup generation.
        self._generaldelta = self._revlog._generaldelta

    def __len__(self):
        return len(self._revlog)

    def __iter__(self):
        return self._revlog.__iter__()

    def revs(self, start=0, stop=None):
        return self._revlog.revs(start=start, stop=stop)

    def parents(self, node):
        return self._revlog.parents(node)

    def parentrevs(self, rev):
        return self._revlog.parentrevs(rev)

    def rev(self, node):
        return self._revlog.rev(node)

    def node(self, rev):
        return self._revlog.node(rev)

    def lookup(self, node):
        return self._revlog.lookup(node)

    def linkrev(self, rev):
        return self._revlog.linkrev(rev)

    # Used by verify.
    def flags(self, rev):
        return self._revlog.flags(rev)

    def commonancestorsheads(self, node1, node2):
        return self._revlog.commonancestorsheads(node1, node2)

    # Used by dagop.blockdescendants().
    def descendants(self, revs):
        return self._revlog.descendants(revs)

    def heads(self, start=None, stop=None):
        return self._revlog.heads(start, stop)

    # Used by hgweb, children extension.
    def children(self, node):
        return self._revlog.children(node)

    def deltaparent(self, rev):
        return self._revlog.deltaparent(rev)

    def iscensored(self, rev):
        return self._revlog.iscensored(rev)

    # Used by repo upgrade, verify.
    def rawsize(self, rev):
        return self._revlog.rawsize(rev)

    # Might be unused.
    def checkhash(self, text, node, p1=None, p2=None, rev=None):
        return self._revlog.checkhash(text, node, p1=p1, p2=p2, rev=rev)

    def revision(self, node, _df=None, raw=False):
        return self._revlog.revision(node, _df=_df, raw=raw)

    def revdiff(self, rev1, rev2):
        return self._revlog.revdiff(rev1, rev2)

    def emitrevisions(self, nodes, nodesorder=None,
                      revisiondata=False, assumehaveparentrevisions=False,
                      deltaprevious=False):
        return self._revlog.emitrevisions(
            nodes, nodesorder=nodesorder, revisiondata=revisiondata,
            assumehaveparentrevisions=assumehaveparentrevisions,
            deltaprevious=deltaprevious)

    def addrevision(self, revisiondata, transaction, linkrev, p1, p2,
                    node=None, flags=revlog.REVIDX_DEFAULT_FLAGS,
                    cachedelta=None):
        return self._revlog.addrevision(revisiondata, transaction, linkrev,
                                    p1, p2, node=node, flags=flags,
                                    cachedelta=cachedelta)

    def addgroup(self, deltas, linkmapper, transaction, addrevisioncb=None):
        return self._revlog.addgroup(deltas, linkmapper, transaction,
                                 addrevisioncb=addrevisioncb)

    def getstrippoint(self, minlink):
        return self._revlog.getstrippoint(minlink)

    def strip(self, minlink, transaction):
        return self._revlog.strip(minlink, transaction)

    def censorrevision(self, tr, node, tombstone=b''):
        return self._revlog.censorrevision(node, tombstone=tombstone)

    def files(self):
        return self._revlog.files()

    def read(self, node):
        t = self.revision(node)
        if not t.startswith('\1\n'):
            return t
        s = t.index('\1\n', 2)
        return t[s + 2:]

    def add(self, text, meta, transaction, link, p1=None, p2=None):
        if meta or text.startswith('\1\n'):
            text = revlog.packmeta(meta, text)
        return self.addrevision(text, transaction, link, p1, p2)

    def renamed(self, node):
        if self.parents(node)[0] != revlog.nullid:
            return False
        t = self.revision(node)
        m = revlog.parsemeta(t)[0]
        # copy and copyrev occur in pairs. In rare cases due to bugs,
        # one can occur without the other.
        if m and "copy" in m and "copyrev" in m:
            return (m["copy"], revlog.bin(m["copyrev"]))
        return False

    def size(self, rev):
        """return the size of a given revision"""

        # for revisions with renames, we have to go the slow way
        node = self.node(rev)
        if self.renamed(node):
            return len(self.read(node))
        if self.iscensored(rev):
            return 0

        # XXX if self.read(node).startswith("\1\n"), this returns (size+4)
        return self._revlog.size(rev)

    def cmp(self, node, text):
        """compare text with a given file revision

        returns True if text is different than what is stored.
        """

        t = text
        if text.startswith('\1\n'):
            t = '\1\n\1\n' + text

        samehashes = not self._revlog.cmp(node, t)
        if samehashes:
            return False

        # censored files compare against the empty file
        if self.iscensored(self.rev(node)):
            return text != ''

        # renaming a file produces a different hash, even if the data
        # remains unchanged. Check if it's the case (slow):
        if self.renamed(node):
            t2 = self.read(node)
            return t2 != text

        return True

    def verifyintegrity(self, state):
        return self._revlog.verifyintegrity(state)

    # TODO these aren't part of the interface and aren't internal methods.
    # Callers should be fixed to not use them.

    # Used by bundlefilelog, unionfilelog.
    @property
    def indexfile(self):
        return self._revlog.indexfile

    @indexfile.setter
    def indexfile(self, value):
        self._revlog.indexfile = value

    # Used by repo upgrade.
    @property
    def opener(self):
        return self._revlog.opener

    # Used by repo upgrade.
    def clone(self, tr, destrevlog, **kwargs):
        if not isinstance(destrevlog, filelog):
            raise error.ProgrammingError('expected filelog to clone()')

        return self._revlog.clone(tr, destrevlog._revlog, **kwargs)

class narrowfilelog(filelog):
    """Filelog variation to be used with narrow stores."""

    def __init__(self, opener, path, narrowmatch):
        super(narrowfilelog, self).__init__(opener, path)
        self._narrowmatch = narrowmatch

    def renamed(self, node):
        res = super(narrowfilelog, self).renamed(node)

        # Renames that come from outside the narrowspec are problematic
        # because we may lack the base text for the rename. This can result
        # in code attempting to walk the ancestry or compute a diff
        # encountering a missing revision. We address this by silently
        # removing rename metadata if the source file is outside the
        # narrow spec.
        #
        # A better solution would be to see if the base revision is available,
        # rather than assuming it isn't.
        #
        # An even better solution would be to teach all consumers of rename
        # metadata that the base revision may not be available.
        #
        # TODO consider better ways of doing this.
        if res and not self._narrowmatch(res[0]):
            return None

        return res

    def size(self, rev):
        # Because we have a custom renamed() that may lie, we need to call
        # the base renamed() to report accurate results.
        node = self.node(rev)
        if super(narrowfilelog, self).renamed(node):
            return len(self.read(node))
        else:
            return super(narrowfilelog, self).size(rev)

    def cmp(self, node, text):
        different = super(narrowfilelog, self).cmp(node, text)

        # Because renamed() may lie, we may get false positives for
        # different content. Check for this by comparing against the original
        # renamed() implementation.
        if different:
            if super(narrowfilelog, self).renamed(node):
                t2 = self.read(node)
                return t2 != text

        return different
