
  $ . "$TESTDIR/narrow-library.sh"

create full repo

  $ hg init master
  $ cd master
  $ cat >> .hg/hgrc <<EOF
  > [narrow]
  > serveellipses=True
  > EOF

  $ mkdir inside
  $ echo 1 > inside/f
  $ hg commit -Aqm 'initial inside'

  $ mkdir outside
  $ echo 1 > outside/f
  $ hg commit -Aqm 'initial outside'

  $ echo 2a > outside/f
  $ hg commit -Aqm 'outside 2a'
  $ echo 3 > inside/f
  $ hg commit -Aqm 'inside 3'
  $ echo 4a > outside/f
  $ hg commit -Aqm 'outside 4a'
  $ hg update '.~3'
  2 files updated, 0 files merged, 0 files removed, 0 files unresolved

  $ echo 2b > outside/f
  $ hg commit -Aqm 'outside 2b'
  $ echo 3 > inside/f
  $ hg commit -Aqm 'inside 3'
  $ echo 4b > outside/f
  $ hg commit -Aqm 'outside 4b'
  $ hg update '.~3'
  2 files updated, 0 files merged, 0 files removed, 0 files unresolved

  $ echo 2c > outside/f
  $ hg commit -Aqm 'outside 2c'
  $ echo 3 > inside/f
  $ hg commit -Aqm 'inside 3'
  $ echo 4c > outside/f
  $ hg commit -Aqm 'outside 4c'
  $ hg update '.~3'
  2 files updated, 0 files merged, 0 files removed, 0 files unresolved

  $ echo 2d > outside/f
  $ hg commit -Aqm 'outside 2d'
  $ echo 3 > inside/f
  $ hg commit -Aqm 'inside 3'
  $ echo 4d > outside/f
  $ hg commit -Aqm 'outside 4d'

  $ hg update -r 'desc("outside 4a")'
  1 files updated, 0 files merged, 0 files removed, 0 files unresolved
  $ hg merge -r 'desc("outside 4b")' 2>&1 | egrep -v '(warning:|incomplete!)'
  merging outside/f
  0 files updated, 0 files merged, 0 files removed, 1 files unresolved
  use 'hg resolve' to retry unresolved file merges or 'hg merge --abort' to abandon
  $ echo 5 > outside/f
  $ rm outside/f.orig
  $ hg resolve --mark outside/f
  (no more unresolved files)
  $ hg commit -m 'merge a/b 5'
  $ echo 6 > outside/f
  $ hg commit -Aqm 'outside 6'

  $ hg merge -r 'desc("outside 4c")' 2>&1 | egrep -v '(warning:|incomplete!)'
  merging outside/f
  0 files updated, 0 files merged, 0 files removed, 1 files unresolved
  use 'hg resolve' to retry unresolved file merges or 'hg merge --abort' to abandon
  $ echo 7 > outside/f
  $ rm outside/f.orig
  $ hg resolve --mark outside/f
  (no more unresolved files)
  $ hg commit -Aqm 'merge a/b/c 7'
  $ echo 8 > outside/f
  $ hg commit -Aqm 'outside 8'

  $ hg merge -r 'desc("outside 4d")' 2>&1 | egrep -v '(warning:|incomplete!)'
  merging outside/f
  0 files updated, 0 files merged, 0 files removed, 1 files unresolved
  use 'hg resolve' to retry unresolved file merges or 'hg merge --abort' to abandon
  $ echo 9 > outside/f
  $ rm outside/f.orig
  $ hg resolve --mark outside/f
  (no more unresolved files)
  $ hg commit -Aqm 'merge a/b/c/d 9'
  $ echo 10 > outside/f
  $ hg commit -Aqm 'outside 10'

  $ echo 11 > inside/f
  $ hg commit -Aqm 'inside 11'
  $ echo 12 > outside/f
  $ hg commit -Aqm 'outside 12'

  $ hg log -G -T '{rev} {node|short} {desc}\n'
  @  21 8d874d57adea outside 12
  |
  o  20 7ef88b4dd4fa inside 11
  |
  o  19 2a20009de83e outside 10
  |
  o    18 3ac1f5779de3 merge a/b/c/d 9
  |\
  | o  17 38a9c2f7e546 outside 8
  | |
  | o    16 094aa62fc898 merge a/b/c 7
  | |\
  | | o  15 f29d083d32e4 outside 6
  | | |
  | | o    14 2dc11382541d merge a/b 5
  | | |\
  o | | |  13 27d07ef97221 outside 4d
  | | | |
  o | | |  12 465567bdfb2d inside 3
  | | | |
  o | | |  11 d1c61993ec83 outside 2d
  | | | |
  | o | |  10 56859a8e33b9 outside 4c
  | | | |
  | o | |  9 bb96a08b062a inside 3
  | | | |
  | o | |  8 b844052e7b3b outside 2c
  |/ / /
  | | o  7 9db2d8fcc2a6 outside 4b
  | | |
  | | o  6 6418167787a6 inside 3
  | | |
  +---o  5 77344f344d83 outside 2b
  | |
  | o  4 9cadde08dc9f outside 4a
  | |
  | o  3 019ef06f125b inside 3
  | |
  | o  2 75e40c075a19 outside 2a
  |/
  o  1 906d6c682641 initial outside
  |
  o  0 9f8e82b51004 initial inside
  

Now narrow clone this and get a hopefully correct graph

  $ cd ..
  $ hg clone --narrow ssh://user@dummy/master narrow --include inside
  requesting all changes
  adding changesets
  adding manifests
  adding file changes
  added 14 changesets with 3 changes to 1 files
  new changesets *:* (glob)
  updating to branch default
  1 files updated, 0 files merged, 0 files removed, 0 files unresolved
  $ cd narrow

To make updating the tests easier, we print the emitted nodes
sorted. This makes it easier to identify when the same node structure
has been emitted, just in a different order.

  $ hg log -T '{if(ellipsis,"...")}{node|short} {p1node|short} {p2node|short} {desc}\n' | sort
  ...094aa62fc898 6418167787a6 bb96a08b062a merge a/b/c 7
  ...2a20009de83e 019ef06f125b 3ac1f5779de3 outside 10
  ...3ac1f5779de3 465567bdfb2d 094aa62fc898 merge a/b/c/d 9
  ...75e40c075a19 9f8e82b51004 000000000000 outside 2a
  ...77344f344d83 9f8e82b51004 000000000000 outside 2b
  ...8d874d57adea 7ef88b4dd4fa 000000000000 outside 12
  ...b844052e7b3b 9f8e82b51004 000000000000 outside 2c
  ...d1c61993ec83 9f8e82b51004 000000000000 outside 2d
  019ef06f125b 75e40c075a19 000000000000 inside 3
  465567bdfb2d d1c61993ec83 000000000000 inside 3
  6418167787a6 77344f344d83 000000000000 inside 3
  7ef88b4dd4fa 2a20009de83e 000000000000 inside 11
  9f8e82b51004 000000000000 000000000000 initial inside
  bb96a08b062a b844052e7b3b 000000000000 inside 3

But seeing the graph is also nice:
  $ hg log -G -T '{if(ellipsis,"...")}{node|short} {desc}\n'
  @  ...8d874d57adea outside 12
  |
  o  7ef88b4dd4fa inside 11
  |
  o    ...2a20009de83e outside 10
  |\
  | o    ...3ac1f5779de3 merge a/b/c/d 9
  | |\
  | | o    ...094aa62fc898 merge a/b/c 7
  | | |\
  | o | |  465567bdfb2d inside 3
  | | | |
  | o | |  ...d1c61993ec83 outside 2d
  | | | |
  | | | o  bb96a08b062a inside 3
  | | | |
  | +---o  ...b844052e7b3b outside 2c
  | | |
  | | o  6418167787a6 inside 3
  | | |
  | | o  ...77344f344d83 outside 2b
  | |/
  o |  019ef06f125b inside 3
  | |
  o |  ...75e40c075a19 outside 2a
  |/
  o  9f8e82b51004 initial inside
  
