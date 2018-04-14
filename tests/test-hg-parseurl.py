from __future__ import absolute_import, print_function

import unittest

from mercurial import (
    hg,
)

class ParseRequestTests(unittest.TestCase):
    def testparse(self):

        self.assertEqual(hg.parseurl('http://example.com/no/anchor'),
                         ('http://example.com/no/anchor', (None, [])))
        self.assertEqual(hg.parseurl('http://example.com/an/anchor#foo'),
                         ('http://example.com/an/anchor', ('foo', [])))
        self.assertEqual(
            hg.parseurl('http://example.com/no/anchor/branches', ['foo']),
            ('http://example.com/no/anchor/branches', (None, ['foo'])))
        self.assertEqual(
            hg.parseurl('http://example.com/an/anchor/branches#bar', ['foo']),
            ('http://example.com/an/anchor/branches', ('bar', ['foo'])))
        self.assertEqual(hg.parseurl(
            'http://example.com/an/anchor/branches-None#foo', None),
            ('http://example.com/an/anchor/branches-None', ('foo', [])))
        self.assertEqual(hg.parseurl('http://example.com/'),
                         ('http://example.com/', (None, [])))
        self.assertEqual(hg.parseurl('http://example.com'),
                         ('http://example.com/', (None, [])))
        self.assertEqual(hg.parseurl('http://example.com#foo'),
                         ('http://example.com/', ('foo', [])))

if __name__ == '__main__':
    import silenttestrunner
    silenttestrunner.main(__name__)
