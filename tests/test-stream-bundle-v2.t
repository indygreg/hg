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
  $ hg debugbundle bundle.hg
  Stream params: {}
  stream2 -- {bytecount: 1693, filecount: 11, requirements: dotencode%2Cfncache%2Cgeneraldelta%2Crevlogv1%2Cstore}
  $ hg debugbundle --spec bundle.hg
  none-v2;stream=v2;requirements%3Ddotencode%2Cfncache%2Cgeneraldelta%2Crevlogv1%2Cstore
