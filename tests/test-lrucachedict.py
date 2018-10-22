from __future__ import absolute_import, print_function

import unittest

import silenttestrunner

from mercurial import (
    util,
)

class testlrucachedict(unittest.TestCase):
    def testsimple(self):
        d = util.lrucachedict(4)
        self.assertEqual(d.capacity, 4)
        d.insert('a', 'va', cost=2)
        d['b'] = 'vb'
        d['c'] = 'vc'
        d.insert('d', 'vd', cost=42)

        self.assertEqual(d['a'], 'va')
        self.assertEqual(d['b'], 'vb')
        self.assertEqual(d['c'], 'vc')
        self.assertEqual(d['d'], 'vd')

        self.assertEqual(d.totalcost, 44)

        # 'a' should be dropped because it was least recently used.
        d['e'] = 've'
        self.assertNotIn('a', d)
        self.assertIsNone(d.get('a'))
        self.assertEqual(d.totalcost, 42)

        self.assertEqual(d['b'], 'vb')
        self.assertEqual(d['c'], 'vc')
        self.assertEqual(d['d'], 'vd')
        self.assertEqual(d['e'], 've')

        # Replacing item with different cost adjusts totalcost.
        d.insert('e', 've', cost=4)
        self.assertEqual(d.totalcost, 46)

        # Touch entries in some order (both get and set).
        d['e']
        d['c'] = 'vc2'
        d['d']
        d['b'] = 'vb2'

        # 'e' should be dropped now
        d['f'] = 'vf'
        self.assertNotIn('e', d)
        self.assertEqual(d['b'], 'vb2')
        self.assertEqual(d['c'], 'vc2')
        self.assertEqual(d['d'], 'vd')
        self.assertEqual(d['f'], 'vf')

        d.clear()
        for key in ('a', 'b', 'c', 'd', 'e', 'f'):
            self.assertNotIn(key, d)

    def testunfull(self):
        d = util.lrucachedict(4)
        d['a'] = 1
        d['b'] = 2
        d['a']
        d['b']

        for key in ('a', 'b'):
            self.assertIn(key, d)

    def testget(self):
        d = util.lrucachedict(4)
        d['a'] = 'va'
        d['b'] = 'vb'
        d['c'] = 'vc'

        self.assertIsNone(d.get('missing'))
        self.assertEqual(list(d), ['c', 'b', 'a'])

        self.assertEqual(d.get('a'), 'va')
        self.assertEqual(list(d), ['a', 'c', 'b'])

    def testcopypartial(self):
        d = util.lrucachedict(4)
        d.insert('a', 'va', cost=4)
        d.insert('b', 'vb', cost=2)

        dc = d.copy()

        self.assertEqual(len(dc), 2)
        self.assertEqual(dc.totalcost, 6)
        for key in ('a', 'b'):
            self.assertIn(key, dc)
            self.assertEqual(dc[key], 'v%s' % key)

        self.assertEqual(len(d), 2)
        for key in ('a', 'b'):
            self.assertIn(key, d)
            self.assertEqual(d[key], 'v%s' % key)

        d['c'] = 'vc'
        del d['b']
        self.assertEqual(d.totalcost, 4)
        dc = d.copy()
        self.assertEqual(len(dc), 2)
        self.assertEqual(dc.totalcost, 4)
        for key in ('a', 'c'):
            self.assertIn(key, dc)
            self.assertEqual(dc[key], 'v%s' % key)

    def testcopyempty(self):
        d = util.lrucachedict(4)
        dc = d.copy()
        self.assertEqual(len(dc), 0)

    def testcopyfull(self):
        d = util.lrucachedict(4)
        d.insert('a', 'va', cost=42)
        d['b'] = 'vb'
        d['c'] = 'vc'
        d['d'] = 'vd'

        dc = d.copy()

        for key in ('a', 'b', 'c', 'd'):
            self.assertIn(key, dc)
            self.assertEqual(dc[key], 'v%s' % key)

        self.assertEqual(d.totalcost, 42)
        self.assertEqual(dc.totalcost, 42)

        # 'a' should be dropped because it was least recently used.
        dc['e'] = 've'
        self.assertNotIn('a', dc)
        for key in ('b', 'c', 'd', 'e'):
            self.assertIn(key, dc)
            self.assertEqual(dc[key], 'v%s' % key)

        self.assertEqual(d.totalcost, 42)
        self.assertEqual(dc.totalcost, 0)

        # Contents and order of original dict should remain unchanged.
        dc['b'] = 'vb_new'

        self.assertEqual(list(iter(d)), ['d', 'c', 'b', 'a'])
        for key in ('a', 'b', 'c', 'd'):
            self.assertEqual(d[key], 'v%s' % key)

        d = util.lrucachedict(4, maxcost=42)
        d.insert('a', 'va', cost=5)
        d.insert('b', 'vb', cost=4)
        d.insert('c', 'vc', cost=3)
        dc = d.copy()
        self.assertEqual(dc.maxcost, 42)
        self.assertEqual(len(dc), 3)

        # Max cost can be lowered as part of copy.
        dc = d.copy(maxcost=10)
        self.assertEqual(dc.maxcost, 10)
        self.assertEqual(len(dc), 2)
        self.assertEqual(dc.totalcost, 7)
        self.assertIn('b', dc)
        self.assertIn('c', dc)

    def testcopydecreasecapacity(self):
        d = util.lrucachedict(5)
        d.insert('a', 'va', cost=4)
        d.insert('b', 'vb', cost=2)
        d['c'] = 'vc'
        d['d'] = 'vd'

        dc = d.copy(2)
        self.assertEqual(dc.totalcost, 0)
        for key in ('a', 'b'):
            self.assertNotIn(key, dc)
        for key in ('c', 'd'):
            self.assertIn(key, dc)
            self.assertEqual(dc[key], 'v%s' % key)

        dc.insert('e', 've', cost=7)
        self.assertEqual(dc.totalcost, 7)
        self.assertNotIn('c', dc)
        for key in ('d', 'e'):
            self.assertIn(key, dc)
            self.assertEqual(dc[key], 'v%s' % key)

        # Original should remain unchanged.
        self.assertEqual(d.totalcost, 6)
        for key in ('a', 'b', 'c', 'd'):
            self.assertIn(key, d)
            self.assertEqual(d[key], 'v%s' % key)

    def testcopyincreasecapacity(self):
        d = util.lrucachedict(5)
        d['a'] = 'va'
        d['b'] = 'vb'
        d['c'] = 'vc'
        d['d'] = 'vd'

        dc = d.copy(6)
        for key in ('a', 'b', 'c', 'd'):
            self.assertIn(key, dc)
            self.assertEqual(dc[key], 'v%s' % key)

        dc['e'] = 've'
        dc['f'] = 'vf'
        for key in ('a', 'b', 'c', 'd', 'e', 'f'):
            self.assertIn(key, dc)
            self.assertEqual(dc[key], 'v%s' % key)

        dc['g'] = 'vg'
        self.assertNotIn('a', dc)
        for key in ('b', 'c', 'd', 'e', 'f', 'g'):
            self.assertIn(key, dc)
            self.assertEqual(dc[key], 'v%s' % key)

        # Original should remain unchanged.
        for key in ('a', 'b', 'c', 'd'):
            self.assertIn(key, d)
            self.assertEqual(d[key], 'v%s' % key)

    def testpopoldest(self):
        d = util.lrucachedict(4)
        d.insert('a', 'va', cost=10)
        d.insert('b', 'vb', cost=5)

        self.assertEqual(len(d), 2)
        self.assertEqual(d.popoldest(), ('a', 'va'))
        self.assertEqual(len(d), 1)
        self.assertEqual(d.totalcost, 5)
        self.assertEqual(d.popoldest(), ('b', 'vb'))
        self.assertEqual(len(d), 0)
        self.assertEqual(d.totalcost, 0)
        self.assertIsNone(d.popoldest())

        d['a'] = 'va'
        d['b'] = 'vb'
        d['c'] = 'vc'
        d['d'] = 'vd'

        self.assertEqual(d.popoldest(), ('a', 'va'))
        self.assertEqual(len(d), 3)
        for key in ('b', 'c', 'd'):
            self.assertEqual(d[key], 'v%s' % key)

        d['a'] = 'va'
        self.assertEqual(d.popoldest(), ('b', 'vb'))

    def testmaxcost(self):
        # Item cost is zero by default.
        d = util.lrucachedict(6, maxcost=10)
        d['a'] = 'va'
        d['b'] = 'vb'
        d['c'] = 'vc'
        d['d'] = 'vd'
        self.assertEqual(len(d), 4)
        self.assertEqual(d.totalcost, 0)

        d.clear()

        # Insertion to exact cost threshold works without eviction.
        d.insert('a', 'va', cost=6)
        d.insert('b', 'vb', cost=4)

        self.assertEqual(len(d), 2)
        self.assertEqual(d['a'], 'va')
        self.assertEqual(d['b'], 'vb')

        # Inserting a new element with 0 cost works.
        d['c'] = 'vc'
        self.assertEqual(len(d), 3)

        # Inserting a new element with cost putting us above high
        # water mark evicts oldest single item.
        d.insert('d', 'vd', cost=1)
        self.assertEqual(len(d), 3)
        self.assertEqual(d.totalcost, 5)
        self.assertNotIn('a', d)
        for key in ('b', 'c', 'd'):
            self.assertEqual(d[key], 'v%s' % key)

        # Inserting a new element with enough room for just itself
        # evicts all items before.
        d.insert('e', 've', cost=10)
        self.assertEqual(len(d), 1)
        self.assertEqual(d.totalcost, 10)
        self.assertIn('e', d)

        # Inserting a new element with cost greater than threshold
        # still retains that item.
        d.insert('f', 'vf', cost=11)
        self.assertEqual(len(d), 1)
        self.assertEqual(d.totalcost, 11)
        self.assertIn('f', d)

        # Inserting a new element will evict the last item since it is
        # too large.
        d['g'] = 'vg'
        self.assertEqual(len(d), 1)
        self.assertEqual(d.totalcost, 0)
        self.assertIn('g', d)

        d.clear()

        d.insert('a', 'va', cost=7)
        d.insert('b', 'vb', cost=3)
        self.assertEqual(len(d), 2)

        # Replacing a value with smaller cost won't result in eviction.
        d.insert('b', 'vb2', cost=2)
        self.assertEqual(len(d), 2)

        # Replacing a value with a higher cost will evict when threshold
        # exceeded.
        d.insert('b', 'vb3', cost=4)
        self.assertEqual(len(d), 1)
        self.assertNotIn('a', d)

    def testmaxcostcomplex(self):
        d = util.lrucachedict(100, maxcost=100)
        d.insert('a', 'va', cost=9)
        d.insert('b', 'vb', cost=21)
        d.insert('c', 'vc', cost=7)
        d.insert('d', 'vc', cost=50)
        self.assertEqual(d.totalcost, 87)

        # Inserting new element should free multiple elements so we hit
        # low water mark.
        d.insert('e', 'vd', cost=25)
        self.assertEqual(len(d), 2)
        self.assertNotIn('a', d)
        self.assertNotIn('b', d)
        self.assertNotIn('c', d)
        self.assertIn('d', d)
        self.assertIn('e', d)

if __name__ == '__main__':
    silenttestrunner.main(__name__)
