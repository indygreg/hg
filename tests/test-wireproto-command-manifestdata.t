  $ . $TESTDIR/wireprotohelpers.sh

  $ hg init server
  $ enablehttpv2 server
  $ cd server
  $ echo a0 > a
  $ echo b0 > b
  $ mkdir -p dir0/child0 dir0/child1 dir1
  $ echo c0 > dir0/c
  $ echo d0 > dir0/d
  $ echo e0 > dir0/child0/e
  $ echo f0 > dir0/child1/f
  $ hg -q commit -A -m 'commit 0'

  $ echo a1 > a
  $ echo d1 > dir0/d
  $ hg commit -m 'commit 1'
  $ echo f0 > dir0/child1/f
  $ hg commit -m 'commit 2'
  nothing changed
  [1]

  $ hg -q up -r 0
  $ echo a2 > a
  $ hg commit -m 'commit 3'
  created new head

  $ hg log -G -T '{rev}:{node} {desc}\n'
  @  2:c8757a2ffe552850d1e0dfe60d295ebf64c196d9 commit 3
  |
  | o  1:650165e803375748a94df471e5b58d85763e0b29 commit 1
  |/
  o  0:6d85ca1270b377d320098556ba5bfad34a9ee12d commit 0
  

  $ hg --debug debugindex -m
     rev linkrev nodeid                                   p1                                       p2
       0       0 1b175b595f022cfab5b809cc0ed551bd0b3ff5e4 0000000000000000000000000000000000000000 0000000000000000000000000000000000000000
       1       1 91e0bdbfb0dde0023fa063edc1445f207a22eac7 1b175b595f022cfab5b809cc0ed551bd0b3ff5e4 0000000000000000000000000000000000000000
       2       2 46a6721b5edaf0ea04b79a5cb3218854a4d2aba0 1b175b595f022cfab5b809cc0ed551bd0b3ff5e4 0000000000000000000000000000000000000000

  $ hg serve -p $HGPORT -d --pid-file hg.pid -E error.log
  $ cat hg.pid > $DAEMON_PIDS

Missing arguments is an error

  $ sendhttpv2peer << EOF
  > command manifestdata
  > EOF
  creating http peer for wire protocol version 2
  sending manifestdata command
  s>     POST /api/exp-http-v2-0002/ro/manifestdata HTTP/1.1\r\n
  s>     Accept-Encoding: identity\r\n
  s>     accept: application/mercurial-exp-framing-0005\r\n
  s>     content-type: application/mercurial-exp-framing-0005\r\n
  s>     content-length: 27\r\n
  s>     host: $LOCALIP:$HGPORT\r\n (glob)
  s>     user-agent: Mercurial debugwireproto\r\n
  s>     \r\n
  s>     \x13\x00\x00\x01\x00\x01\x01\x11\xa1DnameLmanifestdata
  s> makefile('rb', None)
  s>     HTTP/1.1 200 OK\r\n
  s>     Server: testing stub value\r\n
  s>     Date: $HTTP_DATE$\r\n
  s>     Content-Type: application/mercurial-exp-framing-0005\r\n
  s>     Transfer-Encoding: chunked\r\n
  s>     \r\n
  s>     4e\r\n
  s>     F\x00\x00\x01\x00\x02\x012
  s>     \xa2Eerror\xa1GmessageX\'missing required arguments: nodes, treeFstatusEerror
  s>     \r\n
  received frame(size=70; request=1; stream=2; streamflags=stream-begin; type=command-response; flags=eos)
  s>     0\r\n
  s>     \r\n
  abort: missing required arguments: nodes, tree!
  [255]

  $ sendhttpv2peer << EOF
  > command manifestdata
  >     nodes eval:[]
  > EOF
  creating http peer for wire protocol version 2
  sending manifestdata command
  s>     POST /api/exp-http-v2-0002/ro/manifestdata HTTP/1.1\r\n
  s>     Accept-Encoding: identity\r\n
  s>     accept: application/mercurial-exp-framing-0005\r\n
  s>     content-type: application/mercurial-exp-framing-0005\r\n
  s>     content-length: 40\r\n
  s>     host: $LOCALIP:$HGPORT\r\n (glob)
  s>     user-agent: Mercurial debugwireproto\r\n
  s>     \r\n
  s>      \x00\x00\x01\x00\x01\x01\x11\xa2Dargs\xa1Enodes\x80DnameLmanifestdata
  s> makefile('rb', None)
  s>     HTTP/1.1 200 OK\r\n
  s>     Server: testing stub value\r\n
  s>     Date: $HTTP_DATE$\r\n
  s>     Content-Type: application/mercurial-exp-framing-0005\r\n
  s>     Transfer-Encoding: chunked\r\n
  s>     \r\n
  s>     47\r\n
  s>     ?\x00\x00\x01\x00\x02\x012
  s>     \xa2Eerror\xa1GmessageX missing required arguments: treeFstatusEerror
  s>     \r\n
  received frame(size=63; request=1; stream=2; streamflags=stream-begin; type=command-response; flags=eos)
  s>     0\r\n
  s>     \r\n
  abort: missing required arguments: tree!
  [255]

Unknown node is an error

  $ sendhttpv2peer << EOF
  > command manifestdata
  >     nodes eval:[b'\xaa\xaa\xaa\xaa\xaa\xaa\xaa\xaa\xaa\xaa\xaa\xaa\xaa\xaa\xaa\xaa\xaa\xaa\xaa\xaa']
  >     tree eval:b''
  > EOF
  creating http peer for wire protocol version 2
  sending manifestdata command
  s>     POST /api/exp-http-v2-0002/ro/manifestdata HTTP/1.1\r\n
  s>     Accept-Encoding: identity\r\n
  s>     accept: application/mercurial-exp-framing-0005\r\n
  s>     content-type: application/mercurial-exp-framing-0005\r\n
  s>     content-length: 67\r\n
  s>     host: $LOCALIP:$HGPORT\r\n (glob)
  s>     user-agent: Mercurial debugwireproto\r\n
  s>     \r\n
  s>     ;\x00\x00\x01\x00\x01\x01\x11\xa2Dargs\xa2Enodes\x81T\xaa\xaa\xaa\xaa\xaa\xaa\xaa\xaa\xaa\xaa\xaa\xaa\xaa\xaa\xaa\xaa\xaa\xaa\xaa\xaaDtree@DnameLmanifestdata
  s> makefile('rb', None)
  s>     HTTP/1.1 200 OK\r\n
  s>     Server: testing stub value\r\n
  s>     Date: $HTTP_DATE$\r\n
  s>     Content-Type: application/mercurial-exp-framing-0005\r\n
  s>     Transfer-Encoding: chunked\r\n
  s>     \r\n
  s>     51\r\n
  s>     I\x00\x00\x01\x00\x02\x012
  s>     \xa2Eerror\xa2Dargs\x81T\xaa\xaa\xaa\xaa\xaa\xaa\xaa\xaa\xaa\xaa\xaa\xaa\xaa\xaa\xaa\xaa\xaa\xaa\xaa\xaaGmessagePunknown node: %sFstatusEerror
  s>     \r\n
  received frame(size=73; request=1; stream=2; streamflags=stream-begin; type=command-response; flags=eos)
  s>     0\r\n
  s>     \r\n
  abort: unknown node: \xaa\xaa\xaa\xaa\xaa\xaa\xaa\xaa\xaa\xaa\xaa\xaa\xaa\xaa\xaa\xaa\xaa\xaa\xaa\xaa! (esc)
  [255]

Fetching a single revision returns just metadata by default

  $ sendhttpv2peer << EOF
  > command manifestdata
  >     nodes eval:[b'\x46\xa6\x72\x1b\x5e\xda\xf0\xea\x04\xb7\x9a\x5c\xb3\x21\x88\x54\xa4\xd2\xab\xa0']
  >     tree eval:b''
  > EOF
  creating http peer for wire protocol version 2
  sending manifestdata command
  s>     POST /api/exp-http-v2-0002/ro/manifestdata HTTP/1.1\r\n
  s>     Accept-Encoding: identity\r\n
  s>     accept: application/mercurial-exp-framing-0005\r\n
  s>     content-type: application/mercurial-exp-framing-0005\r\n
  s>     content-length: 67\r\n
  s>     host: $LOCALIP:$HGPORT\r\n (glob)
  s>     user-agent: Mercurial debugwireproto\r\n
  s>     \r\n
  s>     ;\x00\x00\x01\x00\x01\x01\x11\xa2Dargs\xa2Enodes\x81TF\xa6r\x1b^\xda\xf0\xea\x04\xb7\x9a\\\xb3!\x88T\xa4\xd2\xab\xa0Dtree@DnameLmanifestdata
  s> makefile('rb', None)
  s>     HTTP/1.1 200 OK\r\n
  s>     Server: testing stub value\r\n
  s>     Date: $HTTP_DATE$\r\n
  s>     Content-Type: application/mercurial-exp-framing-0005\r\n
  s>     Transfer-Encoding: chunked\r\n
  s>     \r\n
  s>     13\r\n
  s>     \x0b\x00\x00\x01\x00\x02\x011
  s>     \xa1FstatusBok
  s>     \r\n
  received frame(size=11; request=1; stream=2; streamflags=stream-begin; type=command-response; flags=continuation)
  s>     30\r\n
  s>     (\x00\x00\x01\x00\x02\x001
  s>     \xa1Jtotalitems\x01\xa1DnodeTF\xa6r\x1b^\xda\xf0\xea\x04\xb7\x9a\\\xb3!\x88T\xa4\xd2\xab\xa0
  s>     \r\n
  received frame(size=40; request=1; stream=2; streamflags=; type=command-response; flags=continuation)
  s>     8\r\n
  s>     \x00\x00\x00\x01\x00\x02\x002
  s>     \r\n
  s>     0\r\n
  s>     \r\n
  received frame(size=0; request=1; stream=2; streamflags=; type=command-response; flags=eos)
  response: gen[
    {
      b'totalitems': 1
    },
    {
      b'node': b'F\xa6r\x1b^\xda\xf0\xea\x04\xb7\x9a\\\xb3!\x88T\xa4\xd2\xab\xa0'
    }
  ]

Requesting parents works

  $ sendhttpv2peer << EOF
  > command manifestdata
  >     nodes eval:[b'\x46\xa6\x72\x1b\x5e\xda\xf0\xea\x04\xb7\x9a\x5c\xb3\x21\x88\x54\xa4\xd2\xab\xa0']
  >     tree eval:b''
  >     fields eval:[b'parents']
  > EOF
  creating http peer for wire protocol version 2
  sending manifestdata command
  s>     POST /api/exp-http-v2-0002/ro/manifestdata HTTP/1.1\r\n
  s>     Accept-Encoding: identity\r\n
  s>     accept: application/mercurial-exp-framing-0005\r\n
  s>     content-type: application/mercurial-exp-framing-0005\r\n
  s>     content-length: 83\r\n
  s>     host: $LOCALIP:$HGPORT\r\n (glob)
  s>     user-agent: Mercurial debugwireproto\r\n
  s>     \r\n
  s>     K\x00\x00\x01\x00\x01\x01\x11\xa2Dargs\xa3Ffields\x81GparentsEnodes\x81TF\xa6r\x1b^\xda\xf0\xea\x04\xb7\x9a\\\xb3!\x88T\xa4\xd2\xab\xa0Dtree@DnameLmanifestdata
  s> makefile('rb', None)
  s>     HTTP/1.1 200 OK\r\n
  s>     Server: testing stub value\r\n
  s>     Date: $HTTP_DATE$\r\n
  s>     Content-Type: application/mercurial-exp-framing-0005\r\n
  s>     Transfer-Encoding: chunked\r\n
  s>     \r\n
  s>     13\r\n
  s>     \x0b\x00\x00\x01\x00\x02\x011
  s>     \xa1FstatusBok
  s>     \r\n
  received frame(size=11; request=1; stream=2; streamflags=stream-begin; type=command-response; flags=continuation)
  s>     63\r\n
  s>     [\x00\x00\x01\x00\x02\x001
  s>     \xa1Jtotalitems\x01\xa2DnodeTF\xa6r\x1b^\xda\xf0\xea\x04\xb7\x9a\\\xb3!\x88T\xa4\xd2\xab\xa0Gparents\x82T\x1b\x17[Y_\x02,\xfa\xb5\xb8\t\xcc\x0e\xd5Q\xbd\x0b?\xf5\xe4T\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00
  s>     \r\n
  received frame(size=91; request=1; stream=2; streamflags=; type=command-response; flags=continuation)
  s>     8\r\n
  s>     \x00\x00\x00\x01\x00\x02\x002
  s>     \r\n
  s>     0\r\n
  s>     \r\n
  received frame(size=0; request=1; stream=2; streamflags=; type=command-response; flags=eos)
  response: gen[
    {
      b'totalitems': 1
    },
    {
      b'node': b'F\xa6r\x1b^\xda\xf0\xea\x04\xb7\x9a\\\xb3!\x88T\xa4\xd2\xab\xa0',
      b'parents': [
        b'\x1b\x17[Y_\x02,\xfa\xb5\xb8\t\xcc\x0e\xd5Q\xbd\x0b?\xf5\xe4',
        b'\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00'
      ]
    }
  ]

Requesting revision data works
(haveparents defaults to false, so fulltext is emitted)

  $ sendhttpv2peer << EOF
  > command manifestdata
  >     nodes eval:[b'\x46\xa6\x72\x1b\x5e\xda\xf0\xea\x04\xb7\x9a\x5c\xb3\x21\x88\x54\xa4\xd2\xab\xa0']
  >     tree eval:b''
  >     fields eval:[b'revision']
  > EOF
  creating http peer for wire protocol version 2
  sending manifestdata command
  s>     POST /api/exp-http-v2-0002/ro/manifestdata HTTP/1.1\r\n
  s>     Accept-Encoding: identity\r\n
  s>     accept: application/mercurial-exp-framing-0005\r\n
  s>     content-type: application/mercurial-exp-framing-0005\r\n
  s>     content-length: 84\r\n
  s>     host: $LOCALIP:$HGPORT\r\n (glob)
  s>     user-agent: Mercurial debugwireproto\r\n
  s>     \r\n
  s>     L\x00\x00\x01\x00\x01\x01\x11\xa2Dargs\xa3Ffields\x81HrevisionEnodes\x81TF\xa6r\x1b^\xda\xf0\xea\x04\xb7\x9a\\\xb3!\x88T\xa4\xd2\xab\xa0Dtree@DnameLmanifestdata
  s> makefile('rb', None)
  s>     HTTP/1.1 200 OK\r\n
  s>     Server: testing stub value\r\n
  s>     Date: $HTTP_DATE$\r\n
  s>     Content-Type: application/mercurial-exp-framing-0005\r\n
  s>     Transfer-Encoding: chunked\r\n
  s>     \r\n
  s>     13\r\n
  s>     \x0b\x00\x00\x01\x00\x02\x011
  s>     \xa1FstatusBok
  s>     \r\n
  received frame(size=11; request=1; stream=2; streamflags=stream-begin; type=command-response; flags=continuation)
  s>     175\r\n
  s>     m\x01\x00\x01\x00\x02\x001
  s>     \xa1Jtotalitems\x01\xa2Ofieldsfollowing\x81\x82Hrevision\x19\x01$DnodeTF\xa6r\x1b^\xda\xf0\xea\x04\xb7\x9a\\\xb3!\x88T\xa4\xd2\xab\xa0Y\x01$a\x000879345e39377229634b420c639454156726c6b6\n
  s>     b\x00819e258d31a5e1606629f365bb902a1b21ee4216\n
  s>     dir0/c\x00914445346a0ca0629bd47ceb5dfe07e4d4cf2501\n
  s>     dir0/child0/e\x00bbba6c06b30f443d34ff841bc985c4d0827c6be4\n
  s>     dir0/child1/f\x0012fc7dcd773b5a0a929ce195228083c6ddc9cec4\n
  s>     dir0/d\x00538206dc971e521540d6843abfe6d16032f6d426\n
  s>     \r\n
  received frame(size=365; request=1; stream=2; streamflags=; type=command-response; flags=continuation)
  s>     8\r\n
  s>     \x00\x00\x00\x01\x00\x02\x002
  s>     \r\n
  s>     0\r\n
  s>     \r\n
  received frame(size=0; request=1; stream=2; streamflags=; type=command-response; flags=eos)
  response: gen[
    {
      b'totalitems': 1
    },
    {
      b'fieldsfollowing': [
        [
          b'revision',
          292
        ]
      ],
      b'node': b'F\xa6r\x1b^\xda\xf0\xea\x04\xb7\x9a\\\xb3!\x88T\xa4\xd2\xab\xa0'
    },
    b'a\x000879345e39377229634b420c639454156726c6b6\nb\x00819e258d31a5e1606629f365bb902a1b21ee4216\ndir0/c\x00914445346a0ca0629bd47ceb5dfe07e4d4cf2501\ndir0/child0/e\x00bbba6c06b30f443d34ff841bc985c4d0827c6be4\ndir0/child1/f\x0012fc7dcd773b5a0a929ce195228083c6ddc9cec4\ndir0/d\x00538206dc971e521540d6843abfe6d16032f6d426\n'
  ]

haveparents=False yields same output

  $ sendhttpv2peer << EOF
  > command manifestdata
  >     nodes eval:[b'\x46\xa6\x72\x1b\x5e\xda\xf0\xea\x04\xb7\x9a\x5c\xb3\x21\x88\x54\xa4\xd2\xab\xa0']
  >     tree eval:b''
  >     fields eval:[b'revision']
  >     haveparents eval:False
  > EOF
  creating http peer for wire protocol version 2
  sending manifestdata command
  s>     POST /api/exp-http-v2-0002/ro/manifestdata HTTP/1.1\r\n
  s>     Accept-Encoding: identity\r\n
  s>     accept: application/mercurial-exp-framing-0005\r\n
  s>     content-type: application/mercurial-exp-framing-0005\r\n
  s>     content-length: 97\r\n
  s>     host: $LOCALIP:$HGPORT\r\n (glob)
  s>     user-agent: Mercurial debugwireproto\r\n
  s>     \r\n
  s>     Y\x00\x00\x01\x00\x01\x01\x11\xa2Dargs\xa4Ffields\x81HrevisionKhaveparents\xf4Enodes\x81TF\xa6r\x1b^\xda\xf0\xea\x04\xb7\x9a\\\xb3!\x88T\xa4\xd2\xab\xa0Dtree@DnameLmanifestdata
  s> makefile('rb', None)
  s>     HTTP/1.1 200 OK\r\n
  s>     Server: testing stub value\r\n
  s>     Date: $HTTP_DATE$\r\n
  s>     Content-Type: application/mercurial-exp-framing-0005\r\n
  s>     Transfer-Encoding: chunked\r\n
  s>     \r\n
  s>     13\r\n
  s>     \x0b\x00\x00\x01\x00\x02\x011
  s>     \xa1FstatusBok
  s>     \r\n
  received frame(size=11; request=1; stream=2; streamflags=stream-begin; type=command-response; flags=continuation)
  s>     175\r\n
  s>     m\x01\x00\x01\x00\x02\x001
  s>     \xa1Jtotalitems\x01\xa2Ofieldsfollowing\x81\x82Hrevision\x19\x01$DnodeTF\xa6r\x1b^\xda\xf0\xea\x04\xb7\x9a\\\xb3!\x88T\xa4\xd2\xab\xa0Y\x01$a\x000879345e39377229634b420c639454156726c6b6\n
  s>     b\x00819e258d31a5e1606629f365bb902a1b21ee4216\n
  s>     dir0/c\x00914445346a0ca0629bd47ceb5dfe07e4d4cf2501\n
  s>     dir0/child0/e\x00bbba6c06b30f443d34ff841bc985c4d0827c6be4\n
  s>     dir0/child1/f\x0012fc7dcd773b5a0a929ce195228083c6ddc9cec4\n
  s>     dir0/d\x00538206dc971e521540d6843abfe6d16032f6d426\n
  s>     \r\n
  received frame(size=365; request=1; stream=2; streamflags=; type=command-response; flags=continuation)
  s>     8\r\n
  s>     \x00\x00\x00\x01\x00\x02\x002
  s>     \r\n
  s>     0\r\n
  s>     \r\n
  received frame(size=0; request=1; stream=2; streamflags=; type=command-response; flags=eos)
  response: gen[
    {
      b'totalitems': 1
    },
    {
      b'fieldsfollowing': [
        [
          b'revision',
          292
        ]
      ],
      b'node': b'F\xa6r\x1b^\xda\xf0\xea\x04\xb7\x9a\\\xb3!\x88T\xa4\xd2\xab\xa0'
    },
    b'a\x000879345e39377229634b420c639454156726c6b6\nb\x00819e258d31a5e1606629f365bb902a1b21ee4216\ndir0/c\x00914445346a0ca0629bd47ceb5dfe07e4d4cf2501\ndir0/child0/e\x00bbba6c06b30f443d34ff841bc985c4d0827c6be4\ndir0/child1/f\x0012fc7dcd773b5a0a929ce195228083c6ddc9cec4\ndir0/d\x00538206dc971e521540d6843abfe6d16032f6d426\n'
  ]

haveparents=True will emit delta

  $ sendhttpv2peer << EOF
  > command manifestdata
  >     nodes eval:[b'\x46\xa6\x72\x1b\x5e\xda\xf0\xea\x04\xb7\x9a\x5c\xb3\x21\x88\x54\xa4\xd2\xab\xa0']
  >     tree eval:b''
  >     fields eval:[b'revision']
  >     haveparents eval:True
  > EOF
  creating http peer for wire protocol version 2
  sending manifestdata command
  s>     POST /api/exp-http-v2-0002/ro/manifestdata HTTP/1.1\r\n
  s>     Accept-Encoding: identity\r\n
  s>     accept: application/mercurial-exp-framing-0005\r\n
  s>     content-type: application/mercurial-exp-framing-0005\r\n
  s>     content-length: 97\r\n
  s>     host: $LOCALIP:$HGPORT\r\n (glob)
  s>     user-agent: Mercurial debugwireproto\r\n
  s>     \r\n
  s>     Y\x00\x00\x01\x00\x01\x01\x11\xa2Dargs\xa4Ffields\x81HrevisionKhaveparents\xf5Enodes\x81TF\xa6r\x1b^\xda\xf0\xea\x04\xb7\x9a\\\xb3!\x88T\xa4\xd2\xab\xa0Dtree@DnameLmanifestdata
  s> makefile('rb', None)
  s>     HTTP/1.1 200 OK\r\n
  s>     Server: testing stub value\r\n
  s>     Date: $HTTP_DATE$\r\n
  s>     Content-Type: application/mercurial-exp-framing-0005\r\n
  s>     Transfer-Encoding: chunked\r\n
  s>     \r\n
  s>     13\r\n
  s>     \x0b\x00\x00\x01\x00\x02\x011
  s>     \xa1FstatusBok
  s>     \r\n
  received frame(size=11; request=1; stream=2; streamflags=stream-begin; type=command-response; flags=continuation)
  s>     a6\r\n
  s>     \x9e\x00\x00\x01\x00\x02\x001
  s>     \xa1Jtotalitems\x01\xa3MdeltabasenodeT\x1b\x17[Y_\x02,\xfa\xb5\xb8\t\xcc\x0e\xd5Q\xbd\x0b?\xf5\xe4Ofieldsfollowing\x81\x82Edelta\x187DnodeTF\xa6r\x1b^\xda\xf0\xea\x04\xb7\x9a\\\xb3!\x88T\xa4\xd2\xab\xa0X7\x00\x00\x00\x00\x00\x00\x00+\x00\x00\x00+a\x000879345e39377229634b420c639454156726c6b6\n
  s>     \r\n
  received frame(size=158; request=1; stream=2; streamflags=; type=command-response; flags=continuation)
  s>     8\r\n
  s>     \x00\x00\x00\x01\x00\x02\x002
  s>     \r\n
  s>     0\r\n
  s>     \r\n
  received frame(size=0; request=1; stream=2; streamflags=; type=command-response; flags=eos)
  response: gen[
    {
      b'totalitems': 1
    },
    {
      b'deltabasenode': b'\x1b\x17[Y_\x02,\xfa\xb5\xb8\t\xcc\x0e\xd5Q\xbd\x0b?\xf5\xe4',
      b'fieldsfollowing': [
        [
          b'delta',
          55
        ]
      ],
      b'node': b'F\xa6r\x1b^\xda\xf0\xea\x04\xb7\x9a\\\xb3!\x88T\xa4\xd2\xab\xa0'
    },
    b'\x00\x00\x00\x00\x00\x00\x00+\x00\x00\x00+a\x000879345e39377229634b420c639454156726c6b6\n'
  ]

Requesting multiple revisions works
(haveparents defaults to false, so fulltext is emitted unless a parent
has been emitted)

  $ sendhttpv2peer << EOF
  > command manifestdata
  >     nodes eval:[b'\x1b\x17\x5b\x59\x5f\x02\x2c\xfa\xb5\xb8\x09\xcc\x0e\xd5\x51\xbd\x0b\x3f\xf5\xe4', b'\x46\xa6\x72\x1b\x5e\xda\xf0\xea\x04\xb7\x9a\x5c\xb3\x21\x88\x54\xa4\xd2\xab\xa0']
  >     tree eval:b''
  >     fields eval:[b'revision']
  > EOF
  creating http peer for wire protocol version 2
  sending manifestdata command
  s>     POST /api/exp-http-v2-0002/ro/manifestdata HTTP/1.1\r\n
  s>     Accept-Encoding: identity\r\n
  s>     accept: application/mercurial-exp-framing-0005\r\n
  s>     content-type: application/mercurial-exp-framing-0005\r\n
  s>     content-length: 105\r\n
  s>     host: $LOCALIP:$HGPORT\r\n (glob)
  s>     user-agent: Mercurial debugwireproto\r\n
  s>     \r\n
  s>     a\x00\x00\x01\x00\x01\x01\x11\xa2Dargs\xa3Ffields\x81HrevisionEnodes\x82T\x1b\x17[Y_\x02,\xfa\xb5\xb8\t\xcc\x0e\xd5Q\xbd\x0b?\xf5\xe4TF\xa6r\x1b^\xda\xf0\xea\x04\xb7\x9a\\\xb3!\x88T\xa4\xd2\xab\xa0Dtree@DnameLmanifestdata
  s> makefile('rb', None)
  s>     HTTP/1.1 200 OK\r\n
  s>     Server: testing stub value\r\n
  s>     Date: $HTTP_DATE$\r\n
  s>     Content-Type: application/mercurial-exp-framing-0005\r\n
  s>     Transfer-Encoding: chunked\r\n
  s>     \r\n
  s>     13\r\n
  s>     \x0b\x00\x00\x01\x00\x02\x011
  s>     \xa1FstatusBok
  s>     \r\n
  received frame(size=11; request=1; stream=2; streamflags=stream-begin; type=command-response; flags=continuation)
  s>     206\r\n
  s>     \xfe\x01\x00\x01\x00\x02\x001
  s>     \xa1Jtotalitems\x02\xa2Ofieldsfollowing\x81\x82Hrevision\x19\x01$DnodeT\x1b\x17[Y_\x02,\xfa\xb5\xb8\t\xcc\x0e\xd5Q\xbd\x0b?\xf5\xe4Y\x01$a\x002b4eb07319bfa077a40a2f04913659aef0da42da\n
  s>     b\x00819e258d31a5e1606629f365bb902a1b21ee4216\n
  s>     dir0/c\x00914445346a0ca0629bd47ceb5dfe07e4d4cf2501\n
  s>     dir0/child0/e\x00bbba6c06b30f443d34ff841bc985c4d0827c6be4\n
  s>     dir0/child1/f\x0012fc7dcd773b5a0a929ce195228083c6ddc9cec4\n
  s>     dir0/d\x00538206dc971e521540d6843abfe6d16032f6d426\n
  s>     \xa3MdeltabasenodeT\x1b\x17[Y_\x02,\xfa\xb5\xb8\t\xcc\x0e\xd5Q\xbd\x0b?\xf5\xe4Ofieldsfollowing\x81\x82Edelta\x187DnodeTF\xa6r\x1b^\xda\xf0\xea\x04\xb7\x9a\\\xb3!\x88T\xa4\xd2\xab\xa0X7\x00\x00\x00\x00\x00\x00\x00+\x00\x00\x00+a\x000879345e39377229634b420c639454156726c6b6\n
  s>     \r\n
  received frame(size=510; request=1; stream=2; streamflags=; type=command-response; flags=continuation)
  s>     8\r\n
  s>     \x00\x00\x00\x01\x00\x02\x002
  s>     \r\n
  s>     0\r\n
  s>     \r\n
  received frame(size=0; request=1; stream=2; streamflags=; type=command-response; flags=eos)
  response: gen[
    {
      b'totalitems': 2
    },
    {
      b'fieldsfollowing': [
        [
          b'revision',
          292
        ]
      ],
      b'node': b'\x1b\x17[Y_\x02,\xfa\xb5\xb8\t\xcc\x0e\xd5Q\xbd\x0b?\xf5\xe4'
    },
    b'a\x002b4eb07319bfa077a40a2f04913659aef0da42da\nb\x00819e258d31a5e1606629f365bb902a1b21ee4216\ndir0/c\x00914445346a0ca0629bd47ceb5dfe07e4d4cf2501\ndir0/child0/e\x00bbba6c06b30f443d34ff841bc985c4d0827c6be4\ndir0/child1/f\x0012fc7dcd773b5a0a929ce195228083c6ddc9cec4\ndir0/d\x00538206dc971e521540d6843abfe6d16032f6d426\n',
    {
      b'deltabasenode': b'\x1b\x17[Y_\x02,\xfa\xb5\xb8\t\xcc\x0e\xd5Q\xbd\x0b?\xf5\xe4',
      b'fieldsfollowing': [
        [
          b'delta',
          55
        ]
      ],
      b'node': b'F\xa6r\x1b^\xda\xf0\xea\x04\xb7\x9a\\\xb3!\x88T\xa4\xd2\xab\xa0'
    },
    b'\x00\x00\x00\x00\x00\x00\x00+\x00\x00\x00+a\x000879345e39377229634b420c639454156726c6b6\n'
  ]

With haveparents=True, first revision is a delta instead of fulltext

  $ sendhttpv2peer << EOF
  > command manifestdata
  >     nodes eval:[b'\x1b\x17\x5b\x59\x5f\x02\x2c\xfa\xb5\xb8\x09\xcc\x0e\xd5\x51\xbd\x0b\x3f\xf5\xe4', b'\x46\xa6\x72\x1b\x5e\xda\xf0\xea\x04\xb7\x9a\x5c\xb3\x21\x88\x54\xa4\xd2\xab\xa0']
  >     tree eval:b''
  >     fields eval:[b'revision']
  >     haveparents eval:True
  > EOF
  creating http peer for wire protocol version 2
  sending manifestdata command
  s>     POST /api/exp-http-v2-0002/ro/manifestdata HTTP/1.1\r\n
  s>     Accept-Encoding: identity\r\n
  s>     accept: application/mercurial-exp-framing-0005\r\n
  s>     content-type: application/mercurial-exp-framing-0005\r\n
  s>     content-length: 118\r\n
  s>     host: $LOCALIP:$HGPORT\r\n (glob)
  s>     user-agent: Mercurial debugwireproto\r\n
  s>     \r\n
  s>     n\x00\x00\x01\x00\x01\x01\x11\xa2Dargs\xa4Ffields\x81HrevisionKhaveparents\xf5Enodes\x82T\x1b\x17[Y_\x02,\xfa\xb5\xb8\t\xcc\x0e\xd5Q\xbd\x0b?\xf5\xe4TF\xa6r\x1b^\xda\xf0\xea\x04\xb7\x9a\\\xb3!\x88T\xa4\xd2\xab\xa0Dtree@DnameLmanifestdata
  s> makefile('rb', None)
  s>     HTTP/1.1 200 OK\r\n
  s>     Server: testing stub value\r\n
  s>     Date: $HTTP_DATE$\r\n
  s>     Content-Type: application/mercurial-exp-framing-0005\r\n
  s>     Transfer-Encoding: chunked\r\n
  s>     \r\n
  s>     13\r\n
  s>     \x0b\x00\x00\x01\x00\x02\x011
  s>     \xa1FstatusBok
  s>     \r\n
  received frame(size=11; request=1; stream=2; streamflags=stream-begin; type=command-response; flags=continuation)
  s>     206\r\n
  s>     \xfe\x01\x00\x01\x00\x02\x001
  s>     \xa1Jtotalitems\x02\xa2Ofieldsfollowing\x81\x82Hrevision\x19\x01$DnodeT\x1b\x17[Y_\x02,\xfa\xb5\xb8\t\xcc\x0e\xd5Q\xbd\x0b?\xf5\xe4Y\x01$a\x002b4eb07319bfa077a40a2f04913659aef0da42da\n
  s>     b\x00819e258d31a5e1606629f365bb902a1b21ee4216\n
  s>     dir0/c\x00914445346a0ca0629bd47ceb5dfe07e4d4cf2501\n
  s>     dir0/child0/e\x00bbba6c06b30f443d34ff841bc985c4d0827c6be4\n
  s>     dir0/child1/f\x0012fc7dcd773b5a0a929ce195228083c6ddc9cec4\n
  s>     dir0/d\x00538206dc971e521540d6843abfe6d16032f6d426\n
  s>     \xa3MdeltabasenodeT\x1b\x17[Y_\x02,\xfa\xb5\xb8\t\xcc\x0e\xd5Q\xbd\x0b?\xf5\xe4Ofieldsfollowing\x81\x82Edelta\x187DnodeTF\xa6r\x1b^\xda\xf0\xea\x04\xb7\x9a\\\xb3!\x88T\xa4\xd2\xab\xa0X7\x00\x00\x00\x00\x00\x00\x00+\x00\x00\x00+a\x000879345e39377229634b420c639454156726c6b6\n
  s>     \r\n
  received frame(size=510; request=1; stream=2; streamflags=; type=command-response; flags=continuation)
  s>     8\r\n
  s>     \x00\x00\x00\x01\x00\x02\x002
  s>     \r\n
  s>     0\r\n
  s>     \r\n
  received frame(size=0; request=1; stream=2; streamflags=; type=command-response; flags=eos)
  response: gen[
    {
      b'totalitems': 2
    },
    {
      b'fieldsfollowing': [
        [
          b'revision',
          292
        ]
      ],
      b'node': b'\x1b\x17[Y_\x02,\xfa\xb5\xb8\t\xcc\x0e\xd5Q\xbd\x0b?\xf5\xe4'
    },
    b'a\x002b4eb07319bfa077a40a2f04913659aef0da42da\nb\x00819e258d31a5e1606629f365bb902a1b21ee4216\ndir0/c\x00914445346a0ca0629bd47ceb5dfe07e4d4cf2501\ndir0/child0/e\x00bbba6c06b30f443d34ff841bc985c4d0827c6be4\ndir0/child1/f\x0012fc7dcd773b5a0a929ce195228083c6ddc9cec4\ndir0/d\x00538206dc971e521540d6843abfe6d16032f6d426\n',
    {
      b'deltabasenode': b'\x1b\x17[Y_\x02,\xfa\xb5\xb8\t\xcc\x0e\xd5Q\xbd\x0b?\xf5\xe4',
      b'fieldsfollowing': [
        [
          b'delta',
          55
        ]
      ],
      b'node': b'F\xa6r\x1b^\xda\xf0\xea\x04\xb7\x9a\\\xb3!\x88T\xa4\xd2\xab\xa0'
    },
    b'\x00\x00\x00\x00\x00\x00\x00+\x00\x00\x00+a\x000879345e39377229634b420c639454156726c6b6\n'
  ]

Revisions are sorted by DAG order, parents first

  $ sendhttpv2peer << EOF
  > command manifestdata
  >     nodes eval:[b'\x46\xa6\x72\x1b\x5e\xda\xf0\xea\x04\xb7\x9a\x5c\xb3\x21\x88\x54\xa4\xd2\xab\xa0', b'\x1b\x17\x5b\x59\x5f\x02\x2c\xfa\xb5\xb8\x09\xcc\x0e\xd5\x51\xbd\x0b\x3f\xf5\xe4']
  >     tree eval:b''
  >     fields eval:[b'revision']
  > EOF
  creating http peer for wire protocol version 2
  sending manifestdata command
  s>     POST /api/exp-http-v2-0002/ro/manifestdata HTTP/1.1\r\n
  s>     Accept-Encoding: identity\r\n
  s>     accept: application/mercurial-exp-framing-0005\r\n
  s>     content-type: application/mercurial-exp-framing-0005\r\n
  s>     content-length: 105\r\n
  s>     host: $LOCALIP:$HGPORT\r\n (glob)
  s>     user-agent: Mercurial debugwireproto\r\n
  s>     \r\n
  s>     a\x00\x00\x01\x00\x01\x01\x11\xa2Dargs\xa3Ffields\x81HrevisionEnodes\x82TF\xa6r\x1b^\xda\xf0\xea\x04\xb7\x9a\\\xb3!\x88T\xa4\xd2\xab\xa0T\x1b\x17[Y_\x02,\xfa\xb5\xb8\t\xcc\x0e\xd5Q\xbd\x0b?\xf5\xe4Dtree@DnameLmanifestdata
  s> makefile('rb', None)
  s>     HTTP/1.1 200 OK\r\n
  s>     Server: testing stub value\r\n
  s>     Date: $HTTP_DATE$\r\n
  s>     Content-Type: application/mercurial-exp-framing-0005\r\n
  s>     Transfer-Encoding: chunked\r\n
  s>     \r\n
  s>     13\r\n
  s>     \x0b\x00\x00\x01\x00\x02\x011
  s>     \xa1FstatusBok
  s>     \r\n
  received frame(size=11; request=1; stream=2; streamflags=stream-begin; type=command-response; flags=continuation)
  s>     206\r\n
  s>     \xfe\x01\x00\x01\x00\x02\x001
  s>     \xa1Jtotalitems\x02\xa2Ofieldsfollowing\x81\x82Hrevision\x19\x01$DnodeT\x1b\x17[Y_\x02,\xfa\xb5\xb8\t\xcc\x0e\xd5Q\xbd\x0b?\xf5\xe4Y\x01$a\x002b4eb07319bfa077a40a2f04913659aef0da42da\n
  s>     b\x00819e258d31a5e1606629f365bb902a1b21ee4216\n
  s>     dir0/c\x00914445346a0ca0629bd47ceb5dfe07e4d4cf2501\n
  s>     dir0/child0/e\x00bbba6c06b30f443d34ff841bc985c4d0827c6be4\n
  s>     dir0/child1/f\x0012fc7dcd773b5a0a929ce195228083c6ddc9cec4\n
  s>     dir0/d\x00538206dc971e521540d6843abfe6d16032f6d426\n
  s>     \xa3MdeltabasenodeT\x1b\x17[Y_\x02,\xfa\xb5\xb8\t\xcc\x0e\xd5Q\xbd\x0b?\xf5\xe4Ofieldsfollowing\x81\x82Edelta\x187DnodeTF\xa6r\x1b^\xda\xf0\xea\x04\xb7\x9a\\\xb3!\x88T\xa4\xd2\xab\xa0X7\x00\x00\x00\x00\x00\x00\x00+\x00\x00\x00+a\x000879345e39377229634b420c639454156726c6b6\n
  s>     \r\n
  received frame(size=510; request=1; stream=2; streamflags=; type=command-response; flags=continuation)
  s>     8\r\n
  s>     \x00\x00\x00\x01\x00\x02\x002
  s>     \r\n
  s>     0\r\n
  s>     \r\n
  received frame(size=0; request=1; stream=2; streamflags=; type=command-response; flags=eos)
  response: gen[
    {
      b'totalitems': 2
    },
    {
      b'fieldsfollowing': [
        [
          b'revision',
          292
        ]
      ],
      b'node': b'\x1b\x17[Y_\x02,\xfa\xb5\xb8\t\xcc\x0e\xd5Q\xbd\x0b?\xf5\xe4'
    },
    b'a\x002b4eb07319bfa077a40a2f04913659aef0da42da\nb\x00819e258d31a5e1606629f365bb902a1b21ee4216\ndir0/c\x00914445346a0ca0629bd47ceb5dfe07e4d4cf2501\ndir0/child0/e\x00bbba6c06b30f443d34ff841bc985c4d0827c6be4\ndir0/child1/f\x0012fc7dcd773b5a0a929ce195228083c6ddc9cec4\ndir0/d\x00538206dc971e521540d6843abfe6d16032f6d426\n',
    {
      b'deltabasenode': b'\x1b\x17[Y_\x02,\xfa\xb5\xb8\t\xcc\x0e\xd5Q\xbd\x0b?\xf5\xe4',
      b'fieldsfollowing': [
        [
          b'delta',
          55
        ]
      ],
      b'node': b'F\xa6r\x1b^\xda\xf0\xea\x04\xb7\x9a\\\xb3!\x88T\xa4\xd2\xab\xa0'
    },
    b'\x00\x00\x00\x00\x00\x00\x00+\x00\x00\x00+a\x000879345e39377229634b420c639454156726c6b6\n'
  ]

Requesting parents and revision data works

  $ sendhttpv2peer << EOF
  > command manifestdata
  >     nodes eval:[b'\x1b\x17\x5b\x59\x5f\x02\x2c\xfa\xb5\xb8\x09\xcc\x0e\xd5\x51\xbd\x0b\x3f\xf5\xe4', b'\x46\xa6\x72\x1b\x5e\xda\xf0\xea\x04\xb7\x9a\x5c\xb3\x21\x88\x54\xa4\xd2\xab\xa0']
  >     tree eval:b''
  >     fields eval:[b'parents', b'revision']
  > EOF
  creating http peer for wire protocol version 2
  sending manifestdata command
  s>     POST /api/exp-http-v2-0002/ro/manifestdata HTTP/1.1\r\n
  s>     Accept-Encoding: identity\r\n
  s>     accept: application/mercurial-exp-framing-0005\r\n
  s>     content-type: application/mercurial-exp-framing-0005\r\n
  s>     content-length: 113\r\n
  s>     host: $LOCALIP:$HGPORT\r\n (glob)
  s>     user-agent: Mercurial debugwireproto\r\n
  s>     \r\n
  s>     i\x00\x00\x01\x00\x01\x01\x11\xa2Dargs\xa3Ffields\x82GparentsHrevisionEnodes\x82T\x1b\x17[Y_\x02,\xfa\xb5\xb8\t\xcc\x0e\xd5Q\xbd\x0b?\xf5\xe4TF\xa6r\x1b^\xda\xf0\xea\x04\xb7\x9a\\\xb3!\x88T\xa4\xd2\xab\xa0Dtree@DnameLmanifestdata
  s> makefile('rb', None)
  s>     HTTP/1.1 200 OK\r\n
  s>     Server: testing stub value\r\n
  s>     Date: $HTTP_DATE$\r\n
  s>     Content-Type: application/mercurial-exp-framing-0005\r\n
  s>     Transfer-Encoding: chunked\r\n
  s>     \r\n
  s>     13\r\n
  s>     \x0b\x00\x00\x01\x00\x02\x011
  s>     \xa1FstatusBok
  s>     \r\n
  received frame(size=11; request=1; stream=2; streamflags=stream-begin; type=command-response; flags=continuation)
  s>     26c\r\n
  s>     d\x02\x00\x01\x00\x02\x001
  s>     \xa1Jtotalitems\x02\xa3Ofieldsfollowing\x81\x82Hrevision\x19\x01$DnodeT\x1b\x17[Y_\x02,\xfa\xb5\xb8\t\xcc\x0e\xd5Q\xbd\x0b?\xf5\xe4Gparents\x82T\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00T\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00Y\x01$a\x002b4eb07319bfa077a40a2f04913659aef0da42da\n
  s>     b\x00819e258d31a5e1606629f365bb902a1b21ee4216\n
  s>     dir0/c\x00914445346a0ca0629bd47ceb5dfe07e4d4cf2501\n
  s>     dir0/child0/e\x00bbba6c06b30f443d34ff841bc985c4d0827c6be4\n
  s>     dir0/child1/f\x0012fc7dcd773b5a0a929ce195228083c6ddc9cec4\n
  s>     dir0/d\x00538206dc971e521540d6843abfe6d16032f6d426\n
  s>     \xa4MdeltabasenodeT\x1b\x17[Y_\x02,\xfa\xb5\xb8\t\xcc\x0e\xd5Q\xbd\x0b?\xf5\xe4Ofieldsfollowing\x81\x82Edelta\x187DnodeTF\xa6r\x1b^\xda\xf0\xea\x04\xb7\x9a\\\xb3!\x88T\xa4\xd2\xab\xa0Gparents\x82T\x1b\x17[Y_\x02,\xfa\xb5\xb8\t\xcc\x0e\xd5Q\xbd\x0b?\xf5\xe4T\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00X7\x00\x00\x00\x00\x00\x00\x00+\x00\x00\x00+a\x000879345e39377229634b420c639454156726c6b6\n
  s>     \r\n
  received frame(size=612; request=1; stream=2; streamflags=; type=command-response; flags=continuation)
  s>     8\r\n
  s>     \x00\x00\x00\x01\x00\x02\x002
  s>     \r\n
  s>     0\r\n
  s>     \r\n
  received frame(size=0; request=1; stream=2; streamflags=; type=command-response; flags=eos)
  response: gen[
    {
      b'totalitems': 2
    },
    {
      b'fieldsfollowing': [
        [
          b'revision',
          292
        ]
      ],
      b'node': b'\x1b\x17[Y_\x02,\xfa\xb5\xb8\t\xcc\x0e\xd5Q\xbd\x0b?\xf5\xe4',
      b'parents': [
        b'\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00',
        b'\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00'
      ]
    },
    b'a\x002b4eb07319bfa077a40a2f04913659aef0da42da\nb\x00819e258d31a5e1606629f365bb902a1b21ee4216\ndir0/c\x00914445346a0ca0629bd47ceb5dfe07e4d4cf2501\ndir0/child0/e\x00bbba6c06b30f443d34ff841bc985c4d0827c6be4\ndir0/child1/f\x0012fc7dcd773b5a0a929ce195228083c6ddc9cec4\ndir0/d\x00538206dc971e521540d6843abfe6d16032f6d426\n',
    {
      b'deltabasenode': b'\x1b\x17[Y_\x02,\xfa\xb5\xb8\t\xcc\x0e\xd5Q\xbd\x0b?\xf5\xe4',
      b'fieldsfollowing': [
        [
          b'delta',
          55
        ]
      ],
      b'node': b'F\xa6r\x1b^\xda\xf0\xea\x04\xb7\x9a\\\xb3!\x88T\xa4\xd2\xab\xa0',
      b'parents': [
        b'\x1b\x17[Y_\x02,\xfa\xb5\xb8\t\xcc\x0e\xd5Q\xbd\x0b?\xf5\xe4',
        b'\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00'
      ]
    },
    b'\x00\x00\x00\x00\x00\x00\x00+\x00\x00\x00+a\x000879345e39377229634b420c639454156726c6b6\n'
  ]

  $ cat error.log
