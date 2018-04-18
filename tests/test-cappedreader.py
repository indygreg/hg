from __future__ import absolute_import, print_function

import io
import unittest

from mercurial import (
    util,
)

class CappedReaderTests(unittest.TestCase):
    def testreadfull(self):
        source = io.BytesIO(b'x' * 100)

        reader = util.cappedreader(source, 10)
        res = reader.read(10)
        self.assertEqual(res, b'x' * 10)
        self.assertEqual(source.tell(), 10)
        source.seek(0)

        reader = util.cappedreader(source, 15)
        res = reader.read(16)
        self.assertEqual(res, b'x' * 15)
        self.assertEqual(source.tell(), 15)
        source.seek(0)

        reader = util.cappedreader(source, 100)
        res = reader.read(100)
        self.assertEqual(res, b'x' * 100)
        self.assertEqual(source.tell(), 100)
        source.seek(0)

        reader = util.cappedreader(source, 50)
        res = reader.read()
        self.assertEqual(res, b'x' * 50)
        self.assertEqual(source.tell(), 50)
        source.seek(0)

    def testreadnegative(self):
        source = io.BytesIO(b'x' * 100)

        reader = util.cappedreader(source, 20)
        res = reader.read(-1)
        self.assertEqual(res, b'x' * 20)
        self.assertEqual(source.tell(), 20)
        source.seek(0)

        reader = util.cappedreader(source, 100)
        res = reader.read(-1)
        self.assertEqual(res, b'x' * 100)
        self.assertEqual(source.tell(), 100)
        source.seek(0)

    def testreadmultiple(self):
        source = io.BytesIO(b'x' * 100)

        reader = util.cappedreader(source, 10)
        for i in range(10):
            res = reader.read(1)
            self.assertEqual(res, b'x')
            self.assertEqual(source.tell(), i + 1)

        self.assertEqual(source.tell(), 10)
        res = reader.read(1)
        self.assertEqual(res, b'')
        self.assertEqual(source.tell(), 10)
        source.seek(0)

        reader = util.cappedreader(source, 45)
        for i in range(4):
            res = reader.read(10)
            self.assertEqual(res, b'x' * 10)
            self.assertEqual(source.tell(), (i + 1) * 10)

        res = reader.read(10)
        self.assertEqual(res, b'x' * 5)
        self.assertEqual(source.tell(), 45)

    def readlimitpasteof(self):
        source = io.BytesIO(b'x' * 100)

        reader = util.cappedreader(source, 1024)
        res = reader.read(1000)
        self.assertEqual(res, b'x' * 100)
        self.assertEqual(source.tell(), 100)
        res = reader.read(1000)
        self.assertEqual(res, b'')
        self.assertEqual(source.tell(), 100)

if __name__ == '__main__':
    import silenttestrunner
    silenttestrunner.main(__name__)
