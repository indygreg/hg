  $ addcommit () {
  >     echo $1 > $1
  >     hg add $1
  >     hg commit -d "${2} 0" -m $1
  > }

  $ commit () {
  >     hg commit -d "${2} 0" -m $1
  > }

  $ hg init a
  $ cd a
  $ addcommit "A" 0
  $ addcommit "B" 1
  $ echo "C" >> A
  $ commit "C" 2

  $ hg update -C 0
  1 files updated, 0 files merged, 1 files removed, 0 files unresolved
  $ echo "D" >> A
  $ commit "D" 3
  created new head

State before the merge

  $ hg status
  $ hg id
  e45016d2b3d3 tip
  $ hg summary
  parent: 3:e45016d2b3d3 tip
   D
  branch: default
  commit: (clean)
  update: 2 new changesets, 2 branch heads (merge)
  phases: 4 draft

Testing the abort functionality first in case of conflicts

  $ hg merge --abort
  abort: no merge in progress
  [255]
  $ hg merge
  merging A
  warning: conflicts while merging A! (edit, then use 'hg resolve --mark')
  1 files updated, 0 files merged, 0 files removed, 1 files unresolved
  use 'hg resolve' to retry unresolved file merges or 'hg merge --abort' to abandon
  [1]

  $ hg merge --abort e4501
  abort: cannot specify a node with --abort
  [255]
  $ hg merge --abort --rev e4501
  abort: cannot specify both --rev and --abort
  [255]

  $ hg merge --abort
  aborting the merge, updating back to e45016d2b3d3
  1 files updated, 0 files merged, 1 files removed, 0 files unresolved

Checking that we got back in the same state

  $ hg status
  ? A.orig
  $ hg id
  e45016d2b3d3 tip
  $ hg summary
  parent: 3:e45016d2b3d3 tip
   D
  branch: default
  commit: 1 unknown (clean)
  update: 2 new changesets, 2 branch heads (merge)
  phases: 4 draft

Merging a conflict araises

  $ hg merge
  merging A
  warning: conflicts while merging A! (edit, then use 'hg resolve --mark')
  1 files updated, 0 files merged, 0 files removed, 1 files unresolved
  use 'hg resolve' to retry unresolved file merges or 'hg merge --abort' to abandon
  [1]

Correct the conflict without marking the file as resolved

  $ echo "ABCD" > A
  $ hg commit -m "Merged"
  abort: unresolved merge conflicts (see 'hg help resolve')
  [255]

Mark the conflict as resolved and commit

  $ hg resolve -m A
  (no more unresolved files)
  $ hg commit -m "Merged"

Test that if a file is removed but not marked resolved, the commit still fails
(issue4972)

  $ hg up ".^"
  1 files updated, 0 files merged, 1 files removed, 0 files unresolved
  $ hg merge 2
  merging A
  warning: conflicts while merging A! (edit, then use 'hg resolve --mark')
  1 files updated, 0 files merged, 0 files removed, 1 files unresolved
  use 'hg resolve' to retry unresolved file merges or 'hg merge --abort' to abandon
  [1]
  $ hg rm --force A
  $ hg commit -m merged
  abort: unresolved merge conflicts (see 'hg help resolve')
  [255]

  $ hg resolve -ma
  (no more unresolved files)
  $ hg commit -m merged
  created new head

Testing the abort functionality in case of no conflicts

  $ hg update -C 0
  1 files updated, 0 files merged, 1 files removed, 0 files unresolved
  $ addcommit "E" 4
  created new head
  $ hg id
  68352a18a7c4 tip

  $ hg merge -r 4
  2 files updated, 0 files merged, 0 files removed, 0 files unresolved
  (branch merge, don't forget to commit)

  $ hg merge --preview --abort
  abort: cannot specify --preview with --abort
  [255]

  $ hg merge --abort
  aborting the merge, updating back to 68352a18a7c4
  1 files updated, 0 files merged, 1 files removed, 0 files unresolved

  $ hg id
  68352a18a7c4 tip

  $ cd ..
