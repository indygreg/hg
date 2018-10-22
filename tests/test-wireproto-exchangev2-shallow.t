#require sqlite

Tests for wire protocol version 2 exchange.
Tests in this file should be folded into existing tests once protocol
v2 has enough features that it can be enabled via #testcase in existing
tests.

  $ . $TESTDIR/wireprotohelpers.sh
  $ enablehttpv2client
  $ cat >> $HGRCPATH << EOF
  > [extensions]
  > sqlitestore =
  > pullext = $TESTDIR/pullext.py
  > [storage]
  > new-repo-backend=sqlite
  > EOF

Configure a server

  $ hg init server-basic
  $ enablehttpv2 server-basic
  $ cd server-basic
  $ mkdir dir0 dir1
  $ echo a0 > a
  $ echo b0 > b
  $ hg -q commit -A -m 'commit 0'
  $ echo c0 > dir0/c
  $ echo d0 > dir0/d
  $ hg -q commit -A -m 'commit 1'
  $ echo e0 > dir1/e
  $ echo f0 > dir1/f
  $ hg -q commit -A -m 'commit 2'
  $ echo c1 > dir0/c
  $ echo e1 > dir1/e
  $ hg commit -m 'commit 3'
  $ echo c2 > dir0/c
  $ echo e2 > dir1/e
  $ echo f1 > dir1/f
  $ hg commit -m 'commit 4'
  $ echo a1 > a
  $ echo b1 > b
  $ hg commit -m 'commit 5'

  $ hg log -G -T '{node} {desc}'
  @  93a8bd067ed2840d9aa810ad598168383a3a2c3a commit 5
  |
  o  dc666cf9ecf3d94e6b830f30e5f1272e2a9164d9 commit 4
  |
  o  97765fc3cd624fd1fa0176932c21ffd16adf432e commit 3
  |
  o  47fe012ab237a8c7fc0c78f9f26d5866eef3f825 commit 2
  |
  o  b709380892b193c1091d3a817f706052e346821b commit 1
  |
  o  3390ef850073fbc2f0dfff2244342c8e9229013a commit 0
  
  $ hg serve -p $HGPORT -d --pid-file hg.pid -E error.log
  $ cat hg.pid > $DAEMON_PIDS

  $ cd ..

Shallow clone pulls down latest revision of every file

  $ hg --debug clone --depth 1 http://localhost:$HGPORT client-shallow-1
  using http://localhost:$HGPORT/
  sending capabilities command
  query 1; heads
  sending 2 commands
  sending command heads: {}
  sending command known: {
    'nodes': []
  }
  received frame(size=9; request=1; stream=2; streamflags=stream-begin; type=stream-settings; flags=eos)
  received frame(size=11; request=1; stream=2; streamflags=encoded; type=command-response; flags=continuation)
  received frame(size=22; request=1; stream=2; streamflags=encoded; type=command-response; flags=continuation)
  received frame(size=0; request=1; stream=2; streamflags=; type=command-response; flags=eos)
  received frame(size=11; request=3; stream=2; streamflags=encoded; type=command-response; flags=continuation)
  received frame(size=1; request=3; stream=2; streamflags=encoded; type=command-response; flags=continuation)
  received frame(size=0; request=3; stream=2; streamflags=; type=command-response; flags=eos)
  sending 1 commands
  sending command changesetdata: {
    'fields': set([
      'bookmarks',
      'parents',
      'phase',
      'revision'
    ]),
    'revisions': [
      {
        'heads': [
          '\x93\xa8\xbd\x06~\xd2\x84\r\x9a\xa8\x10\xadY\x81h8::,:'
        ],
        'roots': [],
        'type': 'changesetdagrange'
      }
    ]
  }
  received frame(size=9; request=1; stream=2; streamflags=stream-begin; type=stream-settings; flags=eos)
  received frame(size=11; request=1; stream=2; streamflags=encoded; type=command-response; flags=continuation)
  received frame(size=1170; request=1; stream=2; streamflags=encoded; type=command-response; flags=continuation)
  received frame(size=0; request=1; stream=2; streamflags=; type=command-response; flags=eos)
  add changeset 3390ef850073
  add changeset b709380892b1
  add changeset 47fe012ab237
  add changeset 97765fc3cd62
  add changeset dc666cf9ecf3
  add changeset 93a8bd067ed2
  checking for updated bookmarks
  sending 1 commands
  sending command manifestdata: {
    'fields': set([
      'parents',
      'revision'
    ]),
    'haveparents': True,
    'nodes': [
      '\x99/Gy\x02\x9a=\xf8\xd0fm\x00\xbb\x92OicN&A',
      '|2 \x1a\xa3\xa1R\xa9\xe6\xa9"+?\xa8\xd0\xe3\x0f\xc2V\xe8',
      '\x8d\xd0W<\x7f\xaf\xe2\x04F\xcc\xea\xac\x05N\xea\xa4x\x91M\xdb',
      '113\x85\xf2!\x8b\x08^\xb2Z\x821\x1e*\xdd\x0e\xeb\x8c3',
      'H]O\xc2`\xef\\\xb9\xc0p6\x88K\x00k\x11\x0ej\xdby',
      '\xd9;\xc4\x0b\x0e*GMp\xee\xf7}^\x91/f\x7fSd\x83'
    ],
    'tree': ''
  }
  received frame(size=9; request=1; stream=2; streamflags=stream-begin; type=stream-settings; flags=eos)
  received frame(size=11; request=1; stream=2; streamflags=encoded; type=command-response; flags=continuation)
  received frame(size=1515; request=1; stream=2; streamflags=encoded; type=command-response; flags=continuation)
  received frame(size=0; request=1; stream=2; streamflags=; type=command-response; flags=eos)
  sending 1 commands
  sending command filesdata: {
    'fields': set([
      'linknode',
      'parents',
      'revision'
    ]),
    'haveparents': False,
    'revisions': [
      {
        'nodes': [
          '\x93\xa8\xbd\x06~\xd2\x84\r\x9a\xa8\x10\xadY\x81h8::,:'
        ],
        'type': 'changesetexplicit'
      }
    ]
  }
  received frame(size=9; request=1; stream=2; streamflags=stream-begin; type=stream-settings; flags=eos)
  received frame(size=11; request=1; stream=2; streamflags=encoded; type=command-response; flags=continuation)
  received frame(size=1005; request=1; stream=2; streamflags=encoded; type=command-response; flags=continuation)
  received frame(size=0; request=1; stream=2; streamflags=; type=command-response; flags=eos)
  updating the branch cache
  new changesets 3390ef850073:93a8bd067ed2
  updating to branch default
  resolving manifests
   branchmerge: False, force: False, partial: False
   ancestor: 000000000000, local: 000000000000+, remote: 93a8bd067ed2
   a: remote created -> g
  getting a
   b: remote created -> g
  getting b
   dir0/c: remote created -> g
  getting dir0/c
   dir0/d: remote created -> g
  getting dir0/d
   dir1/e: remote created -> g
  getting dir1/e
   dir1/f: remote created -> g
  getting dir1/f
  6 files updated, 0 files merged, 0 files removed, 0 files unresolved
  (sent 5 HTTP requests and * bytes; received * bytes in responses) (glob)

  $ sqlite3 -line client-shallow-1/.hg/store/db.sqlite << EOF
  > SELECT id, path, revnum, node, p1rev, p2rev, linkrev, flags FROM filedata ORDER BY id ASC;
  > EOF
       id = 1
     path = a
   revnum = 0
     node = \x9a8\x12)\x97\xb3\xac\x97\xbe*\x9a\xa2\xe5V\x83\x83A\xfd\xf2\xcc (esc)
    p1rev = -1
    p2rev = -1
  linkrev = 5
    flags = 2
  
       id = 2
     path = b
   revnum = 0
     node = \xb1zk\xd3g=\x9a\xb8\xce\xd5\x81\xa2	\xf6/=\xa5\xccEx (esc)
    p1rev = -1
    p2rev = -1
  linkrev = 5
    flags = 2
  
       id = 3
     path = dir0/c
   revnum = 0
     node = I\x1d\xa1\xbb\x89\xeax\xc0\xc0\xa2s[\x16\xce}\x93\x1d\xc8\xe2\r (esc)
    p1rev = -1
    p2rev = -1
  linkrev = 4
    flags = 2
  
       id = 4
     path = dir0/d
   revnum = 0
     node = S\x82\x06\xdc\x97\x1eR\x15@\xd6\x84:\xbf\xe6\xd1`2\xf6\xd4& (esc)
    p1rev = -1
    p2rev = -1
  linkrev = 1
    flags = 0
  
       id = 5
     path = dir1/e
   revnum = 0
     node = ]\xf3\xac\xd8\xd0\xc7\xfaP\x98\xd0'\x9a\x044\xc3\x02\x9e+x\xe1 (esc)
    p1rev = -1
    p2rev = -1
  linkrev = 4
    flags = 2
  
       id = 6
     path = dir1/f
   revnum = 0
     node = (\xc7v\xae\x08\xd0\xd5^\xb4\x06H\xb4\x01\xb9\x0f\xf5DH4\x8e (esc)
    p1rev = -1
    p2rev = -1
  linkrev = 4
    flags = 2

Test a shallow clone with only some files

  $ hg --debug clone --depth 1 --include dir0/ http://localhost:$HGPORT client-shallow-narrow-1
  using http://localhost:$HGPORT/
  sending capabilities command
  query 1; heads
  sending 2 commands
  sending command heads: {}
  sending command known: {
    'nodes': []
  }
  received frame(size=9; request=1; stream=2; streamflags=stream-begin; type=stream-settings; flags=eos)
  received frame(size=11; request=1; stream=2; streamflags=encoded; type=command-response; flags=continuation)
  received frame(size=22; request=1; stream=2; streamflags=encoded; type=command-response; flags=continuation)
  received frame(size=0; request=1; stream=2; streamflags=; type=command-response; flags=eos)
  received frame(size=11; request=3; stream=2; streamflags=encoded; type=command-response; flags=continuation)
  received frame(size=1; request=3; stream=2; streamflags=encoded; type=command-response; flags=continuation)
  received frame(size=0; request=3; stream=2; streamflags=; type=command-response; flags=eos)
  sending 1 commands
  sending command changesetdata: {
    'fields': set([
      'bookmarks',
      'parents',
      'phase',
      'revision'
    ]),
    'revisions': [
      {
        'heads': [
          '\x93\xa8\xbd\x06~\xd2\x84\r\x9a\xa8\x10\xadY\x81h8::,:'
        ],
        'roots': [],
        'type': 'changesetdagrange'
      }
    ]
  }
  received frame(size=9; request=1; stream=2; streamflags=stream-begin; type=stream-settings; flags=eos)
  received frame(size=11; request=1; stream=2; streamflags=encoded; type=command-response; flags=continuation)
  received frame(size=1170; request=1; stream=2; streamflags=encoded; type=command-response; flags=continuation)
  received frame(size=0; request=1; stream=2; streamflags=; type=command-response; flags=eos)
  add changeset 3390ef850073
  add changeset b709380892b1
  add changeset 47fe012ab237
  add changeset 97765fc3cd62
  add changeset dc666cf9ecf3
  add changeset 93a8bd067ed2
  checking for updated bookmarks
  sending 1 commands
  sending command manifestdata: {
    'fields': set([
      'parents',
      'revision'
    ]),
    'haveparents': True,
    'nodes': [
      '\x99/Gy\x02\x9a=\xf8\xd0fm\x00\xbb\x92OicN&A',
      '|2 \x1a\xa3\xa1R\xa9\xe6\xa9"+?\xa8\xd0\xe3\x0f\xc2V\xe8',
      '\x8d\xd0W<\x7f\xaf\xe2\x04F\xcc\xea\xac\x05N\xea\xa4x\x91M\xdb',
      '113\x85\xf2!\x8b\x08^\xb2Z\x821\x1e*\xdd\x0e\xeb\x8c3',
      'H]O\xc2`\xef\\\xb9\xc0p6\x88K\x00k\x11\x0ej\xdby',
      '\xd9;\xc4\x0b\x0e*GMp\xee\xf7}^\x91/f\x7fSd\x83'
    ],
    'tree': ''
  }
  received frame(size=9; request=1; stream=2; streamflags=stream-begin; type=stream-settings; flags=eos)
  received frame(size=11; request=1; stream=2; streamflags=encoded; type=command-response; flags=continuation)
  received frame(size=1515; request=1; stream=2; streamflags=encoded; type=command-response; flags=continuation)
  received frame(size=0; request=1; stream=2; streamflags=; type=command-response; flags=eos)
  sending 1 commands
  sending command filesdata: {
    'fields': set([
      'linknode',
      'parents',
      'revision'
    ]),
    'haveparents': False,
    'pathfilter': {
      'include': [
        'path:dir0'
      ]
    },
    'revisions': [
      {
        'nodes': [
          '\x93\xa8\xbd\x06~\xd2\x84\r\x9a\xa8\x10\xadY\x81h8::,:'
        ],
        'type': 'changesetexplicit'
      }
    ]
  }
  received frame(size=9; request=1; stream=2; streamflags=stream-begin; type=stream-settings; flags=eos)
  received frame(size=11; request=1; stream=2; streamflags=encoded; type=command-response; flags=continuation)
  received frame(size=355; request=1; stream=2; streamflags=encoded; type=command-response; flags=continuation)
  received frame(size=0; request=1; stream=2; streamflags=; type=command-response; flags=eos)
  updating the branch cache
  new changesets 3390ef850073:93a8bd067ed2
  updating to branch default
  resolving manifests
   branchmerge: False, force: False, partial: False
   ancestor: 000000000000, local: 000000000000+, remote: 93a8bd067ed2
   dir0/c: remote created -> g
  getting dir0/c
   dir0/d: remote created -> g
  getting dir0/d
  2 files updated, 0 files merged, 0 files removed, 0 files unresolved
  (sent 5 HTTP requests and * bytes; received * bytes in responses) (glob)

  $ sqlite3 -line client-shallow-narrow-1/.hg/store/db.sqlite << EOF
  > SELECT id, path, revnum, node, p1rev, p2rev, linkrev, flags FROM filedata ORDER BY id ASC;
  > EOF
       id = 1
     path = dir0/c
   revnum = 0
     node = I\x1d\xa1\xbb\x89\xeax\xc0\xc0\xa2s[\x16\xce}\x93\x1d\xc8\xe2\r (esc)
    p1rev = -1
    p2rev = -1
  linkrev = 4
    flags = 2
  
       id = 2
     path = dir0/d
   revnum = 0
     node = S\x82\x06\xdc\x97\x1eR\x15@\xd6\x84:\xbf\xe6\xd1`2\xf6\xd4& (esc)
    p1rev = -1
    p2rev = -1
  linkrev = 1
    flags = 0

Cloning an old revision with depth=1 works

  $ hg --debug clone --depth 1 -r 97765fc3cd624fd1fa0176932c21ffd16adf432e http://localhost:$HGPORT client-shallow-2
  using http://localhost:$HGPORT/
  sending capabilities command
  sending 1 commands
  sending command lookup: {
    'key': '97765fc3cd624fd1fa0176932c21ffd16adf432e'
  }
  received frame(size=9; request=1; stream=2; streamflags=stream-begin; type=stream-settings; flags=eos)
  received frame(size=11; request=1; stream=2; streamflags=encoded; type=command-response; flags=continuation)
  received frame(size=21; request=1; stream=2; streamflags=encoded; type=command-response; flags=continuation)
  received frame(size=0; request=1; stream=2; streamflags=; type=command-response; flags=eos)
  query 1; heads
  sending 2 commands
  sending command heads: {}
  sending command known: {
    'nodes': []
  }
  received frame(size=9; request=1; stream=2; streamflags=stream-begin; type=stream-settings; flags=eos)
  received frame(size=11; request=1; stream=2; streamflags=encoded; type=command-response; flags=continuation)
  received frame(size=22; request=1; stream=2; streamflags=encoded; type=command-response; flags=continuation)
  received frame(size=0; request=1; stream=2; streamflags=; type=command-response; flags=eos)
  received frame(size=11; request=3; stream=2; streamflags=encoded; type=command-response; flags=continuation)
  received frame(size=1; request=3; stream=2; streamflags=encoded; type=command-response; flags=continuation)
  received frame(size=0; request=3; stream=2; streamflags=; type=command-response; flags=eos)
  sending 1 commands
  sending command changesetdata: {
    'fields': set([
      'bookmarks',
      'parents',
      'phase',
      'revision'
    ]),
    'revisions': [
      {
        'heads': [
          '\x97v_\xc3\xcdbO\xd1\xfa\x01v\x93,!\xff\xd1j\xdfC.'
        ],
        'roots': [],
        'type': 'changesetdagrange'
      }
    ]
  }
  received frame(size=9; request=1; stream=2; streamflags=stream-begin; type=stream-settings; flags=eos)
  received frame(size=11; request=1; stream=2; streamflags=encoded; type=command-response; flags=continuation)
  received frame(size=783; request=1; stream=2; streamflags=encoded; type=command-response; flags=continuation)
  received frame(size=0; request=1; stream=2; streamflags=; type=command-response; flags=eos)
  add changeset 3390ef850073
  add changeset b709380892b1
  add changeset 47fe012ab237
  add changeset 97765fc3cd62
  checking for updated bookmarks
  sending 1 commands
  sending command manifestdata: {
    'fields': set([
      'parents',
      'revision'
    ]),
    'haveparents': True,
    'nodes': [
      '\x99/Gy\x02\x9a=\xf8\xd0fm\x00\xbb\x92OicN&A',
      '|2 \x1a\xa3\xa1R\xa9\xe6\xa9"+?\xa8\xd0\xe3\x0f\xc2V\xe8',
      '\x8d\xd0W<\x7f\xaf\xe2\x04F\xcc\xea\xac\x05N\xea\xa4x\x91M\xdb',
      '113\x85\xf2!\x8b\x08^\xb2Z\x821\x1e*\xdd\x0e\xeb\x8c3'
    ],
    'tree': ''
  }
  received frame(size=9; request=1; stream=2; streamflags=stream-begin; type=stream-settings; flags=eos)
  received frame(size=11; request=1; stream=2; streamflags=encoded; type=command-response; flags=continuation)
  received frame(size=967; request=1; stream=2; streamflags=encoded; type=command-response; flags=continuation)
  received frame(size=0; request=1; stream=2; streamflags=; type=command-response; flags=eos)
  sending 1 commands
  sending command filesdata: {
    'fields': set([
      'linknode',
      'parents',
      'revision'
    ]),
    'haveparents': False,
    'revisions': [
      {
        'nodes': [
          '\x97v_\xc3\xcdbO\xd1\xfa\x01v\x93,!\xff\xd1j\xdfC.'
        ],
        'type': 'changesetexplicit'
      }
    ]
  }
  received frame(size=9; request=1; stream=2; streamflags=stream-begin; type=stream-settings; flags=eos)
  received frame(size=11; request=1; stream=2; streamflags=encoded; type=command-response; flags=continuation)
  received frame(size=1005; request=1; stream=2; streamflags=encoded; type=command-response; flags=continuation)
  received frame(size=0; request=1; stream=2; streamflags=; type=command-response; flags=eos)
  updating the branch cache
  new changesets 3390ef850073:97765fc3cd62
  updating to branch default
  resolving manifests
   branchmerge: False, force: False, partial: False
   ancestor: 000000000000, local: 000000000000+, remote: 97765fc3cd62
   a: remote created -> g
  getting a
   b: remote created -> g
  getting b
   dir0/c: remote created -> g
  getting dir0/c
   dir0/d: remote created -> g
  getting dir0/d
   dir1/e: remote created -> g
  getting dir1/e
   dir1/f: remote created -> g
  getting dir1/f
  6 files updated, 0 files merged, 0 files removed, 0 files unresolved
  (sent 6 HTTP requests and * bytes; received * bytes in responses) (glob)

Incremental pull of shallow clone fetches new changesets

  $ hg --cwd client-shallow-2 --debug pull http://localhost:$HGPORT
  pulling from http://localhost:$HGPORT/
  using http://localhost:$HGPORT/
  sending capabilities command
  query 1; heads
  sending 2 commands
  sending command heads: {}
  sending command known: {
    'nodes': [
      '\x97v_\xc3\xcdbO\xd1\xfa\x01v\x93,!\xff\xd1j\xdfC.'
    ]
  }
  received frame(size=9; request=1; stream=2; streamflags=stream-begin; type=stream-settings; flags=eos)
  received frame(size=11; request=1; stream=2; streamflags=encoded; type=command-response; flags=continuation)
  received frame(size=22; request=1; stream=2; streamflags=encoded; type=command-response; flags=continuation)
  received frame(size=0; request=1; stream=2; streamflags=; type=command-response; flags=eos)
  received frame(size=11; request=3; stream=2; streamflags=encoded; type=command-response; flags=continuation)
  received frame(size=2; request=3; stream=2; streamflags=encoded; type=command-response; flags=continuation)
  received frame(size=0; request=3; stream=2; streamflags=; type=command-response; flags=eos)
  searching for changes
  all local heads known remotely
  sending 1 commands
  sending command changesetdata: {
    'fields': set([
      'bookmarks',
      'parents',
      'phase',
      'revision'
    ]),
    'revisions': [
      {
        'heads': [
          '\x93\xa8\xbd\x06~\xd2\x84\r\x9a\xa8\x10\xadY\x81h8::,:'
        ],
        'roots': [
          '\x97v_\xc3\xcdbO\xd1\xfa\x01v\x93,!\xff\xd1j\xdfC.'
        ],
        'type': 'changesetdagrange'
      }
    ]
  }
  received frame(size=9; request=1; stream=2; streamflags=stream-begin; type=stream-settings; flags=eos)
  received frame(size=11; request=1; stream=2; streamflags=encoded; type=command-response; flags=continuation)
  received frame(size=400; request=1; stream=2; streamflags=encoded; type=command-response; flags=continuation)
  received frame(size=0; request=1; stream=2; streamflags=; type=command-response; flags=eos)
  add changeset dc666cf9ecf3
  add changeset 93a8bd067ed2
  checking for updated bookmarks
  sending 1 commands
  sending command manifestdata: {
    'fields': set([
      'parents',
      'revision'
    ]),
    'haveparents': True,
    'nodes': [
      'H]O\xc2`\xef\\\xb9\xc0p6\x88K\x00k\x11\x0ej\xdby',
      '\xd9;\xc4\x0b\x0e*GMp\xee\xf7}^\x91/f\x7fSd\x83'
    ],
    'tree': ''
  }
  received frame(size=9; request=1; stream=2; streamflags=stream-begin; type=stream-settings; flags=eos)
  received frame(size=11; request=1; stream=2; streamflags=encoded; type=command-response; flags=continuation)
  received frame(size=561; request=1; stream=2; streamflags=encoded; type=command-response; flags=continuation)
  received frame(size=0; request=1; stream=2; streamflags=; type=command-response; flags=eos)
  sending 1 commands
  sending command filesdata: {
    'fields': set([
      'linknode',
      'parents',
      'revision'
    ]),
    'haveparents': False,
    'revisions': [
      {
        'nodes': [
          '\xdcfl\xf9\xec\xf3\xd9Nk\x83\x0f0\xe5\xf1\'.*\x91d\xd9',
          '\x93\xa8\xbd\x06~\xd2\x84\r\x9a\xa8\x10\xadY\x81h8::,:'
        ],
        'type': 'changesetexplicit'
      }
    ]
  }
  received frame(size=9; request=1; stream=2; streamflags=stream-begin; type=stream-settings; flags=eos)
  received frame(size=11; request=1; stream=2; streamflags=encoded; type=command-response; flags=continuation)
  received frame(size=1373; request=1; stream=2; streamflags=encoded; type=command-response; flags=continuation)
  received frame(size=0; request=1; stream=2; streamflags=; type=command-response; flags=eos)
  updating the branch cache
  new changesets dc666cf9ecf3:93a8bd067ed2
  (run 'hg update' to get a working copy)
  (sent 5 HTTP requests and * bytes; received * bytes in responses) (glob)

  $ hg --cwd client-shallow-2 up tip
  merging dir0/c
  merging dir1/e
  3 files updated, 2 files merged, 0 files removed, 0 files unresolved
