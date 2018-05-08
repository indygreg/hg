This test file test the various messages when accessing obsolete
revisions.

Global setup
============

  $ . $TESTDIR/testlib/obsmarker-common.sh
  $ cat >> $HGRCPATH <<EOF
  > [ui]
  > interactive = true
  > [phases]
  > publish=False
  > [experimental]
  > evolution.createmarkers = yes
  > evolution.effect-flags = yes
  > EOF

Test output on amended commit
=============================

Test setup
----------

  $ hg init $TESTTMP/local-amend
  $ cd $TESTTMP/local-amend
  $ mkcommit ROOT
  $ mkcommit A0
  $ echo 42 >> A0
  $ hg commit --amend -m "A1
  > 
  > Better commit message"
  $ hg log --hidden -G
  @  changeset:   2:4ae3a4151de9
  |  tag:         tip
  |  parent:      0:ea207398892e
  |  user:        test
  |  date:        Thu Jan 01 00:00:00 1970 +0000
  |  summary:     A1
  |
  | x  changeset:   1:471f378eab4c
  |/   user:        test
  |    date:        Thu Jan 01 00:00:00 1970 +0000
  |    obsolete:    rewritten using amend as 2:4ae3a4151de9
  |    summary:     A0
  |
  o  changeset:   0:ea207398892e
     user:        test
     date:        Thu Jan 01 00:00:00 1970 +0000
     summary:     ROOT
  
Actual test
-----------
  $ hg update 471f378eab4c
  abort: hidden revision '471f378eab4c' was rewritten as: 4ae3a4151de9!
  (use --hidden to access hidden revisions)
  [255]
  $ hg update --hidden "desc(A0)"
  1 files updated, 0 files merged, 0 files removed, 0 files unresolved
  updated to hidden changeset 471f378eab4c
  (hidden revision '471f378eab4c' was rewritten as: 4ae3a4151de9)

Test output with pruned commit
==============================

Test setup
----------

  $ hg init $TESTTMP/local-prune
  $ cd $TESTTMP/local-prune
  $ mkcommit ROOT
  $ mkcommit A0 # 0
  $ mkcommit B0 # 1
  $ hg log --hidden -G
  @  changeset:   2:0dec01379d3b
  |  tag:         tip
  |  user:        test
  |  date:        Thu Jan 01 00:00:00 1970 +0000
  |  summary:     B0
  |
  o  changeset:   1:471f378eab4c
  |  user:        test
  |  date:        Thu Jan 01 00:00:00 1970 +0000
  |  summary:     A0
  |
  o  changeset:   0:ea207398892e
     user:        test
     date:        Thu Jan 01 00:00:00 1970 +0000
     summary:     ROOT
  
  $ hg debugobsolete --record-parents `getid 'desc(B0)'`
  obsoleted 1 changesets

  $ hg log --hidden -G
  @  changeset:   2:0dec01379d3b
  |  tag:         tip
  |  user:        test
  |  date:        Thu Jan 01 00:00:00 1970 +0000
  |  obsolete:    pruned
  |  summary:     B0
  |
  o  changeset:   1:471f378eab4c
  |  user:        test
  |  date:        Thu Jan 01 00:00:00 1970 +0000
  |  summary:     A0
  |
  o  changeset:   0:ea207398892e
     user:        test
     date:        Thu Jan 01 00:00:00 1970 +0000
     summary:     ROOT
  

Actual test
-----------
  $ hg up 1
  0 files updated, 0 files merged, 1 files removed, 0 files unresolved
  $ hg up 0dec01379d3b
  abort: hidden revision '0dec01379d3b' is pruned!
  (use --hidden to access hidden revisions)
  [255]
  $ hg up --hidden -r 'desc(B0)'
  1 files updated, 0 files merged, 0 files removed, 0 files unresolved
  updated to hidden changeset 0dec01379d3b
  (hidden revision '0dec01379d3b' is pruned)

Test output with splitted commit
================================

Test setup
----------

  $ hg init $TESTTMP/local-split
  $ cd $TESTTMP/local-split
  $ mkcommit ROOT
  $ echo 42 >> a
  $ echo 43 >> b
  $ hg commit -A -m "A0"
  adding a
  adding b
  $ hg log --hidden -G
  @  changeset:   1:471597cad322
  |  tag:         tip
  |  user:        test
  |  date:        Thu Jan 01 00:00:00 1970 +0000
  |  summary:     A0
  |
  o  changeset:   0:ea207398892e
     user:        test
     date:        Thu Jan 01 00:00:00 1970 +0000
     summary:     ROOT
  
# Simulate a split
  $ hg up 0
  0 files updated, 0 files merged, 2 files removed, 0 files unresolved

  $ echo 42 >> a
  $ hg commit -A -m "A0"
  adding a
  created new head

  $ echo 43 >> b
  $ hg commit -A -m "A0"
  adding b

  $ hg debugobsolete `getid '1'` `getid '2'` `getid '3'`
  obsoleted 1 changesets

  $ hg log --hidden -G
  @  changeset:   3:f257fde29c7a
  |  tag:         tip
  |  user:        test
  |  date:        Thu Jan 01 00:00:00 1970 +0000
  |  summary:     A0
  |
  o  changeset:   2:337fec4d2edc
  |  parent:      0:ea207398892e
  |  user:        test
  |  date:        Thu Jan 01 00:00:00 1970 +0000
  |  summary:     A0
  |
  | x  changeset:   1:471597cad322
  |/   user:        test
  |    date:        Thu Jan 01 00:00:00 1970 +0000
  |    obsolete:    split as 2:337fec4d2edc, 3:f257fde29c7a
  |    summary:     A0
  |
  o  changeset:   0:ea207398892e
     user:        test
     date:        Thu Jan 01 00:00:00 1970 +0000
     summary:     ROOT
  
Actual test
-----------
  $ hg update 471597cad322
  abort: hidden revision '471597cad322' was split as: 337fec4d2edc, f257fde29c7a!
  (use --hidden to access hidden revisions)
  [255]
  $ hg update --hidden 'min(desc(A0))'
  0 files updated, 0 files merged, 0 files removed, 0 files unresolved
  updated to hidden changeset 471597cad322
  (hidden revision '471597cad322' was split as: 337fec4d2edc, f257fde29c7a)

Test output with lots of splitted commit
========================================

Test setup
----------

  $ hg init $TESTTMP/local-lots-split
  $ cd $TESTTMP/local-lots-split
  $ mkcommit ROOT
  $ echo 42 >> a
  $ echo 43 >> b
  $ echo 44 >> c
  $ echo 45 >> d
  $ hg commit -A -m "A0"
  adding a
  adding b
  adding c
  adding d
  $ hg log --hidden -G
  @  changeset:   1:de7290d8b885
  |  tag:         tip
  |  user:        test
  |  date:        Thu Jan 01 00:00:00 1970 +0000
  |  summary:     A0
  |
  o  changeset:   0:ea207398892e
     user:        test
     date:        Thu Jan 01 00:00:00 1970 +0000
     summary:     ROOT
  
# Simulate a split
  $ hg up 0
  0 files updated, 0 files merged, 4 files removed, 0 files unresolved

  $ echo 42 >> a
  $ hg commit -A -m "A0"
  adding a
  created new head

  $ echo 43 >> b
  $ hg commit -A -m "A0"
  adding b

  $ echo 44 >> c
  $ hg commit -A -m "A0"
  adding c

  $ echo 45 >> d
  $ hg commit -A -m "A0"
  adding d

  $ hg debugobsolete `getid '1'` `getid '2'` `getid '3'` `getid '4'` `getid '5'`
  obsoleted 1 changesets

  $ hg log --hidden -G
  @  changeset:   5:c7f044602e9b
  |  tag:         tip
  |  user:        test
  |  date:        Thu Jan 01 00:00:00 1970 +0000
  |  summary:     A0
  |
  o  changeset:   4:1ae8bc733a14
  |  user:        test
  |  date:        Thu Jan 01 00:00:00 1970 +0000
  |  summary:     A0
  |
  o  changeset:   3:f257fde29c7a
  |  user:        test
  |  date:        Thu Jan 01 00:00:00 1970 +0000
  |  summary:     A0
  |
  o  changeset:   2:337fec4d2edc
  |  parent:      0:ea207398892e
  |  user:        test
  |  date:        Thu Jan 01 00:00:00 1970 +0000
  |  summary:     A0
  |
  | x  changeset:   1:de7290d8b885
  |/   user:        test
  |    date:        Thu Jan 01 00:00:00 1970 +0000
  |    obsolete:    split as 2:337fec4d2edc, 3:f257fde29c7a, 4:1ae8bc733a14, 5:c7f044602e9b
  |    summary:     A0
  |
  o  changeset:   0:ea207398892e
     user:        test
     date:        Thu Jan 01 00:00:00 1970 +0000
     summary:     ROOT
  
Actual test
-----------
  $ hg update de7290d8b885
  abort: hidden revision 'de7290d8b885' was split as: 337fec4d2edc, f257fde29c7a and 2 more!
  (use --hidden to access hidden revisions)
  [255]
  $ hg update --hidden 'min(desc(A0))'
  0 files updated, 0 files merged, 0 files removed, 0 files unresolved
  updated to hidden changeset de7290d8b885
  (hidden revision 'de7290d8b885' was split as: 337fec4d2edc, f257fde29c7a and 2 more)

Test output with folded commit
==============================

Test setup
----------

  $ hg init $TESTTMP/local-fold
  $ cd $TESTTMP/local-fold
  $ mkcommit ROOT
  $ mkcommit A0
  $ mkcommit B0
  $ hg log --hidden -G
  @  changeset:   2:0dec01379d3b
  |  tag:         tip
  |  user:        test
  |  date:        Thu Jan 01 00:00:00 1970 +0000
  |  summary:     B0
  |
  o  changeset:   1:471f378eab4c
  |  user:        test
  |  date:        Thu Jan 01 00:00:00 1970 +0000
  |  summary:     A0
  |
  o  changeset:   0:ea207398892e
     user:        test
     date:        Thu Jan 01 00:00:00 1970 +0000
     summary:     ROOT
  
# Simulate a fold
  $ hg up 0
  0 files updated, 0 files merged, 2 files removed, 0 files unresolved
  $ echo "A0" > A0
  $ echo "B0" > B0
  $ hg add A0 B0
  $ hg commit -m "C0"
  created new head

  $ hg debugobsolete `getid 'desc(A0)'` `getid 'desc(C0)'`
  obsoleted 1 changesets
  1 new orphan changesets
  $ hg debugobsolete `getid 'desc(B0)'` `getid 'desc(C0)'`
  obsoleted 1 changesets

  $ hg log --hidden -G
  @  changeset:   3:eb5a0daa2192
  |  tag:         tip
  |  parent:      0:ea207398892e
  |  user:        test
  |  date:        Thu Jan 01 00:00:00 1970 +0000
  |  summary:     C0
  |
  | x  changeset:   2:0dec01379d3b
  | |  user:        test
  | |  date:        Thu Jan 01 00:00:00 1970 +0000
  | |  obsolete:    rewritten as 3:eb5a0daa2192
  | |  summary:     B0
  | |
  | x  changeset:   1:471f378eab4c
  |/   user:        test
  |    date:        Thu Jan 01 00:00:00 1970 +0000
  |    obsolete:    rewritten as 3:eb5a0daa2192
  |    summary:     A0
  |
  o  changeset:   0:ea207398892e
     user:        test
     date:        Thu Jan 01 00:00:00 1970 +0000
     summary:     ROOT
  
 Actual test
 -----------
  $ hg update 471f378eab4c
  abort: hidden revision '471f378eab4c' was rewritten as: eb5a0daa2192!
  (use --hidden to access hidden revisions)
  [255]
  $ hg update --hidden 'desc(A0)'
  0 files updated, 0 files merged, 1 files removed, 0 files unresolved
  updated to hidden changeset 471f378eab4c
  (hidden revision '471f378eab4c' was rewritten as: eb5a0daa2192)
  $ hg update 0dec01379d3b
  abort: hidden revision '0dec01379d3b' was rewritten as: eb5a0daa2192!
  (use --hidden to access hidden revisions)
  [255]
  $ hg update --hidden 'desc(B0)'
  1 files updated, 0 files merged, 0 files removed, 0 files unresolved
  updated to hidden changeset 0dec01379d3b
  (hidden revision '0dec01379d3b' was rewritten as: eb5a0daa2192)

Test output with divergence
===========================

Test setup
----------

  $ hg init $TESTTMP/local-divergence
  $ cd $TESTTMP/local-divergence
  $ mkcommit ROOT
  $ mkcommit A0
  $ hg commit --amend -m "A1"
  $ hg log --hidden -G
  @  changeset:   2:fdf9bde5129a
  |  tag:         tip
  |  parent:      0:ea207398892e
  |  user:        test
  |  date:        Thu Jan 01 00:00:00 1970 +0000
  |  summary:     A1
  |
  | x  changeset:   1:471f378eab4c
  |/   user:        test
  |    date:        Thu Jan 01 00:00:00 1970 +0000
  |    obsolete:    rewritten using amend as 2:fdf9bde5129a
  |    summary:     A0
  |
  o  changeset:   0:ea207398892e
     user:        test
     date:        Thu Jan 01 00:00:00 1970 +0000
     summary:     ROOT
  
  $ hg update --hidden 'desc(A0)'
  0 files updated, 0 files merged, 0 files removed, 0 files unresolved
  updated to hidden changeset 471f378eab4c
  (hidden revision '471f378eab4c' was rewritten as: fdf9bde5129a)
  $ hg commit --amend -m "A2"
  2 new content-divergent changesets
  $ hg log --hidden -G
  @  changeset:   3:65b757b745b9
  |  tag:         tip
  |  parent:      0:ea207398892e
  |  user:        test
  |  date:        Thu Jan 01 00:00:00 1970 +0000
  |  instability: content-divergent
  |  summary:     A2
  |
  | *  changeset:   2:fdf9bde5129a
  |/   parent:      0:ea207398892e
  |    user:        test
  |    date:        Thu Jan 01 00:00:00 1970 +0000
  |    instability: content-divergent
  |    summary:     A1
  |
  | x  changeset:   1:471f378eab4c
  |/   user:        test
  |    date:        Thu Jan 01 00:00:00 1970 +0000
  |    obsolete:    rewritten using amend as 2:fdf9bde5129a
  |    obsolete:    rewritten using amend as 3:65b757b745b9
  |    summary:     A0
  |
  o  changeset:   0:ea207398892e
     user:        test
     date:        Thu Jan 01 00:00:00 1970 +0000
     summary:     ROOT
  
Actual test
-----------
  $ hg update 471f378eab4c
  abort: hidden revision '471f378eab4c' has diverged!
  (use --hidden to access hidden revisions)
  [255]
  $ hg update --hidden 'desc(A0)'
  0 files updated, 0 files merged, 0 files removed, 0 files unresolved
  updated to hidden changeset 471f378eab4c
  (hidden revision '471f378eab4c' has diverged)

Test output with amended + folded commit
========================================

Test setup
----------

  $ hg init $TESTTMP/local-amend-fold
  $ cd $TESTTMP/local-amend-fold
  $ mkcommit ROOT
  $ mkcommit A0
  $ mkcommit B0
  $ hg commit --amend -m "B1"
  $ hg log --hidden -G
  @  changeset:   3:b7ea6d14e664
  |  tag:         tip
  |  parent:      1:471f378eab4c
  |  user:        test
  |  date:        Thu Jan 01 00:00:00 1970 +0000
  |  summary:     B1
  |
  | x  changeset:   2:0dec01379d3b
  |/   user:        test
  |    date:        Thu Jan 01 00:00:00 1970 +0000
  |    obsolete:    rewritten using amend as 3:b7ea6d14e664
  |    summary:     B0
  |
  o  changeset:   1:471f378eab4c
  |  user:        test
  |  date:        Thu Jan 01 00:00:00 1970 +0000
  |  summary:     A0
  |
  o  changeset:   0:ea207398892e
     user:        test
     date:        Thu Jan 01 00:00:00 1970 +0000
     summary:     ROOT
  

# Simulate a fold
  $ hg up 0
  0 files updated, 0 files merged, 2 files removed, 0 files unresolved
  $ echo "A0" > A0
  $ echo "B0" > B0
  $ hg add A0 B0
  $ hg commit -m "C0"
  created new head

  $ hg debugobsolete `getid 'desc(A0)'` `getid 'desc(C0)'`
  obsoleted 1 changesets
  1 new orphan changesets
  $ hg debugobsolete `getid 'desc(B1)'` `getid 'desc(C0)'`
  obsoleted 1 changesets

  $ hg log --hidden -G
  @  changeset:   4:eb5a0daa2192
  |  tag:         tip
  |  parent:      0:ea207398892e
  |  user:        test
  |  date:        Thu Jan 01 00:00:00 1970 +0000
  |  summary:     C0
  |
  | x  changeset:   3:b7ea6d14e664
  | |  parent:      1:471f378eab4c
  | |  user:        test
  | |  date:        Thu Jan 01 00:00:00 1970 +0000
  | |  obsolete:    rewritten as 4:eb5a0daa2192
  | |  summary:     B1
  | |
  | | x  changeset:   2:0dec01379d3b
  | |/   user:        test
  | |    date:        Thu Jan 01 00:00:00 1970 +0000
  | |    obsolete:    rewritten using amend as 3:b7ea6d14e664
  | |    summary:     B0
  | |
  | x  changeset:   1:471f378eab4c
  |/   user:        test
  |    date:        Thu Jan 01 00:00:00 1970 +0000
  |    obsolete:    rewritten as 4:eb5a0daa2192
  |    summary:     A0
  |
  o  changeset:   0:ea207398892e
     user:        test
     date:        Thu Jan 01 00:00:00 1970 +0000
     summary:     ROOT
  
 Actual test
 -----------
  $ hg update 471f378eab4c
  abort: hidden revision '471f378eab4c' was rewritten as: eb5a0daa2192!
  (use --hidden to access hidden revisions)
  [255]
  $ hg update --hidden 'desc(A0)'
  0 files updated, 0 files merged, 1 files removed, 0 files unresolved
  updated to hidden changeset 471f378eab4c
  (hidden revision '471f378eab4c' was rewritten as: eb5a0daa2192)
  $ hg update --hidden 0dec01379d3b
  1 files updated, 0 files merged, 0 files removed, 0 files unresolved
  updated to hidden changeset 0dec01379d3b
  (hidden revision '0dec01379d3b' was rewritten as: eb5a0daa2192)
  $ hg update 0dec01379d3b
  0 files updated, 0 files merged, 0 files removed, 0 files unresolved
  $ hg update --hidden 'desc(B0)'
  0 files updated, 0 files merged, 0 files removed, 0 files unresolved
