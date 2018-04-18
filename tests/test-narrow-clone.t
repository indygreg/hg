  $ . "$TESTDIR/narrow-library.sh"

  $ hg init master
  $ cd master
  $ cat >> .hg/hgrc <<EOF
  > [narrow]
  > serveellipses=True
  > EOF
  $ mkdir dir
  $ mkdir dir/src
  $ cd dir/src
  $ for x in `$TESTDIR/seq.py 20`; do echo $x > "f$x"; hg add "f$x"; hg commit -m "Commit src $x"; done
  $ cd ..
  $ mkdir tests
  $ cd tests
  $ for x in `$TESTDIR/seq.py 20`; do echo $x > "t$x"; hg add "t$x"; hg commit -m "Commit test $x"; done
  $ cd ../../..

narrow clone a file, f10

  $ hg clone --narrow ssh://user@dummy/master narrow --noupdate --include "dir/src/f10"
  requesting all changes
  adding changesets
  adding manifests
  adding file changes
  added 3 changesets with 1 changes to 1 files
  new changesets *:* (glob)
  $ cd narrow
  $ cat .hg/requires | grep -v generaldelta
  dotencode
  fncache
  narrowhg-experimental
  revlogv1
  store
  testonly-simplestore (reposimplestore !)

  $ cat .hg/narrowspec
  [includes]
  path:dir/src/f10
  [excludes]
  $ hg tracked
  I path:dir/src/f10
  $ hg update
  1 files updated, 0 files merged, 0 files removed, 0 files unresolved
  $ find * | sort
  dir
  dir/src
  dir/src/f10
  $ cat dir/src/f10
  10

  $ cd ..

narrow clone with a newline should fail

  $ hg clone --narrow ssh://user@dummy/master narrow_fail --noupdate --include 'dir/src/f10
  > '
  requesting all changes
  abort: newlines are not allowed in narrowspec paths
  [255]

narrow clone a directory, tests/, except tests/t19

  $ hg clone --narrow ssh://user@dummy/master narrowdir --noupdate --include "dir/tests/" --exclude "dir/tests/t19"
  requesting all changes
  adding changesets
  adding manifests
  adding file changes
  added 21 changesets with 19 changes to 19 files
  new changesets *:* (glob)
  $ cd narrowdir
  $ cat .hg/narrowspec
  [includes]
  path:dir/tests
  [excludes]
  path:dir/tests/t19
  $ hg tracked
  I path:dir/tests
  X path:dir/tests/t19
  $ hg update
  19 files updated, 0 files merged, 0 files removed, 0 files unresolved
  $ find * | sort
  dir
  dir/tests
  dir/tests/t1
  dir/tests/t10
  dir/tests/t11
  dir/tests/t12
  dir/tests/t13
  dir/tests/t14
  dir/tests/t15
  dir/tests/t16
  dir/tests/t17
  dir/tests/t18
  dir/tests/t2
  dir/tests/t20
  dir/tests/t3
  dir/tests/t4
  dir/tests/t5
  dir/tests/t6
  dir/tests/t7
  dir/tests/t8
  dir/tests/t9

  $ cd ..

narrow clone everything but a directory (tests/)

  $ hg clone --narrow ssh://user@dummy/master narrowroot --noupdate --exclude "dir/tests"
  requesting all changes
  adding changesets
  adding manifests
  adding file changes
  added 21 changesets with 20 changes to 20 files
  new changesets *:* (glob)
  $ cd narrowroot
  $ cat .hg/narrowspec
  [includes]
  path:.
  [excludes]
  path:dir/tests
  $ hg tracked
  I path:.
  X path:dir/tests
  $ hg update
  20 files updated, 0 files merged, 0 files removed, 0 files unresolved
  $ find * | sort
  dir
  dir/src
  dir/src/f1
  dir/src/f10
  dir/src/f11
  dir/src/f12
  dir/src/f13
  dir/src/f14
  dir/src/f15
  dir/src/f16
  dir/src/f17
  dir/src/f18
  dir/src/f19
  dir/src/f2
  dir/src/f20
  dir/src/f3
  dir/src/f4
  dir/src/f5
  dir/src/f6
  dir/src/f7
  dir/src/f8
  dir/src/f9

  $ cd ..

narrow clone no paths at all

  $ hg clone --narrow ssh://user@dummy/master narrowempty --noupdate
  requesting all changes
  adding changesets
  adding manifests
  adding file changes
  added 1 changesets with 0 changes to 0 files
  new changesets * (glob)
  $ cd narrowempty
  $ hg tracked
  $ hg update
  0 files updated, 0 files merged, 0 files removed, 0 files unresolved
  $ ls

  $ cd ..

simple clone
  $ hg clone ssh://user@dummy/master simpleclone
  requesting all changes
  adding changesets
  adding manifests
  adding file changes
  added 40 changesets with 40 changes to 40 files
  new changesets * (glob)
  updating to branch default
  40 files updated, 0 files merged, 0 files removed, 0 files unresolved
  $ cd simpleclone
  $ find * | sort
  dir
  dir/src
  dir/src/f1
  dir/src/f10
  dir/src/f11
  dir/src/f12
  dir/src/f13
  dir/src/f14
  dir/src/f15
  dir/src/f16
  dir/src/f17
  dir/src/f18
  dir/src/f19
  dir/src/f2
  dir/src/f20
  dir/src/f3
  dir/src/f4
  dir/src/f5
  dir/src/f6
  dir/src/f7
  dir/src/f8
  dir/src/f9
  dir/tests
  dir/tests/t1
  dir/tests/t10
  dir/tests/t11
  dir/tests/t12
  dir/tests/t13
  dir/tests/t14
  dir/tests/t15
  dir/tests/t16
  dir/tests/t17
  dir/tests/t18
  dir/tests/t19
  dir/tests/t2
  dir/tests/t20
  dir/tests/t3
  dir/tests/t4
  dir/tests/t5
  dir/tests/t6
  dir/tests/t7
  dir/tests/t8
  dir/tests/t9

  $ cd ..
