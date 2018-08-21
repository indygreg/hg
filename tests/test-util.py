# unit tests for mercuril.util utilities
from __future__ import absolute_import

import contextlib
import itertools
import unittest

from mercurial import pycompat, util, utils

@contextlib.contextmanager
def mocktimer(incr=0.1, *additional_targets):
    """Replaces util.timer and additional_targets with a mock

    The timer starts at 0. On each call the time incremented by the value
    of incr. If incr is an iterable, then the time is incremented by the
    next value from that iterable, looping in a cycle when reaching the end.

    additional_targets must be a sequence of (object, attribute_name) tuples;
    the mock is set with setattr(object, attribute_name, mock).

    """
    time = [0]
    try:
        incr = itertools.cycle(incr)
    except TypeError:
        incr = itertools.repeat(incr)

    def timer():
        time[0] += next(incr)
        return time[0]

    # record original values
    orig = util.timer
    additional_origs = [(o, a, getattr(o, a)) for o, a in additional_targets]

    # mock out targets
    util.timer = timer
    for obj, attr in additional_targets:
        setattr(obj, attr, timer)

    try:
        yield
    finally:
        # restore originals
        util.timer = orig
        for args in additional_origs:
            setattr(*args)

# attr.s default factory for util.timedstats.start binds the timer we
# need to mock out.
_start_default = (util.timedcmstats.start.default, 'factory')

@contextlib.contextmanager
def capturestderr():
    """Replace utils.procutil.stderr with a pycompat.bytesio instance

    The instance is made available as the return value of __enter__.

    This contextmanager is reentrant.

    """
    orig = utils.procutil.stderr
    utils.procutil.stderr = pycompat.bytesio()
    try:
        yield utils.procutil.stderr
    finally:
        utils.procutil.stderr = orig

class timedtests(unittest.TestCase):
    def testtimedcmstatsstr(self):
        stats = util.timedcmstats()
        self.assertEqual(str(stats), '<unknown>')
        self.assertEqual(bytes(stats), b'<unknown>')
        stats.elapsed = 12.34
        self.assertEqual(str(stats), pycompat.sysstr(util.timecount(12.34)))
        self.assertEqual(bytes(stats), util.timecount(12.34))

    def testtimedcmcleanexit(self):
        # timestamps 1, 4, elapsed time of 4 - 1 = 3
        with mocktimer([1, 3], _start_default):
            with util.timedcm('pass') as stats:
                # actual context doesn't matter
                pass

        self.assertEqual(stats.start, 1)
        self.assertEqual(stats.elapsed, 3)
        self.assertEqual(stats.level, 1)

    def testtimedcmnested(self):
        # timestamps 1, 3, 6, 10, elapsed times of 6 - 3 = 3 and 10 - 1 = 9
        with mocktimer([1, 2, 3, 4], _start_default):
            with util.timedcm('outer') as outer_stats:
                with util.timedcm('inner') as inner_stats:
                    # actual context doesn't matter
                    pass

        self.assertEqual(outer_stats.start, 1)
        self.assertEqual(outer_stats.elapsed, 9)
        self.assertEqual(outer_stats.level, 1)

        self.assertEqual(inner_stats.start, 3)
        self.assertEqual(inner_stats.elapsed, 3)
        self.assertEqual(inner_stats.level, 2)

    def testtimedcmexception(self):
        # timestamps 1, 4, elapsed time of 4 - 1 = 3
        with mocktimer([1, 3], _start_default):
            try:
                with util.timedcm('exceptional') as stats:
                    raise ValueError()
            except ValueError:
                pass

        self.assertEqual(stats.start, 1)
        self.assertEqual(stats.elapsed, 3)
        self.assertEqual(stats.level, 1)

    def testtimeddecorator(self):
        @util.timed
        def testfunc(callcount=1):
            callcount -= 1
            if callcount:
                testfunc(callcount)

        # timestamps 1, 2, 3, 4, elapsed time of 3 - 2 = 1 and 4 - 1 = 3
        with mocktimer(1, _start_default):
            with capturestderr() as out:
                testfunc(2)

        self.assertEqual(out.getvalue(), (
            b'    testfunc: 1.000 s\n'
            b'  testfunc: 3.000 s\n'
        ))

if __name__ == '__main__':
    import silenttestrunner
    silenttestrunner.main(__name__)
