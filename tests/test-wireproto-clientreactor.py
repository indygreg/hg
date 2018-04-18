from __future__ import absolute_import

import unittest

from mercurial import (
    error,
    wireprotoframing as framing,
)

ffs = framing.makeframefromhumanstring

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
        reactor = framing.clientreactor(hasmultiplesend=False, buffersends=True)

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
        reactor = framing.clientreactor(hasmultiplesend=True, buffersends=False)

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
        reactor = framing.clientreactor()

        action, meta = sendframe(reactor, ffs(b'1 1 0 1 0 foo'))
        self.assertEqual(action, b'error')
        self.assertEqual(meta[b'message'],
                         b'received frame with odd numbered stream ID: 1')

    def testunknownstream(self):
        reactor = framing.clientreactor()

        action, meta = sendframe(reactor, ffs(b'1 0 0 1 0 foo'))
        self.assertEqual(action, b'error')
        self.assertEqual(meta[b'message'],
                         b'received frame on unknown stream without beginning '
                         b'of stream flag set')

    def testunhandledframetype(self):
        reactor = framing.clientreactor(buffersends=False)

        request, action, meta = reactor.callcommand(b'foo', {})
        for frame in meta[b'framegen']:
            pass

        with self.assertRaisesRegex(error.ProgrammingError,
                                     'unhandled frame type'):
            sendframe(reactor, ffs(b'1 0 stream-begin text-output 0 foo'))

class StreamTests(unittest.TestCase):
    def testmultipleresponseframes(self):
        reactor = framing.clientreactor(buffersends=False)

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

if __name__ == '__main__':
    import silenttestrunner
    silenttestrunner.main(__name__)
