Test creating a consuming stream bundle v2

  $ getmainid() {
  >    hg -R main log --template '{node}\n' --rev "$1"
  > }

  $ cp $HGRCPATH $TESTTMP/hgrc.orig

  $ cat >> $HGRCPATH << EOF
  > [experimental]
  > evolution.createmarkers=True
  > evolution.exchange=True
  > bundle2-output-capture=True
  > [ui]
  > ssh="$PYTHON" "$TESTDIR/dummyssh"
  > logtemplate={rev}:{node|short} {phase} {author} {bookmarks} {desc|firstline}
  > [web]
  > push_ssl = false
  > allow_push = *
  > [phases]
  > publish=False
  > [extensions]
  > drawdag=$TESTDIR/drawdag.py
  > EOF

The extension requires a repo (currently unused)

  $ hg init main
  $ cd main

  $ hg debugdrawdag <<'EOF'
  > E
  > |
  > D
  > |
  > C
  > |
  > B
  > |
  > A
  > EOF

  $ hg bundle -a --type="none-v2;stream=v2" bundle.hg
  5 changesets found
  $ hg debugbundle bundle.hg
  Stream params: {}
  changegroup -- {nbchanges: 5, version: 02}
      426bada5c67598ca65036d57d9e4b64b0c1ce7a0
      112478962961147124edd43549aedd1a335e44bf
      26805aba1e600a82e93661149f2313866a221a7b
      f585351a92f85104bff7c284233c338b10eb1df7
      9bc730a19041f9ec7cb33c626e811aa233efb18c
  cache:rev-branch-cache -- {}
  $ hg debugbundle --spec bundle.hg
  none-v2
