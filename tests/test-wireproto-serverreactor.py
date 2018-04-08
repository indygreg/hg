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
        stream = framing.stream(1)
        results = list(sendcommandframes(reactor, stream, 41, b'mycommand',
                                         {b'foo': b'bar'}))
        self.assertEqual(len(results), 1)
        self.assertaction(results[0], 'runcommand')
        self.assertEqual(results[0][1], {
            'requestid': 41,
            'command': b'mycommand',
            'args': {b'foo': b'bar'},
            'data': None,
        })

    def testmultiarguments(self):
        reactor = makereactor()
        stream = framing.stream(1)
        results = list(sendcommandframes(reactor, stream, 1, b'mycommand',
                                         {b'foo': b'bar', b'biz': b'baz'}))
        self.assertEqual(len(results), 1)
        self.assertaction(results[0], 'runcommand')
        self.assertEqual(results[0][1], {
            'requestid': 1,
            'command': b'mycommand',
            'args': {b'foo': b'bar', b'biz': b'baz'},
            'data': None,
        })

    def testsimplecommanddata(self):
        reactor = makereactor()
        stream = framing.stream(1)
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
            ffs(b'1 1 stream-begin command-request new|have-data '
                b"cbor:{b'name': b'command', b'args': {b'key': b'val',"
                b"b'foo': b'bar'}}"),
            ffs(b'1 1 0 command-data continuation value1'),
            ffs(b'1 1 0 command-data eos value2'),
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

    def testnewandcontinuation(self):
        result = self._sendsingleframe(makereactor(),
            ffs(b'1 1 stream-begin command-request new|continuation '))
        self.assertaction(result, 'error')
        self.assertEqual(result[1], {
            'message': b'received command request frame with both new and '
                       b'continuation flags set',
        })

    def testneithernewnorcontinuation(self):
        result = self._sendsingleframe(makereactor(),
            ffs(b'1 1 stream-begin command-request 0 '))
        self.assertaction(result, 'error')
        self.assertEqual(result[1], {
            'message': b'received command request frame with neither new nor '
                       b'continuation flags set',
        })

    def testunexpectedcommanddata(self):
        """Command data frame when not running a command is an error."""
        result = self._sendsingleframe(makereactor(),
            ffs(b'1 1 stream-begin command-data 0 ignored'))
        self.assertaction(result, 'error')
        self.assertEqual(result[1], {
            'message': b'expected command request frame; got 3',
        })

    def testunexpectedcommanddatareceiving(self):
        """Same as above except the command is receiving."""
        results = list(sendframes(makereactor(), [
            ffs(b'1 1 stream-begin command-request new|more '
                b"cbor:{b'name': b'ignored'}"),
            ffs(b'1 1 0 command-data eos ignored'),
        ]))

        self.assertaction(results[0], 'wantframe')
        self.assertaction(results[1], 'error')
        self.assertEqual(results[1][1], {
            'message': b'received command data frame for request that is not '
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
        self.assertaction(result, 'sendframes')
        list(result[1]['framegen'])
        results.append(self._sendsingleframe(
            reactor, ffs(b'1 1 stream-begin command-request new '
                         b"cbor:{b'name': b'command'}")))
        result = reactor.onbytesresponseready(outstream, 1, b'response2')
        self.assertaction(result, 'sendframes')
        list(result[1]['framegen'])
        results.append(self._sendsingleframe(
            reactor, ffs(b'1 1 stream-begin command-request new '
                         b"cbor:{b'name': b'command'}")))
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
            ffs(b'1 1 stream-begin command-request new|more '
                b"cbor:{b'name': b'command'}"),
            ffs(b'1 1 0 command-request new '
                b"cbor:{b'name': b'command1'}"),
        ]))

        self.assertaction(results[0], 'wantframe')
        self.assertaction(results[1], 'error')
        self.assertEqual(results[1][1], {
            'message': b'request with ID 1 already received',
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
        self.assertaction(results[0], 'wantframe')
        self.assertaction(results[1], 'runcommand')

    def testmissingcommanddataframeflags(self):
        frames = [
            ffs(b'1 1 stream-begin command-request new|have-data '
                b"cbor:{b'name': b'command1'}"),
            ffs(b'1 1 0 command-data 0 data'),
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
            ffs(b'1 1 stream-begin command-request new '
                b"cbor:{b'name': b'command1'}"),
            ffs(b'3 1 0 command-request new|have-data '
                b"cbor:{b'name': b'command3'}"),
            ffs(b'5 1 0 command-data eos ignored'),
        ]))
        self.assertaction(results[2], 'error')
        self.assertEqual(results[2][1], {
            'message': b'received frame for request that is not receiving: 5',
        })

    def testsimpleresponse(self):
        """Bytes response to command sends result frames."""
        reactor = makereactor()
        instream = framing.stream(1)
        list(sendcommandframes(reactor, instream, 1, b'mycommand', {}))

        outstream = reactor.makeoutputstream()
        result = reactor.onbytesresponseready(outstream, 1, b'response')
        self.assertaction(result, 'sendframes')
        self.assertframesequal(result[1]['framegen'], [
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
        self.assertaction(result, 'sendframes')
        self.assertframesequal(result[1]['framegen'], [
            b'1 2 stream-begin bytes-response continuation %s' % first,
            b'1 2 0 bytes-response eos %s' % second,
        ])

    def testapplicationerror(self):
        reactor = makereactor()
        instream = framing.stream(1)
        list(sendcommandframes(reactor, instream, 1, b'mycommand', {}))

        outstream = reactor.makeoutputstream()
        result = reactor.onapplicationerror(outstream, 1, b'some message')
        self.assertaction(result, 'sendframes')
        self.assertframesequal(result[1]['framegen'], [
            b'1 2 stream-begin error-response application some message',
        ])

    def test1commanddeferresponse(self):
        """Responses when in deferred output mode are delayed until EOF."""
        reactor = makereactor(deferoutput=True)
        instream = framing.stream(1)
        results = list(sendcommandframes(reactor, instream, 1, b'mycommand',
                                         {}))
        self.assertEqual(len(results), 1)
        self.assertaction(results[0], 'runcommand')

        outstream = reactor.makeoutputstream()
        result = reactor.onbytesresponseready(outstream, 1, b'response')
        self.assertaction(result, 'noop')
        result = reactor.oninputeof()
        self.assertaction(result, 'sendframes')
        self.assertframesequal(result[1]['framegen'], [
            b'1 2 stream-begin bytes-response eos response',
        ])

    def testmultiplecommanddeferresponse(self):
        reactor = makereactor(deferoutput=True)
        instream = framing.stream(1)
        list(sendcommandframes(reactor, instream, 1, b'command1', {}))
        list(sendcommandframes(reactor, instream, 3, b'command2', {}))

        outstream = reactor.makeoutputstream()
        result = reactor.onbytesresponseready(outstream, 1, b'response1')
        self.assertaction(result, 'noop')
        result = reactor.onbytesresponseready(outstream, 3, b'response2')
        self.assertaction(result, 'noop')
        result = reactor.oninputeof()
        self.assertaction(result, 'sendframes')
        self.assertframesequal(result[1]['framegen'], [
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
        self.assertaction(result, 'sendframes')
        self.assertframesequal(result[1]['framegen'], [
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

        self.assertaction(results[0], 'error')
        self.assertEqual(results[0][1], {
            'message': b'request with ID 1 is already active',
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
        self.assertaction(results[0], 'error')
        self.assertEqual(results[0][1], {
            'message': b'request with ID 1 is already active',
        })

    def testduplicaterequestaftersend(self):
        """We can use a duplicate request ID after we've sent the response."""
        reactor = makereactor()
        instream = framing.stream(1)
        list(sendcommandframes(reactor, instream, 1, b'command1', {}))
        outstream = reactor.makeoutputstream()
        res = reactor.onbytesresponseready(outstream, 1, b'response')
        list(res[1]['framegen'])

        results = list(sendcommandframes(reactor, instream, 1, b'command1', {}))
        self.assertaction(results[0], 'runcommand')

if __name__ == '__main__':
    import silenttestrunner
    silenttestrunner.main(__name__)
