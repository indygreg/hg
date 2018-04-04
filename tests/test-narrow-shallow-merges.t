#require no-reposimplestore

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
  

Now narrow and shallow clone this and get a hopefully correct graph

  $ cd ..
  $ hg clone --narrow ssh://user@dummy/master narrow --include inside --depth 7
  requesting all changes
  adding changesets
  adding manifests
  adding file changes
  added 8 changesets with 3 changes to 1 files
  new changesets *:* (glob)
  updating to branch default
  1 files updated, 0 files merged, 0 files removed, 0 files unresolved
  $ cd narrow

To make updating the tests easier, we print the emitted nodes
sorted. This makes it easier to identify when the same node structure
has been emitted, just in a different order.

  $ hg log -G -T '{rev} {node|short}{if(ellipsis,"...")} {desc}\n'
  @  7 8d874d57adea... outside 12
  |
  o  6 7ef88b4dd4fa inside 11
  |
  o  5 2a20009de83e... outside 10
  |
  o    4 3ac1f5779de3... merge a/b/c/d 9
  |\
  | o  3 465567bdfb2d inside 3
  | |
  | o  2 d1c61993ec83... outside 2d
  |
  o  1 bb96a08b062a inside 3
  |
  o  0 b844052e7b3b... outside 2c
  

  $ hg log -T '{if(ellipsis,"...")}{node|short} {p1node|short} {p2node|short} {desc}\n' | sort
  ...2a20009de83e 000000000000 3ac1f5779de3 outside 10
  ...3ac1f5779de3 bb96a08b062a 465567bdfb2d merge a/b/c/d 9
  ...8d874d57adea 7ef88b4dd4fa 000000000000 outside 12
  ...b844052e7b3b 000000000000 000000000000 outside 2c
  ...d1c61993ec83 000000000000 000000000000 outside 2d
  465567bdfb2d d1c61993ec83 000000000000 inside 3
  7ef88b4dd4fa 2a20009de83e 000000000000 inside 11
  bb96a08b062a b844052e7b3b 000000000000 inside 3

  $ cd ..

Incremental test case: show a pull can pull in a conflicted merge even if elided

  $ hg init pullmaster
  $ cd pullmaster
  $ cat >> .hg/hgrc <<EOF
  > [narrow]
  > serveellipses=True
  > EOF
  $ mkdir inside outside
  $ echo v1 > inside/f
  $ echo v1 > outside/f
  $ hg add inside/f outside/f
  $ hg commit -m init

  $ for line in a b c d
  > do
  > hg update -r 0
  > echo v2$line > outside/f
  > hg commit -m "outside 2$line"
  > echo v2$line > inside/f
  > hg commit -m "inside 2$line"
  > echo v3$line > outside/f
  > hg commit -m "outside 3$line"
  > echo v4$line > outside/f
  > hg commit -m "outside 4$line"
  > done
  0 files updated, 0 files merged, 0 files removed, 0 files unresolved
  2 files updated, 0 files merged, 0 files removed, 0 files unresolved
  created new head
  2 files updated, 0 files merged, 0 files removed, 0 files unresolved
  created new head
  2 files updated, 0 files merged, 0 files removed, 0 files unresolved
  created new head

  $ cd ..
  $ hg clone --narrow ssh://user@dummy/pullmaster pullshallow \
  >          --include inside --depth 3
  requesting all changes
  adding changesets
  adding manifests
  adding file changes
  added 12 changesets with 5 changes to 1 files (+3 heads)
  new changesets *:* (glob)
  updating to branch default
  1 files updated, 0 files merged, 0 files removed, 0 files unresolved
  $ cd pullshallow

  $ hg log -G -T '{rev} {node|short}{if(ellipsis,"...")} {desc}\n'
  @  11 0ebbd712a0c8... outside 4d
  |
  o  10 0d4c867aeb23 inside 2d
  |
  o  9 e932969c3961... outside 2d
  
  o  8 33d530345455... outside 4c
  |
  o  7 0ce6481bfe07 inside 2c
  |
  o  6 caa65c940632... outside 2c
  
  o  5 3df233defecc... outside 4b
  |
  o  4 7162cc6d11a4 inside 2b
  |
  o  3 f2a632f0082d... outside 2b
  
  o  2 b8a3da16ba49... outside 4a
  |
  o  1 53f543eb8e45 inside 2a
  |
  o  0 1be3e5221c6a... outside 2a
  
  $ hg log -T '{if(ellipsis,"...")}{node|short} {p1node|short} {p2node|short} {desc}\n' | sort
  ...0ebbd712a0c8 0d4c867aeb23 000000000000 outside 4d
  ...1be3e5221c6a 000000000000 000000000000 outside 2a
  ...33d530345455 0ce6481bfe07 000000000000 outside 4c
  ...3df233defecc 7162cc6d11a4 000000000000 outside 4b
  ...b8a3da16ba49 53f543eb8e45 000000000000 outside 4a
  ...caa65c940632 000000000000 000000000000 outside 2c
  ...e932969c3961 000000000000 000000000000 outside 2d
  ...f2a632f0082d 000000000000 000000000000 outside 2b
  0ce6481bfe07 caa65c940632 000000000000 inside 2c
  0d4c867aeb23 e932969c3961 000000000000 inside 2d
  53f543eb8e45 1be3e5221c6a 000000000000 inside 2a
  7162cc6d11a4 f2a632f0082d 000000000000 inside 2b

  $ cd ../pullmaster
  $ hg update -r 'desc("outside 4a")'
  2 files updated, 0 files merged, 0 files removed, 0 files unresolved
  $ hg merge -r 'desc("outside 4b")' 2>&1 | egrep -v '(warning:|incomplete!)'
  merging inside/f
  merging outside/f
  0 files updated, 0 files merged, 0 files removed, 2 files unresolved
  use 'hg resolve' to retry unresolved file merges or 'hg merge --abort' to abandon
  $ echo 3 > inside/f
  $ echo 5 > outside/f
  $ rm -f {in,out}side/f.orig
  $ hg resolve --mark inside/f outside/f
  (no more unresolved files)
  $ hg commit -m 'merge a/b 5'

  $ hg update -r 'desc("outside 4c")'
  2 files updated, 0 files merged, 0 files removed, 0 files unresolved
  $ hg merge -r 'desc("outside 4d")' 2>&1 | egrep -v '(warning:|incomplete!)'
  merging inside/f
  merging outside/f
  0 files updated, 0 files merged, 0 files removed, 2 files unresolved
  use 'hg resolve' to retry unresolved file merges or 'hg merge --abort' to abandon
  $ echo 3 > inside/f
  $ echo 5 > outside/f
  $ rm -f {in,out}side/f.orig
  $ hg resolve --mark inside/f outside/f
  (no more unresolved files)
  $ hg commit -m 'merge c/d 5'

  $ hg update -r 'desc("merge a/b 5")'
  2 files updated, 0 files merged, 0 files removed, 0 files unresolved
  $ hg merge -r 'desc("merge c/d 5")'
  2 files updated, 0 files merged, 0 files removed, 0 files unresolved
  (branch merge, don't forget to commit)
  $ echo 6 > outside/f
  $ hg commit -m 'outside 6'
  $ echo 7 > outside/f
  $ hg commit -m 'outside 7'
  $ echo 8 > outside/f
  $ hg commit -m 'outside 8'

  $ cd ../pullshallow
  $ hg pull --depth 3
  pulling from ssh://user@dummy/pullmaster
  searching for changes
  adding changesets
  adding manifests
  adding file changes
  added 4 changesets with 3 changes to 1 files (-3 heads)
  new changesets *:* (glob)
  (run 'hg update' to get a working copy)

  $ hg log -T '{if(ellipsis,"...")}{node|short} {p1node|short} {p2node|short} {desc}\n' | sort
  ...0ebbd712a0c8 0d4c867aeb23 000000000000 outside 4d
  ...1be3e5221c6a 000000000000 000000000000 outside 2a
  ...33d530345455 0ce6481bfe07 000000000000 outside 4c
  ...3df233defecc 7162cc6d11a4 000000000000 outside 4b
  ...b8a3da16ba49 53f543eb8e45 000000000000 outside 4a
  ...bf545653453e 968003d40c60 000000000000 outside 8
  ...caa65c940632 000000000000 000000000000 outside 2c
  ...e932969c3961 000000000000 000000000000 outside 2d
  ...f2a632f0082d 000000000000 000000000000 outside 2b
  0ce6481bfe07 caa65c940632 000000000000 inside 2c
  0d4c867aeb23 e932969c3961 000000000000 inside 2d
  53f543eb8e45 1be3e5221c6a 000000000000 inside 2a
  67d49c0bdbda b8a3da16ba49 3df233defecc merge a/b 5
  7162cc6d11a4 f2a632f0082d 000000000000 inside 2b
  968003d40c60 67d49c0bdbda e867021d52c2 outside 6
  e867021d52c2 33d530345455 0ebbd712a0c8 merge c/d 5
