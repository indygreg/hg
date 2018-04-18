
This test test the low-level definition of stack, agnostic from all formatting

Initial setup

  $ cat << EOF >> $HGRCPATH
  > [ui]
  > logtemplate = {rev} {branch} {phase} {desc|firstline}\n
  > [extensions]
  > rebase=
  > [experimental]
  > evolution=createmarkers,exchange,allowunstable
  > EOF

  $ hg init main
  $ cd main
  $ hg branch other
  marked working directory as branch other
  (branches are permanent and global, did you want a bookmark?)
  $ echo aaa > aaa
  $ hg add aaa
  $ hg commit -m c_a
  $ echo aaa > bbb
  $ hg add bbb
  $ hg commit -m c_b
  $ hg branch foo
  marked working directory as branch foo
  $ echo aaa > ccc
  $ hg add ccc
  $ hg commit -m c_c
  $ echo aaa > ddd
  $ hg add ddd
  $ hg commit -m c_d
  $ echo aaa > eee
  $ hg add eee
  $ hg commit -m c_e
  $ echo aaa > fff
  $ hg add fff
  $ hg commit -m c_f
  $ hg log -G
  @  5 foo draft c_f
  |
  o  4 foo draft c_e
  |
  o  3 foo draft c_d
  |
  o  2 foo draft c_c
  |
  o  1 other draft c_b
  |
  o  0 other draft c_a
  

Check that stack doesn't include public changesets
--------------------------------------------------

  $ hg up other
  0 files updated, 0 files merged, 4 files removed, 0 files unresolved
  $ hg log -G -r "stack()"
  @  1 other draft c_b
  |
  o  0 other draft c_a
  
  $ hg phase --public 'branch("other")'
  $ hg log -G -r "stack()"
  $ hg up foo
  4 files updated, 0 files merged, 0 files removed, 0 files unresolved

Simple test
-----------

'stack()' list all changeset in the branch

  $ hg branch
  foo
  $ hg log -G -r "stack()"
  @  5 foo draft c_f
  |
  o  4 foo draft c_e
  |
  o  3 foo draft c_d
  |
  o  2 foo draft c_c
  |
  ~

Case with some of the branch unstable
------------------------------------

  $ hg up 3
  0 files updated, 0 files merged, 2 files removed, 0 files unresolved
  $ echo bbb > ddd
  $ hg commit --amend
  2 new orphan changesets
  $ hg log -G
  @  6 foo draft c_d
  |
  | *  5 foo draft c_f
  | |
  | *  4 foo draft c_e
  | |
  | x  3 foo draft c_d
  |/
  o  2 foo draft c_c
  |
  o  1 other public c_b
  |
  o  0 other public c_a
  
  $ hg log -G -r "stack()"
  @  6 foo draft c_d
  |
  ~
  $ hg up -r "desc(c_e)"
  2 files updated, 0 files merged, 0 files removed, 0 files unresolved
  $ hg log -G -r "stack()"
  @  4 foo draft c_e
  |
  x  3 foo draft c_d
  |
  ~
  $ hg up -r "desc(c_d)"
  1 files updated, 0 files merged, 1 files removed, 0 files unresolved

  $ hg log -G -r "stack()"
  @  6 foo draft c_d
  |
  ~

Case with multiple topological heads
------------------------------------

Make things linear again

  $ hg rebase -s 'desc(c_e)' -d 'desc(c_d) - obsolete()'
  rebasing 4:4f2a69f6d380 "c_e"
  rebasing 5:913c298d8b0a "c_f"
  $ hg log -G
  o  8 foo draft c_f
  |
  o  7 foo draft c_e
  |
  @  6 foo draft c_d
  |
  o  2 foo draft c_c
  |
  o  1 other public c_b
  |
  o  0 other public c_a
  

Create the second branch

  $ hg up 'desc(c_d)'
  0 files updated, 0 files merged, 0 files removed, 0 files unresolved
  $ echo aaa > ggg
  $ hg add ggg
  $ hg commit -m c_g
  created new head
  $ echo aaa > hhh
  $ hg add hhh
  $ hg commit -m c_h
  $ hg log -G
  @  10 foo draft c_h
  |
  o  9 foo draft c_g
  |
  | o  8 foo draft c_f
  | |
  | o  7 foo draft c_e
  |/
  o  6 foo draft c_d
  |
  o  2 foo draft c_c
  |
  o  1 other public c_b
  |
  o  0 other public c_a
  

Test output

  $ hg log -G -r "stack(10)"
  @  10 foo draft c_h
  |
  o  9 foo draft c_g
  |
  ~
  $ hg log -G -r "stack(8)"
  o  8 foo draft c_f
  |
  o  7 foo draft c_e
  |
  ~
  $ hg log -G -r "stack(head())"
  @  10 foo draft c_h
  |
  o  9 foo draft c_g
  |
  ~
  o  8 foo draft c_f
  |
  o  7 foo draft c_e
  |
  ~
Check the stack order
  $ hg log -r "first(stack())"
  9 foo draft c_g
  $ hg log -r "first(stack(10))"
  9 foo draft c_g
  $ hg log -r "first(stack(8))"
  7 foo draft c_e
  $ hg log -r "first(stack(head()))"
  7 foo draft c_e

Case with multiple heads with unstability involved
--------------------------------------------------

We amend the message to make sure the display base pick the right changeset

  $ hg up 'desc(c_d)'
  0 files updated, 0 files merged, 2 files removed, 0 files unresolved
  $ echo ccc > ddd
  $ hg commit --amend -m 'c_D'
  4 new orphan changesets
  $ hg rebase -d . -s 'desc(c_g)'
  rebasing 9:2ebb6e48ab8a "c_g"
  rebasing 10:634f38e27a1d "c_h"
  $ hg log -G
  o  13 foo draft c_h
  |
  o  12 foo draft c_g
  |
  @  11 foo draft c_D
  |
  | *  8 foo draft c_f
  | |
  | *  7 foo draft c_e
  | |
  | x  6 foo draft c_d
  |/
  o  2 foo draft c_c
  |
  o  1 other public c_b
  |
  o  0 other public c_a
  

We should improve stack definition to also show 12 and 13 here
  $ hg log -G -r "stack()"
  @  11 foo draft c_D
  |
  ~
