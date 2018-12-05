#testcases stripbased phasebased

  $ cat <<EOF >> $HGRCPATH
  > [extensions]
  > mq =
  > shelve =
  > [defaults]
  > diff = --nodates --git
  > qnew = --date '0 0'
  > [shelve]
  > maxbackups = 2
  > EOF

#if phasebased

  $ cat <<EOF >> $HGRCPATH
  > [format]
  > internal-phase = yes
  > EOF

#endif

shelve should leave dirstate clean (issue4055)

  $ hg init shelverebase
  $ cd shelverebase
  $ printf 'x\ny\n' > x
  $ echo z > z
  $ hg commit -Aqm xy
  $ echo z >> x
  $ hg commit -Aqm z
  $ hg up 5c4c67fb7dce
  1 files updated, 0 files merged, 0 files removed, 0 files unresolved
  $ printf 'a\nx\ny\nz\n' > x
  $ hg commit -Aqm xyz
  $ echo c >> z
  $ hg shelve
  shelved as default
  1 files updated, 0 files merged, 0 files removed, 0 files unresolved

  $ hg rebase -d 6c103be8f4e4 --config extensions.rebase=
  rebasing 2:323bfa07f744 "xyz"( \(tip\))? (re)
  merging x
  saved backup bundle to \$TESTTMP/shelverebase/.hg/strip-backup/323bfa07f744-(78114325|7ae538ef)-rebase.hg (re)
  $ hg unshelve
  unshelving change 'default'
  rebasing shelved changes
  $ hg status
  M z

  $ cd ..

shelve should only unshelve pending changes (issue4068)

  $ hg init onlypendingchanges
  $ cd onlypendingchanges
  $ touch a
  $ hg ci -Aqm a
  $ touch b
  $ hg ci -Aqm b
  $ hg up -q 3903775176ed
  $ touch c
  $ hg ci -Aqm c

  $ touch d
  $ hg add d
  $ hg shelve
  shelved as default
  0 files updated, 0 files merged, 1 files removed, 0 files unresolved
  $ hg up -q 0e067c57feba
  $ hg unshelve
  unshelving change 'default'
  rebasing shelved changes
  $ hg status
  A d

unshelve should work on an ancestor of the original commit

  $ hg shelve
  shelved as default
  0 files updated, 0 files merged, 1 files removed, 0 files unresolved
  $ hg up 3903775176ed
  0 files updated, 0 files merged, 1 files removed, 0 files unresolved
  $ hg unshelve
  unshelving change 'default'
  rebasing shelved changes
  $ hg status
  A d

test bug 4073 we need to enable obsolete markers for it

  $ cat >> $HGRCPATH << EOF
  > [experimental]
  > evolution.createmarkers=True
  > EOF
  $ hg shelve
  shelved as default
  0 files updated, 0 files merged, 1 files removed, 0 files unresolved
  $ hg debugobsolete `hg log -r 0e067c57feba -T '{node}'`
  obsoleted 1 changesets
  $ hg unshelve
  unshelving change 'default'

unshelve should leave unknown files alone (issue4113)

  $ echo e > e
  $ hg shelve
  shelved as default
  0 files updated, 0 files merged, 1 files removed, 0 files unresolved
  $ hg status
  ? e
  $ hg unshelve
  unshelving change 'default'
  $ hg status
  A d
  ? e
  $ cat e
  e

unshelve should keep a copy of unknown files

  $ hg add e
  $ hg shelve
  shelved as default
  0 files updated, 0 files merged, 2 files removed, 0 files unresolved
  $ echo z > e
  $ hg unshelve
  unshelving change 'default'
  $ cat e
  e
  $ cat e.orig
  z


unshelve and conflicts with tracked and untracked files

 preparing:

  $ rm *.orig
  $ hg ci -qm 'commit stuff'
  $ hg phase -p null:

 no other changes - no merge:

  $ echo f > f
  $ hg add f
  $ hg shelve
  shelved as default
  0 files updated, 0 files merged, 1 files removed, 0 files unresolved
  $ echo g > f
  $ hg unshelve
  unshelving change 'default'
  $ hg st
  A f
  ? f.orig
  $ cat f
  f
  $ cat f.orig
  g

 other uncommitted changes - merge:

  $ hg st
  A f
  ? f.orig
  $ hg shelve
  shelved as default
  0 files updated, 0 files merged, 1 files removed, 0 files unresolved
#if repobundlerepo
  $ hg log -G --template '{rev}  {desc|firstline}  {author}' -R bundle://.hg/shelved/default.hg -r 'bundle()' --hidden
  o  [48]  changes to: commit stuff  shelve@localhost (re)
  |
  ~
#endif
  $ hg log -G --template '{rev}  {desc|firstline}  {author}'
  @  [37]  commit stuff  test (re)
  |
  | o  2  c  test
  |/
  o  0  a  test
  
  $ mv f.orig f
  $ echo 1 > a
  $ hg unshelve --date '1073741824 0'
  unshelving change 'default'
  temporarily committing pending changes (restore with 'hg unshelve --abort')
  rebasing shelved changes
  merging f
  warning: conflicts while merging f! (edit, then use 'hg resolve --mark')
  unresolved conflicts (see 'hg resolve', then 'hg unshelve --continue')
  [1]

#if phasebased
  $ hg log -G --template '{rev}  {desc|firstline}  {author}  {date|isodate}'
  @  9  pending changes temporary commit  shelve@localhost  2004-01-10 13:37 +0000
  |
  | @  8  changes to: commit stuff  shelve@localhost  1970-01-01 00:00 +0000
  |/
  o  7  commit stuff  test  1970-01-01 00:00 +0000
  |
  | o  2  c  test  1970-01-01 00:00 +0000
  |/
  o  0  a  test  1970-01-01 00:00 +0000
  
#endif

#if stripbased
  $ hg log -G --template '{rev}  {desc|firstline}  {author}  {date|isodate}'
  @  5  changes to: commit stuff  shelve@localhost  1970-01-01 00:00 +0000
  |
  | @  4  pending changes temporary commit  shelve@localhost  2004-01-10 13:37 +0000
  |/
  o  3  commit stuff  test  1970-01-01 00:00 +0000
  |
  | o  2  c  test  1970-01-01 00:00 +0000
  |/
  o  0  a  test  1970-01-01 00:00 +0000
  
#endif

  $ hg st
  M f
  ? f.orig
  $ cat f
  <<<<<<< shelve:       d44eae5c3d33 - shelve: pending changes temporary commit
  g
  =======
  f
  >>>>>>> working-copy: aef214a5229c - shelve: changes to: commit stuff
  $ cat f.orig
  g
  $ hg unshelve --abort -t false
  tool option will be ignored
  unshelve of 'default' aborted
  $ hg st
  M a
  ? f.orig
  $ cat f.orig
  g
  $ hg unshelve
  unshelving change 'default'
  temporarily committing pending changes (restore with 'hg unshelve --abort')
  rebasing shelved changes
  $ hg st
  M a
  A f
  ? f.orig

 other committed changes - merge:

  $ hg shelve f
  shelved as default
  0 files updated, 0 files merged, 1 files removed, 0 files unresolved
  $ hg ci a -m 'intermediate other change'
  $ mv f.orig f
  $ hg unshelve
  unshelving change 'default'
  rebasing shelved changes
  merging f
  warning: conflicts while merging f! (edit, then use 'hg resolve --mark')
  unresolved conflicts (see 'hg resolve', then 'hg unshelve --continue')
  [1]
  $ hg st
  M f
  ? f.orig
  $ cat f
  <<<<<<< shelve:       6b563750f973 - test: intermediate other change
  g
  =======
  f
  >>>>>>> working-copy: aef214a5229c - shelve: changes to: commit stuff
  $ cat f.orig
  g
  $ hg unshelve --abort
  unshelve of 'default' aborted
  $ hg st
  ? f.orig
  $ cat f.orig
  g
  $ hg shelve --delete default
  $ cd ..

you shouldn't be able to ask for the patch/stats of the most recent shelve if
there are no shelves

  $ hg init noshelves
  $ cd noshelves

  $ hg shelve --patch
  abort: there are no shelves to show
  [255]
  $ hg shelve --stat
  abort: there are no shelves to show
  [255]

  $ cd ..

test .orig files go where the user wants them to
---------------------------------------------------------------
  $ hg init salvage
  $ cd salvage
  $ echo 'content' > root
  $ hg commit -A -m 'root' -q
  $ echo '' > root
  $ hg shelve -q
  $ echo 'contADDent' > root
  $ hg unshelve -q --config 'ui.origbackuppath=.hg/origbackups'
  warning: conflicts while merging root! (edit, then use 'hg resolve --mark')
  unresolved conflicts (see 'hg resolve', then 'hg unshelve --continue')
  [1]
  $ ls .hg/origbackups
  root
  $ rm -rf .hg/origbackups

test Abort unshelve always gets user out of the unshelved state
---------------------------------------------------------------

with a corrupted shelve state file
  $ sed 's/ae8c668541e8/123456789012/' .hg/shelvedstate > ../corrupt-shelvedstate
  $ mv ../corrupt-shelvedstate .hg/shelvestate
  $ hg unshelve --abort 2>&1 | grep 'aborted'
  unshelve of 'default' aborted
  $ hg summary
  parent: 0:ae8c668541e8 tip
   root
  branch: default
  commit: 1 modified
  update: (current)
  phases: 1 draft
  $ hg up -C .
  1 files updated, 0 files merged, 0 files removed, 0 files unresolved

  $ cd ..

Shelve and unshelve unknown files. For the purposes of unshelve, a shelved
unknown file is the same as a shelved added file, except that it will be in
unknown state after unshelve if and only if it was either absent or unknown
before the unshelve operation.

  $ hg init unknowns
  $ cd unknowns

The simplest case is if I simply have an unknown file that I shelve and unshelve

  $ echo unknown > unknown
  $ hg status
  ? unknown
  $ hg shelve --unknown
  shelved as default
  0 files updated, 0 files merged, 1 files removed, 0 files unresolved
  $ hg status
  $ hg unshelve
  unshelving change 'default'
  $ hg status
  ? unknown
  $ rm unknown

If I shelve, add the file, and unshelve, does it stay added?

  $ echo unknown > unknown
  $ hg shelve -u
  shelved as default
  0 files updated, 0 files merged, 1 files removed, 0 files unresolved
  $ hg status
  $ touch unknown
  $ hg add unknown
  $ hg status
  A unknown
  $ hg unshelve
  unshelving change 'default'
  temporarily committing pending changes (restore with 'hg unshelve --abort')
  rebasing shelved changes
  merging unknown
  $ hg status
  A unknown
  $ hg forget unknown
  $ rm unknown

And if I shelve, commit, then unshelve, does it become modified?

  $ echo unknown > unknown
  $ hg shelve -u
  shelved as default
  0 files updated, 0 files merged, 1 files removed, 0 files unresolved
  $ hg status
  $ touch unknown
  $ hg add unknown
  $ hg commit -qm "Add unknown"
  $ hg status
  $ hg unshelve
  unshelving change 'default'
  rebasing shelved changes
  merging unknown
  $ hg status
  M unknown
  $ hg remove --force unknown
  $ hg commit -qm "Remove unknown"

  $ cd ..

We expects that non-bare shelve keeps newly created branch in
working directory.

  $ hg init shelve-preserve-new-branch
  $ cd shelve-preserve-new-branch
  $ echo "a" >> a
  $ hg add a
  $ echo "b" >> b
  $ hg add b
  $ hg commit -m "ab"
  $ echo "aa" >> a
  $ echo "bb" >> b
  $ hg branch new-branch
  marked working directory as branch new-branch
  (branches are permanent and global, did you want a bookmark?)
  $ hg status
  M a
  M b
  $ hg branch
  new-branch
  $ hg shelve a
  shelved as default
  1 files updated, 0 files merged, 0 files removed, 0 files unresolved
  $ hg branch
  new-branch
  $ hg status
  M b
  $ touch "c" >> c
  $ hg add c
  $ hg status
  M b
  A c
  $ hg shelve --exclude c
  shelved as default-01
  1 files updated, 0 files merged, 0 files removed, 0 files unresolved
  $ hg branch
  new-branch
  $ hg status
  A c
  $ hg shelve --include c
  shelved as default-02
  0 files updated, 0 files merged, 1 files removed, 0 files unresolved
  $ hg branch
  new-branch
  $ hg status
  $ echo "d" >> d
  $ hg add d
  $ hg status
  A d

We expect that bare-shelve will not keep branch in current working directory.

  $ hg shelve
  shelved as default-03
  0 files updated, 0 files merged, 1 files removed, 0 files unresolved
  $ hg branch
  default
  $ cd ..

When i shelve commit on newly created branch i expect
that after unshelve newly created branch will be preserved.

  $ hg init shelve_on_new_branch_simple
  $ cd shelve_on_new_branch_simple
  $ echo "aaa" >> a
  $ hg commit -A -m "a"
  adding a
  $ hg branch
  default
  $ hg branch test
  marked working directory as branch test
  (branches are permanent and global, did you want a bookmark?)
  $ echo "bbb" >> a
  $ hg status
  M a
  $ hg shelve
  shelved as default
  1 files updated, 0 files merged, 0 files removed, 0 files unresolved
  $ hg branch
  default
  $ echo "bbb" >> b
  $ hg status
  ? b
  $ hg unshelve
  unshelving change 'default'
  marked working directory as branch test
  $ hg status
  M a
  ? b
  $ hg branch
  test
  $ cd ..

When i shelve commit on newly created branch, make
some changes, unshelve it and running into merge
conflicts i expect that after fixing them and
running unshelve --continue newly created branch
will be preserved.

  $ hg init shelve_on_new_branch_conflict
  $ cd shelve_on_new_branch_conflict
  $ echo "aaa" >> a
  $ hg commit -A -m "a"
  adding a
  $ hg branch
  default
  $ hg branch test
  marked working directory as branch test
  (branches are permanent and global, did you want a bookmark?)
  $ echo "bbb" >> a
  $ hg status
  M a
  $ hg shelve
  shelved as default
  1 files updated, 0 files merged, 0 files removed, 0 files unresolved
  $ hg branch
  default
  $ echo "ccc" >> a
  $ hg status
  M a
  $ hg unshelve
  unshelving change 'default'
  temporarily committing pending changes (restore with 'hg unshelve --abort')
  rebasing shelved changes
  merging a
  warning: conflicts while merging a! (edit, then use 'hg resolve --mark')
  unresolved conflicts (see 'hg resolve', then 'hg unshelve --continue')
  [1]
  $ echo "aaabbbccc" > a
  $ rm a.orig
  $ hg resolve --mark a
  (no more unresolved files)
  continue: hg unshelve --continue
  $ hg unshelve --continue
  marked working directory as branch test
  unshelve of 'default' complete
  $ cat a
  aaabbbccc
  $ hg status
  M a
  $ hg branch
  test
  $ hg commit -m "test-commit"

When i shelve on test branch, update to default branch
and unshelve i expect that it will not preserve previous
test branch.

  $ echo "xxx" > b
  $ hg add b
  $ hg shelve
  shelved as test
  0 files updated, 0 files merged, 1 files removed, 0 files unresolved
  $ hg update -r 7049e48789d7
  1 files updated, 0 files merged, 0 files removed, 0 files unresolved
  $ hg unshelve
  unshelving change 'test'
  rebasing shelved changes
  $ hg status
  A b
  $ hg branch
  default
  $ cd ..

When i unshelve resulting in merge conflicts and makes saved
file shelvedstate looks like in previous versions in
mercurial(without restore branch information in 7th line) i
expect that after resolving conflicts and successfully
running 'shelve --continue' the branch information won't be
restored and branch will be unchanged.

shelve on new branch, conflict with previous shelvedstate

  $ hg init conflict
  $ cd conflict
  $ echo "aaa" >> a
  $ hg commit -A -m "a"
  adding a
  $ hg branch
  default
  $ hg branch test
  marked working directory as branch test
  (branches are permanent and global, did you want a bookmark?)
  $ echo "bbb" >> a
  $ hg status
  M a
  $ hg shelve
  shelved as default
  1 files updated, 0 files merged, 0 files removed, 0 files unresolved
  $ hg branch
  default
  $ echo "ccc" >> a
  $ hg status
  M a
  $ hg unshelve
  unshelving change 'default'
  temporarily committing pending changes (restore with 'hg unshelve --abort')
  rebasing shelved changes
  merging a
  warning: conflicts while merging a! (edit, then use 'hg resolve --mark')
  unresolved conflicts (see 'hg resolve', then 'hg unshelve --continue')
  [1]

Removing restore branch information from shelvedstate file(making it looks like
in previous versions) and running unshelve --continue

  $ cp .hg/shelvedstate .hg/shelvedstate_old
  $ cat .hg/shelvedstate_old | grep -v 'branchtorestore' > .hg/shelvedstate

  $ echo "aaabbbccc" > a
  $ rm a.orig
  $ hg resolve --mark a
  (no more unresolved files)
  continue: hg unshelve --continue
  $ hg unshelve --continue
  unshelve of 'default' complete
  $ cat a
  aaabbbccc
  $ hg status
  M a
  $ hg branch
  default
  $ cd ..

On non bare shelve the branch information shouldn't be restored

  $ hg init bare_shelve_on_new_branch
  $ cd bare_shelve_on_new_branch
  $ echo "aaa" >> a
  $ hg commit -A -m "a"
  adding a
  $ hg branch
  default
  $ hg branch test
  marked working directory as branch test
  (branches are permanent and global, did you want a bookmark?)
  $ echo "bbb" >> a
  $ hg status
  M a
  $ hg shelve a
  shelved as default
  1 files updated, 0 files merged, 0 files removed, 0 files unresolved
  $ hg branch
  test
  $ hg branch default
  marked working directory as branch default
  (branches are permanent and global, did you want a bookmark?)
  $ echo "bbb" >> b
  $ hg status
  ? b
  $ hg unshelve
  unshelving change 'default'
  $ hg status
  M a
  ? b
  $ hg branch
  default
  $ cd ..

Prepare unshelve with a corrupted shelvedstate
  $ hg init r1 && cd r1
  $ echo text1 > file && hg add file
  $ hg shelve
  shelved as default
  0 files updated, 0 files merged, 1 files removed, 0 files unresolved
  $ echo text2 > file && hg ci -Am text1
  adding file
  $ hg unshelve
  unshelving change 'default'
  rebasing shelved changes
  merging file
  warning: conflicts while merging file! (edit, then use 'hg resolve --mark')
  unresolved conflicts (see 'hg resolve', then 'hg unshelve --continue')
  [1]
  $ echo somethingsomething > .hg/shelvedstate

Unshelve --continue fails with appropriate message if shelvedstate is corrupted
  $ hg unshelve --continue
  abort: corrupted shelved state file
  (please run hg unshelve --abort to abort unshelve operation)
  [255]

Unshelve --abort works with a corrupted shelvedstate
  $ hg unshelve --abort
  could not read shelved state file, your working copy may be in an unexpected state
  please update to some commit

Unshelve --abort fails with appropriate message if there's no unshelve in
progress
  $ hg unshelve --abort
  abort: no unshelve in progress
  [255]
  $ cd ..

Unshelve respects --keep even if user intervention is needed
  $ hg init unshelvekeep && cd unshelvekeep
  $ echo 1 > file && hg ci -Am 1
  adding file
  $ echo 2 >> file
  $ hg shelve
  shelved as default
  1 files updated, 0 files merged, 0 files removed, 0 files unresolved
  $ echo 3 >> file && hg ci -Am 13
  $ hg shelve --list
  default         (*s ago) * changes to: 1 (glob)
  $ hg unshelve --keep
  unshelving change 'default'
  rebasing shelved changes
  merging file
  warning: conflicts while merging file! (edit, then use 'hg resolve --mark')
  unresolved conflicts (see 'hg resolve', then 'hg unshelve --continue')
  [1]
  $ hg resolve --mark file
  (no more unresolved files)
  continue: hg unshelve --continue
  $ hg unshelve --continue
  unshelve of 'default' complete
  $ hg shelve --list
  default         (*s ago) * changes to: 1 (glob)
  $ cd ..

Unshelving when there are deleted files does not crash (issue4176)
  $ hg init unshelve-deleted-file && cd unshelve-deleted-file
  $ echo a > a && echo b > b && hg ci -Am ab
  adding a
  adding b
  $ echo aa > a && hg shelve
  shelved as default
  1 files updated, 0 files merged, 0 files removed, 0 files unresolved
  $ rm b
  $ hg st
  ! b
  $ hg unshelve
  unshelving change 'default'
  $ hg shelve
  shelved as default
  1 files updated, 0 files merged, 0 files removed, 0 files unresolved
  $ rm a && echo b > b
  $ hg st
  ! a
  $ hg unshelve
  unshelving change 'default'
  abort: shelved change touches missing files
  (run hg status to see which files are missing)
  [255]
  $ hg st
  ! a
  $ cd ..

New versions of Mercurial know how to read onld shelvedstate files
  $ hg init oldshelvedstate
  $ cd oldshelvedstate
  $ echo root > root && hg ci -Am root
  adding root
  $ echo 1 > a
  $ hg add a
  $ hg shelve --name ashelve
  shelved as ashelve
  0 files updated, 0 files merged, 1 files removed, 0 files unresolved
  $ echo 2 > a
  $ hg ci -Am a
  adding a
  $ hg unshelve
  unshelving change 'ashelve'
  rebasing shelved changes
  merging a
  warning: conflicts while merging a! (edit, then use 'hg resolve --mark')
  unresolved conflicts (see 'hg resolve', then 'hg unshelve --continue')
  [1]
putting v1 shelvedstate file in place of a created v2
  $ cat << EOF > .hg/shelvedstate
  > 1
  > ashelve
  > 8b058dae057a5a78f393f4535d9e363dd5efac9d
  > 8b058dae057a5a78f393f4535d9e363dd5efac9d
  > 8b058dae057a5a78f393f4535d9e363dd5efac9d f543b27db2cdb41737e2e0008dc524c471da1446
  > f543b27db2cdb41737e2e0008dc524c471da1446
  > 
  > nokeep
  > :no-active-bookmark
  > EOF
  $ echo 1 > a
  $ hg resolve --mark a
  (no more unresolved files)
  continue: hg unshelve --continue
mercurial does not crash
  $ hg unshelve --continue
  unshelve of 'ashelve' complete

#if phasebased

Unshelve with some metadata file missing
----------------------------------------

  $ hg shelve
  shelved as default
  1 files updated, 0 files merged, 0 files removed, 0 files unresolved
  $ echo 3 > a

Test with the `.shelve` missing, but the changeset still in the repo (non-natural case)

  $ rm .hg/shelved/default.shelve
  $ hg unshelve
  unshelving change 'default'
  temporarily committing pending changes (restore with 'hg unshelve --abort')
  rebasing shelved changes
  merging a
  warning: conflicts while merging a! (edit, then use 'hg resolve --mark')
  unresolved conflicts (see 'hg resolve', then 'hg unshelve --continue')
  [1]
  $ hg unshelve --abort
  unshelve of 'default' aborted

Unshelve without .shelve metadata (can happen when upgrading a repository with old shelve)

  $ cat .hg/shelved/default.shelve
  node=82e0cb9893247d12667017593ce1e5655860f1ac
  $ hg strip --hidden --rev 82e0cb989324 --no-backup
  $ rm .hg/shelved/default.shelve
  $ hg unshelve
  unshelving change 'default'
  temporarily committing pending changes (restore with 'hg unshelve --abort')
  rebasing shelved changes
  merging a
  warning: conflicts while merging a! (edit, then use 'hg resolve --mark')
  unresolved conflicts (see 'hg resolve', then 'hg unshelve --continue')
  [1]
  $ cat .hg/shelved/default.shelve
  node=82e0cb9893247d12667017593ce1e5655860f1ac
  $ hg unshelve --abort
  unshelve of 'default' aborted

#endif

  $ cd ..
