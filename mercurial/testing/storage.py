# storage.py - Testing of storage primitives.
#
# Copyright 2018 Gregory Szorc <gregory.szorc@gmail.com>
#
# This software may be used and distributed according to the terms of the
# GNU General Public License version 2 or any later version.

from __future__ import absolute_import

import unittest

from ..node import (
    hex,
    nullid,
    nullrev,
)
from .. import (
    error,
    mdiff,
    revlog,
)

class basetestcase(unittest.TestCase):
    if not getattr(unittest.TestCase, r'assertRaisesRegex', False):
        assertRaisesRegex = (# camelcase-required
            unittest.TestCase.assertRaisesRegexp)

class revisiondeltarequest(object):
    def __init__(self, node, p1, p2, linknode, basenode, ellipsis):
        self.node = node
        self.p1node = p1
        self.p2node = p2
        self.linknode = linknode
        self.basenode = basenode
        self.ellipsis = ellipsis

class ifileindextests(basetestcase):
    """Generic tests for the ifileindex interface.

    All file storage backends for index data should conform to the tests in this
    class.

    Use ``makeifileindextests()`` to create an instance of this type.
    """
    def testempty(self):
        f = self._makefilefn()
        self.assertEqual(len(f), 0, 'new file store has 0 length by default')
        self.assertEqual(list(f), [], 'iter yields nothing by default')

        gen = iter(f)
        with self.assertRaises(StopIteration):
            next(gen)

        # revs() should evaluate to an empty list.
        self.assertEqual(list(f.revs()), [])

        revs = iter(f.revs())
        with self.assertRaises(StopIteration):
            next(revs)

        self.assertEqual(list(f.revs(start=20)), [])

        # parents() and parentrevs() work with nullid/nullrev.
        self.assertEqual(f.parents(nullid), (nullid, nullid))
        self.assertEqual(f.parentrevs(nullrev), (nullrev, nullrev))

        with self.assertRaises(error.LookupError):
            f.parents(b'\x01' * 20)

        for i in range(-5, 5):
            if i == nullrev:
                continue

            with self.assertRaises(IndexError):
                f.parentrevs(i)

        # nullid/nullrev lookup always works.
        self.assertEqual(f.rev(nullid), nullrev)
        self.assertEqual(f.node(nullrev), nullid)

        with self.assertRaises(error.LookupError):
            f.rev(b'\x01' * 20)

        for i in range(-5, 5):
            if i == nullrev:
                continue

            with self.assertRaises(IndexError):
                f.node(i)

        self.assertEqual(f.lookup(nullid), nullid)
        self.assertEqual(f.lookup(nullrev), nullid)
        self.assertEqual(f.lookup(hex(nullid)), nullid)

        # String converted to integer doesn't work for nullrev.
        with self.assertRaises(error.LookupError):
            f.lookup(b'%d' % nullrev)

        self.assertEqual(f.linkrev(nullrev), nullrev)

        for i in range(-5, 5):
            if i == nullrev:
                continue

            with self.assertRaises(IndexError):
                f.linkrev(i)

        self.assertEqual(f.flags(nullrev), 0)

        for i in range(-5, 5):
            if i == nullrev:
                continue

            with self.assertRaises(IndexError):
                f.flags(i)

        self.assertFalse(f.iscensored(nullrev))

        for i in range(-5, 5):
            if i == nullrev:
                continue

            with self.assertRaises(IndexError):
                f.iscensored(i)

        self.assertEqual(list(f.commonancestorsheads(nullid, nullid)), [])

        with self.assertRaises(ValueError):
            self.assertEqual(list(f.descendants([])), [])

        self.assertEqual(list(f.descendants([nullrev])), [])

        self.assertEqual(f.heads(), [nullid])
        self.assertEqual(f.heads(nullid), [nullid])
        self.assertEqual(f.heads(None, [nullid]), [nullid])
        self.assertEqual(f.heads(nullid, [nullid]), [nullid])

        self.assertEqual(f.children(nullid), [])

        with self.assertRaises(error.LookupError):
            f.children(b'\x01' * 20)

        self.assertEqual(f.deltaparent(nullrev), nullrev)

        for i in range(-5, 5):
            if i == nullrev:
                continue

            with self.assertRaises(IndexError):
                f.deltaparent(i)

    def testsinglerevision(self):
        f = self._makefilefn()
        with self._maketransactionfn() as tr:
            node = f.add(b'initial', None, tr, 0, nullid, nullid)

        self.assertEqual(len(f), 1)
        self.assertEqual(list(f), [0])

        gen = iter(f)
        self.assertEqual(next(gen), 0)

        with self.assertRaises(StopIteration):
            next(gen)

        self.assertEqual(list(f.revs()), [0])
        self.assertEqual(list(f.revs(start=1)), [])
        self.assertEqual(list(f.revs(start=0)), [0])
        self.assertEqual(list(f.revs(stop=0)), [0])
        self.assertEqual(list(f.revs(stop=1)), [0])
        self.assertEqual(list(f.revs(1, 1)), [])
        # TODO buggy
        self.assertEqual(list(f.revs(1, 0)), [1, 0])
        self.assertEqual(list(f.revs(2, 0)), [2, 1, 0])

        self.assertEqual(f.parents(node), (nullid, nullid))
        self.assertEqual(f.parentrevs(0), (nullrev, nullrev))

        with self.assertRaises(error.LookupError):
            f.parents(b'\x01' * 20)

        with self.assertRaises(IndexError):
            f.parentrevs(1)

        self.assertEqual(f.rev(node), 0)

        with self.assertRaises(error.LookupError):
            f.rev(b'\x01' * 20)

        self.assertEqual(f.node(0), node)

        with self.assertRaises(IndexError):
            f.node(1)

        self.assertEqual(f.lookup(node), node)
        self.assertEqual(f.lookup(0), node)
        self.assertEqual(f.lookup(b'0'), node)
        self.assertEqual(f.lookup(hex(node)), node)

        self.assertEqual(f.linkrev(0), 0)

        with self.assertRaises(IndexError):
            f.linkrev(1)

        self.assertEqual(f.flags(0), 0)

        with self.assertRaises(IndexError):
            f.flags(1)

        self.assertFalse(f.iscensored(0))

        with self.assertRaises(IndexError):
            f.iscensored(1)

        self.assertEqual(list(f.descendants([0])), [])

        self.assertEqual(f.heads(), [node])
        self.assertEqual(f.heads(node), [node])
        self.assertEqual(f.heads(stop=[node]), [node])

        with self.assertRaises(error.LookupError):
            f.heads(stop=[b'\x01' * 20])

        self.assertEqual(f.children(node), [])

        self.assertEqual(f.deltaparent(0), nullrev)

    def testmultiplerevisions(self):
        fulltext0 = b'x' * 1024
        fulltext1 = fulltext0 + b'y'
        fulltext2 = b'y' + fulltext0 + b'z'

        f = self._makefilefn()
        with self._maketransactionfn() as tr:
            node0 = f.add(fulltext0, None, tr, 0, nullid, nullid)
            node1 = f.add(fulltext1, None, tr, 1, node0, nullid)
            node2 = f.add(fulltext2, None, tr, 3, node1, nullid)

        self.assertEqual(len(f), 3)
        self.assertEqual(list(f), [0, 1, 2])

        gen = iter(f)
        self.assertEqual(next(gen), 0)
        self.assertEqual(next(gen), 1)
        self.assertEqual(next(gen), 2)

        with self.assertRaises(StopIteration):
            next(gen)

        self.assertEqual(list(f.revs()), [0, 1, 2])
        self.assertEqual(list(f.revs(0)), [0, 1, 2])
        self.assertEqual(list(f.revs(1)), [1, 2])
        self.assertEqual(list(f.revs(2)), [2])
        self.assertEqual(list(f.revs(3)), [])
        self.assertEqual(list(f.revs(stop=1)), [0, 1])
        self.assertEqual(list(f.revs(stop=2)), [0, 1, 2])
        self.assertEqual(list(f.revs(stop=3)), [0, 1, 2])
        self.assertEqual(list(f.revs(2, 0)), [2, 1, 0])
        self.assertEqual(list(f.revs(2, 1)), [2, 1])
        # TODO this is wrong
        self.assertEqual(list(f.revs(3, 2)), [3, 2])

        self.assertEqual(f.parents(node0), (nullid, nullid))
        self.assertEqual(f.parents(node1), (node0, nullid))
        self.assertEqual(f.parents(node2), (node1, nullid))

        self.assertEqual(f.parentrevs(0), (nullrev, nullrev))
        self.assertEqual(f.parentrevs(1), (0, nullrev))
        self.assertEqual(f.parentrevs(2), (1, nullrev))

        self.assertEqual(f.rev(node0), 0)
        self.assertEqual(f.rev(node1), 1)
        self.assertEqual(f.rev(node2), 2)

        with self.assertRaises(error.LookupError):
            f.rev(b'\x01' * 20)

        self.assertEqual(f.node(0), node0)
        self.assertEqual(f.node(1), node1)
        self.assertEqual(f.node(2), node2)

        with self.assertRaises(IndexError):
            f.node(3)

        self.assertEqual(f.lookup(node0), node0)
        self.assertEqual(f.lookup(0), node0)
        self.assertEqual(f.lookup(b'0'), node0)
        self.assertEqual(f.lookup(hex(node0)), node0)

        self.assertEqual(f.lookup(node1), node1)
        self.assertEqual(f.lookup(1), node1)
        self.assertEqual(f.lookup(b'1'), node1)
        self.assertEqual(f.lookup(hex(node1)), node1)

        self.assertEqual(f.linkrev(0), 0)
        self.assertEqual(f.linkrev(1), 1)
        self.assertEqual(f.linkrev(2), 3)

        with self.assertRaises(IndexError):
            f.linkrev(3)

        self.assertEqual(f.flags(0), 0)
        self.assertEqual(f.flags(1), 0)
        self.assertEqual(f.flags(2), 0)

        with self.assertRaises(IndexError):
            f.flags(3)

        self.assertFalse(f.iscensored(0))
        self.assertFalse(f.iscensored(1))
        self.assertFalse(f.iscensored(2))

        with self.assertRaises(IndexError):
            f.iscensored(3)

        self.assertEqual(f.commonancestorsheads(node1, nullid), [])
        self.assertEqual(f.commonancestorsheads(node1, node0), [node0])
        self.assertEqual(f.commonancestorsheads(node1, node1), [node1])
        self.assertEqual(f.commonancestorsheads(node0, node1), [node0])
        self.assertEqual(f.commonancestorsheads(node1, node2), [node1])
        self.assertEqual(f.commonancestorsheads(node2, node1), [node1])

        self.assertEqual(list(f.descendants([0])), [1, 2])
        self.assertEqual(list(f.descendants([1])), [2])
        self.assertEqual(list(f.descendants([0, 1])), [1, 2])

        self.assertEqual(f.heads(), [node2])
        self.assertEqual(f.heads(node0), [node2])
        self.assertEqual(f.heads(node1), [node2])
        self.assertEqual(f.heads(node2), [node2])

        # TODO this behavior seems wonky. Is it correct? If so, the
        # docstring for heads() should be updated to reflect desired
        # behavior.
        self.assertEqual(f.heads(stop=[node1]), [node1, node2])
        self.assertEqual(f.heads(stop=[node0]), [node0, node2])
        self.assertEqual(f.heads(stop=[node1, node2]), [node1, node2])

        with self.assertRaises(error.LookupError):
            f.heads(stop=[b'\x01' * 20])

        self.assertEqual(f.children(node0), [node1])
        self.assertEqual(f.children(node1), [node2])
        self.assertEqual(f.children(node2), [])

        self.assertEqual(f.deltaparent(0), nullrev)
        self.assertEqual(f.deltaparent(1), 0)
        self.assertEqual(f.deltaparent(2), 1)

    def testmultipleheads(self):
        f = self._makefilefn()

        with self._maketransactionfn() as tr:
            node0 = f.add(b'0', None, tr, 0, nullid, nullid)
            node1 = f.add(b'1', None, tr, 1, node0, nullid)
            node2 = f.add(b'2', None, tr, 2, node1, nullid)
            node3 = f.add(b'3', None, tr, 3, node0, nullid)
            node4 = f.add(b'4', None, tr, 4, node3, nullid)
            node5 = f.add(b'5', None, tr, 5, node0, nullid)

        self.assertEqual(len(f), 6)

        self.assertEqual(list(f.descendants([0])), [1, 2, 3, 4, 5])
        self.assertEqual(list(f.descendants([1])), [2])
        self.assertEqual(list(f.descendants([2])), [])
        self.assertEqual(list(f.descendants([3])), [4])
        self.assertEqual(list(f.descendants([0, 1])), [1, 2, 3, 4, 5])
        self.assertEqual(list(f.descendants([1, 3])), [2, 4])

        self.assertEqual(f.heads(), [node2, node4, node5])
        self.assertEqual(f.heads(node0), [node2, node4, node5])
        self.assertEqual(f.heads(node1), [node2])
        self.assertEqual(f.heads(node2), [node2])
        self.assertEqual(f.heads(node3), [node4])
        self.assertEqual(f.heads(node4), [node4])
        self.assertEqual(f.heads(node5), [node5])

        # TODO this seems wrong.
        self.assertEqual(f.heads(stop=[node0]), [node0, node2, node4, node5])
        self.assertEqual(f.heads(stop=[node1]), [node1, node2, node4, node5])

        self.assertEqual(f.children(node0), [node1, node3, node5])
        self.assertEqual(f.children(node1), [node2])
        self.assertEqual(f.children(node2), [])
        self.assertEqual(f.children(node3), [node4])
        self.assertEqual(f.children(node4), [])
        self.assertEqual(f.children(node5), [])

class ifiledatatests(basetestcase):
    """Generic tests for the ifiledata interface.

    All file storage backends for data should conform to the tests in this
    class.

    Use ``makeifiledatatests()`` to create an instance of this type.
    """
    def testempty(self):
        f = self._makefilefn()

        self.assertEqual(f.rawsize(nullrev), 0)

        for i in range(-5, 5):
            if i == nullrev:
                continue

            with self.assertRaises(IndexError):
                f.rawsize(i)

        self.assertEqual(f.size(nullrev), 0)

        for i in range(-5, 5):
            if i == nullrev:
                continue

            with self.assertRaises(IndexError):
                f.size(i)

        with self.assertRaises(error.StorageError):
            f.checkhash(b'', nullid)

        with self.assertRaises(error.LookupError):
            f.checkhash(b'', b'\x01' * 20)

        self.assertEqual(f.revision(nullid), b'')
        self.assertEqual(f.revision(nullid, raw=True), b'')

        with self.assertRaises(error.LookupError):
            f.revision(b'\x01' * 20)

        self.assertEqual(f.read(nullid), b'')

        with self.assertRaises(error.LookupError):
            f.read(b'\x01' * 20)

        self.assertFalse(f.renamed(nullid))

        with self.assertRaises(error.LookupError):
            f.read(b'\x01' * 20)

        self.assertTrue(f.cmp(nullid, b''))
        self.assertTrue(f.cmp(nullid, b'foo'))

        with self.assertRaises(error.LookupError):
            f.cmp(b'\x01' * 20, b'irrelevant')

        self.assertEqual(f.revdiff(nullrev, nullrev), b'')

        with self.assertRaises(IndexError):
            f.revdiff(0, nullrev)

        with self.assertRaises(IndexError):
            f.revdiff(nullrev, 0)

        with self.assertRaises(IndexError):
            f.revdiff(0, 0)

        gen = f.emitrevisiondeltas([])
        with self.assertRaises(StopIteration):
            next(gen)

        requests = [
            revisiondeltarequest(nullid, nullid, nullid, nullid, nullid, False),
        ]
        gen = f.emitrevisiondeltas(requests)

        delta = next(gen)

        self.assertEqual(delta.node, nullid)
        self.assertEqual(delta.p1node, nullid)
        self.assertEqual(delta.p2node, nullid)
        self.assertEqual(delta.linknode, nullid)
        self.assertEqual(delta.basenode, nullid)
        self.assertIsNone(delta.baserevisionsize)
        self.assertEqual(delta.revision, b'')
        self.assertIsNone(delta.delta)

        with self.assertRaises(StopIteration):
            next(gen)

        requests = [
            revisiondeltarequest(nullid, nullid, nullid, nullid, nullid, False),
            revisiondeltarequest(nullid, b'\x01' * 20, b'\x02' * 20,
                                 b'\x03' * 20, nullid, False)
        ]

        gen = f.emitrevisiondeltas(requests)

        next(gen)
        delta = next(gen)

        self.assertEqual(delta.node, nullid)
        self.assertEqual(delta.p1node, b'\x01' * 20)
        self.assertEqual(delta.p2node, b'\x02' * 20)
        self.assertEqual(delta.linknode, b'\x03' * 20)
        self.assertEqual(delta.basenode, nullid)
        self.assertIsNone(delta.baserevisionsize)
        self.assertEqual(delta.revision, b'')
        self.assertIsNone(delta.delta)

        with self.assertRaises(StopIteration):
            next(gen)

        # Emitting empty list is an empty generator.
        gen = f.emitrevisions([])
        with self.assertRaises(StopIteration):
            next(gen)

        # Emitting null node yields nothing.
        gen = f.emitrevisions([nullid])
        with self.assertRaises(StopIteration):
            next(gen)

        # Requesting unknown node fails.
        with self.assertRaises(error.LookupError):
            list(f.emitrevisions([b'\x01' * 20]))

    def testsinglerevision(self):
        fulltext = b'initial'

        f = self._makefilefn()
        with self._maketransactionfn() as tr:
            node = f.add(fulltext, None, tr, 0, nullid, nullid)

        self.assertEqual(f.rawsize(0), len(fulltext))

        with self.assertRaises(IndexError):
            f.rawsize(1)

        self.assertEqual(f.size(0), len(fulltext))

        with self.assertRaises(IndexError):
            f.size(1)

        f.checkhash(fulltext, node)
        f.checkhash(fulltext, node, nullid, nullid)

        with self.assertRaises(error.StorageError):
            f.checkhash(fulltext + b'extra', node)

        with self.assertRaises(error.StorageError):
            f.checkhash(fulltext, node, b'\x01' * 20, nullid)

        with self.assertRaises(error.StorageError):
            f.checkhash(fulltext, node, nullid, b'\x01' * 20)

        self.assertEqual(f.revision(node), fulltext)
        self.assertEqual(f.revision(node, raw=True), fulltext)

        self.assertEqual(f.read(node), fulltext)

        self.assertFalse(f.renamed(node))

        self.assertFalse(f.cmp(node, fulltext))
        self.assertTrue(f.cmp(node, fulltext + b'extra'))

        self.assertEqual(f.revdiff(0, 0), b'')
        self.assertEqual(f.revdiff(nullrev, 0),
                         b'\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x07%s' %
                         fulltext)

        self.assertEqual(f.revdiff(0, nullrev),
                         b'\x00\x00\x00\x00\x00\x00\x00\x07\x00\x00\x00\x00')

        requests = [
            revisiondeltarequest(node, nullid, nullid, nullid, nullid, False),
        ]
        gen = f.emitrevisiondeltas(requests)

        delta = next(gen)

        self.assertEqual(delta.node, node)
        self.assertEqual(delta.p1node, nullid)
        self.assertEqual(delta.p2node, nullid)
        self.assertEqual(delta.linknode, nullid)
        self.assertEqual(delta.basenode, nullid)
        self.assertIsNone(delta.baserevisionsize)
        self.assertEqual(delta.revision, fulltext)
        self.assertIsNone(delta.delta)

        with self.assertRaises(StopIteration):
            next(gen)

        # Emitting a single revision works.
        gen = f.emitrevisions([node])
        rev = next(gen)

        self.assertEqual(rev.node, node)
        self.assertEqual(rev.p1node, nullid)
        self.assertEqual(rev.p2node, nullid)
        self.assertIsNone(rev.linknode)
        self.assertEqual(rev.basenode, nullid)
        self.assertIsNone(rev.baserevisionsize)
        self.assertIsNone(rev.revision)
        self.assertIsNone(rev.delta)

        with self.assertRaises(StopIteration):
            next(gen)

        # Requesting revision data works.
        gen = f.emitrevisions([node], revisiondata=True)
        rev = next(gen)

        self.assertEqual(rev.node, node)
        self.assertEqual(rev.p1node, nullid)
        self.assertEqual(rev.p2node, nullid)
        self.assertIsNone(rev.linknode)
        self.assertEqual(rev.basenode, nullid)
        self.assertIsNone(rev.baserevisionsize)
        self.assertEqual(rev.revision, fulltext)
        self.assertIsNone(rev.delta)

        with self.assertRaises(StopIteration):
            next(gen)

        # Emitting an unknown node after a known revision results in error.
        with self.assertRaises(error.LookupError):
            list(f.emitrevisions([node, b'\x01' * 20]))

    def testmultiplerevisions(self):
        fulltext0 = b'x' * 1024
        fulltext1 = fulltext0 + b'y'
        fulltext2 = b'y' + fulltext0 + b'z'

        f = self._makefilefn()
        with self._maketransactionfn() as tr:
            node0 = f.add(fulltext0, None, tr, 0, nullid, nullid)
            node1 = f.add(fulltext1, None, tr, 1, node0, nullid)
            node2 = f.add(fulltext2, None, tr, 3, node1, nullid)

        self.assertEqual(f.rawsize(0), len(fulltext0))
        self.assertEqual(f.rawsize(1), len(fulltext1))
        self.assertEqual(f.rawsize(2), len(fulltext2))

        with self.assertRaises(IndexError):
            f.rawsize(3)

        self.assertEqual(f.size(0), len(fulltext0))
        self.assertEqual(f.size(1), len(fulltext1))
        self.assertEqual(f.size(2), len(fulltext2))

        with self.assertRaises(IndexError):
            f.size(3)

        f.checkhash(fulltext0, node0)
        f.checkhash(fulltext1, node1)
        f.checkhash(fulltext1, node1, node0, nullid)
        f.checkhash(fulltext2, node2, node1, nullid)

        with self.assertRaises(error.StorageError):
            f.checkhash(fulltext1, b'\x01' * 20)

        with self.assertRaises(error.StorageError):
            f.checkhash(fulltext1 + b'extra', node1, node0, nullid)

        with self.assertRaises(error.StorageError):
            f.checkhash(fulltext1, node1, node0, node0)

        self.assertEqual(f.revision(node0), fulltext0)
        self.assertEqual(f.revision(node0, raw=True), fulltext0)
        self.assertEqual(f.revision(node1), fulltext1)
        self.assertEqual(f.revision(node1, raw=True), fulltext1)
        self.assertEqual(f.revision(node2), fulltext2)
        self.assertEqual(f.revision(node2, raw=True), fulltext2)

        with self.assertRaises(error.LookupError):
            f.revision(b'\x01' * 20)

        self.assertEqual(f.read(node0), fulltext0)
        self.assertEqual(f.read(node1), fulltext1)
        self.assertEqual(f.read(node2), fulltext2)

        with self.assertRaises(error.LookupError):
            f.read(b'\x01' * 20)

        self.assertFalse(f.renamed(node0))
        self.assertFalse(f.renamed(node1))
        self.assertFalse(f.renamed(node2))

        with self.assertRaises(error.LookupError):
            f.renamed(b'\x01' * 20)

        self.assertFalse(f.cmp(node0, fulltext0))
        self.assertFalse(f.cmp(node1, fulltext1))
        self.assertFalse(f.cmp(node2, fulltext2))

        self.assertTrue(f.cmp(node1, fulltext0))
        self.assertTrue(f.cmp(node2, fulltext1))

        with self.assertRaises(error.LookupError):
            f.cmp(b'\x01' * 20, b'irrelevant')

        self.assertEqual(f.revdiff(0, 1),
                         b'\x00\x00\x00\x00\x00\x00\x04\x00\x00\x00\x04\x01' +
                         fulltext1)

        self.assertEqual(f.revdiff(0, 2),
                         b'\x00\x00\x00\x00\x00\x00\x04\x00\x00\x00\x04\x02' +
                         fulltext2)

        requests = [
            revisiondeltarequest(node0, nullid, nullid, b'\x01' * 20, nullid,
                                 False),
            revisiondeltarequest(node1, node0, nullid, b'\x02' * 20, node0,
                                 False),
            revisiondeltarequest(node2, node1, nullid, b'\x03' * 20, node1,
                                 False),
        ]
        gen = f.emitrevisiondeltas(requests)

        delta = next(gen)

        self.assertEqual(delta.node, node0)
        self.assertEqual(delta.p1node, nullid)
        self.assertEqual(delta.p2node, nullid)
        self.assertEqual(delta.linknode, b'\x01' * 20)
        self.assertEqual(delta.basenode, nullid)
        self.assertIsNone(delta.baserevisionsize)
        self.assertEqual(delta.revision, fulltext0)
        self.assertIsNone(delta.delta)

        delta = next(gen)

        self.assertEqual(delta.node, node1)
        self.assertEqual(delta.p1node, node0)
        self.assertEqual(delta.p2node, nullid)
        self.assertEqual(delta.linknode, b'\x02' * 20)
        self.assertEqual(delta.basenode, node0)
        self.assertIsNone(delta.baserevisionsize)
        self.assertIsNone(delta.revision)
        self.assertEqual(delta.delta,
                         b'\x00\x00\x00\x00\x00\x00\x04\x00\x00\x00\x04\x01' +
                         fulltext1)

        delta = next(gen)

        self.assertEqual(delta.node, node2)
        self.assertEqual(delta.p1node, node1)
        self.assertEqual(delta.p2node, nullid)
        self.assertEqual(delta.linknode, b'\x03' * 20)
        self.assertEqual(delta.basenode, node1)
        self.assertIsNone(delta.baserevisionsize)
        self.assertIsNone(delta.revision)
        self.assertEqual(delta.delta,
                         b'\x00\x00\x00\x00\x00\x00\x04\x01\x00\x00\x04\x02' +
                         fulltext2)

        with self.assertRaises(StopIteration):
            next(gen)

        # Nodes should be emitted in order.
        gen = f.emitrevisions([node0, node1, node2], revisiondata=True)

        rev = next(gen)

        self.assertEqual(rev.node, node0)
        self.assertEqual(rev.p1node, nullid)
        self.assertEqual(rev.p2node, nullid)
        self.assertIsNone(rev.linknode)
        self.assertEqual(rev.basenode, nullid)
        self.assertIsNone(rev.baserevisionsize)
        self.assertEqual(rev.revision, fulltext0)
        self.assertIsNone(rev.delta)

        rev = next(gen)

        self.assertEqual(rev.node, node1)
        self.assertEqual(rev.p1node, node0)
        self.assertEqual(rev.p2node, nullid)
        self.assertIsNone(rev.linknode)
        self.assertEqual(rev.basenode, node0)
        self.assertIsNone(rev.baserevisionsize)
        self.assertIsNone(rev.revision)
        self.assertEqual(rev.delta,
                         b'\x00\x00\x00\x00\x00\x00\x04\x00\x00\x00\x04\x01' +
                         fulltext1)

        rev = next(gen)

        self.assertEqual(rev.node, node2)
        self.assertEqual(rev.p1node, node1)
        self.assertEqual(rev.p2node, nullid)
        self.assertIsNone(rev.linknode)
        self.assertEqual(rev.basenode, node1)
        self.assertIsNone(rev.baserevisionsize)
        self.assertIsNone(rev.revision)
        self.assertEqual(rev.delta,
                         b'\x00\x00\x00\x00\x00\x00\x04\x01\x00\x00\x04\x02' +
                         fulltext2)

        with self.assertRaises(StopIteration):
            next(gen)

        # Request not in DAG order is reordered to be in DAG order.
        gen = f.emitrevisions([node2, node1, node0], revisiondata=True)

        rev = next(gen)

        self.assertEqual(rev.node, node0)
        self.assertEqual(rev.p1node, nullid)
        self.assertEqual(rev.p2node, nullid)
        self.assertIsNone(rev.linknode)
        self.assertEqual(rev.basenode, nullid)
        self.assertIsNone(rev.baserevisionsize)
        self.assertEqual(rev.revision, fulltext0)
        self.assertIsNone(rev.delta)

        rev = next(gen)

        self.assertEqual(rev.node, node1)
        self.assertEqual(rev.p1node, node0)
        self.assertEqual(rev.p2node, nullid)
        self.assertIsNone(rev.linknode)
        self.assertEqual(rev.basenode, node0)
        self.assertIsNone(rev.baserevisionsize)
        self.assertIsNone(rev.revision)
        self.assertEqual(rev.delta,
                         b'\x00\x00\x00\x00\x00\x00\x04\x00\x00\x00\x04\x01' +
                         fulltext1)

        rev = next(gen)

        self.assertEqual(rev.node, node2)
        self.assertEqual(rev.p1node, node1)
        self.assertEqual(rev.p2node, nullid)
        self.assertIsNone(rev.linknode)
        self.assertEqual(rev.basenode, node1)
        self.assertIsNone(rev.baserevisionsize)
        self.assertIsNone(rev.revision)
        self.assertEqual(rev.delta,
                         b'\x00\x00\x00\x00\x00\x00\x04\x01\x00\x00\x04\x02' +
                         fulltext2)

        with self.assertRaises(StopIteration):
            next(gen)

        # Unrecognized nodesorder value raises ProgrammingError.
        with self.assertRaises(error.ProgrammingError):
            list(f.emitrevisions([], nodesorder='bad'))

        # nodesorder=storage is recognized. But we can't test it thoroughly
        # because behavior is storage-dependent.
        res = list(f.emitrevisions([node2, node1, node0],
                                         nodesorder='storage'))
        self.assertEqual(len(res), 3)
        self.assertEqual({o.node for o in res}, {node0, node1, node2})

        # nodesorder=nodes forces the order.
        gen = f.emitrevisions([node2, node0], nodesorder='nodes',
                              revisiondata=True)

        rev = next(gen)
        self.assertEqual(rev.node, node2)
        self.assertEqual(rev.p1node, node1)
        self.assertEqual(rev.p2node, nullid)
        self.assertEqual(rev.basenode, nullid)
        self.assertIsNone(rev.baserevisionsize)
        self.assertEqual(rev.revision, fulltext2)
        self.assertIsNone(rev.delta)

        rev = next(gen)
        self.assertEqual(rev.node, node0)
        self.assertEqual(rev.p1node, nullid)
        self.assertEqual(rev.p2node, nullid)
        # Delta behavior is storage dependent, so we can't easily test it.

        with self.assertRaises(StopIteration):
            next(gen)

        # assumehaveparentrevisions=False (the default) won't send a delta for
        # the first revision.
        gen = f.emitrevisions({node2, node1}, revisiondata=True)

        rev = next(gen)
        self.assertEqual(rev.node, node1)
        self.assertEqual(rev.p1node, node0)
        self.assertEqual(rev.p2node, nullid)
        self.assertEqual(rev.basenode, nullid)
        self.assertIsNone(rev.baserevisionsize)
        self.assertEqual(rev.revision, fulltext1)
        self.assertIsNone(rev.delta)

        rev = next(gen)
        self.assertEqual(rev.node, node2)
        self.assertEqual(rev.p1node, node1)
        self.assertEqual(rev.p2node, nullid)
        self.assertEqual(rev.basenode, node1)
        self.assertIsNone(rev.baserevisionsize)
        self.assertIsNone(rev.revision)
        self.assertEqual(rev.delta,
                         b'\x00\x00\x00\x00\x00\x00\x04\x01\x00\x00\x04\x02' +
                         fulltext2)

        with self.assertRaises(StopIteration):
            next(gen)

        # assumehaveparentrevisions=True allows delta against initial revision.
        gen = f.emitrevisions([node2, node1],
                              revisiondata=True, assumehaveparentrevisions=True)

        rev = next(gen)
        self.assertEqual(rev.node, node1)
        self.assertEqual(rev.p1node, node0)
        self.assertEqual(rev.p2node, nullid)
        self.assertEqual(rev.basenode, node0)
        self.assertIsNone(rev.baserevisionsize)
        self.assertIsNone(rev.revision)
        self.assertEqual(rev.delta,
                         b'\x00\x00\x00\x00\x00\x00\x04\x00\x00\x00\x04\x01' +
                         fulltext1)

        # forceprevious=True forces a delta against the previous revision.
        # Special case for initial revision.
        gen = f.emitrevisions([node0], revisiondata=True, deltaprevious=True)

        rev = next(gen)
        self.assertEqual(rev.node, node0)
        self.assertEqual(rev.p1node, nullid)
        self.assertEqual(rev.p2node, nullid)
        self.assertEqual(rev.basenode, nullid)
        self.assertIsNone(rev.baserevisionsize)
        self.assertIsNone(rev.revision)
        self.assertEqual(rev.delta,
                         b'\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x04\x00' +
                         fulltext0)

        with self.assertRaises(StopIteration):
            next(gen)

        gen = f.emitrevisions([node0, node2], revisiondata=True,
                              deltaprevious=True)

        rev = next(gen)
        self.assertEqual(rev.node, node0)
        self.assertEqual(rev.p1node, nullid)
        self.assertEqual(rev.p2node, nullid)
        self.assertEqual(rev.basenode, nullid)
        self.assertIsNone(rev.baserevisionsize)
        self.assertIsNone(rev.revision)
        self.assertEqual(rev.delta,
                         b'\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x04\x00' +
                         fulltext0)

        rev = next(gen)
        self.assertEqual(rev.node, node2)
        self.assertEqual(rev.p1node, node1)
        self.assertEqual(rev.p2node, nullid)
        self.assertEqual(rev.basenode, node0)

        with self.assertRaises(StopIteration):
            next(gen)

    def testrenamed(self):
        fulltext0 = b'foo'
        fulltext1 = b'bar'
        fulltext2 = b'baz'

        meta1 = {
            b'copy': b'source0',
            b'copyrev': b'a' * 40,
        }

        meta2 = {
            b'copy': b'source1',
            b'copyrev': b'b' * 40,
        }

        stored1 = b''.join([
            b'\x01\ncopy: source0\n',
            b'copyrev: aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa\n\x01\n',
            fulltext1,
        ])

        stored2 = b''.join([
            b'\x01\ncopy: source1\n',
            b'copyrev: bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb\n\x01\n',
            fulltext2,
        ])

        f = self._makefilefn()
        with self._maketransactionfn() as tr:
            node0 = f.add(fulltext0, None, tr, 0, nullid, nullid)
            node1 = f.add(fulltext1, meta1, tr, 1, node0, nullid)
            node2 = f.add(fulltext2, meta2, tr, 2, nullid, nullid)

        self.assertEqual(f.rawsize(1), len(stored1))
        self.assertEqual(f.rawsize(2), len(stored2))

        # Metadata header isn't recognized when parent isn't nullid.
        self.assertEqual(f.size(1), len(stored1))
        self.assertEqual(f.size(2), len(fulltext2))

        self.assertEqual(f.revision(node1), stored1)
        self.assertEqual(f.revision(node1, raw=True), stored1)
        self.assertEqual(f.revision(node2), stored2)
        self.assertEqual(f.revision(node2, raw=True), stored2)

        self.assertEqual(f.read(node1), fulltext1)
        self.assertEqual(f.read(node2), fulltext2)

        # Returns False when first parent is set.
        self.assertFalse(f.renamed(node1))
        self.assertEqual(f.renamed(node2), (b'source1', b'\xbb' * 20))

        self.assertTrue(f.cmp(node1, fulltext1))
        self.assertTrue(f.cmp(node1, stored1))
        self.assertFalse(f.cmp(node2, fulltext2))
        self.assertTrue(f.cmp(node2, stored2))

    def testmetadataprefix(self):
        # Content with metadata prefix has extra prefix inserted in storage.
        fulltext0 = b'\x01\nfoo'
        stored0 = b'\x01\n\x01\n\x01\nfoo'

        fulltext1 = b'\x01\nbar'
        meta1 = {
            b'copy': b'source0',
            b'copyrev': b'b' * 40,
        }
        stored1 = b''.join([
            b'\x01\ncopy: source0\n',
            b'copyrev: %s\n' % (b'b' * 40),
            b'\x01\n\x01\nbar',
        ])

        f = self._makefilefn()
        with self._maketransactionfn() as tr:
            node0 = f.add(fulltext0, {}, tr, 0, nullid, nullid)
            node1 = f.add(fulltext1, meta1, tr, 1, nullid, nullid)

        self.assertEqual(f.rawsize(0), len(stored0))
        self.assertEqual(f.rawsize(1), len(stored1))

        # TODO this is buggy.
        self.assertEqual(f.size(0), len(fulltext0) + 4)

        self.assertEqual(f.size(1), len(fulltext1))

        self.assertEqual(f.revision(node0), stored0)
        self.assertEqual(f.revision(node0, raw=True), stored0)

        self.assertEqual(f.revision(node1), stored1)
        self.assertEqual(f.revision(node1, raw=True), stored1)

        self.assertEqual(f.read(node0), fulltext0)
        self.assertEqual(f.read(node1), fulltext1)

        self.assertFalse(f.cmp(node0, fulltext0))
        self.assertTrue(f.cmp(node0, stored0))

        self.assertFalse(f.cmp(node1, fulltext1))
        self.assertTrue(f.cmp(node1, stored0))

    def testcensored(self):
        f = self._makefilefn()

        stored1 = revlog.packmeta({
            b'censored': b'tombstone',
        }, b'')

        # TODO tests are incomplete because we need the node to be
        # different due to presence of censor metadata. But we can't
        # do this with addrevision().
        with self._maketransactionfn() as tr:
            node0 = f.add(b'foo', None, tr, 0, nullid, nullid)
            f.addrevision(stored1, tr, 1, node0, nullid,
                          flags=revlog.REVIDX_ISCENSORED)

        self.assertEqual(f.flags(1), revlog.REVIDX_ISCENSORED)
        self.assertTrue(f.iscensored(1))

        self.assertEqual(f.revision(1), stored1)
        self.assertEqual(f.revision(1, raw=True), stored1)

        self.assertEqual(f.read(1), b'')

class ifilemutationtests(basetestcase):
    """Generic tests for the ifilemutation interface.

    All file storage backends that support writing should conform to this
    interface.

    Use ``makeifilemutationtests()`` to create an instance of this type.
    """
    def testaddnoop(self):
        f = self._makefilefn()
        with self._maketransactionfn() as tr:
            node0 = f.add(b'foo', None, tr, 0, nullid, nullid)
            node1 = f.add(b'foo', None, tr, 0, nullid, nullid)
            # Varying by linkrev shouldn't impact hash.
            node2 = f.add(b'foo', None, tr, 1, nullid, nullid)

        self.assertEqual(node1, node0)
        self.assertEqual(node2, node0)
        self.assertEqual(len(f), 1)

    def testaddrevisionbadnode(self):
        f = self._makefilefn()
        with self._maketransactionfn() as tr:
            # Adding a revision with bad node value fails.
            with self.assertRaises(error.StorageError):
                f.addrevision(b'foo', tr, 0, nullid, nullid, node=b'\x01' * 20)

    def testaddrevisionunknownflag(self):
        f = self._makefilefn()
        with self._maketransactionfn() as tr:
            for i in range(15, 0, -1):
                if (1 << i) & ~revlog.REVIDX_KNOWN_FLAGS:
                    flags = 1 << i
                    break

            with self.assertRaises(error.StorageError):
                f.addrevision(b'foo', tr, 0, nullid, nullid, flags=flags)

    def testaddgroupsimple(self):
        f = self._makefilefn()

        callbackargs = []
        def cb(*args, **kwargs):
            callbackargs.append((args, kwargs))

        def linkmapper(node):
            return 0

        with self._maketransactionfn() as tr:
            nodes = f.addgroup([], None, tr, addrevisioncb=cb)

        self.assertEqual(nodes, [])
        self.assertEqual(callbackargs, [])
        self.assertEqual(len(f), 0)

        fulltext0 = b'foo'
        delta0 = mdiff.trivialdiffheader(len(fulltext0)) + fulltext0

        deltas = [
            (b'\x01' * 20, nullid, nullid, nullid, nullid, delta0, 0),
        ]

        with self._maketransactionfn() as tr:
            with self.assertRaises(error.StorageError):
                f.addgroup(deltas, linkmapper, tr, addrevisioncb=cb)

            node0 = f.add(fulltext0, None, tr, 0, nullid, nullid)

        f = self._makefilefn()

        deltas = [
            (node0, nullid, nullid, nullid, nullid, delta0, 0),
        ]

        with self._maketransactionfn() as tr:
            nodes = f.addgroup(deltas, linkmapper, tr, addrevisioncb=cb)

        self.assertEqual(nodes, [
            b'\x49\xd8\xcb\xb1\x5c\xe2\x57\x92\x04\x47'
            b'\x00\x6b\x46\x97\x8b\x7a\xf9\x80\xa9\x79'])

        self.assertEqual(len(callbackargs), 1)
        self.assertEqual(callbackargs[0][0][1], nodes[0])

        self.assertEqual(list(f.revs()), [0])
        self.assertEqual(f.rev(nodes[0]), 0)
        self.assertEqual(f.node(0), nodes[0])

    def testaddgroupmultiple(self):
        f = self._makefilefn()

        fulltexts = [
            b'foo',
            b'bar',
            b'x' * 1024,
        ]

        nodes = []
        with self._maketransactionfn() as tr:
            for fulltext in fulltexts:
                nodes.append(f.add(fulltext, None, tr, 0, nullid, nullid))

        f = self._makefilefn()
        deltas = []
        for i, fulltext in enumerate(fulltexts):
            delta = mdiff.trivialdiffheader(len(fulltext)) + fulltext

            deltas.append((nodes[i], nullid, nullid, nullid, nullid, delta, 0))

        with self._maketransactionfn() as tr:
            self.assertEqual(f.addgroup(deltas, lambda x: 0, tr), nodes)

        self.assertEqual(len(f), len(deltas))
        self.assertEqual(list(f.revs()), [0, 1, 2])
        self.assertEqual(f.rev(nodes[0]), 0)
        self.assertEqual(f.rev(nodes[1]), 1)
        self.assertEqual(f.rev(nodes[2]), 2)
        self.assertEqual(f.node(0), nodes[0])
        self.assertEqual(f.node(1), nodes[1])
        self.assertEqual(f.node(2), nodes[2])

def makeifileindextests(makefilefn, maketransactionfn):
    """Create a unittest.TestCase class suitable for testing file storage.

    ``makefilefn`` is a callable which receives the test case as an
    argument and returns an object implementing the ``ifilestorage`` interface.

    ``maketransactionfn`` is a callable which receives the test case as an
    argument and returns a transaction object.

    Returns a type that is a ``unittest.TestCase`` that can be used for
    testing the object implementing the file storage interface. Simply
    assign the returned value to a module-level attribute and a test loader
    should find and run it automatically.
    """
    d = {
        r'_makefilefn': makefilefn,
        r'_maketransactionfn': maketransactionfn,
    }
    return type(r'ifileindextests', (ifileindextests,), d)

def makeifiledatatests(makefilefn, maketransactionfn):
    d = {
        r'_makefilefn': makefilefn,
        r'_maketransactionfn': maketransactionfn,
    }
    return type(r'ifiledatatests', (ifiledatatests,), d)

def makeifilemutationtests(makefilefn, maketransactionfn):
    d = {
        r'_makefilefn': makefilefn,
        r'_maketransactionfn': maketransactionfn,
    }
    return type(r'ifilemutationtests', (ifilemutationtests,), d)
