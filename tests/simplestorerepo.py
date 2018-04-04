# simplestorerepo.py - Extension that swaps in alternate repository storage.
#
# Copyright 2018 Gregory Szorc <gregory.szorc@gmail.com>
#
# This software may be used and distributed according to the terms of the
# GNU General Public License version 2 or any later version.

# To use this with the test suite:
#
#   $ HGREPOFEATURES="simplestore" ./run-tests.py \
#       --extra-config-opt extensions.simplestore=`pwd`/simplestorerepo.py

from __future__ import absolute_import

from mercurial.i18n import _
from mercurial.node import (
    bin,
    hex,
    nullid,
    nullrev,
)
from mercurial.thirdparty import (
    cbor,
)
from mercurial import (
    ancestor,
    error,
    filelog,
    mdiff,
    pycompat,
    revlog,
)

# Note for extension authors: ONLY specify testedwith = 'ships-with-hg-core' for
# extensions which SHIP WITH MERCURIAL. Non-mainline extensions should
# be specifying the version(s) of Mercurial they are tested with, or
# leave the attribute unspecified.
testedwith = 'ships-with-hg-core'

def validatenode(node):
    if isinstance(node, int):
        raise ValueError('expected node; got int')

    if len(node) != 20:
        raise ValueError('expected 20 byte node')

def validaterev(rev):
    if not isinstance(rev, int):
        raise ValueError('expected int')

class filestorage(object):
    """Implements storage for a tracked path.

    Data is stored in the VFS in a directory corresponding to the tracked
    path.

    Index data is stored in an ``index`` file using CBOR.

    Fulltext data is stored in files having names of the node.
    """

    def __init__(self, svfs, path):
        self._svfs = svfs
        self._path = path

        self._storepath = b'/'.join([b'data', path])
        self._indexpath = b'/'.join([self._storepath, b'index'])

        indexdata = self._svfs.tryread(self._indexpath)
        if indexdata:
            indexdata = cbor.loads(indexdata)

        self._indexdata = indexdata or []
        self._indexbynode = {}
        self._indexbyrev = {}
        self.index = []
        self._refreshindex()

        # This is used by changegroup code :/
        self._generaldelta = True
        self.storedeltachains = False

        self.version = 1

    def _refreshindex(self):
        self._indexbynode.clear()
        self._indexbyrev.clear()
        self.index = []

        for i, entry in enumerate(self._indexdata):
            self._indexbynode[entry[b'node']] = entry
            self._indexbyrev[i] = entry

        self._indexbynode[nullid] = {
            b'node': nullid,
            b'p1': nullid,
            b'p2': nullid,
            b'linkrev': nullrev,
            b'flags': 0,
        }

        self._indexbyrev[nullrev] = {
            b'node': nullid,
            b'p1': nullid,
            b'p2': nullid,
            b'linkrev': nullrev,
            b'flags': 0,
        }

        for i, entry in enumerate(self._indexdata):
            p1rev, p2rev = self.parentrevs(self.rev(entry[b'node']))

            # start, length, rawsize, chainbase, linkrev, p1, p2, node
            self.index.append((0, 0, 0, -1, entry[b'linkrev'], p1rev, p2rev,
                               entry[b'node']))

        self.index.append((0, 0, 0, -1, -1, -1, -1, nullid))

    def __len__(self):
        return len(self._indexdata)

    def __iter__(self):
        return iter(range(len(self)))

    def revs(self, start=0, stop=None):
        step = 1
        if stop is not None:
            if start > stop:
                step = -1

            stop += step
        else:
            stop = len(self)

        return range(start, stop, step)

    def parents(self, node):
        validatenode(node)

        if node not in self._indexbynode:
            raise KeyError('unknown node')

        entry = self._indexbynode[node]

        return entry[b'p1'], entry[b'p2']

    def parentrevs(self, rev):
        p1, p2 = self.parents(self._indexbyrev[rev][b'node'])
        return self.rev(p1), self.rev(p2)

    def rev(self, node):
        validatenode(node)

        # Will raise KeyError.
        self._indexbynode[node]

        for rev, entry in self._indexbyrev.items():
            if entry[b'node'] == node:
                return rev

        raise error.ProgrammingError('this should not occur')

    def node(self, rev):
        validaterev(rev)

        return self._indexbyrev[rev][b'node']

    def lookup(self, node):
        if isinstance(node, int):
            return self.node(node)

        if len(node) == 20:
            try:
                self.rev(node)
                return node
            except LookupError:
                pass

        try:
            rev = int(node)
            if '%d' % rev != node:
                raise ValueError

            if rev < 0:
                rev = len(self) + rev
            if rev < 0 or rev >= len(self):
                raise ValueError

            return self.node(rev)
        except (ValueError, OverflowError):
            pass

        if len(node) == 40:
            try:
                rawnode = bin(node)
                self.rev(rawnode)
                return rawnode
            except (TypeError, LookupError):
                pass

        raise LookupError(node, self._path, _('invalid lookup input'))

    def linkrev(self, rev):
        validaterev(rev)

        return self._indexbyrev[rev][b'linkrev']

    def flags(self, rev):
        validaterev(rev)

        return self._indexbyrev[rev][b'flags']

    def deltaparent(self, rev):
        validaterev(rev)

        p1node = self.parents(self.node(rev))[0]
        return self.rev(p1node)

    def candelta(self, baserev, rev):
        validaterev(baserev)
        validaterev(rev)

        if ((self.flags(baserev) & revlog.REVIDX_RAWTEXT_CHANGING_FLAGS)
            or (self.flags(rev) & revlog.REVIDX_RAWTEXT_CHANGING_FLAGS)):
            return False

        return True

    def rawsize(self, rev):
        validaterev(rev)
        node = self.node(rev)
        return len(self.revision(node, raw=True))

    def _processflags(self, text, flags, operation, raw=False):
        if flags == 0:
            return text, True

        validatehash = True
        # Depending on the operation (read or write), the order might be
        # reversed due to non-commutative transforms.
        orderedflags = revlog.REVIDX_FLAGS_ORDER
        if operation == 'write':
            orderedflags = reversed(orderedflags)

        for flag in orderedflags:
            # If a flagprocessor has been registered for a known flag, apply the
            # related operation transform and update result tuple.
            if flag & flags:
                vhash = True

                if flag not in revlog._flagprocessors:
                    message = _("missing processor for flag '%#x'") % (flag)
                    raise revlog.RevlogError(message)

                processor = revlog._flagprocessors[flag]
                if processor is not None:
                    readtransform, writetransform, rawtransform = processor

                    if raw:
                        vhash = rawtransform(self, text)
                    elif operation == 'read':
                        text, vhash = readtransform(self, text)
                    else:  # write operation
                        text, vhash = writetransform(self, text)
                validatehash = validatehash and vhash

        return text, validatehash

    def checkhash(self, text, node, p1=None, p2=None, rev=None):
        if p1 is None and p2 is None:
            p1, p2 = self.parents(node)
        if node != revlog.hash(text, p1, p2):
            raise error.RevlogError(_("integrity check failed on %s") %
                self._path)

    def revision(self, node, raw=False):
        validatenode(node)

        if node == nullid:
            return b''

        self._indexbynode[node]

        rev = self.rev(node)
        flags = self.flags(rev)

        path = b'/'.join([self._storepath, hex(node)])
        rawtext = self._svfs.read(path)

        text, validatehash = self._processflags(rawtext, flags, 'read', raw=raw)
        if validatehash:
            self.checkhash(text, node, rev=rev)

        return text

    def read(self, node):
        validatenode(node)

        revision = self.revision(node)

        if not revision.startswith(b'\1\n'):
            return revision

        start = revision.index(b'\1\n', 2)
        return revision[start + 2:]

    def renamed(self, node):
        validatenode(node)

        if self.parents(node)[0] != nullid:
            return False

        fulltext = self.revision(node)
        m = filelog.parsemeta(fulltext)[0]

        if m and 'copy' in m:
            return m['copy'], bin(m['copyrev'])

        return False

    def cmp(self, node, text):
        validatenode(node)

        t = text

        if text.startswith(b'\1\n'):
            t = b'\1\n\1\n' + text

        p1, p2 = self.parents(node)

        if revlog.hash(t, p1, p2) == node:
            return False

        if self.iscensored(self.rev(node)):
            return text != b''

        if self.renamed(node):
            t2 = self.read(node)
            return t2 != text

        return True

    def size(self, rev):
        validaterev(rev)

        node = self._indexbyrev[rev][b'node']

        if self.renamed(node):
            return len(self.read(node))

        if self.iscensored(rev):
            return 0

        return len(self.revision(node))

    def iscensored(self, rev):
        validaterev(rev)

        return self.flags(rev) & revlog.REVIDX_ISCENSORED

    def commonancestorsheads(self, a, b):
        validatenode(a)
        validatenode(b)

        a = self.rev(a)
        b = self.rev(b)

        ancestors = ancestor.commonancestorsheads(self.parentrevs, a, b)
        return pycompat.maplist(self.node, ancestors)

    def descendants(self, revs):
        # This is a copy of revlog.descendants()
        first = min(revs)
        if first == nullrev:
            for i in self:
                yield i
            return

        seen = set(revs)
        for i in self.revs(start=first + 1):
            for x in self.parentrevs(i):
                if x != nullrev and x in seen:
                    seen.add(i)
                    yield i
                    break

    # Required by verify.
    def files(self):
        entries = self._svfs.listdir(self._storepath)

        # Strip out undo.backup.* files created as part of transaction
        # recording.
        entries = [f for f in entries if not f.startswith('undo.backup.')]

        return [b'/'.join((self._storepath, f)) for f in entries]

    # Required by verify.
    def checksize(self):
        return 0, 0

    def add(self, text, meta, transaction, linkrev, p1, p2):
        if meta or text.startswith(b'\1\n'):
            text = filelog.packmeta(meta, text)

        return self.addrevision(text, transaction, linkrev, p1, p2)

    def addrevision(self, text, transaction, linkrev, p1, p2, node=None,
                    flags=0):
        validatenode(p1)
        validatenode(p2)

        if flags:
            node = node or revlog.hash(text, p1, p2)

        rawtext, validatehash = self._processflags(text, flags, 'write')

        node = node or revlog.hash(text, p1, p2)

        if node in self._indexbynode:
            return node

        if validatehash:
            self.checkhash(rawtext, node, p1=p1, p2=p2)

        path = b'/'.join([self._storepath, hex(node)])

        self._svfs.write(path, text)

        self._indexdata.append({
            b'node': node,
            b'p1': p1,
            b'p2': p2,
            b'linkrev': linkrev,
            b'flags': flags,
        })

        self._reflectindexupdate()

        return node

    def _reflectindexupdate(self):
        self._refreshindex()
        self._svfs.write(self._indexpath, cbor.dumps(self._indexdata))

    def addgroup(self, deltas, linkmapper, transaction, addrevisioncb=None):
        nodes = []

        transaction.addbackup(self._indexpath)

        for node, p1, p2, linknode, deltabase, delta, flags in deltas:
            linkrev = linkmapper(linknode)

            nodes.append(node)

            if node in self._indexbynode:
                continue

            # Need to resolve the fulltext from the delta base.
            if deltabase == nullid:
                text = mdiff.patch(b'', delta)
            else:
                text = mdiff.patch(self.revision(deltabase), delta)

            self.addrevision(text, transaction, linkrev, p1, p2, flags)

            if addrevisioncb:
                addrevisioncb(self, node)

        return nodes

    def revdiff(self, rev1, rev2):
        validaterev(rev1)
        validaterev(rev2)

        node1 = self.node(rev1)
        node2 = self.node(rev2)

        return mdiff.textdiff(self.revision(node1, raw=True),
                              self.revision(node2, raw=True))

    def headrevs(self):
        # Assume all revisions are heads by default.
        revishead = {rev: True for rev in self._indexbyrev}

        for rev, entry in self._indexbyrev.items():
            # Unset head flag for all seen parents.
            revishead[self.rev(entry[b'p1'])] = False
            revishead[self.rev(entry[b'p2'])] = False

        return [rev for rev, ishead in sorted(revishead.items())
                if ishead]

    def heads(self, start=None, stop=None):
        # This is copied from revlog.py.
        if start is None and stop is None:
            if not len(self):
                return [nullid]
            return [self.node(r) for r in self.headrevs()]

        if start is None:
            start = nullid
        if stop is None:
            stop = []
        stoprevs = set([self.rev(n) for n in stop])
        startrev = self.rev(start)
        reachable = {startrev}
        heads = {startrev}

        parentrevs = self.parentrevs
        for r in self.revs(start=startrev + 1):
            for p in parentrevs(r):
                if p in reachable:
                    if r not in stoprevs:
                        reachable.add(r)
                    heads.add(r)
                if p in heads and p not in stoprevs:
                    heads.remove(p)

        return [self.node(r) for r in heads]

    def children(self, node):
        validatenode(node)

        # This is a copy of revlog.children().
        c = []
        p = self.rev(node)
        for r in self.revs(start=p + 1):
            prevs = [pr for pr in self.parentrevs(r) if pr != nullrev]
            if prevs:
                for pr in prevs:
                    if pr == p:
                        c.append(self.node(r))
            elif p == nullrev:
                c.append(self.node(r))
        return c

    def getstrippoint(self, minlink):

        # This is largely a copy of revlog.getstrippoint().
        brokenrevs = set()
        strippoint = len(self)

        heads = {}
        futurelargelinkrevs = set()
        for head in self.headrevs():
            headlinkrev = self.linkrev(head)
            heads[head] = headlinkrev
            if headlinkrev >= minlink:
                futurelargelinkrevs.add(headlinkrev)

        # This algorithm involves walking down the rev graph, starting at the
        # heads. Since the revs are topologically sorted according to linkrev,
        # once all head linkrevs are below the minlink, we know there are
        # no more revs that could have a linkrev greater than minlink.
        # So we can stop walking.
        while futurelargelinkrevs:
            strippoint -= 1
            linkrev = heads.pop(strippoint)

            if linkrev < minlink:
                brokenrevs.add(strippoint)
            else:
                futurelargelinkrevs.remove(linkrev)

            for p in self.parentrevs(strippoint):
                if p != nullrev:
                    plinkrev = self.linkrev(p)
                    heads[p] = plinkrev
                    if plinkrev >= minlink:
                        futurelargelinkrevs.add(plinkrev)

        return strippoint, brokenrevs

    def strip(self, minlink, transaction):
        if not len(self):
            return

        rev, _ignored = self.getstrippoint(minlink)
        if rev == len(self):
            return

        # Purge index data starting at the requested revision.
        self._indexdata[rev:] = []
        self._reflectindexupdate()

def reposetup(ui, repo):
    if not repo.local():
        return

    class simplestorerepo(repo.__class__):
        def file(self, f):
            return filestorage(self.svfs, f)

    repo.__class__ = simplestorerepo
