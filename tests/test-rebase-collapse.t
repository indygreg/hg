  $ cat >> $HGRCPATH <<EOF
  > [extensions]
  > rebase=
  > mq=
  > drawdag=$TESTDIR/drawdag.py
  > 
  > [phases]
  > publish=False
  > 
  > [alias]
  > tglog = log -G --template "{rev}: {node|short} '{desc}' {branches}\n"
  > tglogp = log -G --template "{rev}: {node|short} {phase} '{desc}' {branches}\n"
  > EOF

Highest phase of source commits is used:

  $ hg init phase
  $ cd phase
  $ hg debugdrawdag << 'EOF'
  >   D
  >   |
  > F C
  > | |
  > E B
  > |/
  > A
  > EOF

  $ hg phase --force --secret D

  $ cat > $TESTTMP/editor.sh <<EOF
  > echo "==== before editing"
  > cat \$1
  > echo "===="
  > echo "edited manually" >> \$1
  > EOF
  $ HGEDITOR="sh $TESTTMP/editor.sh" hg rebase --collapse --keepbranches -e --dest F
  rebasing 1:112478962961 "B" (B)
  rebasing 3:26805aba1e60 "C" (C)
  rebasing 5:f585351a92f8 "D" (D tip)
  ==== before editing
  Collapsed revision
  * B
  * C
  * D
  
  
  HG: Enter commit message.  Lines beginning with 'HG:' are removed.
  HG: Leave message empty to abort commit.
  HG: --
  HG: user: test
  HG: branch 'default'
  HG: added B
  HG: added C
  HG: added D
  ====
  saved backup bundle to $TESTTMP/phase/.hg/strip-backup/112478962961-cb2a9b47-rebase.hg

  $ hg tglogp
  o  3: 92fa5f5fe108 secret 'Collapsed revision
  |  * B
  |  * C
  |  * D
  |
  |
  |  edited manually'
  o  2: 64a8289d2492 draft 'F'
  |
  o  1: 7fb047a69f22 draft 'E'
  |
  o  0: 426bada5c675 draft 'A'
  
  $ hg manifest --rev tip
  A
  B
  C
  D
  E
  F

  $ cd ..


Merge gets linearized:

  $ hg init linearized-merge
  $ cd linearized-merge

  $ hg debugdrawdag << 'EOF'
  > F D
  > |/|
  > C B
  > |/
  > A
  > EOF

  $ hg phase --force --secret D
  $ hg rebase --source B --collapse --dest F
  rebasing 1:112478962961 "B" (B)
  rebasing 3:4e4f9194f9f1 "D" (D)
  saved backup bundle to $TESTTMP/linearized-merge/.hg/strip-backup/112478962961-e389075b-rebase.hg

  $ hg tglog
  o  3: 5bdc08b7da2b 'Collapsed revision
  |  * B
  |  * D'
  o  2: afc707c82df0 'F'
  |
  o  1: dc0947a82db8 'C'
  |
  o  0: 426bada5c675 'A'
  
  $ hg manifest --rev tip
  A
  B
  C
  F

  $ cd ..

Custom message:

  $ hg init message
  $ cd message

  $ hg debugdrawdag << 'EOF'
  >   C
  >   |
  > D B
  > |/
  > A
  > EOF


  $ hg rebase --base B -m 'custom message'
  abort: message can only be specified with collapse
  [255]

  $ cat > $TESTTMP/checkeditform.sh <<EOF
  > env | grep HGEDITFORM
  > true
  > EOF
  $ HGEDITOR="sh $TESTTMP/checkeditform.sh" hg rebase --source B --collapse -m 'custom message' -e --dest D
  rebasing 1:112478962961 "B" (B)
  rebasing 3:26805aba1e60 "C" (C tip)
  HGEDITFORM=rebase.collapse
  saved backup bundle to $TESTTMP/message/.hg/strip-backup/112478962961-f4131707-rebase.hg

  $ hg tglog
  o  2: 2f197b9a08f3 'custom message'
  |
  o  1: b18e25de2cf5 'D'
  |
  o  0: 426bada5c675 'A'
  
  $ hg manifest --rev tip
  A
  B
  C
  D

  $ cd ..

Rebase and collapse - more than one external (fail):

  $ hg init multiple-external-parents
  $ cd multiple-external-parents

  $ hg debugdrawdag << 'EOF'
  >   G
  >   |\
  >   | F
  >   | |
  >   D E
  >   |\|
  > H C B
  >  \|/
  >   A
  > EOF

  $ hg rebase -s C --dest H --collapse
  abort: unable to collapse on top of 3, there is more than one external parent: 1, 6
  [255]

Rebase and collapse - E onto H:

  $ hg rebase -s E --dest I --collapse # root (E) is not a merge
  abort: unknown revision 'I'!
  [255]

  $ hg tglog
  o    7: 64e264db77f0 'G'
  |\
  | o  6: 11abe3fb10b8 'F'
  | |
  | o  5: 49cb92066bfd 'E'
  | |
  o |  4: 4e4f9194f9f1 'D'
  |\|
  | | o  3: 575c4b5ec114 'H'
  | | |
  o---+  2: dc0947a82db8 'C'
   / /
  o /  1: 112478962961 'B'
  |/
  o  0: 426bada5c675 'A'
  
  $ hg manifest --rev tip
  A
  B
  C
  E
  F

  $ cd ..




Test that branchheads cache is updated correctly when doing a strip in which
the parent of the ancestor node to be stripped does not become a head and also,
the parent of a node that is a child of the node stripped becomes a head (node
3). The code is now much simpler and we could just test a simpler scenario
We keep it the test this way in case new complexity is injected.

Create repo b:

  $ hg init branch-heads
  $ cd branch-heads

  $ hg debugdrawdag << 'EOF'
  >   G
  >   |\
  >   | F
  >   | |
  >   D E
  >   |\|
  > H C B
  >  \|/
  >   A
  > EOF

  $ hg heads --template="{rev}:{node} {branch}\n"
  7:64e264db77f061f16d9132b70c5a58e2461fb630 default
  3:575c4b5ec114d64b681d33f8792853568bfb2b2c default

  $ cat $TESTTMP/branch-heads/.hg/cache/branch2-served
  64e264db77f061f16d9132b70c5a58e2461fb630 7
  575c4b5ec114d64b681d33f8792853568bfb2b2c o default
  64e264db77f061f16d9132b70c5a58e2461fb630 o default

  $ hg strip 4
  saved backup bundle to $TESTTMP/branch-heads/.hg/strip-backup/4e4f9194f9f1-5ec4b5e6-backup.hg

  $ cat $TESTTMP/branch-heads/.hg/cache/branch2-served
  11abe3fb10b8689b560681094b17fe161871d043 5
  dc0947a82db884575bb76ea10ac97b08536bfa03 o default
  575c4b5ec114d64b681d33f8792853568bfb2b2c o default
  11abe3fb10b8689b560681094b17fe161871d043 o default

  $ hg heads --template="{rev}:{node} {branch}\n"
  5:11abe3fb10b8689b560681094b17fe161871d043 default
  3:575c4b5ec114d64b681d33f8792853568bfb2b2c default
  2:dc0947a82db884575bb76ea10ac97b08536bfa03 default

  $ cd ..



Preserves external parent

  $ hg init external-parent
  $ cd external-parent

  $ hg debugdrawdag << 'EOF'
  >   H
  >   |\
  >   | G
  >   | |
  >   | F # F/E = F\n
  >   | |
  >   D E # D/D = D\n
  >   |\|
  > I C B
  >  \|/
  >   A
  > EOF

  $ hg rebase -s F --dest I --collapse # root (F) is not a merge
  rebasing 6:c82b08f646f1 "F" (F)
  rebasing 7:a6db7fa104e1 "G" (G)
  rebasing 8:e1d201b72d91 "H" (H tip)
  saved backup bundle to $TESTTMP/external-parent/.hg/strip-backup/c82b08f646f1-f2721fbf-rebase.hg

  $ hg tglog
  o    6: 681daa3e686d 'Collapsed revision
  |\   * F
  | |  * G
  | |  * H'
  | | o  5: 49cb92066bfd 'E'
  | | |
  | o |  4: 09143c0bf13e 'D'
  | |\|
  o | |  3: 08ebfeb61bac 'I'
  | | |
  | o |  2: dc0947a82db8 'C'
  |/ /
  | o  1: 112478962961 'B'
  |/
  o  0: 426bada5c675 'A'
  
  $ hg manifest --rev tip
  A
  C
  D
  E
  F
  G
  I

  $ hg up tip -q
  $ cat E
  F

  $ cd ..

Rebasing from multiple bases:

  $ hg init multiple-bases
  $ cd multiple-bases
  $ hg debugdrawdag << 'EOF'
  >   C B
  > D |/
  > |/
  > A
  > EOF
  $ hg rebase --collapse -r 'B+C' -d D
  rebasing 1:fc2b737bb2e5 "B" (B)
  rebasing 2:dc0947a82db8 "C" (C)
  saved backup bundle to $TESTTMP/multiple-bases/.hg/strip-backup/dc0947a82db8-b0c1a7ea-rebase.hg
  $ hg tglog
  o  2: 2127ae44d291 'Collapsed revision
  |  * B
  |  * C'
  o  1: b18e25de2cf5 'D'
  |
  o  0: 426bada5c675 'A'
  
  $ cd ..

With non-contiguous commits:

  $ hg init non-contiguous
  $ cd non-contiguous
  $ cat >> .hg/hgrc <<EOF
  > [experimental]
  > evolution=all
  > EOF

  $ hg debugdrawdag << 'EOF'
  > F
  > |
  > E
  > |
  > D
  > |
  > C
  > |
  > B G
  > |/
  > A
  > EOF

BROKEN: should be allowed
  $ hg rebase --collapse -r 'B+D+F' -d G
  abort: unable to collapse on top of 2, there is more than one external parent: 3, 5
  [255]
  $ cd ..


  $ hg init multiple-external-parents-2
  $ cd multiple-external-parents-2
  $ hg debugdrawdag << 'EOF'
  > D       G
  > |\     /|
  > B C   E F
  >  \|   |/
  >   \ H /
  >    \|/
  >     A
  > EOF

  $ hg rebase --collapse -d H -s 'B+F'
  abort: unable to collapse on top of 5, there is more than one external parent: 1, 3
  [255]
  $ cd ..

With internal merge:

  $ hg init internal-merge
  $ cd internal-merge

  $ hg debugdrawdag << 'EOF'
  >   E
  >   |\
  >   C D
  >   |/
  > F B
  > |/
  > A
  > EOF


  $ hg rebase -s B --collapse --dest F
  rebasing 1:112478962961 "B" (B)
  rebasing 3:26805aba1e60 "C" (C)
  rebasing 4:be0ef73c17ad "D" (D)
  rebasing 5:02c4367d6973 "E" (E tip)
  saved backup bundle to $TESTTMP/internal-merge/.hg/strip-backup/112478962961-1dfb057b-rebase.hg

  $ hg tglog
  o  2: c0512a1797b0 'Collapsed revision
  |  * B
  |  * C
  |  * D
  |  * E'
  o  1: 8908a377a434 'F'
  |
  o  0: 426bada5c675 'A'
  
  $ hg manifest --rev tip
  A
  B
  C
  D
  F
  $ cd ..

Interactions between collapse and keepbranches
  $ hg init e
  $ cd e
  $ echo 'a' > a
  $ hg ci -Am 'A'
  adding a

  $ hg branch 'one'
  marked working directory as branch one
  (branches are permanent and global, did you want a bookmark?)
  $ echo 'b' > b
  $ hg ci -Am 'B'
  adding b

  $ hg branch 'two'
  marked working directory as branch two
  $ echo 'c' > c
  $ hg ci -Am 'C'
  adding c

  $ hg up -q 0
  $ echo 'd' > d
  $ hg ci -Am 'D'
  adding d

  $ hg tglog
  @  3: 41acb9dca9eb 'D'
  |
  | o  2: 8ac4a08debf1 'C' two
  | |
  | o  1: 1ba175478953 'B' one
  |/
  o  0: 1994f17a630e 'A'
  
  $ hg rebase --keepbranches --collapse -s 1 -d 3
  abort: cannot collapse multiple named branches
  [255]

  $ repeatchange() {
  >   hg checkout $1
  >   hg cp d z
  >   echo blah >> z
  >   hg commit -Am "$2" --user "$3"
  > }
  $ repeatchange 3 "E" "user1"
  0 files updated, 0 files merged, 0 files removed, 0 files unresolved
  $ repeatchange 3 "E" "user2"
  0 files updated, 0 files merged, 1 files removed, 0 files unresolved
  created new head
  $ hg tglog
  @  5: fbfb97b1089a 'E'
  |
  | o  4: f338eb3c2c7c 'E'
  |/
  o  3: 41acb9dca9eb 'D'
  |
  | o  2: 8ac4a08debf1 'C' two
  | |
  | o  1: 1ba175478953 'B' one
  |/
  o  0: 1994f17a630e 'A'
  
  $ hg rebase -s 5 -d 4
  rebasing 5:fbfb97b1089a "E" (tip)
  note: rebase of 5:fbfb97b1089a created no changes to commit
  saved backup bundle to $TESTTMP/e/.hg/strip-backup/fbfb97b1089a-553e1d85-rebase.hg
  $ hg tglog
  @  4: f338eb3c2c7c 'E'
  |
  o  3: 41acb9dca9eb 'D'
  |
  | o  2: 8ac4a08debf1 'C' two
  | |
  | o  1: 1ba175478953 'B' one
  |/
  o  0: 1994f17a630e 'A'
  
  $ hg export tip
  # HG changeset patch
  # User user1
  # Date 0 0
  #      Thu Jan 01 00:00:00 1970 +0000
  # Node ID f338eb3c2c7cc5b5915676a2376ba7ac558c5213
  # Parent  41acb9dca9eb976e84cd21fcb756b4afa5a35c09
  E
  
  diff -r 41acb9dca9eb -r f338eb3c2c7c z
  --- /dev/null	Thu Jan 01 00:00:00 1970 +0000
  +++ b/z	Thu Jan 01 00:00:00 1970 +0000
  @@ -0,0 +1,2 @@
  +d
  +blah

  $ cd ..

Rebase, collapse and copies

  $ hg init copies
  $ cd copies
  $ hg unbundle "$TESTDIR/bundles/renames.hg"
  adding changesets
  adding manifests
  adding file changes
  added 4 changesets with 11 changes to 7 files (+1 heads)
  new changesets f447d5abf5ea:338e84e2e558 (4 drafts)
  (run 'hg heads' to see heads, 'hg merge' to merge)
  $ hg up -q tip
  $ hg tglog
  @  3: 338e84e2e558 'move2'
  |
  o  2: 6e7340ee38c0 'move1'
  |
  | o  1: 1352765a01d4 'change'
  |/
  o  0: f447d5abf5ea 'add'
  
  $ hg rebase --collapse -d 1
  rebasing 2:6e7340ee38c0 "move1"
  merging a and d to d
  merging b and e to e
  merging c and f to f
  rebasing 3:338e84e2e558 "move2" (tip)
  merging f and c to c
  merging e and g to g
  saved backup bundle to $TESTTMP/copies/.hg/strip-backup/6e7340ee38c0-ef8ef003-rebase.hg
  $ hg st
  $ hg st --copies --change tip
  A d
    a
  A g
    b
  R b
  $ hg up tip -q
  $ cat c
  c
  c
  $ cat d
  a
  a
  $ cat g
  b
  b
  $ hg log -r . --template "{file_copies}\n"
  d (a)g (b)

Test collapsing a middle revision in-place

  $ hg tglog
  @  2: 64b456429f67 'Collapsed revision
  |  * move1
  |  * move2'
  o  1: 1352765a01d4 'change'
  |
  o  0: f447d5abf5ea 'add'
  
  $ hg rebase --collapse -r 1 -d 0
  abort: can't remove original changesets with unrebased descendants
  (use --keep to keep original changesets)
  [255]

Test collapsing in place

  $ hg rebase --collapse -b . -d 0
  rebasing 1:1352765a01d4 "change"
  rebasing 2:64b456429f67 "Collapsed revision" (tip)
  saved backup bundle to $TESTTMP/copies/.hg/strip-backup/1352765a01d4-45a352ea-rebase.hg
  $ hg st --change tip --copies
  M a
  M c
  A d
    a
  A g
    b
  R b
  $ hg up tip -q
  $ cat a
  a
  a
  $ cat c
  c
  c
  $ cat d
  a
  a
  $ cat g
  b
  b
  $ cd ..


Test stripping a revision with another child

  $ hg init f
  $ cd f

  $ hg debugdrawdag << 'EOF'
  > C B
  > |/
  > A
  > EOF

  $ hg heads --template="{rev}:{node} {branch}: {desc}\n"
  2:dc0947a82db884575bb76ea10ac97b08536bfa03 default: C
  1:112478962961147124edd43549aedd1a335e44bf default: B

  $ hg strip C
  saved backup bundle to $TESTTMP/f/.hg/strip-backup/dc0947a82db8-d21b92a4-backup.hg

  $ hg tglog
  o  1: 112478962961 'B'
  |
  o  0: 426bada5c675 'A'
  


  $ hg heads --template="{rev}:{node} {branch}: {desc}\n"
  1:112478962961147124edd43549aedd1a335e44bf default: B

  $ cd ..

Test collapsing changes that add then remove a file

  $ hg init collapseaddremove
  $ cd collapseaddremove

  $ touch base
  $ hg commit -Am base
  adding base
  $ touch a
  $ hg commit -Am a
  adding a
  $ hg rm a
  $ touch b
  $ hg commit -Am b
  adding b
  $ hg book foo
  $ hg rebase -d 0 -r "1::2" --collapse -m collapsed
  rebasing 1:6d8d9f24eec3 "a"
  rebasing 2:1cc73eca5ecc "b" (foo tip)
  saved backup bundle to $TESTTMP/collapseaddremove/.hg/strip-backup/6d8d9f24eec3-77d3b6e2-rebase.hg
  $ hg log -G --template "{rev}: '{desc}' {bookmarks}"
  @  1: 'collapsed' foo
  |
  o  0: 'base'
  
  $ hg manifest --rev tip
  b
  base

  $ cd ..

Test that rebase --collapse will remember message after
running into merge conflict and invoking rebase --continue.

  $ hg init collapse_remember_message
  $ cd collapse_remember_message
  $ hg debugdrawdag << 'EOF'
  > C B # B/A = B\n
  > |/  # C/A = C\n
  > A
  > EOF
  $ hg rebase --collapse -m "new message" -b B -d C
  rebasing 1:81e5401e4d37 "B" (B)
  merging A
  warning: conflicts while merging A! (edit, then use 'hg resolve --mark')
  unresolved conflicts (see hg resolve, then hg rebase --continue)
  [1]
  $ rm A.orig
  $ hg resolve --mark A
  (no more unresolved files)
  continue: hg rebase --continue
  $ hg rebase --continue
  rebasing 1:81e5401e4d37 "B" (B)
  saved backup bundle to $TESTTMP/collapse_remember_message/.hg/strip-backup/81e5401e4d37-96c3dd30-rebase.hg
  $ hg log
  changeset:   2:17186933e123
  tag:         tip
  user:        test
  date:        Thu Jan 01 00:00:00 1970 +0000
  summary:     new message
  
  changeset:   1:043039e9df84
  tag:         C
  user:        test
  date:        Thu Jan 01 00:00:00 1970 +0000
  summary:     C
  
  changeset:   0:426bada5c675
  tag:         A
  user:        test
  date:        Thu Jan 01 00:00:00 1970 +0000
  summary:     A
  
  $ cd ..

Test aborted editor on final message

  $ HGMERGE=:merge3
  $ export HGMERGE
  $ hg init aborted-editor
  $ cd aborted-editor
  $ hg debugdrawdag << 'EOF'
  > C   # D/A = D\n
  > |   # C/A = C\n
  > B D # B/A = B\n
  > |/  # A/A = A\n
  > A
  > EOF
  $ hg rebase --collapse -t internal:merge3 -s B -d D
  rebasing 1:f899f3910ce7 "B" (B)
  merging A
  warning: conflicts while merging A! (edit, then use 'hg resolve --mark')
  unresolved conflicts (see hg resolve, then hg rebase --continue)
  [1]
  $ hg tglog
  o  3: 63668d570d21 'C'
  |
  | @  2: 82b8abf9c185 'D'
  | |
  @ |  1: f899f3910ce7 'B'
  |/
  o  0: 4a2df7238c3b 'A'
  
  $ cat A
  <<<<<<< dest:   82b8abf9c185 D - test: D
  D
  ||||||| base
  A
  =======
  B
  >>>>>>> source: f899f3910ce7 B - test: B
  $ echo BC > A
  $ hg resolve -m
  (no more unresolved files)
  continue: hg rebase --continue
  $ hg rebase --continue
  rebasing 1:f899f3910ce7 "B" (B)
  rebasing 3:63668d570d21 "C" (C tip)
  merging A
  warning: conflicts while merging A! (edit, then use 'hg resolve --mark')
  unresolved conflicts (see hg resolve, then hg rebase --continue)
  [1]
  $ hg tglog
  @  3: 63668d570d21 'C'
  |
  | @  2: 82b8abf9c185 'D'
  | |
  o |  1: f899f3910ce7 'B'
  |/
  o  0: 4a2df7238c3b 'A'
  
  $ cat A
  <<<<<<< dest:   82b8abf9c185 D - test: D
  BC
  ||||||| base
  B
  =======
  C
  >>>>>>> source: 63668d570d21 C tip - test: C
  $ echo BD > A
  $ hg resolve -m
  (no more unresolved files)
  continue: hg rebase --continue
  $ HGEDITOR=false hg rebase --continue --config ui.interactive=1
  already rebased 1:f899f3910ce7 "B" (B) as 82b8abf9c185
  rebasing 3:63668d570d21 "C" (C tip)
  abort: edit failed: false exited with status 1
  [255]
  $ hg tglog
  o  3: 63668d570d21 'C'
  |
  | @  2: 82b8abf9c185 'D'
  | |
  o |  1: f899f3910ce7 'B'
  |/
  o  0: 4a2df7238c3b 'A'
  
  $ hg rebase --continue
  already rebased 1:f899f3910ce7 "B" (B) as 82b8abf9c185
  already rebased 3:63668d570d21 "C" (C tip) as 82b8abf9c185
  saved backup bundle to $TESTTMP/aborted-editor/.hg/strip-backup/f899f3910ce7-7cab5e15-rebase.hg
