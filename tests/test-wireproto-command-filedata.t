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
  

  $ hg --debug debugindex a
     rev linkrev nodeid                                   p1                                       p2
       0       0 2b4eb07319bfa077a40a2f04913659aef0da42da 0000000000000000000000000000000000000000 0000000000000000000000000000000000000000
       1       1 9a38122997b3ac97be2a9aa2e556838341fdf2cc 2b4eb07319bfa077a40a2f04913659aef0da42da 0000000000000000000000000000000000000000
       2       2 0879345e39377229634b420c639454156726c6b6 2b4eb07319bfa077a40a2f04913659aef0da42da 0000000000000000000000000000000000000000

  $ hg --debug debugindex dir0/child0/e
     rev linkrev nodeid                                   p1                                       p2
       0       0 bbba6c06b30f443d34ff841bc985c4d0827c6be4 0000000000000000000000000000000000000000 0000000000000000000000000000000000000000

  $ hg serve -p $HGPORT -d --pid-file hg.pid -E error.log
  $ cat hg.pid > $DAEMON_PIDS

Missing arguments is an error

  $ sendhttpv2peer << EOF
  > command filedata
  > EOF
  creating http peer for wire protocol version 2
  sending filedata command
  s>     POST /api/exp-http-v2-0001/ro/filedata HTTP/1.1\r\n
  s>     Accept-Encoding: identity\r\n
  s>     accept: application/mercurial-exp-framing-0005\r\n
  s>     content-type: application/mercurial-exp-framing-0005\r\n
  s>     content-length: 23\r\n
  s>     host: $LOCALIP:$HGPORT\r\n (glob)
  s>     user-agent: Mercurial debugwireproto\r\n
  s>     \r\n
  s>     \x0f\x00\x00\x01\x00\x01\x01\x11\xa1DnameHfiledata
  s> makefile('rb', None)
  s>     HTTP/1.1 200 OK\r\n
  s>     Server: testing stub value\r\n
  s>     Date: $HTTP_DATE$\r\n
  s>     Content-Type: application/mercurial-exp-framing-0005\r\n
  s>     Transfer-Encoding: chunked\r\n
  s>     \r\n
  s>     45\r\n
  s>     =\x00\x00\x01\x00\x02\x012
  s>     \xa2Eerror\xa1GmessageX\x1enodes argument must be definedFstatusEerror
  s>     \r\n
  received frame(size=61; request=1; stream=2; streamflags=stream-begin; type=command-response; flags=eos)
  s>     0\r\n
  s>     \r\n
  abort: nodes argument must be defined!
  [255]

  $ sendhttpv2peer << EOF
  > command filedata
  >     nodes eval:[]
  > EOF
  creating http peer for wire protocol version 2
  sending filedata command
  s>     POST /api/exp-http-v2-0001/ro/filedata HTTP/1.1\r\n
  s>     Accept-Encoding: identity\r\n
  s>     accept: application/mercurial-exp-framing-0005\r\n
  s>     content-type: application/mercurial-exp-framing-0005\r\n
  s>     content-length: 36\r\n
  s>     host: $LOCALIP:$HGPORT\r\n (glob)
  s>     user-agent: Mercurial debugwireproto\r\n
  s>     \r\n
  s>     \x1c\x00\x00\x01\x00\x01\x01\x11\xa2Dargs\xa1Enodes\x80DnameHfiledata
  s> makefile('rb', None)
  s>     HTTP/1.1 200 OK\r\n
  s>     Server: testing stub value\r\n
  s>     Date: $HTTP_DATE$\r\n
  s>     Content-Type: application/mercurial-exp-framing-0005\r\n
  s>     Transfer-Encoding: chunked\r\n
  s>     \r\n
  s>     44\r\n
  s>     <\x00\x00\x01\x00\x02\x012
  s>     \xa2Eerror\xa1GmessageX\x1dpath argument must be definedFstatusEerror
  s>     \r\n
  received frame(size=60; request=1; stream=2; streamflags=stream-begin; type=command-response; flags=eos)
  s>     0\r\n
  s>     \r\n
  abort: path argument must be defined!
  [255]

Unknown node is an error

  $ sendhttpv2peer << EOF
  > command filedata
  >     nodes eval:[b'\xaa\xaa\xaa\xaa\xaa\xaa\xaa\xaa\xaa\xaa\xaa\xaa\xaa\xaa\xaa\xaa\xaa\xaa\xaa\xaa']
  >     path eval:b'a'
  > EOF
  creating http peer for wire protocol version 2
  sending filedata command
  s>     POST /api/exp-http-v2-0001/ro/filedata HTTP/1.1\r\n
  s>     Accept-Encoding: identity\r\n
  s>     accept: application/mercurial-exp-framing-0005\r\n
  s>     content-type: application/mercurial-exp-framing-0005\r\n
  s>     content-length: 64\r\n
  s>     host: $LOCALIP:$HGPORT\r\n (glob)
  s>     user-agent: Mercurial debugwireproto\r\n
  s>     \r\n
  s>     8\x00\x00\x01\x00\x01\x01\x11\xa2Dargs\xa2Enodes\x81T\xaa\xaa\xaa\xaa\xaa\xaa\xaa\xaa\xaa\xaa\xaa\xaa\xaa\xaa\xaa\xaa\xaa\xaa\xaa\xaaDpathAaDnameHfiledata
  s> makefile('rb', None)
  s>     HTTP/1.1 200 OK\r\n
  s>     Server: testing stub value\r\n
  s>     Date: $HTTP_DATE$\r\n
  s>     Content-Type: application/mercurial-exp-framing-0005\r\n
  s>     Transfer-Encoding: chunked\r\n
  s>     \r\n
  s>     6b\r\n
  s>     c\x00\x00\x01\x00\x02\x012
  s>     \xa2Eerror\xa2Dargs\x81X(aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaGmessageUunknown file node: %sFstatusEerror
  s>     \r\n
  received frame(size=99; request=1; stream=2; streamflags=stream-begin; type=command-response; flags=eos)
  s>     0\r\n
  s>     \r\n
  abort: unknown file node: aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa!
  [255]

Fetching a single revision returns just metadata by default

  $ sendhttpv2peer << EOF
  > command filedata
  >     nodes eval:[b'\x9a\x38\x12\x29\x97\xb3\xac\x97\xbe\x2a\x9a\xa2\xe5\x56\x83\x83\x41\xfd\xf2\xcc']
  >     path eval:b'a'
  > EOF
  creating http peer for wire protocol version 2
  sending filedata command
  s>     POST /api/exp-http-v2-0001/ro/filedata HTTP/1.1\r\n
  s>     Accept-Encoding: identity\r\n
  s>     accept: application/mercurial-exp-framing-0005\r\n
  s>     content-type: application/mercurial-exp-framing-0005\r\n
  s>     content-length: 64\r\n
  s>     host: $LOCALIP:$HGPORT\r\n (glob)
  s>     user-agent: Mercurial debugwireproto\r\n
  s>     \r\n
  s>     8\x00\x00\x01\x00\x01\x01\x11\xa2Dargs\xa2Enodes\x81T\x9a8\x12)\x97\xb3\xac\x97\xbe*\x9a\xa2\xe5V\x83\x83A\xfd\xf2\xccDpathAaDnameHfiledata
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
  s>     \xa1Jtotalitems\x01\xa1DnodeT\x9a8\x12)\x97\xb3\xac\x97\xbe*\x9a\xa2\xe5V\x83\x83A\xfd\xf2\xcc
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
      b'node': b'\x9a8\x12)\x97\xb3\xac\x97\xbe*\x9a\xa2\xe5V\x83\x83A\xfd\xf2\xcc'
    }
  ]

Requesting parents works

  $ sendhttpv2peer << EOF
  > command filedata
  >     nodes eval:[b'\x9a\x38\x12\x29\x97\xb3\xac\x97\xbe\x2a\x9a\xa2\xe5\x56\x83\x83\x41\xfd\xf2\xcc']
  >     path eval:b'a'
  >     fields eval:[b'parents']
  > EOF
  creating http peer for wire protocol version 2
  sending filedata command
  s>     POST /api/exp-http-v2-0001/ro/filedata HTTP/1.1\r\n
  s>     Accept-Encoding: identity\r\n
  s>     accept: application/mercurial-exp-framing-0005\r\n
  s>     content-type: application/mercurial-exp-framing-0005\r\n
  s>     content-length: 80\r\n
  s>     host: $LOCALIP:$HGPORT\r\n (glob)
  s>     user-agent: Mercurial debugwireproto\r\n
  s>     \r\n
  s>     H\x00\x00\x01\x00\x01\x01\x11\xa2Dargs\xa3Ffields\x81GparentsEnodes\x81T\x9a8\x12)\x97\xb3\xac\x97\xbe*\x9a\xa2\xe5V\x83\x83A\xfd\xf2\xccDpathAaDnameHfiledata
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
  s>     \xa1Jtotalitems\x01\xa2DnodeT\x9a8\x12)\x97\xb3\xac\x97\xbe*\x9a\xa2\xe5V\x83\x83A\xfd\xf2\xccGparents\x82T+N\xb0s\x19\xbf\xa0w\xa4\n
  s>     /\x04\x916Y\xae\xf0\xdaB\xdaT\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00
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
      b'node': b'\x9a8\x12)\x97\xb3\xac\x97\xbe*\x9a\xa2\xe5V\x83\x83A\xfd\xf2\xcc',
      b'parents': [
        b'+N\xb0s\x19\xbf\xa0w\xa4\n/\x04\x916Y\xae\xf0\xdaB\xda',
        b'\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00'
      ]
    }
  ]

Requesting revision data works

  $ sendhttpv2peer << EOF
  > command filedata
  >     nodes eval:[b'\x9a\x38\x12\x29\x97\xb3\xac\x97\xbe\x2a\x9a\xa2\xe5\x56\x83\x83\x41\xfd\xf2\xcc']
  >     path eval:b'a'
  >     fields eval:[b'revision']
  > EOF
  creating http peer for wire protocol version 2
  sending filedata command
  s>     POST /api/exp-http-v2-0001/ro/filedata HTTP/1.1\r\n
  s>     Accept-Encoding: identity\r\n
  s>     accept: application/mercurial-exp-framing-0005\r\n
  s>     content-type: application/mercurial-exp-framing-0005\r\n
  s>     content-length: 81\r\n
  s>     host: $LOCALIP:$HGPORT\r\n (glob)
  s>     user-agent: Mercurial debugwireproto\r\n
  s>     \r\n
  s>     I\x00\x00\x01\x00\x01\x01\x11\xa2Dargs\xa3Ffields\x81HrevisionEnodes\x81T\x9a8\x12)\x97\xb3\xac\x97\xbe*\x9a\xa2\xe5V\x83\x83A\xfd\xf2\xccDpathAaDnameHfiledata
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
  s>     6e\r\n
  s>     f\x00\x00\x01\x00\x02\x001
  s>     \xa1Jtotalitems\x01\xa3MdeltabasenodeT+N\xb0s\x19\xbf\xa0w\xa4\n
  s>     /\x04\x916Y\xae\xf0\xdaB\xdaIdeltasize\x0fDnodeT\x9a8\x12)\x97\xb3\xac\x97\xbe*\x9a\xa2\xe5V\x83\x83A\xfd\xf2\xccO\x00\x00\x00\x00\x00\x00\x00\x03\x00\x00\x00\x03a1\n
  s>     \r\n
  received frame(size=102; request=1; stream=2; streamflags=; type=command-response; flags=continuation)
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
      b'deltabasenode': b'+N\xb0s\x19\xbf\xa0w\xa4\n/\x04\x916Y\xae\xf0\xdaB\xda',
      b'deltasize': 15,
      b'node': b'\x9a8\x12)\x97\xb3\xac\x97\xbe*\x9a\xa2\xe5V\x83\x83A\xfd\xf2\xcc'
    },
    b'\x00\x00\x00\x00\x00\x00\x00\x03\x00\x00\x00\x03a1\n'
  ]

Requesting multiple revisions works
(first revision should be fulltext, subsequents are deltas)

  $ sendhttpv2peer << EOF
  > command filedata
  >     nodes eval:['\x2b\x4e\xb0\x73\x19\xbf\xa0\x77\xa4\x0a\x2f\x04\x91\x36\x59\xae\xf0\xda\x42\xda', '\x9a\x38\x12\x29\x97\xb3\xac\x97\xbe\x2a\x9a\xa2\xe5\x56\x83\x83\x41\xfd\xf2\xcc']
  >     path eval:b'a'
  >     fields eval:[b'revision']
  > EOF
  creating http peer for wire protocol version 2
  sending filedata command
  s>     POST /api/exp-http-v2-0001/ro/filedata HTTP/1.1\r\n
  s>     Accept-Encoding: identity\r\n
  s>     accept: application/mercurial-exp-framing-0005\r\n
  s>     content-type: application/mercurial-exp-framing-0005\r\n
  s>     content-length: 102\r\n
  s>     host: $LOCALIP:$HGPORT\r\n (glob)
  s>     user-agent: Mercurial debugwireproto\r\n
  s>     \r\n
  s>     ^\x00\x00\x01\x00\x01\x01\x11\xa2Dargs\xa3Ffields\x81HrevisionEnodes\x82T+N\xb0s\x19\xbf\xa0w\xa4\n
  s>     /\x04\x916Y\xae\xf0\xdaB\xdaT\x9a8\x12)\x97\xb3\xac\x97\xbe*\x9a\xa2\xe5V\x83\x83A\xfd\xf2\xccDpathAaDnameHfiledata
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
  s>     9b\r\n
  s>     \x93\x00\x00\x01\x00\x02\x001
  s>     \xa1Jtotalitems\x02\xa2DnodeT+N\xb0s\x19\xbf\xa0w\xa4\n
  s>     /\x04\x916Y\xae\xf0\xdaB\xdaLrevisionsize\x03Ca0\n
  s>     \xa3MdeltabasenodeT+N\xb0s\x19\xbf\xa0w\xa4\n
  s>     /\x04\x916Y\xae\xf0\xdaB\xdaIdeltasize\x0fDnodeT\x9a8\x12)\x97\xb3\xac\x97\xbe*\x9a\xa2\xe5V\x83\x83A\xfd\xf2\xccO\x00\x00\x00\x00\x00\x00\x00\x03\x00\x00\x00\x03a1\n
  s>     \r\n
  received frame(size=147; request=1; stream=2; streamflags=; type=command-response; flags=continuation)
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
      b'node': b'+N\xb0s\x19\xbf\xa0w\xa4\n/\x04\x916Y\xae\xf0\xdaB\xda',
      b'revisionsize': 3
    },
    b'a0\n',
    {
      b'deltabasenode': b'+N\xb0s\x19\xbf\xa0w\xa4\n/\x04\x916Y\xae\xf0\xdaB\xda',
      b'deltasize': 15,
      b'node': b'\x9a8\x12)\x97\xb3\xac\x97\xbe*\x9a\xa2\xe5V\x83\x83A\xfd\xf2\xcc'
    },
    b'\x00\x00\x00\x00\x00\x00\x00\x03\x00\x00\x00\x03a1\n'
  ]

Revisions are sorted by DAG order, parents first

  $ sendhttpv2peer << EOF
  > command filedata
  >     nodes eval:['\x9a\x38\x12\x29\x97\xb3\xac\x97\xbe\x2a\x9a\xa2\xe5\x56\x83\x83\x41\xfd\xf2\xcc', '\x2b\x4e\xb0\x73\x19\xbf\xa0\x77\xa4\x0a\x2f\x04\x91\x36\x59\xae\xf0\xda\x42\xda']
  >     path eval:b'a'
  >     fields eval:[b'revision']
  > EOF
  creating http peer for wire protocol version 2
  sending filedata command
  s>     POST /api/exp-http-v2-0001/ro/filedata HTTP/1.1\r\n
  s>     Accept-Encoding: identity\r\n
  s>     accept: application/mercurial-exp-framing-0005\r\n
  s>     content-type: application/mercurial-exp-framing-0005\r\n
  s>     content-length: 102\r\n
  s>     host: $LOCALIP:$HGPORT\r\n (glob)
  s>     user-agent: Mercurial debugwireproto\r\n
  s>     \r\n
  s>     ^\x00\x00\x01\x00\x01\x01\x11\xa2Dargs\xa3Ffields\x81HrevisionEnodes\x82T\x9a8\x12)\x97\xb3\xac\x97\xbe*\x9a\xa2\xe5V\x83\x83A\xfd\xf2\xccT+N\xb0s\x19\xbf\xa0w\xa4\n
  s>     /\x04\x916Y\xae\xf0\xdaB\xdaDpathAaDnameHfiledata
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
  s>     9b\r\n
  s>     \x93\x00\x00\x01\x00\x02\x001
  s>     \xa1Jtotalitems\x02\xa2DnodeT+N\xb0s\x19\xbf\xa0w\xa4\n
  s>     /\x04\x916Y\xae\xf0\xdaB\xdaLrevisionsize\x03Ca0\n
  s>     \xa3MdeltabasenodeT+N\xb0s\x19\xbf\xa0w\xa4\n
  s>     /\x04\x916Y\xae\xf0\xdaB\xdaIdeltasize\x0fDnodeT\x9a8\x12)\x97\xb3\xac\x97\xbe*\x9a\xa2\xe5V\x83\x83A\xfd\xf2\xccO\x00\x00\x00\x00\x00\x00\x00\x03\x00\x00\x00\x03a1\n
  s>     \r\n
  received frame(size=147; request=1; stream=2; streamflags=; type=command-response; flags=continuation)
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
      b'node': b'+N\xb0s\x19\xbf\xa0w\xa4\n/\x04\x916Y\xae\xf0\xdaB\xda',
      b'revisionsize': 3
    },
    b'a0\n',
    {
      b'deltabasenode': b'+N\xb0s\x19\xbf\xa0w\xa4\n/\x04\x916Y\xae\xf0\xdaB\xda',
      b'deltasize': 15,
      b'node': b'\x9a8\x12)\x97\xb3\xac\x97\xbe*\x9a\xa2\xe5V\x83\x83A\xfd\xf2\xcc'
    },
    b'\x00\x00\x00\x00\x00\x00\x00\x03\x00\x00\x00\x03a1\n'
  ]

Requesting parents and revision data works

  $ sendhttpv2peer << EOF
  > command filedata
  >     nodes eval:['\x08\x79\x34\x5e\x39\x37\x72\x29\x63\x4b\x42\x0c\x63\x94\x54\x15\x67\x26\xc6\xb6']
  >     path eval:b'a'
  >     fields eval:[b'parents', b'revision']
  > EOF
  creating http peer for wire protocol version 2
  sending filedata command
  s>     POST /api/exp-http-v2-0001/ro/filedata HTTP/1.1\r\n
  s>     Accept-Encoding: identity\r\n
  s>     accept: application/mercurial-exp-framing-0005\r\n
  s>     content-type: application/mercurial-exp-framing-0005\r\n
  s>     content-length: 89\r\n
  s>     host: $LOCALIP:$HGPORT\r\n (glob)
  s>     user-agent: Mercurial debugwireproto\r\n
  s>     \r\n
  s>     Q\x00\x00\x01\x00\x01\x01\x11\xa2Dargs\xa3Ffields\x82GparentsHrevisionEnodes\x81T\x08y4^97r)cKB\x0cc\x94T\x15g&\xc6\xb6DpathAaDnameHfiledata
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
  s>     a1\r\n
  s>     \x99\x00\x00\x01\x00\x02\x001
  s>     \xa1Jtotalitems\x01\xa4MdeltabasenodeT+N\xb0s\x19\xbf\xa0w\xa4\n
  s>     /\x04\x916Y\xae\xf0\xdaB\xdaIdeltasize\x0fDnodeT\x08y4^97r)cKB\x0cc\x94T\x15g&\xc6\xb6Gparents\x82T+N\xb0s\x19\xbf\xa0w\xa4\n
  s>     /\x04\x916Y\xae\xf0\xdaB\xdaT\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00O\x00\x00\x00\x00\x00\x00\x00\x03\x00\x00\x00\x03a2\n
  s>     \r\n
  received frame(size=153; request=1; stream=2; streamflags=; type=command-response; flags=continuation)
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
      b'deltabasenode': b'+N\xb0s\x19\xbf\xa0w\xa4\n/\x04\x916Y\xae\xf0\xdaB\xda',
      b'deltasize': 15,
      b'node': b'\x08y4^97r)cKB\x0cc\x94T\x15g&\xc6\xb6',
      b'parents': [
        b'+N\xb0s\x19\xbf\xa0w\xa4\n/\x04\x916Y\xae\xf0\xdaB\xda',
        b'\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00'
      ]
    },
    b'\x00\x00\x00\x00\x00\x00\x00\x03\x00\x00\x00\x03a2\n'
  ]

  $ cat error.log
