from __future__ import absolute_import
from __future__ import print_function

import unittest

from mercurial import (
    mdiff,
)

class splitnewlinesTests(unittest.TestCase):

    def test_splitnewlines(self):
        cases = {b'a\nb\nc\n': [b'a\n', b'b\n', b'c\n'],
                 b'a\nb\nc': [b'a\n', b'b\n', b'c'],
                 b'a\nb\nc\n\n': [b'a\n', b'b\n', b'c\n', b'\n'],
                 b'': [],
                 b'abcabc': [b'abcabc'],
                 }
        for inp, want in cases.items():
            self.assertEqual(mdiff.splitnewlines(inp), want)

if __name__ == '__main__':
    import silenttestrunner
    silenttestrunner.main(__name__)
