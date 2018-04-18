#require no-reposimplestore

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
  > clonebundles=
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

Test that we can apply the bundle as a stream clone bundle

  $ cat > .hg/clonebundles.manifest << EOF
  > http://localhost:$HGPORT1/bundle.hg BUNDLESPEC=`hg debugbundle --spec bundle.hg`
  > EOF

  $ hg serve -d -p $HGPORT --pid-file hg.pid --accesslog access.log
  $ cat hg.pid >> $DAEMON_PIDS

  $ "$PYTHON" $TESTDIR/dumbhttp.py -p $HGPORT1 --pid http.pid
  $ cat http.pid >> $DAEMON_PIDS

  $ cd ..
  $ hg clone http://localhost:$HGPORT streamv2-clone-implicit --debug
  using http://localhost:$HGPORT/
  sending capabilities command
  sending clonebundles command
  applying clone bundle from http://localhost:$HGPORT1/bundle.hg
  bundle2-input-bundle: with-transaction
  bundle2-input-part: "stream2" (params: 3 mandatory) supported
  applying stream bundle
  11 files to transfer, 1.65 KB of data
  starting 4 threads for background file closing (?)
  starting 4 threads for background file closing (?)
  adding [s] data/A.i (66 bytes)
  adding [s] data/B.i (66 bytes)
  adding [s] data/C.i (66 bytes)
  adding [s] data/D.i (66 bytes)
  adding [s] data/E.i (66 bytes)
  adding [s] 00manifest.i (584 bytes)
  adding [s] 00changelog.i (595 bytes)
  adding [s] phaseroots (43 bytes)
  adding [c] branch2-served (94 bytes)
  adding [c] rbc-names-v1 (7 bytes)
  adding [c] rbc-revs-v1 (40 bytes)
  transferred 1.65 KB in \d\.\d seconds \(.*/sec\) (re)
  bundle2-input-part: total payload size 1840
  bundle2-input-bundle: 0 parts total
  finished applying clone bundle
  query 1; heads
  sending batch command
  searching for changes
  all remote heads known locally
  no changes found
  sending getbundle command
  bundle2-input-bundle: with-transaction
  bundle2-input-part: "listkeys" (params: 1 mandatory) supported
  bundle2-input-part: "phase-heads" supported
  bundle2-input-part: total payload size 24
  bundle2-input-bundle: 1 parts total
  checking for updated bookmarks
  updating to branch default
  resolving manifests
   branchmerge: False, force: False, partial: False
   ancestor: 000000000000, local: 000000000000+, remote: 9bc730a19041
   A: remote created -> g
  getting A
   B: remote created -> g
  getting B
   C: remote created -> g
  getting C
   D: remote created -> g
  getting D
   E: remote created -> g
  getting E
  5 files updated, 0 files merged, 0 files removed, 0 files unresolved

  $ hg clone --stream http://localhost:$HGPORT streamv2-clone-explicit --debug
  using http://localhost:$HGPORT/
  sending capabilities command
  sending clonebundles command
  applying clone bundle from http://localhost:$HGPORT1/bundle.hg
  bundle2-input-bundle: with-transaction
  bundle2-input-part: "stream2" (params: 3 mandatory) supported
  applying stream bundle
  11 files to transfer, 1.65 KB of data
  starting 4 threads for background file closing (?)
  starting 4 threads for background file closing (?)
  adding [s] data/A.i (66 bytes)
  adding [s] data/B.i (66 bytes)
  adding [s] data/C.i (66 bytes)
  adding [s] data/D.i (66 bytes)
  adding [s] data/E.i (66 bytes)
  adding [s] 00manifest.i (584 bytes)
  adding [s] 00changelog.i (595 bytes)
  adding [s] phaseroots (43 bytes)
  adding [c] branch2-served (94 bytes)
  adding [c] rbc-names-v1 (7 bytes)
  adding [c] rbc-revs-v1 (40 bytes)
  transferred 1.65 KB in *.* seconds (*/sec) (glob)
  bundle2-input-part: total payload size 1840
  bundle2-input-bundle: 0 parts total
  finished applying clone bundle
  query 1; heads
  sending batch command
  searching for changes
  all remote heads known locally
  no changes found
  sending getbundle command
  bundle2-input-bundle: with-transaction
  bundle2-input-part: "listkeys" (params: 1 mandatory) supported
  bundle2-input-part: "phase-heads" supported
  bundle2-input-part: total payload size 24
  bundle2-input-bundle: 1 parts total
  checking for updated bookmarks
  updating to branch default
  resolving manifests
   branchmerge: False, force: False, partial: False
   ancestor: 000000000000, local: 000000000000+, remote: 9bc730a19041
   A: remote created -> g
  getting A
   B: remote created -> g
  getting B
   C: remote created -> g
  getting C
   D: remote created -> g
  getting D
   E: remote created -> g
  getting E
  5 files updated, 0 files merged, 0 files removed, 0 files unresolved
