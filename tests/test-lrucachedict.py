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

if __name__ == '__main__':
    silenttestrunner.main(__name__)
