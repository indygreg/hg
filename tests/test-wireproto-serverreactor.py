from __future__ import absolute_import, print_function

import unittest

from mercurial.thirdparty import (
    cbor,
)
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
                                                header.streamid,
                                                header.streamflags,
                                                header.typeid,
                                                header.flags,
                                                payload))

def sendcommandframes(reactor, stream, rid, cmd, args, datafh=None):
    """Generate frames to run a command and send them to a reactor."""
    return sendframes(reactor,
                      framing.createcommandframes(stream, rid, cmd, args,
                                                  datafh))


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
        stream = framing.stream(1)
        results = list(sendcommandframes(reactor, stream, 1, b'mycommand', {}))
        self.assertEqual(len(results), 1)
        self.assertaction(results[0], b'runcommand')
        self.assertEqual(results[0][1], {
            b'requestid': 1,
            b'command': b'mycommand',
            b'args': {},
            b'data': None,
        })

        result = reactor.oninputeof()
        self.assertaction(result, b'noop')

    def test1argument(self):
        reactor = makereactor()
        stream = framing.stream(1)
        results = list(sendcommandframes(reactor, stream, 41, b'mycommand',
                                         {b'foo': b'bar'}))
        self.assertEqual(len(results), 1)
        self.assertaction(results[0], b'runcommand')
        self.assertEqual(results[0][1], {
            b'requestid': 41,
            b'command': b'mycommand',
            b'args': {b'foo': b'bar'},
            b'data': None,
        })

    def testmultiarguments(self):
        reactor = makereactor()
        stream = framing.stream(1)
        results = list(sendcommandframes(reactor, stream, 1, b'mycommand',
                                         {b'foo': b'bar', b'biz': b'baz'}))
        self.assertEqual(len(results), 1)
        self.assertaction(results[0], b'runcommand')
        self.assertEqual(results[0][1], {
            b'requestid': 1,
            b'command': b'mycommand',
            b'args': {b'foo': b'bar', b'biz': b'baz'},
            b'data': None,
        })

    def testsimplecommanddata(self):
        reactor = makereactor()
        stream = framing.stream(1)
        results = list(sendcommandframes(reactor, stream, 1, b'mycommand', {},
                                         util.bytesio(b'data!')))
        self.assertEqual(len(results), 2)
        self.assertaction(results[0], b'wantframe')
        self.assertaction(results[1], b'runcommand')
        self.assertEqual(results[1][1], {
            b'requestid': 1,
            b'command': b'mycommand',
            b'args': {},
            b'data': b'data!',
        })

    def testmultipledataframes(self):
        frames = [
            ffs(b'1 1 stream-begin command-request new|have-data '
                b"cbor:{b'name': b'mycommand'}"),
            ffs(b'1 1 0 command-data continuation data1'),
            ffs(b'1 1 0 command-data continuation data2'),
            ffs(b'1 1 0 command-data eos data3'),
        ]

        reactor = makereactor()
        results = list(sendframes(reactor, frames))
        self.assertEqual(len(results), 4)
        for i in range(3):
            self.assertaction(results[i], b'wantframe')
        self.assertaction(results[3], b'runcommand')
        self.assertEqual(results[3][1], {
            b'requestid': 1,
            b'command': b'mycommand',
            b'args': {},
            b'data': b'data1data2data3',
        })

    def testargumentanddata(self):
        frames = [
            ffs(b'1 1 stream-begin command-request new|have-data '
                b"cbor:{b'name': b'command', b'args': {b'key': b'val',"
                b"b'foo': b'bar'}}"),
            ffs(b'1 1 0 command-data continuation value1'),
            ffs(b'1 1 0 command-data eos value2'),
        ]

        reactor = makereactor()
        results = list(sendframes(reactor, frames))

        self.assertaction(results[-1], b'runcommand')
        self.assertEqual(results[-1][1], {
            b'requestid': 1,
            b'command': b'command',
            b'args': {
                b'key': b'val',
                b'foo': b'bar',
            },
            b'data': b'value1value2',
        })

    def testnewandcontinuation(self):
        result = self._sendsingleframe(makereactor(),
            ffs(b'1 1 stream-begin command-request new|continuation '))
        self.assertaction(result, b'error')
        self.assertEqual(result[1], {
            b'message': b'received command request frame with both new and '
                        b'continuation flags set',
        })

    def testneithernewnorcontinuation(self):
        result = self._sendsingleframe(makereactor(),
            ffs(b'1 1 stream-begin command-request 0 '))
        self.assertaction(result, b'error')
        self.assertEqual(result[1], {
            b'message': b'received command request frame with neither new nor '
                        b'continuation flags set',
        })

    def testunexpectedcommanddata(self):
        """Command data frame when not running a command is an error."""
        result = self._sendsingleframe(makereactor(),
            ffs(b'1 1 stream-begin command-data 0 ignored'))
        self.assertaction(result, b'error')
        self.assertEqual(result[1], {
            b'message': b'expected command request frame; got 2',
        })

    def testunexpectedcommanddatareceiving(self):
        """Same as above except the command is receiving."""
        results = list(sendframes(makereactor(), [
            ffs(b'1 1 stream-begin command-request new|more '
                b"cbor:{b'name': b'ignored'}"),
            ffs(b'1 1 0 command-data eos ignored'),
        ]))

        self.assertaction(results[0], b'wantframe')
        self.assertaction(results[1], b'error')
        self.assertEqual(results[1][1], {
            b'message': b'received command data frame for request that is not '
                        b'expecting data: 1',
        })

    def testconflictingrequestidallowed(self):
        """Multiple fully serviced commands with same request ID is allowed."""
        reactor = makereactor()
        results = []
        outstream = reactor.makeoutputstream()
        results.append(self._sendsingleframe(
            reactor, ffs(b'1 1 stream-begin command-request new '
                         b"cbor:{b'name': b'command'}")))
        result = reactor.onbytesresponseready(outstream, 1, b'response1')
        self.assertaction(result, b'sendframes')
        list(result[1][b'framegen'])
        results.append(self._sendsingleframe(
            reactor, ffs(b'1 1 stream-begin command-request new '
                         b"cbor:{b'name': b'command'}")))
        result = reactor.onbytesresponseready(outstream, 1, b'response2')
        self.assertaction(result, b'sendframes')
        list(result[1][b'framegen'])
        results.append(self._sendsingleframe(
            reactor, ffs(b'1 1 stream-begin command-request new '
                         b"cbor:{b'name': b'command'}")))
        result = reactor.onbytesresponseready(outstream, 1, b'response3')
        self.assertaction(result, b'sendframes')
        list(result[1][b'framegen'])

        for i in range(3):
            self.assertaction(results[i], b'runcommand')
            self.assertEqual(results[i][1], {
                b'requestid': 1,
                b'command': b'command',
                b'args': {},
                b'data': None,
            })

    def testconflictingrequestid(self):
        """Request ID for new command matching in-flight command is illegal."""
        results = list(sendframes(makereactor(), [
            ffs(b'1 1 stream-begin command-request new|more '
                b"cbor:{b'name': b'command'}"),
            ffs(b'1 1 0 command-request new '
                b"cbor:{b'name': b'command1'}"),
        ]))

        self.assertaction(results[0], b'wantframe')
        self.assertaction(results[1], b'error')
        self.assertEqual(results[1][1], {
            b'message': b'request with ID 1 already received',
        })

    def testinterleavedcommands(self):
        cbor1 = cbor.dumps({
            b'name': b'command1',
            b'args': {
                b'foo': b'bar',
                b'key1': b'val',
            }
        }, canonical=True)
        cbor3 = cbor.dumps({
            b'name': b'command3',
            b'args': {
                b'biz': b'baz',
                b'key': b'val',
            },
        }, canonical=True)

        results = list(sendframes(makereactor(), [
            ffs(b'1 1 stream-begin command-request new|more %s' % cbor1[0:6]),
            ffs(b'3 1 0 command-request new|more %s' % cbor3[0:10]),
            ffs(b'1 1 0 command-request continuation|more %s' % cbor1[6:9]),
            ffs(b'3 1 0 command-request continuation|more %s' % cbor3[10:13]),
            ffs(b'3 1 0 command-request continuation %s' % cbor3[13:]),
            ffs(b'1 1 0 command-request continuation %s' % cbor1[9:]),
        ]))

        self.assertEqual([t[0] for t in results], [
            b'wantframe',
            b'wantframe',
            b'wantframe',
            b'wantframe',
            b'runcommand',
            b'runcommand',
        ])

        self.assertEqual(results[4][1], {
            b'requestid': 3,
            b'command': b'command3',
            b'args': {b'biz': b'baz', b'key': b'val'},
            b'data': None,
        })
        self.assertEqual(results[5][1], {
            b'requestid': 1,
            b'command': b'command1',
            b'args': {b'foo': b'bar', b'key1': b'val'},
            b'data': None,
        })

    def testmissingcommanddataframe(self):
        # The reactor doesn't currently handle partially received commands.
        # So this test is failing to do anything with request 1.
        frames = [
            ffs(b'1 1 stream-begin command-request new|have-data '
                b"cbor:{b'name': b'command1'}"),
            ffs(b'3 1 0 command-request new '
                b"cbor:{b'name': b'command2'}"),
        ]
        results = list(sendframes(makereactor(), frames))
        self.assertEqual(len(results), 2)
        self.assertaction(results[0], b'wantframe')
        self.assertaction(results[1], b'runcommand')

    def testmissingcommanddataframeflags(self):
        frames = [
            ffs(b'1 1 stream-begin command-request new|have-data '
                b"cbor:{b'name': b'command1'}"),
            ffs(b'1 1 0 command-data 0 data'),
        ]
        results = list(sendframes(makereactor(), frames))
        self.assertEqual(len(results), 2)
        self.assertaction(results[0], b'wantframe')
        self.assertaction(results[1], b'error')
        self.assertEqual(results[1][1], {
            b'message': b'command data frame without flags',
        })

    def testframefornonreceivingrequest(self):
        """Receiving a frame for a command that is not receiving is illegal."""
        results = list(sendframes(makereactor(), [
            ffs(b'1 1 stream-begin command-request new '
                b"cbor:{b'name': b'command1'}"),
            ffs(b'3 1 0 command-request new|have-data '
                b"cbor:{b'name': b'command3'}"),
            ffs(b'5 1 0 command-data eos ignored'),
        ]))
        self.assertaction(results[2], b'error')
        self.assertEqual(results[2][1], {
            b'message': b'received frame for request that is not receiving: 5',
        })

    def testsimpleresponse(self):
        """Bytes response to command sends result frames."""
        reactor = makereactor()
        instream = framing.stream(1)
        list(sendcommandframes(reactor, instream, 1, b'mycommand', {}))

        outstream = reactor.makeoutputstream()
        result = reactor.onbytesresponseready(outstream, 1, b'response')
        self.assertaction(result, b'sendframes')
        self.assertframesequal(result[1][b'framegen'], [
            b'1 2 stream-begin bytes-response eos response',
        ])

    def testmultiframeresponse(self):
        """Bytes response spanning multiple frames is handled."""
        first = b'x' * framing.DEFAULT_MAX_FRAME_SIZE
        second = b'y' * 100

        reactor = makereactor()
        instream = framing.stream(1)
        list(sendcommandframes(reactor, instream, 1, b'mycommand', {}))

        outstream = reactor.makeoutputstream()
        result = reactor.onbytesresponseready(outstream, 1, first + second)
        self.assertaction(result, b'sendframes')
        self.assertframesequal(result[1][b'framegen'], [
            b'1 2 stream-begin bytes-response continuation %s' % first,
            b'1 2 0 bytes-response eos %s' % second,
        ])

    def testapplicationerror(self):
        reactor = makereactor()
        instream = framing.stream(1)
        list(sendcommandframes(reactor, instream, 1, b'mycommand', {}))

        outstream = reactor.makeoutputstream()
        result = reactor.onapplicationerror(outstream, 1, b'some message')
        self.assertaction(result, b'sendframes')
        self.assertframesequal(result[1][b'framegen'], [
            b'1 2 stream-begin error-response application some message',
        ])

    def test1commanddeferresponse(self):
        """Responses when in deferred output mode are delayed until EOF."""
        reactor = makereactor(deferoutput=True)
        instream = framing.stream(1)
        results = list(sendcommandframes(reactor, instream, 1, b'mycommand',
                                         {}))
        self.assertEqual(len(results), 1)
        self.assertaction(results[0], b'runcommand')

        outstream = reactor.makeoutputstream()
        result = reactor.onbytesresponseready(outstream, 1, b'response')
        self.assertaction(result, b'noop')
        result = reactor.oninputeof()
        self.assertaction(result, b'sendframes')
        self.assertframesequal(result[1][b'framegen'], [
            b'1 2 stream-begin bytes-response eos response',
        ])

    def testmultiplecommanddeferresponse(self):
        reactor = makereactor(deferoutput=True)
        instream = framing.stream(1)
        list(sendcommandframes(reactor, instream, 1, b'command1', {}))
        list(sendcommandframes(reactor, instream, 3, b'command2', {}))

        outstream = reactor.makeoutputstream()
        result = reactor.onbytesresponseready(outstream, 1, b'response1')
        self.assertaction(result, b'noop')
        result = reactor.onbytesresponseready(outstream, 3, b'response2')
        self.assertaction(result, b'noop')
        result = reactor.oninputeof()
        self.assertaction(result, b'sendframes')
        self.assertframesequal(result[1][b'framegen'], [
            b'1 2 stream-begin bytes-response eos response1',
            b'3 2 0 bytes-response eos response2'
        ])

    def testrequestidtracking(self):
        reactor = makereactor(deferoutput=True)
        instream = framing.stream(1)
        list(sendcommandframes(reactor, instream, 1, b'command1', {}))
        list(sendcommandframes(reactor, instream, 3, b'command2', {}))
        list(sendcommandframes(reactor, instream, 5, b'command3', {}))

        # Register results for commands out of order.
        outstream = reactor.makeoutputstream()
        reactor.onbytesresponseready(outstream, 3, b'response3')
        reactor.onbytesresponseready(outstream, 1, b'response1')
        reactor.onbytesresponseready(outstream, 5, b'response5')

        result = reactor.oninputeof()
        self.assertaction(result, b'sendframes')
        self.assertframesequal(result[1][b'framegen'], [
            b'3 2 stream-begin bytes-response eos response3',
            b'1 2 0 bytes-response eos response1',
            b'5 2 0 bytes-response eos response5',
        ])

    def testduplicaterequestonactivecommand(self):
        """Receiving a request ID that matches a request that isn't finished."""
        reactor = makereactor()
        stream = framing.stream(1)
        list(sendcommandframes(reactor, stream, 1, b'command1', {}))
        results = list(sendcommandframes(reactor, stream, 1, b'command1', {}))

        self.assertaction(results[0], b'error')
        self.assertEqual(results[0][1], {
            b'message': b'request with ID 1 is already active',
        })

    def testduplicaterequestonactivecommandnosend(self):
        """Same as above but we've registered a response but haven't sent it."""
        reactor = makereactor()
        instream = framing.stream(1)
        list(sendcommandframes(reactor, instream, 1, b'command1', {}))
        outstream = reactor.makeoutputstream()
        reactor.onbytesresponseready(outstream, 1, b'response')

        # We've registered the response but haven't sent it. From the
        # perspective of the reactor, the command is still active.

        results = list(sendcommandframes(reactor, instream, 1, b'command1', {}))
        self.assertaction(results[0], b'error')
        self.assertEqual(results[0][1], {
            b'message': b'request with ID 1 is already active',
        })

    def testduplicaterequestaftersend(self):
        """We can use a duplicate request ID after we've sent the response."""
        reactor = makereactor()
        instream = framing.stream(1)
        list(sendcommandframes(reactor, instream, 1, b'command1', {}))
        outstream = reactor.makeoutputstream()
        res = reactor.onbytesresponseready(outstream, 1, b'response')
        list(res[1][b'framegen'])

        results = list(sendcommandframes(reactor, instream, 1, b'command1', {}))
        self.assertaction(results[0], b'runcommand')

if __name__ == '__main__':
    import silenttestrunner
    silenttestrunner.main(__name__)
