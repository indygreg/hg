from __future__ import absolute_import, print_function

import unittest

from mercurial import (
    util,
    wireprotoframing as framing,
)

ffs = framing.makeframefromhumanstring

class FrameHumanStringTests(unittest.TestCase):
    def testbasic(self):
        self.assertEqual(ffs(b'1 1 0 1 0 '),
                         b'\x00\x00\x00\x01\x00\x01\x00\x10')

        self.assertEqual(ffs(b'2 4 0 1 0 '),
                         b'\x00\x00\x00\x02\x00\x04\x00\x10')

        self.assertEqual(ffs(b'2 4 0 1 0 foo'),
                         b'\x03\x00\x00\x02\x00\x04\x00\x10foo')

    def testcborint(self):
        self.assertEqual(ffs(b'1 1 0 1 0 cbor:15'),
                         b'\x01\x00\x00\x01\x00\x01\x00\x10\x0f')

        self.assertEqual(ffs(b'1 1 0 1 0 cbor:42'),
                         b'\x02\x00\x00\x01\x00\x01\x00\x10\x18*')

        self.assertEqual(ffs(b'1 1 0 1 0 cbor:1048576'),
                         b'\x05\x00\x00\x01\x00\x01\x00\x10\x1a'
                         b'\x00\x10\x00\x00')

        self.assertEqual(ffs(b'1 1 0 1 0 cbor:0'),
                         b'\x01\x00\x00\x01\x00\x01\x00\x10\x00')

        self.assertEqual(ffs(b'1 1 0 1 0 cbor:-1'),
                         b'\x01\x00\x00\x01\x00\x01\x00\x10 ')

        self.assertEqual(ffs(b'1 1 0 1 0 cbor:-342542'),
                         b'\x05\x00\x00\x01\x00\x01\x00\x10:\x00\x05:\r')

    def testcborstrings(self):
        self.assertEqual(ffs(b"1 1 0 1 0 cbor:b'foo'"),
                         b'\x04\x00\x00\x01\x00\x01\x00\x10Cfoo')

        self.assertEqual(ffs(b"1 1 0 1 0 cbor:u'foo'"),
                         b'\x04\x00\x00\x01\x00\x01\x00\x10cfoo')

    def testcborlists(self):
        self.assertEqual(ffs(b"1 1 0 1 0 cbor:[None, True, False, 42, b'foo']"),
                         b'\n\x00\x00\x01\x00\x01\x00\x10\x85\xf6\xf5\xf4'
                         b'\x18*Cfoo')

    def testcbordicts(self):
        self.assertEqual(ffs(b"1 1 0 1 0 "
                             b"cbor:{b'foo': b'val1', b'bar': b'val2'}"),
                         b'\x13\x00\x00\x01\x00\x01\x00\x10\xa2'
                         b'CbarDval2CfooDval1')

class FrameTests(unittest.TestCase):
    def testdataexactframesize(self):
        data = util.bytesio(b'x' * framing.DEFAULT_MAX_FRAME_SIZE)

        stream = framing.stream(1)
        frames = list(framing.createcommandframes(stream, 1, b'command',
                                                  {}, data))
        self.assertEqual(frames, [
            ffs(b'1 1 stream-begin command-request new|have-data '
                b"cbor:{b'name': b'command'}"),
            ffs(b'1 1 0 command-data continuation %s' % data.getvalue()),
            ffs(b'1 1 0 command-data eos ')
        ])

    def testdatamultipleframes(self):
        data = util.bytesio(b'x' * (framing.DEFAULT_MAX_FRAME_SIZE + 1))

        stream = framing.stream(1)
        frames = list(framing.createcommandframes(stream, 1, b'command', {},
                                                  data))
        self.assertEqual(frames, [
            ffs(b'1 1 stream-begin command-request new|have-data '
                b"cbor:{b'name': b'command'}"),
            ffs(b'1 1 0 command-data continuation %s' % (
                b'x' * framing.DEFAULT_MAX_FRAME_SIZE)),
            ffs(b'1 1 0 command-data eos x'),
        ])

    def testargsanddata(self):
        data = util.bytesio(b'x' * 100)

        stream = framing.stream(1)
        frames = list(framing.createcommandframes(stream, 1, b'command', {
            b'key1': b'key1value',
            b'key2': b'key2value',
            b'key3': b'key3value',
        }, data))

        self.assertEqual(frames, [
            ffs(b'1 1 stream-begin command-request new|have-data '
                b"cbor:{b'name': b'command', b'args': {b'key1': b'key1value', "
                b"b'key2': b'key2value', b'key3': b'key3value'}}"),
            ffs(b'1 1 0 command-data eos %s' % data.getvalue()),
        ])

    def testtextoutputformattingstringtype(self):
        """Formatting string must be bytes."""
        with self.assertRaisesRegexp(ValueError, 'must use bytes formatting '):
            list(framing.createtextoutputframe(None, 1, [
                (b'foo'.decode('ascii'), [], [])]))

    def testtextoutputargumentbytes(self):
        with self.assertRaisesRegexp(ValueError, 'must use bytes for argument'):
            list(framing.createtextoutputframe(None, 1, [
                (b'foo', [b'foo'.decode('ascii')], [])]))

    def testtextoutputlabelbytes(self):
        with self.assertRaisesRegexp(ValueError, 'must use bytes for labels'):
            list(framing.createtextoutputframe(None, 1, [
                (b'foo', [], [b'foo'.decode('ascii')])]))

    def testtextoutput1simpleatom(self):
        stream = framing.stream(1)
        val = list(framing.createtextoutputframe(stream, 1, [
            (b'foo', [], [])]))

        self.assertEqual(val, [
            ffs(b'1 1 stream-begin text-output 0 '
                b"cbor:[{b'msg': b'foo'}]"),
        ])

    def testtextoutput2simpleatoms(self):
        stream = framing.stream(1)
        val = list(framing.createtextoutputframe(stream, 1, [
            (b'foo', [], []),
            (b'bar', [], []),
        ]))

        self.assertEqual(val, [
            ffs(b'1 1 stream-begin text-output 0 '
                b"cbor:[{b'msg': b'foo'}, {b'msg': b'bar'}]")
        ])

    def testtextoutput1arg(self):
        stream = framing.stream(1)
        val = list(framing.createtextoutputframe(stream, 1, [
            (b'foo %s', [b'val1'], []),
        ]))

        self.assertEqual(val, [
            ffs(b'1 1 stream-begin text-output 0 '
                b"cbor:[{b'msg': b'foo %s', b'args': [b'val1']}]")
        ])

    def testtextoutput2arg(self):
        stream = framing.stream(1)
        val = list(framing.createtextoutputframe(stream, 1, [
            (b'foo %s %s', [b'val', b'value'], []),
        ]))

        self.assertEqual(val, [
            ffs(b'1 1 stream-begin text-output 0 '
                b"cbor:[{b'msg': b'foo %s %s', b'args': [b'val', b'value']}]")
        ])

    def testtextoutput1label(self):
        stream = framing.stream(1)
        val = list(framing.createtextoutputframe(stream, 1, [
            (b'foo', [], [b'label']),
        ]))

        self.assertEqual(val, [
            ffs(b'1 1 stream-begin text-output 0 '
                b"cbor:[{b'msg': b'foo', b'labels': [b'label']}]")
        ])

    def testargandlabel(self):
        stream = framing.stream(1)
        val = list(framing.createtextoutputframe(stream, 1, [
            (b'foo %s', [b'arg'], [b'label']),
        ]))

        self.assertEqual(val, [
            ffs(b'1 1 stream-begin text-output 0 '
                b"cbor:[{b'msg': b'foo %s', b'args': [b'arg'], "
                b"b'labels': [b'label']}]")
        ])

if __name__ == '__main__':
    import silenttestrunner
    silenttestrunner.main(__name__)
