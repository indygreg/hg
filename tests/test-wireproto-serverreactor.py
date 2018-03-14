from __future__ import absolute_import, print_function

import unittest

from mercurial import (
    util,
    wireprotoframing as framing,
)

ffs = framing.makeframefromhumanstring

def makereactor():
    return framing.serverreactor()

def sendframes(reactor, gen):
    """Send a generator of frame bytearray to a reactor.

    Emits a generator of results from ``onframerecv()`` calls.
    """
    for frame in gen:
        frametype, frameflags, framelength = framing.parseheader(frame)
        payload = frame[framing.FRAME_HEADER_SIZE:]
        assert len(payload) == framelength

        yield reactor.onframerecv(frametype, frameflags, payload)

def sendcommandframes(reactor, cmd, args, datafh=None):
    """Generate frames to run a command and send them to a reactor."""
    return sendframes(reactor, framing.createcommandframes(cmd, args, datafh))

class FrameTests(unittest.TestCase):
    def testdataexactframesize(self):
        data = util.bytesio(b'x' * framing.DEFAULT_MAX_FRAME_SIZE)

        frames = list(framing.createcommandframes(b'command', {}, data))
        self.assertEqual(frames, [
            ffs(b'command-name have-data command'),
            ffs(b'command-data continuation %s' % data.getvalue()),
            ffs(b'command-data eos ')
        ])

    def testdatamultipleframes(self):
        data = util.bytesio(b'x' * (framing.DEFAULT_MAX_FRAME_SIZE + 1))
        frames = list(framing.createcommandframes(b'command', {}, data))
        self.assertEqual(frames, [
            ffs(b'command-name have-data command'),
            ffs(b'command-data continuation %s' % (
                b'x' * framing.DEFAULT_MAX_FRAME_SIZE)),
            ffs(b'command-data eos x'),
        ])

    def testargsanddata(self):
        data = util.bytesio(b'x' * 100)

        frames = list(framing.createcommandframes(b'command', {
            b'key1': b'key1value',
            b'key2': b'key2value',
            b'key3': b'key3value',
        }, data))

        self.assertEqual(frames, [
            ffs(b'command-name have-args|have-data command'),
            ffs(br'command-argument 0 \x04\x00\x09\x00key1key1value'),
            ffs(br'command-argument 0 \x04\x00\x09\x00key2key2value'),
            ffs(br'command-argument eoa \x04\x00\x09\x00key3key3value'),
            ffs(b'command-data eos %s' % data.getvalue()),
        ])

class ServerReactorTests(unittest.TestCase):
    def _sendsingleframe(self, reactor, s):
        results = list(sendframes(reactor, [ffs(s)]))
        self.assertEqual(len(results), 1)

        return results[0]

    def assertaction(self, res, expected):
        self.assertIsInstance(res, tuple)
        self.assertEqual(len(res), 2)
        self.assertIsInstance(res[1], dict)
        self.assertEqual(res[0], expected)

    def assertframesequal(self, frames, framestrings):
        expected = [ffs(s) for s in framestrings]
        self.assertEqual(list(frames), expected)

    def test1framecommand(self):
        """Receiving a command in a single frame yields request to run it."""
        reactor = makereactor()
        results = list(sendcommandframes(reactor, b'mycommand', {}))
        self.assertEqual(len(results), 1)
        self.assertaction(results[0], 'runcommand')
        self.assertEqual(results[0][1], {
            'command': b'mycommand',
            'args': {},
            'data': None,
        })

    def test1argument(self):
        reactor = makereactor()
        results = list(sendcommandframes(reactor, b'mycommand',
                                         {b'foo': b'bar'}))
        self.assertEqual(len(results), 2)
        self.assertaction(results[0], 'wantframe')
        self.assertaction(results[1], 'runcommand')
        self.assertEqual(results[1][1], {
            'command': b'mycommand',
            'args': {b'foo': b'bar'},
            'data': None,
        })

    def testmultiarguments(self):
        reactor = makereactor()
        results = list(sendcommandframes(reactor, b'mycommand',
                                         {b'foo': b'bar', b'biz': b'baz'}))
        self.assertEqual(len(results), 3)
        self.assertaction(results[0], 'wantframe')
        self.assertaction(results[1], 'wantframe')
        self.assertaction(results[2], 'runcommand')
        self.assertEqual(results[2][1], {
            'command': b'mycommand',
            'args': {b'foo': b'bar', b'biz': b'baz'},
            'data': None,
        })

    def testsimplecommanddata(self):
        reactor = makereactor()
        results = list(sendcommandframes(reactor, b'mycommand', {},
                                         util.bytesio(b'data!')))
        self.assertEqual(len(results), 2)
        self.assertaction(results[0], 'wantframe')
        self.assertaction(results[1], 'runcommand')
        self.assertEqual(results[1][1], {
            'command': b'mycommand',
            'args': {},
            'data': b'data!',
        })

    def testmultipledataframes(self):
        frames = [
            ffs(b'command-name have-data mycommand'),
            ffs(b'command-data continuation data1'),
            ffs(b'command-data continuation data2'),
            ffs(b'command-data eos data3'),
        ]

        reactor = makereactor()
        results = list(sendframes(reactor, frames))
        self.assertEqual(len(results), 4)
        for i in range(3):
            self.assertaction(results[i], 'wantframe')
        self.assertaction(results[3], 'runcommand')
        self.assertEqual(results[3][1], {
            'command': b'mycommand',
            'args': {},
            'data': b'data1data2data3',
        })

    def testargumentanddata(self):
        frames = [
            ffs(b'command-name have-args|have-data command'),
            ffs(br'command-argument 0 \x03\x00\x03\x00keyval'),
            ffs(br'command-argument eoa \x03\x00\x03\x00foobar'),
            ffs(b'command-data continuation value1'),
            ffs(b'command-data eos value2'),
        ]

        reactor = makereactor()
        results = list(sendframes(reactor, frames))

        self.assertaction(results[-1], 'runcommand')
        self.assertEqual(results[-1][1], {
            'command': b'command',
            'args': {
                b'key': b'val',
                b'foo': b'bar',
            },
            'data': b'value1value2',
        })

    def testunexpectedcommandargument(self):
        """Command argument frame when not running a command is an error."""
        result = self._sendsingleframe(makereactor(),
                                       b'command-argument 0 ignored')
        self.assertaction(result, 'error')
        self.assertEqual(result[1], {
            'message': b'expected command frame; got 2',
        })

    def testunexpectedcommanddata(self):
        """Command argument frame when not running a command is an error."""
        result = self._sendsingleframe(makereactor(),
                                       b'command-data 0 ignored')
        self.assertaction(result, 'error')
        self.assertEqual(result[1], {
            'message': b'expected command frame; got 3',
        })

    def testmissingcommandframeflags(self):
        """Command name frame must have flags set."""
        result = self._sendsingleframe(makereactor(),
                                       b'command-name 0 command')
        self.assertaction(result, 'error')
        self.assertEqual(result[1], {
            'message': b'missing frame flags on command frame',
        })

    def testmissingargumentframe(self):
        frames = [
            ffs(b'command-name have-args command'),
            ffs(b'command-name 0 ignored'),
        ]

        results = list(sendframes(makereactor(), frames))
        self.assertEqual(len(results), 2)
        self.assertaction(results[0], 'wantframe')
        self.assertaction(results[1], 'error')
        self.assertEqual(results[1][1], {
            'message': b'expected command argument frame; got 1',
        })

    def testincompleteargumentname(self):
        """Argument frame with incomplete name."""
        frames = [
            ffs(b'command-name have-args command1'),
            ffs(br'command-argument eoa \x04\x00\xde\xadfoo'),
        ]

        results = list(sendframes(makereactor(), frames))
        self.assertEqual(len(results), 2)
        self.assertaction(results[0], 'wantframe')
        self.assertaction(results[1], 'error')
        self.assertEqual(results[1][1], {
            'message': b'malformed argument frame: partial argument name',
        })

    def testincompleteargumentvalue(self):
        """Argument frame with incomplete value."""
        frames = [
            ffs(b'command-name have-args command'),
            ffs(br'command-argument eoa \x03\x00\xaa\xaafoopartialvalue'),
        ]

        results = list(sendframes(makereactor(), frames))
        self.assertEqual(len(results), 2)
        self.assertaction(results[0], 'wantframe')
        self.assertaction(results[1], 'error')
        self.assertEqual(results[1][1], {
            'message': b'malformed argument frame: partial argument value',
        })

    def testmissingcommanddataframe(self):
        frames = [
            ffs(b'command-name have-data command1'),
            ffs(b'command-name eos command2'),
        ]
        results = list(sendframes(makereactor(), frames))
        self.assertEqual(len(results), 2)
        self.assertaction(results[0], 'wantframe')
        self.assertaction(results[1], 'error')
        self.assertEqual(results[1][1], {
            'message': b'expected command data frame; got 1',
        })

    def testmissingcommanddataframeflags(self):
        frames = [
            ffs(b'command-name have-data command1'),
            ffs(b'command-data 0 data'),
        ]
        results = list(sendframes(makereactor(), frames))
        self.assertEqual(len(results), 2)
        self.assertaction(results[0], 'wantframe')
        self.assertaction(results[1], 'error')
        self.assertEqual(results[1][1], {
            'message': b'command data frame without flags',
        })

    def testsimpleresponse(self):
        """Bytes response to command sends result frames."""
        reactor = makereactor()
        list(sendcommandframes(reactor, b'mycommand', {}))

        result = reactor.onbytesresponseready(b'response')
        self.assertaction(result, 'sendframes')
        self.assertframesequal(result[1]['framegen'], [
            b'bytes-response eos response',
        ])

    def testmultiframeresponse(self):
        """Bytes response spanning multiple frames is handled."""
        first = b'x' * framing.DEFAULT_MAX_FRAME_SIZE
        second = b'y' * 100

        reactor = makereactor()
        list(sendcommandframes(reactor, b'mycommand', {}))

        result = reactor.onbytesresponseready(first + second)
        self.assertaction(result, 'sendframes')
        self.assertframesequal(result[1]['framegen'], [
            b'bytes-response continuation %s' % first,
            b'bytes-response eos %s' % second,
        ])

    def testapplicationerror(self):
        reactor = makereactor()
        list(sendcommandframes(reactor, b'mycommand', {}))

        result = reactor.onapplicationerror(b'some message')
        self.assertaction(result, 'sendframes')
        self.assertframesequal(result[1]['framegen'], [
            b'error-response application some message',
        ])

if __name__ == '__main__':
    import silenttestrunner
    silenttestrunner.main(__name__)
