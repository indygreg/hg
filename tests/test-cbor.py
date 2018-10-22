from __future__ import absolute_import

import unittest

from mercurial.thirdparty import (
    cbor,
)
from mercurial.utils import (
    cborutil,
)

class TestCase(unittest.TestCase):
    if not getattr(unittest.TestCase, 'assertRaisesRegex', False):
        # Python 3.7 deprecates the regex*p* version, but 2.7 lacks
        # the regex version.
        assertRaisesRegex = (# camelcase-required
            unittest.TestCase.assertRaisesRegexp)

def loadit(it):
    return cbor.loads(b''.join(it))

class BytestringTests(TestCase):
    def testsimple(self):
        self.assertEqual(
            list(cborutil.streamencode(b'foobar')),
            [b'\x46', b'foobar'])

        self.assertEqual(
            loadit(cborutil.streamencode(b'foobar')),
            b'foobar')

        self.assertEqual(cborutil.decodeall(b'\x46foobar'),
                         [b'foobar'])

        self.assertEqual(cborutil.decodeall(b'\x46foobar\x45fizbi'),
                         [b'foobar', b'fizbi'])

    def testlong(self):
        source = b'x' * 1048576

        self.assertEqual(loadit(cborutil.streamencode(source)), source)

        encoded = b''.join(cborutil.streamencode(source))
        self.assertEqual(cborutil.decodeall(encoded), [source])

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

        self.assertEqual(cborutil.decodeall(b'\x5f\x44\xaa\xbb\xcc\xdd'
                                            b'\x43\xee\xff\x99\xff'),
                         [b'\xaa\xbb\xcc\xdd', b'\xee\xff\x99', b''])

        for i, chunk in enumerate(
            cborutil.decodeall(b'\x5f\x44\xaa\xbb\xcc\xdd'
                               b'\x43\xee\xff\x99\xff')):
            self.assertIsInstance(chunk, cborutil.bytestringchunk)

            if i == 0:
                self.assertTrue(chunk.isfirst)
            else:
                self.assertFalse(chunk.isfirst)

            if i == 2:
                self.assertTrue(chunk.islast)
            else:
                self.assertFalse(chunk.islast)

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
        self.assertEqual(cbor.loads(dest), source)

        self.assertEqual(b''.join(cborutil.decodeall(dest)), source)

        for chunk in cborutil.decodeall(dest):
            self.assertIsInstance(chunk, cborutil.bytestringchunk)
            self.assertIn(len(chunk), (0, 8, 42))

        encoded = b'\x5f\xff'
        b = cborutil.decodeall(encoded)
        self.assertEqual(b, [b''])
        self.assertTrue(b[0].isfirst)
        self.assertTrue(b[0].islast)

    def testdecodevariouslengths(self):
        for i in (0, 1, 22, 23, 24, 25, 254, 255, 256, 65534, 65535, 65536):
            source = b'x' * i
            encoded = b''.join(cborutil.streamencode(source))

            if len(source) < 24:
                hlen = 1
            elif len(source) < 256:
                hlen = 2
            elif len(source) < 65536:
                hlen = 3
            elif len(source) < 1048576:
                hlen = 5

            self.assertEqual(cborutil.decodeitem(encoded),
                             (True, source, hlen + len(source),
                              cborutil.SPECIAL_NONE))

    def testpartialdecode(self):
        encoded = b''.join(cborutil.streamencode(b'foobar'))

        self.assertEqual(cborutil.decodeitem(encoded[0:1]),
                         (False, None, -6, cborutil.SPECIAL_NONE))
        self.assertEqual(cborutil.decodeitem(encoded[0:2]),
                         (False, None, -5, cborutil.SPECIAL_NONE))
        self.assertEqual(cborutil.decodeitem(encoded[0:3]),
                         (False, None, -4, cborutil.SPECIAL_NONE))
        self.assertEqual(cborutil.decodeitem(encoded[0:4]),
                         (False, None, -3, cborutil.SPECIAL_NONE))
        self.assertEqual(cborutil.decodeitem(encoded[0:5]),
                         (False, None, -2, cborutil.SPECIAL_NONE))
        self.assertEqual(cborutil.decodeitem(encoded[0:6]),
                         (False, None, -1, cborutil.SPECIAL_NONE))
        self.assertEqual(cborutil.decodeitem(encoded[0:7]),
                         (True, b'foobar', 7, cborutil.SPECIAL_NONE))

    def testpartialdecodevariouslengths(self):
        lens = [
            2,
            3,
            10,
            23,
            24,
            25,
            31,
            100,
            254,
            255,
            256,
            257,
            16384,
            65534,
            65535,
            65536,
            65537,
            131071,
            131072,
            131073,
            1048575,
            1048576,
            1048577,
        ]

        for size in lens:
            if size < 24:
                hlen = 1
            elif size < 2**8:
                hlen = 2
            elif size < 2**16:
                hlen = 3
            elif size < 2**32:
                hlen = 5
            else:
                assert False

            source = b'x' * size
            encoded = b''.join(cborutil.streamencode(source))

            res = cborutil.decodeitem(encoded[0:1])

            if hlen > 1:
                self.assertEqual(res, (False, None, -(hlen - 1),
                                       cborutil.SPECIAL_NONE))
            else:
                self.assertEqual(res, (False, None, -(size + hlen - 1),
                                       cborutil.SPECIAL_NONE))

            # Decoding partial header reports remaining header size.
            for i in range(hlen - 1):
                self.assertEqual(cborutil.decodeitem(encoded[0:i + 1]),
                                 (False, None, -(hlen - i - 1),
                                  cborutil.SPECIAL_NONE))

            # Decoding complete header reports item size.
            self.assertEqual(cborutil.decodeitem(encoded[0:hlen]),
                             (False, None, -size, cborutil.SPECIAL_NONE))

            # Decoding single byte after header reports item size - 1
            self.assertEqual(cborutil.decodeitem(encoded[0:hlen + 1]),
                             (False, None, -(size - 1), cborutil.SPECIAL_NONE))

            # Decoding all but the last byte reports -1 needed.
            self.assertEqual(cborutil.decodeitem(encoded[0:hlen + size - 1]),
                             (False, None, -1, cborutil.SPECIAL_NONE))

            # Decoding last byte retrieves value.
            self.assertEqual(cborutil.decodeitem(encoded[0:hlen + size]),
                             (True, source, hlen + size, cborutil.SPECIAL_NONE))

    def testindefinitepartialdecode(self):
        encoded = b''.join(cborutil.streamencodebytestringfromiter(
            [b'foobar', b'biz']))

        # First item should be begin of bytestring special.
        self.assertEqual(cborutil.decodeitem(encoded[0:1]),
                         (True, None, 1,
                          cborutil.SPECIAL_START_INDEFINITE_BYTESTRING))

        # Second item should be the first chunk. But only available when
        # we give it 7 bytes (1 byte header + 6 byte chunk).
        self.assertEqual(cborutil.decodeitem(encoded[1:2]),
                         (False, None, -6, cborutil.SPECIAL_NONE))
        self.assertEqual(cborutil.decodeitem(encoded[1:3]),
                         (False, None, -5, cborutil.SPECIAL_NONE))
        self.assertEqual(cborutil.decodeitem(encoded[1:4]),
                         (False, None, -4, cborutil.SPECIAL_NONE))
        self.assertEqual(cborutil.decodeitem(encoded[1:5]),
                         (False, None, -3, cborutil.SPECIAL_NONE))
        self.assertEqual(cborutil.decodeitem(encoded[1:6]),
                         (False, None, -2, cborutil.SPECIAL_NONE))
        self.assertEqual(cborutil.decodeitem(encoded[1:7]),
                         (False, None, -1, cborutil.SPECIAL_NONE))

        self.assertEqual(cborutil.decodeitem(encoded[1:8]),
                         (True, b'foobar', 7, cborutil.SPECIAL_NONE))

        # Third item should be second chunk. But only available when
        # we give it 4 bytes (1 byte header + 3 byte chunk).
        self.assertEqual(cborutil.decodeitem(encoded[8:9]),
                         (False, None, -3, cborutil.SPECIAL_NONE))
        self.assertEqual(cborutil.decodeitem(encoded[8:10]),
                         (False, None, -2, cborutil.SPECIAL_NONE))
        self.assertEqual(cborutil.decodeitem(encoded[8:11]),
                         (False, None, -1, cborutil.SPECIAL_NONE))

        self.assertEqual(cborutil.decodeitem(encoded[8:12]),
                         (True, b'biz', 4, cborutil.SPECIAL_NONE))

        # Fourth item should be end of indefinite stream marker.
        self.assertEqual(cborutil.decodeitem(encoded[12:13]),
                         (True, None, 1, cborutil.SPECIAL_INDEFINITE_BREAK))

        # Now test the behavior when going through the decoder.

        self.assertEqual(cborutil.sansiodecoder().decode(encoded[0:1]),
                         (False, 1, 0))
        self.assertEqual(cborutil.sansiodecoder().decode(encoded[0:2]),
                         (False, 1, 6))
        self.assertEqual(cborutil.sansiodecoder().decode(encoded[0:3]),
                         (False, 1, 5))
        self.assertEqual(cborutil.sansiodecoder().decode(encoded[0:4]),
                         (False, 1, 4))
        self.assertEqual(cborutil.sansiodecoder().decode(encoded[0:5]),
                         (False, 1, 3))
        self.assertEqual(cborutil.sansiodecoder().decode(encoded[0:6]),
                         (False, 1, 2))
        self.assertEqual(cborutil.sansiodecoder().decode(encoded[0:7]),
                         (False, 1, 1))
        self.assertEqual(cborutil.sansiodecoder().decode(encoded[0:8]),
                         (True, 8, 0))

        self.assertEqual(cborutil.sansiodecoder().decode(encoded[0:9]),
                         (True, 8, 3))
        self.assertEqual(cborutil.sansiodecoder().decode(encoded[0:10]),
                         (True, 8, 2))
        self.assertEqual(cborutil.sansiodecoder().decode(encoded[0:11]),
                         (True, 8, 1))
        self.assertEqual(cborutil.sansiodecoder().decode(encoded[0:12]),
                         (True, 12, 0))

        self.assertEqual(cborutil.sansiodecoder().decode(encoded[0:13]),
                         (True, 13, 0))

        decoder = cborutil.sansiodecoder()
        decoder.decode(encoded[0:8])
        values = decoder.getavailable()
        self.assertEqual(values, [b'foobar'])
        self.assertTrue(values[0].isfirst)
        self.assertFalse(values[0].islast)

        self.assertEqual(decoder.decode(encoded[8:12]),
                         (True, 4, 0))
        values = decoder.getavailable()
        self.assertEqual(values, [b'biz'])
        self.assertFalse(values[0].isfirst)
        self.assertFalse(values[0].islast)

        self.assertEqual(decoder.decode(encoded[12:]),
                         (True, 1, 0))
        values = decoder.getavailable()
        self.assertEqual(values, [b''])
        self.assertFalse(values[0].isfirst)
        self.assertTrue(values[0].islast)

class StringTests(TestCase):
    def testdecodeforbidden(self):
        encoded = b'\x63foo'
        with self.assertRaisesRegex(cborutil.CBORDecodeError,
                                    'string major type not supported'):
            cborutil.decodeall(encoded)

class IntTests(TestCase):
    def testsmall(self):
        self.assertEqual(list(cborutil.streamencode(0)), [b'\x00'])
        self.assertEqual(cborutil.decodeall(b'\x00'), [0])

        self.assertEqual(list(cborutil.streamencode(1)), [b'\x01'])
        self.assertEqual(cborutil.decodeall(b'\x01'), [1])

        self.assertEqual(list(cborutil.streamencode(2)), [b'\x02'])
        self.assertEqual(cborutil.decodeall(b'\x02'), [2])

        self.assertEqual(list(cborutil.streamencode(3)), [b'\x03'])
        self.assertEqual(cborutil.decodeall(b'\x03'), [3])

        self.assertEqual(list(cborutil.streamencode(4)), [b'\x04'])
        self.assertEqual(cborutil.decodeall(b'\x04'), [4])

        # Multiple value decode works.
        self.assertEqual(cborutil.decodeall(b'\x00\x01\x02\x03\x04'),
                         [0, 1, 2, 3, 4])

    def testnegativesmall(self):
        self.assertEqual(list(cborutil.streamencode(-1)), [b'\x20'])
        self.assertEqual(cborutil.decodeall(b'\x20'), [-1])

        self.assertEqual(list(cborutil.streamencode(-2)), [b'\x21'])
        self.assertEqual(cborutil.decodeall(b'\x21'), [-2])

        self.assertEqual(list(cborutil.streamencode(-3)), [b'\x22'])
        self.assertEqual(cborutil.decodeall(b'\x22'), [-3])

        self.assertEqual(list(cborutil.streamencode(-4)), [b'\x23'])
        self.assertEqual(cborutil.decodeall(b'\x23'), [-4])

        self.assertEqual(list(cborutil.streamencode(-5)), [b'\x24'])
        self.assertEqual(cborutil.decodeall(b'\x24'), [-5])

        # Multiple value decode works.
        self.assertEqual(cborutil.decodeall(b'\x20\x21\x22\x23\x24'),
                         [-1, -2, -3, -4, -5])

    def testrange(self):
        for i in range(-70000, 70000, 10):
            encoded = b''.join(cborutil.streamencode(i))

            self.assertEqual(encoded, cbor.dumps(i))
            self.assertEqual(cborutil.decodeall(encoded), [i])

    def testdecodepartialubyte(self):
        encoded = b''.join(cborutil.streamencode(250))

        self.assertEqual(cborutil.decodeitem(encoded[0:1]),
                         (False, None, -1, cborutil.SPECIAL_NONE))
        self.assertEqual(cborutil.decodeitem(encoded[0:2]),
                         (True, 250, 2, cborutil.SPECIAL_NONE))

    def testdecodepartialbyte(self):
        encoded = b''.join(cborutil.streamencode(-42))
        self.assertEqual(cborutil.decodeitem(encoded[0:1]),
                         (False, None, -1, cborutil.SPECIAL_NONE))
        self.assertEqual(cborutil.decodeitem(encoded[0:2]),
                         (True, -42, 2, cborutil.SPECIAL_NONE))

    def testdecodepartialushort(self):
        encoded = b''.join(cborutil.streamencode(2**15))

        self.assertEqual(cborutil.decodeitem(encoded[0:1]),
                         (False, None, -2, cborutil.SPECIAL_NONE))
        self.assertEqual(cborutil.decodeitem(encoded[0:2]),
                         (False, None, -1, cborutil.SPECIAL_NONE))
        self.assertEqual(cborutil.decodeitem(encoded[0:5]),
                         (True, 2**15, 3, cborutil.SPECIAL_NONE))

    def testdecodepartialshort(self):
        encoded = b''.join(cborutil.streamencode(-1024))

        self.assertEqual(cborutil.decodeitem(encoded[0:1]),
                         (False, None, -2, cborutil.SPECIAL_NONE))
        self.assertEqual(cborutil.decodeitem(encoded[0:2]),
                         (False, None, -1, cborutil.SPECIAL_NONE))
        self.assertEqual(cborutil.decodeitem(encoded[0:3]),
                         (True, -1024, 3, cborutil.SPECIAL_NONE))

    def testdecodepartialulong(self):
        encoded = b''.join(cborutil.streamencode(2**28))

        self.assertEqual(cborutil.decodeitem(encoded[0:1]),
                         (False, None, -4, cborutil.SPECIAL_NONE))
        self.assertEqual(cborutil.decodeitem(encoded[0:2]),
                         (False, None, -3, cborutil.SPECIAL_NONE))
        self.assertEqual(cborutil.decodeitem(encoded[0:3]),
                         (False, None, -2, cborutil.SPECIAL_NONE))
        self.assertEqual(cborutil.decodeitem(encoded[0:4]),
                         (False, None, -1, cborutil.SPECIAL_NONE))
        self.assertEqual(cborutil.decodeitem(encoded[0:5]),
                         (True, 2**28, 5, cborutil.SPECIAL_NONE))

    def testdecodepartiallong(self):
        encoded = b''.join(cborutil.streamencode(-1048580))

        self.assertEqual(cborutil.decodeitem(encoded[0:1]),
                         (False, None, -4, cborutil.SPECIAL_NONE))
        self.assertEqual(cborutil.decodeitem(encoded[0:2]),
                         (False, None, -3, cborutil.SPECIAL_NONE))
        self.assertEqual(cborutil.decodeitem(encoded[0:3]),
                         (False, None, -2, cborutil.SPECIAL_NONE))
        self.assertEqual(cborutil.decodeitem(encoded[0:4]),
                         (False, None, -1, cborutil.SPECIAL_NONE))
        self.assertEqual(cborutil.decodeitem(encoded[0:5]),
                         (True, -1048580, 5, cborutil.SPECIAL_NONE))

    def testdecodepartialulonglong(self):
        encoded = b''.join(cborutil.streamencode(2**32))

        self.assertEqual(cborutil.decodeitem(encoded[0:1]),
                         (False, None, -8, cborutil.SPECIAL_NONE))
        self.assertEqual(cborutil.decodeitem(encoded[0:2]),
                         (False, None, -7, cborutil.SPECIAL_NONE))
        self.assertEqual(cborutil.decodeitem(encoded[0:3]),
                         (False, None, -6, cborutil.SPECIAL_NONE))
        self.assertEqual(cborutil.decodeitem(encoded[0:4]),
                         (False, None, -5, cborutil.SPECIAL_NONE))
        self.assertEqual(cborutil.decodeitem(encoded[0:5]),
                         (False, None, -4, cborutil.SPECIAL_NONE))
        self.assertEqual(cborutil.decodeitem(encoded[0:6]),
                         (False, None, -3, cborutil.SPECIAL_NONE))
        self.assertEqual(cborutil.decodeitem(encoded[0:7]),
                         (False, None, -2, cborutil.SPECIAL_NONE))
        self.assertEqual(cborutil.decodeitem(encoded[0:8]),
                         (False, None, -1, cborutil.SPECIAL_NONE))
        self.assertEqual(cborutil.decodeitem(encoded[0:9]),
                         (True, 2**32, 9, cborutil.SPECIAL_NONE))

        with self.assertRaisesRegex(
            cborutil.CBORDecodeError, 'input data not fully consumed'):
            cborutil.decodeall(encoded[0:1])

        with self.assertRaisesRegex(
            cborutil.CBORDecodeError, 'input data not fully consumed'):
            cborutil.decodeall(encoded[0:2])

    def testdecodepartiallonglong(self):
        encoded = b''.join(cborutil.streamencode(-7000000000))

        self.assertEqual(cborutil.decodeitem(encoded[0:1]),
                         (False, None, -8, cborutil.SPECIAL_NONE))
        self.assertEqual(cborutil.decodeitem(encoded[0:2]),
                         (False, None, -7, cborutil.SPECIAL_NONE))
        self.assertEqual(cborutil.decodeitem(encoded[0:3]),
                         (False, None, -6, cborutil.SPECIAL_NONE))
        self.assertEqual(cborutil.decodeitem(encoded[0:4]),
                         (False, None, -5, cborutil.SPECIAL_NONE))
        self.assertEqual(cborutil.decodeitem(encoded[0:5]),
                         (False, None, -4, cborutil.SPECIAL_NONE))
        self.assertEqual(cborutil.decodeitem(encoded[0:6]),
                         (False, None, -3, cborutil.SPECIAL_NONE))
        self.assertEqual(cborutil.decodeitem(encoded[0:7]),
                         (False, None, -2, cborutil.SPECIAL_NONE))
        self.assertEqual(cborutil.decodeitem(encoded[0:8]),
                         (False, None, -1, cborutil.SPECIAL_NONE))
        self.assertEqual(cborutil.decodeitem(encoded[0:9]),
                         (True, -7000000000, 9, cborutil.SPECIAL_NONE))

class ArrayTests(TestCase):
    def testempty(self):
        self.assertEqual(list(cborutil.streamencode([])), [b'\x80'])
        self.assertEqual(loadit(cborutil.streamencode([])), [])

        self.assertEqual(cborutil.decodeall(b'\x80'), [[]])

    def testbasic(self):
        source = [b'foo', b'bar', 1, -10]

        chunks = [
            b'\x84', b'\x43', b'foo', b'\x43', b'bar', b'\x01', b'\x29']

        self.assertEqual(list(cborutil.streamencode(source)), chunks)

        self.assertEqual(cborutil.decodeall(b''.join(chunks)), [source])

    def testemptyfromiter(self):
        self.assertEqual(b''.join(cborutil.streamencodearrayfromiter([])),
                         b'\x9f\xff')

        with self.assertRaisesRegex(cborutil.CBORDecodeError,
                                    'indefinite length uint not allowed'):
            cborutil.decodeall(b'\x9f\xff')

    def testfromiter1(self):
        source = [b'foo']

        self.assertEqual(list(cborutil.streamencodearrayfromiter(source)), [
            b'\x9f',
            b'\x43', b'foo',
            b'\xff',
        ])

        dest = b''.join(cborutil.streamencodearrayfromiter(source))
        self.assertEqual(cbor.loads(dest), source)

        with self.assertRaisesRegex(cborutil.CBORDecodeError,
                                    'indefinite length uint not allowed'):
            cborutil.decodeall(dest)

    def testtuple(self):
        source = (b'foo', None, 42)
        encoded = b''.join(cborutil.streamencode(source))

        self.assertEqual(cbor.loads(encoded), list(source))

        self.assertEqual(cborutil.decodeall(encoded), [list(source)])

    def testpartialdecode(self):
        source = list(range(4))
        encoded = b''.join(cborutil.streamencode(source))
        self.assertEqual(cborutil.decodeitem(encoded[0:1]),
                         (True, 4, 1, cborutil.SPECIAL_START_ARRAY))
        self.assertEqual(cborutil.decodeitem(encoded[0:2]),
                         (True, 4, 1, cborutil.SPECIAL_START_ARRAY))

        source = list(range(23))
        encoded = b''.join(cborutil.streamencode(source))
        self.assertEqual(cborutil.decodeitem(encoded[0:1]),
                         (True, 23, 1, cborutil.SPECIAL_START_ARRAY))
        self.assertEqual(cborutil.decodeitem(encoded[0:2]),
                         (True, 23, 1, cborutil.SPECIAL_START_ARRAY))

        source = list(range(24))
        encoded = b''.join(cborutil.streamencode(source))
        self.assertEqual(cborutil.decodeitem(encoded[0:1]),
                         (False, None, -1, cborutil.SPECIAL_NONE))
        self.assertEqual(cborutil.decodeitem(encoded[0:2]),
                         (True, 24, 2, cborutil.SPECIAL_START_ARRAY))
        self.assertEqual(cborutil.decodeitem(encoded[0:3]),
                         (True, 24, 2, cborutil.SPECIAL_START_ARRAY))

        source = list(range(256))
        encoded = b''.join(cborutil.streamencode(source))
        self.assertEqual(cborutil.decodeitem(encoded[0:1]),
                         (False, None, -2, cborutil.SPECIAL_NONE))
        self.assertEqual(cborutil.decodeitem(encoded[0:2]),
                         (False, None, -1, cborutil.SPECIAL_NONE))
        self.assertEqual(cborutil.decodeitem(encoded[0:3]),
                         (True, 256, 3, cborutil.SPECIAL_START_ARRAY))
        self.assertEqual(cborutil.decodeitem(encoded[0:4]),
                         (True, 256, 3, cborutil.SPECIAL_START_ARRAY))

    def testnested(self):
        source = [[], [], [[], [], []]]
        encoded = b''.join(cborutil.streamencode(source))
        self.assertEqual(cborutil.decodeall(encoded), [source])

        source = [True, None, [True, 0, 2], [None], [], [[[]], -87]]
        encoded = b''.join(cborutil.streamencode(source))
        self.assertEqual(cborutil.decodeall(encoded), [source])

        # A set within an array.
        source = [None, {b'foo', b'bar', None, False}, set()]
        encoded = b''.join(cborutil.streamencode(source))
        self.assertEqual(cborutil.decodeall(encoded), [source])

        # A map within an array.
        source = [None, {}, {b'foo': b'bar', True: False}, [{}]]
        encoded = b''.join(cborutil.streamencode(source))
        self.assertEqual(cborutil.decodeall(encoded), [source])

    def testindefinitebytestringvalues(self):
        # Single value array whose value is an empty indefinite bytestring.
        encoded = b'\x81\x5f\x40\xff'

        with self.assertRaisesRegex(cborutil.CBORDecodeError,
                                    'indefinite length bytestrings not '
                                    'allowed as array values'):
            cborutil.decodeall(encoded)

class SetTests(TestCase):
    def testempty(self):
        self.assertEqual(list(cborutil.streamencode(set())), [
            b'\xd9\x01\x02',
            b'\x80',
        ])

        self.assertEqual(cborutil.decodeall(b'\xd9\x01\x02\x80'), [set()])

    def testset(self):
        source = {b'foo', None, 42}
        encoded = b''.join(cborutil.streamencode(source))

        self.assertEqual(cbor.loads(encoded), source)

        self.assertEqual(cborutil.decodeall(encoded), [source])

    def testinvalidtag(self):
        # Must use array to encode sets.
        encoded = b'\xd9\x01\x02\xa0'

        with self.assertRaisesRegex(cborutil.CBORDecodeError,
                                    'expected array after finite set '
                                    'semantic tag'):
            cborutil.decodeall(encoded)

    def testpartialdecode(self):
        # Semantic tag item will be 3 bytes. Set header will be variable
        # depending on length.
        encoded = b''.join(cborutil.streamencode({i for i in range(23)}))
        self.assertEqual(cborutil.decodeitem(encoded[0:1]),
                         (False, None, -2, cborutil.SPECIAL_NONE))
        self.assertEqual(cborutil.decodeitem(encoded[0:2]),
                         (False, None, -1, cborutil.SPECIAL_NONE))
        self.assertEqual(cborutil.decodeitem(encoded[0:3]),
                         (False, None, -1, cborutil.SPECIAL_NONE))
        self.assertEqual(cborutil.decodeitem(encoded[0:4]),
                         (True, 23, 4, cborutil.SPECIAL_START_SET))
        self.assertEqual(cborutil.decodeitem(encoded[0:5]),
                         (True, 23, 4, cborutil.SPECIAL_START_SET))

        encoded = b''.join(cborutil.streamencode({i for i in range(24)}))
        self.assertEqual(cborutil.decodeitem(encoded[0:1]),
                         (False, None, -2, cborutil.SPECIAL_NONE))
        self.assertEqual(cborutil.decodeitem(encoded[0:2]),
                         (False, None, -1, cborutil.SPECIAL_NONE))
        self.assertEqual(cborutil.decodeitem(encoded[0:3]),
                         (False, None, -1, cborutil.SPECIAL_NONE))
        self.assertEqual(cborutil.decodeitem(encoded[0:4]),
                         (False, None, -1, cborutil.SPECIAL_NONE))
        self.assertEqual(cborutil.decodeitem(encoded[0:5]),
                         (True, 24, 5, cborutil.SPECIAL_START_SET))
        self.assertEqual(cborutil.decodeitem(encoded[0:6]),
                         (True, 24, 5, cborutil.SPECIAL_START_SET))

        encoded = b''.join(cborutil.streamencode({i for i in range(256)}))
        self.assertEqual(cborutil.decodeitem(encoded[0:1]),
                         (False, None, -2, cborutil.SPECIAL_NONE))
        self.assertEqual(cborutil.decodeitem(encoded[0:2]),
                         (False, None, -1, cborutil.SPECIAL_NONE))
        self.assertEqual(cborutil.decodeitem(encoded[0:3]),
                         (False, None, -1, cborutil.SPECIAL_NONE))
        self.assertEqual(cborutil.decodeitem(encoded[0:4]),
                         (False, None, -2, cborutil.SPECIAL_NONE))
        self.assertEqual(cborutil.decodeitem(encoded[0:5]),
                         (False, None, -1, cborutil.SPECIAL_NONE))
        self.assertEqual(cborutil.decodeitem(encoded[0:6]),
                         (True, 256, 6, cborutil.SPECIAL_START_SET))

    def testinvalidvalue(self):
        encoded = b''.join([
            b'\xd9\x01\x02', # semantic tag
            b'\x81', # array of size 1
            b'\x5f\x43foo\xff', # indefinite length bytestring "foo"
        ])

        with self.assertRaisesRegex(cborutil.CBORDecodeError,
                                    'indefinite length bytestrings not '
                                    'allowed as set values'):
            cborutil.decodeall(encoded)

        encoded = b''.join([
            b'\xd9\x01\x02',
            b'\x81',
            b'\x80', # empty array
        ])

        with self.assertRaisesRegex(cborutil.CBORDecodeError,
                                    'collections not allowed as set values'):
            cborutil.decodeall(encoded)

        encoded = b''.join([
            b'\xd9\x01\x02',
            b'\x81',
            b'\xa0', # empty map
        ])

        with self.assertRaisesRegex(cborutil.CBORDecodeError,
                                    'collections not allowed as set values'):
            cborutil.decodeall(encoded)

        encoded = b''.join([
            b'\xd9\x01\x02',
            b'\x81',
            b'\xd9\x01\x02\x81\x01', # set with integer 1
        ])

        with self.assertRaisesRegex(cborutil.CBORDecodeError,
                                    'collections not allowed as set values'):
            cborutil.decodeall(encoded)

class BoolTests(TestCase):
    def testbasic(self):
        self.assertEqual(list(cborutil.streamencode(True)),  [b'\xf5'])
        self.assertEqual(list(cborutil.streamencode(False)), [b'\xf4'])

        self.assertIs(loadit(cborutil.streamencode(True)), True)
        self.assertIs(loadit(cborutil.streamencode(False)), False)

        self.assertEqual(cborutil.decodeall(b'\xf4'), [False])
        self.assertEqual(cborutil.decodeall(b'\xf5'), [True])

        self.assertEqual(cborutil.decodeall(b'\xf4\xf5\xf5\xf4'),
                         [False, True, True, False])

class NoneTests(TestCase):
    def testbasic(self):
        self.assertEqual(list(cborutil.streamencode(None)), [b'\xf6'])

        self.assertIs(loadit(cborutil.streamencode(None)), None)

        self.assertEqual(cborutil.decodeall(b'\xf6'), [None])
        self.assertEqual(cborutil.decodeall(b'\xf6\xf6'), [None, None])

class MapTests(TestCase):
    def testempty(self):
        self.assertEqual(list(cborutil.streamencode({})), [b'\xa0'])
        self.assertEqual(loadit(cborutil.streamencode({})), {})

        self.assertEqual(cborutil.decodeall(b'\xa0'), [{}])

    def testemptyindefinite(self):
        self.assertEqual(list(cborutil.streamencodemapfromiter([])), [
            b'\xbf', b'\xff'])

        self.assertEqual(loadit(cborutil.streamencodemapfromiter([])), {})

        with self.assertRaisesRegex(cborutil.CBORDecodeError,
                                    'indefinite length uint not allowed'):
            cborutil.decodeall(b'\xbf\xff')

    def testone(self):
        source = {b'foo': b'bar'}
        self.assertEqual(list(cborutil.streamencode(source)), [
            b'\xa1', b'\x43', b'foo', b'\x43', b'bar'])

        self.assertEqual(loadit(cborutil.streamencode(source)), source)

        self.assertEqual(cborutil.decodeall(b'\xa1\x43foo\x43bar'), [source])

    def testmultiple(self):
        source = {
            b'foo': b'bar',
            b'baz': b'value1',
        }

        self.assertEqual(loadit(cborutil.streamencode(source)), source)

        self.assertEqual(
            loadit(cborutil.streamencodemapfromiter(source.items())),
            source)

        encoded = b''.join(cborutil.streamencode(source))
        self.assertEqual(cborutil.decodeall(encoded), [source])

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

        encoded = b''.join(cborutil.streamencode(source))
        self.assertEqual(cborutil.decodeall(encoded), [source])

    def testnested(self):
        source = {b'key1': None, b'key2': {b'sub1': b'sub2'}, b'sub2': {}}
        encoded = b''.join(cborutil.streamencode(source))

        self.assertEqual(cborutil.decodeall(encoded), [source])

        source = {
            b'key1': [],
            b'key2': [None, False],
            b'key3': {b'foo', b'bar'},
            b'key4': {},
        }
        encoded = b''.join(cborutil.streamencode(source))
        self.assertEqual(cborutil.decodeall(encoded), [source])

    def testillegalkey(self):
        encoded = b''.join([
            # map header + len 1
            b'\xa1',
            # indefinite length bytestring "foo" in key position
            b'\x5f\x03foo\xff'
        ])

        with self.assertRaisesRegex(cborutil.CBORDecodeError,
                                    'indefinite length bytestrings not '
                                    'allowed as map keys'):
            cborutil.decodeall(encoded)

        encoded = b''.join([
            b'\xa1',
            b'\x80', # empty array
            b'\x43foo',
        ])

        with self.assertRaisesRegex(cborutil.CBORDecodeError,
                                    'collections not supported as map keys'):
            cborutil.decodeall(encoded)

    def testillegalvalue(self):
        encoded = b''.join([
            b'\xa1', # map headers
            b'\x43foo', # key
            b'\x5f\x03bar\xff', # indefinite length value
        ])

        with self.assertRaisesRegex(cborutil.CBORDecodeError,
                                    'indefinite length bytestrings not '
                                    'allowed as map values'):
            cborutil.decodeall(encoded)

    def testpartialdecode(self):
        source = {b'key1': b'value1'}
        encoded = b''.join(cborutil.streamencode(source))

        self.assertEqual(cborutil.decodeitem(encoded[0:1]),
                         (True, 1, 1, cborutil.SPECIAL_START_MAP))
        self.assertEqual(cborutil.decodeitem(encoded[0:2]),
                         (True, 1, 1, cborutil.SPECIAL_START_MAP))

        source = {b'key%d' % i: None for i in range(23)}
        encoded = b''.join(cborutil.streamencode(source))
        self.assertEqual(cborutil.decodeitem(encoded[0:1]),
                         (True, 23, 1, cborutil.SPECIAL_START_MAP))

        source = {b'key%d' % i: None for i in range(24)}
        encoded = b''.join(cborutil.streamencode(source))
        self.assertEqual(cborutil.decodeitem(encoded[0:1]),
                         (False, None, -1, cborutil.SPECIAL_NONE))
        self.assertEqual(cborutil.decodeitem(encoded[0:2]),
                         (True, 24, 2, cborutil.SPECIAL_START_MAP))
        self.assertEqual(cborutil.decodeitem(encoded[0:3]),
                         (True, 24, 2, cborutil.SPECIAL_START_MAP))

        source = {b'key%d' % i: None for i in range(256)}
        encoded = b''.join(cborutil.streamencode(source))
        self.assertEqual(cborutil.decodeitem(encoded[0:1]),
                         (False, None, -2, cborutil.SPECIAL_NONE))
        self.assertEqual(cborutil.decodeitem(encoded[0:2]),
                         (False, None, -1, cborutil.SPECIAL_NONE))
        self.assertEqual(cborutil.decodeitem(encoded[0:3]),
                         (True, 256, 3, cborutil.SPECIAL_START_MAP))
        self.assertEqual(cborutil.decodeitem(encoded[0:4]),
                         (True, 256, 3, cborutil.SPECIAL_START_MAP))

        source = {b'key%d' % i: None for i in range(65536)}
        encoded = b''.join(cborutil.streamencode(source))
        self.assertEqual(cborutil.decodeitem(encoded[0:1]),
                         (False, None, -4, cborutil.SPECIAL_NONE))
        self.assertEqual(cborutil.decodeitem(encoded[0:2]),
                         (False, None, -3, cborutil.SPECIAL_NONE))
        self.assertEqual(cborutil.decodeitem(encoded[0:3]),
                         (False, None, -2, cborutil.SPECIAL_NONE))
        self.assertEqual(cborutil.decodeitem(encoded[0:4]),
                         (False, None, -1, cborutil.SPECIAL_NONE))
        self.assertEqual(cborutil.decodeitem(encoded[0:5]),
                         (True, 65536, 5, cborutil.SPECIAL_START_MAP))
        self.assertEqual(cborutil.decodeitem(encoded[0:6]),
                         (True, 65536, 5, cborutil.SPECIAL_START_MAP))

class SemanticTagTests(TestCase):
    def testdecodeforbidden(self):
        for i in range(500):
            if i == cborutil.SEMANTIC_TAG_FINITE_SET:
                continue

            tag = cborutil.encodelength(cborutil.MAJOR_TYPE_SEMANTIC,
                                        i)

            encoded = tag + cborutil.encodelength(cborutil.MAJOR_TYPE_UINT, 42)

            # Partial decode is incomplete.
            if i < 24:
                pass
            elif i < 256:
                self.assertEqual(cborutil.decodeitem(encoded[0:1]),
                                 (False, None, -1, cborutil.SPECIAL_NONE))
            elif i < 65536:
                self.assertEqual(cborutil.decodeitem(encoded[0:1]),
                                 (False, None, -2, cborutil.SPECIAL_NONE))
                self.assertEqual(cborutil.decodeitem(encoded[0:2]),
                                 (False, None, -1, cborutil.SPECIAL_NONE))

            with self.assertRaisesRegex(cborutil.CBORDecodeError,
                                        'semantic tag \d+ not allowed'):
                cborutil.decodeitem(encoded)

class SpecialTypesTests(TestCase):
    def testforbiddentypes(self):
        for i in range(256):
            if i == cborutil.SUBTYPE_FALSE:
                continue
            elif i == cborutil.SUBTYPE_TRUE:
                continue
            elif i == cborutil.SUBTYPE_NULL:
                continue

            encoded = cborutil.encodelength(cborutil.MAJOR_TYPE_SPECIAL, i)

            with self.assertRaisesRegex(cborutil.CBORDecodeError,
                                        'special type \d+ not allowed'):
                cborutil.decodeitem(encoded)

class SansIODecoderTests(TestCase):
    def testemptyinput(self):
        decoder = cborutil.sansiodecoder()
        self.assertEqual(decoder.decode(b''), (False, 0, 0))

class BufferingDecoderTests(TestCase):
    def testsimple(self):
        source = [
            b'foobar',
            b'x' * 128,
            {b'foo': b'bar'},
            True,
            False,
            None,
            [None for i in range(128)],
        ]

        encoded = b''.join(cborutil.streamencode(source))

        for step in range(1, 32):
            decoder = cborutil.bufferingdecoder()
            start = 0

            while start < len(encoded):
                decoder.decode(encoded[start:start + step])
                start += step

            self.assertEqual(decoder.getavailable(), [source])

    def testbytearray(self):
        source = b''.join(cborutil.streamencode(b'foobar'))

        decoder = cborutil.bufferingdecoder()
        decoder.decode(bytearray(source))

        self.assertEqual(decoder.getavailable(), [b'foobar'])

class DecodeallTests(TestCase):
    def testemptyinput(self):
        self.assertEqual(cborutil.decodeall(b''), [])

    def testpartialinput(self):
        encoded = b''.join([
            b'\x82', # array of 2 elements
            b'\x01', # integer 1
        ])

        with self.assertRaisesRegex(cborutil.CBORDecodeError,
                                    'input data not complete'):
            cborutil.decodeall(encoded)

if __name__ == '__main__':
    import silenttestrunner
    silenttestrunner.main(__name__)
