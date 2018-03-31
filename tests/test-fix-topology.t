A script that implements uppercasing all letters in a file.

  $ UPPERCASEPY="$TESTTMP/uppercase.py"
  $ cat > $UPPERCASEPY <<EOF
  > import sys
  > from mercurial.utils.procutil import setbinary
  > setbinary(sys.stdin)
  > setbinary(sys.stdout)
  > sys.stdout.write(sys.stdin.read().upper())
  > EOF
  $ TESTLINES="foo\nbar\nbaz\n"
  $ printf $TESTLINES | $PYTHON $UPPERCASEPY
  FOO
  BAR
  BAZ

Tests for the fix extension's behavior around non-trivial history topologies.
Looks for correct incremental fixing and reproduction of parent/child
relationships. We indicate fixed file content by uppercasing it.

  $ cat >> $HGRCPATH <<EOF
  > [extensions]
  > fix =
  > [fix]
  > uppercase-whole-file:command=$PYTHON $UPPERCASEPY
  > uppercase-whole-file:fileset=set:**
  > EOF

This tests the only behavior that should really be affected by obsolescence, so
we'll test it with evolution off and on. This only changes the revision
numbers, if all is well.

#testcases obsstore-off obsstore-on
#if obsstore-on
  $ cat >> $HGRCPATH <<EOF
  > [experimental]
  > evolution.createmarkers=True
  > evolution.allowunstable=True
  > EOF
#endif

Setting up the test topology. Scroll down to see the graph produced. We make it
clear which files were modified in each revision. It's enough to test at the
file granularity, because that demonstrates which baserevs were diffed against.
The computation of changed lines is orthogonal and tested separately.

  $ hg init repo
  $ cd repo

  $ printf "aaaa\n" > a
  $ hg commit -Am "change A"
  adding a
  $ printf "bbbb\n" > b
  $ hg commit -Am "change B"
  adding b
  $ printf "cccc\n" > c
  $ hg commit -Am "change C"
  adding c
  $ hg checkout 0
  0 files updated, 0 files merged, 2 files removed, 0 files unresolved
  $ printf "dddd\n" > d
  $ hg commit -Am "change D"
  adding d
  created new head
  $ hg merge -r 2
  2 files updated, 0 files merged, 0 files removed, 0 files unresolved
  (branch merge, don't forget to commit)
  $ printf "eeee\n" > e
  $ hg commit -Am "change E"
  adding e
  $ hg checkout 0
  0 files updated, 0 files merged, 4 files removed, 0 files unresolved
  $ printf "ffff\n" > f
  $ hg commit -Am "change F"
  adding f
  created new head
  $ hg checkout 0
  0 files updated, 0 files merged, 1 files removed, 0 files unresolved
  $ printf "gggg\n" > g
  $ hg commit -Am "change G"
  adding g
  created new head
  $ hg merge -r 5
  1 files updated, 0 files merged, 0 files removed, 0 files unresolved
  (branch merge, don't forget to commit)
  $ printf "hhhh\n" > h
  $ hg commit -Am "change H"
  adding h
  $ hg merge -r 4
  4 files updated, 0 files merged, 0 files removed, 0 files unresolved
  (branch merge, don't forget to commit)
  $ printf "iiii\n" > i
  $ hg commit -Am "change I"
  adding i
  $ hg checkout 2
  0 files updated, 0 files merged, 6 files removed, 0 files unresolved
  $ printf "jjjj\n" > j
  $ hg commit -Am "change J"
  adding j
  created new head
  $ hg checkout 7
  3 files updated, 0 files merged, 3 files removed, 0 files unresolved
  $ printf "kkkk\n" > k
  $ hg add
  adding k

  $ hg log --graph --template '{rev} {desc}\n'
  o  9 change J
  |
  | o    8 change I
  | |\
  | | @    7 change H
  | | |\
  | | | o  6 change G
  | | | |
  | | o |  5 change F
  | | |/
  | o |  4 change E
  |/| |
  | o |  3 change D
  | |/
  o |  2 change C
  | |
  o |  1 change B
  |/
  o  0 change A
  

Fix all but the root revision and its four children.

#if obsstore-on
  $ hg fix -r '2|4|7|8|9' --working-dir
#else
  $ hg fix -r '2|4|7|8|9' --working-dir
  saved backup bundle to * (glob)
#endif

The five revisions remain, but the other revisions were fixed and replaced. All
parent pointers have been accurately set to reproduce the previous topology
(though it is rendered in a slightly different order now).

#if obsstore-on
  $ hg log --graph --template '{rev} {desc}\n'
  o  14 change J
  |
  | o    13 change I
  | |\
  | | @    12 change H
  | | |\
  | o | |  11 change E
  |/| | |
  o | | |  10 change C
  | | | |
  | | | o  6 change G
  | | | |
  | | o |  5 change F
  | | |/
  | o /  3 change D
  | |/
  o /  1 change B
  |/
  o  0 change A
  
  $ C=10
  $ E=11
  $ H=12
  $ I=13
  $ J=14
#else
  $ hg log --graph --template '{rev} {desc}\n'
  o  9 change J
  |
  | o    8 change I
  | |\
  | | @    7 change H
  | | |\
  | o | |  6 change E
  |/| | |
  o | | |  5 change C
  | | | |
  | | | o  4 change G
  | | | |
  | | o |  3 change F
  | | |/
  | o /  2 change D
  | |/
  o /  1 change B
  |/
  o  0 change A
  
  $ C=5
  $ E=6
  $ H=7
  $ I=8
  $ J=9
#endif

Change C is a root of the set being fixed, so all we fix is what has changed
since its parent. That parent, change B, is its baserev.

  $ hg cat -r $C 'set:**'
  aaaa
  bbbb
  CCCC

Change E is a merge with only one parent being fixed. Its baserevs are the
unfixed parent plus the baserevs of the other parent. This evaluates to changes
B and D. We now have to decide what it means to incrementally fix a merge
commit. We choose to fix anything that has changed versus any baserev. Only the
undisturbed content of the common ancestor, change A, is unfixed.

  $ hg cat -r $E 'set:**'
  aaaa
  BBBB
  CCCC
  DDDD
  EEEE

Change H is a merge with neither parent being fixed. This is essentially
equivalent to the previous case because there is still only one baserev for
each parent of the merge.

  $ hg cat -r $H 'set:**'
  aaaa
  FFFF
  GGGG
  HHHH

Change I is a merge that has four baserevs; two from each parent. We handle
multiple baserevs in the same way regardless of how many came from each parent.
So, fixing change H will fix any files that were not exactly the same in each
baserev.

  $ hg cat -r $I 'set:**'
  aaaa
  BBBB
  CCCC
  DDDD
  EEEE
  FFFF
  GGGG
  HHHH
  IIII

Change J is a simple case with one baserev, but its baserev is not its parent,
change C. Its baserev is its grandparent, change B.

  $ hg cat -r $J 'set:**'
  aaaa
  bbbb
  CCCC
  JJJJ

The working copy was dirty, so it is treated much like a revision. The baserevs
for the working copy are inherited from its parent, change H, because it is
also being fixed.

  $ cat *
  aaaa
  FFFF
  GGGG
  HHHH
  KKKK

Change A was never a baserev because none of its children were to be fixed.

  $ cd ..

