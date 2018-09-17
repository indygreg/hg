  $ . $TESTDIR/wireprotohelpers.sh

  $ hg init server
  $ enablehttpv2 server
  $ cd server
  $ cat >> .hg/hgrc << EOF
  > [phases]
  > publish = false
  > EOF
  $ echo a0 > a
  $ echo b0 > b

  $ hg -q commit -A -m 'commit 0'

  $ echo a1 > a
  $ echo b1 > b
  $ hg commit -m 'commit 1'
  $ echo b2 > b
  $ hg commit -m 'commit 2'
  $ hg phase --public -r .

  $ hg -q up -r 0
  $ echo a2 > a
  $ hg commit -m 'commit 3'
  created new head

  $ hg log -G -T '{rev}:{node} {desc}\n'
  @  3:eae5f82c2e622368d27daecb76b7e393d0f24211 commit 3
  |
  | o  2:0bb8ad894a15b15380b2a2a5b183e20f2a4b28dd commit 2
  | |
  | o  1:7592917e1c3e82677cb0a4bc715ca25dd12d28c1 commit 1
  |/
  o  0:3390ef850073fbc2f0dfff2244342c8e9229013a commit 0
  

  $ hg serve -p $HGPORT -d --pid-file hg.pid -E error.log
  $ cat hg.pid > $DAEMON_PIDS

No arguments is an invalid request

  $ sendhttpv2peer << EOF
  > command changesetdata
  > EOF
  creating http peer for wire protocol version 2
  sending changesetdata command
  s>     POST /api/exp-http-v2-0002/ro/changesetdata HTTP/1.1\r\n
  s>     Accept-Encoding: identity\r\n
  s>     accept: application/mercurial-exp-framing-0005\r\n
  s>     content-type: application/mercurial-exp-framing-0005\r\n
  s>     content-length: 28\r\n
  s>     host: $LOCALIP:$HGPORT\r\n (glob)
  s>     user-agent: Mercurial debugwireproto\r\n
  s>     \r\n
  s>     \x14\x00\x00\x01\x00\x01\x01\x11\xa1DnameMchangesetdata
  s> makefile('rb', None)
  s>     HTTP/1.1 200 OK\r\n
  s>     Server: testing stub value\r\n
  s>     Date: $HTTP_DATE$\r\n
  s>     Content-Type: application/mercurial-exp-framing-0005\r\n
  s>     Transfer-Encoding: chunked\r\n
  s>     \r\n
  s>     49\r\n
  s>     A\x00\x00\x01\x00\x02\x012
  s>     \xa2Eerror\xa1GmessageX"noderange or nodes must be definedFstatusEerror
  s>     \r\n
  received frame(size=65; request=1; stream=2; streamflags=stream-begin; type=command-response; flags=eos)
  s>     0\r\n
  s>     \r\n
  abort: noderange or nodes must be defined!
  [255]

Empty noderange heads results in an error

  $ sendhttpv2peer << EOF
  > command changesetdata
  >     noderange eval:[[],[]]
  > EOF
  creating http peer for wire protocol version 2
  sending changesetdata command
  s>     POST /api/exp-http-v2-0002/ro/changesetdata HTTP/1.1\r\n
  s>     Accept-Encoding: identity\r\n
  s>     accept: application/mercurial-exp-framing-0005\r\n
  s>     content-type: application/mercurial-exp-framing-0005\r\n
  s>     content-length: 47\r\n
  s>     host: $LOCALIP:$HGPORT\r\n (glob)
  s>     user-agent: Mercurial debugwireproto\r\n
  s>     \r\n
  s>     \'\x00\x00\x01\x00\x01\x01\x11\xa2Dargs\xa1Inoderange\x82\x80\x80DnameMchangesetdata
  s> makefile('rb', None)
  s>     HTTP/1.1 200 OK\r\n
  s>     Server: testing stub value\r\n
  s>     Date: $HTTP_DATE$\r\n
  s>     Content-Type: application/mercurial-exp-framing-0005\r\n
  s>     Transfer-Encoding: chunked\r\n
  s>     \r\n
  s>     51\r\n
  s>     I\x00\x00\x01\x00\x02\x012
  s>     \xa2Eerror\xa1GmessageX*heads in noderange request cannot be emptyFstatusEerror
  s>     \r\n
  received frame(size=73; request=1; stream=2; streamflags=stream-begin; type=command-response; flags=eos)
  s>     0\r\n
  s>     \r\n
  abort: heads in noderange request cannot be empty!
  [255]

nodesdepth requires nodes argument

  $ sendhttpv2peer << EOF
  > command changesetdata
  >     nodesdepth 42
  >     noderange eval:[[], [b'ignored']]
  > EOF
  creating http peer for wire protocol version 2
  sending changesetdata command
  s>     POST /api/exp-http-v2-0002/ro/changesetdata HTTP/1.1\r\n
  s>     Accept-Encoding: identity\r\n
  s>     accept: application/mercurial-exp-framing-0005\r\n
  s>     content-type: application/mercurial-exp-framing-0005\r\n
  s>     content-length: 69\r\n
  s>     host: $LOCALIP:$HGPORT\r\n (glob)
  s>     user-agent: Mercurial debugwireproto\r\n
  s>     \r\n
  s>     =\x00\x00\x01\x00\x01\x01\x11\xa2Dargs\xa2Inoderange\x82\x80\x81GignoredJnodesdepthB42DnameMchangesetdata
  s> makefile('rb', None)
  s>     HTTP/1.1 200 OK\r\n
  s>     Server: testing stub value\r\n
  s>     Date: $HTTP_DATE$\r\n
  s>     Content-Type: application/mercurial-exp-framing-0005\r\n
  s>     Transfer-Encoding: chunked\r\n
  s>     \r\n
  s>     4d\r\n
  s>     E\x00\x00\x01\x00\x02\x012
  s>     \xa2Eerror\xa1GmessageX&nodesdepth requires the nodes argumentFstatusEerror
  s>     \r\n
  received frame(size=69; request=1; stream=2; streamflags=stream-begin; type=command-response; flags=eos)
  s>     0\r\n
  s>     \r\n
  abort: nodesdepth requires the nodes argument!
  [255]

Sending just noderange heads sends all revisions

  $ sendhttpv2peer << EOF
  > command changesetdata
  >     noderange eval:[[], [b'\x0b\xb8\xad\x89\x4a\x15\xb1\x53\x80\xb2\xa2\xa5\xb1\x83\xe2\x0f\x2a\x4b\x28\xdd', b'\xea\xe5\xf8\x2c\x2e\x62\x23\x68\xd2\x7d\xae\xcb\x76\xb7\xe3\x93\xd0\xf2\x42\x11']]
  > EOF
  creating http peer for wire protocol version 2
  sending changesetdata command
  s>     POST /api/exp-http-v2-0002/ro/changesetdata HTTP/1.1\r\n
  s>     Accept-Encoding: identity\r\n
  s>     accept: application/mercurial-exp-framing-0005\r\n
  s>     content-type: application/mercurial-exp-framing-0005\r\n
  s>     content-length: 89\r\n
  s>     host: $LOCALIP:$HGPORT\r\n (glob)
  s>     user-agent: Mercurial debugwireproto\r\n
  s>     \r\n
  s>     Q\x00\x00\x01\x00\x01\x01\x11\xa2Dargs\xa1Inoderange\x82\x80\x82T\x0b\xb8\xad\x89J\x15\xb1S\x80\xb2\xa2\xa5\xb1\x83\xe2\x0f*K(\xddT\xea\xe5\xf8,.b#h\xd2}\xae\xcbv\xb7\xe3\x93\xd0\xf2B\x11DnameMchangesetdata
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
  s>     81\r\n
  s>     y\x00\x00\x01\x00\x02\x001
  s>     \xa1Jtotalitems\x04\xa1DnodeT3\x90\xef\x85\x00s\xfb\xc2\xf0\xdf\xff"D4,\x8e\x92)\x01:\xa1DnodeTu\x92\x91~\x1c>\x82g|\xb0\xa4\xbcq\\\xa2]\xd1-(\xc1\xa1DnodeT\x0b\xb8\xad\x89J\x15\xb1S\x80\xb2\xa2\xa5\xb1\x83\xe2\x0f*K(\xdd\xa1DnodeT\xea\xe5\xf8,.b#h\xd2}\xae\xcbv\xb7\xe3\x93\xd0\xf2B\x11
  s>     \r\n
  received frame(size=121; request=1; stream=2; streamflags=; type=command-response; flags=continuation)
  s>     8\r\n
  s>     \x00\x00\x00\x01\x00\x02\x002
  s>     \r\n
  s>     0\r\n
  s>     \r\n
  received frame(size=0; request=1; stream=2; streamflags=; type=command-response; flags=eos)
  response: gen[
    {
      b'totalitems': 4
    },
    {
      b'node': b'3\x90\xef\x85\x00s\xfb\xc2\xf0\xdf\xff"D4,\x8e\x92)\x01:'
    },
    {
      b'node': b'u\x92\x91~\x1c>\x82g|\xb0\xa4\xbcq\\\xa2]\xd1-(\xc1'
    },
    {
      b'node': b'\x0b\xb8\xad\x89J\x15\xb1S\x80\xb2\xa2\xa5\xb1\x83\xe2\x0f*K(\xdd'
    },
    {
      b'node': b'\xea\xe5\xf8,.b#h\xd2}\xae\xcbv\xb7\xe3\x93\xd0\xf2B\x11'
    }
  ]

Sending root nodes limits what data is sent

  $ sendhttpv2peer << EOF
  > command changesetdata
  >     noderange eval:[[b'\x33\x90\xef\x85\x00\x73\xfb\xc2\xf0\xdf\xff\x22\x44\x34\x2c\x8e\x92\x29\x01\x3a'], [b'\x0b\xb8\xad\x89\x4a\x15\xb1\x53\x80\xb2\xa2\xa5\xb1\x83\xe2\x0f\x2a\x4b\x28\xdd']]
  > EOF
  creating http peer for wire protocol version 2
  sending changesetdata command
  s>     POST /api/exp-http-v2-0002/ro/changesetdata HTTP/1.1\r\n
  s>     Accept-Encoding: identity\r\n
  s>     accept: application/mercurial-exp-framing-0005\r\n
  s>     content-type: application/mercurial-exp-framing-0005\r\n
  s>     content-length: 89\r\n
  s>     host: $LOCALIP:$HGPORT\r\n (glob)
  s>     user-agent: Mercurial debugwireproto\r\n
  s>     \r\n
  s>     Q\x00\x00\x01\x00\x01\x01\x11\xa2Dargs\xa1Inoderange\x82\x81T3\x90\xef\x85\x00s\xfb\xc2\xf0\xdf\xff"D4,\x8e\x92)\x01:\x81T\x0b\xb8\xad\x89J\x15\xb1S\x80\xb2\xa2\xa5\xb1\x83\xe2\x0f*K(\xddDnameMchangesetdata
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
  s>     4b\r\n
  s>     C\x00\x00\x01\x00\x02\x001
  s>     \xa1Jtotalitems\x02\xa1DnodeTu\x92\x91~\x1c>\x82g|\xb0\xa4\xbcq\\\xa2]\xd1-(\xc1\xa1DnodeT\x0b\xb8\xad\x89J\x15\xb1S\x80\xb2\xa2\xa5\xb1\x83\xe2\x0f*K(\xdd
  s>     \r\n
  received frame(size=67; request=1; stream=2; streamflags=; type=command-response; flags=continuation)
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
      b'node': b'u\x92\x91~\x1c>\x82g|\xb0\xa4\xbcq\\\xa2]\xd1-(\xc1'
    },
    {
      b'node': b'\x0b\xb8\xad\x89J\x15\xb1S\x80\xb2\xa2\xa5\xb1\x83\xe2\x0f*K(\xdd'
    }
  ]

Requesting data on a single node by node works

  $ sendhttpv2peer << EOF
  > command changesetdata
  >     nodes eval:[b'\x33\x90\xef\x85\x00\x73\xfb\xc2\xf0\xdf\xff\x22\x44\x34\x2c\x8e\x92\x29\x01\x3a']
  > EOF
  creating http peer for wire protocol version 2
  sending changesetdata command
  s>     POST /api/exp-http-v2-0002/ro/changesetdata HTTP/1.1\r\n
  s>     Accept-Encoding: identity\r\n
  s>     accept: application/mercurial-exp-framing-0005\r\n
  s>     content-type: application/mercurial-exp-framing-0005\r\n
  s>     content-length: 62\r\n
  s>     host: $LOCALIP:$HGPORT\r\n (glob)
  s>     user-agent: Mercurial debugwireproto\r\n
  s>     \r\n
  s>     6\x00\x00\x01\x00\x01\x01\x11\xa2Dargs\xa1Enodes\x81T3\x90\xef\x85\x00s\xfb\xc2\xf0\xdf\xff"D4,\x8e\x92)\x01:DnameMchangesetdata
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
  s>     \xa1Jtotalitems\x01\xa1DnodeT3\x90\xef\x85\x00s\xfb\xc2\xf0\xdf\xff"D4,\x8e\x92)\x01:
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
      b'node': b'3\x90\xef\x85\x00s\xfb\xc2\xf0\xdf\xff"D4,\x8e\x92)\x01:'
    }
  ]

Specifying a noderange and nodes takes union

  $ sendhttpv2peer << EOF
  > command changesetdata
  >     noderange eval:[[b'\x75\x92\x91\x7e\x1c\x3e\x82\x67\x7c\xb0\xa4\xbc\x71\x5c\xa2\x5d\xd1\x2d\x28\xc1'], [b'\x0b\xb8\xad\x89\x4a\x15\xb1\x53\x80\xb2\xa2\xa5\xb1\x83\xe2\x0f\x2a\x4b\x28\xdd']]
  >     nodes eval:[b'\xea\xe5\xf8\x2c\x2e\x62\x23\x68\xd2\x7d\xae\xcb\x76\xb7\xe3\x93\xd0\xf2\x42\x11']
  > EOF
  creating http peer for wire protocol version 2
  sending changesetdata command
  s>     POST /api/exp-http-v2-0002/ro/changesetdata HTTP/1.1\r\n
  s>     Accept-Encoding: identity\r\n
  s>     accept: application/mercurial-exp-framing-0005\r\n
  s>     content-type: application/mercurial-exp-framing-0005\r\n
  s>     content-length: 117\r\n
  s>     host: $LOCALIP:$HGPORT\r\n (glob)
  s>     user-agent: Mercurial debugwireproto\r\n
  s>     \r\n
  s>     m\x00\x00\x01\x00\x01\x01\x11\xa2Dargs\xa2Inoderange\x82\x81Tu\x92\x91~\x1c>\x82g|\xb0\xa4\xbcq\\\xa2]\xd1-(\xc1\x81T\x0b\xb8\xad\x89J\x15\xb1S\x80\xb2\xa2\xa5\xb1\x83\xe2\x0f*K(\xddEnodes\x81T\xea\xe5\xf8,.b#h\xd2}\xae\xcbv\xb7\xe3\x93\xd0\xf2B\x11DnameMchangesetdata
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
  s>     4b\r\n
  s>     C\x00\x00\x01\x00\x02\x001
  s>     \xa1Jtotalitems\x02\xa1DnodeT\xea\xe5\xf8,.b#h\xd2}\xae\xcbv\xb7\xe3\x93\xd0\xf2B\x11\xa1DnodeT\x0b\xb8\xad\x89J\x15\xb1S\x80\xb2\xa2\xa5\xb1\x83\xe2\x0f*K(\xdd
  s>     \r\n
  received frame(size=67; request=1; stream=2; streamflags=; type=command-response; flags=continuation)
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
      b'node': b'\xea\xe5\xf8,.b#h\xd2}\xae\xcbv\xb7\xe3\x93\xd0\xf2B\x11'
    },
    {
      b'node': b'\x0b\xb8\xad\x89J\x15\xb1S\x80\xb2\xa2\xa5\xb1\x83\xe2\x0f*K(\xdd'
    }
  ]

nodesdepth of 1 limits to exactly requested nodes

  $ sendhttpv2peer << EOF
  > command changesetdata
  >     nodes eval:[b'\xea\xe5\xf8\x2c\x2e\x62\x23\x68\xd2\x7d\xae\xcb\x76\xb7\xe3\x93\xd0\xf2\x42\x11']
  >     nodesdepth eval:1
  > EOF
  creating http peer for wire protocol version 2
  sending changesetdata command
  s>     POST /api/exp-http-v2-0002/ro/changesetdata HTTP/1.1\r\n
  s>     Accept-Encoding: identity\r\n
  s>     accept: application/mercurial-exp-framing-0005\r\n
  s>     content-type: application/mercurial-exp-framing-0005\r\n
  s>     content-length: 74\r\n
  s>     host: $LOCALIP:$HGPORT\r\n (glob)
  s>     user-agent: Mercurial debugwireproto\r\n
  s>     \r\n
  s>     B\x00\x00\x01\x00\x01\x01\x11\xa2Dargs\xa2Enodes\x81T\xea\xe5\xf8,.b#h\xd2}\xae\xcbv\xb7\xe3\x93\xd0\xf2B\x11Jnodesdepth\x01DnameMchangesetdata
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
  s>     \xa1Jtotalitems\x01\xa1DnodeT\xea\xe5\xf8,.b#h\xd2}\xae\xcbv\xb7\xe3\x93\xd0\xf2B\x11
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
      b'node': b'\xea\xe5\xf8,.b#h\xd2}\xae\xcbv\xb7\xe3\x93\xd0\xf2B\x11'
    }
  ]

nodesdepth of 2 limits to first ancestor

  $ sendhttpv2peer << EOF
  > command changesetdata
  >     nodes eval:[b'\xea\xe5\xf8\x2c\x2e\x62\x23\x68\xd2\x7d\xae\xcb\x76\xb7\xe3\x93\xd0\xf2\x42\x11']
  >     nodesdepth eval:2
  > EOF
  creating http peer for wire protocol version 2
  sending changesetdata command
  s>     POST /api/exp-http-v2-0002/ro/changesetdata HTTP/1.1\r\n
  s>     Accept-Encoding: identity\r\n
  s>     accept: application/mercurial-exp-framing-0005\r\n
  s>     content-type: application/mercurial-exp-framing-0005\r\n
  s>     content-length: 74\r\n
  s>     host: $LOCALIP:$HGPORT\r\n (glob)
  s>     user-agent: Mercurial debugwireproto\r\n
  s>     \r\n
  s>     B\x00\x00\x01\x00\x01\x01\x11\xa2Dargs\xa2Enodes\x81T\xea\xe5\xf8,.b#h\xd2}\xae\xcbv\xb7\xe3\x93\xd0\xf2B\x11Jnodesdepth\x02DnameMchangesetdata
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
  s>     4b\r\n
  s>     C\x00\x00\x01\x00\x02\x001
  s>     \xa1Jtotalitems\x02\xa1DnodeT3\x90\xef\x85\x00s\xfb\xc2\xf0\xdf\xff"D4,\x8e\x92)\x01:\xa1DnodeT\xea\xe5\xf8,.b#h\xd2}\xae\xcbv\xb7\xe3\x93\xd0\xf2B\x11
  s>     \r\n
  received frame(size=67; request=1; stream=2; streamflags=; type=command-response; flags=continuation)
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
      b'node': b'3\x90\xef\x85\x00s\xfb\xc2\xf0\xdf\xff"D4,\x8e\x92)\x01:'
    },
    {
      b'node': b'\xea\xe5\xf8,.b#h\xd2}\xae\xcbv\xb7\xe3\x93\xd0\xf2B\x11'
    }
  ]

nodesdepth with multiple nodes

  $ sendhttpv2peer << EOF
  > command changesetdata
  >     nodes eval:[b'\xea\xe5\xf8\x2c\x2e\x62\x23\x68\xd2\x7d\xae\xcb\x76\xb7\xe3\x93\xd0\xf2\x42\x11', b'\x0b\xb8\xad\x89\x4a\x15\xb1\x53\x80\xb2\xa2\xa5\xb1\x83\xe2\x0f\x2a\x4b\x28\xdd']
  >     nodesdepth eval:2
  > EOF
  creating http peer for wire protocol version 2
  sending changesetdata command
  s>     POST /api/exp-http-v2-0002/ro/changesetdata HTTP/1.1\r\n
  s>     Accept-Encoding: identity\r\n
  s>     accept: application/mercurial-exp-framing-0005\r\n
  s>     content-type: application/mercurial-exp-framing-0005\r\n
  s>     content-length: 95\r\n
  s>     host: $LOCALIP:$HGPORT\r\n (glob)
  s>     user-agent: Mercurial debugwireproto\r\n
  s>     \r\n
  s>     W\x00\x00\x01\x00\x01\x01\x11\xa2Dargs\xa2Enodes\x82T\xea\xe5\xf8,.b#h\xd2}\xae\xcbv\xb7\xe3\x93\xd0\xf2B\x11T\x0b\xb8\xad\x89J\x15\xb1S\x80\xb2\xa2\xa5\xb1\x83\xe2\x0f*K(\xddJnodesdepth\x02DnameMchangesetdata
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
  s>     81\r\n
  s>     y\x00\x00\x01\x00\x02\x001
  s>     \xa1Jtotalitems\x04\xa1DnodeT3\x90\xef\x85\x00s\xfb\xc2\xf0\xdf\xff"D4,\x8e\x92)\x01:\xa1DnodeTu\x92\x91~\x1c>\x82g|\xb0\xa4\xbcq\\\xa2]\xd1-(\xc1\xa1DnodeT\x0b\xb8\xad\x89J\x15\xb1S\x80\xb2\xa2\xa5\xb1\x83\xe2\x0f*K(\xdd\xa1DnodeT\xea\xe5\xf8,.b#h\xd2}\xae\xcbv\xb7\xe3\x93\xd0\xf2B\x11
  s>     \r\n
  received frame(size=121; request=1; stream=2; streamflags=; type=command-response; flags=continuation)
  s>     8\r\n
  s>     \x00\x00\x00\x01\x00\x02\x002
  s>     \r\n
  s>     0\r\n
  s>     \r\n
  received frame(size=0; request=1; stream=2; streamflags=; type=command-response; flags=eos)
  response: gen[
    {
      b'totalitems': 4
    },
    {
      b'node': b'3\x90\xef\x85\x00s\xfb\xc2\xf0\xdf\xff"D4,\x8e\x92)\x01:'
    },
    {
      b'node': b'u\x92\x91~\x1c>\x82g|\xb0\xa4\xbcq\\\xa2]\xd1-(\xc1'
    },
    {
      b'node': b'\x0b\xb8\xad\x89J\x15\xb1S\x80\xb2\xa2\xa5\xb1\x83\xe2\x0f*K(\xdd'
    },
    {
      b'node': b'\xea\xe5\xf8,.b#h\xd2}\xae\xcbv\xb7\xe3\x93\xd0\xf2B\x11'
    }
  ]

Parents data is transferred upon request

  $ sendhttpv2peer << EOF
  > command changesetdata
  >     fields eval:[b'parents']
  >     nodes eval:[b'\xea\xe5\xf8\x2c\x2e\x62\x23\x68\xd2\x7d\xae\xcb\x76\xb7\xe3\x93\xd0\xf2\x42\x11']
  > EOF
  creating http peer for wire protocol version 2
  sending changesetdata command
  s>     POST /api/exp-http-v2-0002/ro/changesetdata HTTP/1.1\r\n
  s>     Accept-Encoding: identity\r\n
  s>     accept: application/mercurial-exp-framing-0005\r\n
  s>     content-type: application/mercurial-exp-framing-0005\r\n
  s>     content-length: 78\r\n
  s>     host: $LOCALIP:$HGPORT\r\n (glob)
  s>     user-agent: Mercurial debugwireproto\r\n
  s>     \r\n
  s>     F\x00\x00\x01\x00\x01\x01\x11\xa2Dargs\xa2Ffields\x81GparentsEnodes\x81T\xea\xe5\xf8,.b#h\xd2}\xae\xcbv\xb7\xe3\x93\xd0\xf2B\x11DnameMchangesetdata
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
  s>     \xa1Jtotalitems\x01\xa2DnodeT\xea\xe5\xf8,.b#h\xd2}\xae\xcbv\xb7\xe3\x93\xd0\xf2B\x11Gparents\x82T3\x90\xef\x85\x00s\xfb\xc2\xf0\xdf\xff"D4,\x8e\x92)\x01:T\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00
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
      b'node': b'\xea\xe5\xf8,.b#h\xd2}\xae\xcbv\xb7\xe3\x93\xd0\xf2B\x11',
      b'parents': [
        b'3\x90\xef\x85\x00s\xfb\xc2\xf0\xdf\xff"D4,\x8e\x92)\x01:',
        b'\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00'
      ]
    }
  ]

Phase data is transferred upon request

  $ sendhttpv2peer << EOF
  > command changesetdata
  >     fields eval:[b'phase']
  >     nodes eval:[b'\x0b\xb8\xad\x89\x4a\x15\xb1\x53\x80\xb2\xa2\xa5\xb1\x83\xe2\x0f\x2a\x4b\x28\xdd']
  > EOF
  creating http peer for wire protocol version 2
  sending changesetdata command
  s>     POST /api/exp-http-v2-0002/ro/changesetdata HTTP/1.1\r\n
  s>     Accept-Encoding: identity\r\n
  s>     accept: application/mercurial-exp-framing-0005\r\n
  s>     content-type: application/mercurial-exp-framing-0005\r\n
  s>     content-length: 76\r\n
  s>     host: $LOCALIP:$HGPORT\r\n (glob)
  s>     user-agent: Mercurial debugwireproto\r\n
  s>     \r\n
  s>     D\x00\x00\x01\x00\x01\x01\x11\xa2Dargs\xa2Ffields\x81EphaseEnodes\x81T\x0b\xb8\xad\x89J\x15\xb1S\x80\xb2\xa2\xa5\xb1\x83\xe2\x0f*K(\xddDnameMchangesetdata
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
  s>     3d\r\n
  s>     5\x00\x00\x01\x00\x02\x001
  s>     \xa1Jtotalitems\x01\xa2DnodeT\x0b\xb8\xad\x89J\x15\xb1S\x80\xb2\xa2\xa5\xb1\x83\xe2\x0f*K(\xddEphaseFpublic
  s>     \r\n
  received frame(size=53; request=1; stream=2; streamflags=; type=command-response; flags=continuation)
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
      b'node': b'\x0b\xb8\xad\x89J\x15\xb1S\x80\xb2\xa2\xa5\xb1\x83\xe2\x0f*K(\xdd',
      b'phase': b'public'
    }
  ]

Revision data is transferred upon request

  $ sendhttpv2peer << EOF
  > command changesetdata
  >     fields eval:[b'revision']
  >     nodes eval:[b'\xea\xe5\xf8\x2c\x2e\x62\x23\x68\xd2\x7d\xae\xcb\x76\xb7\xe3\x93\xd0\xf2\x42\x11']
  > EOF
  creating http peer for wire protocol version 2
  sending changesetdata command
  s>     POST /api/exp-http-v2-0002/ro/changesetdata HTTP/1.1\r\n
  s>     Accept-Encoding: identity\r\n
  s>     accept: application/mercurial-exp-framing-0005\r\n
  s>     content-type: application/mercurial-exp-framing-0005\r\n
  s>     content-length: 79\r\n
  s>     host: $LOCALIP:$HGPORT\r\n (glob)
  s>     user-agent: Mercurial debugwireproto\r\n
  s>     \r\n
  s>     G\x00\x00\x01\x00\x01\x01\x11\xa2Dargs\xa2Ffields\x81HrevisionEnodes\x81T\xea\xe5\xf8,.b#h\xd2}\xae\xcbv\xb7\xe3\x93\xd0\xf2B\x11DnameMchangesetdata
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
  s>     8c\r\n
  s>     \x84\x00\x00\x01\x00\x02\x001
  s>     \xa1Jtotalitems\x01\xa2Ofieldsfollowing\x81\x82Hrevision\x18=DnodeT\xea\xe5\xf8,.b#h\xd2}\xae\xcbv\xb7\xe3\x93\xd0\xf2B\x11X=1b74476799ec8318045db759b1b4bcc9b839d0aa\n
  s>     test\n
  s>     0 0\n
  s>     a\n
  s>     \n
  s>     commit 3
  s>     \r\n
  received frame(size=132; request=1; stream=2; streamflags=; type=command-response; flags=continuation)
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
          61
        ]
      ],
      b'node': b'\xea\xe5\xf8,.b#h\xd2}\xae\xcbv\xb7\xe3\x93\xd0\xf2B\x11'
    },
    b'1b74476799ec8318045db759b1b4bcc9b839d0aa\ntest\n0 0\na\n\ncommit 3'
  ]

Bookmarks key isn't present if no bookmarks data

  $ sendhttpv2peer << EOF
  > command changesetdata
  >     fields eval:[b'bookmarks']
  >     noderange eval:[[], [b'\x0b\xb8\xad\x89\x4a\x15\xb1\x53\x80\xb2\xa2\xa5\xb1\x83\xe2\x0f\x2a\x4b\x28\xdd', b'\xea\xe5\xf8\x2c\x2e\x62\x23\x68\xd2\x7d\xae\xcb\x76\xb7\xe3\x93\xd0\xf2\x42\x11']]
  > EOF
  creating http peer for wire protocol version 2
  sending changesetdata command
  s>     POST /api/exp-http-v2-0002/ro/changesetdata HTTP/1.1\r\n
  s>     Accept-Encoding: identity\r\n
  s>     accept: application/mercurial-exp-framing-0005\r\n
  s>     content-type: application/mercurial-exp-framing-0005\r\n
  s>     content-length: 107\r\n
  s>     host: $LOCALIP:$HGPORT\r\n (glob)
  s>     user-agent: Mercurial debugwireproto\r\n
  s>     \r\n
  s>     c\x00\x00\x01\x00\x01\x01\x11\xa2Dargs\xa2Ffields\x81IbookmarksInoderange\x82\x80\x82T\x0b\xb8\xad\x89J\x15\xb1S\x80\xb2\xa2\xa5\xb1\x83\xe2\x0f*K(\xddT\xea\xe5\xf8,.b#h\xd2}\xae\xcbv\xb7\xe3\x93\xd0\xf2B\x11DnameMchangesetdata
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
  s>     81\r\n
  s>     y\x00\x00\x01\x00\x02\x001
  s>     \xa1Jtotalitems\x04\xa1DnodeT3\x90\xef\x85\x00s\xfb\xc2\xf0\xdf\xff"D4,\x8e\x92)\x01:\xa1DnodeTu\x92\x91~\x1c>\x82g|\xb0\xa4\xbcq\\\xa2]\xd1-(\xc1\xa1DnodeT\x0b\xb8\xad\x89J\x15\xb1S\x80\xb2\xa2\xa5\xb1\x83\xe2\x0f*K(\xdd\xa1DnodeT\xea\xe5\xf8,.b#h\xd2}\xae\xcbv\xb7\xe3\x93\xd0\xf2B\x11
  s>     \r\n
  received frame(size=121; request=1; stream=2; streamflags=; type=command-response; flags=continuation)
  s>     8\r\n
  s>     \x00\x00\x00\x01\x00\x02\x002
  s>     \r\n
  s>     0\r\n
  s>     \r\n
  received frame(size=0; request=1; stream=2; streamflags=; type=command-response; flags=eos)
  response: gen[
    {
      b'totalitems': 4
    },
    {
      b'node': b'3\x90\xef\x85\x00s\xfb\xc2\xf0\xdf\xff"D4,\x8e\x92)\x01:'
    },
    {
      b'node': b'u\x92\x91~\x1c>\x82g|\xb0\xa4\xbcq\\\xa2]\xd1-(\xc1'
    },
    {
      b'node': b'\x0b\xb8\xad\x89J\x15\xb1S\x80\xb2\xa2\xa5\xb1\x83\xe2\x0f*K(\xdd'
    },
    {
      b'node': b'\xea\xe5\xf8,.b#h\xd2}\xae\xcbv\xb7\xe3\x93\xd0\xf2B\x11'
    }
  ]

Bookmarks are sent when requested

  $ hg -R ../server bookmark -r 0bb8ad894a15b15380b2a2a5b183e20f2a4b28dd book-1
  $ hg -R ../server bookmark -r eae5f82c2e622368d27daecb76b7e393d0f24211 book-2
  $ hg -R ../server bookmark -r eae5f82c2e622368d27daecb76b7e393d0f24211 book-3

  $ sendhttpv2peer << EOF
  > command changesetdata
  >     fields eval:[b'bookmarks']
  >     noderange eval:[[], [b'\x0b\xb8\xad\x89\x4a\x15\xb1\x53\x80\xb2\xa2\xa5\xb1\x83\xe2\x0f\x2a\x4b\x28\xdd', b'\xea\xe5\xf8\x2c\x2e\x62\x23\x68\xd2\x7d\xae\xcb\x76\xb7\xe3\x93\xd0\xf2\x42\x11']]
  > EOF
  creating http peer for wire protocol version 2
  sending changesetdata command
  s>     POST /api/exp-http-v2-0002/ro/changesetdata HTTP/1.1\r\n
  s>     Accept-Encoding: identity\r\n
  s>     accept: application/mercurial-exp-framing-0005\r\n
  s>     content-type: application/mercurial-exp-framing-0005\r\n
  s>     content-length: 107\r\n
  s>     host: $LOCALIP:$HGPORT\r\n (glob)
  s>     user-agent: Mercurial debugwireproto\r\n
  s>     \r\n
  s>     c\x00\x00\x01\x00\x01\x01\x11\xa2Dargs\xa2Ffields\x81IbookmarksInoderange\x82\x80\x82T\x0b\xb8\xad\x89J\x15\xb1S\x80\xb2\xa2\xa5\xb1\x83\xe2\x0f*K(\xddT\xea\xe5\xf8,.b#h\xd2}\xae\xcbv\xb7\xe3\x93\xd0\xf2B\x11DnameMchangesetdata
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
  s>     ac\r\n
  s>     \xa4\x00\x00\x01\x00\x02\x001
  s>     \xa1Jtotalitems\x04\xa1DnodeT3\x90\xef\x85\x00s\xfb\xc2\xf0\xdf\xff"D4,\x8e\x92)\x01:\xa1DnodeTu\x92\x91~\x1c>\x82g|\xb0\xa4\xbcq\\\xa2]\xd1-(\xc1\xa2Ibookmarks\x81Fbook-1DnodeT\x0b\xb8\xad\x89J\x15\xb1S\x80\xb2\xa2\xa5\xb1\x83\xe2\x0f*K(\xdd\xa2Ibookmarks\x82Fbook-2Fbook-3DnodeT\xea\xe5\xf8,.b#h\xd2}\xae\xcbv\xb7\xe3\x93\xd0\xf2B\x11
  s>     \r\n
  received frame(size=164; request=1; stream=2; streamflags=; type=command-response; flags=continuation)
  s>     8\r\n
  s>     \x00\x00\x00\x01\x00\x02\x002
  s>     \r\n
  s>     0\r\n
  s>     \r\n
  received frame(size=0; request=1; stream=2; streamflags=; type=command-response; flags=eos)
  response: gen[
    {
      b'totalitems': 4
    },
    {
      b'node': b'3\x90\xef\x85\x00s\xfb\xc2\xf0\xdf\xff"D4,\x8e\x92)\x01:'
    },
    {
      b'node': b'u\x92\x91~\x1c>\x82g|\xb0\xa4\xbcq\\\xa2]\xd1-(\xc1'
    },
    {
      b'bookmarks': [
        b'book-1'
      ],
      b'node': b'\x0b\xb8\xad\x89J\x15\xb1S\x80\xb2\xa2\xa5\xb1\x83\xe2\x0f*K(\xdd'
    },
    {
      b'bookmarks': [
        b'book-2',
        b'book-3'
      ],
      b'node': b'\xea\xe5\xf8,.b#h\xd2}\xae\xcbv\xb7\xe3\x93\xd0\xf2B\x11'
    }
  ]

Bookmarks are sent when we make a no-new-revisions request

  $ sendhttpv2peer << EOF
  > command changesetdata
  >     fields eval:[b'bookmarks', b'revision']
  >     noderange eval:[[b'\xea\xe5\xf8\x2c\x2e\x62\x23\x68\xd2\x7d\xae\xcb\x76\xb7\xe3\x93\xd0\xf2\x42\x11'], [b'\x0b\xb8\xad\x89\x4a\x15\xb1\x53\x80\xb2\xa2\xa5\xb1\x83\xe2\x0f\x2a\x4b\x28\xdd', b'\xea\xe5\xf8\x2c\x2e\x62\x23\x68\xd2\x7d\xae\xcb\x76\xb7\xe3\x93\xd0\xf2\x42\x11']]
  > EOF
  creating http peer for wire protocol version 2
  sending changesetdata command
  s>     POST /api/exp-http-v2-0002/ro/changesetdata HTTP/1.1\r\n
  s>     Accept-Encoding: identity\r\n
  s>     accept: application/mercurial-exp-framing-0005\r\n
  s>     content-type: application/mercurial-exp-framing-0005\r\n
  s>     content-length: 137\r\n
  s>     host: $LOCALIP:$HGPORT\r\n (glob)
  s>     user-agent: Mercurial debugwireproto\r\n
  s>     \r\n
  s>     \x81\x00\x00\x01\x00\x01\x01\x11\xa2Dargs\xa2Ffields\x82IbookmarksHrevisionInoderange\x82\x81T\xea\xe5\xf8,.b#h\xd2}\xae\xcbv\xb7\xe3\x93\xd0\xf2B\x11\x82T\x0b\xb8\xad\x89J\x15\xb1S\x80\xb2\xa2\xa5\xb1\x83\xe2\x0f*K(\xddT\xea\xe5\xf8,.b#h\xd2}\xae\xcbv\xb7\xe3\x93\xd0\xf2B\x11DnameMchangesetdata
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
  s>     14b\r\n
  s>     C\x01\x00\x01\x00\x02\x001
  s>     \xa1Jtotalitems\x02\xa2Ofieldsfollowing\x81\x82Hrevision\x18?DnodeTu\x92\x91~\x1c>\x82g|\xb0\xa4\xbcq\\\xa2]\xd1-(\xc1X?7f144aea0ba742713887b564d57e9d12f12ff382\n
  s>     test\n
  s>     0 0\n
  s>     a\n
  s>     b\n
  s>     \n
  s>     commit 1\xa3Ibookmarks\x81Fbook-1Ofieldsfollowing\x81\x82Hrevision\x18=DnodeT\x0b\xb8\xad\x89J\x15\xb1S\x80\xb2\xa2\xa5\xb1\x83\xe2\x0f*K(\xddX=37f0a2d1c28ffe4b879109a7d1bbf8f07b3c763b\n
  s>     test\n
  s>     0 0\n
  s>     b\n
  s>     \n
  s>     commit 2\xa2Ibookmarks\x82Fbook-2Fbook-3DnodeT\xea\xe5\xf8,.b#h\xd2}\xae\xcbv\xb7\xe3\x93\xd0\xf2B\x11
  s>     \r\n
  received frame(size=323; request=1; stream=2; streamflags=; type=command-response; flags=continuation)
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
          63
        ]
      ],
      b'node': b'u\x92\x91~\x1c>\x82g|\xb0\xa4\xbcq\\\xa2]\xd1-(\xc1'
    },
    b'7f144aea0ba742713887b564d57e9d12f12ff382\ntest\n0 0\na\nb\n\ncommit 1',
    {
      b'bookmarks': [
        b'book-1'
      ],
      b'fieldsfollowing': [
        [
          b'revision',
          61
        ]
      ],
      b'node': b'\x0b\xb8\xad\x89J\x15\xb1S\x80\xb2\xa2\xa5\xb1\x83\xe2\x0f*K(\xdd'
    },
    b'37f0a2d1c28ffe4b879109a7d1bbf8f07b3c763b\ntest\n0 0\nb\n\ncommit 2',
    {
      b'bookmarks': [
        b'book-2',
        b'book-3'
      ],
      b'node': b'\xea\xe5\xf8,.b#h\xd2}\xae\xcbv\xb7\xe3\x93\xd0\xf2B\x11'
    }
  ]

Multiple fields can be transferred

  $ sendhttpv2peer << EOF
  > command changesetdata
  >     fields eval:[b'parents', b'revision']
  >     nodes eval:[b'\xea\xe5\xf8\x2c\x2e\x62\x23\x68\xd2\x7d\xae\xcb\x76\xb7\xe3\x93\xd0\xf2\x42\x11']
  > EOF
  creating http peer for wire protocol version 2
  sending changesetdata command
  s>     POST /api/exp-http-v2-0002/ro/changesetdata HTTP/1.1\r\n
  s>     Accept-Encoding: identity\r\n
  s>     accept: application/mercurial-exp-framing-0005\r\n
  s>     content-type: application/mercurial-exp-framing-0005\r\n
  s>     content-length: 87\r\n
  s>     host: $LOCALIP:$HGPORT\r\n (glob)
  s>     user-agent: Mercurial debugwireproto\r\n
  s>     \r\n
  s>     O\x00\x00\x01\x00\x01\x01\x11\xa2Dargs\xa2Ffields\x82GparentsHrevisionEnodes\x81T\xea\xe5\xf8,.b#h\xd2}\xae\xcbv\xb7\xe3\x93\xd0\xf2B\x11DnameMchangesetdata
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
  s>     bf\r\n
  s>     \xb7\x00\x00\x01\x00\x02\x001
  s>     \xa1Jtotalitems\x01\xa3Ofieldsfollowing\x81\x82Hrevision\x18=DnodeT\xea\xe5\xf8,.b#h\xd2}\xae\xcbv\xb7\xe3\x93\xd0\xf2B\x11Gparents\x82T3\x90\xef\x85\x00s\xfb\xc2\xf0\xdf\xff"D4,\x8e\x92)\x01:T\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00X=1b74476799ec8318045db759b1b4bcc9b839d0aa\n
  s>     test\n
  s>     0 0\n
  s>     a\n
  s>     \n
  s>     commit 3
  s>     \r\n
  received frame(size=183; request=1; stream=2; streamflags=; type=command-response; flags=continuation)
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
          61
        ]
      ],
      b'node': b'\xea\xe5\xf8,.b#h\xd2}\xae\xcbv\xb7\xe3\x93\xd0\xf2B\x11',
      b'parents': [
        b'3\x90\xef\x85\x00s\xfb\xc2\xf0\xdf\xff"D4,\x8e\x92)\x01:',
        b'\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00'
      ]
    },
    b'1b74476799ec8318045db759b1b4bcc9b839d0aa\ntest\n0 0\na\n\ncommit 3'
  ]

Base nodes have just their metadata (e.g. phase) transferred

  $ sendhttpv2peer << EOF
  > command changesetdata
  >     fields eval:[b'phase', b'parents', b'revision']
  >     noderange eval:[[b'\x33\x90\xef\x85\x00\x73\xfb\xc2\xf0\xdf\xff\x22\x44\x34\x2c\x8e\x92\x29\x01\x3a'], [b'\x0b\xb8\xad\x89\x4a\x15\xb1\x53\x80\xb2\xa2\xa5\xb1\x83\xe2\x0f\x2a\x4b\x28\xdd', b'\xea\xe5\xf8\x2c\x2e\x62\x23\x68\xd2\x7d\xae\xcb\x76\xb7\xe3\x93\xd0\xf2\x42\x11']]
  > EOF
  creating http peer for wire protocol version 2
  sending changesetdata command
  s>     POST /api/exp-http-v2-0002/ro/changesetdata HTTP/1.1\r\n
  s>     Accept-Encoding: identity\r\n
  s>     accept: application/mercurial-exp-framing-0005\r\n
  s>     content-type: application/mercurial-exp-framing-0005\r\n
  s>     content-length: 141\r\n
  s>     host: $LOCALIP:$HGPORT\r\n (glob)
  s>     user-agent: Mercurial debugwireproto\r\n
  s>     \r\n
  s>     \x85\x00\x00\x01\x00\x01\x01\x11\xa2Dargs\xa2Ffields\x83EphaseGparentsHrevisionInoderange\x82\x81T3\x90\xef\x85\x00s\xfb\xc2\xf0\xdf\xff"D4,\x8e\x92)\x01:\x82T\x0b\xb8\xad\x89J\x15\xb1S\x80\xb2\xa2\xa5\xb1\x83\xe2\x0f*K(\xddT\xea\xe5\xf8,.b#h\xd2}\xae\xcbv\xb7\xe3\x93\xd0\xf2B\x11DnameMchangesetdata
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
  s>     263\r\n
  s>     [\x02\x00\x01\x00\x02\x001
  s>     \xa1Jtotalitems\x03\xa2DnodeT3\x90\xef\x85\x00s\xfb\xc2\xf0\xdf\xff"D4,\x8e\x92)\x01:EphaseFpublic\xa4Ofieldsfollowing\x81\x82Hrevision\x18?DnodeTu\x92\x91~\x1c>\x82g|\xb0\xa4\xbcq\\\xa2]\xd1-(\xc1Gparents\x82T3\x90\xef\x85\x00s\xfb\xc2\xf0\xdf\xff"D4,\x8e\x92)\x01:T\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00EphaseFpublicX?7f144aea0ba742713887b564d57e9d12f12ff382\n
  s>     test\n
  s>     0 0\n
  s>     a\n
  s>     b\n
  s>     \n
  s>     commit 1\xa4Ofieldsfollowing\x81\x82Hrevision\x18=DnodeT\x0b\xb8\xad\x89J\x15\xb1S\x80\xb2\xa2\xa5\xb1\x83\xe2\x0f*K(\xddGparents\x82Tu\x92\x91~\x1c>\x82g|\xb0\xa4\xbcq\\\xa2]\xd1-(\xc1T\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00EphaseFpublicX=37f0a2d1c28ffe4b879109a7d1bbf8f07b3c763b\n
  s>     test\n
  s>     0 0\n
  s>     b\n
  s>     \n
  s>     commit 2\xa4Ofieldsfollowing\x81\x82Hrevision\x18=DnodeT\xea\xe5\xf8,.b#h\xd2}\xae\xcbv\xb7\xe3\x93\xd0\xf2B\x11Gparents\x82T3\x90\xef\x85\x00s\xfb\xc2\xf0\xdf\xff"D4,\x8e\x92)\x01:T\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00EphaseEdraftX=1b74476799ec8318045db759b1b4bcc9b839d0aa\n
  s>     test\n
  s>     0 0\n
  s>     a\n
  s>     \n
  s>     commit 3
  s>     \r\n
  received frame(size=603; request=1; stream=2; streamflags=; type=command-response; flags=continuation)
  s>     8\r\n
  s>     \x00\x00\x00\x01\x00\x02\x002
  s>     \r\n
  s>     0\r\n
  s>     \r\n
  received frame(size=0; request=1; stream=2; streamflags=; type=command-response; flags=eos)
  response: gen[
    {
      b'totalitems': 3
    },
    {
      b'node': b'3\x90\xef\x85\x00s\xfb\xc2\xf0\xdf\xff"D4,\x8e\x92)\x01:',
      b'phase': b'public'
    },
    {
      b'fieldsfollowing': [
        [
          b'revision',
          63
        ]
      ],
      b'node': b'u\x92\x91~\x1c>\x82g|\xb0\xa4\xbcq\\\xa2]\xd1-(\xc1',
      b'parents': [
        b'3\x90\xef\x85\x00s\xfb\xc2\xf0\xdf\xff"D4,\x8e\x92)\x01:',
        b'\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00'
      ],
      b'phase': b'public'
    },
    b'7f144aea0ba742713887b564d57e9d12f12ff382\ntest\n0 0\na\nb\n\ncommit 1',
    {
      b'fieldsfollowing': [
        [
          b'revision',
          61
        ]
      ],
      b'node': b'\x0b\xb8\xad\x89J\x15\xb1S\x80\xb2\xa2\xa5\xb1\x83\xe2\x0f*K(\xdd',
      b'parents': [
        b'u\x92\x91~\x1c>\x82g|\xb0\xa4\xbcq\\\xa2]\xd1-(\xc1',
        b'\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00'
      ],
      b'phase': b'public'
    },
    b'37f0a2d1c28ffe4b879109a7d1bbf8f07b3c763b\ntest\n0 0\nb\n\ncommit 2',
    {
      b'fieldsfollowing': [
        [
          b'revision',
          61
        ]
      ],
      b'node': b'\xea\xe5\xf8,.b#h\xd2}\xae\xcbv\xb7\xe3\x93\xd0\xf2B\x11',
      b'parents': [
        b'3\x90\xef\x85\x00s\xfb\xc2\xf0\xdf\xff"D4,\x8e\x92)\x01:',
        b'\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00'
      ],
      b'phase': b'draft'
    },
    b'1b74476799ec8318045db759b1b4bcc9b839d0aa\ntest\n0 0\na\n\ncommit 3'
  ]

  $ cat error.log
