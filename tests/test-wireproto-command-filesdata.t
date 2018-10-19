  $ . $TESTDIR/wireprotohelpers.sh

  $ hg init server
  $ enablehttpv2 server
  $ cd server
  $ cat > a << EOF
  > a0
  > 00000000000000000000000000000000000000
  > 11111111111111111111111111111111111111
  > EOF
  $ cat > b << EOF
  > b0
  > aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa
  > bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb
  > EOF
  $ mkdir -p dir0/child0 dir0/child1 dir1
  $ echo c0 > dir0/c
  $ echo d0 > dir0/d
  $ echo e0 > dir0/child0/e
  $ echo f0 > dir0/child1/f
  $ hg -q commit -A -m 'commit 0'

  $ echo a1 >> a
  $ echo d1 > dir0/d
  $ echo g0 > g
  $ echo h0 > h
  $ hg -q commit -A -m 'commit 1'
  $ echo f1 > dir0/child1/f
  $ echo i0 > dir0/i
  $ hg -q commit -A -m 'commit 2'

  $ hg -q up -r 0
  $ echo a2 >> a
  $ hg commit -m 'commit 3'
  created new head

  $ hg log -G -T '{rev}:{node} {desc}\n'
  @  3:476fbf122cd82f6726f0191ff146f67140946abc commit 3
  |
  | o  2:b91c03cbba3519ab149b6cd0a0afbdb5cf1b5c8a commit 2
  | |
  | o  1:5b0b1a23577e205ea240e39c9704e28d7697cbd8 commit 1
  |/
  o  0:6e875ff18c227659ad6143bb3580c65700734884 commit 0
  

  $ hg serve -p $HGPORT -d --pid-file hg.pid -E error.log
  $ cat hg.pid > $DAEMON_PIDS

Missing arguments is an error

  $ sendhttpv2peer << EOF
  > command filesdata
  > EOF
  creating http peer for wire protocol version 2
  sending filesdata command
  abort: missing required arguments: revisions!
  [255]

Bad pattern to pathfilter is rejected

  $ sendhttpv2peer << EOF
  > command filesdata
  >     revisions eval:[{
  >          b'type': b'changesetexplicit',
  >          b'nodes': [
  >              b'\x5b\x0b\x1a\x23\x57\x7e\x20\x5e\xa2\x40\xe3\x9c\x97\x04\xe2\x8d\x76\x97\xcb\xd8',
  >          ]}]
  >     pathfilter eval:{b'include': [b'bad:foo']}
  > EOF
  creating http peer for wire protocol version 2
  sending filesdata command
  abort: include pattern must begin with `path:` or `rootfilesin:`; got bad:foo!
  [255]

  $ sendhttpv2peer << EOF
  > command filesdata
  >     revisions eval:[{
  >         b'type': b'changesetexplicit',
  >         b'nodes': [
  >             b'\x5b\x0b\x1a\x23\x57\x7e\x20\x5e\xa2\x40\xe3\x9c\x97\x04\xe2\x8d\x76\x97\xcb\xd8',
  >         ]}]
  >     pathfilter eval:{b'exclude': [b'glob:foo']}
  > EOF
  creating http peer for wire protocol version 2
  sending filesdata command
  abort: exclude pattern must begin with `path:` or `rootfilesin:`; got glob:foo!
  [255]

Fetching a single changeset without parents fetches all files

  $ sendhttpv2peer << EOF
  > command filesdata
  >     revisions eval:[{
  >         b'type': b'changesetexplicit',
  >         b'nodes': [
  >             b'\x5b\x0b\x1a\x23\x57\x7e\x20\x5e\xa2\x40\xe3\x9c\x97\x04\xe2\x8d\x76\x97\xcb\xd8',
  >         ]}]
  > EOF
  creating http peer for wire protocol version 2
  sending filesdata command
  response: gen[
    {
      b'totalitems': 8,
      b'totalpaths': 8
    },
    {
      b'path': b'a',
      b'totalitems': 1
    },
    {
      b'node': b'\n\x862\x1f\x13y\xd1\xa9\xec\xd0W\x9a"\x97z\xf7\xa5\xac\xaf\x11'
    },
    {
      b'path': b'b',
      b'totalitems': 1
    },
    {
      b'node': b'\x88\xbac\xb8\xd8\xc6 :\xc6z\xc9\x98\xac\xd9\x17K\xf7\x05!\xb2'
    },
    {
      b'path': b'dir0/c',
      b'totalitems': 1
    },
    {
      b'node': b'\x91DE4j\x0c\xa0b\x9b\xd4|\xeb]\xfe\x07\xe4\xd4\xcf%\x01'
    },
    {
      b'path': b'dir0/child0/e',
      b'totalitems': 1
    },
    {
      b'node': b'\xbb\xbal\x06\xb3\x0fD=4\xff\x84\x1b\xc9\x85\xc4\xd0\x82|k\xe4'
    },
    {
      b'path': b'dir0/child1/f',
      b'totalitems': 1
    },
    {
      b'node': b'\x12\xfc}\xcdw;Z\n\x92\x9c\xe1\x95"\x80\x83\xc6\xdd\xc9\xce\xc4'
    },
    {
      b'path': b'dir0/d',
      b'totalitems': 1
    },
    {
      b'node': b'\x93\x88)\xad\x01R}2\xba\x06_\x81#6\xfe\xc7\x9d\xdd9G'
    },
    {
      b'path': b'g',
      b'totalitems': 1
    },
    {
      b'node': b'\xde\xca\xba5DFjI\x95r\xe9\x0f\xac\xe6\xfa\x0c!k\xba\x8c'
    },
    {
      b'path': b'h',
      b'totalitems': 1
    },
    {
      b'node': b'\x03A\xfc\x84\x1b\xb5\xb4\xba\x93\xb2mM\xdaa\xf7y6]\xb3K'
    }
  ]

Fetching a single changeset saying parents data is available fetches just new files

  $ sendhttpv2peer << EOF
  > command filesdata
  >     revisions eval:[{
  >         b'type': b'changesetexplicit',
  >         b'nodes': [
  >             b'\x5b\x0b\x1a\x23\x57\x7e\x20\x5e\xa2\x40\xe3\x9c\x97\x04\xe2\x8d\x76\x97\xcb\xd8',
  >         ]}]
  >     haveparents eval:True
  > EOF
  creating http peer for wire protocol version 2
  sending filesdata command
  response: gen[
    {
      b'totalitems': 4,
      b'totalpaths': 4
    },
    {
      b'path': b'a',
      b'totalitems': 1
    },
    {
      b'node': b'\n\x862\x1f\x13y\xd1\xa9\xec\xd0W\x9a"\x97z\xf7\xa5\xac\xaf\x11'
    },
    {
      b'path': b'dir0/d',
      b'totalitems': 1
    },
    {
      b'node': b'\x93\x88)\xad\x01R}2\xba\x06_\x81#6\xfe\xc7\x9d\xdd9G'
    },
    {
      b'path': b'g',
      b'totalitems': 1
    },
    {
      b'node': b'\xde\xca\xba5DFjI\x95r\xe9\x0f\xac\xe6\xfa\x0c!k\xba\x8c'
    },
    {
      b'path': b'h',
      b'totalitems': 1
    },
    {
      b'node': b'\x03A\xfc\x84\x1b\xb5\xb4\xba\x93\xb2mM\xdaa\xf7y6]\xb3K'
    }
  ]

A path filter for a sub-directory is honored

  $ sendhttpv2peer << EOF
  > command filesdata
  >     revisions eval:[{
  >         b'type': b'changesetexplicit',
  >         b'nodes': [
  >             b'\x5b\x0b\x1a\x23\x57\x7e\x20\x5e\xa2\x40\xe3\x9c\x97\x04\xe2\x8d\x76\x97\xcb\xd8',
  >         ]}]
  >     haveparents eval:True
  >     pathfilter eval:{b'include': [b'path:dir0']}
  > EOF
  creating http peer for wire protocol version 2
  sending filesdata command
  response: gen[
    {
      b'totalitems': 1,
      b'totalpaths': 1
    },
    {
      b'path': b'dir0/d',
      b'totalitems': 1
    },
    {
      b'node': b'\x93\x88)\xad\x01R}2\xba\x06_\x81#6\xfe\xc7\x9d\xdd9G'
    }
  ]

  $ sendhttpv2peer << EOF
  > command filesdata
  >     revisions eval:[{
  >         b'type': b'changesetexplicit',
  >         b'nodes': [
  >             b'\x5b\x0b\x1a\x23\x57\x7e\x20\x5e\xa2\x40\xe3\x9c\x97\x04\xe2\x8d\x76\x97\xcb\xd8',
  >         ]}]
  >     haveparents eval:True
  >     pathfilter eval:{b'exclude': [b'path:a', b'path:g']}
  > EOF
  creating http peer for wire protocol version 2
  sending filesdata command
  response: gen[
    {
      b'totalitems': 2,
      b'totalpaths': 2
    },
    {
      b'path': b'dir0/d',
      b'totalitems': 1
    },
    {
      b'node': b'\x93\x88)\xad\x01R}2\xba\x06_\x81#6\xfe\xc7\x9d\xdd9G'
    },
    {
      b'path': b'h',
      b'totalitems': 1
    },
    {
      b'node': b'\x03A\xfc\x84\x1b\xb5\xb4\xba\x93\xb2mM\xdaa\xf7y6]\xb3K'
    }
  ]

Requesting multiple changeset nodes without haveparents sends all data for both

  $ sendhttpv2peer << EOF
  > command filesdata
  >     revisions eval:[{
  >         b'type': b'changesetexplicit',
  >         b'nodes': [
  >             b'\x5b\x0b\x1a\x23\x57\x7e\x20\x5e\xa2\x40\xe3\x9c\x97\x04\xe2\x8d\x76\x97\xcb\xd8',
  >             b'\xb9\x1c\x03\xcb\xba\x35\x19\xab\x14\x9b\x6c\xd0\xa0\xaf\xbd\xb5\xcf\x1b\x5c\x8a',
  >         ]}]
  > EOF
  creating http peer for wire protocol version 2
  sending filesdata command
  response: gen[
    {
      b'totalitems': 10,
      b'totalpaths': 9
    },
    {
      b'path': b'a',
      b'totalitems': 1
    },
    {
      b'node': b'\n\x862\x1f\x13y\xd1\xa9\xec\xd0W\x9a"\x97z\xf7\xa5\xac\xaf\x11'
    },
    {
      b'path': b'b',
      b'totalitems': 1
    },
    {
      b'node': b'\x88\xbac\xb8\xd8\xc6 :\xc6z\xc9\x98\xac\xd9\x17K\xf7\x05!\xb2'
    },
    {
      b'path': b'dir0/c',
      b'totalitems': 1
    },
    {
      b'node': b'\x91DE4j\x0c\xa0b\x9b\xd4|\xeb]\xfe\x07\xe4\xd4\xcf%\x01'
    },
    {
      b'path': b'dir0/child0/e',
      b'totalitems': 1
    },
    {
      b'node': b'\xbb\xbal\x06\xb3\x0fD=4\xff\x84\x1b\xc9\x85\xc4\xd0\x82|k\xe4'
    },
    {
      b'path': b'dir0/child1/f',
      b'totalitems': 2
    },
    {
      b'node': b'\x12\xfc}\xcdw;Z\n\x92\x9c\xe1\x95"\x80\x83\xc6\xdd\xc9\xce\xc4'
    },
    {
      b'node': b'(\xc7v\xae\x08\xd0\xd5^\xb4\x06H\xb4\x01\xb9\x0f\xf5DH4\x8e'
    },
    {
      b'path': b'dir0/d',
      b'totalitems': 1
    },
    {
      b'node': b'\x93\x88)\xad\x01R}2\xba\x06_\x81#6\xfe\xc7\x9d\xdd9G'
    },
    {
      b'path': b'dir0/i',
      b'totalitems': 1
    },
    {
      b'node': b'\xd7t\xb5\x80Jq\xfd1\xe1\xae\x05\xea\x8e2\xdd\x9b\xa3\xd8S\xd7'
    },
    {
      b'path': b'g',
      b'totalitems': 1
    },
    {
      b'node': b'\xde\xca\xba5DFjI\x95r\xe9\x0f\xac\xe6\xfa\x0c!k\xba\x8c'
    },
    {
      b'path': b'h',
      b'totalitems': 1
    },
    {
      b'node': b'\x03A\xfc\x84\x1b\xb5\xb4\xba\x93\xb2mM\xdaa\xf7y6]\xb3K'
    }
  ]

Requesting multiple changeset nodes with haveparents sends incremental data for both

  $ sendhttpv2peer << EOF
  > command filesdata
  >     revisions eval:[{
  >         b'type': b'changesetexplicit',
  >         b'nodes': [
  >             b'\x5b\x0b\x1a\x23\x57\x7e\x20\x5e\xa2\x40\xe3\x9c\x97\x04\xe2\x8d\x76\x97\xcb\xd8',
  >             b'\xb9\x1c\x03\xcb\xba\x35\x19\xab\x14\x9b\x6c\xd0\xa0\xaf\xbd\xb5\xcf\x1b\x5c\x8a',
  >         ]}]
  >     haveparents eval:True
  > EOF
  creating http peer for wire protocol version 2
  sending filesdata command
  response: gen[
    {
      b'totalitems': 6,
      b'totalpaths': 6
    },
    {
      b'path': b'a',
      b'totalitems': 1
    },
    {
      b'node': b'\n\x862\x1f\x13y\xd1\xa9\xec\xd0W\x9a"\x97z\xf7\xa5\xac\xaf\x11'
    },
    {
      b'path': b'dir0/child1/f',
      b'totalitems': 1
    },
    {
      b'node': b'(\xc7v\xae\x08\xd0\xd5^\xb4\x06H\xb4\x01\xb9\x0f\xf5DH4\x8e'
    },
    {
      b'path': b'dir0/d',
      b'totalitems': 1
    },
    {
      b'node': b'\x93\x88)\xad\x01R}2\xba\x06_\x81#6\xfe\xc7\x9d\xdd9G'
    },
    {
      b'path': b'dir0/i',
      b'totalitems': 1
    },
    {
      b'node': b'\xd7t\xb5\x80Jq\xfd1\xe1\xae\x05\xea\x8e2\xdd\x9b\xa3\xd8S\xd7'
    },
    {
      b'path': b'g',
      b'totalitems': 1
    },
    {
      b'node': b'\xde\xca\xba5DFjI\x95r\xe9\x0f\xac\xe6\xfa\x0c!k\xba\x8c'
    },
    {
      b'path': b'h',
      b'totalitems': 1
    },
    {
      b'node': b'\x03A\xfc\x84\x1b\xb5\xb4\xba\x93\xb2mM\xdaa\xf7y6]\xb3K'
    }
  ]

Requesting parents works

  $ sendhttpv2peer << EOF
  > command filesdata
  >     revisions eval:[{
  >         b'type': b'changesetexplicit',
  >         b'nodes': [
  >             b'\x5b\x0b\x1a\x23\x57\x7e\x20\x5e\xa2\x40\xe3\x9c\x97\x04\xe2\x8d\x76\x97\xcb\xd8',
  >         ]}]
  >     fields eval:[b'parents']
  > EOF
  creating http peer for wire protocol version 2
  sending filesdata command
  response: gen[
    {
      b'totalitems': 8,
      b'totalpaths': 8
    },
    {
      b'path': b'a',
      b'totalitems': 1
    },
    {
      b'node': b'\n\x862\x1f\x13y\xd1\xa9\xec\xd0W\x9a"\x97z\xf7\xa5\xac\xaf\x11',
      b'parents': [
        b'd\x9d\x14\x9d\xf4=\x83\x88%#\xb7\xfb\x1ej:\xf6\xf1\x90{9',
        b'\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00'
      ]
    },
    {
      b'path': b'b',
      b'totalitems': 1
    },
    {
      b'node': b'\x88\xbac\xb8\xd8\xc6 :\xc6z\xc9\x98\xac\xd9\x17K\xf7\x05!\xb2',
      b'parents': [
        b'\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00',
        b'\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00'
      ]
    },
    {
      b'path': b'dir0/c',
      b'totalitems': 1
    },
    {
      b'node': b'\x91DE4j\x0c\xa0b\x9b\xd4|\xeb]\xfe\x07\xe4\xd4\xcf%\x01',
      b'parents': [
        b'\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00',
        b'\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00'
      ]
    },
    {
      b'path': b'dir0/child0/e',
      b'totalitems': 1
    },
    {
      b'node': b'\xbb\xbal\x06\xb3\x0fD=4\xff\x84\x1b\xc9\x85\xc4\xd0\x82|k\xe4',
      b'parents': [
        b'\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00',
        b'\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00'
      ]
    },
    {
      b'path': b'dir0/child1/f',
      b'totalitems': 1
    },
    {
      b'node': b'\x12\xfc}\xcdw;Z\n\x92\x9c\xe1\x95"\x80\x83\xc6\xdd\xc9\xce\xc4',
      b'parents': [
        b'\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00',
        b'\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00'
      ]
    },
    {
      b'path': b'dir0/d',
      b'totalitems': 1
    },
    {
      b'node': b'\x93\x88)\xad\x01R}2\xba\x06_\x81#6\xfe\xc7\x9d\xdd9G',
      b'parents': [
        b'S\x82\x06\xdc\x97\x1eR\x15@\xd6\x84:\xbf\xe6\xd1`2\xf6\xd4&',
        b'\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00'
      ]
    },
    {
      b'path': b'g',
      b'totalitems': 1
    },
    {
      b'node': b'\xde\xca\xba5DFjI\x95r\xe9\x0f\xac\xe6\xfa\x0c!k\xba\x8c',
      b'parents': [
        b'\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00',
        b'\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00'
      ]
    },
    {
      b'path': b'h',
      b'totalitems': 1
    },
    {
      b'node': b'\x03A\xfc\x84\x1b\xb5\xb4\xba\x93\xb2mM\xdaa\xf7y6]\xb3K',
      b'parents': [
        b'\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00',
        b'\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00'
      ]
    }
  ]

Requesting revision data works
(haveparents defaults to False, so fulltext is emitted)

  $ sendhttpv2peer << EOF
  > command filesdata
  >     revisions eval:[{
  >         b'type': b'changesetexplicit',
  >         b'nodes': [
  >             b'\x5b\x0b\x1a\x23\x57\x7e\x20\x5e\xa2\x40\xe3\x9c\x97\x04\xe2\x8d\x76\x97\xcb\xd8',
  >         ]}]
  >     fields eval:[b'revision']
  > EOF
  creating http peer for wire protocol version 2
  sending filesdata command
  response: gen[
    {
      b'totalitems': 8,
      b'totalpaths': 8
    },
    {
      b'path': b'a',
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
    b'a0\n00000000000000000000000000000000000000\n11111111111111111111111111111111111111\na1\n',
    {
      b'path': b'b',
      b'totalitems': 1
    },
    {
      b'fieldsfollowing': [
        [
          b'revision',
          81
        ]
      ],
      b'node': b'\x88\xbac\xb8\xd8\xc6 :\xc6z\xc9\x98\xac\xd9\x17K\xf7\x05!\xb2'
    },
    b'b0\naaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa\nbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb\n',
    {
      b'path': b'dir0/c',
      b'totalitems': 1
    },
    {
      b'fieldsfollowing': [
        [
          b'revision',
          3
        ]
      ],
      b'node': b'\x91DE4j\x0c\xa0b\x9b\xd4|\xeb]\xfe\x07\xe4\xd4\xcf%\x01'
    },
    b'c0\n',
    {
      b'path': b'dir0/child0/e',
      b'totalitems': 1
    },
    {
      b'fieldsfollowing': [
        [
          b'revision',
          3
        ]
      ],
      b'node': b'\xbb\xbal\x06\xb3\x0fD=4\xff\x84\x1b\xc9\x85\xc4\xd0\x82|k\xe4'
    },
    b'e0\n',
    {
      b'path': b'dir0/child1/f',
      b'totalitems': 1
    },
    {
      b'fieldsfollowing': [
        [
          b'revision',
          3
        ]
      ],
      b'node': b'\x12\xfc}\xcdw;Z\n\x92\x9c\xe1\x95"\x80\x83\xc6\xdd\xc9\xce\xc4'
    },
    b'f0\n',
    {
      b'path': b'dir0/d',
      b'totalitems': 1
    },
    {
      b'fieldsfollowing': [
        [
          b'revision',
          3
        ]
      ],
      b'node': b'\x93\x88)\xad\x01R}2\xba\x06_\x81#6\xfe\xc7\x9d\xdd9G'
    },
    b'd1\n',
    {
      b'path': b'g',
      b'totalitems': 1
    },
    {
      b'fieldsfollowing': [
        [
          b'revision',
          3
        ]
      ],
      b'node': b'\xde\xca\xba5DFjI\x95r\xe9\x0f\xac\xe6\xfa\x0c!k\xba\x8c'
    },
    b'g0\n',
    {
      b'path': b'h',
      b'totalitems': 1
    },
    {
      b'fieldsfollowing': [
        [
          b'revision',
          3
        ]
      ],
      b'node': b'\x03A\xfc\x84\x1b\xb5\xb4\xba\x93\xb2mM\xdaa\xf7y6]\xb3K'
    },
    b'h0\n'
  ]

haveparents=False should be same as above

  $ sendhttpv2peer << EOF
  > command filesdata
  >     revisions eval:[{
  >         b'type': b'changesetexplicit',
  >         b'nodes': [
  >             b'\x5b\x0b\x1a\x23\x57\x7e\x20\x5e\xa2\x40\xe3\x9c\x97\x04\xe2\x8d\x76\x97\xcb\xd8',
  >         ]}]
  >     fields eval:[b'revision']
  >     haveparents eval:False
  > EOF
  creating http peer for wire protocol version 2
  sending filesdata command
  response: gen[
    {
      b'totalitems': 8,
      b'totalpaths': 8
    },
    {
      b'path': b'a',
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
    b'a0\n00000000000000000000000000000000000000\n11111111111111111111111111111111111111\na1\n',
    {
      b'path': b'b',
      b'totalitems': 1
    },
    {
      b'fieldsfollowing': [
        [
          b'revision',
          81
        ]
      ],
      b'node': b'\x88\xbac\xb8\xd8\xc6 :\xc6z\xc9\x98\xac\xd9\x17K\xf7\x05!\xb2'
    },
    b'b0\naaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa\nbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb\n',
    {
      b'path': b'dir0/c',
      b'totalitems': 1
    },
    {
      b'fieldsfollowing': [
        [
          b'revision',
          3
        ]
      ],
      b'node': b'\x91DE4j\x0c\xa0b\x9b\xd4|\xeb]\xfe\x07\xe4\xd4\xcf%\x01'
    },
    b'c0\n',
    {
      b'path': b'dir0/child0/e',
      b'totalitems': 1
    },
    {
      b'fieldsfollowing': [
        [
          b'revision',
          3
        ]
      ],
      b'node': b'\xbb\xbal\x06\xb3\x0fD=4\xff\x84\x1b\xc9\x85\xc4\xd0\x82|k\xe4'
    },
    b'e0\n',
    {
      b'path': b'dir0/child1/f',
      b'totalitems': 1
    },
    {
      b'fieldsfollowing': [
        [
          b'revision',
          3
        ]
      ],
      b'node': b'\x12\xfc}\xcdw;Z\n\x92\x9c\xe1\x95"\x80\x83\xc6\xdd\xc9\xce\xc4'
    },
    b'f0\n',
    {
      b'path': b'dir0/d',
      b'totalitems': 1
    },
    {
      b'fieldsfollowing': [
        [
          b'revision',
          3
        ]
      ],
      b'node': b'\x93\x88)\xad\x01R}2\xba\x06_\x81#6\xfe\xc7\x9d\xdd9G'
    },
    b'd1\n',
    {
      b'path': b'g',
      b'totalitems': 1
    },
    {
      b'fieldsfollowing': [
        [
          b'revision',
          3
        ]
      ],
      b'node': b'\xde\xca\xba5DFjI\x95r\xe9\x0f\xac\xe6\xfa\x0c!k\xba\x8c'
    },
    b'g0\n',
    {
      b'path': b'h',
      b'totalitems': 1
    },
    {
      b'fieldsfollowing': [
        [
          b'revision',
          3
        ]
      ],
      b'node': b'\x03A\xfc\x84\x1b\xb5\xb4\xba\x93\xb2mM\xdaa\xf7y6]\xb3K'
    },
    b'h0\n'
  ]

haveparents=True should emit a delta

  $ sendhttpv2peer << EOF
  > command filesdata
  >     revisions eval:[{
  >         b'type': b'changesetexplicit',
  >         b'nodes': [
  >             b'\x5b\x0b\x1a\x23\x57\x7e\x20\x5e\xa2\x40\xe3\x9c\x97\x04\xe2\x8d\x76\x97\xcb\xd8',
  >         ]}]
  >     fields eval:[b'revision']
  >     haveparents eval:True
  > EOF
  creating http peer for wire protocol version 2
  sending filesdata command
  response: gen[
    {
      b'totalitems': 4,
      b'totalpaths': 4
    },
    {
      b'path': b'a',
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
    b'\x00\x00\x00Q\x00\x00\x00Q\x00\x00\x00\x03a1\n',
    {
      b'path': b'dir0/d',
      b'totalitems': 1
    },
    {
      b'deltabasenode': b'S\x82\x06\xdc\x97\x1eR\x15@\xd6\x84:\xbf\xe6\xd1`2\xf6\xd4&',
      b'fieldsfollowing': [
        [
          b'delta',
          15
        ]
      ],
      b'node': b'\x93\x88)\xad\x01R}2\xba\x06_\x81#6\xfe\xc7\x9d\xdd9G'
    },
    b'\x00\x00\x00\x00\x00\x00\x00\x03\x00\x00\x00\x03d1\n',
    {
      b'path': b'g',
      b'totalitems': 1
    },
    {
      b'fieldsfollowing': [
        [
          b'revision',
          3
        ]
      ],
      b'node': b'\xde\xca\xba5DFjI\x95r\xe9\x0f\xac\xe6\xfa\x0c!k\xba\x8c'
    },
    b'g0\n',
    {
      b'path': b'h',
      b'totalitems': 1
    },
    {
      b'fieldsfollowing': [
        [
          b'revision',
          3
        ]
      ],
      b'node': b'\x03A\xfc\x84\x1b\xb5\xb4\xba\x93\xb2mM\xdaa\xf7y6]\xb3K'
    },
    b'h0\n'
  ]

Requesting multiple revisions works
(first revision is a fulltext since haveparents=False by default)

  $ sendhttpv2peer << EOF
  > command filesdata
  >     revisions eval:[{
  >         b'type': b'changesetexplicit',
  >         b'nodes': [
  >             b'\x6e\x87\x5f\xf1\x8c\x22\x76\x59\xad\x61\x43\xbb\x35\x80\xc6\x57\x00\x73\x48\x84',
  >             b'\x5b\x0b\x1a\x23\x57\x7e\x20\x5e\xa2\x40\xe3\x9c\x97\x04\xe2\x8d\x76\x97\xcb\xd8',
  >             b'\xb9\x1c\x03\xcb\xba\x35\x19\xab\x14\x9b\x6c\xd0\xa0\xaf\xbd\xb5\xcf\x1b\x5c\x8a',
  >         ]}]
  >     fields eval:[b'revision']
  > EOF
  creating http peer for wire protocol version 2
  sending filesdata command
  response: gen[
    {
      b'totalitems': 12,
      b'totalpaths': 9
    },
    {
      b'path': b'a',
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
    b'\x00\x00\x00Q\x00\x00\x00Q\x00\x00\x00\x03a1\n',
    {
      b'path': b'b',
      b'totalitems': 1
    },
    {
      b'fieldsfollowing': [
        [
          b'revision',
          81
        ]
      ],
      b'node': b'\x88\xbac\xb8\xd8\xc6 :\xc6z\xc9\x98\xac\xd9\x17K\xf7\x05!\xb2'
    },
    b'b0\naaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa\nbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb\n',
    {
      b'path': b'dir0/c',
      b'totalitems': 1
    },
    {
      b'fieldsfollowing': [
        [
          b'revision',
          3
        ]
      ],
      b'node': b'\x91DE4j\x0c\xa0b\x9b\xd4|\xeb]\xfe\x07\xe4\xd4\xcf%\x01'
    },
    b'c0\n',
    {
      b'path': b'dir0/child0/e',
      b'totalitems': 1
    },
    {
      b'fieldsfollowing': [
        [
          b'revision',
          3
        ]
      ],
      b'node': b'\xbb\xbal\x06\xb3\x0fD=4\xff\x84\x1b\xc9\x85\xc4\xd0\x82|k\xe4'
    },
    b'e0\n',
    {
      b'path': b'dir0/child1/f',
      b'totalitems': 2
    },
    {
      b'fieldsfollowing': [
        [
          b'revision',
          3
        ]
      ],
      b'node': b'\x12\xfc}\xcdw;Z\n\x92\x9c\xe1\x95"\x80\x83\xc6\xdd\xc9\xce\xc4'
    },
    b'f0\n',
    {
      b'deltabasenode': b'\x12\xfc}\xcdw;Z\n\x92\x9c\xe1\x95"\x80\x83\xc6\xdd\xc9\xce\xc4',
      b'fieldsfollowing': [
        [
          b'delta',
          15
        ]
      ],
      b'node': b'(\xc7v\xae\x08\xd0\xd5^\xb4\x06H\xb4\x01\xb9\x0f\xf5DH4\x8e'
    },
    b'\x00\x00\x00\x00\x00\x00\x00\x03\x00\x00\x00\x03f1\n',
    {
      b'path': b'dir0/d',
      b'totalitems': 2
    },
    {
      b'fieldsfollowing': [
        [
          b'revision',
          3
        ]
      ],
      b'node': b'S\x82\x06\xdc\x97\x1eR\x15@\xd6\x84:\xbf\xe6\xd1`2\xf6\xd4&'
    },
    b'd0\n',
    {
      b'deltabasenode': b'S\x82\x06\xdc\x97\x1eR\x15@\xd6\x84:\xbf\xe6\xd1`2\xf6\xd4&',
      b'fieldsfollowing': [
        [
          b'delta',
          15
        ]
      ],
      b'node': b'\x93\x88)\xad\x01R}2\xba\x06_\x81#6\xfe\xc7\x9d\xdd9G'
    },
    b'\x00\x00\x00\x00\x00\x00\x00\x03\x00\x00\x00\x03d1\n',
    {
      b'path': b'dir0/i',
      b'totalitems': 1
    },
    {
      b'fieldsfollowing': [
        [
          b'revision',
          3
        ]
      ],
      b'node': b'\xd7t\xb5\x80Jq\xfd1\xe1\xae\x05\xea\x8e2\xdd\x9b\xa3\xd8S\xd7'
    },
    b'i0\n',
    {
      b'path': b'g',
      b'totalitems': 1
    },
    {
      b'fieldsfollowing': [
        [
          b'revision',
          3
        ]
      ],
      b'node': b'\xde\xca\xba5DFjI\x95r\xe9\x0f\xac\xe6\xfa\x0c!k\xba\x8c'
    },
    b'g0\n',
    {
      b'path': b'h',
      b'totalitems': 1
    },
    {
      b'fieldsfollowing': [
        [
          b'revision',
          3
        ]
      ],
      b'node': b'\x03A\xfc\x84\x1b\xb5\xb4\xba\x93\xb2mM\xdaa\xf7y6]\xb3K'
    },
    b'h0\n'
  ]

Requesting linknode field works

  $ sendhttpv2peer << EOF
  > command filesdata
  >     revisions eval:[{
  >         b'type': b'changesetexplicit',
  >         b'nodes': [
  >             b'\x6e\x87\x5f\xf1\x8c\x22\x76\x59\xad\x61\x43\xbb\x35\x80\xc6\x57\x00\x73\x48\x84',
  >             b'\x5b\x0b\x1a\x23\x57\x7e\x20\x5e\xa2\x40\xe3\x9c\x97\x04\xe2\x8d\x76\x97\xcb\xd8',
  >             b'\xb9\x1c\x03\xcb\xba\x35\x19\xab\x14\x9b\x6c\xd0\xa0\xaf\xbd\xb5\xcf\x1b\x5c\x8a',
  >         ]}]
  >     fields eval:[b'linknode']
  > EOF
  creating http peer for wire protocol version 2
  sending filesdata command
  response: gen[
    {
      b'totalitems': 12,
      b'totalpaths': 9
    },
    {
      b'path': b'a',
      b'totalitems': 2
    },
    {
      b'linknode': b'n\x87_\xf1\x8c"vY\xadaC\xbb5\x80\xc6W\x00sH\x84',
      b'node': b'd\x9d\x14\x9d\xf4=\x83\x88%#\xb7\xfb\x1ej:\xf6\xf1\x90{9'
    },
    {
      b'linknode': b'[\x0b\x1a#W~ ^\xa2@\xe3\x9c\x97\x04\xe2\x8dv\x97\xcb\xd8',
      b'node': b'\n\x862\x1f\x13y\xd1\xa9\xec\xd0W\x9a"\x97z\xf7\xa5\xac\xaf\x11'
    },
    {
      b'path': b'b',
      b'totalitems': 1
    },
    {
      b'linknode': b'n\x87_\xf1\x8c"vY\xadaC\xbb5\x80\xc6W\x00sH\x84',
      b'node': b'\x88\xbac\xb8\xd8\xc6 :\xc6z\xc9\x98\xac\xd9\x17K\xf7\x05!\xb2'
    },
    {
      b'path': b'dir0/c',
      b'totalitems': 1
    },
    {
      b'linknode': b'n\x87_\xf1\x8c"vY\xadaC\xbb5\x80\xc6W\x00sH\x84',
      b'node': b'\x91DE4j\x0c\xa0b\x9b\xd4|\xeb]\xfe\x07\xe4\xd4\xcf%\x01'
    },
    {
      b'path': b'dir0/child0/e',
      b'totalitems': 1
    },
    {
      b'linknode': b'n\x87_\xf1\x8c"vY\xadaC\xbb5\x80\xc6W\x00sH\x84',
      b'node': b'\xbb\xbal\x06\xb3\x0fD=4\xff\x84\x1b\xc9\x85\xc4\xd0\x82|k\xe4'
    },
    {
      b'path': b'dir0/child1/f',
      b'totalitems': 2
    },
    {
      b'linknode': b'n\x87_\xf1\x8c"vY\xadaC\xbb5\x80\xc6W\x00sH\x84',
      b'node': b'\x12\xfc}\xcdw;Z\n\x92\x9c\xe1\x95"\x80\x83\xc6\xdd\xc9\xce\xc4'
    },
    {
      b'linknode': b'\xb9\x1c\x03\xcb\xba5\x19\xab\x14\x9bl\xd0\xa0\xaf\xbd\xb5\xcf\x1b\\\x8a',
      b'node': b'(\xc7v\xae\x08\xd0\xd5^\xb4\x06H\xb4\x01\xb9\x0f\xf5DH4\x8e'
    },
    {
      b'path': b'dir0/d',
      b'totalitems': 2
    },
    {
      b'linknode': b'n\x87_\xf1\x8c"vY\xadaC\xbb5\x80\xc6W\x00sH\x84',
      b'node': b'S\x82\x06\xdc\x97\x1eR\x15@\xd6\x84:\xbf\xe6\xd1`2\xf6\xd4&'
    },
    {
      b'linknode': b'[\x0b\x1a#W~ ^\xa2@\xe3\x9c\x97\x04\xe2\x8dv\x97\xcb\xd8',
      b'node': b'\x93\x88)\xad\x01R}2\xba\x06_\x81#6\xfe\xc7\x9d\xdd9G'
    },
    {
      b'path': b'dir0/i',
      b'totalitems': 1
    },
    {
      b'linknode': b'\xb9\x1c\x03\xcb\xba5\x19\xab\x14\x9bl\xd0\xa0\xaf\xbd\xb5\xcf\x1b\\\x8a',
      b'node': b'\xd7t\xb5\x80Jq\xfd1\xe1\xae\x05\xea\x8e2\xdd\x9b\xa3\xd8S\xd7'
    },
    {
      b'path': b'g',
      b'totalitems': 1
    },
    {
      b'linknode': b'[\x0b\x1a#W~ ^\xa2@\xe3\x9c\x97\x04\xe2\x8dv\x97\xcb\xd8',
      b'node': b'\xde\xca\xba5DFjI\x95r\xe9\x0f\xac\xe6\xfa\x0c!k\xba\x8c'
    },
    {
      b'path': b'h',
      b'totalitems': 1
    },
    {
      b'linknode': b'[\x0b\x1a#W~ ^\xa2@\xe3\x9c\x97\x04\xe2\x8dv\x97\xcb\xd8',
      b'node': b'\x03A\xfc\x84\x1b\xb5\xb4\xba\x93\xb2mM\xdaa\xf7y6]\xb3K'
    }
  ]

  $ cat error.log
