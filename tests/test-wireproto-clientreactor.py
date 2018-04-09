from __future__ import absolute_import

import unittest

from mercurial import (
    error,
    wireprotoframing as framing,
)

class SingleSendTests(unittest.TestCase):
    """A reactor that can only send once rejects subsequent sends."""
    def testbasic(self):
        reactor = framing.clientreactor(hasmultiplesend=False, buffersends=True)

        request, action, meta = reactor.callcommand(b'foo', {})
        self.assertEqual(request.state, 'pending')
        self.assertEqual(action, 'noop')

        action, meta = reactor.flushcommands()
        self.assertEqual(action, 'sendframes')

        for frame in meta['framegen']:
            self.assertEqual(request.state, 'sending')

        self.assertEqual(request.state, 'sent')

        with self.assertRaisesRegexp(error.ProgrammingError,
                                     'cannot issue new commands'):
            reactor.callcommand(b'foo', {})

        with self.assertRaisesRegexp(error.ProgrammingError,
                                     'cannot issue new commands'):
            reactor.callcommand(b'foo', {})

class NoBufferTests(unittest.TestCase):
    """A reactor without send buffering sends requests immediately."""
    def testbasic(self):
        reactor = framing.clientreactor(hasmultiplesend=True, buffersends=False)

        request, action, meta = reactor.callcommand(b'command1', {})
        self.assertEqual(request.requestid, 1)
        self.assertEqual(action, 'sendframes')

        self.assertEqual(request.state, 'pending')

        for frame in meta['framegen']:
            self.assertEqual(request.state, 'sending')

        self.assertEqual(request.state, 'sent')

        action, meta = reactor.flushcommands()
        self.assertEqual(action, 'noop')

        # And we can send another command.
        request, action, meta = reactor.callcommand(b'command2', {})
        self.assertEqual(request.requestid, 3)
        self.assertEqual(action, 'sendframes')

        for frame in meta['framegen']:
            self.assertEqual(request.state, 'sending')

        self.assertEqual(request.state, 'sent')

if __name__ == '__main__':
    import silenttestrunner
    silenttestrunner.main(__name__)
