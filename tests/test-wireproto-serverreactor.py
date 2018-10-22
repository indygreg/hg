from __future__ import absolute_import, print_function

import unittest

from mercurial.thirdparty import (
    cbor,
)
from mercurial import (
    ui as uimod,
    util,
    wireprotoframing as framing,
)
from mercurial.utils import (
    cborutil,
)

ffs = framing.makeframefromhumanstring

OK = cbor.dumps({b'status': b'ok'})

def makereactor(deferoutput=False):
    ui = uimod.ui()
    return framing.serverreactor(ui, deferoutput=deferoutput)

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
            b'redirect': None,
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
            b'redirect': None,
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
            b'redirect': None,
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
            b'redirect': None,
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
            b'redirect': None,
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
            b'redirect': None,
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
            b'message': b'expected sender protocol settings or command request '
                        b'frame; got 2',
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
        result = reactor.oncommandresponsereadyobjects(
            outstream, 1, [b'response1'])
        self.assertaction(result, b'sendframes')
        list(result[1][b'framegen'])
        results.append(self._sendsingleframe(
            reactor, ffs(b'1 1 stream-begin command-request new '
                         b"cbor:{b'name': b'command'}")))
        result = reactor.oncommandresponsereadyobjects(
            outstream, 1, [b'response2'])
        self.assertaction(result, b'sendframes')
        list(result[1][b'framegen'])
        results.append(self._sendsingleframe(
            reactor, ffs(b'1 1 stream-begin command-request new '
                         b"cbor:{b'name': b'command'}")))
        result = reactor.oncommandresponsereadyobjects(
            outstream, 1, [b'response3'])
        self.assertaction(result, b'sendframes')
        list(result[1][b'framegen'])

        for i in range(3):
            self.assertaction(results[i], b'runcommand')
            self.assertEqual(results[i][1], {
                b'requestid': 1,
                b'command': b'command',
                b'args': {},
                b'redirect': None,
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
            b'redirect': None,
            b'data': None,
        })
        self.assertEqual(results[5][1], {
            b'requestid': 1,
            b'command': b'command1',
            b'args': {b'foo': b'bar', b'key1': b'val'},
            b'redirect': None,
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
        result = reactor.oncommandresponsereadyobjects(
            outstream, 1, [b'response'])
        self.assertaction(result, b'sendframes')
        self.assertframesequal(result[1][b'framegen'], [
            b'1 2 stream-begin stream-settings eos cbor:b"identity"',
            b'1 2 encoded command-response continuation %s' % OK,
            b'1 2 encoded command-response continuation cbor:b"response"',
            b'1 2 0 command-response eos ',
        ])

    def testmultiframeresponse(self):
        """Bytes response spanning multiple frames is handled."""
        first = b'x' * framing.DEFAULT_MAX_FRAME_SIZE
        second = b'y' * 100

        reactor = makereactor()
        instream = framing.stream(1)
        list(sendcommandframes(reactor, instream, 1, b'mycommand', {}))

        outstream = reactor.makeoutputstream()
        result = reactor.oncommandresponsereadyobjects(
            outstream, 1, [first + second])
        self.assertaction(result, b'sendframes')
        self.assertframesequal(result[1][b'framegen'], [
            b'1 2 stream-begin stream-settings eos cbor:b"identity"',
            b'1 2 encoded command-response continuation %s' % OK,
            b'1 2 encoded command-response continuation Y\x80d',
            b'1 2 encoded command-response continuation %s' % first,
            b'1 2 encoded command-response continuation %s' % second,
            b'1 2 0 command-response eos '
        ])

    def testservererror(self):
        reactor = makereactor()
        instream = framing.stream(1)
        list(sendcommandframes(reactor, instream, 1, b'mycommand', {}))

        outstream = reactor.makeoutputstream()
        result = reactor.onservererror(outstream, 1, b'some message')
        self.assertaction(result, b'sendframes')
        self.assertframesequal(result[1][b'framegen'], [
            b"1 2 stream-begin error-response 0 "
            b"cbor:{b'type': b'server', "
            b"b'message': [{b'msg': b'some message'}]}",
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
        result = reactor.oncommandresponsereadyobjects(
            outstream, 1, [b'response'])
        self.assertaction(result, b'noop')
        result = reactor.oninputeof()
        self.assertaction(result, b'sendframes')
        self.assertframesequal(result[1][b'framegen'], [
            b'1 2 stream-begin stream-settings eos cbor:b"identity"',
            b'1 2 encoded command-response continuation %s' % OK,
            b'1 2 encoded command-response continuation cbor:b"response"',
            b'1 2 0 command-response eos ',
        ])

    def testmultiplecommanddeferresponse(self):
        reactor = makereactor(deferoutput=True)
        instream = framing.stream(1)
        list(sendcommandframes(reactor, instream, 1, b'command1', {}))
        list(sendcommandframes(reactor, instream, 3, b'command2', {}))

        outstream = reactor.makeoutputstream()
        result = reactor.oncommandresponsereadyobjects(
            outstream, 1, [b'response1'])
        self.assertaction(result, b'noop')
        result = reactor.oncommandresponsereadyobjects(
            outstream, 3, [b'response2'])
        self.assertaction(result, b'noop')
        result = reactor.oninputeof()
        self.assertaction(result, b'sendframes')
        self.assertframesequal(result[1][b'framegen'], [
            b'1 2 stream-begin stream-settings eos cbor:b"identity"',
            b'1 2 encoded command-response continuation %s' % OK,
            b'1 2 encoded command-response continuation cbor:b"response1"',
            b'1 2 0 command-response eos ',
            b'3 2 encoded command-response continuation %s' % OK,
            b'3 2 encoded command-response continuation cbor:b"response2"',
            b'3 2 0 command-response eos ',
        ])

    def testrequestidtracking(self):
        reactor = makereactor(deferoutput=True)
        instream = framing.stream(1)
        list(sendcommandframes(reactor, instream, 1, b'command1', {}))
        list(sendcommandframes(reactor, instream, 3, b'command2', {}))
        list(sendcommandframes(reactor, instream, 5, b'command3', {}))

        # Register results for commands out of order.
        outstream = reactor.makeoutputstream()
        reactor.oncommandresponsereadyobjects(outstream, 3, [b'response3'])
        reactor.oncommandresponsereadyobjects(outstream, 1, [b'response1'])
        reactor.oncommandresponsereadyobjects(outstream, 5, [b'response5'])

        result = reactor.oninputeof()
        self.assertaction(result, b'sendframes')
        self.assertframesequal(result[1][b'framegen'], [
            b'3 2 stream-begin stream-settings eos cbor:b"identity"',
            b'3 2 encoded command-response continuation %s' % OK,
            b'3 2 encoded command-response continuation cbor:b"response3"',
            b'3 2 0 command-response eos ',
            b'1 2 encoded command-response continuation %s' % OK,
            b'1 2 encoded command-response continuation cbor:b"response1"',
            b'1 2 0 command-response eos ',
            b'5 2 encoded command-response continuation %s' % OK,
            b'5 2 encoded command-response continuation cbor:b"response5"',
            b'5 2 0 command-response eos ',
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
        reactor.oncommandresponsereadyobjects(outstream, 1, [b'response'])

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
        res = reactor.oncommandresponsereadyobjects(outstream, 1, [b'response'])
        list(res[1][b'framegen'])

        results = list(sendcommandframes(reactor, instream, 1, b'command1', {}))
        self.assertaction(results[0], b'runcommand')

    def testprotocolsettingsnoflags(self):
        result = self._sendsingleframe(
            makereactor(),
            ffs(b'0 1 stream-begin sender-protocol-settings 0 '))
        self.assertaction(result, b'error')
        self.assertEqual(result[1], {
            b'message': b'sender protocol settings frame must have '
                        b'continuation or end of stream flag set',
        })

    def testprotocolsettingsconflictflags(self):
        result = self._sendsingleframe(
            makereactor(),
            ffs(b'0 1 stream-begin sender-protocol-settings continuation|eos '))
        self.assertaction(result, b'error')
        self.assertEqual(result[1], {
            b'message': b'sender protocol settings frame cannot have both '
                        b'continuation and end of stream flags set',
        })

    def testprotocolsettingsemptypayload(self):
        result = self._sendsingleframe(
            makereactor(),
            ffs(b'0 1 stream-begin sender-protocol-settings eos '))
        self.assertaction(result, b'error')
        self.assertEqual(result[1], {
            b'message': b'sender protocol settings frame did not contain CBOR '
                        b'data',
        })

    def testprotocolsettingsmultipleobjects(self):
        result = self._sendsingleframe(
            makereactor(),
            ffs(b'0 1 stream-begin sender-protocol-settings eos '
                b'\x46foobar\x43foo'))
        self.assertaction(result, b'error')
        self.assertEqual(result[1], {
            b'message': b'sender protocol settings frame contained multiple '
                        b'CBOR values',
        })

    def testprotocolsettingscontentencodings(self):
        reactor = makereactor()

        result = self._sendsingleframe(
            reactor,
            ffs(b'0 1 stream-begin sender-protocol-settings eos '
                b'cbor:{b"contentencodings": [b"a", b"b"]}'))
        self.assertaction(result, b'wantframe')

        self.assertEqual(reactor._state, b'idle')
        self.assertEqual(reactor._sendersettings[b'contentencodings'],
                         [b'a', b'b'])

    def testprotocolsettingsmultipleframes(self):
        reactor = makereactor()

        data = b''.join(cborutil.streamencode({
            b'contentencodings': [b'value1', b'value2'],
        }))

        results = list(sendframes(reactor, [
            ffs(b'0 1 stream-begin sender-protocol-settings continuation %s' %
                data[0:5]),
            ffs(b'0 1 0 sender-protocol-settings eos %s' % data[5:]),
        ]))

        self.assertEqual(len(results), 2)

        self.assertaction(results[0], b'wantframe')
        self.assertaction(results[1], b'wantframe')

        self.assertEqual(reactor._state, b'idle')
        self.assertEqual(reactor._sendersettings[b'contentencodings'],
                         [b'value1', b'value2'])

    def testprotocolsettingsbadcbor(self):
        result = self._sendsingleframe(
            makereactor(),
            ffs(b'0 1 stream-begin sender-protocol-settings eos badvalue'))
        self.assertaction(result, b'error')

    def testprotocolsettingsnoninitial(self):
        # Cannot have protocol settings frames as non-initial frames.
        reactor = makereactor()

        stream = framing.stream(1)
        results = list(sendcommandframes(reactor, stream, 1, b'mycommand', {}))
        self.assertEqual(len(results), 1)
        self.assertaction(results[0], b'runcommand')

        result = self._sendsingleframe(
            reactor,
            ffs(b'0 1 0 sender-protocol-settings eos '))
        self.assertaction(result, b'error')
        self.assertEqual(result[1], {
            b'message': b'expected command request frame; got 8',
        })

if __name__ == '__main__':
    import silenttestrunner
    silenttestrunner.main(__name__)
