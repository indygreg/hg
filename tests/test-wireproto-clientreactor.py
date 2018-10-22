from __future__ import absolute_import

import unittest
import zlib

from mercurial import (
    error,
    ui as uimod,
    wireprotoframing as framing,
)
from mercurial.utils import (
    cborutil,
)

try:
    from mercurial import zstd
    zstd.__version__
except ImportError:
    zstd = None

ffs = framing.makeframefromhumanstring

globalui = uimod.ui()

def sendframe(reactor, frame):
    """Send a frame bytearray to a reactor."""
    header = framing.parseheader(frame)
    payload = frame[framing.FRAME_HEADER_SIZE:]
    assert len(payload) == header.length

    return reactor.onframerecv(framing.frame(header.requestid,
                                             header.streamid,
                                             header.streamflags,
                                             header.typeid,
                                             header.flags,
                                             payload))

class SingleSendTests(unittest.TestCase):
    """A reactor that can only send once rejects subsequent sends."""

    if not getattr(unittest.TestCase, 'assertRaisesRegex', False):
        # Python 3.7 deprecates the regex*p* version, but 2.7 lacks
        # the regex version.
        assertRaisesRegex = (# camelcase-required
            unittest.TestCase.assertRaisesRegexp)

    def testbasic(self):
        reactor = framing.clientreactor(globalui,
                                        hasmultiplesend=False,
                                        buffersends=True)

        request, action, meta = reactor.callcommand(b'foo', {})
        self.assertEqual(request.state, b'pending')
        self.assertEqual(action, b'noop')

        action, meta = reactor.flushcommands()
        self.assertEqual(action, b'sendframes')

        for frame in meta[b'framegen']:
            self.assertEqual(request.state, b'sending')

        self.assertEqual(request.state, b'sent')

        with self.assertRaisesRegex(error.ProgrammingError,
                                     'cannot issue new commands'):
            reactor.callcommand(b'foo', {})

        with self.assertRaisesRegex(error.ProgrammingError,
                                     'cannot issue new commands'):
            reactor.callcommand(b'foo', {})

class NoBufferTests(unittest.TestCase):
    """A reactor without send buffering sends requests immediately."""
    def testbasic(self):
        reactor = framing.clientreactor(globalui,
                                        hasmultiplesend=True,
                                        buffersends=False)

        request, action, meta = reactor.callcommand(b'command1', {})
        self.assertEqual(request.requestid, 1)
        self.assertEqual(action, b'sendframes')

        self.assertEqual(request.state, b'pending')

        for frame in meta[b'framegen']:
            self.assertEqual(request.state, b'sending')

        self.assertEqual(request.state, b'sent')

        action, meta = reactor.flushcommands()
        self.assertEqual(action, b'noop')

        # And we can send another command.
        request, action, meta = reactor.callcommand(b'command2', {})
        self.assertEqual(request.requestid, 3)
        self.assertEqual(action, b'sendframes')

        for frame in meta[b'framegen']:
            self.assertEqual(request.state, b'sending')

        self.assertEqual(request.state, b'sent')

class BadFrameRecvTests(unittest.TestCase):
    if not getattr(unittest.TestCase, 'assertRaisesRegex', False):
        # Python 3.7 deprecates the regex*p* version, but 2.7 lacks
        # the regex version.
        assertRaisesRegex = (# camelcase-required
            unittest.TestCase.assertRaisesRegexp)

    def testoddstream(self):
        reactor = framing.clientreactor(globalui)

        action, meta = sendframe(reactor, ffs(b'1 1 0 1 0 foo'))
        self.assertEqual(action, b'error')
        self.assertEqual(meta[b'message'],
                         b'received frame with odd numbered stream ID: 1')

    def testunknownstream(self):
        reactor = framing.clientreactor(globalui)

        action, meta = sendframe(reactor, ffs(b'1 0 0 1 0 foo'))
        self.assertEqual(action, b'error')
        self.assertEqual(meta[b'message'],
                         b'received frame on unknown stream without beginning '
                         b'of stream flag set')

    def testunhandledframetype(self):
        reactor = framing.clientreactor(globalui, buffersends=False)

        request, action, meta = reactor.callcommand(b'foo', {})
        for frame in meta[b'framegen']:
            pass

        with self.assertRaisesRegex(error.ProgrammingError,
                                     'unhandled frame type'):
            sendframe(reactor, ffs(b'1 0 stream-begin text-output 0 foo'))

class StreamTests(unittest.TestCase):
    def testmultipleresponseframes(self):
        reactor = framing.clientreactor(globalui, buffersends=False)

        request, action, meta = reactor.callcommand(b'foo', {})

        self.assertEqual(action, b'sendframes')
        for f in meta[b'framegen']:
            pass

        action, meta = sendframe(
            reactor,
            ffs(b'%d 0 stream-begin command-response 0 foo' %
                request.requestid))
        self.assertEqual(action, b'responsedata')

        action, meta = sendframe(
            reactor,
            ffs(b'%d 0 0 command-response eos bar' % request.requestid))
        self.assertEqual(action, b'responsedata')

class RedirectTests(unittest.TestCase):
    def testredirect(self):
        reactor = framing.clientreactor(globalui, buffersends=False)

        redirect = {
            b'targets': [b'a', b'b'],
            b'hashes': [b'sha256'],
        }

        request, action, meta = reactor.callcommand(
            b'foo', {}, redirect=redirect)

        self.assertEqual(action, b'sendframes')

        frames = list(meta[b'framegen'])
        self.assertEqual(len(frames), 1)

        self.assertEqual(frames[0],
                         ffs(b'1 1 stream-begin command-request new '
                             b"cbor:{b'name': b'foo', "
                             b"b'redirect': {b'targets': [b'a', b'b'], "
                             b"b'hashes': [b'sha256']}}"))

class StreamSettingsTests(unittest.TestCase):
    def testnoflags(self):
        reactor = framing.clientreactor(globalui, buffersends=False)

        request, action, meta = reactor.callcommand(b'foo', {})
        for f in meta[b'framegen']:
            pass

        action, meta = sendframe(reactor,
            ffs(b'1 2 stream-begin stream-settings 0 '))

        self.assertEqual(action, b'error')
        self.assertEqual(meta, {
            b'message': b'stream encoding settings frame must have '
                        b'continuation or end of stream flag set',
        })

    def testconflictflags(self):
        reactor = framing.clientreactor(globalui, buffersends=False)

        request, action, meta = reactor.callcommand(b'foo', {})
        for f in meta[b'framegen']:
            pass

        action, meta = sendframe(reactor,
            ffs(b'1 2 stream-begin stream-settings continuation|eos '))

        self.assertEqual(action, b'error')
        self.assertEqual(meta, {
            b'message': b'stream encoding settings frame cannot have both '
                        b'continuation and end of stream flags set',
        })

    def testemptypayload(self):
        reactor = framing.clientreactor(globalui, buffersends=False)

        request, action, meta = reactor.callcommand(b'foo', {})
        for f in meta[b'framegen']:
            pass

        action, meta = sendframe(reactor,
            ffs(b'1 2 stream-begin stream-settings eos '))

        self.assertEqual(action, b'error')
        self.assertEqual(meta, {
            b'message': b'stream encoding settings frame did not contain '
                        b'CBOR data'
        })

    def testbadcbor(self):
        reactor = framing.clientreactor(globalui, buffersends=False)

        request, action, meta = reactor.callcommand(b'foo', {})
        for f in meta[b'framegen']:
            pass

        action, meta = sendframe(reactor,
            ffs(b'1 2 stream-begin stream-settings eos badvalue'))

        self.assertEqual(action, b'error')

    def testsingleobject(self):
        reactor = framing.clientreactor(globalui, buffersends=False)

        request, action, meta = reactor.callcommand(b'foo', {})
        for f in meta[b'framegen']:
            pass

        action, meta = sendframe(reactor,
            ffs(b'1 2 stream-begin stream-settings eos cbor:b"identity"'))

        self.assertEqual(action, b'noop')
        self.assertEqual(meta, {})

    def testmultipleobjects(self):
        reactor = framing.clientreactor(globalui, buffersends=False)

        request, action, meta = reactor.callcommand(b'foo', {})
        for f in meta[b'framegen']:
            pass

        data = b''.join([
            b''.join(cborutil.streamencode(b'identity')),
            b''.join(cborutil.streamencode({b'foo', b'bar'})),
        ])

        action, meta = sendframe(reactor,
            ffs(b'1 2 stream-begin stream-settings eos %s' % data))

        self.assertEqual(action, b'error')
        self.assertEqual(meta, {
            b'message': b'error setting stream decoder: identity decoder '
                        b'received unexpected additional values',
        })

    def testmultipleframes(self):
        reactor = framing.clientreactor(globalui, buffersends=False)

        request, action, meta = reactor.callcommand(b'foo', {})
        for f in meta[b'framegen']:
            pass

        data = b''.join(cborutil.streamencode(b'identity'))

        action, meta = sendframe(reactor,
            ffs(b'1 2 stream-begin stream-settings continuation %s' %
                data[0:3]))

        self.assertEqual(action, b'noop')
        self.assertEqual(meta, {})

        action, meta = sendframe(reactor,
            ffs(b'1 2 0 stream-settings eos %s' % data[3:]))

        self.assertEqual(action, b'noop')
        self.assertEqual(meta, {})

    def testinvalidencoder(self):
        reactor = framing.clientreactor(globalui, buffersends=False)

        request, action, meta = reactor.callcommand(b'foo', {})
        for f in meta[b'framegen']:
            pass

        action, meta = sendframe(reactor,
            ffs(b'1 2 stream-begin stream-settings eos cbor:b"badvalue"'))

        self.assertEqual(action, b'error')
        self.assertEqual(meta, {
            b'message': b'error setting stream decoder: unknown stream '
                        b'decoder: badvalue',
        })

    def testzlibencoding(self):
        reactor = framing.clientreactor(globalui, buffersends=False)

        request, action, meta = reactor.callcommand(b'foo', {})
        for f in meta[b'framegen']:
            pass

        action, meta = sendframe(reactor,
            ffs(b'%d 2 stream-begin stream-settings eos cbor:b"zlib"' %
                request.requestid))

        self.assertEqual(action, b'noop')
        self.assertEqual(meta, {})

        result = {
            b'status': b'ok',
        }
        encoded = b''.join(cborutil.streamencode(result))

        compressed = zlib.compress(encoded)
        self.assertEqual(zlib.decompress(compressed), encoded)

        action, meta = sendframe(reactor,
            ffs(b'%d 2 encoded command-response eos %s' %
                (request.requestid, compressed)))

        self.assertEqual(action, b'responsedata')
        self.assertEqual(meta[b'data'], encoded)

    def testzlibencodingsinglebyteframes(self):
        reactor = framing.clientreactor(globalui, buffersends=False)

        request, action, meta = reactor.callcommand(b'foo', {})
        for f in meta[b'framegen']:
            pass

        action, meta = sendframe(reactor,
            ffs(b'%d 2 stream-begin stream-settings eos cbor:b"zlib"' %
                request.requestid))

        self.assertEqual(action, b'noop')
        self.assertEqual(meta, {})

        result = {
            b'status': b'ok',
        }
        encoded = b''.join(cborutil.streamencode(result))

        compressed = zlib.compress(encoded)
        self.assertEqual(zlib.decompress(compressed), encoded)

        chunks = []

        for i in range(len(compressed)):
            char = compressed[i:i + 1]
            if char == b'\\':
                char = b'\\\\'
            action, meta = sendframe(reactor,
                ffs(b'%d 2 encoded command-response continuation %s' %
                    (request.requestid, char)))

            self.assertEqual(action, b'responsedata')
            chunks.append(meta[b'data'])
            self.assertTrue(meta[b'expectmore'])
            self.assertFalse(meta[b'eos'])

        # zlib will have the full data decoded at this point, even though
        # we haven't flushed.
        self.assertEqual(b''.join(chunks), encoded)

        # End the stream for good measure.
        action, meta = sendframe(reactor,
            ffs(b'%d 2 stream-end command-response eos ' % request.requestid))

        self.assertEqual(action, b'responsedata')
        self.assertEqual(meta[b'data'], b'')
        self.assertFalse(meta[b'expectmore'])
        self.assertTrue(meta[b'eos'])

    def testzlibmultipleresponses(self):
        # We feed in zlib compressed data on the same stream but belonging to
        # 2 different requests. This tests our flushing behavior.
        reactor = framing.clientreactor(globalui, buffersends=False,
                                        hasmultiplesend=True)

        request1, action, meta = reactor.callcommand(b'foo', {})
        for f in meta[b'framegen']:
            pass

        request2, action, meta = reactor.callcommand(b'foo', {})
        for f in meta[b'framegen']:
            pass

        outstream = framing.outputstream(2)
        outstream.setencoder(globalui, b'zlib')

        response1 = b''.join(cborutil.streamencode({
            b'status': b'ok',
            b'extra': b'response1' * 10,
        }))

        response2 = b''.join(cborutil.streamencode({
            b'status': b'error',
            b'extra': b'response2' * 10,
        }))

        action, meta = sendframe(reactor,
            ffs(b'%d 2 stream-begin stream-settings eos cbor:b"zlib"' %
                request1.requestid))

        self.assertEqual(action, b'noop')
        self.assertEqual(meta, {})

        # Feeding partial data in won't get anything useful out.
        action, meta = sendframe(reactor,
            ffs(b'%d 2 encoded command-response continuation %s' % (
                request1.requestid, outstream.encode(response1))))
        self.assertEqual(action, b'responsedata')
        self.assertEqual(meta[b'data'], b'')

        # But flushing data at both ends will get our original data.
        action, meta = sendframe(reactor,
            ffs(b'%d 2 encoded command-response eos %s' % (
                request1.requestid, outstream.flush())))
        self.assertEqual(action, b'responsedata')
        self.assertEqual(meta[b'data'], response1)

        # We should be able to reuse the compressor/decompressor for the
        # 2nd response.
        action, meta = sendframe(reactor,
            ffs(b'%d 2 encoded command-response continuation %s' % (
                request2.requestid, outstream.encode(response2))))
        self.assertEqual(action, b'responsedata')
        self.assertEqual(meta[b'data'], b'')

        action, meta = sendframe(reactor,
            ffs(b'%d 2 encoded command-response eos %s' % (
                request2.requestid, outstream.flush())))
        self.assertEqual(action, b'responsedata')
        self.assertEqual(meta[b'data'], response2)

    @unittest.skipUnless(zstd, 'zstd not available')
    def testzstd8mbencoding(self):
        reactor = framing.clientreactor(globalui, buffersends=False)

        request, action, meta = reactor.callcommand(b'foo', {})
        for f in meta[b'framegen']:
            pass

        action, meta = sendframe(reactor,
            ffs(b'%d 2 stream-begin stream-settings eos cbor:b"zstd-8mb"' %
                request.requestid))

        self.assertEqual(action, b'noop')
        self.assertEqual(meta, {})

        result = {
            b'status': b'ok',
        }
        encoded = b''.join(cborutil.streamencode(result))

        encoder = framing.zstd8mbencoder(globalui)
        compressed = encoder.encode(encoded) + encoder.finish()
        self.assertEqual(zstd.ZstdDecompressor().decompress(
            compressed, max_output_size=len(encoded)), encoded)

        action, meta = sendframe(reactor,
            ffs(b'%d 2 encoded command-response eos %s' %
                (request.requestid, compressed)))

        self.assertEqual(action, b'responsedata')
        self.assertEqual(meta[b'data'], encoded)

    @unittest.skipUnless(zstd, 'zstd not available')
    def testzstd8mbencodingsinglebyteframes(self):
        reactor = framing.clientreactor(globalui, buffersends=False)

        request, action, meta = reactor.callcommand(b'foo', {})
        for f in meta[b'framegen']:
            pass

        action, meta = sendframe(reactor,
            ffs(b'%d 2 stream-begin stream-settings eos cbor:b"zstd-8mb"' %
                request.requestid))

        self.assertEqual(action, b'noop')
        self.assertEqual(meta, {})

        result = {
            b'status': b'ok',
        }
        encoded = b''.join(cborutil.streamencode(result))

        compressed = zstd.ZstdCompressor().compress(encoded)
        self.assertEqual(zstd.ZstdDecompressor().decompress(compressed),
                         encoded)

        chunks = []

        for i in range(len(compressed)):
            char = compressed[i:i + 1]
            if char == b'\\':
                char = b'\\\\'
            action, meta = sendframe(reactor,
                ffs(b'%d 2 encoded command-response continuation %s' %
                    (request.requestid, char)))

            self.assertEqual(action, b'responsedata')
            chunks.append(meta[b'data'])
            self.assertTrue(meta[b'expectmore'])
            self.assertFalse(meta[b'eos'])

        # zstd decompressor will flush at frame boundaries.
        self.assertEqual(b''.join(chunks), encoded)

        # End the stream for good measure.
        action, meta = sendframe(reactor,
            ffs(b'%d 2 stream-end command-response eos ' % request.requestid))

        self.assertEqual(action, b'responsedata')
        self.assertEqual(meta[b'data'], b'')
        self.assertFalse(meta[b'expectmore'])
        self.assertTrue(meta[b'eos'])

    @unittest.skipUnless(zstd, 'zstd not available')
    def testzstd8mbmultipleresponses(self):
        # We feed in zstd compressed data on the same stream but belonging to
        # 2 different requests. This tests our flushing behavior.
        reactor = framing.clientreactor(globalui, buffersends=False,
                                        hasmultiplesend=True)

        request1, action, meta = reactor.callcommand(b'foo', {})
        for f in meta[b'framegen']:
            pass

        request2, action, meta = reactor.callcommand(b'foo', {})
        for f in meta[b'framegen']:
            pass

        outstream = framing.outputstream(2)
        outstream.setencoder(globalui, b'zstd-8mb')

        response1 = b''.join(cborutil.streamencode({
            b'status': b'ok',
            b'extra': b'response1' * 10,
        }))

        response2 = b''.join(cborutil.streamencode({
            b'status': b'error',
            b'extra': b'response2' * 10,
        }))

        action, meta = sendframe(reactor,
            ffs(b'%d 2 stream-begin stream-settings eos cbor:b"zstd-8mb"' %
                request1.requestid))

        self.assertEqual(action, b'noop')
        self.assertEqual(meta, {})

        # Feeding partial data in won't get anything useful out.
        action, meta = sendframe(reactor,
            ffs(b'%d 2 encoded command-response continuation %s' % (
                request1.requestid, outstream.encode(response1))))
        self.assertEqual(action, b'responsedata')
        self.assertEqual(meta[b'data'], b'')

        # But flushing data at both ends will get our original data.
        action, meta = sendframe(reactor,
            ffs(b'%d 2 encoded command-response eos %s' % (
                request1.requestid, outstream.flush())))
        self.assertEqual(action, b'responsedata')
        self.assertEqual(meta[b'data'], response1)

        # We should be able to reuse the compressor/decompressor for the
        # 2nd response.
        action, meta = sendframe(reactor,
            ffs(b'%d 2 encoded command-response continuation %s' % (
                request2.requestid, outstream.encode(response2))))
        self.assertEqual(action, b'responsedata')
        self.assertEqual(meta[b'data'], b'')

        action, meta = sendframe(reactor,
            ffs(b'%d 2 encoded command-response eos %s' % (
                request2.requestid, outstream.flush())))
        self.assertEqual(action, b'responsedata')
        self.assertEqual(meta[b'data'], response2)

if __name__ == '__main__':
    import silenttestrunner
    silenttestrunner.main(__name__)
