from __future__ import absolute_import

import unittest

from mercurial import (
    encoding,
)

class IsasciistrTest(unittest.TestCase):
    asciistrs = [
        b'a',
        b'ab',
        b'abc',
        b'abcd',
        b'abcde',
        b'abcdefghi',
        b'abcd\0fghi',
    ]

    def testascii(self):
        for s in self.asciistrs:
            self.assertTrue(encoding.isasciistr(s))

    def testnonasciichar(self):
        for s in self.asciistrs:
            for i in range(len(s)):
                t = bytearray(s)
                t[i] |= 0x80
                self.assertFalse(encoding.isasciistr(bytes(t)))

class LocalEncodingTest(unittest.TestCase):
    def testasciifastpath(self):
        s = b'\0' * 100
        self.assertTrue(s is encoding.tolocal(s))
        self.assertTrue(s is encoding.fromlocal(s))

class Utf8bEncodingTest(unittest.TestCase):
    def setUp(self):
        self.origencoding = encoding.encoding

    def tearDown(self):
        encoding.encoding = self.origencoding

    def testasciifastpath(self):
        s = b'\0' * 100
        self.assertTrue(s is encoding.toutf8b(s))
        self.assertTrue(s is encoding.fromutf8b(s))

    def testlossylatin(self):
        encoding.encoding = b'ascii'
        s = u'\xc0'.encode('utf-8')
        l = encoding.tolocal(s)
        self.assertEqual(l, b'?')  # lossy
        self.assertEqual(s, encoding.toutf8b(l))  # utf8 sequence preserved

    def testlosslesslatin(self):
        encoding.encoding = b'latin-1'
        s = u'\xc0'.encode('utf-8')
        l = encoding.tolocal(s)
        self.assertEqual(l, b'\xc0')  # lossless
        self.assertEqual(s, encoding.toutf8b(l))  # convert back to utf-8

    def testlossy0xed(self):
        encoding.encoding = b'euc-kr'  # U+Dxxx Hangul
        s = u'\ud1bc\xc0'.encode('utf-8')
        l = encoding.tolocal(s)
        self.assertIn(b'\xed', l)
        self.assertTrue(l.endswith(b'?'))  # lossy
        self.assertEqual(s, encoding.toutf8b(l))  # utf8 sequence preserved

    def testlossless0xed(self):
        encoding.encoding = b'euc-kr'  # U+Dxxx Hangul
        s = u'\ud1bc'.encode('utf-8')
        l = encoding.tolocal(s)
        self.assertEqual(l, b'\xc5\xed')  # lossless
        self.assertEqual(s, encoding.toutf8b(l))  # convert back to utf-8

if __name__ == '__main__':
    import silenttestrunner
    silenttestrunner.main(__name__)
