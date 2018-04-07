# filelog.py - file history class for mercurial
#
# Copyright 2005-2007 Matt Mackall <mpm@selenic.com>
#
# This software may be used and distributed according to the terms of the
# GNU General Public License version 2 or any later version.

from __future__ import absolute_import

from .thirdparty.zope import (
    interface as zi,
)
from . import (
    error,
    repository,
    revlog,
)

@zi.implementer(repository.ifilestorage)
class filelog(object):
    def __init__(self, opener, path):
        self._revlog = revlog.revlog(opener,
                                     '/'.join(('data', path + '.i')),
                                     censorable=True)
        # full name of the user visible file, relative to the repository root
        self.filename = path
        self.index = self._revlog.index
        self.version = self._revlog.version
        self.storedeltachains = self._revlog.storedeltachains
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

    def flags(self, rev):
        return self._revlog.flags(rev)

    def commonancestorsheads(self, node1, node2):
        return self._revlog.commonancestorsheads(node1, node2)

    def descendants(self, revs):
        return self._revlog.descendants(revs)

    def headrevs(self):
        return self._revlog.headrevs()

    def heads(self, start=None, stop=None):
        return self._revlog.heads(start, stop)

    def children(self, node):
        return self._revlog.children(node)

    def deltaparent(self, rev):
        return self._revlog.deltaparent(rev)

    def candelta(self, baserev, rev):
        return self._revlog.candelta(baserev, rev)

    def iscensored(self, rev):
        return self._revlog.iscensored(rev)

    def rawsize(self, rev):
        return self._revlog.rawsize(rev)

    def checkhash(self, text, node, p1=None, p2=None, rev=None):
        return self._revlog.checkhash(text, node, p1=p1, p2=p2, rev=rev)

    def revision(self, node, _df=None, raw=False):
        return self._revlog.revision(node, _df=_df, raw=raw)

    def revdiff(self, rev1, rev2):
        return self._revlog.revdiff(rev1, rev2)

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

    def files(self):
        return self._revlog.files()

    def checksize(self):
        return self._revlog.checksize()

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
        if m and "copy" in m:
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

    @property
    def filename(self):
        return self._revlog.filename

    @filename.setter
    def filename(self, value):
        self._revlog.filename = value

    # TODO these aren't part of the interface and aren't internal methods.
    # Callers should be fixed to not use them.
    @property
    def indexfile(self):
        return self._revlog.indexfile

    @indexfile.setter
    def indexfile(self, value):
        self._revlog.indexfile = value

    @property
    def datafile(self):
        return self._revlog.datafile

    @property
    def opener(self):
        return self._revlog.opener

    @property
    def _lazydeltabase(self):
        return self._revlog._lazydeltabase

    @_lazydeltabase.setter
    def _lazydeltabase(self, value):
        self._revlog._lazydeltabase = value

    @property
    def _aggressivemergedeltas(self):
        return self._revlog._aggressivemergedeltas

    @_aggressivemergedeltas.setter
    def _aggressivemergedeltas(self, value):
        self._revlog._aggressivemergedeltas = value

    @property
    def _inline(self):
        return self._revlog._inline

    @property
    def _withsparseread(self):
        return getattr(self._revlog, '_withsparseread', False)

    @property
    def _srmingapsize(self):
        return self._revlog._srmingapsize

    @property
    def _srdensitythreshold(self):
        return self._revlog._srdensitythreshold

    def _deltachain(self, rev, stoprev=None):
        return self._revlog._deltachain(rev, stoprev)

    def chainbase(self, rev):
        return self._revlog.chainbase(rev)

    def chainlen(self, rev):
        return self._revlog.chainlen(rev)

    def clone(self, tr, destrevlog, **kwargs):
        if not isinstance(destrevlog, filelog):
            raise error.ProgrammingError('expected filelog to clone()')

        return self._revlog.clone(tr, destrevlog._revlog, **kwargs)

    def start(self, rev):
        return self._revlog.start(rev)

    def end(self, rev):
        return self._revlog.end(rev)

    def length(self, rev):
        return self._revlog.length(rev)

    def compress(self, data):
        return self._revlog.compress(data)

    def _addrevision(self, *args, **kwargs):
        return self._revlog._addrevision(*args, **kwargs)
