  $ . $TESTDIR/wireprotohelpers.sh

  $ hg init server
  $ enablehttpv2 server
  $ cd server
  $ cat > a << EOF
  > a0
  > 00000000000000000000000000000000000000
  > 11111111111111111111111111111111111111
  > EOF
  $ echo b0 > b
  $ mkdir -p dir0/child0 dir0/child1 dir1
  $ echo c0 > dir0/c
  $ echo d0 > dir0/d
  $ echo e0 > dir0/child0/e
  $ echo f0 > dir0/child1/f
  $ hg -q commit -A -m 'commit 0'

  $ echo a1 >> a
  $ echo d1 > dir0/d
  $ hg commit -m 'commit 1'
  $ echo f0 > dir0/child1/f
  $ hg commit -m 'commit 2'
  nothing changed
  [1]

  $ hg -q up -r 0
  $ echo a2 >> a
  $ hg commit -m 'commit 3'
  created new head

  $ hg log -G -T '{rev}:{node} {desc}\n'
  @  2:5ce944d7fece1252dae06c34422b573c191b9489 commit 3
  |
  | o  1:3ef5e551f219ba505481d34d6b0316b017fa3f00 commit 1
  |/
  o  0:91b232a2253ce0638496f67bdfd7a4933fb51b25 commit 0
  

  $ hg --debug debugindex a
     rev linkrev nodeid                                   p1                                       p2
       0       0 649d149df43d83882523b7fb1e6a3af6f1907b39 0000000000000000000000000000000000000000 0000000000000000000000000000000000000000
       1       1 0a86321f1379d1a9ecd0579a22977af7a5acaf11 649d149df43d83882523b7fb1e6a3af6f1907b39 0000000000000000000000000000000000000000
       2       2 7e5801b6d5f03a5a54f3c47b583f7567aad43e5b 649d149df43d83882523b7fb1e6a3af6f1907b39 0000000000000000000000000000000000000000

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
  abort: missing required arguments: nodes, path!
  [255]

  $ sendhttpv2peer << EOF
  > command filedata
  >     nodes eval:[]
  > EOF
  creating http peer for wire protocol version 2
  sending filedata command
  abort: missing required arguments: path!
  [255]

Unknown node is an error

  $ sendhttpv2peer << EOF
  > command filedata
  >     nodes eval:[b'\xaa\xaa\xaa\xaa\xaa\xaa\xaa\xaa\xaa\xaa\xaa\xaa\xaa\xaa\xaa\xaa\xaa\xaa\xaa\xaa']
  >     path eval:b'a'
  > EOF
  creating http peer for wire protocol version 2
  sending filedata command
  abort: unknown file node: aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa!
  [255]

Fetching a single revision returns just metadata by default

  $ sendhttpv2peer << EOF
  > command filedata
  >     nodes eval:[b'\x0a\x86\x32\x1f\x13\x79\xd1\xa9\xec\xd0\x57\x9a\x22\x97\x7a\xf7\xa5\xac\xaf\x11']
  >     path eval:b'a'
  > EOF
  creating http peer for wire protocol version 2
  sending filedata command
  response: gen[
    {
      b'totalitems': 1
    },
    {
      b'node': b'\n\x862\x1f\x13y\xd1\xa9\xec\xd0W\x9a"\x97z\xf7\xa5\xac\xaf\x11'
    }
  ]

Requesting parents works

  $ sendhttpv2peer << EOF
  > command filedata
  >     nodes eval:[b'\x0a\x86\x32\x1f\x13\x79\xd1\xa9\xec\xd0\x57\x9a\x22\x97\x7a\xf7\xa5\xac\xaf\x11']
  >     path eval:b'a'
  >     fields eval:[b'parents']
  > EOF
  creating http peer for wire protocol version 2
  sending filedata command
  response: gen[
    {
      b'totalitems': 1
    },
    {
      b'node': b'\n\x862\x1f\x13y\xd1\xa9\xec\xd0W\x9a"\x97z\xf7\xa5\xac\xaf\x11',
      b'parents': [
        b'd\x9d\x14\x9d\xf4=\x83\x88%#\xb7\xfb\x1ej:\xf6\xf1\x90{9',
        b'\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00'
      ]
    }
  ]

Requesting revision data works
(haveparents defaults to False, so fulltext is emitted)

  $ sendhttpv2peer << EOF
  > command filedata
  >     nodes eval:[b'\x0a\x86\x32\x1f\x13\x79\xd1\xa9\xec\xd0\x57\x9a\x22\x97\x7a\xf7\xa5\xac\xaf\x11']
  >     path eval:b'a'
  >     fields eval:[b'revision']
  > EOF
  creating http peer for wire protocol version 2
  sending filedata command
  response: gen[
    {
      b'totalitems': 1
    },
    {
      b'fieldsfollowing': [
        [
          b'revision',
          84
        ]
      ],
      b'node': b'\n\x862\x1f\x13y\xd1\xa9\xec\xd0W\x9a"\x97z\xf7\xa5\xac\xaf\x11'
    },
    b'a0\n00000000000000000000000000000000000000\n11111111111111111111111111111111111111\na1\n'
  ]

haveparents=False should be same as above

  $ sendhttpv2peer << EOF
  > command filedata
  >     nodes eval:[b'\x0a\x86\x32\x1f\x13\x79\xd1\xa9\xec\xd0\x57\x9a\x22\x97\x7a\xf7\xa5\xac\xaf\x11']
  >     path eval:b'a'
  >     fields eval:[b'revision']
  >     haveparents eval:False
  > EOF
  creating http peer for wire protocol version 2
  sending filedata command
  response: gen[
    {
      b'totalitems': 1
    },
    {
      b'fieldsfollowing': [
        [
          b'revision',
          84
        ]
      ],
      b'node': b'\n\x862\x1f\x13y\xd1\xa9\xec\xd0W\x9a"\x97z\xf7\xa5\xac\xaf\x11'
    },
    b'a0\n00000000000000000000000000000000000000\n11111111111111111111111111111111111111\na1\n'
  ]

haveparents=True should emit a delta

  $ sendhttpv2peer << EOF
  > command filedata
  >     nodes eval:[b'\x0a\x86\x32\x1f\x13\x79\xd1\xa9\xec\xd0\x57\x9a\x22\x97\x7a\xf7\xa5\xac\xaf\x11']
  >     path eval:b'a'
  >     fields eval:[b'revision']
  >     haveparents eval:True
  > EOF
  creating http peer for wire protocol version 2
  sending filedata command
  response: gen[
    {
      b'totalitems': 1
    },
    {
      b'deltabasenode': b'd\x9d\x14\x9d\xf4=\x83\x88%#\xb7\xfb\x1ej:\xf6\xf1\x90{9',
      b'fieldsfollowing': [
        [
          b'delta',
          15
        ]
      ],
      b'node': b'\n\x862\x1f\x13y\xd1\xa9\xec\xd0W\x9a"\x97z\xf7\xa5\xac\xaf\x11'
    },
    b'\x00\x00\x00Q\x00\x00\x00Q\x00\x00\x00\x03a1\n'
  ]

Requesting multiple revisions works
(first revision is a fulltext since haveparents=False by default)

  $ sendhttpv2peer << EOF
  > command filedata
  >     nodes eval:[b'\x64\x9d\x14\x9d\xf4\x3d\x83\x88\x25\x23\xb7\xfb\x1e\x6a\x3a\xf6\xf1\x90\x7b\x39', b'\x0a\x86\x32\x1f\x13\x79\xd1\xa9\xec\xd0\x57\x9a\x22\x97\x7a\xf7\xa5\xac\xaf\x11']
  >     path eval:b'a'
  >     fields eval:[b'revision']
  > EOF
  creating http peer for wire protocol version 2
  sending filedata command
  response: gen[
    {
      b'totalitems': 2
    },
    {
      b'fieldsfollowing': [
        [
          b'revision',
          81
        ]
      ],
      b'node': b'd\x9d\x14\x9d\xf4=\x83\x88%#\xb7\xfb\x1ej:\xf6\xf1\x90{9'
    },
    b'a0\n00000000000000000000000000000000000000\n11111111111111111111111111111111111111\n',
    {
      b'deltabasenode': b'd\x9d\x14\x9d\xf4=\x83\x88%#\xb7\xfb\x1ej:\xf6\xf1\x90{9',
      b'fieldsfollowing': [
        [
          b'delta',
          15
        ]
      ],
      b'node': b'\n\x862\x1f\x13y\xd1\xa9\xec\xd0W\x9a"\x97z\xf7\xa5\xac\xaf\x11'
    },
    b'\x00\x00\x00Q\x00\x00\x00Q\x00\x00\x00\x03a1\n'
  ]

Revisions are sorted by DAG order, parents first

  $ sendhttpv2peer << EOF
  > command filedata
  >     nodes eval:[b'\x0a\x86\x32\x1f\x13\x79\xd1\xa9\xec\xd0\x57\x9a\x22\x97\x7a\xf7\xa5\xac\xaf\x11', b'\x64\x9d\x14\x9d\xf4\x3d\x83\x88\x25\x23\xb7\xfb\x1e\x6a\x3a\xf6\xf1\x90\x7b\x39']
  >     path eval:b'a'
  >     fields eval:[b'revision']
  > EOF
  creating http peer for wire protocol version 2
  sending filedata command
  response: gen[
    {
      b'totalitems': 2
    },
    {
      b'fieldsfollowing': [
        [
          b'revision',
          81
        ]
      ],
      b'node': b'd\x9d\x14\x9d\xf4=\x83\x88%#\xb7\xfb\x1ej:\xf6\xf1\x90{9'
    },
    b'a0\n00000000000000000000000000000000000000\n11111111111111111111111111111111111111\n',
    {
      b'deltabasenode': b'd\x9d\x14\x9d\xf4=\x83\x88%#\xb7\xfb\x1ej:\xf6\xf1\x90{9',
      b'fieldsfollowing': [
        [
          b'delta',
          15
        ]
      ],
      b'node': b'\n\x862\x1f\x13y\xd1\xa9\xec\xd0W\x9a"\x97z\xf7\xa5\xac\xaf\x11'
    },
    b'\x00\x00\x00Q\x00\x00\x00Q\x00\x00\x00\x03a1\n'
  ]

Requesting parents and revision data works

  $ sendhttpv2peer << EOF
  > command filedata
  >     nodes eval:[b'\x7e\x58\x01\xb6\xd5\xf0\x3a\x5a\x54\xf3\xc4\x7b\x58\x3f\x75\x67\xaa\xd4\x3e\x5b']
  >     path eval:b'a'
  >     fields eval:[b'parents', b'revision']
  > EOF
  creating http peer for wire protocol version 2
  sending filedata command
  response: gen[
    {
      b'totalitems': 1
    },
    {
      b'fieldsfollowing': [
        [
          b'revision',
          84
        ]
      ],
      b'node': b'~X\x01\xb6\xd5\xf0:ZT\xf3\xc4{X?ug\xaa\xd4>[',
      b'parents': [
        b'd\x9d\x14\x9d\xf4=\x83\x88%#\xb7\xfb\x1ej:\xf6\xf1\x90{9',
        b'\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00'
      ]
    },
    b'a0\n00000000000000000000000000000000000000\n11111111111111111111111111111111111111\na2\n'
  ]

  $ cat error.log
