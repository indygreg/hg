
  $ . "$TESTDIR/narrow-library.sh"

create full repo

  $ hg init master
  $ cd master
  $ echo init > init
  $ hg ci -Aqm 'initial'

  $ mkdir inside
  $ echo inside > inside/f1
  $ mkdir outside
  $ echo outside > outside/f1
  $ hg ci -Aqm 'add inside and outside'

  $ echo modified > inside/f1
  $ hg ci -qm 'modify inside'

  $ echo modified > outside/f1
  $ hg ci -qm 'modify outside'

  $ cd ..

  $ hg clone --narrow ssh://user@dummy/master narrow --include inside
  requesting all changes
  adding changesets
  adding manifests
  adding file changes
  added 4 changesets with 2 changes to 1 files
  new changesets *:* (glob)
  updating to branch default
  1 files updated, 0 files merged, 0 files removed, 0 files unresolved
  $ cd narrow
  $ hg debugindex -c
     rev linkrev nodeid       p1           p2
       0       0 9958b1af2add 000000000000 000000000000
       1       1 2db4ce2a3bfe 9958b1af2add 000000000000
       2       2 0980ee31a742 2db4ce2a3bfe 000000000000
       3       3 4410145019b7 0980ee31a742 000000000000

  $ hg update -q 0

Can update to revision with changes inside

  $ hg update -q 'desc("add inside and outside")'
  $ hg update -q 'desc("modify inside")'
  $ find *
  inside
  inside/f1
  $ cat inside/f1
  modified

Can update to revision with changes outside

  $ hg update -q 'desc("modify outside")'
  $ find *
  inside
  inside/f1
  $ cat inside/f1
  modified

Can update with a deleted file inside

  $ hg rm inside/f1
  $ hg update -q 'desc("modify inside")'
  $ hg update -q 'desc("modify outside")'
  $ hg update -q 'desc("initial")'
  $ hg update -q 'desc("modify inside")'

Can update with a moved file inside

  $ hg mv inside/f1 inside/f2
  $ hg update -q 'desc("modify outside")'
  $ hg update -q 'desc("initial")'
  $ hg update -q 'desc("modify inside")'
