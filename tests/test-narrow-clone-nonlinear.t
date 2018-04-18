Testing narrow clones when changesets modifying a matching file exist on
multiple branches

  $ . "$TESTDIR/narrow-library.sh"

  $ hg init master
  $ cd master
  $ cat >> .hg/hgrc <<EOF
  > [narrow]
  > serveellipses=True
  > EOF

  $ hg branch default
  marked working directory as branch default
  (branches are permanent and global, did you want a bookmark?)
  $ for x in `$TESTDIR/seq.py 10`; do
  >   echo $x > "f$x"
  >   hg add "f$x"
  >   hg commit -m "Add $x"
  > done

  $ hg branch release-v1
  marked working directory as branch release-v1
  (branches are permanent and global, did you want a bookmark?)
  $ hg commit -m "Start release for v1"

  $ hg update default
  0 files updated, 0 files merged, 0 files removed, 0 files unresolved
  $ for x in `$TESTDIR/seq.py 10`; do
  >   echo "$x v2" > "f$x"
  >   hg commit -m "Update $x to v2"
  > done

  $ hg update release-v1
  10 files updated, 0 files merged, 0 files removed, 0 files unresolved
  $ hg branch release-v1
  marked working directory as branch release-v1
  $ for x in `$TESTDIR/seq.py 1 5`; do
  >   echo "$x v1 hotfix" > "f$x"
  >   hg commit -m "Hotfix $x in v1"
  > done

  $ hg update default
  10 files updated, 0 files merged, 0 files removed, 0 files unresolved
  $ hg branch release-v2
  marked working directory as branch release-v2
  $ hg commit -m "Start release for v2"

  $ hg update default
  0 files updated, 0 files merged, 0 files removed, 0 files unresolved
  $ hg branch default
  marked working directory as branch default
  $ for x in `$TESTDIR/seq.py 10`; do
  >   echo "$x v3" > "f$x"
  >   hg commit -m "Update $x to v3"
  > done

  $ hg update release-v2
  10 files updated, 0 files merged, 0 files removed, 0 files unresolved
  $ hg branch release-v2
  marked working directory as branch release-v2
  $ for x in `$TESTDIR/seq.py 4 9`; do
  >   echo "$x v2 hotfix" > "f$x"
  >   hg commit -m "Hotfix $x in v2"
  > done

  $ hg heads -T '{rev} <- {p1rev} ({branch}): {desc}\n'
  42 <- 41 (release-v2): Hotfix 9 in v2
  36 <- 35 (default): Update 10 to v3
  25 <- 24 (release-v1): Hotfix 5 in v1

  $ cd ..

We now have 3 branches: default, which has v3 of all files, release-v1 which
has v1 of all files, and release-v2 with v2 of all files.

Narrow clone which should get all branches

  $ hg clone --narrow ssh://user@dummy/master narrow --include "f5"
  requesting all changes
  adding changesets
  adding manifests
  adding file changes
  added 12 changesets with 5 changes to 1 files (+2 heads)
  new changesets *:* (glob)
  updating to branch default
  1 files updated, 0 files merged, 0 files removed, 0 files unresolved
  $ cd narrow
  $ hg log -G -T "{if(ellipsis, '...')}{node|short} ({branch}): {desc}\n"
  o  ...031f516143fe (release-v2): Hotfix 9 in v2
  |
  o  9cd7f7bb9ca1 (release-v2): Hotfix 5 in v2
  |
  o  ...37bbc88f3ef0 (release-v2): Hotfix 4 in v2
  |
  | @  ...dae2f368ca07 (default): Update 10 to v3
  | |
  | o  9c224e89cb31 (default): Update 5 to v3
  | |
  | o  ...04fb59c7c9dc (default): Update 4 to v3
  |/
  | o  b2253e82401f (release-v1): Hotfix 5 in v1
  | |
  | o  ...960ac37d74fd (release-v1): Hotfix 4 in v1
  | |
  o |  986298e3f347 (default): Update 5 to v2
  | |
  o |  ...75d539c667ec (default): Update 4 to v2
  |/
  o  04c71bd5707f (default): Add 5
  |
  o  ...881b3891d041 (default): Add 4
  

Narrow clone the first file, hitting edge condition where unaligned
changeset and manifest revnums cross branches.

  $ hg clone --narrow ssh://user@dummy/master narrow --include "f1"
  requesting all changes
  adding changesets
  adding manifests
  adding file changes
  added 10 changesets with 4 changes to 1 files (+2 heads)
  new changesets *:* (glob)
  updating to branch default
  1 files updated, 0 files merged, 0 files removed, 0 files unresolved
  $ cd narrow
  $ hg log -G -T "{if(ellipsis, '...')}{node|short} ({branch}): {desc}\n"
  o  ...031f516143fe (release-v2): Hotfix 9 in v2
  |
  | @  ...dae2f368ca07 (default): Update 10 to v3
  | |
  | o  1f5d184b8e96 (default): Update 1 to v3
  |/
  | o  ...b2253e82401f (release-v1): Hotfix 5 in v1
  | |
  | o  133502f6b7e5 (release-v1): Hotfix 1 in v1
  | |
  o |  ...79165c83d644 (default): Update 10 to v2
  | |
  o |  c7b7a5f2f088 (default): Update 1 to v2
  | |
  | o  ...f0531a3db7a9 (release-v1): Start release for v1
  |/
  o  ...6a3f0f0abef3 (default): Add 10
  |
  o  e012ac15eaaa (default): Add 1
  
