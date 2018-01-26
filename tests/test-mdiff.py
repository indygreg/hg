from __future__ import absolute_import
from __future__ import print_function

import unittest

from mercurial import (
    mdiff,
)

class splitnewlinesTests(unittest.TestCase):

    def test_splitnewlines(self):
        cases = {'a\nb\nc\n': ['a\n', 'b\n', 'c\n'],
                 'a\nb\nc': ['a\n', 'b\n', 'c'],
                 'a\nb\nc\n\n': ['a\n', 'b\n', 'c\n', '\n'],
                 '': [],
                 'abcabc': ['abcabc'],
                 }
        for inp, want in cases.iteritems():
            self.assertEqual(mdiff.splitnewlines(inp), want)

if __name__ == '__main__':
    import silenttestrunner
    silenttestrunner.main(__name__)
