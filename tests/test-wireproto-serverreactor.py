from __future__ import absolute_import, print_function

import unittest

from mercurial import (
    util,
    wireprotoframing as framing,
)

ffs = framing.makeframefromhumanstring

def makereactor(deferoutput=False):
    return framing.serverreactor(deferoutput=deferoutput)

def sendframes(reactor, gen):
    """Send a generator of frame bytearray to a reactor.

    Emits a generator of results from ``onframerecv()`` calls.
    """
    for frame in gen:
        header = framing.parseheader(frame)
        payload = frame[framing.FRAME_HEADER_SIZE:]
        assert len(payload) == header.length

        yield reactor.onframerecv(framing.frame(header.requestid,
                                                header.typeid,
                                                header.flags,
                                                payload))

def sendcommandframes(reactor, stream, rid, cmd, args, datafh=None):
    """Generate frames to run a command and send them to a reactor."""
    return sendframes(reactor,
                      framing.createcommandframes(stream, rid, cmd, args,
                                                  datafh))

class FrameTests(unittest.TestCase):
    def testdataexactframesize(self):
        data = util.bytesio(b'x' * framing.DEFAULT_MAX_FRAME_SIZE)

        stream = framing.stream()
        frames = list(framing.createcommandframes(stream, 1, b'command',
                                                  {}, data))
        self.assertEqual(frames, [
            ffs(b'1 command-name have-data command'),
            ffs(b'1 command-data continuation %s' % data.getvalue()),
            ffs(b'1 command-data eos ')
        ])

    def testdatamultipleframes(self):
        data = util.bytesio(b'x' * (framing.DEFAULT_MAX_FRAME_SIZE + 1))

        stream = framing.stream()
        frames = list(framing.createcommandframes(stream, 1, b'command', {},
                                                  data))
        self.assertEqual(frames, [
            ffs(b'1 command-name have-data command'),
            ffs(b'1 command-data continuation %s' % (
                b'x' * framing.DEFAULT_MAX_FRAME_SIZE)),
            ffs(b'1 command-data eos x'),
        ])

    def testargsanddata(self):
        data = util.bytesio(b'x' * 100)

        stream = framing.stream()
        frames = list(framing.createcommandframes(stream, 1, b'command', {
            b'key1': b'key1value',
            b'key2': b'key2value',
            b'key3': b'key3value',
        }, data))

        self.assertEqual(frames, [
            ffs(b'1 command-name have-args|have-data command'),
            ffs(br'1 command-argument 0 \x04\x00\x09\x00key1key1value'),
            ffs(br'1 command-argument 0 \x04\x00\x09\x00key2key2value'),
            ffs(br'1 command-argument eoa \x04\x00\x09\x00key3key3value'),
            ffs(b'1 command-data eos %s' % data.getvalue()),
        ])

    def testtextoutputexcessiveargs(self):
        """At most 255 formatting arguments are allowed."""
        with self.assertRaisesRegexp(ValueError,
                                     'cannot use more than 255 formatting'):
            args = [b'x' for i in range(256)]
            list(framing.createtextoutputframe(None, 1,
                                               [(b'bleh', args, [])]))

    def testtextoutputexcessivelabels(self):
        """At most 255 labels are allowed."""
        with self.assertRaisesRegexp(ValueError,
                                     'cannot use more than 255 labels'):
            labels = [b'l' for i in range(256)]
            list(framing.createtextoutputframe(None, 1,
                                               [(b'bleh', [], labels)]))

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

    def testtextoutputtoolongformatstring(self):
        with self.assertRaisesRegexp(ValueError,
                                     'formatting string cannot be longer than'):
            list(framing.createtextoutputframe(None, 1, [
                (b'x' * 65536, [], [])]))

    def testtextoutputtoolongargumentstring(self):
        with self.assertRaisesRegexp(ValueError,
                                     'argument string cannot be longer than'):
            list(framing.createtextoutputframe(None, 1, [
                (b'bleh', [b'x' * 65536], [])]))

    def testtextoutputtoolonglabelstring(self):
        with self.assertRaisesRegexp(ValueError,
                                     'label string cannot be longer than'):
            list(framing.createtextoutputframe(None, 1, [
                (b'bleh', [], [b'x' * 65536])]))

    def testtextoutput1simpleatom(self):
        stream = framing.stream()
        val = list(framing.createtextoutputframe(stream, 1, [
            (b'foo', [], [])]))

        self.assertEqual(val, [
            ffs(br'1 text-output 0 \x03\x00\x00\x00foo'),
        ])

    def testtextoutput2simpleatoms(self):
        stream = framing.stream()
        val = list(framing.createtextoutputframe(stream, 1, [
            (b'foo', [], []),
            (b'bar', [], []),
        ]))

        self.assertEqual(val, [
            ffs(br'1 text-output 0 \x03\x00\x00\x00foo\x03\x00\x00\x00bar'),
        ])

    def testtextoutput1arg(self):
        stream = framing.stream()
        val = list(framing.createtextoutputframe(stream, 1, [
            (b'foo %s', [b'val1'], []),
        ]))

        self.assertEqual(val, [
            ffs(br'1 text-output 0 \x06\x00\x00\x01\x04\x00foo %sval1'),
        ])

    def testtextoutput2arg(self):
        stream = framing.stream()
        val = list(framing.createtextoutputframe(stream, 1, [
            (b'foo %s %s', [b'val', b'value'], []),
        ]))

        self.assertEqual(val, [
            ffs(br'1 text-output 0 \x09\x00\x00\x02\x03\x00\x05\x00'
                br'foo %s %svalvalue'),
        ])

    def testtextoutput1label(self):
        stream = framing.stream()
        val = list(framing.createtextoutputframe(stream, 1, [
            (b'foo', [], [b'label']),
        ]))

        self.assertEqual(val, [
            ffs(br'1 text-output 0 \x03\x00\x01\x00\x05foolabel'),
        ])

    def testargandlabel(self):
        stream = framing.stream()
        val = list(framing.createtextoutputframe(stream, 1, [
            (b'foo %s', [b'arg'], [b'label']),
        ]))

        self.assertEqual(val, [
            ffs(br'1 text-output 0 \x06\x00\x01\x01\x05\x03\x00foo %slabelarg'),
        ])

class ServerReactorTests(unittest.TestCase):
    def _sendsingleframe(self, reactor, f):
        results = list(sendframes(reactor, [f]))
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
        stream = framing.stream()
        results = list(sendcommandframes(reactor, stream, 1, b'mycommand', {}))
        self.assertEqual(len(results), 1)
        self.assertaction(results[0], 'runcommand')
        self.assertEqual(results[0][1], {
            'requestid': 1,
            'command': b'mycommand',
            'args': {},
            'data': None,
        })

        result = reactor.oninputeof()
        self.assertaction(result, 'noop')

    def test1argument(self):
        reactor = makereactor()
        stream = framing.stream()
        results = list(sendcommandframes(reactor, stream, 41, b'mycommand',
                                         {b'foo': b'bar'}))
        self.assertEqual(len(results), 2)
        self.assertaction(results[0], 'wantframe')
        self.assertaction(results[1], 'runcommand')
        self.assertEqual(results[1][1], {
            'requestid': 41,
            'command': b'mycommand',
            'args': {b'foo': b'bar'},
            'data': None,
        })

    def testmultiarguments(self):
        reactor = makereactor()
        stream = framing.stream()
        results = list(sendcommandframes(reactor, stream, 1, b'mycommand',
                                         {b'foo': b'bar', b'biz': b'baz'}))
        self.assertEqual(len(results), 3)
        self.assertaction(results[0], 'wantframe')
        self.assertaction(results[1], 'wantframe')
        self.assertaction(results[2], 'runcommand')
        self.assertEqual(results[2][1], {
            'requestid': 1,
            'command': b'mycommand',
            'args': {b'foo': b'bar', b'biz': b'baz'},
            'data': None,
        })

    def testsimplecommanddata(self):
        reactor = makereactor()
        stream = framing.stream()
        results = list(sendcommandframes(reactor, stream, 1, b'mycommand', {},
                                         util.bytesio(b'data!')))
        self.assertEqual(len(results), 2)
        self.assertaction(results[0], 'wantframe')
        self.assertaction(results[1], 'runcommand')
        self.assertEqual(results[1][1], {
            'requestid': 1,
            'command': b'mycommand',
            'args': {},
            'data': b'data!',
        })

    def testmultipledataframes(self):
        frames = [
            ffs(b'1 command-name have-data mycommand'),
            ffs(b'1 command-data continuation data1'),
            ffs(b'1 command-data continuation data2'),
            ffs(b'1 command-data eos data3'),
        ]

        reactor = makereactor()
        results = list(sendframes(reactor, frames))
        self.assertEqual(len(results), 4)
        for i in range(3):
            self.assertaction(results[i], 'wantframe')
        self.assertaction(results[3], 'runcommand')
        self.assertEqual(results[3][1], {
            'requestid': 1,
            'command': b'mycommand',
            'args': {},
            'data': b'data1data2data3',
        })

    def testargumentanddata(self):
        frames = [
            ffs(b'1 command-name have-args|have-data command'),
            ffs(br'1 command-argument 0 \x03\x00\x03\x00keyval'),
            ffs(br'1 command-argument eoa \x03\x00\x03\x00foobar'),
            ffs(b'1 command-data continuation value1'),
            ffs(b'1 command-data eos value2'),
        ]

        reactor = makereactor()
        results = list(sendframes(reactor, frames))

        self.assertaction(results[-1], 'runcommand')
        self.assertEqual(results[-1][1], {
            'requestid': 1,
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
                                       ffs(b'1 command-argument 0 ignored'))
        self.assertaction(result, 'error')
        self.assertEqual(result[1], {
            'message': b'expected command frame; got 2',
        })

    def testunexpectedcommandargumentreceiving(self):
        """Same as above but the command is receiving."""
        results = list(sendframes(makereactor(), [
            ffs(b'1 command-name have-data command'),
            ffs(b'1 command-argument eoa ignored'),
        ]))

        self.assertaction(results[1], 'error')
        self.assertEqual(results[1][1], {
            'message': b'received command argument frame for request that is '
                       b'not expecting arguments: 1',
        })

    def testunexpectedcommanddata(self):
        """Command argument frame when not running a command is an error."""
        result = self._sendsingleframe(makereactor(),
                                       ffs(b'1 command-data 0 ignored'))
        self.assertaction(result, 'error')
        self.assertEqual(result[1], {
            'message': b'expected command frame; got 3',
        })

    def testunexpectedcommanddatareceiving(self):
        """Same as above except the command is receiving."""
        results = list(sendframes(makereactor(), [
            ffs(b'1 command-name have-args command'),
            ffs(b'1 command-data eos ignored'),
        ]))

        self.assertaction(results[1], 'error')
        self.assertEqual(results[1][1], {
            'message': b'received command data frame for request that is not '
                       b'expecting data: 1',
        })

    def testmissingcommandframeflags(self):
        """Command name frame must have flags set."""
        result = self._sendsingleframe(makereactor(),
                                       ffs(b'1 command-name 0 command'))
        self.assertaction(result, 'error')
        self.assertEqual(result[1], {
            'message': b'missing frame flags on command frame',
        })

    def testconflictingrequestidallowed(self):
        """Multiple fully serviced commands with same request ID is allowed."""
        reactor = makereactor()
        results = []
        outstream = framing.stream()
        results.append(self._sendsingleframe(
            reactor, ffs(b'1 command-name eos command')))
        result = reactor.onbytesresponseready(outstream, 1, b'response1')
        self.assertaction(result, 'sendframes')
        list(result[1]['framegen'])
        results.append(self._sendsingleframe(
            reactor, ffs(b'1 command-name eos command')))
        result = reactor.onbytesresponseready(outstream, 1, b'response2')
        self.assertaction(result, 'sendframes')
        list(result[1]['framegen'])
        results.append(self._sendsingleframe(
            reactor, ffs(b'1 command-name eos command')))
        result = reactor.onbytesresponseready(outstream, 1, b'response3')
        self.assertaction(result, 'sendframes')
        list(result[1]['framegen'])

        for i in range(3):
            self.assertaction(results[i], 'runcommand')
            self.assertEqual(results[i][1], {
                'requestid': 1,
                'command': b'command',
                'args': {},
                'data': None,
            })

    def testconflictingrequestid(self):
        """Request ID for new command matching in-flight command is illegal."""
        results = list(sendframes(makereactor(), [
            ffs(b'1 command-name have-args command'),
            ffs(b'1 command-name eos command'),
        ]))

        self.assertaction(results[0], 'wantframe')
        self.assertaction(results[1], 'error')
        self.assertEqual(results[1][1], {
            'message': b'request with ID 1 already received',
        })

    def testinterleavedcommands(self):
        results = list(sendframes(makereactor(), [
            ffs(b'1 command-name have-args command1'),
            ffs(b'3 command-name have-args command3'),
            ffs(br'1 command-argument 0 \x03\x00\x03\x00foobar'),
            ffs(br'3 command-argument 0 \x03\x00\x03\x00bizbaz'),
            ffs(br'3 command-argument eoa \x03\x00\x03\x00keyval'),
            ffs(br'1 command-argument eoa \x04\x00\x03\x00key1val'),
        ]))

        self.assertEqual([t[0] for t in results], [
            'wantframe',
            'wantframe',
            'wantframe',
            'wantframe',
            'runcommand',
            'runcommand',
        ])

        self.assertEqual(results[4][1], {
            'requestid': 3,
            'command': 'command3',
            'args': {b'biz': b'baz', b'key': b'val'},
            'data': None,
        })
        self.assertEqual(results[5][1], {
            'requestid': 1,
            'command': 'command1',
            'args': {b'foo': b'bar', b'key1': b'val'},
            'data': None,
        })

    def testmissingargumentframe(self):
        # This test attempts to test behavior when reactor has an incomplete
        # command request waiting on argument data. But it doesn't handle that
        # scenario yet. So this test does nothing of value.
        frames = [
            ffs(b'1 command-name have-args command'),
        ]

        results = list(sendframes(makereactor(), frames))
        self.assertaction(results[0], 'wantframe')

    def testincompleteargumentname(self):
        """Argument frame with incomplete name."""
        frames = [
            ffs(b'1 command-name have-args command1'),
            ffs(br'1 command-argument eoa \x04\x00\xde\xadfoo'),
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
            ffs(b'1 command-name have-args command'),
            ffs(br'1 command-argument eoa \x03\x00\xaa\xaafoopartialvalue'),
        ]

        results = list(sendframes(makereactor(), frames))
        self.assertEqual(len(results), 2)
        self.assertaction(results[0], 'wantframe')
        self.assertaction(results[1], 'error')
        self.assertEqual(results[1][1], {
            'message': b'malformed argument frame: partial argument value',
        })

    def testmissingcommanddataframe(self):
        # The reactor doesn't currently handle partially received commands.
        # So this test is failing to do anything with request 1.
        frames = [
            ffs(b'1 command-name have-data command1'),
            ffs(b'3 command-name eos command2'),
        ]
        results = list(sendframes(makereactor(), frames))
        self.assertEqual(len(results), 2)
        self.assertaction(results[0], 'wantframe')
        self.assertaction(results[1], 'runcommand')

    def testmissingcommanddataframeflags(self):
        frames = [
            ffs(b'1 command-name have-data command1'),
            ffs(b'1 command-data 0 data'),
        ]
        results = list(sendframes(makereactor(), frames))
        self.assertEqual(len(results), 2)
        self.assertaction(results[0], 'wantframe')
        self.assertaction(results[1], 'error')
        self.assertEqual(results[1][1], {
            'message': b'command data frame without flags',
        })

    def testframefornonreceivingrequest(self):
        """Receiving a frame for a command that is not receiving is illegal."""
        results = list(sendframes(makereactor(), [
            ffs(b'1 command-name eos command1'),
            ffs(b'3 command-name have-data command3'),
            ffs(b'5 command-argument eoa ignored'),
        ]))
        self.assertaction(results[2], 'error')
        self.assertEqual(results[2][1], {
            'message': b'received frame for request that is not receiving: 5',
        })

    def testsimpleresponse(self):
        """Bytes response to command sends result frames."""
        reactor = makereactor()
        instream = framing.stream()
        list(sendcommandframes(reactor, instream, 1, b'mycommand', {}))

        outstream = framing.stream()
        result = reactor.onbytesresponseready(outstream, 1, b'response')
        self.assertaction(result, 'sendframes')
        self.assertframesequal(result[1]['framegen'], [
            b'1 bytes-response eos response',
        ])

    def testmultiframeresponse(self):
        """Bytes response spanning multiple frames is handled."""
        first = b'x' * framing.DEFAULT_MAX_FRAME_SIZE
        second = b'y' * 100

        reactor = makereactor()
        instream = framing.stream()
        list(sendcommandframes(reactor, instream, 1, b'mycommand', {}))

        outstream = framing.stream()
        result = reactor.onbytesresponseready(outstream, 1, first + second)
        self.assertaction(result, 'sendframes')
        self.assertframesequal(result[1]['framegen'], [
            b'1 bytes-response continuation %s' % first,
            b'1 bytes-response eos %s' % second,
        ])

    def testapplicationerror(self):
        reactor = makereactor()
        instream = framing.stream()
        list(sendcommandframes(reactor, instream, 1, b'mycommand', {}))

        outstream = framing.stream()
        result = reactor.onapplicationerror(outstream, 1, b'some message')
        self.assertaction(result, 'sendframes')
        self.assertframesequal(result[1]['framegen'], [
            b'1 error-response application some message',
        ])

    def test1commanddeferresponse(self):
        """Responses when in deferred output mode are delayed until EOF."""
        reactor = makereactor(deferoutput=True)
        instream = framing.stream()
        results = list(sendcommandframes(reactor, instream, 1, b'mycommand',
                                         {}))
        self.assertEqual(len(results), 1)
        self.assertaction(results[0], 'runcommand')

        outstream = framing.stream()
        result = reactor.onbytesresponseready(outstream, 1, b'response')
        self.assertaction(result, 'noop')
        result = reactor.oninputeof()
        self.assertaction(result, 'sendframes')
        self.assertframesequal(result[1]['framegen'], [
            b'1 bytes-response eos response',
        ])

    def testmultiplecommanddeferresponse(self):
        reactor = makereactor(deferoutput=True)
        instream = framing.stream()
        list(sendcommandframes(reactor, instream, 1, b'command1', {}))
        list(sendcommandframes(reactor, instream, 3, b'command2', {}))

        outstream = framing.stream()
        result = reactor.onbytesresponseready(outstream, 1, b'response1')
        self.assertaction(result, 'noop')
        result = reactor.onbytesresponseready(outstream, 3, b'response2')
        self.assertaction(result, 'noop')
        result = reactor.oninputeof()
        self.assertaction(result, 'sendframes')
        self.assertframesequal(result[1]['framegen'], [
            b'1 bytes-response eos response1',
            b'3 bytes-response eos response2'
        ])

    def testrequestidtracking(self):
        reactor = makereactor(deferoutput=True)
        instream = framing.stream()
        list(sendcommandframes(reactor, instream, 1, b'command1', {}))
        list(sendcommandframes(reactor, instream, 3, b'command2', {}))
        list(sendcommandframes(reactor, instream, 5, b'command3', {}))

        # Register results for commands out of order.
        outstream = framing.stream()
        reactor.onbytesresponseready(outstream, 3, b'response3')
        reactor.onbytesresponseready(outstream, 1, b'response1')
        reactor.onbytesresponseready(outstream, 5, b'response5')

        result = reactor.oninputeof()
        self.assertaction(result, 'sendframes')
        self.assertframesequal(result[1]['framegen'], [
            b'3 bytes-response eos response3',
            b'1 bytes-response eos response1',
            b'5 bytes-response eos response5',
        ])

    def testduplicaterequestonactivecommand(self):
        """Receiving a request ID that matches a request that isn't finished."""
        reactor = makereactor()
        stream = framing.stream()
        list(sendcommandframes(reactor, stream, 1, b'command1', {}))
        results = list(sendcommandframes(reactor, stream, 1, b'command1', {}))

        self.assertaction(results[0], 'error')
        self.assertEqual(results[0][1], {
            'message': b'request with ID 1 is already active',
        })

    def testduplicaterequestonactivecommandnosend(self):
        """Same as above but we've registered a response but haven't sent it."""
        reactor = makereactor()
        instream = framing.stream()
        list(sendcommandframes(reactor, instream, 1, b'command1', {}))
        outstream = framing.stream()
        reactor.onbytesresponseready(outstream, 1, b'response')

        # We've registered the response but haven't sent it. From the
        # perspective of the reactor, the command is still active.

        results = list(sendcommandframes(reactor, instream, 1, b'command1', {}))
        self.assertaction(results[0], 'error')
        self.assertEqual(results[0][1], {
            'message': b'request with ID 1 is already active',
        })

    def testduplicaterequestargumentframe(self):
        """Variant on above except we sent an argument frame instead of name."""
        reactor = makereactor()
        stream = framing.stream()
        list(sendcommandframes(reactor, stream, 1, b'command', {}))
        results = list(sendframes(reactor, [
            ffs(b'3 command-name have-args command'),
            ffs(b'1 command-argument 0 ignored'),
        ]))
        self.assertaction(results[0], 'wantframe')
        self.assertaction(results[1], 'error')
        self.assertEqual(results[1][1], {
            'message': 'received frame for request that is still active: 1',
        })

    def testduplicaterequestaftersend(self):
        """We can use a duplicate request ID after we've sent the response."""
        reactor = makereactor()
        instream = framing.stream()
        list(sendcommandframes(reactor, instream, 1, b'command1', {}))
        outstream = framing.stream()
        res = reactor.onbytesresponseready(outstream, 1, b'response')
        list(res[1]['framegen'])

        results = list(sendcommandframes(reactor, instream, 1, b'command1', {}))
        self.assertaction(results[0], 'runcommand')

if __name__ == '__main__':
    import silenttestrunner
    silenttestrunner.main(__name__)
