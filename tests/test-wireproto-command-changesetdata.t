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
  abort: missing required arguments: revisions!
  [255]

Missing nodes for changesetexplicit results in error

  $ sendhttpv2peer << EOF
  > command changesetdata
  >     revisions eval:[{b'type': b'changesetexplicit'}]
  > EOF
  creating http peer for wire protocol version 2
  sending changesetdata command
  abort: nodes key not present in changesetexplicit revision specifier!
  [255]

changesetexplicitdepth requires nodes and depth keys

  $ sendhttpv2peer << EOF
  > command changesetdata
  >     revisions eval:[{b'type': b'changesetexplicitdepth'}]
  > EOF
  creating http peer for wire protocol version 2
  sending changesetdata command
  abort: nodes key not present in changesetexplicitdepth revision specifier!
  [255]

  $ sendhttpv2peer << EOF
  > command changesetdata
  >     revisions eval:[{b'type': b'changesetexplicitdepth', b'nodes': []}]
  > EOF
  creating http peer for wire protocol version 2
  sending changesetdata command
  abort: depth key not present in changesetexplicitdepth revision specifier!
  [255]

  $ sendhttpv2peer << EOF
  > command changesetdata
  >     revisions eval:[{b'type': b'changesetexplicitdepth', b'depth': 42}]
  > EOF
  creating http peer for wire protocol version 2
  sending changesetdata command
  abort: nodes key not present in changesetexplicitdepth revision specifier!
  [255]

changesetdagrange requires roots and heads keys

  $ sendhttpv2peer << EOF
  > command changesetdata
  >     revisions eval:[{b'type': b'changesetdagrange'}]
  > EOF
  creating http peer for wire protocol version 2
  sending changesetdata command
  abort: roots key not present in changesetdagrange revision specifier!
  [255]

  $ sendhttpv2peer << EOF
  > command changesetdata
  >     revisions eval:[{b'type': b'changesetdagrange', b'roots': []}]
  > EOF
  creating http peer for wire protocol version 2
  sending changesetdata command
  abort: heads key not present in changesetdagrange revision specifier!
  [255]

  $ sendhttpv2peer << EOF
  > command changesetdata
  >     revisions eval:[{b'type': b'changesetdagrange', b'heads': [b'dummy']}]
  > EOF
  creating http peer for wire protocol version 2
  sending changesetdata command
  abort: roots key not present in changesetdagrange revision specifier!
  [255]

Empty changesetdagrange heads results in an error

  $ sendhttpv2peer << EOF
  > command changesetdata
  >     revisions eval:[{b'type': b'changesetdagrange', b'heads': [], b'roots': []}]
  > EOF
  creating http peer for wire protocol version 2
  sending changesetdata command
  abort: heads key in changesetdagrange cannot be empty!
  [255]

Sending just dagrange heads sends all revisions

  $ sendhttpv2peer << EOF
  > command changesetdata
  >     revisions eval:[{
  >         b'type': b'changesetdagrange',
  >         b'roots': [],
  >         b'heads': [
  >             b'\x0b\xb8\xad\x89\x4a\x15\xb1\x53\x80\xb2\xa2\xa5\xb1\x83\xe2\x0f\x2a\x4b\x28\xdd',
  >             b'\xea\xe5\xf8\x2c\x2e\x62\x23\x68\xd2\x7d\xae\xcb\x76\xb7\xe3\x93\xd0\xf2\x42\x11',
  >         ]}]
  > EOF
  creating http peer for wire protocol version 2
  sending changesetdata command
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
  >     revisions eval:[{
  >         b'type': b'changesetdagrange',
  >         b'roots': [b'\x33\x90\xef\x85\x00\x73\xfb\xc2\xf0\xdf\xff\x22\x44\x34\x2c\x8e\x92\x29\x01\x3a'],
  >         b'heads': [
  >             b'\x0b\xb8\xad\x89\x4a\x15\xb1\x53\x80\xb2\xa2\xa5\xb1\x83\xe2\x0f\x2a\x4b\x28\xdd',
  >         ]}]
  > EOF
  creating http peer for wire protocol version 2
  sending changesetdata command
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
  >     revisions eval:[{
  >         b'type': b'changesetexplicit',
  >         b'nodes': [b'\x33\x90\xef\x85\x00\x73\xfb\xc2\xf0\xdf\xff\x22\x44\x34\x2c\x8e\x92\x29\x01\x3a']}]
  > EOF
  creating http peer for wire protocol version 2
  sending changesetdata command
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
  >     revisions eval:[
  >         {
  >             b'type': b'changesetexplicit',
  >             b'nodes': [b'\xea\xe5\xf8\x2c\x2e\x62\x23\x68\xd2\x7d\xae\xcb\x76\xb7\xe3\x93\xd0\xf2\x42\x11'],
  >         },
  >         {
  >             b'type': b'changesetdagrange',
  >             b'roots': [b'\x75\x92\x91\x7e\x1c\x3e\x82\x67\x7c\xb0\xa4\xbc\x71\x5c\xa2\x5d\xd1\x2d\x28\xc1'],
  >             b'heads': [b'\x0b\xb8\xad\x89\x4a\x15\xb1\x53\x80\xb2\xa2\xa5\xb1\x83\xe2\x0f\x2a\x4b\x28\xdd'],
  >         }]
  > EOF
  creating http peer for wire protocol version 2
  sending changesetdata command
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
  >     revisions eval:[{
  >         b'type': b'changesetexplicitdepth',
  >         b'nodes': [b'\xea\xe5\xf8\x2c\x2e\x62\x23\x68\xd2\x7d\xae\xcb\x76\xb7\xe3\x93\xd0\xf2\x42\x11'],
  >         b'depth': 1}] 
  > EOF
  creating http peer for wire protocol version 2
  sending changesetdata command
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
  >     revisions eval:[{
  >         b'type': b'changesetexplicitdepth',
  >         b'nodes': [b'\xea\xe5\xf8\x2c\x2e\x62\x23\x68\xd2\x7d\xae\xcb\x76\xb7\xe3\x93\xd0\xf2\x42\x11'],
  >         b'depth': 2}]
  > EOF
  creating http peer for wire protocol version 2
  sending changesetdata command
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
  >     revisions eval:[{
  >         b'type': b'changesetexplicitdepth',
  >         b'nodes': [b'\xea\xe5\xf8\x2c\x2e\x62\x23\x68\xd2\x7d\xae\xcb\x76\xb7\xe3\x93\xd0\xf2\x42\x11', b'\x0b\xb8\xad\x89\x4a\x15\xb1\x53\x80\xb2\xa2\xa5\xb1\x83\xe2\x0f\x2a\x4b\x28\xdd'],
  >         b'depth': 2}]
  > EOF
  creating http peer for wire protocol version 2
  sending changesetdata command
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
  >     revisions eval:[{
  >         b'type': b'changesetexplicit',
  >         b'nodes': [
  >             b'\xea\xe5\xf8\x2c\x2e\x62\x23\x68\xd2\x7d\xae\xcb\x76\xb7\xe3\x93\xd0\xf2\x42\x11',
  >         ]}]
  > EOF
  creating http peer for wire protocol version 2
  sending changesetdata command
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
  >     revisions eval:[{
  >         b'type': b'changesetexplicit',
  >         b'nodes': [
  >             b'\x0b\xb8\xad\x89\x4a\x15\xb1\x53\x80\xb2\xa2\xa5\xb1\x83\xe2\x0f\x2a\x4b\x28\xdd',
  >         ]}]
  > EOF
  creating http peer for wire protocol version 2
  sending changesetdata command
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
  >     revisions eval:[{
  >         b'type': b'changesetexplicit',
  >         b'nodes': [
  >             b'\xea\xe5\xf8\x2c\x2e\x62\x23\x68\xd2\x7d\xae\xcb\x76\xb7\xe3\x93\xd0\xf2\x42\x11',
  >         ]}]
  > EOF
  creating http peer for wire protocol version 2
  sending changesetdata command
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
  >     revisions eval:[{
  >         b'type': b'changesetdagrange',
  >         b'roots': [],
  >         b'heads': [
  >             b'\x0b\xb8\xad\x89\x4a\x15\xb1\x53\x80\xb2\xa2\xa5\xb1\x83\xe2\x0f\x2a\x4b\x28\xdd',
  >             b'\xea\xe5\xf8\x2c\x2e\x62\x23\x68\xd2\x7d\xae\xcb\x76\xb7\xe3\x93\xd0\xf2\x42\x11',
  >         ]}]
  > EOF
  creating http peer for wire protocol version 2
  sending changesetdata command
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
  >     revisions eval:[{
  >         b'type': b'changesetdagrange',
  >         b'roots': [],
  >         b'heads': [
  >             b'\x0b\xb8\xad\x89\x4a\x15\xb1\x53\x80\xb2\xa2\xa5\xb1\x83\xe2\x0f\x2a\x4b\x28\xdd',
  >             b'\xea\xe5\xf8\x2c\x2e\x62\x23\x68\xd2\x7d\xae\xcb\x76\xb7\xe3\x93\xd0\xf2\x42\x11',
  >         ]}]
  > EOF
  creating http peer for wire protocol version 2
  sending changesetdata command
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
  >     revisions eval:[{
  >         b'type': b'changesetdagrange',
  >         b'roots': [b'\xea\xe5\xf8\x2c\x2e\x62\x23\x68\xd2\x7d\xae\xcb\x76\xb7\xe3\x93\xd0\xf2\x42\x11'],
  >         b'heads': [
  >             b'\x0b\xb8\xad\x89\x4a\x15\xb1\x53\x80\xb2\xa2\xa5\xb1\x83\xe2\x0f\x2a\x4b\x28\xdd',
  >             b'\xea\xe5\xf8\x2c\x2e\x62\x23\x68\xd2\x7d\xae\xcb\x76\xb7\xe3\x93\xd0\xf2\x42\x11',
  >         ]}]
  > EOF
  creating http peer for wire protocol version 2
  sending changesetdata command
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
  >     revisions eval:[{
  >         b'type': b'changesetexplicit',
  >         b'nodes': [
  >             b'\xea\xe5\xf8\x2c\x2e\x62\x23\x68\xd2\x7d\xae\xcb\x76\xb7\xe3\x93\xd0\xf2\x42\x11',
  >         ]}]
  > EOF
  creating http peer for wire protocol version 2
  sending changesetdata command
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
TODO this doesn't work

  $ sendhttpv2peer << EOF
  > command changesetdata
  >     fields eval:[b'phase', b'parents', b'revision']
  >     revisions eval:[{
  >         b'type': b'changesetdagrange',
  >         b'roots': [b'\x33\x90\xef\x85\x00\x73\xfb\xc2\xf0\xdf\xff\x22\x44\x34\x2c\x8e\x92\x29\x01\x3a'],
  >         b'heads': [
  >             b'\x0b\xb8\xad\x89\x4a\x15\xb1\x53\x80\xb2\xa2\xa5\xb1\x83\xe2\x0f\x2a\x4b\x28\xdd',
  >             b'\xea\xe5\xf8\x2c\x2e\x62\x23\x68\xd2\x7d\xae\xcb\x76\xb7\xe3\x93\xd0\xf2\x42\x11',
  >         ]}]
  > EOF
  creating http peer for wire protocol version 2
  sending changesetdata command
  response: gen[
    {
      b'totalitems': 3
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
