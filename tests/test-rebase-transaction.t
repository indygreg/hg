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
- We should only see two status stored messages. One from the start, one from
- the end.
  $ hg rebase --debug -b D -d Z | grep 'status stored'
  rebase status stored
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
