from __future__ import absolute_import

import unittest

import silenttestrunner

from mercurial import (
    match as matchmod,
    util,
)

class BaseMatcherTests(unittest.TestCase):

    def testVisitdir(self):
        m = matchmod.basematcher('', '')
        self.assertTrue(m.visitdir('.'))
        self.assertTrue(m.visitdir('dir'))

    def testVisitchildrenset(self):
        m = matchmod.basematcher('', '')
        self.assertEqual(m.visitchildrenset('.'), 'this')
        self.assertEqual(m.visitchildrenset('dir'), 'this')

class AlwaysMatcherTests(unittest.TestCase):

    def testVisitdir(self):
        m = matchmod.alwaysmatcher('', '')
        self.assertEqual(m.visitdir('.'), 'all')
        self.assertEqual(m.visitdir('dir'), 'all')

    def testVisitchildrenset(self):
        m = matchmod.alwaysmatcher('', '')
        self.assertEqual(m.visitchildrenset('.'), 'all')
        self.assertEqual(m.visitchildrenset('dir'), 'all')

class NeverMatcherTests(unittest.TestCase):

    def testVisitdir(self):
        m = matchmod.nevermatcher('', '')
        self.assertFalse(m.visitdir('.'))
        self.assertFalse(m.visitdir('dir'))

    def testVisitchildrenset(self):
        m = matchmod.nevermatcher('', '')
        self.assertEqual(m.visitchildrenset('.'), set())
        self.assertEqual(m.visitchildrenset('dir'), set())

class PredicateMatcherTests(unittest.TestCase):
    # predicatematcher does not currently define either of these methods, so
    # this is equivalent to BaseMatcherTests.

    def testVisitdir(self):
        m = matchmod.predicatematcher('', '', lambda *a: False)
        self.assertTrue(m.visitdir('.'))
        self.assertTrue(m.visitdir('dir'))

    def testVisitchildrenset(self):
        m = matchmod.predicatematcher('', '', lambda *a: False)
        self.assertEqual(m.visitchildrenset('.'), 'this')
        self.assertEqual(m.visitchildrenset('dir'), 'this')

class PatternMatcherTests(unittest.TestCase):

    def testVisitdirPrefix(self):
        m = matchmod.match('x', '', patterns=['path:dir/subdir'])
        assert isinstance(m, matchmod.patternmatcher)
        self.assertTrue(m.visitdir('.'))
        self.assertTrue(m.visitdir('dir'))
        self.assertEqual(m.visitdir('dir/subdir'), 'all')
        # OPT: This should probably be 'all' if its parent is?
        self.assertTrue(m.visitdir('dir/subdir/x'))
        self.assertFalse(m.visitdir('folder'))

    def testVisitchildrensetPrefix(self):
        m = matchmod.match('x', '', patterns=['path:dir/subdir'])
        assert isinstance(m, matchmod.patternmatcher)
        self.assertEqual(m.visitchildrenset('.'), 'this')
        self.assertEqual(m.visitchildrenset('dir'), 'this')
        self.assertEqual(m.visitchildrenset('dir/subdir'), 'all')
        # OPT: This should probably be 'all' if its parent is?
        self.assertEqual(m.visitchildrenset('dir/subdir/x'), 'this')
        self.assertEqual(m.visitchildrenset('folder'), set())

    def testVisitdirRootfilesin(self):
        m = matchmod.match('x', '', patterns=['rootfilesin:dir/subdir'])
        assert isinstance(m, matchmod.patternmatcher)
        self.assertTrue(m.visitdir('.'))
        self.assertFalse(m.visitdir('dir/subdir/x'))
        self.assertFalse(m.visitdir('folder'))
        # FIXME: These should probably be True.
        self.assertFalse(m.visitdir('dir'))
        self.assertFalse(m.visitdir('dir/subdir'))

    def testVisitchildrensetRootfilesin(self):
        m = matchmod.match('x', '', patterns=['rootfilesin:dir/subdir'])
        assert isinstance(m, matchmod.patternmatcher)
        self.assertEqual(m.visitchildrenset('.'), 'this')
        self.assertEqual(m.visitchildrenset('dir/subdir/x'), set())
        self.assertEqual(m.visitchildrenset('folder'), set())
        self.assertEqual(m.visitchildrenset('dir'), set())
        self.assertEqual(m.visitchildrenset('dir/subdir'), set())

    def testVisitdirGlob(self):
        m = matchmod.match('x', '', patterns=['glob:dir/z*'])
        assert isinstance(m, matchmod.patternmatcher)
        self.assertTrue(m.visitdir('.'))
        self.assertTrue(m.visitdir('dir'))
        self.assertFalse(m.visitdir('folder'))
        # OPT: these should probably be False.
        self.assertTrue(m.visitdir('dir/subdir'))
        self.assertTrue(m.visitdir('dir/subdir/x'))

    def testVisitchildrensetGlob(self):
        m = matchmod.match('x', '', patterns=['glob:dir/z*'])
        assert isinstance(m, matchmod.patternmatcher)
        self.assertEqual(m.visitchildrenset('.'), 'this')
        self.assertEqual(m.visitchildrenset('folder'), set())
        self.assertEqual(m.visitchildrenset('dir'), 'this')
        # OPT: these should probably be set().
        self.assertEqual(m.visitchildrenset('dir/subdir'), 'this')
        self.assertEqual(m.visitchildrenset('dir/subdir/x'), 'this')

class IncludeMatcherTests(unittest.TestCase):

    def testVisitdirPrefix(self):
        m = matchmod.match('x', '', include=['path:dir/subdir'])
        assert isinstance(m, matchmod.includematcher)
        self.assertTrue(m.visitdir('.'))
        self.assertTrue(m.visitdir('dir'))
        self.assertEqual(m.visitdir('dir/subdir'), 'all')
        # OPT: This should probably be 'all' if its parent is?
        self.assertTrue(m.visitdir('dir/subdir/x'))
        self.assertFalse(m.visitdir('folder'))

    def testVisitchildrensetPrefix(self):
        m = matchmod.match('x', '', include=['path:dir/subdir'])
        assert isinstance(m, matchmod.includematcher)
        self.assertEqual(m.visitchildrenset('.'), {'dir'})
        self.assertEqual(m.visitchildrenset('dir'), {'subdir'})
        self.assertEqual(m.visitchildrenset('dir/subdir'), 'all')
        # OPT: This should probably be 'all' if its parent is?
        self.assertEqual(m.visitchildrenset('dir/subdir/x'), 'this')
        self.assertEqual(m.visitchildrenset('folder'), set())

    def testVisitdirRootfilesin(self):
        m = matchmod.match('x', '', include=['rootfilesin:dir/subdir'])
        assert isinstance(m, matchmod.includematcher)
        self.assertTrue(m.visitdir('.'))
        self.assertTrue(m.visitdir('dir'))
        self.assertTrue(m.visitdir('dir/subdir'))
        self.assertFalse(m.visitdir('dir/subdir/x'))
        self.assertFalse(m.visitdir('folder'))

    def testVisitchildrensetRootfilesin(self):
        m = matchmod.match('x', '', include=['rootfilesin:dir/subdir'])
        assert isinstance(m, matchmod.includematcher)
        self.assertEqual(m.visitchildrenset('.'), {'dir'})
        self.assertEqual(m.visitchildrenset('dir'), {'subdir'})
        self.assertEqual(m.visitchildrenset('dir/subdir'), 'this')
        self.assertEqual(m.visitchildrenset('dir/subdir/x'), set())
        self.assertEqual(m.visitchildrenset('folder'), set())

    def testVisitdirGlob(self):
        m = matchmod.match('x', '', include=['glob:dir/z*'])
        assert isinstance(m, matchmod.includematcher)
        self.assertTrue(m.visitdir('.'))
        self.assertTrue(m.visitdir('dir'))
        self.assertFalse(m.visitdir('folder'))
        # OPT: these should probably be False.
        self.assertTrue(m.visitdir('dir/subdir'))
        self.assertTrue(m.visitdir('dir/subdir/x'))

    def testVisitchildrensetGlob(self):
        m = matchmod.match('x', '', include=['glob:dir/z*'])
        assert isinstance(m, matchmod.includematcher)
        self.assertEqual(m.visitchildrenset('.'), {'dir'})
        self.assertEqual(m.visitchildrenset('folder'), set())
        self.assertEqual(m.visitchildrenset('dir'), 'this')
        # OPT: these should probably be set().
        self.assertEqual(m.visitchildrenset('dir/subdir'), 'this')
        self.assertEqual(m.visitchildrenset('dir/subdir/x'), 'this')

class ExactMatcherTests(unittest.TestCase):

    def testVisitdir(self):
        m = matchmod.match('x', '', patterns=['dir/subdir/foo.txt'], exact=True)
        assert isinstance(m, matchmod.exactmatcher)
        self.assertTrue(m.visitdir('.'))
        self.assertTrue(m.visitdir('dir'))
        self.assertTrue(m.visitdir('dir/subdir'))
        self.assertFalse(m.visitdir('dir/subdir/foo.txt'))
        self.assertFalse(m.visitdir('dir/foo'))
        self.assertFalse(m.visitdir('dir/subdir/x'))
        self.assertFalse(m.visitdir('folder'))

    def testVisitchildrenset(self):
        m = matchmod.match('x', '', patterns=['dir/subdir/foo.txt'], exact=True)
        assert isinstance(m, matchmod.exactmatcher)
        self.assertEqual(m.visitchildrenset('.'), {'dir'})
        self.assertEqual(m.visitchildrenset('dir'), {'subdir'})
        self.assertEqual(m.visitchildrenset('dir/subdir'), 'this')
        self.assertEqual(m.visitchildrenset('dir/subdir/x'), set())
        self.assertEqual(m.visitchildrenset('dir/subdir/foo.txt'), set())
        self.assertEqual(m.visitchildrenset('folder'), set())

class DifferenceMatcherTests(unittest.TestCase):

    def testVisitdirM2always(self):
        m1 = matchmod.alwaysmatcher('', '')
        m2 = matchmod.alwaysmatcher('', '')
        dm = matchmod.differencematcher(m1, m2)
        # dm should be equivalent to a nevermatcher.
        self.assertFalse(dm.visitdir('.'))
        self.assertFalse(dm.visitdir('dir'))
        self.assertFalse(dm.visitdir('dir/subdir'))
        self.assertFalse(dm.visitdir('dir/subdir/z'))
        self.assertFalse(dm.visitdir('dir/foo'))
        self.assertFalse(dm.visitdir('dir/subdir/x'))
        self.assertFalse(dm.visitdir('folder'))

    def testVisitchildrensetM2always(self):
        m1 = matchmod.alwaysmatcher('', '')
        m2 = matchmod.alwaysmatcher('', '')
        dm = matchmod.differencematcher(m1, m2)
        # dm should be equivalent to a nevermatcher.
        self.assertEqual(dm.visitchildrenset('.'), set())
        self.assertEqual(dm.visitchildrenset('dir'), set())
        self.assertEqual(dm.visitchildrenset('dir/subdir'), set())
        self.assertEqual(dm.visitchildrenset('dir/subdir/z'), set())
        self.assertEqual(dm.visitchildrenset('dir/foo'), set())
        self.assertEqual(dm.visitchildrenset('dir/subdir/x'), set())
        self.assertEqual(dm.visitchildrenset('folder'), set())

    def testVisitdirM2never(self):
        m1 = matchmod.alwaysmatcher('', '')
        m2 = matchmod.nevermatcher('', '')
        dm = matchmod.differencematcher(m1, m2)
        # dm should be equivalent to a alwaysmatcher. OPT: if m2 is a
        # nevermatcher, we could return 'all' for these.
        #
        # We're testing Equal-to-True instead of just 'assertTrue' since
        # assertTrue does NOT verify that it's a bool, just that it's truthy.
        # While we may want to eventually make these return 'all', they should
        # not currently do so.
        self.assertEqual(dm.visitdir('.'), True)
        self.assertEqual(dm.visitdir('dir'), True)
        self.assertEqual(dm.visitdir('dir/subdir'), True)
        self.assertEqual(dm.visitdir('dir/subdir/z'), True)
        self.assertEqual(dm.visitdir('dir/foo'), True)
        self.assertEqual(dm.visitdir('dir/subdir/x'), True)
        self.assertEqual(dm.visitdir('folder'), True)

    def testVisitchildrensetM2never(self):
        m1 = matchmod.alwaysmatcher('', '')
        m2 = matchmod.nevermatcher('', '')
        dm = matchmod.differencematcher(m1, m2)
        # dm should be equivalent to a alwaysmatcher.
        self.assertEqual(dm.visitchildrenset('.'), 'all')
        self.assertEqual(dm.visitchildrenset('dir'), 'all')
        self.assertEqual(dm.visitchildrenset('dir/subdir'), 'all')
        self.assertEqual(dm.visitchildrenset('dir/subdir/z'), 'all')
        self.assertEqual(dm.visitchildrenset('dir/foo'), 'all')
        self.assertEqual(dm.visitchildrenset('dir/subdir/x'), 'all')
        self.assertEqual(dm.visitchildrenset('folder'), 'all')

    def testVisitdirM2SubdirPrefix(self):
        m1 = matchmod.alwaysmatcher('', '')
        m2 = matchmod.match('', '', patterns=['path:dir/subdir'])
        dm = matchmod.differencematcher(m1, m2)
        self.assertEqual(dm.visitdir('.'), True)
        self.assertEqual(dm.visitdir('dir'), True)
        self.assertFalse(dm.visitdir('dir/subdir'))
        # OPT: We should probably return False for these; we don't because
        # patternmatcher.visitdir() (our m2) doesn't return 'all' for subdirs of
        # an 'all' pattern, just True.
        self.assertEqual(dm.visitdir('dir/subdir/z'), True)
        self.assertEqual(dm.visitdir('dir/subdir/x'), True)
        # OPT: We could return 'all' for these.
        self.assertEqual(dm.visitdir('dir/foo'), True)
        self.assertEqual(dm.visitdir('folder'), True)

    def testVisitchildrensetM2SubdirPrefix(self):
        m1 = matchmod.alwaysmatcher('', '')
        m2 = matchmod.match('', '', patterns=['path:dir/subdir'])
        dm = matchmod.differencematcher(m1, m2)
        self.assertEqual(dm.visitchildrenset('.'), 'this')
        self.assertEqual(dm.visitchildrenset('dir'), 'this')
        self.assertEqual(dm.visitchildrenset('dir/subdir'), set())
        self.assertEqual(dm.visitchildrenset('dir/foo'), 'all')
        self.assertEqual(dm.visitchildrenset('folder'), 'all')
        # OPT: We should probably return set() for these; we don't because
        # patternmatcher.visitdir() (our m2) doesn't return 'all' for subdirs of
        # an 'all' pattern, just 'this'.
        self.assertEqual(dm.visitchildrenset('dir/subdir/z'), 'this')
        self.assertEqual(dm.visitchildrenset('dir/subdir/x'), 'this')

    # We're using includematcher instead of patterns because it behaves slightly
    # better (giving narrower results) than patternmatcher.
    def testVisitdirIncludeIncludfe(self):
        m1 = matchmod.match('', '', include=['path:dir/subdir'])
        m2 = matchmod.match('', '', include=['rootfilesin:dir'])
        dm = matchmod.differencematcher(m1, m2)
        self.assertEqual(dm.visitdir('.'), True)
        self.assertEqual(dm.visitdir('dir'), True)
        self.assertEqual(dm.visitdir('dir/subdir'), True)
        self.assertFalse(dm.visitdir('dir/foo'))
        self.assertFalse(dm.visitdir('folder'))
        # OPT: We should probably return False for these; we don't because
        # patternmatcher.visitdir() (our m2) doesn't return 'all' for subdirs of
        # an 'all' pattern, just True.
        self.assertEqual(dm.visitdir('dir/subdir/z'), True)
        self.assertEqual(dm.visitdir('dir/subdir/x'), True)

    def testVisitchildrensetIncludeInclude(self):
        m1 = matchmod.match('', '', include=['path:dir/subdir'])
        m2 = matchmod.match('', '', include=['rootfilesin:dir'])
        dm = matchmod.differencematcher(m1, m2)
        self.assertEqual(dm.visitchildrenset('.'), {'dir'})
        self.assertEqual(dm.visitchildrenset('dir'), {'subdir'})
        self.assertEqual(dm.visitchildrenset('dir/subdir'), 'all')
        self.assertEqual(dm.visitchildrenset('dir/foo'), set())
        self.assertEqual(dm.visitchildrenset('folder'), set())
        # OPT: We should probably return set() for these; we don't because
        # patternmatcher.visitdir() (our m2) doesn't return 'all' for subdirs of
        # an 'all' pattern, just 'this'.
        self.assertEqual(dm.visitchildrenset('dir/subdir/z'), 'this')
        self.assertEqual(dm.visitchildrenset('dir/subdir/x'), 'this')

class IntersectionMatcherTests(unittest.TestCase):

    def testVisitdirM2always(self):
        m1 = matchmod.alwaysmatcher('', '')
        m2 = matchmod.alwaysmatcher('', '')
        im = matchmod.intersectmatchers(m1, m2)
        # im should be equivalent to a alwaysmatcher.
        self.assertEqual(im.visitdir('.'), 'all')
        self.assertEqual(im.visitdir('dir'), 'all')
        self.assertEqual(im.visitdir('dir/subdir'), 'all')
        self.assertEqual(im.visitdir('dir/subdir/z'), 'all')
        self.assertEqual(im.visitdir('dir/foo'), 'all')
        self.assertEqual(im.visitdir('dir/subdir/x'), 'all')
        self.assertEqual(im.visitdir('folder'), 'all')

    def testVisitchildrensetM2always(self):
        m1 = matchmod.alwaysmatcher('', '')
        m2 = matchmod.alwaysmatcher('', '')
        im = matchmod.intersectmatchers(m1, m2)
        # im should be equivalent to a alwaysmatcher.
        self.assertEqual(im.visitchildrenset('.'), 'all')
        self.assertEqual(im.visitchildrenset('dir'), 'all')
        self.assertEqual(im.visitchildrenset('dir/subdir'), 'all')
        self.assertEqual(im.visitchildrenset('dir/subdir/z'), 'all')
        self.assertEqual(im.visitchildrenset('dir/foo'), 'all')
        self.assertEqual(im.visitchildrenset('dir/subdir/x'), 'all')
        self.assertEqual(im.visitchildrenset('folder'), 'all')

    def testVisitdirM2never(self):
        m1 = matchmod.alwaysmatcher('', '')
        m2 = matchmod.nevermatcher('', '')
        im = matchmod.intersectmatchers(m1, m2)
        # im should be equivalent to a nevermatcher.
        self.assertFalse(im.visitdir('.'))
        self.assertFalse(im.visitdir('dir'))
        self.assertFalse(im.visitdir('dir/subdir'))
        self.assertFalse(im.visitdir('dir/subdir/z'))
        self.assertFalse(im.visitdir('dir/foo'))
        self.assertFalse(im.visitdir('dir/subdir/x'))
        self.assertFalse(im.visitdir('folder'))

    def testVisitchildrensetM2never(self):
        m1 = matchmod.alwaysmatcher('', '')
        m2 = matchmod.nevermatcher('', '')
        im = matchmod.intersectmatchers(m1, m2)
        # im should be equivalent to a nevermqtcher.
        self.assertEqual(im.visitchildrenset('.'), set())
        self.assertEqual(im.visitchildrenset('dir'), set())
        self.assertEqual(im.visitchildrenset('dir/subdir'), set())
        self.assertEqual(im.visitchildrenset('dir/subdir/z'), set())
        self.assertEqual(im.visitchildrenset('dir/foo'), set())
        self.assertEqual(im.visitchildrenset('dir/subdir/x'), set())
        self.assertEqual(im.visitchildrenset('folder'), set())

    def testVisitdirM2SubdirPrefix(self):
        m1 = matchmod.alwaysmatcher('', '')
        m2 = matchmod.match('', '', patterns=['path:dir/subdir'])
        im = matchmod.intersectmatchers(m1, m2)
        self.assertEqual(im.visitdir('.'), True)
        self.assertEqual(im.visitdir('dir'), True)
        self.assertEqual(im.visitdir('dir/subdir'), 'all')
        self.assertFalse(im.visitdir('dir/foo'))
        self.assertFalse(im.visitdir('folder'))
        # OPT: We should probably return 'all' for these; we don't because
        # patternmatcher.visitdir() (our m2) doesn't return 'all' for subdirs of
        # an 'all' pattern, just True.
        self.assertEqual(im.visitdir('dir/subdir/z'), True)
        self.assertEqual(im.visitdir('dir/subdir/x'), True)

    def testVisitchildrensetM2SubdirPrefix(self):
        m1 = matchmod.alwaysmatcher('', '')
        m2 = matchmod.match('', '', include=['path:dir/subdir'])
        im = matchmod.intersectmatchers(m1, m2)
        self.assertEqual(im.visitchildrenset('.'), {'dir'})
        self.assertEqual(im.visitchildrenset('dir'), {'subdir'})
        self.assertEqual(im.visitchildrenset('dir/subdir'), 'all')
        self.assertEqual(im.visitchildrenset('dir/foo'), set())
        self.assertEqual(im.visitchildrenset('folder'), set())
        # OPT: We should probably return 'all' for these
        self.assertEqual(im.visitchildrenset('dir/subdir/z'), 'this')
        self.assertEqual(im.visitchildrenset('dir/subdir/x'), 'this')

    # We're using includematcher instead of patterns because it behaves slightly
    # better (giving narrower results) than patternmatcher.
    def testVisitdirIncludeIncludfe(self):
        m1 = matchmod.match('', '', include=['path:dir/subdir'])
        m2 = matchmod.match('', '', include=['rootfilesin:dir'])
        im = matchmod.intersectmatchers(m1, m2)
        self.assertEqual(im.visitdir('.'), True)
        self.assertEqual(im.visitdir('dir'), True)
        self.assertFalse(im.visitdir('dir/subdir'))
        self.assertFalse(im.visitdir('dir/foo'))
        self.assertFalse(im.visitdir('folder'))
        self.assertFalse(im.visitdir('dir/subdir/z'))
        self.assertFalse(im.visitdir('dir/subdir/x'))

    def testVisitchildrensetIncludeInclude(self):
        m1 = matchmod.match('', '', include=['path:dir/subdir'])
        m2 = matchmod.match('', '', include=['rootfilesin:dir'])
        im = matchmod.intersectmatchers(m1, m2)
        self.assertEqual(im.visitchildrenset('.'), {'dir'})
        self.assertEqual(im.visitchildrenset('dir'), 'this')
        self.assertEqual(im.visitchildrenset('dir/subdir'), set())
        self.assertEqual(im.visitchildrenset('dir/foo'), set())
        self.assertEqual(im.visitchildrenset('folder'), set())
        self.assertEqual(im.visitchildrenset('dir/subdir/z'), set())
        self.assertEqual(im.visitchildrenset('dir/subdir/x'), set())

    # We're using includematcher instead of patterns because it behaves slightly
    # better (giving narrower results) than patternmatcher.
    def testVisitdirIncludeInclude2(self):
        m1 = matchmod.match('', '', include=['path:dir/subdir'])
        m2 = matchmod.match('', '', include=['path:folder'])
        im = matchmod.intersectmatchers(m1, m2)
        # FIXME: is True correct here?
        self.assertEqual(im.visitdir('.'), True)
        self.assertFalse(im.visitdir('dir'))
        self.assertFalse(im.visitdir('dir/subdir'))
        self.assertFalse(im.visitdir('dir/foo'))
        self.assertFalse(im.visitdir('folder'))
        self.assertFalse(im.visitdir('dir/subdir/z'))
        self.assertFalse(im.visitdir('dir/subdir/x'))

    def testVisitchildrensetIncludeInclude2(self):
        m1 = matchmod.match('', '', include=['path:dir/subdir'])
        m2 = matchmod.match('', '', include=['path:folder'])
        im = matchmod.intersectmatchers(m1, m2)
        # FIXME: is set() correct here?
        self.assertEqual(im.visitchildrenset('.'), set())
        self.assertEqual(im.visitchildrenset('dir'), set())
        self.assertEqual(im.visitchildrenset('dir/subdir'), set())
        self.assertEqual(im.visitchildrenset('dir/foo'), set())
        self.assertEqual(im.visitchildrenset('folder'), set())
        self.assertEqual(im.visitchildrenset('dir/subdir/z'), set())
        self.assertEqual(im.visitchildrenset('dir/subdir/x'), set())

    # We're using includematcher instead of patterns because it behaves slightly
    # better (giving narrower results) than patternmatcher.
    def testVisitdirIncludeInclude3(self):
        m1 = matchmod.match('', '', include=['path:dir/subdir/x'])
        m2 = matchmod.match('', '', include=['path:dir/subdir'])
        im = matchmod.intersectmatchers(m1, m2)
        self.assertEqual(im.visitdir('.'), True)
        self.assertEqual(im.visitdir('dir'), True)
        self.assertEqual(im.visitdir('dir/subdir'), True)
        self.assertFalse(im.visitdir('dir/foo'))
        self.assertFalse(im.visitdir('folder'))
        self.assertFalse(im.visitdir('dir/subdir/z'))
        # OPT: this should probably be 'all' not True.
        self.assertEqual(im.visitdir('dir/subdir/x'), True)

    def testVisitchildrensetIncludeInclude3(self):
        m1 = matchmod.match('', '', include=['path:dir/subdir/x'])
        m2 = matchmod.match('', '', include=['path:dir/subdir'])
        im = matchmod.intersectmatchers(m1, m2)
        self.assertEqual(im.visitchildrenset('.'), {'dir'})
        self.assertEqual(im.visitchildrenset('dir'), {'subdir'})
        self.assertEqual(im.visitchildrenset('dir/subdir'), {'x'})
        self.assertEqual(im.visitchildrenset('dir/foo'), set())
        self.assertEqual(im.visitchildrenset('folder'), set())
        self.assertEqual(im.visitchildrenset('dir/subdir/z'), set())
        # OPT: this should probably be 'all' not 'this'.
        self.assertEqual(im.visitchildrenset('dir/subdir/x'), 'this')

    # We're using includematcher instead of patterns because it behaves slightly
    # better (giving narrower results) than patternmatcher.
    def testVisitdirIncludeInclude4(self):
        m1 = matchmod.match('', '', include=['path:dir/subdir/x'])
        m2 = matchmod.match('', '', include=['path:dir/subdir/z'])
        im = matchmod.intersectmatchers(m1, m2)
        # OPT: these next three could probably be False as well.
        self.assertEqual(im.visitdir('.'), True)
        self.assertEqual(im.visitdir('dir'), True)
        self.assertEqual(im.visitdir('dir/subdir'), True)
        self.assertFalse(im.visitdir('dir/foo'))
        self.assertFalse(im.visitdir('folder'))
        self.assertFalse(im.visitdir('dir/subdir/z'))
        self.assertFalse(im.visitdir('dir/subdir/x'))

    def testVisitchildrensetIncludeInclude4(self):
        m1 = matchmod.match('', '', include=['path:dir/subdir/x'])
        m2 = matchmod.match('', '', include=['path:dir/subdir/z'])
        im = matchmod.intersectmatchers(m1, m2)
        # OPT: these next two could probably be set() as well.
        self.assertEqual(im.visitchildrenset('.'), {'dir'})
        self.assertEqual(im.visitchildrenset('dir'), {'subdir'})
        self.assertEqual(im.visitchildrenset('dir/subdir'), set())
        self.assertEqual(im.visitchildrenset('dir/foo'), set())
        self.assertEqual(im.visitchildrenset('folder'), set())
        self.assertEqual(im.visitchildrenset('dir/subdir/z'), set())
        self.assertEqual(im.visitchildrenset('dir/subdir/x'), set())

class UnionMatcherTests(unittest.TestCase):

    def testVisitdirM2always(self):
        m1 = matchmod.alwaysmatcher('', '')
        m2 = matchmod.alwaysmatcher('', '')
        um = matchmod.unionmatcher([m1, m2])
        # um should be equivalent to a alwaysmatcher.
        self.assertEqual(um.visitdir('.'), 'all')
        self.assertEqual(um.visitdir('dir'), 'all')
        self.assertEqual(um.visitdir('dir/subdir'), 'all')
        self.assertEqual(um.visitdir('dir/subdir/z'), 'all')
        self.assertEqual(um.visitdir('dir/foo'), 'all')
        self.assertEqual(um.visitdir('dir/subdir/x'), 'all')
        self.assertEqual(um.visitdir('folder'), 'all')

    def testVisitchildrensetM2always(self):
        m1 = matchmod.alwaysmatcher('', '')
        m2 = matchmod.alwaysmatcher('', '')
        um = matchmod.unionmatcher([m1, m2])
        # um should be equivalent to a alwaysmatcher.
        self.assertEqual(um.visitchildrenset('.'), 'all')
        self.assertEqual(um.visitchildrenset('dir'), 'all')
        self.assertEqual(um.visitchildrenset('dir/subdir'), 'all')
        self.assertEqual(um.visitchildrenset('dir/subdir/z'), 'all')
        self.assertEqual(um.visitchildrenset('dir/foo'), 'all')
        self.assertEqual(um.visitchildrenset('dir/subdir/x'), 'all')
        self.assertEqual(um.visitchildrenset('folder'), 'all')

    def testVisitdirM1never(self):
        m1 = matchmod.nevermatcher('', '')
        m2 = matchmod.alwaysmatcher('', '')
        um = matchmod.unionmatcher([m1, m2])
        # um should be equivalent to a alwaysmatcher.
        self.assertEqual(um.visitdir('.'), 'all')
        self.assertEqual(um.visitdir('dir'), 'all')
        self.assertEqual(um.visitdir('dir/subdir'), 'all')
        self.assertEqual(um.visitdir('dir/subdir/z'), 'all')
        self.assertEqual(um.visitdir('dir/foo'), 'all')
        self.assertEqual(um.visitdir('dir/subdir/x'), 'all')
        self.assertEqual(um.visitdir('folder'), 'all')

    def testVisitchildrensetM1never(self):
        m1 = matchmod.nevermatcher('', '')
        m2 = matchmod.alwaysmatcher('', '')
        um = matchmod.unionmatcher([m1, m2])
        # um should be equivalent to a alwaysmatcher.
        self.assertEqual(um.visitchildrenset('.'), 'all')
        self.assertEqual(um.visitchildrenset('dir'), 'all')
        self.assertEqual(um.visitchildrenset('dir/subdir'), 'all')
        self.assertEqual(um.visitchildrenset('dir/subdir/z'), 'all')
        self.assertEqual(um.visitchildrenset('dir/foo'), 'all')
        self.assertEqual(um.visitchildrenset('dir/subdir/x'), 'all')
        self.assertEqual(um.visitchildrenset('folder'), 'all')

    def testVisitdirM2never(self):
        m1 = matchmod.alwaysmatcher('', '')
        m2 = matchmod.nevermatcher('', '')
        um = matchmod.unionmatcher([m1, m2])
        # um should be equivalent to a alwaysmatcher.
        self.assertEqual(um.visitdir('.'), 'all')
        self.assertEqual(um.visitdir('dir'), 'all')
        self.assertEqual(um.visitdir('dir/subdir'), 'all')
        self.assertEqual(um.visitdir('dir/subdir/z'), 'all')
        self.assertEqual(um.visitdir('dir/foo'), 'all')
        self.assertEqual(um.visitdir('dir/subdir/x'), 'all')
        self.assertEqual(um.visitdir('folder'), 'all')

    def testVisitchildrensetM2never(self):
        m1 = matchmod.alwaysmatcher('', '')
        m2 = matchmod.nevermatcher('', '')
        um = matchmod.unionmatcher([m1, m2])
        # um should be equivalent to a alwaysmatcher.
        self.assertEqual(um.visitchildrenset('.'), 'all')
        self.assertEqual(um.visitchildrenset('dir'), 'all')
        self.assertEqual(um.visitchildrenset('dir/subdir'), 'all')
        self.assertEqual(um.visitchildrenset('dir/subdir/z'), 'all')
        self.assertEqual(um.visitchildrenset('dir/foo'), 'all')
        self.assertEqual(um.visitchildrenset('dir/subdir/x'), 'all')
        self.assertEqual(um.visitchildrenset('folder'), 'all')

    def testVisitdirM2SubdirPrefix(self):
        m1 = matchmod.alwaysmatcher('', '')
        m2 = matchmod.match('', '', patterns=['path:dir/subdir'])
        um = matchmod.unionmatcher([m1, m2])
        self.assertEqual(um.visitdir('.'), 'all')
        self.assertEqual(um.visitdir('dir'), 'all')
        self.assertEqual(um.visitdir('dir/subdir'), 'all')
        self.assertEqual(um.visitdir('dir/foo'), 'all')
        self.assertEqual(um.visitdir('folder'), 'all')
        self.assertEqual(um.visitdir('dir/subdir/z'), 'all')
        self.assertEqual(um.visitdir('dir/subdir/x'), 'all')

    def testVisitchildrensetM2SubdirPrefix(self):
        m1 = matchmod.alwaysmatcher('', '')
        m2 = matchmod.match('', '', include=['path:dir/subdir'])
        um = matchmod.unionmatcher([m1, m2])
        self.assertEqual(um.visitchildrenset('.'), 'all')
        self.assertEqual(um.visitchildrenset('dir'), 'all')
        self.assertEqual(um.visitchildrenset('dir/subdir'), 'all')
        self.assertEqual(um.visitchildrenset('dir/foo'), 'all')
        self.assertEqual(um.visitchildrenset('folder'), 'all')
        self.assertEqual(um.visitchildrenset('dir/subdir/z'), 'all')
        self.assertEqual(um.visitchildrenset('dir/subdir/x'), 'all')

    # We're using includematcher instead of patterns because it behaves slightly
    # better (giving narrower results) than patternmatcher.
    def testVisitdirIncludeIncludfe(self):
        m1 = matchmod.match('', '', include=['path:dir/subdir'])
        m2 = matchmod.match('', '', include=['rootfilesin:dir'])
        um = matchmod.unionmatcher([m1, m2])
        self.assertEqual(um.visitdir('.'), True)
        self.assertEqual(um.visitdir('dir'), True)
        self.assertEqual(um.visitdir('dir/subdir'), 'all')
        self.assertFalse(um.visitdir('dir/foo'))
        self.assertFalse(um.visitdir('folder'))
        # OPT: These two should probably be 'all' not True.
        self.assertEqual(um.visitdir('dir/subdir/z'), True)
        self.assertEqual(um.visitdir('dir/subdir/x'), True)

    def testVisitchildrensetIncludeInclude(self):
        m1 = matchmod.match('', '', include=['path:dir/subdir'])
        m2 = matchmod.match('', '', include=['rootfilesin:dir'])
        um = matchmod.unionmatcher([m1, m2])
        self.assertEqual(um.visitchildrenset('.'), {'dir'})
        self.assertEqual(um.visitchildrenset('dir'), 'this')
        self.assertEqual(um.visitchildrenset('dir/subdir'), 'all')
        self.assertEqual(um.visitchildrenset('dir/foo'), set())
        self.assertEqual(um.visitchildrenset('folder'), set())
        # OPT: These next two could be 'all' instead of 'this'.
        self.assertEqual(um.visitchildrenset('dir/subdir/z'), 'this')
        self.assertEqual(um.visitchildrenset('dir/subdir/x'), 'this')

    # We're using includematcher instead of patterns because it behaves slightly
    # better (giving narrower results) than patternmatcher.
    def testVisitdirIncludeInclude2(self):
        m1 = matchmod.match('', '', include=['path:dir/subdir'])
        m2 = matchmod.match('', '', include=['path:folder'])
        um = matchmod.unionmatcher([m1, m2])
        self.assertEqual(um.visitdir('.'), True)
        self.assertEqual(um.visitdir('dir'), True)
        self.assertEqual(um.visitdir('dir/subdir'), 'all')
        self.assertFalse(um.visitdir('dir/foo'))
        self.assertEqual(um.visitdir('folder'), 'all')
        # OPT: These should probably be 'all' not True.
        self.assertEqual(um.visitdir('dir/subdir/z'), True)
        self.assertEqual(um.visitdir('dir/subdir/x'), True)

    def testVisitchildrensetIncludeInclude2(self):
        m1 = matchmod.match('', '', include=['path:dir/subdir'])
        m2 = matchmod.match('', '', include=['path:folder'])
        um = matchmod.unionmatcher([m1, m2])
        self.assertEqual(um.visitchildrenset('.'), {'folder', 'dir'})
        self.assertEqual(um.visitchildrenset('dir'), {'subdir'})
        self.assertEqual(um.visitchildrenset('dir/subdir'), 'all')
        self.assertEqual(um.visitchildrenset('dir/foo'), set())
        self.assertEqual(um.visitchildrenset('folder'), 'all')
        # OPT: These next two could be 'all' instead of 'this'.
        self.assertEqual(um.visitchildrenset('dir/subdir/z'), 'this')
        self.assertEqual(um.visitchildrenset('dir/subdir/x'), 'this')

    # We're using includematcher instead of patterns because it behaves slightly
    # better (giving narrower results) than patternmatcher.
    def testVisitdirIncludeInclude3(self):
        m1 = matchmod.match('', '', include=['path:dir/subdir/x'])
        m2 = matchmod.match('', '', include=['path:dir/subdir'])
        um = matchmod.unionmatcher([m1, m2])
        self.assertEqual(um.visitdir('.'), True)
        self.assertEqual(um.visitdir('dir'), True)
        self.assertEqual(um.visitdir('dir/subdir'), 'all')
        self.assertFalse(um.visitdir('dir/foo'))
        self.assertFalse(um.visitdir('folder'))
        self.assertEqual(um.visitdir('dir/subdir/x'), 'all')
        # OPT: this should probably be 'all' not True.
        self.assertEqual(um.visitdir('dir/subdir/z'), True)

    def testVisitchildrensetIncludeInclude3(self):
        m1 = matchmod.match('', '', include=['path:dir/subdir/x'])
        m2 = matchmod.match('', '', include=['path:dir/subdir'])
        um = matchmod.unionmatcher([m1, m2])
        self.assertEqual(um.visitchildrenset('.'), {'dir'})
        self.assertEqual(um.visitchildrenset('dir'), {'subdir'})
        self.assertEqual(um.visitchildrenset('dir/subdir'), 'all')
        self.assertEqual(um.visitchildrenset('dir/foo'), set())
        self.assertEqual(um.visitchildrenset('folder'), set())
        self.assertEqual(um.visitchildrenset('dir/subdir/x'), 'all')
        # OPT: this should probably be 'all' not 'this'.
        self.assertEqual(um.visitchildrenset('dir/subdir/z'), 'this')

    # We're using includematcher instead of patterns because it behaves slightly
    # better (giving narrower results) than patternmatcher.
    def testVisitdirIncludeInclude4(self):
        m1 = matchmod.match('', '', include=['path:dir/subdir/x'])
        m2 = matchmod.match('', '', include=['path:dir/subdir/z'])
        um = matchmod.unionmatcher([m1, m2])
        # OPT: these next three could probably be False as well.
        self.assertEqual(um.visitdir('.'), True)
        self.assertEqual(um.visitdir('dir'), True)
        self.assertEqual(um.visitdir('dir/subdir'), True)
        self.assertFalse(um.visitdir('dir/foo'))
        self.assertFalse(um.visitdir('folder'))
        self.assertEqual(um.visitdir('dir/subdir/z'), 'all')
        self.assertEqual(um.visitdir('dir/subdir/x'), 'all')

    def testVisitchildrensetIncludeInclude4(self):
        m1 = matchmod.match('', '', include=['path:dir/subdir/x'])
        m2 = matchmod.match('', '', include=['path:dir/subdir/z'])
        um = matchmod.unionmatcher([m1, m2])
        self.assertEqual(um.visitchildrenset('.'), {'dir'})
        self.assertEqual(um.visitchildrenset('dir'), {'subdir'})
        self.assertEqual(um.visitchildrenset('dir/subdir'), {'x', 'z'})
        self.assertEqual(um.visitchildrenset('dir/foo'), set())
        self.assertEqual(um.visitchildrenset('folder'), set())
        self.assertEqual(um.visitchildrenset('dir/subdir/z'), 'all')
        self.assertEqual(um.visitchildrenset('dir/subdir/x'), 'all')

class SubdirMatcherTests(unittest.TestCase):

    def testVisitdir(self):
        m = matchmod.match('', '', include=['path:dir/subdir'])
        sm = matchmod.subdirmatcher('dir', m)

        self.assertEqual(sm.visitdir('.'), True)
        self.assertEqual(sm.visitdir('subdir'), 'all')
        # OPT: These next two should probably be 'all' not True.
        self.assertEqual(sm.visitdir('subdir/x'), True)
        self.assertEqual(sm.visitdir('subdir/z'), True)
        self.assertFalse(sm.visitdir('foo'))

    def testVisitchildrenset(self):
        m = matchmod.match('', '', include=['path:dir/subdir'])
        sm = matchmod.subdirmatcher('dir', m)

        self.assertEqual(sm.visitchildrenset('.'), {'subdir'})
        self.assertEqual(sm.visitchildrenset('subdir'), 'all')
        # OPT: These next two should probably be 'all' not 'this'.
        self.assertEqual(sm.visitchildrenset('subdir/x'), 'this')
        self.assertEqual(sm.visitchildrenset('subdir/z'), 'this')
        self.assertEqual(sm.visitchildrenset('foo'), set())

class PrefixdirMatcherTests(unittest.TestCase):

    def testVisitdir(self):
        m = matchmod.match(util.localpath('root/d'), 'e/f',
                ['../a.txt', 'b.txt'])
        pm = matchmod.prefixdirmatcher('root', 'd/e/f', 'd', m)

        # `m` elides 'd' because it's part of the root, and the rest of the
        # patterns are relative.
        self.assertEqual(bool(m('a.txt')), False)
        self.assertEqual(bool(m('b.txt')), False)
        self.assertEqual(bool(m('e/a.txt')), True)
        self.assertEqual(bool(m('e/b.txt')), False)
        self.assertEqual(bool(m('e/f/b.txt')), True)

        # The prefix matcher re-adds 'd' to the paths, so they need to be
        # specified when using the prefixdirmatcher.
        self.assertEqual(bool(pm('a.txt')), False)
        self.assertEqual(bool(pm('b.txt')), False)
        self.assertEqual(bool(pm('d/e/a.txt')), True)
        self.assertEqual(bool(pm('d/e/b.txt')), False)
        self.assertEqual(bool(pm('d/e/f/b.txt')), True)

        self.assertEqual(m.visitdir('.'), True)
        self.assertEqual(m.visitdir('e'), True)
        self.assertEqual(m.visitdir('e/f'), True)
        self.assertEqual(m.visitdir('e/f/g'), False)

        self.assertEqual(pm.visitdir('.'), True)
        self.assertEqual(pm.visitdir('d'), True)
        self.assertEqual(pm.visitdir('d/e'), True)
        self.assertEqual(pm.visitdir('d/e/f'), True)
        self.assertEqual(pm.visitdir('d/e/f/g'), False)

    def testVisitchildrenset(self):
        m = matchmod.match(util.localpath('root/d'), 'e/f',
                ['../a.txt', 'b.txt'])
        pm = matchmod.prefixdirmatcher('root', 'd/e/f', 'd', m)

        # OPT: visitchildrenset could possibly return {'e'} and {'f'} for these
        # next two, respectively; patternmatcher does not have this
        # optimization.
        self.assertEqual(m.visitchildrenset('.'), 'this')
        self.assertEqual(m.visitchildrenset('e'), 'this')
        self.assertEqual(m.visitchildrenset('e/f'), 'this')
        self.assertEqual(m.visitchildrenset('e/f/g'), set())

        # OPT: visitchildrenset could possibly return {'d'}, {'e'}, and {'f'}
        # for these next three, respectively; patternmatcher does not have this
        # optimization.
        self.assertEqual(pm.visitchildrenset('.'), 'this')
        self.assertEqual(pm.visitchildrenset('d'), 'this')
        self.assertEqual(pm.visitchildrenset('d/e'), 'this')
        self.assertEqual(pm.visitchildrenset('d/e/f'), 'this')
        self.assertEqual(pm.visitchildrenset('d/e/f/g'), set())

if __name__ == '__main__':
    silenttestrunner.main(__name__)
