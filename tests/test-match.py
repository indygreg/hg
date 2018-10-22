from __future__ import absolute_import

import unittest

import silenttestrunner

from mercurial import (
    match as matchmod,
    util,
)

class BaseMatcherTests(unittest.TestCase):

    def testVisitdir(self):
        m = matchmod.basematcher(b'', b'')
        self.assertTrue(m.visitdir(b'.'))
        self.assertTrue(m.visitdir(b'dir'))

    def testVisitchildrenset(self):
        m = matchmod.basematcher(b'', b'')
        self.assertEqual(m.visitchildrenset(b'.'), b'this')
        self.assertEqual(m.visitchildrenset(b'dir'), b'this')

class AlwaysMatcherTests(unittest.TestCase):

    def testVisitdir(self):
        m = matchmod.alwaysmatcher(b'', b'')
        self.assertEqual(m.visitdir(b'.'), b'all')
        self.assertEqual(m.visitdir(b'dir'), b'all')

    def testVisitchildrenset(self):
        m = matchmod.alwaysmatcher(b'', b'')
        self.assertEqual(m.visitchildrenset(b'.'), b'all')
        self.assertEqual(m.visitchildrenset(b'dir'), b'all')

class NeverMatcherTests(unittest.TestCase):

    def testVisitdir(self):
        m = matchmod.nevermatcher(b'', b'')
        self.assertFalse(m.visitdir(b'.'))
        self.assertFalse(m.visitdir(b'dir'))

    def testVisitchildrenset(self):
        m = matchmod.nevermatcher(b'', b'')
        self.assertEqual(m.visitchildrenset(b'.'), set())
        self.assertEqual(m.visitchildrenset(b'dir'), set())

class PredicateMatcherTests(unittest.TestCase):
    # predicatematcher does not currently define either of these methods, so
    # this is equivalent to BaseMatcherTests.

    def testVisitdir(self):
        m = matchmod.predicatematcher(b'', b'', lambda *a: False)
        self.assertTrue(m.visitdir(b'.'))
        self.assertTrue(m.visitdir(b'dir'))

    def testVisitchildrenset(self):
        m = matchmod.predicatematcher(b'', b'', lambda *a: False)
        self.assertEqual(m.visitchildrenset(b'.'), b'this')
        self.assertEqual(m.visitchildrenset(b'dir'), b'this')

class PatternMatcherTests(unittest.TestCase):

    def testVisitdirPrefix(self):
        m = matchmod.match(b'x', b'', patterns=[b'path:dir/subdir'])
        assert isinstance(m, matchmod.patternmatcher)
        self.assertTrue(m.visitdir(b'.'))
        self.assertTrue(m.visitdir(b'dir'))
        self.assertEqual(m.visitdir(b'dir/subdir'), b'all')
        # OPT: This should probably be 'all' if its parent is?
        self.assertTrue(m.visitdir(b'dir/subdir/x'))
        self.assertFalse(m.visitdir(b'folder'))

    def testVisitchildrensetPrefix(self):
        m = matchmod.match(b'x', b'', patterns=[b'path:dir/subdir'])
        assert isinstance(m, matchmod.patternmatcher)
        self.assertEqual(m.visitchildrenset(b'.'), b'this')
        self.assertEqual(m.visitchildrenset(b'dir'), b'this')
        self.assertEqual(m.visitchildrenset(b'dir/subdir'), b'all')
        # OPT: This should probably be 'all' if its parent is?
        self.assertEqual(m.visitchildrenset(b'dir/subdir/x'), b'this')
        self.assertEqual(m.visitchildrenset(b'folder'), set())

    def testVisitdirRootfilesin(self):
        m = matchmod.match(b'x', b'', patterns=[b'rootfilesin:dir/subdir'])
        assert isinstance(m, matchmod.patternmatcher)
        self.assertTrue(m.visitdir(b'.'))
        self.assertFalse(m.visitdir(b'dir/subdir/x'))
        self.assertFalse(m.visitdir(b'folder'))
        # FIXME: These should probably be True.
        self.assertFalse(m.visitdir(b'dir'))
        self.assertFalse(m.visitdir(b'dir/subdir'))

    def testVisitchildrensetRootfilesin(self):
        m = matchmod.match(b'x', b'', patterns=[b'rootfilesin:dir/subdir'])
        assert isinstance(m, matchmod.patternmatcher)
        self.assertEqual(m.visitchildrenset(b'.'), b'this')
        self.assertEqual(m.visitchildrenset(b'dir/subdir/x'), set())
        self.assertEqual(m.visitchildrenset(b'folder'), set())
        # FIXME: These should probably be {'subdir'} and 'this', respectively,
        # or at least 'this' and 'this'.
        self.assertEqual(m.visitchildrenset(b'dir'), set())
        self.assertEqual(m.visitchildrenset(b'dir/subdir'), set())

    def testVisitdirGlob(self):
        m = matchmod.match(b'x', b'', patterns=[b'glob:dir/z*'])
        assert isinstance(m, matchmod.patternmatcher)
        self.assertTrue(m.visitdir(b'.'))
        self.assertTrue(m.visitdir(b'dir'))
        self.assertFalse(m.visitdir(b'folder'))
        # OPT: these should probably be False.
        self.assertTrue(m.visitdir(b'dir/subdir'))
        self.assertTrue(m.visitdir(b'dir/subdir/x'))

    def testVisitchildrensetGlob(self):
        m = matchmod.match(b'x', b'', patterns=[b'glob:dir/z*'])
        assert isinstance(m, matchmod.patternmatcher)
        self.assertEqual(m.visitchildrenset(b'.'), b'this')
        self.assertEqual(m.visitchildrenset(b'folder'), set())
        self.assertEqual(m.visitchildrenset(b'dir'), b'this')
        # OPT: these should probably be set().
        self.assertEqual(m.visitchildrenset(b'dir/subdir'), b'this')
        self.assertEqual(m.visitchildrenset(b'dir/subdir/x'), b'this')

class IncludeMatcherTests(unittest.TestCase):

    def testVisitdirPrefix(self):
        m = matchmod.match(b'x', b'', include=[b'path:dir/subdir'])
        assert isinstance(m, matchmod.includematcher)
        self.assertTrue(m.visitdir(b'.'))
        self.assertTrue(m.visitdir(b'dir'))
        self.assertEqual(m.visitdir(b'dir/subdir'), b'all')
        # OPT: This should probably be 'all' if its parent is?
        self.assertTrue(m.visitdir(b'dir/subdir/x'))
        self.assertFalse(m.visitdir(b'folder'))

    def testVisitchildrensetPrefix(self):
        m = matchmod.match(b'x', b'', include=[b'path:dir/subdir'])
        assert isinstance(m, matchmod.includematcher)
        self.assertEqual(m.visitchildrenset(b'.'), {b'dir'})
        self.assertEqual(m.visitchildrenset(b'dir'), {b'subdir'})
        self.assertEqual(m.visitchildrenset(b'dir/subdir'), b'all')
        # OPT: This should probably be 'all' if its parent is?
        self.assertEqual(m.visitchildrenset(b'dir/subdir/x'), b'this')
        self.assertEqual(m.visitchildrenset(b'folder'), set())

    def testVisitdirRootfilesin(self):
        m = matchmod.match(b'x', b'', include=[b'rootfilesin:dir/subdir'])
        assert isinstance(m, matchmod.includematcher)
        self.assertTrue(m.visitdir(b'.'))
        self.assertTrue(m.visitdir(b'dir'))
        self.assertTrue(m.visitdir(b'dir/subdir'))
        self.assertFalse(m.visitdir(b'dir/subdir/x'))
        self.assertFalse(m.visitdir(b'folder'))

    def testVisitchildrensetRootfilesin(self):
        m = matchmod.match(b'x', b'', include=[b'rootfilesin:dir/subdir'])
        assert isinstance(m, matchmod.includematcher)
        self.assertEqual(m.visitchildrenset(b'.'), {b'dir'})
        self.assertEqual(m.visitchildrenset(b'dir'), {b'subdir'})
        self.assertEqual(m.visitchildrenset(b'dir/subdir'), b'this')
        self.assertEqual(m.visitchildrenset(b'dir/subdir/x'), set())
        self.assertEqual(m.visitchildrenset(b'folder'), set())

    def testVisitdirGlob(self):
        m = matchmod.match(b'x', b'', include=[b'glob:dir/z*'])
        assert isinstance(m, matchmod.includematcher)
        self.assertTrue(m.visitdir(b'.'))
        self.assertTrue(m.visitdir(b'dir'))
        self.assertFalse(m.visitdir(b'folder'))
        # OPT: these should probably be False.
        self.assertTrue(m.visitdir(b'dir/subdir'))
        self.assertTrue(m.visitdir(b'dir/subdir/x'))

    def testVisitchildrensetGlob(self):
        m = matchmod.match(b'x', b'', include=[b'glob:dir/z*'])
        assert isinstance(m, matchmod.includematcher)
        self.assertEqual(m.visitchildrenset(b'.'), {b'dir'})
        self.assertEqual(m.visitchildrenset(b'folder'), set())
        self.assertEqual(m.visitchildrenset(b'dir'), b'this')
        # OPT: these should probably be set().
        self.assertEqual(m.visitchildrenset(b'dir/subdir'), b'this')
        self.assertEqual(m.visitchildrenset(b'dir/subdir/x'), b'this')

class ExactMatcherTests(unittest.TestCase):

    def testVisitdir(self):
        m = matchmod.match(b'x', b'', patterns=[b'dir/subdir/foo.txt'],
                           exact=True)
        assert isinstance(m, matchmod.exactmatcher)
        self.assertTrue(m.visitdir(b'.'))
        self.assertTrue(m.visitdir(b'dir'))
        self.assertTrue(m.visitdir(b'dir/subdir'))
        self.assertFalse(m.visitdir(b'dir/subdir/foo.txt'))
        self.assertFalse(m.visitdir(b'dir/foo'))
        self.assertFalse(m.visitdir(b'dir/subdir/x'))
        self.assertFalse(m.visitdir(b'folder'))

    def testVisitchildrenset(self):
        m = matchmod.match(b'x', b'', patterns=[b'dir/subdir/foo.txt'],
                           exact=True)
        assert isinstance(m, matchmod.exactmatcher)
        self.assertEqual(m.visitchildrenset(b'.'), {b'dir'})
        self.assertEqual(m.visitchildrenset(b'dir'), {b'subdir'})
        self.assertEqual(m.visitchildrenset(b'dir/subdir'), {b'foo.txt'})
        self.assertEqual(m.visitchildrenset(b'dir/subdir/x'), set())
        self.assertEqual(m.visitchildrenset(b'dir/subdir/foo.txt'), set())
        self.assertEqual(m.visitchildrenset(b'folder'), set())

    def testVisitchildrensetFilesAndDirs(self):
        m = matchmod.match(b'x', b'', patterns=[b'rootfile.txt',
                                                b'a/file1.txt',
                                                b'a/b/file2.txt',
                                                # no file in a/b/c
                                                b'a/b/c/d/file4.txt'],
                           exact=True)
        assert isinstance(m, matchmod.exactmatcher)
        self.assertEqual(m.visitchildrenset(b'.'), {b'a', b'rootfile.txt'})
        self.assertEqual(m.visitchildrenset(b'a'), {b'b', b'file1.txt'})
        self.assertEqual(m.visitchildrenset(b'a/b'), {b'c', b'file2.txt'})
        self.assertEqual(m.visitchildrenset(b'a/b/c'), {b'd'})
        self.assertEqual(m.visitchildrenset(b'a/b/c/d'), {b'file4.txt'})
        self.assertEqual(m.visitchildrenset(b'a/b/c/d/e'), set())
        self.assertEqual(m.visitchildrenset(b'folder'), set())

class DifferenceMatcherTests(unittest.TestCase):

    def testVisitdirM2always(self):
        m1 = matchmod.alwaysmatcher(b'', b'')
        m2 = matchmod.alwaysmatcher(b'', b'')
        dm = matchmod.differencematcher(m1, m2)
        # dm should be equivalent to a nevermatcher.
        self.assertFalse(dm.visitdir(b'.'))
        self.assertFalse(dm.visitdir(b'dir'))
        self.assertFalse(dm.visitdir(b'dir/subdir'))
        self.assertFalse(dm.visitdir(b'dir/subdir/z'))
        self.assertFalse(dm.visitdir(b'dir/foo'))
        self.assertFalse(dm.visitdir(b'dir/subdir/x'))
        self.assertFalse(dm.visitdir(b'folder'))

    def testVisitchildrensetM2always(self):
        m1 = matchmod.alwaysmatcher(b'', b'')
        m2 = matchmod.alwaysmatcher(b'', b'')
        dm = matchmod.differencematcher(m1, m2)
        # dm should be equivalent to a nevermatcher.
        self.assertEqual(dm.visitchildrenset(b'.'), set())
        self.assertEqual(dm.visitchildrenset(b'dir'), set())
        self.assertEqual(dm.visitchildrenset(b'dir/subdir'), set())
        self.assertEqual(dm.visitchildrenset(b'dir/subdir/z'), set())
        self.assertEqual(dm.visitchildrenset(b'dir/foo'), set())
        self.assertEqual(dm.visitchildrenset(b'dir/subdir/x'), set())
        self.assertEqual(dm.visitchildrenset(b'folder'), set())

    def testVisitdirM2never(self):
        m1 = matchmod.alwaysmatcher(b'', b'')
        m2 = matchmod.nevermatcher(b'', b'')
        dm = matchmod.differencematcher(m1, m2)
        # dm should be equivalent to a alwaysmatcher. OPT: if m2 is a
        # nevermatcher, we could return 'all' for these.
        #
        # We're testing Equal-to-True instead of just 'assertTrue' since
        # assertTrue does NOT verify that it's a bool, just that it's truthy.
        # While we may want to eventually make these return 'all', they should
        # not currently do so.
        self.assertEqual(dm.visitdir(b'.'), True)
        self.assertEqual(dm.visitdir(b'dir'), True)
        self.assertEqual(dm.visitdir(b'dir/subdir'), True)
        self.assertEqual(dm.visitdir(b'dir/subdir/z'), True)
        self.assertEqual(dm.visitdir(b'dir/foo'), True)
        self.assertEqual(dm.visitdir(b'dir/subdir/x'), True)
        self.assertEqual(dm.visitdir(b'folder'), True)

    def testVisitchildrensetM2never(self):
        m1 = matchmod.alwaysmatcher(b'', b'')
        m2 = matchmod.nevermatcher(b'', b'')
        dm = matchmod.differencematcher(m1, m2)
        # dm should be equivalent to a alwaysmatcher.
        self.assertEqual(dm.visitchildrenset(b'.'), b'all')
        self.assertEqual(dm.visitchildrenset(b'dir'), b'all')
        self.assertEqual(dm.visitchildrenset(b'dir/subdir'), b'all')
        self.assertEqual(dm.visitchildrenset(b'dir/subdir/z'), b'all')
        self.assertEqual(dm.visitchildrenset(b'dir/foo'), b'all')
        self.assertEqual(dm.visitchildrenset(b'dir/subdir/x'), b'all')
        self.assertEqual(dm.visitchildrenset(b'folder'), b'all')

    def testVisitdirM2SubdirPrefix(self):
        m1 = matchmod.alwaysmatcher(b'', b'')
        m2 = matchmod.match(b'', b'', patterns=[b'path:dir/subdir'])
        dm = matchmod.differencematcher(m1, m2)
        self.assertEqual(dm.visitdir(b'.'), True)
        self.assertEqual(dm.visitdir(b'dir'), True)
        self.assertFalse(dm.visitdir(b'dir/subdir'))
        # OPT: We should probably return False for these; we don't because
        # patternmatcher.visitdir() (our m2) doesn't return 'all' for subdirs of
        # an 'all' pattern, just True.
        self.assertEqual(dm.visitdir(b'dir/subdir/z'), True)
        self.assertEqual(dm.visitdir(b'dir/subdir/x'), True)
        # OPT: We could return 'all' for these.
        self.assertEqual(dm.visitdir(b'dir/foo'), True)
        self.assertEqual(dm.visitdir(b'folder'), True)

    def testVisitchildrensetM2SubdirPrefix(self):
        m1 = matchmod.alwaysmatcher(b'', b'')
        m2 = matchmod.match(b'', b'', patterns=[b'path:dir/subdir'])
        dm = matchmod.differencematcher(m1, m2)
        self.assertEqual(dm.visitchildrenset(b'.'), b'this')
        self.assertEqual(dm.visitchildrenset(b'dir'), b'this')
        self.assertEqual(dm.visitchildrenset(b'dir/subdir'), set())
        self.assertEqual(dm.visitchildrenset(b'dir/foo'), b'all')
        self.assertEqual(dm.visitchildrenset(b'folder'), b'all')
        # OPT: We should probably return set() for these; we don't because
        # patternmatcher.visitdir() (our m2) doesn't return 'all' for subdirs of
        # an 'all' pattern, just 'this'.
        self.assertEqual(dm.visitchildrenset(b'dir/subdir/z'), b'this')
        self.assertEqual(dm.visitchildrenset(b'dir/subdir/x'), b'this')

    # We're using includematcher instead of patterns because it behaves slightly
    # better (giving narrower results) than patternmatcher.
    def testVisitdirIncludeIncludfe(self):
        m1 = matchmod.match(b'', b'', include=[b'path:dir/subdir'])
        m2 = matchmod.match(b'', b'', include=[b'rootfilesin:dir'])
        dm = matchmod.differencematcher(m1, m2)
        self.assertEqual(dm.visitdir(b'.'), True)
        self.assertEqual(dm.visitdir(b'dir'), True)
        self.assertEqual(dm.visitdir(b'dir/subdir'), True)
        self.assertFalse(dm.visitdir(b'dir/foo'))
        self.assertFalse(dm.visitdir(b'folder'))
        # OPT: We should probably return False for these; we don't because
        # patternmatcher.visitdir() (our m2) doesn't return 'all' for subdirs of
        # an 'all' pattern, just True.
        self.assertEqual(dm.visitdir(b'dir/subdir/z'), True)
        self.assertEqual(dm.visitdir(b'dir/subdir/x'), True)

    def testVisitchildrensetIncludeInclude(self):
        m1 = matchmod.match(b'', b'', include=[b'path:dir/subdir'])
        m2 = matchmod.match(b'', b'', include=[b'rootfilesin:dir'])
        dm = matchmod.differencematcher(m1, m2)
        self.assertEqual(dm.visitchildrenset(b'.'), {b'dir'})
        self.assertEqual(dm.visitchildrenset(b'dir'), {b'subdir'})
        self.assertEqual(dm.visitchildrenset(b'dir/subdir'), b'all')
        self.assertEqual(dm.visitchildrenset(b'dir/foo'), set())
        self.assertEqual(dm.visitchildrenset(b'folder'), set())
        # OPT: We should probably return set() for these; we don't because
        # patternmatcher.visitdir() (our m2) doesn't return 'all' for subdirs of
        # an 'all' pattern, just 'this'.
        self.assertEqual(dm.visitchildrenset(b'dir/subdir/z'), b'this')
        self.assertEqual(dm.visitchildrenset(b'dir/subdir/x'), b'this')

class IntersectionMatcherTests(unittest.TestCase):

    def testVisitdirM2always(self):
        m1 = matchmod.alwaysmatcher(b'', b'')
        m2 = matchmod.alwaysmatcher(b'', b'')
        im = matchmod.intersectmatchers(m1, m2)
        # im should be equivalent to a alwaysmatcher.
        self.assertEqual(im.visitdir(b'.'), b'all')
        self.assertEqual(im.visitdir(b'dir'), b'all')
        self.assertEqual(im.visitdir(b'dir/subdir'), b'all')
        self.assertEqual(im.visitdir(b'dir/subdir/z'), b'all')
        self.assertEqual(im.visitdir(b'dir/foo'), b'all')
        self.assertEqual(im.visitdir(b'dir/subdir/x'), b'all')
        self.assertEqual(im.visitdir(b'folder'), b'all')

    def testVisitchildrensetM2always(self):
        m1 = matchmod.alwaysmatcher(b'', b'')
        m2 = matchmod.alwaysmatcher(b'', b'')
        im = matchmod.intersectmatchers(m1, m2)
        # im should be equivalent to a alwaysmatcher.
        self.assertEqual(im.visitchildrenset(b'.'), b'all')
        self.assertEqual(im.visitchildrenset(b'dir'), b'all')
        self.assertEqual(im.visitchildrenset(b'dir/subdir'), b'all')
        self.assertEqual(im.visitchildrenset(b'dir/subdir/z'), b'all')
        self.assertEqual(im.visitchildrenset(b'dir/foo'), b'all')
        self.assertEqual(im.visitchildrenset(b'dir/subdir/x'), b'all')
        self.assertEqual(im.visitchildrenset(b'folder'), b'all')

    def testVisitdirM2never(self):
        m1 = matchmod.alwaysmatcher(b'', b'')
        m2 = matchmod.nevermatcher(b'', b'')
        im = matchmod.intersectmatchers(m1, m2)
        # im should be equivalent to a nevermatcher.
        self.assertFalse(im.visitdir(b'.'))
        self.assertFalse(im.visitdir(b'dir'))
        self.assertFalse(im.visitdir(b'dir/subdir'))
        self.assertFalse(im.visitdir(b'dir/subdir/z'))
        self.assertFalse(im.visitdir(b'dir/foo'))
        self.assertFalse(im.visitdir(b'dir/subdir/x'))
        self.assertFalse(im.visitdir(b'folder'))

    def testVisitchildrensetM2never(self):
        m1 = matchmod.alwaysmatcher(b'', b'')
        m2 = matchmod.nevermatcher(b'', b'')
        im = matchmod.intersectmatchers(m1, m2)
        # im should be equivalent to a nevermqtcher.
        self.assertEqual(im.visitchildrenset(b'.'), set())
        self.assertEqual(im.visitchildrenset(b'dir'), set())
        self.assertEqual(im.visitchildrenset(b'dir/subdir'), set())
        self.assertEqual(im.visitchildrenset(b'dir/subdir/z'), set())
        self.assertEqual(im.visitchildrenset(b'dir/foo'), set())
        self.assertEqual(im.visitchildrenset(b'dir/subdir/x'), set())
        self.assertEqual(im.visitchildrenset(b'folder'), set())

    def testVisitdirM2SubdirPrefix(self):
        m1 = matchmod.alwaysmatcher(b'', b'')
        m2 = matchmod.match(b'', b'', patterns=[b'path:dir/subdir'])
        im = matchmod.intersectmatchers(m1, m2)
        self.assertEqual(im.visitdir(b'.'), True)
        self.assertEqual(im.visitdir(b'dir'), True)
        self.assertEqual(im.visitdir(b'dir/subdir'), b'all')
        self.assertFalse(im.visitdir(b'dir/foo'))
        self.assertFalse(im.visitdir(b'folder'))
        # OPT: We should probably return 'all' for these; we don't because
        # patternmatcher.visitdir() (our m2) doesn't return 'all' for subdirs of
        # an 'all' pattern, just True.
        self.assertEqual(im.visitdir(b'dir/subdir/z'), True)
        self.assertEqual(im.visitdir(b'dir/subdir/x'), True)

    def testVisitchildrensetM2SubdirPrefix(self):
        m1 = matchmod.alwaysmatcher(b'', b'')
        m2 = matchmod.match(b'', b'', include=[b'path:dir/subdir'])
        im = matchmod.intersectmatchers(m1, m2)
        self.assertEqual(im.visitchildrenset(b'.'), {b'dir'})
        self.assertEqual(im.visitchildrenset(b'dir'), {b'subdir'})
        self.assertEqual(im.visitchildrenset(b'dir/subdir'), b'all')
        self.assertEqual(im.visitchildrenset(b'dir/foo'), set())
        self.assertEqual(im.visitchildrenset(b'folder'), set())
        # OPT: We should probably return 'all' for these
        self.assertEqual(im.visitchildrenset(b'dir/subdir/z'), b'this')
        self.assertEqual(im.visitchildrenset(b'dir/subdir/x'), b'this')

    # We're using includematcher instead of patterns because it behaves slightly
    # better (giving narrower results) than patternmatcher.
    def testVisitdirIncludeIncludfe(self):
        m1 = matchmod.match(b'', b'', include=[b'path:dir/subdir'])
        m2 = matchmod.match(b'', b'', include=[b'rootfilesin:dir'])
        im = matchmod.intersectmatchers(m1, m2)
        self.assertEqual(im.visitdir(b'.'), True)
        self.assertEqual(im.visitdir(b'dir'), True)
        self.assertFalse(im.visitdir(b'dir/subdir'))
        self.assertFalse(im.visitdir(b'dir/foo'))
        self.assertFalse(im.visitdir(b'folder'))
        self.assertFalse(im.visitdir(b'dir/subdir/z'))
        self.assertFalse(im.visitdir(b'dir/subdir/x'))

    def testVisitchildrensetIncludeInclude(self):
        m1 = matchmod.match(b'', b'', include=[b'path:dir/subdir'])
        m2 = matchmod.match(b'', b'', include=[b'rootfilesin:dir'])
        im = matchmod.intersectmatchers(m1, m2)
        self.assertEqual(im.visitchildrenset(b'.'), {b'dir'})
        self.assertEqual(im.visitchildrenset(b'dir'), b'this')
        self.assertEqual(im.visitchildrenset(b'dir/subdir'), set())
        self.assertEqual(im.visitchildrenset(b'dir/foo'), set())
        self.assertEqual(im.visitchildrenset(b'folder'), set())
        self.assertEqual(im.visitchildrenset(b'dir/subdir/z'), set())
        self.assertEqual(im.visitchildrenset(b'dir/subdir/x'), set())

    # We're using includematcher instead of patterns because it behaves slightly
    # better (giving narrower results) than patternmatcher.
    def testVisitdirIncludeInclude2(self):
        m1 = matchmod.match(b'', b'', include=[b'path:dir/subdir'])
        m2 = matchmod.match(b'', b'', include=[b'path:folder'])
        im = matchmod.intersectmatchers(m1, m2)
        # FIXME: is True correct here?
        self.assertEqual(im.visitdir(b'.'), True)
        self.assertFalse(im.visitdir(b'dir'))
        self.assertFalse(im.visitdir(b'dir/subdir'))
        self.assertFalse(im.visitdir(b'dir/foo'))
        self.assertFalse(im.visitdir(b'folder'))
        self.assertFalse(im.visitdir(b'dir/subdir/z'))
        self.assertFalse(im.visitdir(b'dir/subdir/x'))

    def testVisitchildrensetIncludeInclude2(self):
        m1 = matchmod.match(b'', b'', include=[b'path:dir/subdir'])
        m2 = matchmod.match(b'', b'', include=[b'path:folder'])
        im = matchmod.intersectmatchers(m1, m2)
        # FIXME: is set() correct here?
        self.assertEqual(im.visitchildrenset(b'.'), set())
        self.assertEqual(im.visitchildrenset(b'dir'), set())
        self.assertEqual(im.visitchildrenset(b'dir/subdir'), set())
        self.assertEqual(im.visitchildrenset(b'dir/foo'), set())
        self.assertEqual(im.visitchildrenset(b'folder'), set())
        self.assertEqual(im.visitchildrenset(b'dir/subdir/z'), set())
        self.assertEqual(im.visitchildrenset(b'dir/subdir/x'), set())

    # We're using includematcher instead of patterns because it behaves slightly
    # better (giving narrower results) than patternmatcher.
    def testVisitdirIncludeInclude3(self):
        m1 = matchmod.match(b'', b'', include=[b'path:dir/subdir/x'])
        m2 = matchmod.match(b'', b'', include=[b'path:dir/subdir'])
        im = matchmod.intersectmatchers(m1, m2)
        self.assertEqual(im.visitdir(b'.'), True)
        self.assertEqual(im.visitdir(b'dir'), True)
        self.assertEqual(im.visitdir(b'dir/subdir'), True)
        self.assertFalse(im.visitdir(b'dir/foo'))
        self.assertFalse(im.visitdir(b'folder'))
        self.assertFalse(im.visitdir(b'dir/subdir/z'))
        # OPT: this should probably be 'all' not True.
        self.assertEqual(im.visitdir(b'dir/subdir/x'), True)

    def testVisitchildrensetIncludeInclude3(self):
        m1 = matchmod.match(b'', b'', include=[b'path:dir/subdir/x'])
        m2 = matchmod.match(b'', b'', include=[b'path:dir/subdir'])
        im = matchmod.intersectmatchers(m1, m2)
        self.assertEqual(im.visitchildrenset(b'.'), {b'dir'})
        self.assertEqual(im.visitchildrenset(b'dir'), {b'subdir'})
        self.assertEqual(im.visitchildrenset(b'dir/subdir'), {b'x'})
        self.assertEqual(im.visitchildrenset(b'dir/foo'), set())
        self.assertEqual(im.visitchildrenset(b'folder'), set())
        self.assertEqual(im.visitchildrenset(b'dir/subdir/z'), set())
        # OPT: this should probably be 'all' not 'this'.
        self.assertEqual(im.visitchildrenset(b'dir/subdir/x'), b'this')

    # We're using includematcher instead of patterns because it behaves slightly
    # better (giving narrower results) than patternmatcher.
    def testVisitdirIncludeInclude4(self):
        m1 = matchmod.match(b'', b'', include=[b'path:dir/subdir/x'])
        m2 = matchmod.match(b'', b'', include=[b'path:dir/subdir/z'])
        im = matchmod.intersectmatchers(m1, m2)
        # OPT: these next three could probably be False as well.
        self.assertEqual(im.visitdir(b'.'), True)
        self.assertEqual(im.visitdir(b'dir'), True)
        self.assertEqual(im.visitdir(b'dir/subdir'), True)
        self.assertFalse(im.visitdir(b'dir/foo'))
        self.assertFalse(im.visitdir(b'folder'))
        self.assertFalse(im.visitdir(b'dir/subdir/z'))
        self.assertFalse(im.visitdir(b'dir/subdir/x'))

    def testVisitchildrensetIncludeInclude4(self):
        m1 = matchmod.match(b'', b'', include=[b'path:dir/subdir/x'])
        m2 = matchmod.match(b'', b'', include=[b'path:dir/subdir/z'])
        im = matchmod.intersectmatchers(m1, m2)
        # OPT: these next two could probably be set() as well.
        self.assertEqual(im.visitchildrenset(b'.'), {b'dir'})
        self.assertEqual(im.visitchildrenset(b'dir'), {b'subdir'})
        self.assertEqual(im.visitchildrenset(b'dir/subdir'), set())
        self.assertEqual(im.visitchildrenset(b'dir/foo'), set())
        self.assertEqual(im.visitchildrenset(b'folder'), set())
        self.assertEqual(im.visitchildrenset(b'dir/subdir/z'), set())
        self.assertEqual(im.visitchildrenset(b'dir/subdir/x'), set())

class UnionMatcherTests(unittest.TestCase):

    def testVisitdirM2always(self):
        m1 = matchmod.alwaysmatcher(b'', b'')
        m2 = matchmod.alwaysmatcher(b'', b'')
        um = matchmod.unionmatcher([m1, m2])
        # um should be equivalent to a alwaysmatcher.
        self.assertEqual(um.visitdir(b'.'), b'all')
        self.assertEqual(um.visitdir(b'dir'), b'all')
        self.assertEqual(um.visitdir(b'dir/subdir'), b'all')
        self.assertEqual(um.visitdir(b'dir/subdir/z'), b'all')
        self.assertEqual(um.visitdir(b'dir/foo'), b'all')
        self.assertEqual(um.visitdir(b'dir/subdir/x'), b'all')
        self.assertEqual(um.visitdir(b'folder'), b'all')

    def testVisitchildrensetM2always(self):
        m1 = matchmod.alwaysmatcher(b'', b'')
        m2 = matchmod.alwaysmatcher(b'', b'')
        um = matchmod.unionmatcher([m1, m2])
        # um should be equivalent to a alwaysmatcher.
        self.assertEqual(um.visitchildrenset(b'.'), b'all')
        self.assertEqual(um.visitchildrenset(b'dir'), b'all')
        self.assertEqual(um.visitchildrenset(b'dir/subdir'), b'all')
        self.assertEqual(um.visitchildrenset(b'dir/subdir/z'), b'all')
        self.assertEqual(um.visitchildrenset(b'dir/foo'), b'all')
        self.assertEqual(um.visitchildrenset(b'dir/subdir/x'), b'all')
        self.assertEqual(um.visitchildrenset(b'folder'), b'all')

    def testVisitdirM1never(self):
        m1 = matchmod.nevermatcher(b'', b'')
        m2 = matchmod.alwaysmatcher(b'', b'')
        um = matchmod.unionmatcher([m1, m2])
        # um should be equivalent to a alwaysmatcher.
        self.assertEqual(um.visitdir(b'.'), b'all')
        self.assertEqual(um.visitdir(b'dir'), b'all')
        self.assertEqual(um.visitdir(b'dir/subdir'), b'all')
        self.assertEqual(um.visitdir(b'dir/subdir/z'), b'all')
        self.assertEqual(um.visitdir(b'dir/foo'), b'all')
        self.assertEqual(um.visitdir(b'dir/subdir/x'), b'all')
        self.assertEqual(um.visitdir(b'folder'), b'all')

    def testVisitchildrensetM1never(self):
        m1 = matchmod.nevermatcher(b'', b'')
        m2 = matchmod.alwaysmatcher(b'', b'')
        um = matchmod.unionmatcher([m1, m2])
        # um should be equivalent to a alwaysmatcher.
        self.assertEqual(um.visitchildrenset(b'.'), b'all')
        self.assertEqual(um.visitchildrenset(b'dir'), b'all')
        self.assertEqual(um.visitchildrenset(b'dir/subdir'), b'all')
        self.assertEqual(um.visitchildrenset(b'dir/subdir/z'), b'all')
        self.assertEqual(um.visitchildrenset(b'dir/foo'), b'all')
        self.assertEqual(um.visitchildrenset(b'dir/subdir/x'), b'all')
        self.assertEqual(um.visitchildrenset(b'folder'), b'all')

    def testVisitdirM2never(self):
        m1 = matchmod.alwaysmatcher(b'', b'')
        m2 = matchmod.nevermatcher(b'', b'')
        um = matchmod.unionmatcher([m1, m2])
        # um should be equivalent to a alwaysmatcher.
        self.assertEqual(um.visitdir(b'.'), b'all')
        self.assertEqual(um.visitdir(b'dir'), b'all')
        self.assertEqual(um.visitdir(b'dir/subdir'), b'all')
        self.assertEqual(um.visitdir(b'dir/subdir/z'), b'all')
        self.assertEqual(um.visitdir(b'dir/foo'), b'all')
        self.assertEqual(um.visitdir(b'dir/subdir/x'), b'all')
        self.assertEqual(um.visitdir(b'folder'), b'all')

    def testVisitchildrensetM2never(self):
        m1 = matchmod.alwaysmatcher(b'', b'')
        m2 = matchmod.nevermatcher(b'', b'')
        um = matchmod.unionmatcher([m1, m2])
        # um should be equivalent to a alwaysmatcher.
        self.assertEqual(um.visitchildrenset(b'.'), b'all')
        self.assertEqual(um.visitchildrenset(b'dir'), b'all')
        self.assertEqual(um.visitchildrenset(b'dir/subdir'), b'all')
        self.assertEqual(um.visitchildrenset(b'dir/subdir/z'), b'all')
        self.assertEqual(um.visitchildrenset(b'dir/foo'), b'all')
        self.assertEqual(um.visitchildrenset(b'dir/subdir/x'), b'all')
        self.assertEqual(um.visitchildrenset(b'folder'), b'all')

    def testVisitdirM2SubdirPrefix(self):
        m1 = matchmod.alwaysmatcher(b'', b'')
        m2 = matchmod.match(b'', b'', patterns=[b'path:dir/subdir'])
        um = matchmod.unionmatcher([m1, m2])
        self.assertEqual(um.visitdir(b'.'), b'all')
        self.assertEqual(um.visitdir(b'dir'), b'all')
        self.assertEqual(um.visitdir(b'dir/subdir'), b'all')
        self.assertEqual(um.visitdir(b'dir/foo'), b'all')
        self.assertEqual(um.visitdir(b'folder'), b'all')
        self.assertEqual(um.visitdir(b'dir/subdir/z'), b'all')
        self.assertEqual(um.visitdir(b'dir/subdir/x'), b'all')

    def testVisitchildrensetM2SubdirPrefix(self):
        m1 = matchmod.alwaysmatcher(b'', b'')
        m2 = matchmod.match(b'', b'', include=[b'path:dir/subdir'])
        um = matchmod.unionmatcher([m1, m2])
        self.assertEqual(um.visitchildrenset(b'.'), b'all')
        self.assertEqual(um.visitchildrenset(b'dir'), b'all')
        self.assertEqual(um.visitchildrenset(b'dir/subdir'), b'all')
        self.assertEqual(um.visitchildrenset(b'dir/foo'), b'all')
        self.assertEqual(um.visitchildrenset(b'folder'), b'all')
        self.assertEqual(um.visitchildrenset(b'dir/subdir/z'), b'all')
        self.assertEqual(um.visitchildrenset(b'dir/subdir/x'), b'all')

    # We're using includematcher instead of patterns because it behaves slightly
    # better (giving narrower results) than patternmatcher.
    def testVisitdirIncludeIncludfe(self):
        m1 = matchmod.match(b'', b'', include=[b'path:dir/subdir'])
        m2 = matchmod.match(b'', b'', include=[b'rootfilesin:dir'])
        um = matchmod.unionmatcher([m1, m2])
        self.assertEqual(um.visitdir(b'.'), True)
        self.assertEqual(um.visitdir(b'dir'), True)
        self.assertEqual(um.visitdir(b'dir/subdir'), b'all')
        self.assertFalse(um.visitdir(b'dir/foo'))
        self.assertFalse(um.visitdir(b'folder'))
        # OPT: These two should probably be 'all' not True.
        self.assertEqual(um.visitdir(b'dir/subdir/z'), True)
        self.assertEqual(um.visitdir(b'dir/subdir/x'), True)

    def testVisitchildrensetIncludeInclude(self):
        m1 = matchmod.match(b'', b'', include=[b'path:dir/subdir'])
        m2 = matchmod.match(b'', b'', include=[b'rootfilesin:dir'])
        um = matchmod.unionmatcher([m1, m2])
        self.assertEqual(um.visitchildrenset(b'.'), {b'dir'})
        self.assertEqual(um.visitchildrenset(b'dir'), b'this')
        self.assertEqual(um.visitchildrenset(b'dir/subdir'), b'all')
        self.assertEqual(um.visitchildrenset(b'dir/foo'), set())
        self.assertEqual(um.visitchildrenset(b'folder'), set())
        # OPT: These next two could be 'all' instead of 'this'.
        self.assertEqual(um.visitchildrenset(b'dir/subdir/z'), b'this')
        self.assertEqual(um.visitchildrenset(b'dir/subdir/x'), b'this')

    # We're using includematcher instead of patterns because it behaves slightly
    # better (giving narrower results) than patternmatcher.
    def testVisitdirIncludeInclude2(self):
        m1 = matchmod.match(b'', b'', include=[b'path:dir/subdir'])
        m2 = matchmod.match(b'', b'', include=[b'path:folder'])
        um = matchmod.unionmatcher([m1, m2])
        self.assertEqual(um.visitdir(b'.'), True)
        self.assertEqual(um.visitdir(b'dir'), True)
        self.assertEqual(um.visitdir(b'dir/subdir'), b'all')
        self.assertFalse(um.visitdir(b'dir/foo'))
        self.assertEqual(um.visitdir(b'folder'), b'all')
        # OPT: These should probably be 'all' not True.
        self.assertEqual(um.visitdir(b'dir/subdir/z'), True)
        self.assertEqual(um.visitdir(b'dir/subdir/x'), True)

    def testVisitchildrensetIncludeInclude2(self):
        m1 = matchmod.match(b'', b'', include=[b'path:dir/subdir'])
        m2 = matchmod.match(b'', b'', include=[b'path:folder'])
        um = matchmod.unionmatcher([m1, m2])
        self.assertEqual(um.visitchildrenset(b'.'), {b'folder', b'dir'})
        self.assertEqual(um.visitchildrenset(b'dir'), {b'subdir'})
        self.assertEqual(um.visitchildrenset(b'dir/subdir'), b'all')
        self.assertEqual(um.visitchildrenset(b'dir/foo'), set())
        self.assertEqual(um.visitchildrenset(b'folder'), b'all')
        # OPT: These next two could be 'all' instead of 'this'.
        self.assertEqual(um.visitchildrenset(b'dir/subdir/z'), b'this')
        self.assertEqual(um.visitchildrenset(b'dir/subdir/x'), b'this')

    # We're using includematcher instead of patterns because it behaves slightly
    # better (giving narrower results) than patternmatcher.
    def testVisitdirIncludeInclude3(self):
        m1 = matchmod.match(b'', b'', include=[b'path:dir/subdir/x'])
        m2 = matchmod.match(b'', b'', include=[b'path:dir/subdir'])
        um = matchmod.unionmatcher([m1, m2])
        self.assertEqual(um.visitdir(b'.'), True)
        self.assertEqual(um.visitdir(b'dir'), True)
        self.assertEqual(um.visitdir(b'dir/subdir'), b'all')
        self.assertFalse(um.visitdir(b'dir/foo'))
        self.assertFalse(um.visitdir(b'folder'))
        self.assertEqual(um.visitdir(b'dir/subdir/x'), b'all')
        # OPT: this should probably be 'all' not True.
        self.assertEqual(um.visitdir(b'dir/subdir/z'), True)

    def testVisitchildrensetIncludeInclude3(self):
        m1 = matchmod.match(b'', b'', include=[b'path:dir/subdir/x'])
        m2 = matchmod.match(b'', b'', include=[b'path:dir/subdir'])
        um = matchmod.unionmatcher([m1, m2])
        self.assertEqual(um.visitchildrenset(b'.'), {b'dir'})
        self.assertEqual(um.visitchildrenset(b'dir'), {b'subdir'})
        self.assertEqual(um.visitchildrenset(b'dir/subdir'), b'all')
        self.assertEqual(um.visitchildrenset(b'dir/foo'), set())
        self.assertEqual(um.visitchildrenset(b'folder'), set())
        self.assertEqual(um.visitchildrenset(b'dir/subdir/x'), b'all')
        # OPT: this should probably be 'all' not 'this'.
        self.assertEqual(um.visitchildrenset(b'dir/subdir/z'), b'this')

    # We're using includematcher instead of patterns because it behaves slightly
    # better (giving narrower results) than patternmatcher.
    def testVisitdirIncludeInclude4(self):
        m1 = matchmod.match(b'', b'', include=[b'path:dir/subdir/x'])
        m2 = matchmod.match(b'', b'', include=[b'path:dir/subdir/z'])
        um = matchmod.unionmatcher([m1, m2])
        # OPT: these next three could probably be False as well.
        self.assertEqual(um.visitdir(b'.'), True)
        self.assertEqual(um.visitdir(b'dir'), True)
        self.assertEqual(um.visitdir(b'dir/subdir'), True)
        self.assertFalse(um.visitdir(b'dir/foo'))
        self.assertFalse(um.visitdir(b'folder'))
        self.assertEqual(um.visitdir(b'dir/subdir/z'), b'all')
        self.assertEqual(um.visitdir(b'dir/subdir/x'), b'all')

    def testVisitchildrensetIncludeInclude4(self):
        m1 = matchmod.match(b'', b'', include=[b'path:dir/subdir/x'])
        m2 = matchmod.match(b'', b'', include=[b'path:dir/subdir/z'])
        um = matchmod.unionmatcher([m1, m2])
        self.assertEqual(um.visitchildrenset(b'.'), {b'dir'})
        self.assertEqual(um.visitchildrenset(b'dir'), {b'subdir'})
        self.assertEqual(um.visitchildrenset(b'dir/subdir'), {b'x', b'z'})
        self.assertEqual(um.visitchildrenset(b'dir/foo'), set())
        self.assertEqual(um.visitchildrenset(b'folder'), set())
        self.assertEqual(um.visitchildrenset(b'dir/subdir/z'), b'all')
        self.assertEqual(um.visitchildrenset(b'dir/subdir/x'), b'all')

class SubdirMatcherTests(unittest.TestCase):

    def testVisitdir(self):
        m = matchmod.match(b'', b'', include=[b'path:dir/subdir'])
        sm = matchmod.subdirmatcher(b'dir', m)

        self.assertEqual(sm.visitdir(b'.'), True)
        self.assertEqual(sm.visitdir(b'subdir'), b'all')
        # OPT: These next two should probably be 'all' not True.
        self.assertEqual(sm.visitdir(b'subdir/x'), True)
        self.assertEqual(sm.visitdir(b'subdir/z'), True)
        self.assertFalse(sm.visitdir(b'foo'))

    def testVisitchildrenset(self):
        m = matchmod.match(b'', b'', include=[b'path:dir/subdir'])
        sm = matchmod.subdirmatcher(b'dir', m)

        self.assertEqual(sm.visitchildrenset(b'.'), {b'subdir'})
        self.assertEqual(sm.visitchildrenset(b'subdir'), b'all')
        # OPT: These next two should probably be 'all' not 'this'.
        self.assertEqual(sm.visitchildrenset(b'subdir/x'), b'this')
        self.assertEqual(sm.visitchildrenset(b'subdir/z'), b'this')
        self.assertEqual(sm.visitchildrenset(b'foo'), set())

class PrefixdirMatcherTests(unittest.TestCase):

    def testVisitdir(self):
        m = matchmod.match(util.localpath(b'root/d'), b'e/f',
                [b'../a.txt', b'b.txt'])
        pm = matchmod.prefixdirmatcher(b'root', b'd/e/f', b'd', m)

        # `m` elides 'd' because it's part of the root, and the rest of the
        # patterns are relative.
        self.assertEqual(bool(m(b'a.txt')), False)
        self.assertEqual(bool(m(b'b.txt')), False)
        self.assertEqual(bool(m(b'e/a.txt')), True)
        self.assertEqual(bool(m(b'e/b.txt')), False)
        self.assertEqual(bool(m(b'e/f/b.txt')), True)

        # The prefix matcher re-adds 'd' to the paths, so they need to be
        # specified when using the prefixdirmatcher.
        self.assertEqual(bool(pm(b'a.txt')), False)
        self.assertEqual(bool(pm(b'b.txt')), False)
        self.assertEqual(bool(pm(b'd/e/a.txt')), True)
        self.assertEqual(bool(pm(b'd/e/b.txt')), False)
        self.assertEqual(bool(pm(b'd/e/f/b.txt')), True)

        self.assertEqual(m.visitdir(b'.'), True)
        self.assertEqual(m.visitdir(b'e'), True)
        self.assertEqual(m.visitdir(b'e/f'), True)
        self.assertEqual(m.visitdir(b'e/f/g'), False)

        self.assertEqual(pm.visitdir(b'.'), True)
        self.assertEqual(pm.visitdir(b'd'), True)
        self.assertEqual(pm.visitdir(b'd/e'), True)
        self.assertEqual(pm.visitdir(b'd/e/f'), True)
        self.assertEqual(pm.visitdir(b'd/e/f/g'), False)

    def testVisitchildrenset(self):
        m = matchmod.match(util.localpath(b'root/d'), b'e/f',
                [b'../a.txt', b'b.txt'])
        pm = matchmod.prefixdirmatcher(b'root', b'd/e/f', b'd', m)

        # OPT: visitchildrenset could possibly return {'e'} and {'f'} for these
        # next two, respectively; patternmatcher does not have this
        # optimization.
        self.assertEqual(m.visitchildrenset(b'.'), b'this')
        self.assertEqual(m.visitchildrenset(b'e'), b'this')
        self.assertEqual(m.visitchildrenset(b'e/f'), b'this')
        self.assertEqual(m.visitchildrenset(b'e/f/g'), set())

        # OPT: visitchildrenset could possibly return {'d'}, {'e'}, and {'f'}
        # for these next three, respectively; patternmatcher does not have this
        # optimization.
        self.assertEqual(pm.visitchildrenset(b'.'), b'this')
        self.assertEqual(pm.visitchildrenset(b'd'), b'this')
        self.assertEqual(pm.visitchildrenset(b'd/e'), b'this')
        self.assertEqual(pm.visitchildrenset(b'd/e/f'), b'this')
        self.assertEqual(pm.visitchildrenset(b'd/e/f/g'), set())

if __name__ == '__main__':
    silenttestrunner.main(__name__)
