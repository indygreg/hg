Tests for wire protocol version 2 exchange.
Tests in this file should be folded into existing tests once protocol
v2 has enough features that it can be enabled via #testcase in existing
tests.

  $ . $TESTDIR/wireprotohelpers.sh
  $ enablehttpv2client

  $ hg init server-simple
  $ enablehttpv2 server-simple
  $ cd server-simple
  $ cat >> .hg/hgrc << EOF
  > [phases]
  > publish = false
  > EOF
  $ echo a0 > a
  $ echo b0 > b
  $ hg -q commit -A -m 'commit 0'

  $ echo a1 > a
  $ hg commit -m 'commit 1'
  $ hg phase --public -r .
  $ echo a2 > a
  $ hg commit -m 'commit 2'

  $ hg -q up -r 0
  $ echo b1 > b
  $ hg -q commit -m 'head 2 commit 1'
  $ echo b2 > b
  $ hg -q commit -m 'head 2 commit 2'

  $ hg serve -p $HGPORT -d --pid-file hg.pid -E error.log
  $ cat hg.pid > $DAEMON_PIDS

  $ cd ..

Test basic clone

  $ hg --debug clone -U http://localhost:$HGPORT client-simple
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
  received frame(size=43; request=1; stream=2; streamflags=encoded; type=command-response; flags=continuation)
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
    'noderange': [
      [],
      [
        '\xca\xa2\xa4eE\x1d\xd1\xfa\xcd\xa0\xf5\xb1#\x12\xc3UXA\x88\xa1',
        '\xcd%4vk\xec\xe18\xc7\xc1\xaf\xdch%0/\x0fb\xd8\x1f'
      ]
    ]
  }
  received frame(size=9; request=1; stream=2; streamflags=stream-begin; type=stream-settings; flags=eos)
  received frame(size=11; request=1; stream=2; streamflags=encoded; type=command-response; flags=continuation)
  received frame(size=941; request=1; stream=2; streamflags=encoded; type=command-response; flags=continuation)
  received frame(size=0; request=1; stream=2; streamflags=; type=command-response; flags=eos)
  add changeset 3390ef850073
  add changeset 4432d83626e8
  add changeset cd2534766bec
  add changeset e96ae20f4188
  add changeset caa2a465451d
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
      '\xa9\x88\xfbCX>\x87\x1d\x1e\xd5u\x0e\xe0t\xc6\xd8@\xbb\xbf\xc8',
      '\xec\x80NH\x8c \x88\xc25\t\x9a\x10 u\x13\xbe\xcd\xc3\xdd\xa5',
      '\x04\\\x7f9\'\xda\x13\xe7Z\xf8\xf0\xe4\xf0HI\xe4a\xa9x\x0f',
      '7\x9c\xb0\xc2\xe6d\\y\xdd\xc5\x9a\x1dG\'\xa9\xfb\x83\n\xeb&'
    ],
    'tree': ''
  }
  received frame(size=9; request=1; stream=2; streamflags=stream-begin; type=stream-settings; flags=eos)
  received frame(size=11; request=1; stream=2; streamflags=encoded; type=command-response; flags=continuation)
  received frame(size=992; request=1; stream=2; streamflags=encoded; type=command-response; flags=continuation)
  received frame(size=0; request=1; stream=2; streamflags=; type=command-response; flags=eos)
  sending 2 commands
  sending command filedata: {
    'fields': set([
      'parents',
      'revision'
    ]),
    'haveparents': True,
    'nodes': [
      '+N\xb0s\x19\xbf\xa0w\xa4\n/\x04\x916Y\xae\xf0\xdaB\xda',
      '\x9a8\x12)\x97\xb3\xac\x97\xbe*\x9a\xa2\xe5V\x83\x83A\xfd\xf2\xcc',
      '\xc2\xa2\x05\xc8\xb2\xad\xe2J\xf2`b\xe5<\xd5\xbc8\x01\xd6`\xda'
    ],
    'path': 'a'
  }
  sending command filedata: {
    'fields': set([
      'parents',
      'revision'
    ]),
    'haveparents': True,
    'nodes': [
      '\x81\x9e%\x8d1\xa5\xe1`f)\xf3e\xbb\x90*\x1b!\xeeB\x16',
      '\xb1zk\xd3g=\x9a\xb8\xce\xd5\x81\xa2\t\xf6/=\xa5\xccEx',
      '\xc5\xb1\xf9\xd3n\x1c\xc18\xbf\xb6\xef\xb3\xde\xb7]\x8c\xcad\x94\xc3'
    ],
    'path': 'b'
  }
  received frame(size=9; request=1; stream=2; streamflags=stream-begin; type=stream-settings; flags=eos)
  received frame(size=11; request=1; stream=2; streamflags=encoded; type=command-response; flags=continuation)
  received frame(size=431; request=1; stream=2; streamflags=encoded; type=command-response; flags=continuation)
  received frame(size=0; request=1; stream=2; streamflags=; type=command-response; flags=eos)
  received frame(size=11; request=3; stream=2; streamflags=encoded; type=command-response; flags=continuation)
  received frame(size=431; request=3; stream=2; streamflags=encoded; type=command-response; flags=continuation)
  received frame(size=0; request=3; stream=2; streamflags=; type=command-response; flags=eos)
  updating the branch cache
  new changesets 3390ef850073:caa2a465451d (3 drafts)
  (sent 5 HTTP requests and * bytes; received * bytes in responses) (glob)

All changesets should have been transferred

  $ hg -R client-simple debugindex -c
     rev linkrev nodeid       p1           p2
       0       0 3390ef850073 000000000000 000000000000
       1       1 4432d83626e8 3390ef850073 000000000000
       2       2 cd2534766bec 4432d83626e8 000000000000
       3       3 e96ae20f4188 3390ef850073 000000000000
       4       4 caa2a465451d e96ae20f4188 000000000000

  $ hg -R client-simple log -G -T '{rev} {node} {phase}\n'
  o  4 caa2a465451dd1facda0f5b12312c355584188a1 draft
  |
  o  3 e96ae20f4188487b9ae4ef3941c27c81143146e5 draft
  |
  | o  2 cd2534766bece138c7c1afdc6825302f0f62d81f draft
  | |
  | o  1 4432d83626e8a98655f062ec1f2a43b07f7fbbb0 public
  |/
  o  0 3390ef850073fbc2f0dfff2244342c8e9229013a public
  

All manifests should have been transferred

  $ hg -R client-simple debugindex -m
     rev linkrev nodeid       p1           p2
       0       0 992f4779029a 000000000000 000000000000
       1       1 a988fb43583e 992f4779029a 000000000000
       2       2 ec804e488c20 a988fb43583e 000000000000
       3       3 045c7f3927da 992f4779029a 000000000000
       4       4 379cb0c2e664 045c7f3927da 000000000000

Cloning only a specific revision works

  $ hg --debug clone -U -r 4432d83626e8 http://localhost:$HGPORT client-singlehead
  using http://localhost:$HGPORT/
  sending capabilities command
  sending 1 commands
  sending command lookup: {
    'key': '4432d83626e8'
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
  received frame(size=43; request=1; stream=2; streamflags=encoded; type=command-response; flags=continuation)
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
    'noderange': [
      [],
      [
        'D2\xd86&\xe8\xa9\x86U\xf0b\xec\x1f*C\xb0\x7f\x7f\xbb\xb0'
      ]
    ]
  }
  received frame(size=9; request=1; stream=2; streamflags=stream-begin; type=stream-settings; flags=eos)
  received frame(size=11; request=1; stream=2; streamflags=encoded; type=command-response; flags=continuation)
  received frame(size=381; request=1; stream=2; streamflags=encoded; type=command-response; flags=continuation)
  received frame(size=0; request=1; stream=2; streamflags=; type=command-response; flags=eos)
  add changeset 3390ef850073
  add changeset 4432d83626e8
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
      '\xa9\x88\xfbCX>\x87\x1d\x1e\xd5u\x0e\xe0t\xc6\xd8@\xbb\xbf\xc8'
    ],
    'tree': ''
  }
  received frame(size=9; request=1; stream=2; streamflags=stream-begin; type=stream-settings; flags=eos)
  received frame(size=11; request=1; stream=2; streamflags=encoded; type=command-response; flags=continuation)
  received frame(size=404; request=1; stream=2; streamflags=encoded; type=command-response; flags=continuation)
  received frame(size=0; request=1; stream=2; streamflags=; type=command-response; flags=eos)
  sending 2 commands
  sending command filedata: {
    'fields': set([
      'parents',
      'revision'
    ]),
    'haveparents': True,
    'nodes': [
      '+N\xb0s\x19\xbf\xa0w\xa4\n/\x04\x916Y\xae\xf0\xdaB\xda',
      '\x9a8\x12)\x97\xb3\xac\x97\xbe*\x9a\xa2\xe5V\x83\x83A\xfd\xf2\xcc'
    ],
    'path': 'a'
  }
  sending command filedata: {
    'fields': set([
      'parents',
      'revision'
    ]),
    'haveparents': True,
    'nodes': [
      '\x81\x9e%\x8d1\xa5\xe1`f)\xf3e\xbb\x90*\x1b!\xeeB\x16'
    ],
    'path': 'b'
  }
  received frame(size=9; request=1; stream=2; streamflags=stream-begin; type=stream-settings; flags=eos)
  received frame(size=11; request=1; stream=2; streamflags=encoded; type=command-response; flags=continuation)
  received frame(size=277; request=1; stream=2; streamflags=encoded; type=command-response; flags=continuation)
  received frame(size=0; request=1; stream=2; streamflags=; type=command-response; flags=eos)
  received frame(size=11; request=3; stream=2; streamflags=encoded; type=command-response; flags=continuation)
  received frame(size=123; request=3; stream=2; streamflags=encoded; type=command-response; flags=continuation)
  received frame(size=0; request=3; stream=2; streamflags=; type=command-response; flags=eos)
  updating the branch cache
  new changesets 3390ef850073:4432d83626e8
  (sent 6 HTTP requests and * bytes; received * bytes in responses) (glob)

  $ cd client-singlehead

  $ hg log -G -T '{rev} {node} {phase}\n'
  o  1 4432d83626e8a98655f062ec1f2a43b07f7fbbb0 public
  |
  o  0 3390ef850073fbc2f0dfff2244342c8e9229013a public
  

  $ hg debugindex -m
     rev linkrev nodeid       p1           p2
       0       0 992f4779029a 000000000000 000000000000
       1       1 a988fb43583e 992f4779029a 000000000000

Incremental pull works

  $ hg --debug pull
  pulling from http://localhost:$HGPORT/
  using http://localhost:$HGPORT/
  sending capabilities command
  query 1; heads
  sending 2 commands
  sending command heads: {}
  sending command known: {
    'nodes': [
      'D2\xd86&\xe8\xa9\x86U\xf0b\xec\x1f*C\xb0\x7f\x7f\xbb\xb0'
    ]
  }
  received frame(size=9; request=1; stream=2; streamflags=stream-begin; type=stream-settings; flags=eos)
  received frame(size=11; request=1; stream=2; streamflags=encoded; type=command-response; flags=continuation)
  received frame(size=43; request=1; stream=2; streamflags=encoded; type=command-response; flags=continuation)
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
    'noderange': [
      [
        'D2\xd86&\xe8\xa9\x86U\xf0b\xec\x1f*C\xb0\x7f\x7f\xbb\xb0'
      ],
      [
        '\xca\xa2\xa4eE\x1d\xd1\xfa\xcd\xa0\xf5\xb1#\x12\xc3UXA\x88\xa1',
        '\xcd%4vk\xec\xe18\xc7\xc1\xaf\xdch%0/\x0fb\xd8\x1f'
      ]
    ]
  }
  received frame(size=9; request=1; stream=2; streamflags=stream-begin; type=stream-settings; flags=eos)
  received frame(size=11; request=1; stream=2; streamflags=encoded; type=command-response; flags=continuation)
  received frame(size=573; request=1; stream=2; streamflags=encoded; type=command-response; flags=continuation)
  received frame(size=0; request=1; stream=2; streamflags=; type=command-response; flags=eos)
  add changeset cd2534766bec
  add changeset e96ae20f4188
  add changeset caa2a465451d
  checking for updated bookmarks
  sending 1 commands
  sending command manifestdata: {
    'fields': set([
      'parents',
      'revision'
    ]),
    'haveparents': True,
    'nodes': [
      '\xec\x80NH\x8c \x88\xc25\t\x9a\x10 u\x13\xbe\xcd\xc3\xdd\xa5',
      '\x04\\\x7f9\'\xda\x13\xe7Z\xf8\xf0\xe4\xf0HI\xe4a\xa9x\x0f',
      '7\x9c\xb0\xc2\xe6d\\y\xdd\xc5\x9a\x1dG\'\xa9\xfb\x83\n\xeb&'
    ],
    'tree': ''
  }
  received frame(size=9; request=1; stream=2; streamflags=stream-begin; type=stream-settings; flags=eos)
  received frame(size=11; request=1; stream=2; streamflags=encoded; type=command-response; flags=continuation)
  received frame(size=601; request=1; stream=2; streamflags=encoded; type=command-response; flags=continuation)
  received frame(size=0; request=1; stream=2; streamflags=; type=command-response; flags=eos)
  sending 2 commands
  sending command filedata: {
    'fields': set([
      'parents',
      'revision'
    ]),
    'haveparents': True,
    'nodes': [
      '+N\xb0s\x19\xbf\xa0w\xa4\n/\x04\x916Y\xae\xf0\xdaB\xda',
      '\xc2\xa2\x05\xc8\xb2\xad\xe2J\xf2`b\xe5<\xd5\xbc8\x01\xd6`\xda'
    ],
    'path': 'a'
  }
  sending command filedata: {
    'fields': set([
      'parents',
      'revision'
    ]),
    'haveparents': True,
    'nodes': [
      '\x81\x9e%\x8d1\xa5\xe1`f)\xf3e\xbb\x90*\x1b!\xeeB\x16',
      '\xb1zk\xd3g=\x9a\xb8\xce\xd5\x81\xa2\t\xf6/=\xa5\xccEx',
      '\xc5\xb1\xf9\xd3n\x1c\xc18\xbf\xb6\xef\xb3\xde\xb7]\x8c\xcad\x94\xc3'
    ],
    'path': 'b'
  }
  received frame(size=9; request=1; stream=2; streamflags=stream-begin; type=stream-settings; flags=eos)
  received frame(size=11; request=1; stream=2; streamflags=encoded; type=command-response; flags=continuation)
  received frame(size=277; request=1; stream=2; streamflags=encoded; type=command-response; flags=continuation)
  received frame(size=0; request=1; stream=2; streamflags=; type=command-response; flags=eos)
  received frame(size=11; request=3; stream=2; streamflags=encoded; type=command-response; flags=continuation)
  received frame(size=431; request=3; stream=2; streamflags=encoded; type=command-response; flags=continuation)
  received frame(size=0; request=3; stream=2; streamflags=; type=command-response; flags=eos)
  updating the branch cache
  new changesets cd2534766bec:caa2a465451d (3 drafts)
  (run 'hg update' to get a working copy)
  (sent 5 HTTP requests and * bytes; received * bytes in responses) (glob)

  $ hg log -G -T '{rev} {node} {phase}\n'
  o  4 caa2a465451dd1facda0f5b12312c355584188a1 draft
  |
  o  3 e96ae20f4188487b9ae4ef3941c27c81143146e5 draft
  |
  | o  2 cd2534766bece138c7c1afdc6825302f0f62d81f draft
  | |
  | o  1 4432d83626e8a98655f062ec1f2a43b07f7fbbb0 public
  |/
  o  0 3390ef850073fbc2f0dfff2244342c8e9229013a public
  

  $ hg debugindex -m
     rev linkrev nodeid       p1           p2
       0       0 992f4779029a 000000000000 000000000000
       1       1 a988fb43583e 992f4779029a 000000000000
       2       2 ec804e488c20 a988fb43583e 000000000000
       3       3 045c7f3927da 992f4779029a 000000000000
       4       4 379cb0c2e664 045c7f3927da 000000000000

Phase-only update works
TODO this doesn't work

  $ hg -R ../server-simple phase --public -r caa2a465451dd
  $ hg --debug pull
  pulling from http://localhost:$HGPORT/
  using http://localhost:$HGPORT/
  sending capabilities command
  query 1; heads
  sending 2 commands
  sending command heads: {}
  sending command known: {
    'nodes': [
      '\xcd%4vk\xec\xe18\xc7\xc1\xaf\xdch%0/\x0fb\xd8\x1f',
      '\xca\xa2\xa4eE\x1d\xd1\xfa\xcd\xa0\xf5\xb1#\x12\xc3UXA\x88\xa1'
    ]
  }
  received frame(size=9; request=1; stream=2; streamflags=stream-begin; type=stream-settings; flags=eos)
  received frame(size=11; request=1; stream=2; streamflags=encoded; type=command-response; flags=continuation)
  received frame(size=43; request=1; stream=2; streamflags=encoded; type=command-response; flags=continuation)
  received frame(size=0; request=1; stream=2; streamflags=; type=command-response; flags=eos)
  received frame(size=11; request=3; stream=2; streamflags=encoded; type=command-response; flags=continuation)
  received frame(size=3; request=3; stream=2; streamflags=encoded; type=command-response; flags=continuation)
  received frame(size=0; request=3; stream=2; streamflags=; type=command-response; flags=eos)
  searching for changes
  all remote heads known locally
  sending 1 commands
  sending command changesetdata: {
    'fields': set([
      'bookmarks',
      'parents',
      'phase',
      'revision'
    ]),
    'noderange': [
      [
        '\xca\xa2\xa4eE\x1d\xd1\xfa\xcd\xa0\xf5\xb1#\x12\xc3UXA\x88\xa1',
        '\xcd%4vk\xec\xe18\xc7\xc1\xaf\xdch%0/\x0fb\xd8\x1f'
      ],
      [
        '\xca\xa2\xa4eE\x1d\xd1\xfa\xcd\xa0\xf5\xb1#\x12\xc3UXA\x88\xa1',
        '\xcd%4vk\xec\xe18\xc7\xc1\xaf\xdch%0/\x0fb\xd8\x1f'
      ]
    ]
  }
  received frame(size=9; request=1; stream=2; streamflags=stream-begin; type=stream-settings; flags=eos)
  received frame(size=11; request=1; stream=2; streamflags=encoded; type=command-response; flags=continuation)
  received frame(size=13; request=1; stream=2; streamflags=encoded; type=command-response; flags=continuation)
  received frame(size=0; request=1; stream=2; streamflags=; type=command-response; flags=eos)
  checking for updated bookmarks
  (run 'hg update' to get a working copy)
  (sent 3 HTTP requests and * bytes; received * bytes in responses) (glob)

  $ hg log -G -T '{rev} {node} {phase}\n'
  o  4 caa2a465451dd1facda0f5b12312c355584188a1 draft
  |
  o  3 e96ae20f4188487b9ae4ef3941c27c81143146e5 draft
  |
  | o  2 cd2534766bece138c7c1afdc6825302f0f62d81f draft
  | |
  | o  1 4432d83626e8a98655f062ec1f2a43b07f7fbbb0 public
  |/
  o  0 3390ef850073fbc2f0dfff2244342c8e9229013a public
  

  $ cd ..

Bookmarks are transferred on clone

  $ hg -R server-simple bookmark -r 3390ef850073fbc2f0dfff2244342c8e9229013a book-1
  $ hg -R server-simple bookmark -r cd2534766bece138c7c1afdc6825302f0f62d81f book-2

  $ hg --debug clone -U http://localhost:$HGPORT/ client-bookmarks
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
  received frame(size=43; request=1; stream=2; streamflags=encoded; type=command-response; flags=continuation)
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
    'noderange': [
      [],
      [
        '\xca\xa2\xa4eE\x1d\xd1\xfa\xcd\xa0\xf5\xb1#\x12\xc3UXA\x88\xa1',
        '\xcd%4vk\xec\xe18\xc7\xc1\xaf\xdch%0/\x0fb\xd8\x1f'
      ]
    ]
  }
  received frame(size=9; request=1; stream=2; streamflags=stream-begin; type=stream-settings; flags=eos)
  received frame(size=11; request=1; stream=2; streamflags=encoded; type=command-response; flags=continuation)
  received frame(size=979; request=1; stream=2; streamflags=encoded; type=command-response; flags=continuation)
  received frame(size=0; request=1; stream=2; streamflags=; type=command-response; flags=eos)
  add changeset 3390ef850073
  add changeset 4432d83626e8
  add changeset cd2534766bec
  add changeset e96ae20f4188
  add changeset caa2a465451d
  checking for updated bookmarks
  adding remote bookmark book-1
  adding remote bookmark book-2
  sending 1 commands
  sending command manifestdata: {
    'fields': set([
      'parents',
      'revision'
    ]),
    'haveparents': True,
    'nodes': [
      '\x99/Gy\x02\x9a=\xf8\xd0fm\x00\xbb\x92OicN&A',
      '\xa9\x88\xfbCX>\x87\x1d\x1e\xd5u\x0e\xe0t\xc6\xd8@\xbb\xbf\xc8',
      '\xec\x80NH\x8c \x88\xc25\t\x9a\x10 u\x13\xbe\xcd\xc3\xdd\xa5',
      '\x04\\\x7f9\'\xda\x13\xe7Z\xf8\xf0\xe4\xf0HI\xe4a\xa9x\x0f',
      '7\x9c\xb0\xc2\xe6d\\y\xdd\xc5\x9a\x1dG\'\xa9\xfb\x83\n\xeb&'
    ],
    'tree': ''
  }
  received frame(size=9; request=1; stream=2; streamflags=stream-begin; type=stream-settings; flags=eos)
  received frame(size=11; request=1; stream=2; streamflags=encoded; type=command-response; flags=continuation)
  received frame(size=992; request=1; stream=2; streamflags=encoded; type=command-response; flags=continuation)
  received frame(size=0; request=1; stream=2; streamflags=; type=command-response; flags=eos)
  sending 2 commands
  sending command filedata: {
    'fields': set([
      'parents',
      'revision'
    ]),
    'haveparents': True,
    'nodes': [
      '+N\xb0s\x19\xbf\xa0w\xa4\n/\x04\x916Y\xae\xf0\xdaB\xda',
      '\x9a8\x12)\x97\xb3\xac\x97\xbe*\x9a\xa2\xe5V\x83\x83A\xfd\xf2\xcc',
      '\xc2\xa2\x05\xc8\xb2\xad\xe2J\xf2`b\xe5<\xd5\xbc8\x01\xd6`\xda'
    ],
    'path': 'a'
  }
  sending command filedata: {
    'fields': set([
      'parents',
      'revision'
    ]),
    'haveparents': True,
    'nodes': [
      '\x81\x9e%\x8d1\xa5\xe1`f)\xf3e\xbb\x90*\x1b!\xeeB\x16',
      '\xb1zk\xd3g=\x9a\xb8\xce\xd5\x81\xa2\t\xf6/=\xa5\xccEx',
      '\xc5\xb1\xf9\xd3n\x1c\xc18\xbf\xb6\xef\xb3\xde\xb7]\x8c\xcad\x94\xc3'
    ],
    'path': 'b'
  }
  received frame(size=9; request=1; stream=2; streamflags=stream-begin; type=stream-settings; flags=eos)
  received frame(size=11; request=1; stream=2; streamflags=encoded; type=command-response; flags=continuation)
  received frame(size=431; request=1; stream=2; streamflags=encoded; type=command-response; flags=continuation)
  received frame(size=0; request=1; stream=2; streamflags=; type=command-response; flags=eos)
  received frame(size=11; request=3; stream=2; streamflags=encoded; type=command-response; flags=continuation)
  received frame(size=431; request=3; stream=2; streamflags=encoded; type=command-response; flags=continuation)
  received frame(size=0; request=3; stream=2; streamflags=; type=command-response; flags=eos)
  updating the branch cache
  new changesets 3390ef850073:caa2a465451d (1 drafts)
  (sent 5 HTTP requests and * bytes; received * bytes in responses) (glob)

  $ hg -R client-bookmarks bookmarks
     book-1                    0:3390ef850073
     book-2                    2:cd2534766bec

Server-side bookmark moves are reflected during `hg pull`

  $ hg -R server-simple bookmark -r cd2534766bece138c7c1afdc6825302f0f62d81f book-1
  moving bookmark 'book-1' forward from 3390ef850073

  $ hg -R client-bookmarks --debug pull
  pulling from http://localhost:$HGPORT/
  using http://localhost:$HGPORT/
  sending capabilities command
  query 1; heads
  sending 2 commands
  sending command heads: {}
  sending command known: {
    'nodes': [
      '\xcd%4vk\xec\xe18\xc7\xc1\xaf\xdch%0/\x0fb\xd8\x1f',
      '\xca\xa2\xa4eE\x1d\xd1\xfa\xcd\xa0\xf5\xb1#\x12\xc3UXA\x88\xa1'
    ]
  }
  received frame(size=9; request=1; stream=2; streamflags=stream-begin; type=stream-settings; flags=eos)
  received frame(size=11; request=1; stream=2; streamflags=encoded; type=command-response; flags=continuation)
  received frame(size=43; request=1; stream=2; streamflags=encoded; type=command-response; flags=continuation)
  received frame(size=0; request=1; stream=2; streamflags=; type=command-response; flags=eos)
  received frame(size=11; request=3; stream=2; streamflags=encoded; type=command-response; flags=continuation)
  received frame(size=3; request=3; stream=2; streamflags=encoded; type=command-response; flags=continuation)
  received frame(size=0; request=3; stream=2; streamflags=; type=command-response; flags=eos)
  searching for changes
  all remote heads known locally
  sending 1 commands
  sending command changesetdata: {
    'fields': set([
      'bookmarks',
      'parents',
      'phase',
      'revision'
    ]),
    'noderange': [
      [
        '\xca\xa2\xa4eE\x1d\xd1\xfa\xcd\xa0\xf5\xb1#\x12\xc3UXA\x88\xa1',
        '\xcd%4vk\xec\xe18\xc7\xc1\xaf\xdch%0/\x0fb\xd8\x1f'
      ],
      [
        '\xca\xa2\xa4eE\x1d\xd1\xfa\xcd\xa0\xf5\xb1#\x12\xc3UXA\x88\xa1',
        '\xcd%4vk\xec\xe18\xc7\xc1\xaf\xdch%0/\x0fb\xd8\x1f'
      ]
    ]
  }
  received frame(size=9; request=1; stream=2; streamflags=stream-begin; type=stream-settings; flags=eos)
  received frame(size=11; request=1; stream=2; streamflags=encoded; type=command-response; flags=continuation)
  received frame(size=65; request=1; stream=2; streamflags=encoded; type=command-response; flags=continuation)
  received frame(size=0; request=1; stream=2; streamflags=; type=command-response; flags=eos)
  checking for updated bookmarks
  updating bookmark book-1
  (run 'hg update' to get a working copy)
  (sent 3 HTTP requests and * bytes; received * bytes in responses) (glob)

  $ hg -R client-bookmarks bookmarks
     book-1                    2:cd2534766bec
     book-2                    2:cd2534766bec
