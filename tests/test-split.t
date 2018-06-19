#testcases obsstore-on obsstore-off

  $ cat > $TESTTMP/editor.py <<EOF
  > #!$PYTHON
  > import os
  > import sys
  > path = os.path.join(os.environ['TESTTMP'], 'messages')
  > messages = open(path).read().split('--\n')
  > prompt = open(sys.argv[1]).read()
  > sys.stdout.write(''.join('EDITOR: %s' % l for l in prompt.splitlines(True)))
  > sys.stdout.flush()
  > with open(sys.argv[1], 'w') as f:
  >    f.write(messages[0])
  > with open(path, 'w') as f:
  >    f.write('--\n'.join(messages[1:]))
  > EOF

  $ cat >> $HGRCPATH <<EOF
  > [extensions]
  > drawdag=$TESTDIR/drawdag.py
  > split=
  > [ui]
  > interactive=1
  > color=no
  > paginate=never
  > [diff]
  > git=1
  > unified=0
  > [alias]
  > glog=log -G -T '{rev}:{node|short} {desc} {bookmarks}\n'
  > EOF

#if obsstore-on
  $ cat >> $HGRCPATH <<EOF
  > [experimental]
  > evolution=all
  > EOF
#endif

  $ hg init a
  $ cd a

Nothing to split

  $ hg split
  nothing to split
  [1]

  $ hg commit -m empty --config ui.allowemptycommit=1
  $ hg split
  abort: cannot split an empty revision
  [255]

  $ rm -rf .hg
  $ hg init

Cannot split working directory

  $ hg split -r 'wdir()'
  abort: cannot split working directory
  [255]

Generate some content.  The sed filter drop CR on Windows, which is dropped in
the a > b line.

  $ $TESTDIR/seq.py 1 5 | sed 's/\r$//' >> a
  $ hg ci -m a1 -A a -q
  $ hg bookmark -i r1
  $ sed 's/1/11/;s/3/33/;s/5/55/' a > b
  $ mv b a
  $ hg ci -m a2 -q
  $ hg bookmark -i r2

Cannot split a public changeset

  $ hg phase --public -r 'all()'
  $ hg split .
  abort: cannot split public changeset
  (see 'hg help phases' for details)
  [255]

  $ hg phase --draft -f -r 'all()'

Cannot split while working directory is dirty

  $ touch dirty
  $ hg add dirty
  $ hg split .
  abort: uncommitted changes
  [255]
  $ hg forget dirty
  $ rm dirty

Make a clean directory for future tests to build off of

  $ cp -R . ../clean

Split a head

  $ hg bookmark r3

  $ hg split 'all()'
  abort: cannot split multiple revisions
  [255]

  $ runsplit() {
  > cat > $TESTTMP/messages <<EOF
  > split 1
  > --
  > split 2
  > --
  > split 3
  > EOF
  > cat <<EOF | hg split "$@"
  > y
  > y
  > y
  > y
  > y
  > y
  > EOF
  > }

  $ HGEDITOR=false runsplit
  diff --git a/a b/a
  1 hunks, 1 lines changed
  examine changes to 'a'? [Ynesfdaq?] y
  
  @@ -5,1 +5,1 @@ 4
  -5
  +55
  record this change to 'a'? [Ynesfdaq?] y
  
  transaction abort!
  rollback completed
  abort: edit failed: false exited with status 1
  [255]
  $ hg status

  $ HGEDITOR="\"$PYTHON\" $TESTTMP/editor.py"
  $ runsplit
  diff --git a/a b/a
  1 hunks, 1 lines changed
  examine changes to 'a'? [Ynesfdaq?] y
  
  @@ -5,1 +5,1 @@ 4
  -5
  +55
  record this change to 'a'? [Ynesfdaq?] y
  
  EDITOR: HG: Splitting 1df0d5c5a3ab. Write commit message for the first split changeset.
  EDITOR: a2
  EDITOR: 
  EDITOR: 
  EDITOR: HG: Enter commit message.  Lines beginning with 'HG:' are removed.
  EDITOR: HG: Leave message empty to abort commit.
  EDITOR: HG: --
  EDITOR: HG: user: test
  EDITOR: HG: branch 'default'
  EDITOR: HG: changed a
  created new head
  diff --git a/a b/a
  1 hunks, 1 lines changed
  examine changes to 'a'? [Ynesfdaq?] y
  
  @@ -3,1 +3,1 @@ 2
  -3
  +33
  record this change to 'a'? [Ynesfdaq?] y
  
  EDITOR: HG: Splitting 1df0d5c5a3ab. So far it has been split into:
  EDITOR: HG: - e704349bd21b: split 1
  EDITOR: HG: Write commit message for the next split changeset.
  EDITOR: a2
  EDITOR: 
  EDITOR: 
  EDITOR: HG: Enter commit message.  Lines beginning with 'HG:' are removed.
  EDITOR: HG: Leave message empty to abort commit.
  EDITOR: HG: --
  EDITOR: HG: user: test
  EDITOR: HG: branch 'default'
  EDITOR: HG: changed a
  diff --git a/a b/a
  1 hunks, 1 lines changed
  examine changes to 'a'? [Ynesfdaq?] y
  
  @@ -1,1 +1,1 @@
  -1
  +11
  record this change to 'a'? [Ynesfdaq?] y
  
  EDITOR: HG: Splitting 1df0d5c5a3ab. So far it has been split into:
  EDITOR: HG: - e704349bd21b: split 1
  EDITOR: HG: - a09ad58faae3: split 2
  EDITOR: HG: Write commit message for the next split changeset.
  EDITOR: a2
  EDITOR: 
  EDITOR: 
  EDITOR: HG: Enter commit message.  Lines beginning with 'HG:' are removed.
  EDITOR: HG: Leave message empty to abort commit.
  EDITOR: HG: --
  EDITOR: HG: user: test
  EDITOR: HG: branch 'default'
  EDITOR: HG: changed a
  saved backup bundle to $TESTTMP/a/.hg/strip-backup/1df0d5c5a3ab-8341b760-split.hg (obsstore-off !)

#if obsstore-off
  $ hg bookmark
     r1                        0:a61bcde8c529
     r2                        3:00eebaf8d2e2
   * r3                        3:00eebaf8d2e2
  $ hg glog -p
  @  3:00eebaf8d2e2 split 3 r2 r3
  |  diff --git a/a b/a
  |  --- a/a
  |  +++ b/a
  |  @@ -1,1 +1,1 @@
  |  -1
  |  +11
  |
  o  2:a09ad58faae3 split 2
  |  diff --git a/a b/a
  |  --- a/a
  |  +++ b/a
  |  @@ -3,1 +3,1 @@
  |  -3
  |  +33
  |
  o  1:e704349bd21b split 1
  |  diff --git a/a b/a
  |  --- a/a
  |  +++ b/a
  |  @@ -5,1 +5,1 @@
  |  -5
  |  +55
  |
  o  0:a61bcde8c529 a1 r1
     diff --git a/a b/a
     new file mode 100644
     --- /dev/null
     +++ b/a
     @@ -0,0 +1,5 @@
     +1
     +2
     +3
     +4
     +5
  
#else
  $ hg bookmark
     r1                        0:a61bcde8c529
     r2                        4:00eebaf8d2e2
   * r3                        4:00eebaf8d2e2
  $ hg glog
  @  4:00eebaf8d2e2 split 3 r2 r3
  |
  o  3:a09ad58faae3 split 2
  |
  o  2:e704349bd21b split 1
  |
  o  0:a61bcde8c529 a1 r1
  
#endif

Split a head while working parent is not that head

  $ cp -R $TESTTMP/clean $TESTTMP/b
  $ cd $TESTTMP/b

  $ hg up 0 -q
  $ hg bookmark r3

  $ runsplit tip >/dev/null

#if obsstore-off
  $ hg bookmark
     r1                        0:a61bcde8c529
     r2                        3:00eebaf8d2e2
   * r3                        0:a61bcde8c529
  $ hg glog
  o  3:00eebaf8d2e2 split 3 r2
  |
  o  2:a09ad58faae3 split 2
  |
  o  1:e704349bd21b split 1
  |
  @  0:a61bcde8c529 a1 r1 r3
  
#else
  $ hg bookmark
     r1                        0:a61bcde8c529
     r2                        4:00eebaf8d2e2
   * r3                        0:a61bcde8c529
  $ hg glog
  o  4:00eebaf8d2e2 split 3 r2
  |
  o  3:a09ad58faae3 split 2
  |
  o  2:e704349bd21b split 1
  |
  @  0:a61bcde8c529 a1 r1 r3
  
#endif

Split a non-head

  $ cp -R $TESTTMP/clean $TESTTMP/c
  $ cd $TESTTMP/c
  $ echo d > d
  $ hg ci -m d1 -A d
  $ hg bookmark -i d1
  $ echo 2 >> d
  $ hg ci -m d2
  $ echo 3 >> d
  $ hg ci -m d3
  $ hg bookmark -i d3
  $ hg up '.^' -q
  $ hg bookmark d2
  $ cp -R . ../d

  $ runsplit -r 1 | grep rebasing
  rebasing 2:b5c5ea414030 "d1" (d1)
  rebasing 3:f4a0a8d004cc "d2" (d2)
  rebasing 4:777940761eba "d3" (d3)
#if obsstore-off
  $ hg bookmark
     d1                        4:c4b449ef030e
   * d2                        5:c9dd00ab36a3
     d3                        6:19f476bc865c
     r1                        0:a61bcde8c529
     r2                        3:00eebaf8d2e2
  $ hg glog -p
  o  6:19f476bc865c d3 d3
  |  diff --git a/d b/d
  |  --- a/d
  |  +++ b/d
  |  @@ -2,0 +3,1 @@
  |  +3
  |
  @  5:c9dd00ab36a3 d2 d2
  |  diff --git a/d b/d
  |  --- a/d
  |  +++ b/d
  |  @@ -1,0 +2,1 @@
  |  +2
  |
  o  4:c4b449ef030e d1 d1
  |  diff --git a/d b/d
  |  new file mode 100644
  |  --- /dev/null
  |  +++ b/d
  |  @@ -0,0 +1,1 @@
  |  +d
  |
  o  3:00eebaf8d2e2 split 3 r2
  |  diff --git a/a b/a
  |  --- a/a
  |  +++ b/a
  |  @@ -1,1 +1,1 @@
  |  -1
  |  +11
  |
  o  2:a09ad58faae3 split 2
  |  diff --git a/a b/a
  |  --- a/a
  |  +++ b/a
  |  @@ -3,1 +3,1 @@
  |  -3
  |  +33
  |
  o  1:e704349bd21b split 1
  |  diff --git a/a b/a
  |  --- a/a
  |  +++ b/a
  |  @@ -5,1 +5,1 @@
  |  -5
  |  +55
  |
  o  0:a61bcde8c529 a1 r1
     diff --git a/a b/a
     new file mode 100644
     --- /dev/null
     +++ b/a
     @@ -0,0 +1,5 @@
     +1
     +2
     +3
     +4
     +5
  
#else
  $ hg bookmark
     d1                        8:c4b449ef030e
   * d2                        9:c9dd00ab36a3
     d3                        10:19f476bc865c
     r1                        0:a61bcde8c529
     r2                        7:00eebaf8d2e2
  $ hg glog
  o  10:19f476bc865c d3 d3
  |
  @  9:c9dd00ab36a3 d2 d2
  |
  o  8:c4b449ef030e d1 d1
  |
  o  7:00eebaf8d2e2 split 3 r2
  |
  o  6:a09ad58faae3 split 2
  |
  o  5:e704349bd21b split 1
  |
  o  0:a61bcde8c529 a1 r1
  
#endif

Split a non-head without rebase

  $ cd $TESTTMP/d
#if obsstore-off
  $ runsplit -r 1 --no-rebase
  abort: cannot split changeset with children without rebase
  [255]
#else
  $ runsplit -r 1 --no-rebase >/dev/null
  3 new orphan changesets
  $ hg bookmark
     d1                        2:b5c5ea414030
   * d2                        3:f4a0a8d004cc
     d3                        4:777940761eba
     r1                        0:a61bcde8c529
     r2                        7:00eebaf8d2e2

  $ hg glog
  o  7:00eebaf8d2e2 split 3 r2
  |
  o  6:a09ad58faae3 split 2
  |
  o  5:e704349bd21b split 1
  |
  | *  4:777940761eba d3 d3
  | |
  | @  3:f4a0a8d004cc d2 d2
  | |
  | *  2:b5c5ea414030 d1 d1
  | |
  | x  1:1df0d5c5a3ab a2
  |/
  o  0:a61bcde8c529 a1 r1
  
#endif

Split a non-head with obsoleted descendants

#if obsstore-on
  $ hg init $TESTTMP/e
  $ cd $TESTTMP/e
  $ hg debugdrawdag <<'EOS'
  >   H I   J
  >   | |   |
  >   F G1 G2  # amend: G1 -> G2
  >   | |  /   # prune: F
  >   C D E
  >    \|/
  >     B
  >     |
  >     A
  > EOS
  2 new orphan changesets
  $ eval `hg tags -T '{tag}={node}\n'`
  $ rm .hg/localtags
  $ hg split $B --config experimental.evolution=createmarkers
  abort: split would leave orphaned changesets behind
  [255]
  $ cat > $TESTTMP/messages <<EOF
  > Split B
  > EOF
  $ cat <<EOF | hg split $B
  > y
  > y
  > EOF
  diff --git a/B b/B
  new file mode 100644
  examine changes to 'B'? [Ynesfdaq?] y
  
  @@ -0,0 +1,1 @@
  +B
  \ No newline at end of file
  record this change to 'B'? [Ynesfdaq?] y
  
  EDITOR: HG: Splitting 112478962961. Write commit message for the first split changeset.
  EDITOR: B
  EDITOR: 
  EDITOR: 
  EDITOR: HG: Enter commit message.  Lines beginning with 'HG:' are removed.
  EDITOR: HG: Leave message empty to abort commit.
  EDITOR: HG: --
  EDITOR: HG: user: test
  EDITOR: HG: branch 'default'
  EDITOR: HG: added B
  created new head
  rebasing 2:26805aba1e60 "C"
  rebasing 3:be0ef73c17ad "D"
  rebasing 4:49cb92066bfd "E"
  rebasing 7:97a6268cc7ef "G2"
  rebasing 10:e2f1e425c0db "J"
  $ hg glog -r 'sort(all(), topo)'
  o  16:556c085f8b52 J
  |
  o  15:8761f6c9123f G2
  |
  o  14:a7aeffe59b65 E
  |
  | o  13:e1e914ede9ab D
  |/
  | o  12:01947e9b98aa C
  |/
  o  11:0947baa74d47 Split B
  |
  | *  9:88ede1d5ee13 I
  | |
  | x  6:af8cbf225b7b G1
  | |
  | x  3:be0ef73c17ad D
  | |
  | | *  8:74863e5b5074 H
  | | |
  | | x  5:ee481a2a1e69 F
  | | |
  | | x  2:26805aba1e60 C
  | |/
  | x  1:112478962961 B
  |/
  o  0:426bada5c675 A
  
#endif

Preserve secret phase in split

  $ cp -R $TESTTMP/clean $TESTTMP/phases1
  $ cd $TESTTMP/phases1
  $ hg phase --secret -fr tip
  $ hg log -T '{short(node)} {phase}\n'
  1df0d5c5a3ab secret
  a61bcde8c529 draft
  $ runsplit tip >/dev/null
  $ hg log -T '{short(node)} {phase}\n'
  00eebaf8d2e2 secret
  a09ad58faae3 secret
  e704349bd21b secret
  a61bcde8c529 draft

Do not move things to secret even if phases.new-commit=secret

  $ cp -R $TESTTMP/clean $TESTTMP/phases2
  $ cd $TESTTMP/phases2
  $ cat >> .hg/hgrc <<EOF
  > [phases]
  > new-commit=secret
  > EOF
  $ hg log -T '{short(node)} {phase}\n'
  1df0d5c5a3ab draft
  a61bcde8c529 draft
  $ runsplit tip >/dev/null
  $ hg log -T '{short(node)} {phase}\n'
  00eebaf8d2e2 draft
  a09ad58faae3 draft
  e704349bd21b draft
  a61bcde8c529 draft
