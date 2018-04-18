from __future__ import absolute_import

import io
import unittest

from mercurial.thirdparty import (
    cbor,
)
from mercurial.utils import (
    cborutil,
)

def loadit(it):
    return cbor.loads(b''.join(it))

class BytestringTests(unittest.TestCase):
    def testsimple(self):
        self.assertEqual(
            list(cborutil.streamencode(b'foobar')),
            [b'\x46', b'foobar'])

        self.assertEqual(
            loadit(cborutil.streamencode(b'foobar')),
            b'foobar')

    def testlong(self):
        source = b'x' * 1048576

        self.assertEqual(loadit(cborutil.streamencode(source)), source)

    def testfromiter(self):
        # This is the example from RFC 7049 Section 2.2.2.
        source = [b'\xaa\xbb\xcc\xdd', b'\xee\xff\x99']

        self.assertEqual(
            list(cborutil.streamencodebytestringfromiter(source)),
            [
                b'\x5f',
                b'\x44',
                b'\xaa\xbb\xcc\xdd',
                b'\x43',
                b'\xee\xff\x99',
                b'\xff',
            ])

        self.assertEqual(
            loadit(cborutil.streamencodebytestringfromiter(source)),
            b''.join(source))

    def testfromiterlarge(self):
        source = [b'a' * 16, b'b' * 128, b'c' * 1024, b'd' * 1048576]

        self.assertEqual(
            loadit(cborutil.streamencodebytestringfromiter(source)),
            b''.join(source))

    def testindefinite(self):
        source = b'\x00\x01\x02\x03' + b'\xff' * 16384

        it = cborutil.streamencodeindefinitebytestring(source, chunksize=2)

        self.assertEqual(next(it), b'\x5f')
        self.assertEqual(next(it), b'\x42')
        self.assertEqual(next(it), b'\x00\x01')
        self.assertEqual(next(it), b'\x42')
        self.assertEqual(next(it), b'\x02\x03')
        self.assertEqual(next(it), b'\x42')
        self.assertEqual(next(it), b'\xff\xff')

        dest = b''.join(cborutil.streamencodeindefinitebytestring(
            source, chunksize=42))
        self.assertEqual(cbor.loads(dest), b''.join(source))

    def testreadtoiter(self):
        source = io.BytesIO(b'\x5f\x44\xaa\xbb\xcc\xdd\x43\xee\xff\x99\xff')

        it = cborutil.readindefinitebytestringtoiter(source)
        self.assertEqual(next(it), b'\xaa\xbb\xcc\xdd')
        self.assertEqual(next(it), b'\xee\xff\x99')

        with self.assertRaises(StopIteration):
            next(it)

class IntTests(unittest.TestCase):
    def testsmall(self):
        self.assertEqual(list(cborutil.streamencode(0)), [b'\x00'])
        self.assertEqual(list(cborutil.streamencode(1)), [b'\x01'])
        self.assertEqual(list(cborutil.streamencode(2)), [b'\x02'])
        self.assertEqual(list(cborutil.streamencode(3)), [b'\x03'])
        self.assertEqual(list(cborutil.streamencode(4)), [b'\x04'])

    def testnegativesmall(self):
        self.assertEqual(list(cborutil.streamencode(-1)), [b'\x20'])
        self.assertEqual(list(cborutil.streamencode(-2)), [b'\x21'])
        self.assertEqual(list(cborutil.streamencode(-3)), [b'\x22'])
        self.assertEqual(list(cborutil.streamencode(-4)), [b'\x23'])
        self.assertEqual(list(cborutil.streamencode(-5)), [b'\x24'])

    def testrange(self):
        for i in range(-70000, 70000, 10):
            self.assertEqual(
                b''.join(cborutil.streamencode(i)),
                cbor.dumps(i))

class ArrayTests(unittest.TestCase):
    def testempty(self):
        self.assertEqual(list(cborutil.streamencode([])), [b'\x80'])
        self.assertEqual(loadit(cborutil.streamencode([])), [])

    def testbasic(self):
        source = [b'foo', b'bar', 1, -10]

        self.assertEqual(list(cborutil.streamencode(source)), [
            b'\x84', b'\x43', b'foo', b'\x43', b'bar', b'\x01', b'\x29'])

    def testemptyfromiter(self):
        self.assertEqual(b''.join(cborutil.streamencodearrayfromiter([])),
                         b'\x9f\xff')

    def testfromiter1(self):
        source = [b'foo']

        self.assertEqual(list(cborutil.streamencodearrayfromiter(source)), [
            b'\x9f',
            b'\x43', b'foo',
            b'\xff',
        ])

        dest = b''.join(cborutil.streamencodearrayfromiter(source))
        self.assertEqual(cbor.loads(dest), source)

    def testtuple(self):
        source = (b'foo', None, 42)

        self.assertEqual(cbor.loads(b''.join(cborutil.streamencode(source))),
                         list(source))

class SetTests(unittest.TestCase):
    def testempty(self):
        self.assertEqual(list(cborutil.streamencode(set())), [
            b'\xd9\x01\x02',
            b'\x80',
        ])

    def testset(self):
        source = {b'foo', None, 42}

        self.assertEqual(cbor.loads(b''.join(cborutil.streamencode(source))),
                         source)

class BoolTests(unittest.TestCase):
    def testbasic(self):
        self.assertEqual(list(cborutil.streamencode(True)),  [b'\xf5'])
        self.assertEqual(list(cborutil.streamencode(False)), [b'\xf4'])

        self.assertIs(loadit(cborutil.streamencode(True)), True)
        self.assertIs(loadit(cborutil.streamencode(False)), False)

class NoneTests(unittest.TestCase):
    def testbasic(self):
        self.assertEqual(list(cborutil.streamencode(None)), [b'\xf6'])

        self.assertIs(loadit(cborutil.streamencode(None)), None)

class MapTests(unittest.TestCase):
    def testempty(self):
        self.assertEqual(list(cborutil.streamencode({})), [b'\xa0'])
        self.assertEqual(loadit(cborutil.streamencode({})), {})

    def testemptyindefinite(self):
        self.assertEqual(list(cborutil.streamencodemapfromiter([])), [
            b'\xbf', b'\xff'])

        self.assertEqual(loadit(cborutil.streamencodemapfromiter([])), {})

    def testone(self):
        source = {b'foo': b'bar'}
        self.assertEqual(list(cborutil.streamencode(source)), [
            b'\xa1', b'\x43', b'foo', b'\x43', b'bar'])

        self.assertEqual(loadit(cborutil.streamencode(source)), source)

    def testmultiple(self):
        source = {
            b'foo': b'bar',
            b'baz': b'value1',
        }

        self.assertEqual(loadit(cborutil.streamencode(source)), source)

        self.assertEqual(
            loadit(cborutil.streamencodemapfromiter(source.items())),
            source)

    def testcomplex(self):
        source = {
            b'key': 1,
            2: -10,
        }

        self.assertEqual(loadit(cborutil.streamencode(source)),
                         source)

        self.assertEqual(
            loadit(cborutil.streamencodemapfromiter(source.items())),
            source)

if __name__ == '__main__':
    import silenttestrunner
    silenttestrunner.main(__name__)
