#require no-reposimplestore

  $ . "$TESTDIR/narrow-library.sh"

  $ hg init master
  $ cd master
  $ cat >> .hg/hgrc <<EOF
  > [narrow]
  > serveellipses=True
  > EOF
  $ for x in `$TESTDIR/seq.py 10`
  > do
  >   echo $x > "f$x"
  >   hg add "f$x"
  > done
  $ hg commit -m "Add root files"
  $ mkdir d1 d2
  $ for x in `$TESTDIR/seq.py 10`
  > do
  >   echo d1/$x > "d1/f$x"
  >   hg add "d1/f$x"
  >   echo d2/$x > "d2/f$x"
  >   hg add "d2/f$x"
  > done
  $ hg commit -m "Add d1 and d2"
  $ for x in `$TESTDIR/seq.py 10`
  > do
  >   echo f$x rev2 > "f$x"
  >   echo d1/f$x rev2 > "d1/f$x"
  >   echo d2/f$x rev2 > "d2/f$x"
  >   hg commit -m "Commit rev2 of f$x, d1/f$x, d2/f$x"
  > done
  $ cd ..

narrow and shallow clone the d2 directory

  $ hg clone --narrow ssh://user@dummy/master shallow --include "d2" --depth 2
  requesting all changes
  adding changesets
  adding manifests
  adding file changes
  added 4 changesets with 13 changes to 10 files
  new changesets *:* (glob)
  updating to branch default
  10 files updated, 0 files merged, 0 files removed, 0 files unresolved
  $ cd shallow
  $ hg log -T '{rev}{if(ellipsis,"...")}: {desc}\n'
  3: Commit rev2 of f10, d1/f10, d2/f10
  2: Commit rev2 of f9, d1/f9, d2/f9
  1: Commit rev2 of f8, d1/f8, d2/f8
  0...: Commit rev2 of f7, d1/f7, d2/f7
  $ hg update 0
  3 files updated, 0 files merged, 0 files removed, 0 files unresolved
  $ cat d2/f7 d2/f8
  d2/f7 rev2
  d2/8

  $ cd ..

change every upstream file once

  $ cd master
  $ for x in `$TESTDIR/seq.py 10`
  > do
  >   echo f$x rev3 > "f$x"
  >   echo d1/f$x rev3 > "d1/f$x"
  >   echo d2/f$x rev3 > "d2/f$x"
  >   hg commit -m "Commit rev3 of f$x, d1/f$x, d2/f$x"
  > done
  $ cd ..

pull new changes with --depth specified. There were 10 changes to the d2
directory but the shallow pull should only fetch 3.

  $ cd shallow
  $ hg pull --depth 2
  pulling from ssh://user@dummy/master
  searching for changes
  adding changesets
  adding manifests
  adding file changes
  added 4 changesets with 10 changes to 10 files
  new changesets *:* (glob)
  (run 'hg update' to get a working copy)
  $ hg log -T '{rev}{if(ellipsis,"...")}: {desc}\n'
  7: Commit rev3 of f10, d1/f10, d2/f10
  6: Commit rev3 of f9, d1/f9, d2/f9
  5: Commit rev3 of f8, d1/f8, d2/f8
  4...: Commit rev3 of f7, d1/f7, d2/f7
  3: Commit rev2 of f10, d1/f10, d2/f10
  2: Commit rev2 of f9, d1/f9, d2/f9
  1: Commit rev2 of f8, d1/f8, d2/f8
  0...: Commit rev2 of f7, d1/f7, d2/f7
  $ hg update 4
  merging d2/f1
  merging d2/f2
  merging d2/f3
  merging d2/f4
  merging d2/f5
  merging d2/f6
  merging d2/f7
  3 files updated, 7 files merged, 0 files removed, 0 files unresolved
  $ cat d2/f7 d2/f8
  d2/f7 rev3
  d2/f8 rev2
  $ hg update 7
  3 files updated, 0 files merged, 0 files removed, 0 files unresolved
  $ cat d2/f10
  d2/f10 rev3

  $ cd ..

cannot clone with zero or negative depth

  $ hg clone --narrow ssh://user@dummy/master bad --include "d2" --depth 0
  requesting all changes
  remote: abort: depth must be positive, got 0
  abort: pull failed on remote
  [255]
  $ hg clone --narrow ssh://user@dummy/master bad --include "d2" --depth -1
  requesting all changes
  remote: abort: depth must be positive, got -1
  abort: pull failed on remote
  [255]
