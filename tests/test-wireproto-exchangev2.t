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
  received frame(size=11; request=1; stream=2; streamflags=stream-begin; type=command-response; flags=continuation)
  received frame(size=43; request=1; stream=2; streamflags=; type=command-response; flags=continuation)
  received frame(size=0; request=1; stream=2; streamflags=; type=command-response; flags=eos)
  received frame(size=11; request=3; stream=2; streamflags=; type=command-response; flags=continuation)
  received frame(size=1; request=3; stream=2; streamflags=; type=command-response; flags=continuation)
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
  received frame(size=11; request=1; stream=2; streamflags=stream-begin; type=command-response; flags=continuation)
  received frame(size=871; request=1; stream=2; streamflags=; type=command-response; flags=continuation)
  received frame(size=0; request=1; stream=2; streamflags=; type=command-response; flags=eos)
  add changeset 3390ef850073
  add changeset 4432d83626e8
  add changeset cd2534766bec
  add changeset e96ae20f4188
  add changeset caa2a465451d
  checking for updated bookmarks
  updating the branch cache
  new changesets 3390ef850073:caa2a465451d (3 drafts)

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
  

Cloning only a specific revision works

  $ hg --debug clone -U -r 4432d83626e8 http://localhost:$HGPORT client-singlehead
  using http://localhost:$HGPORT/
  sending capabilities command
  sending 1 commands
  sending command lookup: {
    'key': '4432d83626e8'
  }
  received frame(size=11; request=1; stream=2; streamflags=stream-begin; type=command-response; flags=continuation)
  received frame(size=21; request=1; stream=2; streamflags=; type=command-response; flags=continuation)
  received frame(size=0; request=1; stream=2; streamflags=; type=command-response; flags=eos)
  query 1; heads
  sending 2 commands
  sending command heads: {}
  sending command known: {
    'nodes': []
  }
  received frame(size=11; request=1; stream=2; streamflags=stream-begin; type=command-response; flags=continuation)
  received frame(size=43; request=1; stream=2; streamflags=; type=command-response; flags=continuation)
  received frame(size=0; request=1; stream=2; streamflags=; type=command-response; flags=eos)
  received frame(size=11; request=3; stream=2; streamflags=; type=command-response; flags=continuation)
  received frame(size=1; request=3; stream=2; streamflags=; type=command-response; flags=continuation)
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
  received frame(size=11; request=1; stream=2; streamflags=stream-begin; type=command-response; flags=continuation)
  received frame(size=353; request=1; stream=2; streamflags=; type=command-response; flags=continuation)
  received frame(size=0; request=1; stream=2; streamflags=; type=command-response; flags=eos)
  add changeset 3390ef850073
  add changeset 4432d83626e8
  checking for updated bookmarks
  updating the branch cache
  new changesets 3390ef850073:4432d83626e8

  $ cd client-singlehead

  $ hg log -G -T '{rev} {node} {phase}\n'
  o  1 4432d83626e8a98655f062ec1f2a43b07f7fbbb0 public
  |
  o  0 3390ef850073fbc2f0dfff2244342c8e9229013a public
  

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
  received frame(size=11; request=1; stream=2; streamflags=stream-begin; type=command-response; flags=continuation)
  received frame(size=43; request=1; stream=2; streamflags=; type=command-response; flags=continuation)
  received frame(size=0; request=1; stream=2; streamflags=; type=command-response; flags=eos)
  received frame(size=11; request=3; stream=2; streamflags=; type=command-response; flags=continuation)
  received frame(size=2; request=3; stream=2; streamflags=; type=command-response; flags=continuation)
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
  received frame(size=11; request=1; stream=2; streamflags=stream-begin; type=command-response; flags=continuation)
  received frame(size=571; request=1; stream=2; streamflags=; type=command-response; flags=continuation)
  received frame(size=0; request=1; stream=2; streamflags=; type=command-response; flags=eos)
  add changeset cd2534766bec
  add changeset e96ae20f4188
  add changeset caa2a465451d
  checking for updated bookmarks
  updating the branch cache
  new changesets cd2534766bec:caa2a465451d (3 drafts)
  (run 'hg update' to get a working copy)

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
  

Phase-only update works

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
  received frame(size=11; request=1; stream=2; streamflags=stream-begin; type=command-response; flags=continuation)
  received frame(size=43; request=1; stream=2; streamflags=; type=command-response; flags=continuation)
  received frame(size=0; request=1; stream=2; streamflags=; type=command-response; flags=eos)
  received frame(size=11; request=3; stream=2; streamflags=; type=command-response; flags=continuation)
  received frame(size=3; request=3; stream=2; streamflags=; type=command-response; flags=continuation)
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
  received frame(size=11; request=1; stream=2; streamflags=stream-begin; type=command-response; flags=continuation)
  received frame(size=92; request=1; stream=2; streamflags=; type=command-response; flags=continuation)
  received frame(size=0; request=1; stream=2; streamflags=; type=command-response; flags=eos)
  checking for updated bookmarks
  2 local changesets published
  (run 'hg update' to get a working copy)

  $ hg log -G -T '{rev} {node} {phase}\n'
  o  4 caa2a465451dd1facda0f5b12312c355584188a1 public
  |
  o  3 e96ae20f4188487b9ae4ef3941c27c81143146e5 public
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
  received frame(size=11; request=1; stream=2; streamflags=stream-begin; type=command-response; flags=continuation)
  received frame(size=43; request=1; stream=2; streamflags=; type=command-response; flags=continuation)
  received frame(size=0; request=1; stream=2; streamflags=; type=command-response; flags=eos)
  received frame(size=11; request=3; stream=2; streamflags=; type=command-response; flags=continuation)
  received frame(size=1; request=3; stream=2; streamflags=; type=command-response; flags=continuation)
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
  received frame(size=11; request=1; stream=2; streamflags=stream-begin; type=command-response; flags=continuation)
  received frame(size=909; request=1; stream=2; streamflags=; type=command-response; flags=continuation)
  received frame(size=0; request=1; stream=2; streamflags=; type=command-response; flags=eos)
  add changeset 3390ef850073
  add changeset 4432d83626e8
  add changeset cd2534766bec
  add changeset e96ae20f4188
  add changeset caa2a465451d
  checking for updated bookmarks
  adding remote bookmark book-1
  adding remote bookmark book-2
  updating the branch cache
  new changesets 3390ef850073:caa2a465451d (1 drafts)

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
  received frame(size=11; request=1; stream=2; streamflags=stream-begin; type=command-response; flags=continuation)
  received frame(size=43; request=1; stream=2; streamflags=; type=command-response; flags=continuation)
  received frame(size=0; request=1; stream=2; streamflags=; type=command-response; flags=eos)
  received frame(size=11; request=3; stream=2; streamflags=; type=command-response; flags=continuation)
  received frame(size=3; request=3; stream=2; streamflags=; type=command-response; flags=continuation)
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
  received frame(size=11; request=1; stream=2; streamflags=stream-begin; type=command-response; flags=continuation)
  received frame(size=144; request=1; stream=2; streamflags=; type=command-response; flags=continuation)
  received frame(size=0; request=1; stream=2; streamflags=; type=command-response; flags=eos)
  checking for updated bookmarks
  updating bookmark book-1
  (run 'hg update' to get a working copy)

  $ hg -R client-bookmarks bookmarks
     book-1                    2:cd2534766bec
     book-2                    2:cd2534766bec
