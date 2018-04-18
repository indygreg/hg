Rebasing using a single transaction

  $ cat >> $HGRCPATH <<EOF
  > [extensions]
  > rebase=
  > drawdag=$TESTDIR/drawdag.py
  > 
  > [rebase]
  > singletransaction=True
  > 
  > [phases]
  > publish=False
  > 
  > [alias]
  > tglog = log -G --template "{rev}: {desc}"
  > EOF

Check that a simple rebase works

  $ hg init simple && cd simple
  $ hg debugdrawdag <<'EOF'
  >   Z
  >   |
  >   | D
  >   | |
  >   | C
  >   | |
  >   Y B
  >   |/
  >   A
  > EOF
- We should only see one status stored message. It comes from the start.
  $ hg rebase --debug -b D -d Z | grep 'status stored'
  rebase status stored
  $ hg tglog
  o  5: D
  |
  o  4: C
  |
  o  3: B
  |
  o  2: Z
  |
  o  1: Y
  |
  o  0: A
  
  $ cd ..

Check that --collapse works

  $ hg init collapse && cd collapse
  $ hg debugdrawdag <<'EOF'
  >   Z
  >   |
  >   | D
  >   | |
  >   | C
  >   | |
  >   Y B
  >   |/
  >   A
  > EOF
- We should only see two status stored messages. One from the start, one from
- cmdutil.commitforceeditor() which forces tr.writepending()
  $ hg rebase --collapse --debug -b D -d Z | grep 'status stored'
  rebase status stored
  rebase status stored
  $ hg tglog
  o  3: Collapsed revision
  |  * B
  |  * C
  |  * D
  o  2: Z
  |
  o  1: Y
  |
  o  0: A
  
  $ cd ..

With --collapse, check that conflicts can be resolved and rebase can then be
continued

  $ hg init collapse-conflict && cd collapse-conflict
  $ hg debugdrawdag <<'EOF'
  >   Z   # Z/conflict=Z
  >   |
  >   | D
  >   | |
  >   | C # C/conflict=C
  >   | |
  >   Y B
  >   |/
  >   A
  > EOF
  $ hg rebase --collapse -b D -d Z
  rebasing 1:112478962961 "B" (B)
  rebasing 3:c26739dbe603 "C" (C)
  merging conflict
  warning: conflicts while merging conflict! (edit, then use 'hg resolve --mark')
  unresolved conflicts (see hg resolve, then hg rebase --continue)
  [1]
  $ hg tglog
  o  5: D
  |
  | @  4: Z
  | |
  @ |  3: C
  | |
  | o  2: Y
  | |
  o |  1: B
  |/
  o  0: A
  
  $ hg st
  M C
  M conflict
  A B
  ? conflict.orig
  $ echo resolved > conflict
  $ hg resolve -m
  (no more unresolved files)
  continue: hg rebase --continue
  $ hg rebase --continue
  already rebased 1:112478962961 "B" (B) as 79bc8f4973ce
  rebasing 3:c26739dbe603 "C" (C)
  rebasing 5:d24bb333861c "D" (D tip)
  saved backup bundle to $TESTTMP/collapse-conflict/.hg/strip-backup/112478962961-b5b34645-rebase.hg
  $ hg tglog
  o  3: Collapsed revision
  |  * B
  |  * C
  |  * D
  o  2: Z
  |
  o  1: Y
  |
  o  0: A
  
  $ cd ..

With --collapse, check that the commit message editing can be canceled and
rebase can then be continued

  $ hg init collapse-cancel-editor && cd collapse-cancel-editor
  $ hg debugdrawdag <<'EOF'
  >   Z
  >   |
  >   | D
  >   | |
  >   | C
  >   | |
  >   Y B
  >   |/
  >   A
  > EOF
  $ HGEDITOR=false hg --config ui.interactive=1 rebase --collapse -b D -d Z
  rebasing 1:112478962961 "B" (B)
  rebasing 3:26805aba1e60 "C" (C)
  rebasing 5:f585351a92f8 "D" (D tip)
  transaction abort!
  rollback completed
  abort: edit failed: false exited with status 1
  [255]
  $ hg tglog
  o  5: D
  |
  | o  4: Z
  | |
  o |  3: C
  | |
  | o  2: Y
  | |
  o |  1: B
  |/
  o  0: A
  
  $ hg rebase --continue
  rebasing 1:112478962961 "B" (B)
  rebasing 3:26805aba1e60 "C" (C)
  rebasing 5:f585351a92f8 "D" (D tip)
  saved backup bundle to $TESTTMP/collapse-cancel-editor/.hg/strip-backup/112478962961-cb2a9b47-rebase.hg
  $ hg tglog
  o  3: Collapsed revision
  |  * B
  |  * C
  |  * D
  o  2: Z
  |
  o  1: Y
  |
  o  0: A
  
  $ cd ..
