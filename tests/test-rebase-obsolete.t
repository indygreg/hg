==========================
Test rebase with obsolete
==========================

Enable obsolete

  $ cat >> $HGRCPATH << EOF
  > [ui]
  > logtemplate= {rev}:{node|short} {desc|firstline}{if(obsolete,' ({obsfate})')}
  > [experimental]
  > evolution.createmarkers=True
  > evolution.allowunstable=True
  > [phases]
  > publish=False
  > [extensions]
  > rebase=
  > drawdag=$TESTDIR/drawdag.py
  > strip=
  > EOF

Setup rebase canonical repo

  $ hg init base
  $ cd base
  $ hg unbundle "$TESTDIR/bundles/rebase.hg"
  adding changesets
  adding manifests
  adding file changes
  added 8 changesets with 7 changes to 7 files (+2 heads)
  new changesets cd010b8cd998:02de42196ebe (8 drafts)
  (run 'hg heads' to see heads, 'hg merge' to merge)
  $ hg up tip
  3 files updated, 0 files merged, 0 files removed, 0 files unresolved
  $ hg log -G
  @  7:02de42196ebe H
  |
  | o  6:eea13746799a G
  |/|
  o |  5:24b6387c8c8c F
  | |
  | o  4:9520eea781bc E
  |/
  | o  3:32af7686d403 D
  | |
  | o  2:5fddd98957c8 C
  | |
  | o  1:42ccdea3bb16 B
  |/
  o  0:cd010b8cd998 A
  
  $ cd ..

simple rebase
---------------------------------

  $ hg clone base simple
  updating to branch default
  3 files updated, 0 files merged, 0 files removed, 0 files unresolved
  $ cd simple
  $ hg up 32af7686d403
  3 files updated, 0 files merged, 2 files removed, 0 files unresolved
  $ hg rebase -d eea13746799a
  rebasing 1:42ccdea3bb16 "B"
  rebasing 2:5fddd98957c8 "C"
  rebasing 3:32af7686d403 "D"
  $ hg log -G
  @  10:8eeb3c33ad33 D
  |
  o  9:2327fea05063 C
  |
  o  8:e4e5be0395b2 B
  |
  | o  7:02de42196ebe H
  | |
  o |  6:eea13746799a G
  |\|
  | o  5:24b6387c8c8c F
  | |
  o |  4:9520eea781bc E
  |/
  o  0:cd010b8cd998 A
  
  $ hg log --hidden -G
  @  10:8eeb3c33ad33 D
  |
  o  9:2327fea05063 C
  |
  o  8:e4e5be0395b2 B
  |
  | o  7:02de42196ebe H
  | |
  o |  6:eea13746799a G
  |\|
  | o  5:24b6387c8c8c F
  | |
  o |  4:9520eea781bc E
  |/
  | x  3:32af7686d403 D (rewritten using rebase as 10:8eeb3c33ad33)
  | |
  | x  2:5fddd98957c8 C (rewritten using rebase as 9:2327fea05063)
  | |
  | x  1:42ccdea3bb16 B (rewritten using rebase as 8:e4e5be0395b2)
  |/
  o  0:cd010b8cd998 A
  
  $ hg debugobsolete
  42ccdea3bb16d28e1848c95fe2e44c000f3f21b1 e4e5be0395b2cbd471ed22a26b1b6a1a0658a794 0 (Thu Jan 01 00:00:00 1970 +0000) {'ef1': '4', 'operation': 'rebase', 'user': 'test'}
  5fddd98957c8a54a4d436dfe1da9d87f21a1b97b 2327fea05063f39961b14cb69435a9898dc9a245 0 (Thu Jan 01 00:00:00 1970 +0000) {'ef1': '4', 'operation': 'rebase', 'user': 'test'}
  32af7686d403cf45b5d95f2d70cebea587ac806a 8eeb3c33ad33d452c89e5dcf611c347f978fb42b 0 (Thu Jan 01 00:00:00 1970 +0000) {'ef1': '4', 'operation': 'rebase', 'user': 'test'}


  $ cd ..

empty changeset
---------------------------------

  $ hg clone base empty
  updating to branch default
  3 files updated, 0 files merged, 0 files removed, 0 files unresolved
  $ cd empty
  $ hg up eea13746799a
  1 files updated, 0 files merged, 1 files removed, 0 files unresolved

We make a copy of both the first changeset in the rebased and some other in the
set.

  $ hg graft 42ccdea3bb16 32af7686d403
  grafting 1:42ccdea3bb16 "B"
  grafting 3:32af7686d403 "D"
  $ hg rebase  -s 42ccdea3bb16 -d .
  rebasing 1:42ccdea3bb16 "B"
  note: not rebasing 1:42ccdea3bb16 "B", its destination already has all its changes
  rebasing 2:5fddd98957c8 "C"
  rebasing 3:32af7686d403 "D"
  note: not rebasing 3:32af7686d403 "D", its destination already has all its changes
  $ hg log -G
  o  10:5ae4c968c6ac C
  |
  @  9:08483444fef9 D
  |
  o  8:8877864f1edb B
  |
  | o  7:02de42196ebe H
  | |
  o |  6:eea13746799a G
  |\|
  | o  5:24b6387c8c8c F
  | |
  o |  4:9520eea781bc E
  |/
  o  0:cd010b8cd998 A
  
  $ hg log --hidden -G
  o  10:5ae4c968c6ac C
  |
  @  9:08483444fef9 D
  |
  o  8:8877864f1edb B
  |
  | o  7:02de42196ebe H
  | |
  o |  6:eea13746799a G
  |\|
  | o  5:24b6387c8c8c F
  | |
  o |  4:9520eea781bc E
  |/
  | x  3:32af7686d403 D (pruned using rebase)
  | |
  | x  2:5fddd98957c8 C (rewritten using rebase as 10:5ae4c968c6ac)
  | |
  | x  1:42ccdea3bb16 B (pruned using rebase)
  |/
  o  0:cd010b8cd998 A
  
  $ hg debugobsolete
  42ccdea3bb16d28e1848c95fe2e44c000f3f21b1 0 {cd010b8cd998f3981a5a8115f94f8da4ab506089} (Thu Jan 01 00:00:00 1970 +0000) {'ef1': '0', 'operation': 'rebase', 'user': 'test'}
  5fddd98957c8a54a4d436dfe1da9d87f21a1b97b 5ae4c968c6aca831df823664e706c9d4aa34473d 0 (Thu Jan 01 00:00:00 1970 +0000) {'ef1': '4', 'operation': 'rebase', 'user': 'test'}
  32af7686d403cf45b5d95f2d70cebea587ac806a 0 {5fddd98957c8a54a4d436dfe1da9d87f21a1b97b} (Thu Jan 01 00:00:00 1970 +0000) {'ef1': '0', 'operation': 'rebase', 'user': 'test'}


More complex case where part of the rebase set were already rebased

  $ hg rebase --rev 'desc(D)' --dest 'desc(H)'
  rebasing 9:08483444fef9 "D"
  1 new orphan changesets
  $ hg debugobsolete
  42ccdea3bb16d28e1848c95fe2e44c000f3f21b1 0 {cd010b8cd998f3981a5a8115f94f8da4ab506089} (Thu Jan 01 00:00:00 1970 +0000) {'ef1': '0', 'operation': 'rebase', 'user': 'test'}
  5fddd98957c8a54a4d436dfe1da9d87f21a1b97b 5ae4c968c6aca831df823664e706c9d4aa34473d 0 (Thu Jan 01 00:00:00 1970 +0000) {'ef1': '4', 'operation': 'rebase', 'user': 'test'}
  32af7686d403cf45b5d95f2d70cebea587ac806a 0 {5fddd98957c8a54a4d436dfe1da9d87f21a1b97b} (Thu Jan 01 00:00:00 1970 +0000) {'ef1': '0', 'operation': 'rebase', 'user': 'test'}
  08483444fef91d6224f6655ee586a65d263ad34c 4596109a6a4328c398bde3a4a3b6737cfade3003 0 (Thu Jan 01 00:00:00 1970 +0000) {'ef1': '4', 'operation': 'rebase', 'user': 'test'}
  $ hg log -G
  @  11:4596109a6a43 D
  |
  | *  10:5ae4c968c6ac C
  | |
  | x  9:08483444fef9 D (rewritten using rebase as 11:4596109a6a43)
  | |
  | o  8:8877864f1edb B
  | |
  o |  7:02de42196ebe H
  | |
  | o  6:eea13746799a G
  |/|
  o |  5:24b6387c8c8c F
  | |
  | o  4:9520eea781bc E
  |/
  o  0:cd010b8cd998 A
  
  $ hg rebase --source 'desc(B)' --dest 'tip' --config experimental.rebaseskipobsolete=True
  rebasing 8:8877864f1edb "B"
  note: not rebasing 9:08483444fef9 "D", already in destination as 11:4596109a6a43 "D" (tip)
  rebasing 10:5ae4c968c6ac "C"
  $ hg debugobsolete
  42ccdea3bb16d28e1848c95fe2e44c000f3f21b1 0 {cd010b8cd998f3981a5a8115f94f8da4ab506089} (Thu Jan 01 00:00:00 1970 +0000) {'ef1': '0', 'operation': 'rebase', 'user': 'test'}
  5fddd98957c8a54a4d436dfe1da9d87f21a1b97b 5ae4c968c6aca831df823664e706c9d4aa34473d 0 (Thu Jan 01 00:00:00 1970 +0000) {'ef1': '4', 'operation': 'rebase', 'user': 'test'}
  32af7686d403cf45b5d95f2d70cebea587ac806a 0 {5fddd98957c8a54a4d436dfe1da9d87f21a1b97b} (Thu Jan 01 00:00:00 1970 +0000) {'ef1': '0', 'operation': 'rebase', 'user': 'test'}
  08483444fef91d6224f6655ee586a65d263ad34c 4596109a6a4328c398bde3a4a3b6737cfade3003 0 (Thu Jan 01 00:00:00 1970 +0000) {'ef1': '4', 'operation': 'rebase', 'user': 'test'}
  8877864f1edb05d0e07dc4ba77b67a80a7b86672 462a34d07e599b87ea08676a449373fe4e2e1347 0 (Thu Jan 01 00:00:00 1970 +0000) {'ef1': '4', 'operation': 'rebase', 'user': 'test'}
  5ae4c968c6aca831df823664e706c9d4aa34473d 98f6af4ee9539e14da4465128f894c274900b6e5 0 (Thu Jan 01 00:00:00 1970 +0000) {'ef1': '4', 'operation': 'rebase', 'user': 'test'}
  $ hg log --rev 'contentdivergent()'
  $ hg log -G
  o  13:98f6af4ee953 C
  |
  o  12:462a34d07e59 B
  |
  @  11:4596109a6a43 D
  |
  o  7:02de42196ebe H
  |
  | o  6:eea13746799a G
  |/|
  o |  5:24b6387c8c8c F
  | |
  | o  4:9520eea781bc E
  |/
  o  0:cd010b8cd998 A
  
  $ hg log --style default --debug -r 4596109a6a4328c398bde3a4a3b6737cfade3003
  changeset:   11:4596109a6a4328c398bde3a4a3b6737cfade3003
  phase:       draft
  parent:      7:02de42196ebee42ef284b6780a87cdc96e8eaab6
  parent:      -1:0000000000000000000000000000000000000000
  manifest:    11:a91006e3a02f1edf631f7018e6e5684cf27dd905
  user:        Nicolas Dumazet <nicdumz.commits@gmail.com>
  date:        Sat Apr 30 15:24:48 2011 +0200
  files+:      D
  extra:       branch=default
  extra:       rebase_source=08483444fef91d6224f6655ee586a65d263ad34c
  extra:       source=32af7686d403cf45b5d95f2d70cebea587ac806a
  description:
  D
  
  
  $ hg up -qr 'desc(G)'
  $ hg graft 4596109a6a4328c398bde3a4a3b6737cfade3003
  grafting 11:4596109a6a43 "D"
  $ hg up -qr 'desc(E)'
  $ hg rebase -s tip -d .
  rebasing 14:9e36056a46e3 "D" (tip)
  $ hg log --style default --debug -r tip
  changeset:   15:627d4614809036ba22b9e7cb31638ddc06ab99ab
  tag:         tip
  phase:       draft
  parent:      4:9520eea781bcca16c1e15acc0ba14335a0e8e5ba
  parent:      -1:0000000000000000000000000000000000000000
  manifest:    15:648e8ede73ae3e497d093d3a4c8fcc2daa864f42
  user:        Nicolas Dumazet <nicdumz.commits@gmail.com>
  date:        Sat Apr 30 15:24:48 2011 +0200
  files+:      D
  extra:       branch=default
  extra:       intermediate-source=4596109a6a4328c398bde3a4a3b6737cfade3003
  extra:       rebase_source=9e36056a46e37c9776168c7375734eebc70e294f
  extra:       source=32af7686d403cf45b5d95f2d70cebea587ac806a
  description:
  D
  
  
Start rebase from a commit that is obsolete but not hidden only because it's
a working copy parent. We should be moved back to the starting commit as usual
even though it is hidden (until we're moved there).

  $ hg --hidden up -qr 'first(hidden())'
  updated to hidden changeset 42ccdea3bb16
  (hidden revision '42ccdea3bb16' is pruned)
  $ hg rebase --rev 13 --dest 15
  rebasing 13:98f6af4ee953 "C"
  $ hg log -G
  o  16:294a2b93eb4d C
  |
  o  15:627d46148090 D
  |
  | o  12:462a34d07e59 B
  | |
  | o  11:4596109a6a43 D
  | |
  | o  7:02de42196ebe H
  | |
  +---o  6:eea13746799a G
  | |/
  | o  5:24b6387c8c8c F
  | |
  o |  4:9520eea781bc E
  |/
  | @  1:42ccdea3bb16 B (pruned using rebase)
  |/
  o  0:cd010b8cd998 A
  

  $ cd ..

collapse rebase
---------------------------------

  $ hg clone base collapse
  updating to branch default
  3 files updated, 0 files merged, 0 files removed, 0 files unresolved
  $ cd collapse
  $ hg rebase  -s 42ccdea3bb16 -d eea13746799a --collapse
  rebasing 1:42ccdea3bb16 "B"
  rebasing 2:5fddd98957c8 "C"
  rebasing 3:32af7686d403 "D"
  $ hg log -G
  o  8:4dc2197e807b Collapsed revision
  |
  | @  7:02de42196ebe H
  | |
  o |  6:eea13746799a G
  |\|
  | o  5:24b6387c8c8c F
  | |
  o |  4:9520eea781bc E
  |/
  o  0:cd010b8cd998 A
  
  $ hg log --hidden -G
  o  8:4dc2197e807b Collapsed revision
  |
  | @  7:02de42196ebe H
  | |
  o |  6:eea13746799a G
  |\|
  | o  5:24b6387c8c8c F
  | |
  o |  4:9520eea781bc E
  |/
  | x  3:32af7686d403 D (rewritten using rebase as 8:4dc2197e807b)
  | |
  | x  2:5fddd98957c8 C (rewritten using rebase as 8:4dc2197e807b)
  | |
  | x  1:42ccdea3bb16 B (rewritten using rebase as 8:4dc2197e807b)
  |/
  o  0:cd010b8cd998 A
  
  $ hg id --debug -r tip
  4dc2197e807bae9817f09905b50ab288be2dbbcf tip
  $ hg debugobsolete
  42ccdea3bb16d28e1848c95fe2e44c000f3f21b1 4dc2197e807bae9817f09905b50ab288be2dbbcf 0 (Thu Jan 01 00:00:00 1970 +0000) {'ef1': '13', 'fold-id': '6fb65cdc', 'fold-idx': '1', 'fold-size': '3', 'operation': 'rebase', 'user': 'test'}
  5fddd98957c8a54a4d436dfe1da9d87f21a1b97b 4dc2197e807bae9817f09905b50ab288be2dbbcf 0 (Thu Jan 01 00:00:00 1970 +0000) {'ef1': '13', 'fold-id': '6fb65cdc', 'fold-idx': '2', 'fold-size': '3', 'operation': 'rebase', 'user': 'test'}
  32af7686d403cf45b5d95f2d70cebea587ac806a 4dc2197e807bae9817f09905b50ab288be2dbbcf 0 (Thu Jan 01 00:00:00 1970 +0000) {'ef1': '13', 'fold-id': '6fb65cdc', 'fold-idx': '3', 'fold-size': '3', 'operation': 'rebase', 'user': 'test'}

  $ cd ..

Rebase set has hidden descendants
---------------------------------

We rebase a changeset which has hidden descendants. Hidden changesets must not
be rebased.

  $ hg clone base hidden
  updating to branch default
  3 files updated, 0 files merged, 0 files removed, 0 files unresolved
  $ cd hidden
  $ hg log -G
  @  7:02de42196ebe H
  |
  | o  6:eea13746799a G
  |/|
  o |  5:24b6387c8c8c F
  | |
  | o  4:9520eea781bc E
  |/
  | o  3:32af7686d403 D
  | |
  | o  2:5fddd98957c8 C
  | |
  | o  1:42ccdea3bb16 B
  |/
  o  0:cd010b8cd998 A
  
  $ hg rebase -s 5fddd98957c8 -d eea13746799a
  rebasing 2:5fddd98957c8 "C"
  rebasing 3:32af7686d403 "D"
  $ hg log -G
  o  9:cf44d2f5a9f4 D
  |
  o  8:e273c5e7d2d2 C
  |
  | @  7:02de42196ebe H
  | |
  o |  6:eea13746799a G
  |\|
  | o  5:24b6387c8c8c F
  | |
  o |  4:9520eea781bc E
  |/
  | o  1:42ccdea3bb16 B
  |/
  o  0:cd010b8cd998 A
  
  $ hg rebase -s 42ccdea3bb16 -d 02de42196ebe
  rebasing 1:42ccdea3bb16 "B"
  $ hg log -G
  o  10:7c6027df6a99 B
  |
  | o  9:cf44d2f5a9f4 D
  | |
  | o  8:e273c5e7d2d2 C
  | |
  @ |  7:02de42196ebe H
  | |
  | o  6:eea13746799a G
  |/|
  o |  5:24b6387c8c8c F
  | |
  | o  4:9520eea781bc E
  |/
  o  0:cd010b8cd998 A
  
  $ hg log --hidden -G
  o  10:7c6027df6a99 B
  |
  | o  9:cf44d2f5a9f4 D
  | |
  | o  8:e273c5e7d2d2 C
  | |
  @ |  7:02de42196ebe H
  | |
  | o  6:eea13746799a G
  |/|
  o |  5:24b6387c8c8c F
  | |
  | o  4:9520eea781bc E
  |/
  | x  3:32af7686d403 D (rewritten using rebase as 9:cf44d2f5a9f4)
  | |
  | x  2:5fddd98957c8 C (rewritten using rebase as 8:e273c5e7d2d2)
  | |
  | x  1:42ccdea3bb16 B (rewritten using rebase as 10:7c6027df6a99)
  |/
  o  0:cd010b8cd998 A
  
  $ hg debugobsolete
  5fddd98957c8a54a4d436dfe1da9d87f21a1b97b e273c5e7d2d29df783dce9f9eaa3ac4adc69c15d 0 (Thu Jan 01 00:00:00 1970 +0000) {'ef1': '4', 'operation': 'rebase', 'user': 'test'}
  32af7686d403cf45b5d95f2d70cebea587ac806a cf44d2f5a9f4297a62be94cbdd3dff7c7dc54258 0 (Thu Jan 01 00:00:00 1970 +0000) {'ef1': '4', 'operation': 'rebase', 'user': 'test'}
  42ccdea3bb16d28e1848c95fe2e44c000f3f21b1 7c6027df6a99d93f461868e5433f63bde20b6dfb 0 (Thu Jan 01 00:00:00 1970 +0000) {'ef1': '4', 'operation': 'rebase', 'user': 'test'}

Test that rewriting leaving instability behind is allowed
---------------------------------------------------------------------

  $ hg log -r 'children(8)'
  9:cf44d2f5a9f4 D (no-eol)
  $ hg rebase -r 8
  rebasing 8:e273c5e7d2d2 "C"
  1 new orphan changesets
  $ hg log -G
  o  11:0d8f238b634c C
  |
  o  10:7c6027df6a99 B
  |
  | *  9:cf44d2f5a9f4 D
  | |
  | x  8:e273c5e7d2d2 C (rewritten using rebase as 11:0d8f238b634c)
  | |
  @ |  7:02de42196ebe H
  | |
  | o  6:eea13746799a G
  |/|
  o |  5:24b6387c8c8c F
  | |
  | o  4:9520eea781bc E
  |/
  o  0:cd010b8cd998 A
  
  $ cd ..
  $ cp -R hidden stabilize
  $ cd stabilize
  $ hg rebase --auto-orphans '0::' -d 10
  abort: --auto-orphans is incompatible with --dest
  [255]
  $ hg rebase --auto-orphans '0::'
  rebasing 9:cf44d2f5a9f4 "D"
  $ hg log -G
  o  12:7e3935feaa68 D
  |
  o  11:0d8f238b634c C
  |
  o  10:7c6027df6a99 B
  |
  @  7:02de42196ebe H
  |
  | o  6:eea13746799a G
  |/|
  o |  5:24b6387c8c8c F
  | |
  | o  4:9520eea781bc E
  |/
  o  0:cd010b8cd998 A
  

  $ cd ../hidden
  $ rm -r ../stabilize

Test multiple root handling
------------------------------------

  $ hg rebase --dest 4 --rev '7+11+9'
  rebasing 9:cf44d2f5a9f4 "D"
  rebasing 7:02de42196ebe "H"
  rebasing 11:0d8f238b634c "C" (tip)
  $ hg log -G
  o  14:1e8370e38cca C
  |
  @  13:bfe264faf697 H
  |
  | o  12:102b4c1d889b D
  |/
  | *  10:7c6027df6a99 B
  | |
  | x  7:02de42196ebe H (rewritten using rebase as 13:bfe264faf697)
  | |
  +---o  6:eea13746799a G
  | |/
  | o  5:24b6387c8c8c F
  | |
  o |  4:9520eea781bc E
  |/
  o  0:cd010b8cd998 A
  
  $ cd ..

Detach both parents

  $ hg init double-detach
  $ cd double-detach

  $ hg debugdrawdag <<EOF
  >   F
  >  /|
  > C E
  > | |
  > B D G
  >  \|/
  >   A
  > EOF

  $ hg rebase -d G -r 'B + D + F'
  rebasing 1:112478962961 "B" (B)
  rebasing 2:b18e25de2cf5 "D" (D)
  rebasing 6:f15c3adaf214 "F" (F tip)
  abort: cannot rebase 6:f15c3adaf214 without moving at least one of its parents
  [255]

  $ cd ..

test on rebase dropping a merge

(setup)

  $ hg init dropmerge
  $ cd dropmerge
  $ hg unbundle "$TESTDIR/bundles/rebase.hg"
  adding changesets
  adding manifests
  adding file changes
  added 8 changesets with 7 changes to 7 files (+2 heads)
  new changesets cd010b8cd998:02de42196ebe (8 drafts)
  (run 'hg heads' to see heads, 'hg merge' to merge)
  $ hg up 3
  4 files updated, 0 files merged, 0 files removed, 0 files unresolved
  $ hg merge 7
  2 files updated, 0 files merged, 0 files removed, 0 files unresolved
  (branch merge, don't forget to commit)
  $ hg ci -m 'M'
  $ echo I > I
  $ hg add I
  $ hg ci -m I
  $ hg log -G
  @  9:4bde274eefcf I
  |
  o    8:53a6a128b2b7 M
  |\
  | o  7:02de42196ebe H
  | |
  | | o  6:eea13746799a G
  | |/|
  | o |  5:24b6387c8c8c F
  | | |
  | | o  4:9520eea781bc E
  | |/
  o |  3:32af7686d403 D
  | |
  o |  2:5fddd98957c8 C
  | |
  o |  1:42ccdea3bb16 B
  |/
  o  0:cd010b8cd998 A
  
(actual test)

  $ hg rebase --dest 6 --rev '((desc(H) + desc(D))::) - desc(M)'
  rebasing 3:32af7686d403 "D"
  rebasing 7:02de42196ebe "H"
  rebasing 9:4bde274eefcf "I" (tip)
  1 new orphan changesets
  $ hg log -G
  @  12:acd174b7ab39 I
  |
  o  11:6c11a6218c97 H
  |
  | o  10:b5313c85b22e D
  |/
  | *    8:53a6a128b2b7 M
  | |\
  | | x  7:02de42196ebe H (rewritten using rebase as 11:6c11a6218c97)
  | | |
  o---+  6:eea13746799a G
  | | |
  | | o  5:24b6387c8c8c F
  | | |
  o---+  4:9520eea781bc E
   / /
  x |  3:32af7686d403 D (rewritten using rebase as 10:b5313c85b22e)
  | |
  o |  2:5fddd98957c8 C
  | |
  o |  1:42ccdea3bb16 B
  |/
  o  0:cd010b8cd998 A
  

Test hidden changesets in the rebase set (issue4504)

  $ hg up --hidden 9
  3 files updated, 0 files merged, 1 files removed, 0 files unresolved
  updated to hidden changeset 4bde274eefcf
  (hidden revision '4bde274eefcf' was rewritten as: acd174b7ab39)
  $ echo J > J
  $ hg add J
  $ hg commit -m J
  1 new orphan changesets
  $ hg debugobsolete `hg log --rev . -T '{node}'`
  obsoleted 1 changesets

  $ hg rebase --rev .~1::. --dest 'max(desc(D))' --traceback --config experimental.rebaseskipobsolete=off
  rebasing 9:4bde274eefcf "I"
  rebasing 13:06edfc82198f "J" (tip)
  2 new content-divergent changesets
  $ hg log -G
  @  15:5ae8a643467b J
  |
  *  14:9ad579b4a5de I
  |
  | *  12:acd174b7ab39 I
  | |
  | o  11:6c11a6218c97 H
  | |
  o |  10:b5313c85b22e D
  |/
  | *    8:53a6a128b2b7 M
  | |\
  | | x  7:02de42196ebe H (rewritten using rebase as 11:6c11a6218c97)
  | | |
  o---+  6:eea13746799a G
  | | |
  | | o  5:24b6387c8c8c F
  | | |
  o---+  4:9520eea781bc E
   / /
  x |  3:32af7686d403 D (rewritten using rebase as 10:b5313c85b22e)
  | |
  o |  2:5fddd98957c8 C
  | |
  o |  1:42ccdea3bb16 B
  |/
  o  0:cd010b8cd998 A
  
  $ hg up 14 -C
  0 files updated, 0 files merged, 1 files removed, 0 files unresolved
  $ echo "K" > K
  $ hg add K
  $ hg commit --amend -m "K"
  1 new orphan changesets
  $ echo "L" > L
  $ hg add L
  $ hg commit -m "L"
  $ hg up '.^'
  0 files updated, 0 files merged, 1 files removed, 0 files unresolved
  $ echo "M" > M
  $ hg add M
  $ hg commit --amend -m "M"
  1 new orphan changesets
  $ hg log -G
  @  18:bfaedf8eb73b M
  |
  | *  17:97219452e4bd L
  | |
  | x  16:fc37a630c901 K (rewritten using amend as 18:bfaedf8eb73b)
  |/
  | *  15:5ae8a643467b J
  | |
  | x  14:9ad579b4a5de I (rewritten using amend as 16:fc37a630c901)
  |/
  | *  12:acd174b7ab39 I
  | |
  | o  11:6c11a6218c97 H
  | |
  o |  10:b5313c85b22e D
  |/
  | *    8:53a6a128b2b7 M
  | |\
  | | x  7:02de42196ebe H (rewritten using rebase as 11:6c11a6218c97)
  | | |
  o---+  6:eea13746799a G
  | | |
  | | o  5:24b6387c8c8c F
  | | |
  o---+  4:9520eea781bc E
   / /
  x |  3:32af7686d403 D (rewritten using rebase as 10:b5313c85b22e)
  | |
  o |  2:5fddd98957c8 C
  | |
  o |  1:42ccdea3bb16 B
  |/
  o  0:cd010b8cd998 A
  
  $ hg rebase -s 14 -d 17 --config experimental.rebaseskipobsolete=True
  note: not rebasing 14:9ad579b4a5de "I", already in destination as 16:fc37a630c901 "K"
  rebasing 15:5ae8a643467b "J"
  1 new orphan changesets

  $ cd ..

Skip obsolete changeset even with multiple hops
-----------------------------------------------

setup

  $ hg init obsskip
  $ cd obsskip
  $ cat << EOF >> .hg/hgrc
  > [experimental]
  > rebaseskipobsolete = True
  > [extensions]
  > strip =
  > EOF
  $ echo A > A
  $ hg add A
  $ hg commit -m A
  $ echo B > B
  $ hg add B
  $ hg commit -m B0
  $ hg commit --amend -m B1
  $ hg commit --amend -m B2
  $ hg up --hidden 'desc(B0)'
  0 files updated, 0 files merged, 0 files removed, 0 files unresolved
  updated to hidden changeset a8b11f55fb19
  (hidden revision 'a8b11f55fb19' was rewritten as: 261e70097290)
  $ echo C > C
  $ hg add C
  $ hg commit -m C
  1 new orphan changesets
  $ hg log -G
  @  4:212cb178bcbb C
  |
  | o  3:261e70097290 B2
  | |
  x |  1:a8b11f55fb19 B0 (rewritten using amend as 3:261e70097290)
  |/
  o  0:4a2df7238c3b A
  

Rebase finds its way in a chain of marker

  $ hg rebase -d 'desc(B2)'
  note: not rebasing 1:a8b11f55fb19 "B0", already in destination as 3:261e70097290 "B2"
  rebasing 4:212cb178bcbb "C" (tip)

Even when the chain include missing node

  $ hg up --hidden 'desc(B0)'
  0 files updated, 0 files merged, 1 files removed, 0 files unresolved
  updated to hidden changeset a8b11f55fb19
  (hidden revision 'a8b11f55fb19' was rewritten as: 261e70097290)
  $ echo D > D
  $ hg add D
  $ hg commit -m D
  1 new orphan changesets
  $ hg --hidden strip -r 'desc(B1)'
  saved backup bundle to $TESTTMP/obsskip/.hg/strip-backup/86f6414ccda7-b1c452ee-backup.hg
  1 new orphan changesets
  $ hg log -G
  @  5:1a79b7535141 D
  |
  | o  4:ff2c4d47b71d C
  | |
  | o  2:261e70097290 B2
  | |
  x |  1:a8b11f55fb19 B0 (rewritten using amend as 2:261e70097290)
  |/
  o  0:4a2df7238c3b A
  

  $ hg rebase -d 'desc(B2)'
  note: not rebasing 1:a8b11f55fb19 "B0", already in destination as 2:261e70097290 "B2"
  rebasing 5:1a79b7535141 "D" (tip)
  $ hg up 4
  1 files updated, 0 files merged, 1 files removed, 0 files unresolved
  $ echo "O" > O
  $ hg add O
  $ hg commit -m O
  $ echo "P" > P
  $ hg add P
  $ hg commit -m P
  $ hg log -G
  @  8:8d47583e023f P
  |
  o  7:360bbaa7d3ce O
  |
  | o  6:9c48361117de D
  | |
  o |  4:ff2c4d47b71d C
  |/
  o  2:261e70097290 B2
  |
  o  0:4a2df7238c3b A
  
  $ hg debugobsolete `hg log -r 7 -T '{node}\n'` --config experimental.evolution=true
  obsoleted 1 changesets
  1 new orphan changesets
  $ hg rebase -d 6 -r "4::"
  rebasing 4:ff2c4d47b71d "C"
  note: not rebasing 7:360bbaa7d3ce "O", it has no successor
  rebasing 8:8d47583e023f "P" (tip)

If all the changeset to be rebased are obsolete and present in the destination, we
should display a friendly error message

  $ hg log -G
  @  10:121d9e3bc4c6 P
  |
  o  9:4be60e099a77 C
  |
  o  6:9c48361117de D
  |
  o  2:261e70097290 B2
  |
  o  0:4a2df7238c3b A
  

  $ hg up 9
  0 files updated, 0 files merged, 1 files removed, 0 files unresolved
  $ echo "non-relevant change" > nonrelevant
  $ hg add nonrelevant
  $ hg commit -m nonrelevant
  created new head
  $ hg debugobsolete `hg log -r 11 -T '{node}\n'` --config experimental.evolution=true
  obsoleted 1 changesets
  $ hg log -G
  @  11:f44da1f4954c nonrelevant (pruned)
  |
  | o  10:121d9e3bc4c6 P
  |/
  o  9:4be60e099a77 C
  |
  o  6:9c48361117de D
  |
  o  2:261e70097290 B2
  |
  o  0:4a2df7238c3b A
  
  $ hg rebase -r . -d 10
  note: not rebasing 11:f44da1f4954c "nonrelevant" (tip), it has no successor

If a rebase is going to create divergence, it should abort

  $ hg log -G
  @  10:121d9e3bc4c6 P
  |
  o  9:4be60e099a77 C
  |
  o  6:9c48361117de D
  |
  o  2:261e70097290 B2
  |
  o  0:4a2df7238c3b A
  

  $ hg up 9
  0 files updated, 0 files merged, 1 files removed, 0 files unresolved
  $ echo "john" > doe
  $ hg add doe
  $ hg commit -m "john doe"
  created new head
  $ hg up 10
  1 files updated, 0 files merged, 1 files removed, 0 files unresolved
  $ echo "foo" > bar
  $ hg add bar
  $ hg commit --amend -m "10'"
  $ hg up 10 --hidden
  0 files updated, 0 files merged, 1 files removed, 0 files unresolved
  updated to hidden changeset 121d9e3bc4c6
  (hidden revision '121d9e3bc4c6' was rewritten as: 77d874d096a2)
  $ echo "bar" > foo
  $ hg add foo
  $ hg commit -m "bar foo"
  1 new orphan changesets
  $ hg log -G
  @  14:73568ab6879d bar foo
  |
  | o  13:77d874d096a2 10'
  | |
  | | o  12:3eb461388009 john doe
  | |/
  x |  10:121d9e3bc4c6 P (rewritten using amend as 13:77d874d096a2)
  |/
  o  9:4be60e099a77 C
  |
  o  6:9c48361117de D
  |
  o  2:261e70097290 B2
  |
  o  0:4a2df7238c3b A
  
  $ hg summary
  parent: 14:73568ab6879d tip (orphan)
   bar foo
  branch: default
  commit: (clean)
  update: 2 new changesets, 3 branch heads (merge)
  phases: 8 draft
  orphan: 1 changesets
  $ hg rebase -s 10 -d 12
  abort: this rebase will cause divergences from: 121d9e3bc4c6
  (to force the rebase please set experimental.evolution.allowdivergence=True)
  [255]
  $ hg log -G
  @  14:73568ab6879d bar foo
  |
  | o  13:77d874d096a2 10'
  | |
  | | o  12:3eb461388009 john doe
  | |/
  x |  10:121d9e3bc4c6 P (rewritten using amend as 13:77d874d096a2)
  |/
  o  9:4be60e099a77 C
  |
  o  6:9c48361117de D
  |
  o  2:261e70097290 B2
  |
  o  0:4a2df7238c3b A
  
With experimental.evolution.allowdivergence=True, rebase can create divergence

  $ hg rebase -s 10 -d 12 --config experimental.evolution.allowdivergence=True
  rebasing 10:121d9e3bc4c6 "P"
  rebasing 14:73568ab6879d "bar foo" (tip)
  2 new content-divergent changesets
  $ hg summary
  parent: 16:61bd55f69bc4 tip
   bar foo
  branch: default
  commit: (clean)
  update: 1 new changesets, 2 branch heads (merge)
  phases: 8 draft
  content-divergent: 2 changesets

rebase --continue + skipped rev because their successors are in destination
we make a change in trunk and work on conflicting changes to make rebase abort.

  $ hg log -G -r 16::
  @  16:61bd55f69bc4 bar foo
  |
  ~

Create the two changes in trunk
  $ printf "a" > willconflict
  $ hg add willconflict
  $ hg commit -m "willconflict first version"

  $ printf "dummy" > C
  $ hg commit -m "dummy change successor"

Create the changes that we will rebase
  $ hg update -C 16 -q
  $ printf "b" > willconflict
  $ hg add willconflict
  $ hg commit -m "willconflict second version"
  created new head
  $ printf "dummy" > K
  $ hg add K
  $ hg commit -m "dummy change"
  $ printf "dummy" > L
  $ hg add L
  $ hg commit -m "dummy change"
  $ hg debugobsolete `hg log -r ".^" -T '{node}'` `hg log -r 18 -T '{node}'` --config experimental.evolution=true
  obsoleted 1 changesets
  1 new orphan changesets

  $ hg log -G -r 16::
  @  21:7bdc8a87673d dummy change
  |
  x  20:8b31da3c4919 dummy change (rewritten as 18:601db7a18f51)
  |
  o  19:b82fb57ea638 willconflict second version
  |
  | o  18:601db7a18f51 dummy change successor
  | |
  | o  17:357ddf1602d5 willconflict first version
  |/
  o  16:61bd55f69bc4 bar foo
  |
  ~
  $ hg rebase -r ".^^ + .^ + ." -d 18
  rebasing 19:b82fb57ea638 "willconflict second version"
  merging willconflict
  warning: conflicts while merging willconflict! (edit, then use 'hg resolve --mark')
  unresolved conflicts (see hg resolve, then hg rebase --continue)
  [1]

  $ hg resolve --mark willconflict
  (no more unresolved files)
  continue: hg rebase --continue
  $ hg rebase --continue
  rebasing 19:b82fb57ea638 "willconflict second version"
  note: not rebasing 20:8b31da3c4919 "dummy change", already in destination as 18:601db7a18f51 "dummy change successor"
  rebasing 21:7bdc8a87673d "dummy change" (tip)
  $ cd ..

Divergence cases due to obsolete changesets
-------------------------------------------

We should ignore branches with unstable changesets when they are based on an
obsolete changeset which successor is in rebase set.

  $ hg init divergence
  $ cd divergence
  $ cat >> .hg/hgrc << EOF
  > [extensions]
  > strip =
  > [alias]
  > strip = strip --no-backup --quiet
  > [templates]
  > instabilities = '{rev}:{node|short} {desc|firstline}{if(instabilities," ({instabilities})")}\n'
  > EOF

  $ hg debugdrawdag <<EOF
  >   e   f
  >   |   |
  >   d'  d # replace: d -> d'
  >    \ /
  >     c
  >     |
  >   x b
  >    \|
  >     a
  > EOF
  1 new orphan changesets
  $ hg log -G -r 'a'::
  *  7:1143e9adc121 f
  |
  | o  6:d60ebfa0f1cb e
  | |
  | o  5:027ad6c5830d d'
  | |
  x |  4:76be324c128b d (rewritten using replace as 5:027ad6c5830d)
  |/
  o  3:a82ac2b38757 c
  |
  | o  2:630d7c95eff7 x
  | |
  o |  1:488e1b7e7341 b
  |/
  o  0:b173517d0057 a
  

Changeset d and its descendants are excluded to avoid divergence of d, which
would occur because the successor of d (d') is also in rebaseset. As a
consequence f (descendant of d) is left behind.

  $ hg rebase -b 'e' -d 'x'
  rebasing 1:488e1b7e7341 "b" (b)
  rebasing 3:a82ac2b38757 "c" (c)
  rebasing 5:027ad6c5830d "d'" (d')
  rebasing 6:d60ebfa0f1cb "e" (e)
  note: not rebasing 4:76be324c128b "d" (d) and its descendants as this would cause divergence
  $ hg log -G -r 'a'::
  o  11:eb6d63fc4ed5 e
  |
  o  10:44d8c724a70c d'
  |
  o  9:d008e6b4d3fd c
  |
  o  8:67e8f4a16c49 b
  |
  | *  7:1143e9adc121 f
  | |
  | | x  6:d60ebfa0f1cb e (rewritten using rebase as 11:eb6d63fc4ed5)
  | | |
  | | x  5:027ad6c5830d d' (rewritten using rebase as 10:44d8c724a70c)
  | | |
  | x |  4:76be324c128b d (rewritten using replace as 5:027ad6c5830d)
  | |/
  | x  3:a82ac2b38757 c (rewritten using rebase as 9:d008e6b4d3fd)
  | |
  o |  2:630d7c95eff7 x
  | |
  | x  1:488e1b7e7341 b (rewritten using rebase as 8:67e8f4a16c49)
  |/
  o  0:b173517d0057 a
  
  $ hg strip -r 8:
  $ hg log -G -r 'a'::
  *  7:1143e9adc121 f
  |
  | o  6:d60ebfa0f1cb e
  | |
  | o  5:027ad6c5830d d'
  | |
  x |  4:76be324c128b d (rewritten using replace as 5:027ad6c5830d)
  |/
  o  3:a82ac2b38757 c
  |
  | o  2:630d7c95eff7 x
  | |
  o |  1:488e1b7e7341 b
  |/
  o  0:b173517d0057 a
  

If the rebase set has an obsolete (d) with a successor (d') outside the rebase
set and none in destination, we still get the divergence warning.
By allowing divergence, we can perform the rebase.

  $ hg rebase -r 'c'::'f' -d 'x'
  abort: this rebase will cause divergences from: 76be324c128b
  (to force the rebase please set experimental.evolution.allowdivergence=True)
  [255]
  $ hg rebase --config experimental.evolution.allowdivergence=true -r 'c'::'f' -d 'x'
  rebasing 3:a82ac2b38757 "c" (c)
  rebasing 4:76be324c128b "d" (d)
  rebasing 7:1143e9adc121 "f" (f tip)
  1 new orphan changesets
  2 new content-divergent changesets
  $ hg log -G -r 'a':: -T instabilities
  o  10:e1744ea07510 f
  |
  *  9:e2b36ea9a0a0 d (content-divergent)
  |
  o  8:6a0376de376e c
  |
  | x  7:1143e9adc121 f
  | |
  | | *  6:d60ebfa0f1cb e (orphan)
  | | |
  | | *  5:027ad6c5830d d' (orphan content-divergent)
  | | |
  | x |  4:76be324c128b d
  | |/
  | x  3:a82ac2b38757 c
  | |
  o |  2:630d7c95eff7 x
  | |
  | o  1:488e1b7e7341 b
  |/
  o  0:b173517d0057 a
  
  $ hg strip -r 8:

(Not skipping obsoletes means that divergence is allowed.)

  $ hg rebase --config experimental.rebaseskipobsolete=false -r 'c'::'f' -d 'x'
  rebasing 3:a82ac2b38757 "c" (c)
  rebasing 4:76be324c128b "d" (d)
  rebasing 7:1143e9adc121 "f" (f tip)
  1 new orphan changesets
  2 new content-divergent changesets

  $ hg strip -r 0:

Similar test on a more complex graph

  $ hg debugdrawdag <<EOF
  >       g
  >       |
  >   f   e
  >   |   |
  >   e'  d # replace: e -> e'
  >    \ /
  >     c
  >     |
  >   x b
  >    \|
  >     a
  > EOF
  1 new orphan changesets
  $ hg log -G -r 'a':
  *  8:2876ce66c6eb g
  |
  | o  7:3ffec603ab53 f
  | |
  x |  6:e36fae928aec e (rewritten using replace as 5:63324dc512ea)
  | |
  | o  5:63324dc512ea e'
  | |
  o |  4:76be324c128b d
  |/
  o  3:a82ac2b38757 c
  |
  | o  2:630d7c95eff7 x
  | |
  o |  1:488e1b7e7341 b
  |/
  o  0:b173517d0057 a
  
  $ hg rebase -b 'f' -d 'x'
  rebasing 1:488e1b7e7341 "b" (b)
  rebasing 3:a82ac2b38757 "c" (c)
  rebasing 5:63324dc512ea "e'" (e')
  rebasing 7:3ffec603ab53 "f" (f)
  rebasing 4:76be324c128b "d" (d)
  note: not rebasing 6:e36fae928aec "e" (e) and its descendants as this would cause divergence
  $ hg log -G -r 'a':
  o  13:a1707a5b7c2c d
  |
  | o  12:ef6251596616 f
  | |
  | o  11:b6f172e64af9 e'
  |/
  o  10:d008e6b4d3fd c
  |
  o  9:67e8f4a16c49 b
  |
  | *  8:2876ce66c6eb g
  | |
  | | x  7:3ffec603ab53 f (rewritten using rebase as 12:ef6251596616)
  | | |
  | x |  6:e36fae928aec e (rewritten using replace as 5:63324dc512ea)
  | | |
  | | x  5:63324dc512ea e' (rewritten using rebase as 11:b6f172e64af9)
  | | |
  | x |  4:76be324c128b d (rewritten using rebase as 13:a1707a5b7c2c)
  | |/
  | x  3:a82ac2b38757 c (rewritten using rebase as 10:d008e6b4d3fd)
  | |
  o |  2:630d7c95eff7 x
  | |
  | x  1:488e1b7e7341 b (rewritten using rebase as 9:67e8f4a16c49)
  |/
  o  0:b173517d0057 a
  

issue5782
  $ hg strip -r 0:
  $ hg debugdrawdag <<EOF
  >       d
  >       |
  >   c1  c # replace: c -> c1
  >    \ /
  >     b
  >     |
  >     a
  > EOF
  1 new orphan changesets
  $ hg debugobsolete `hg log -T "{node}" --hidden -r 'desc("c1")'`
  obsoleted 1 changesets
  $ hg log -G -r 'a': --hidden
  *  4:76be324c128b d
  |
  | x  3:ef8a456de8fa c1 (pruned)
  | |
  x |  2:a82ac2b38757 c (rewritten using replace as 3:ef8a456de8fa)
  |/
  o  1:488e1b7e7341 b
  |
  o  0:b173517d0057 a
  
  $ hg rebase -d 0 -r 2
  rebasing 2:a82ac2b38757 "c" (c)
  $ hg log -G -r 'a': --hidden
  o  5:69ad416a4a26 c
  |
  | *  4:76be324c128b d
  | |
  | | x  3:ef8a456de8fa c1 (pruned)
  | | |
  | x |  2:a82ac2b38757 c (rewritten using replace as 3:ef8a456de8fa rewritten using rebase as 5:69ad416a4a26)
  | |/
  | o  1:488e1b7e7341 b
  |/
  o  0:b173517d0057 a
  
  $ cd ..

Rebase merge where successor of one parent is equal to destination (issue5198)

  $ hg init p1-succ-is-dest
  $ cd p1-succ-is-dest

  $ hg debugdrawdag <<EOF
  >   F
  >  /|
  > E D B # replace: D -> B
  >  \|/
  >   A
  > EOF
  1 new orphan changesets

  $ hg rebase -d B -s D
  note: not rebasing 2:b18e25de2cf5 "D" (D), already in destination as 1:112478962961 "B" (B)
  rebasing 4:66f1a38021c9 "F" (F tip)
  $ hg log -G
  o    5:50e9d60b99c6 F
  |\
  | | x  4:66f1a38021c9 F (rewritten using rebase as 5:50e9d60b99c6)
  | |/|
  | o |  3:7fb047a69f22 E
  | | |
  | | x  2:b18e25de2cf5 D (rewritten using replace as 1:112478962961)
  | |/
  o |  1:112478962961 B
  |/
  o  0:426bada5c675 A
  
  $ cd ..

Rebase merge where successor of other parent is equal to destination

  $ hg init p2-succ-is-dest
  $ cd p2-succ-is-dest

  $ hg debugdrawdag <<EOF
  >   F
  >  /|
  > E D B # replace: E -> B
  >  \|/
  >   A
  > EOF
  1 new orphan changesets

  $ hg rebase -d B -s E
  note: not rebasing 3:7fb047a69f22 "E" (E), already in destination as 1:112478962961 "B" (B)
  rebasing 4:66f1a38021c9 "F" (F tip)
  $ hg log -G
  o    5:aae1787dacee F
  |\
  | | x  4:66f1a38021c9 F (rewritten using rebase as 5:aae1787dacee)
  | |/|
  | | x  3:7fb047a69f22 E (rewritten using replace as 1:112478962961)
  | | |
  | o |  2:b18e25de2cf5 D
  | |/
  o /  1:112478962961 B
  |/
  o  0:426bada5c675 A
  
  $ cd ..

Rebase merge where successor of one parent is ancestor of destination

  $ hg init p1-succ-in-dest
  $ cd p1-succ-in-dest

  $ hg debugdrawdag <<EOF
  >   F C
  >  /| |
  > E D B # replace: D -> B
  >  \|/
  >   A
  > EOF
  1 new orphan changesets

  $ hg rebase -d C -s D
  note: not rebasing 2:b18e25de2cf5 "D" (D), already in destination as 1:112478962961 "B" (B)
  rebasing 5:66f1a38021c9 "F" (F tip)

  $ hg log -G
  o    6:0913febf6439 F
  |\
  +---x  5:66f1a38021c9 F (rewritten using rebase as 6:0913febf6439)
  | | |
  | o |  4:26805aba1e60 C
  | | |
  o | |  3:7fb047a69f22 E
  | | |
  +---x  2:b18e25de2cf5 D (rewritten using replace as 1:112478962961)
  | |
  | o  1:112478962961 B
  |/
  o  0:426bada5c675 A
  
  $ cd ..

Rebase merge where successor of other parent is ancestor of destination

  $ hg init p2-succ-in-dest
  $ cd p2-succ-in-dest

  $ hg debugdrawdag <<EOF
  >   F C
  >  /| |
  > E D B # replace: E -> B
  >  \|/
  >   A
  > EOF
  1 new orphan changesets

  $ hg rebase -d C -s E
  note: not rebasing 3:7fb047a69f22 "E" (E), already in destination as 1:112478962961 "B" (B)
  rebasing 5:66f1a38021c9 "F" (F tip)
  $ hg log -G
  o    6:c6ab0cc6d220 F
  |\
  +---x  5:66f1a38021c9 F (rewritten using rebase as 6:c6ab0cc6d220)
  | | |
  | o |  4:26805aba1e60 C
  | | |
  | | x  3:7fb047a69f22 E (rewritten using replace as 1:112478962961)
  | | |
  o---+  2:b18e25de2cf5 D
   / /
  o /  1:112478962961 B
  |/
  o  0:426bada5c675 A
  
  $ cd ..

Rebase merge where successor of one parent is ancestor of destination

  $ hg init p1-succ-in-dest-b
  $ cd p1-succ-in-dest-b

  $ hg debugdrawdag <<EOF
  >   F C
  >  /| |
  > E D B # replace: E -> B
  >  \|/
  >   A
  > EOF
  1 new orphan changesets

  $ hg rebase -d C -b F
  rebasing 2:b18e25de2cf5 "D" (D)
  note: not rebasing 3:7fb047a69f22 "E" (E), already in destination as 1:112478962961 "B" (B)
  rebasing 5:66f1a38021c9 "F" (F tip)
  note: not rebasing 5:66f1a38021c9 "F" (F tip), its destination already has all its changes
  $ hg log -G
  o  6:8f47515dda15 D
  |
  | x    5:66f1a38021c9 F (pruned using rebase)
  | |\
  o | |  4:26805aba1e60 C
  | | |
  | | x  3:7fb047a69f22 E (rewritten using replace as 1:112478962961)
  | | |
  | x |  2:b18e25de2cf5 D (rewritten using rebase as 6:8f47515dda15)
  | |/
  o /  1:112478962961 B
  |/
  o  0:426bada5c675 A
  
  $ cd ..

Rebase merge where successor of other parent is ancestor of destination

  $ hg init p2-succ-in-dest-b
  $ cd p2-succ-in-dest-b

  $ hg debugdrawdag <<EOF
  >   F C
  >  /| |
  > E D B # replace: D -> B
  >  \|/
  >   A
  > EOF
  1 new orphan changesets

  $ hg rebase -d C -b F
  note: not rebasing 2:b18e25de2cf5 "D" (D), already in destination as 1:112478962961 "B" (B)
  rebasing 3:7fb047a69f22 "E" (E)
  rebasing 5:66f1a38021c9 "F" (F tip)
  note: not rebasing 5:66f1a38021c9 "F" (F tip), its destination already has all its changes

  $ hg log -G
  o  6:533690786a86 E
  |
  | x    5:66f1a38021c9 F (pruned using rebase)
  | |\
  o | |  4:26805aba1e60 C
  | | |
  | | x  3:7fb047a69f22 E (rewritten using rebase as 6:533690786a86)
  | | |
  | x |  2:b18e25de2cf5 D (rewritten using replace as 1:112478962961)
  | |/
  o /  1:112478962961 B
  |/
  o  0:426bada5c675 A
  
  $ cd ..

Rebase merge where extinct node has successor that is not an ancestor of
destination

  $ hg init extinct-with-succ-not-in-dest
  $ cd extinct-with-succ-not-in-dest

  $ hg debugdrawdag <<EOF
  > E C # replace: C -> E
  > | |
  > D B
  > |/
  > A
  > EOF

  $ hg rebase -d D -s B
  rebasing 1:112478962961 "B" (B)
  note: not rebasing 3:26805aba1e60 "C" (C) and its descendants as this would cause divergence

  $ cd ..

  $ hg init p2-succ-in-dest-c
  $ cd p2-succ-in-dest-c

The scenario here was that B::D were developed on default.  B was queued on
stable, but amended before being push to hg-committed.  C was queued on default,
along with unrelated J.

  $ hg debugdrawdag <<EOF
  > J
  > |
  > F
  > |
  > E
  > | D
  > | |
  > | C      # replace: C -> F
  > | |  H I # replace: B -> H -> I
  > | B  |/
  > |/   G
  > A
  > EOF
  1 new orphan changesets

This strip seems to be the key to avoid an early divergence warning.
  $ hg --config extensions.strip= --hidden strip -qr H
  1 new orphan changesets

  $ hg rebase -b 'desc("D")' -d 'desc("J")'
  abort: this rebase will cause divergences from: 112478962961
  (to force the rebase please set experimental.evolution.allowdivergence=True)
  [255]

Rebase merge where both parents have successors in destination

  $ hg init p12-succ-in-dest
  $ cd p12-succ-in-dest
  $ hg debugdrawdag <<'EOS'
  >   E   F
  >  /|  /|  # replace: A -> C
  > A B C D  # replace: B -> D
  > | |
  > X Y
  > EOS
  1 new orphan changesets
  $ hg rebase -r A+B+E -d F
  note: not rebasing 4:a3d17304151f "A" (A), already in destination as 0:96cc3511f894 "C" (C)
  note: not rebasing 5:b23a2cc00842 "B" (B), already in destination as 1:058c1e1fb10a "D" (D)
  rebasing 7:dac5d11c5a7d "E" (E tip)
  abort: rebasing 7:dac5d11c5a7d will include unwanted changes from 3:59c792af609c, 5:b23a2cc00842 or 2:ba2b7fa7166d, 4:a3d17304151f
  [255]
  $ cd ..

Rebase a non-clean merge. One parent has successor in destination, the other
parent moves as requested.

  $ hg init p1-succ-p2-move
  $ cd p1-succ-p2-move
  $ hg debugdrawdag <<'EOS'
  >   D Z
  >  /| | # replace: A -> C
  > A B C # D/D = D
  > EOS
  1 new orphan changesets
  $ hg rebase -r A+B+D -d Z
  note: not rebasing 0:426bada5c675 "A" (A), already in destination as 2:96cc3511f894 "C" (C)
  rebasing 1:fc2b737bb2e5 "B" (B)
  rebasing 3:b8ed089c80ad "D" (D)

  $ rm .hg/localtags
  $ hg log -G
  o  6:e4f78693cc88 D
  |
  o  5:76840d832e98 B
  |
  o  4:50e41c1f3950 Z
  |
  o  2:96cc3511f894 C
  
  $ hg files -r tip
  B
  C
  D
  Z

  $ cd ..

  $ hg init p1-move-p2-succ
  $ cd p1-move-p2-succ
  $ hg debugdrawdag <<'EOS'
  >   D Z
  >  /| |  # replace: B -> C
  > A B C  # D/D = D
  > EOS
  1 new orphan changesets
  $ hg rebase -r B+A+D -d Z
  rebasing 0:426bada5c675 "A" (A)
  note: not rebasing 1:fc2b737bb2e5 "B" (B), already in destination as 2:96cc3511f894 "C" (C)
  rebasing 3:b8ed089c80ad "D" (D)

  $ rm .hg/localtags
  $ hg log -G
  o  6:1b355ed94d82 D
  |
  o  5:a81a74d764a6 A
  |
  o  4:50e41c1f3950 Z
  |
  o  2:96cc3511f894 C
  
  $ hg files -r tip
  A
  C
  D
  Z

  $ cd ..

Test that bookmark is moved and working dir is updated when all changesets have
equivalents in destination
  $ hg init rbsrepo && cd rbsrepo
  $ echo "[experimental]" > .hg/hgrc
  $ echo "evolution=true" >> .hg/hgrc
  $ echo "rebaseskipobsolete=on" >> .hg/hgrc
  $ echo root > root && hg ci -Am root
  adding root
  $ echo a > a && hg ci -Am a
  adding a
  $ hg up 0
  0 files updated, 0 files merged, 1 files removed, 0 files unresolved
  $ echo b > b && hg ci -Am b
  adding b
  created new head
  $ hg rebase -r 2 -d 1
  rebasing 2:1e9a3c00cbe9 "b" (tip)
  $ hg log -r .  # working dir is at rev 3 (successor of 2)
  3:be1832deae9a b (no-eol)
  $ hg book -r 2 mybook --hidden  # rev 2 has a bookmark on it now
  bookmarking hidden changeset 1e9a3c00cbe9
  (hidden revision '1e9a3c00cbe9' was rewritten as: be1832deae9a)
  $ hg up 2 && hg log -r .  # working dir is at rev 2 again
  0 files updated, 0 files merged, 1 files removed, 0 files unresolved
  2:1e9a3c00cbe9 b (rewritten using rebase as 3:be1832deae9a) (no-eol)
  $ hg rebase -r 2 -d 3 --config experimental.evolution.track-operation=1
  note: not rebasing 2:1e9a3c00cbe9 "b" (mybook), already in destination as 3:be1832deae9a "b" (tip)
Check that working directory and bookmark was updated to rev 3 although rev 2
was skipped
  $ hg log -r .
  3:be1832deae9a b (no-eol)
  $ hg bookmarks
     mybook                    3:be1832deae9a
  $ hg debugobsolete --rev tip
  1e9a3c00cbe90d236ac05ef61efcc5e40b7412bc be1832deae9ac531caa7438b8dcf6055a122cd8e 0 (Thu Jan 01 00:00:00 1970 +0000) {'ef1': '4', 'operation': 'rebase', 'user': 'test'}

Obsoleted working parent and bookmark could be moved if an ancestor of working
parent gets moved:

  $ hg init $TESTTMP/ancestor-wd-move
  $ cd $TESTTMP/ancestor-wd-move
  $ hg debugdrawdag <<'EOS'
  >  E D1  # rebase: D1 -> D2
  >  | |
  >  | C
  > D2 |
  >  | B
  >  |/
  >  A
  > EOS
  $ hg update D1 -q
  $ hg bookmark book -i
  $ hg rebase -r B+D1 -d E
  rebasing 1:112478962961 "B" (B)
  note: not rebasing 5:15ecf15e0114 "D1" (book D1 tip), already in destination as 2:0807738e0be9 "D2" (D2)
  1 new orphan changesets
  $ hg log -G -T '{desc} {bookmarks}'
  @  B book
  |
  | x  D1
  | |
  o |  E
  | |
  | *  C
  | |
  o |  D2
  | |
  | x  B
  |/
  o  A
  
Rebasing a merge with one of its parent having a hidden successor

  $ hg init $TESTTMP/merge-p1-hidden-successor
  $ cd $TESTTMP/merge-p1-hidden-successor

  $ hg debugdrawdag <<'EOS'
  >  E
  >  |
  > B3 B2 # amend: B1 -> B2 -> B3
  >  |/   # B2 is hidden
  >  |  D
  >  |  |\
  >  | B1 C
  >  |/
  >  A
  > EOS
  1 new orphan changesets

  $ eval `hg tags -T '{tag}={node}\n'`
  $ rm .hg/localtags

  $ hg rebase -r $D -d $E
  rebasing 5:9e62094e4d94 "D"

  $ hg log -G
  o    7:a699d059adcf D
  |\
  | o  6:ecc93090a95c E
  | |
  | o  4:0dc878468a23 B3
  | |
  o |  1:96cc3511f894 C
   /
  o  0:426bada5c675 A
  
For some reasons (--hidden, rebaseskipobsolete=0, directaccess, etc.),
rebasestate may contain hidden hashes. "rebase --abort" should work regardless.

  $ hg init $TESTTMP/hidden-state1
  $ cd $TESTTMP/hidden-state1
  $ cat >> .hg/hgrc <<EOF
  > [experimental]
  > rebaseskipobsolete=0
  > EOF

  $ hg debugdrawdag <<'EOS'
  >    C
  >    |
  >  D B # prune: B, C
  >  |/  # B/D=B
  >  A
  > EOS

  $ eval `hg tags -T '{tag}={node}\n'`
  $ rm .hg/localtags

  $ hg update -q $C --hidden
  updated to hidden changeset 7829726be4dc
  (hidden revision '7829726be4dc' is pruned)
  $ hg rebase -s $B -d $D
  rebasing 1:2ec65233581b "B"
  merging D
  warning: conflicts while merging D! (edit, then use 'hg resolve --mark')
  unresolved conflicts (see hg resolve, then hg rebase --continue)
  [1]

  $ cp -R . $TESTTMP/hidden-state2

  $ hg log -G
  @  2:b18e25de2cf5 D
  |
  | @  1:2ec65233581b B (pruned using prune)
  |/
  o  0:426bada5c675 A
  
  $ hg summary
  parent: 2:b18e25de2cf5 tip
   D
  parent: 1:2ec65233581b  (obsolete)
   B
  branch: default
  commit: 2 modified, 1 unknown, 1 unresolved (merge)
  update: (current)
  phases: 3 draft
  rebase: 0 rebased, 2 remaining (rebase --continue)

  $ hg rebase --abort
  rebase aborted

Also test --continue for the above case

  $ cd $TESTTMP/hidden-state2
  $ hg resolve -m
  (no more unresolved files)
  continue: hg rebase --continue
  $ hg rebase --continue
  rebasing 1:2ec65233581b "B"
  rebasing 3:7829726be4dc "C" (tip)
  $ hg log -G
  @  5:1964d5d5b547 C
  |
  o  4:68deb90c12a2 B
  |
  o  2:b18e25de2cf5 D
  |
  o  0:426bada5c675 A
  
====================
Test --stop option |
====================
  $ cd ..
  $ hg init rbstop
  $ cd rbstop
  $ echo a>a
  $ hg ci -Aqma
  $ echo b>b
  $ hg ci -Aqmb
  $ echo c>c
  $ hg ci -Aqmc
  $ echo d>d
  $ hg ci -Aqmd
  $ hg up 0 -q
  $ echo f>f
  $ hg ci -Aqmf
  $ echo D>d
  $ hg ci -Aqm "conflict with d"
  $ hg up 3 -q
  $ hg log -G --template "{rev}:{short(node)} {person(author)}\n{firstline(desc)} {topic}\n\n"
  o  5:00bfc9898aeb test
  |  conflict with d
  |
  o  4:dafd40200f93 test
  |  f
  |
  | @  3:055a42cdd887 test
  | |  d
  | |
  | o  2:177f92b77385 test
  | |  c
  | |
  | o  1:d2ae7f538514 test
  |/   b
  |
  o  0:cb9a9f314b8b test
     a
  
  $ hg rebase -s 1 -d 5
  rebasing 1:d2ae7f538514 "b"
  rebasing 2:177f92b77385 "c"
  rebasing 3:055a42cdd887 "d"
  merging d
  warning: conflicts while merging d! (edit, then use 'hg resolve --mark')
  unresolved conflicts (see hg resolve, then hg rebase --continue)
  [1]
  $ hg rebase --stop
  1 new orphan changesets
  $ hg log -G --template "{rev}:{short(node)} {person(author)}\n{firstline(desc)} {topic}\n\n"
  o  7:7fffad344617 test
  |  c
  |
  o  6:b15528633407 test
  |  b
  |
  o  5:00bfc9898aeb test
  |  conflict with d
  |
  o  4:dafd40200f93 test
  |  f
  |
  | @  3:055a42cdd887 test
  | |  d
  | |
  | x  2:177f92b77385 test
  | |  c
  | |
  | x  1:d2ae7f538514 test
  |/   b
  |
  o  0:cb9a9f314b8b test
     a
  
Test it aborts if unstable csets is not allowed:
===============================================
  $ cat >> $HGRCPATH << EOF
  > [experimental]
  > evolution.allowunstable=False
  > EOF

  $ hg strip 6 --no-backup -q
  $ hg log -G --template "{rev}:{short(node)} {person(author)}\n{firstline(desc)} {topic}\n\n"
  o  5:00bfc9898aeb test
  |  conflict with d
  |
  o  4:dafd40200f93 test
  |  f
  |
  | @  3:055a42cdd887 test
  | |  d
  | |
  | o  2:177f92b77385 test
  | |  c
  | |
  | o  1:d2ae7f538514 test
  |/   b
  |
  o  0:cb9a9f314b8b test
     a
  
  $ hg rebase -s 1 -d 5
  rebasing 1:d2ae7f538514 "b"
  rebasing 2:177f92b77385 "c"
  rebasing 3:055a42cdd887 "d"
  merging d
  warning: conflicts while merging d! (edit, then use 'hg resolve --mark')
  unresolved conflicts (see hg resolve, then hg rebase --continue)
  [1]
  $ hg rebase --stop
  abort: cannot remove original changesets with unrebased descendants
  (either enable obsmarkers to allow unstable revisions or use --keep to keep original changesets)
  [255]
  $ hg rebase --abort
  saved backup bundle to $TESTTMP/rbstop/.hg/strip-backup/b15528633407-6eb72b6f-backup.hg
  rebase aborted

Test --stop when --keep is passed:
==================================
  $ hg rebase -s 1 -d 5 --keep
  rebasing 1:d2ae7f538514 "b"
  rebasing 2:177f92b77385 "c"
  rebasing 3:055a42cdd887 "d"
  merging d
  warning: conflicts while merging d! (edit, then use 'hg resolve --mark')
  unresolved conflicts (see hg resolve, then hg rebase --continue)
  [1]
  $ hg rebase --stop
  $ hg log -G --template "{rev}:{short(node)} {person(author)}\n{firstline(desc)} {topic}\n\n"
  o  7:7fffad344617 test
  |  c
  |
  o  6:b15528633407 test
  |  b
  |
  o  5:00bfc9898aeb test
  |  conflict with d
  |
  o  4:dafd40200f93 test
  |  f
  |
  | @  3:055a42cdd887 test
  | |  d
  | |
  | o  2:177f92b77385 test
  | |  c
  | |
  | o  1:d2ae7f538514 test
  |/   b
  |
  o  0:cb9a9f314b8b test
     a
  
Test --stop aborts when --collapse was passed:
=============================================
  $ cat >> $HGRCPATH << EOF
  > [experimental]
  > evolution.allowunstable=True
  > EOF

  $ hg strip 6
  saved backup bundle to $TESTTMP/rbstop/.hg/strip-backup/b15528633407-6eb72b6f-backup.hg
  $ hg log -G --template "{rev}:{short(node)} {person(author)}\n{firstline(desc)} {topic}\n\n"
  o  5:00bfc9898aeb test
  |  conflict with d
  |
  o  4:dafd40200f93 test
  |  f
  |
  | @  3:055a42cdd887 test
  | |  d
  | |
  | o  2:177f92b77385 test
  | |  c
  | |
  | o  1:d2ae7f538514 test
  |/   b
  |
  o  0:cb9a9f314b8b test
     a
  
  $ hg rebase -s 1 -d 5 --collapse -m "collapsed b c d"
  rebasing 1:d2ae7f538514 "b"
  rebasing 2:177f92b77385 "c"
  rebasing 3:055a42cdd887 "d"
  merging d
  warning: conflicts while merging d! (edit, then use 'hg resolve --mark')
  unresolved conflicts (see hg resolve, then hg rebase --continue)
  [1]
  $ hg rebase --stop
  abort: cannot stop in --collapse session
  [255]
  $ hg rebase --abort
  rebase aborted
  $ hg diff
  $ hg log -G --template "{rev}:{short(node)} {person(author)}\n{firstline(desc)} {topic}\n\n"
  o  5:00bfc9898aeb test
  |  conflict with d
  |
  o  4:dafd40200f93 test
  |  f
  |
  | @  3:055a42cdd887 test
  | |  d
  | |
  | o  2:177f92b77385 test
  | |  c
  | |
  | o  1:d2ae7f538514 test
  |/   b
  |
  o  0:cb9a9f314b8b test
     a
  
Test --stop raise errors with conflicting options:
=================================================
  $ hg rebase -s 3 -d 5
  rebasing 3:055a42cdd887 "d"
  merging d
  warning: conflicts while merging d! (edit, then use 'hg resolve --mark')
  unresolved conflicts (see hg resolve, then hg rebase --continue)
  [1]
  $ hg rebase --stop --dry-run
  abort: cannot specify both --dry-run and --stop
  [255]

  $ hg rebase -s 3 -d 5
  abort: rebase in progress
  (use 'hg rebase --continue' or 'hg rebase --abort')
  [255]
  $ hg rebase --stop --continue
  abort: cannot use --stop with --continue
  [255]

Test --stop moves bookmarks of original revisions to new rebased nodes:
======================================================================
  $ cd ..
  $ hg init repo
  $ cd repo

  $ echo a > a
  $ hg ci -Am A
  adding a

  $ echo b > b
  $ hg ci -Am B
  adding b
  $ hg book X
  $ hg book Y

  $ echo c > c
  $ hg ci -Am C
  adding c
  $ hg book Z

  $ echo d > d
  $ hg ci -Am D
  adding d

  $ hg up 0 -q
  $ echo e > e
  $ hg ci -Am E
  adding e
  created new head

  $ echo doubt > d
  $ hg ci -Am "conflict with d"
  adding d

  $ hg log -GT "{rev}: {node|short} '{desc}' bookmarks: {bookmarks}\n"
  @  5: 39adf30bc1be 'conflict with d' bookmarks:
  |
  o  4: 9c1e55f411b6 'E' bookmarks:
  |
  | o  3: 67a385d4e6f2 'D' bookmarks: Z
  | |
  | o  2: 49cb3485fa0c 'C' bookmarks: Y
  | |
  | o  1: 6c81ed0049f8 'B' bookmarks: X
  |/
  o  0: 1994f17a630e 'A' bookmarks:
  
  $ hg rebase -s 1 -d 5
  rebasing 1:6c81ed0049f8 "B" (X)
  rebasing 2:49cb3485fa0c "C" (Y)
  rebasing 3:67a385d4e6f2 "D" (Z)
  merging d
  warning: conflicts while merging d! (edit, then use 'hg resolve --mark')
  unresolved conflicts (see hg resolve, then hg rebase --continue)
  [1]
  $ hg rebase --stop
  1 new orphan changesets
  $ hg log -GT "{rev}: {node|short} '{desc}' bookmarks: {bookmarks}\n"
  o  7: 9c86c650b686 'C' bookmarks: Y
  |
  o  6: 9b87b54e5fd8 'B' bookmarks: X
  |
  @  5: 39adf30bc1be 'conflict with d' bookmarks:
  |
  o  4: 9c1e55f411b6 'E' bookmarks:
  |
  | *  3: 67a385d4e6f2 'D' bookmarks: Z
  | |
  | x  2: 49cb3485fa0c 'C' bookmarks:
  | |
  | x  1: 6c81ed0049f8 'B' bookmarks:
  |/
  o  0: 1994f17a630e 'A' bookmarks:
  
