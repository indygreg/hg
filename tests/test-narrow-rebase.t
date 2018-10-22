
  $ . "$TESTDIR/narrow-library.sh"

create full repo

  $ hg init master
  $ cd master

  $ mkdir inside
  $ echo inside1 > inside/f1
  $ echo inside2 > inside/f2
  $ mkdir outside
  $ echo outside1 > outside/f1
  $ echo outside2 > outside/f2
  $ hg ci -Aqm 'initial'

  $ echo modified > inside/f1
  $ hg ci -qm 'modify inside/f1'

  $ hg update -q 0
  $ echo modified2 > inside/f2
  $ hg ci -qm 'modify inside/f2'

  $ hg update -q 0
  $ echo modified > outside/f1
  $ hg ci -qm 'modify outside/f1'

  $ hg update -q 0
  $ echo modified2 > outside/f1
  $ hg ci -qm 'conflicting outside/f1'

  $ cd ..

  $ hg clone --narrow ssh://user@dummy/master narrow --include inside
  requesting all changes
  adding changesets
  adding manifests
  adding file changes
  added 5 changesets with 4 changes to 2 files (+3 heads)
  new changesets *:* (glob)
  updating to branch default
  2 files updated, 0 files merged, 0 files removed, 0 files unresolved
  $ cd narrow
  $ cat >> $HGRCPATH <<EOF
  > [extensions]
  > rebase=
  > EOF

  $ hg update -q 0

Can rebase onto commit where no files outside narrow spec are involved

  $ hg update -q 0
  $ echo modified > inside/f2
  $ hg ci -qm 'modify inside/f2'
  $ hg rebase -d 'desc("modify inside/f1")'
  rebasing 5:c2f36d04e05d "modify inside/f2" (tip)
  saved backup bundle to $TESTTMP/narrow/.hg/strip-backup/*-rebase.hg (glob)

Can rebase onto conflicting changes inside narrow spec

  $ hg update -q 0
  $ echo conflicting > inside/f1
  $ hg ci -qm 'conflicting inside/f1'
  $ hg rebase -d 'desc("modify inside/f1")' 2>&1 | egrep -v '(warning:|incomplete!)'
  rebasing 6:cdce97fbf653 "conflicting inside/f1" (tip)
  merging inside/f1
  unresolved conflicts (see hg resolve, then hg rebase --continue)
  $ echo modified3 > inside/f1
  $ hg resolve -m 2>&1 | grep -v continue:
  (no more unresolved files)
  $ hg rebase --continue
  rebasing 6:cdce97fbf653 "conflicting inside/f1" (tip)
  saved backup bundle to $TESTTMP/narrow/.hg/strip-backup/*-rebase.hg (glob)

Can rebase onto non-conflicting changes outside narrow spec

  $ hg update -q 0
  $ echo modified > inside/f2
  $ hg ci -qm 'modify inside/f2'
  $ hg rebase -d 'desc("modify outside/f1")'
  rebasing 7:c2f36d04e05d "modify inside/f2" (tip)
  saved backup bundle to $TESTTMP/narrow/.hg/strip-backup/*-rebase.hg (glob)

Rebase interrupts on conflicting changes outside narrow spec

  $ hg update -q 'desc("conflicting outside/f1")'
  $ hg phase -f -d .
  $ hg rebase -d 'desc("modify outside/f1")'
  rebasing 4:707c035aadb6 "conflicting outside/f1"
  abort: conflict in file 'outside/f1' is outside narrow clone
  [255]
