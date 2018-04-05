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
    repository,
    revlog,
)

@zi.implementer(repository.ifilestorage)
class filelog(revlog.revlog):
    def __init__(self, opener, path):
        super(filelog, self).__init__(opener,
                        "/".join(("data", path + ".i")),
                                      censorable=True)
        # full name of the user visible file, relative to the repository root
        self.filename = path

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
        return super(filelog, self).size(rev)

    def cmp(self, node, text):
        """compare text with a given file revision

        returns True if text is different than what is stored.
        """

        t = text
        if text.startswith('\1\n'):
            t = '\1\n\1\n' + text

        samehashes = not super(filelog, self).cmp(node, t)
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
