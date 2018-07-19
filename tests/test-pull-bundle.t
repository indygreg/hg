#require no-chg

  $ hg init repo
  $ cd repo
  $ echo foo > foo
  $ hg ci -qAm 'add foo'
  $ echo >> foo
  $ hg ci -m 'change foo'
  $ hg up -qC 0
  $ echo bar > bar
  $ hg ci -qAm 'add bar'

  $ hg log
  changeset:   2:effea6de0384
  tag:         tip
  parent:      0:bbd179dfa0a7
  user:        test
  date:        Thu Jan 01 00:00:00 1970 +0000
  summary:     add bar
  
  changeset:   1:ed1b79f46b9a
  user:        test
  date:        Thu Jan 01 00:00:00 1970 +0000
  summary:     change foo
  
  changeset:   0:bbd179dfa0a7
  user:        test
  date:        Thu Jan 01 00:00:00 1970 +0000
  summary:     add foo
  
  $ cd ..

Test pullbundle functionality

  $ cd repo
  $ cat <<EOF > .hg/hgrc
  > [server]
  > pullbundle = True
  > [extensions]
  > blackbox =
  > EOF
  $ hg bundle --base null -r 0 .hg/0.hg
  1 changesets found
  $ hg bundle --base 0 -r 1 .hg/1.hg
  1 changesets found
  $ hg bundle --base 1 -r 2 .hg/2.hg
  1 changesets found
  $ cat <<EOF > .hg/pullbundles.manifest
  > 2.hg BUNDLESPEC=none-v2 heads=effea6de0384e684f44435651cb7bd70b8735bd4 bases=bbd179dfa0a71671c253b3ae0aa1513b60d199fa
  > 1.hg BUNDLESPEC=bzip2-v2 heads=ed1b79f46b9a29f5a6efa59cf12fcfca43bead5a bases=bbd179dfa0a71671c253b3ae0aa1513b60d199fa
  > 0.hg BUNDLESPEC=gzip-v2 heads=bbd179dfa0a71671c253b3ae0aa1513b60d199fa
  > EOF
  $ hg --config blackbox.track=debug --debug serve -p $HGPORT2 -d --pid-file=../repo.pid
  listening at http://*:$HGPORT2/ (bound to $LOCALIP:$HGPORT2) (glob) (?)
  $ cat ../repo.pid >> $DAEMON_PIDS
  $ cd ..
  $ hg clone -r 0 http://localhost:$HGPORT2/ repo.pullbundle
  adding changesets
  adding manifests
  adding file changes
  added 1 changesets with 1 changes to 1 files
  new changesets bbd179dfa0a7
  updating to branch default
  1 files updated, 0 files merged, 0 files removed, 0 files unresolved
  $ cd repo.pullbundle
  $ hg pull -r 1
  pulling from http://localhost:$HGPORT2/
  searching for changes
  adding changesets
  adding manifests
  adding file changes
  added 1 changesets with 1 changes to 1 files
  new changesets ed1b79f46b9a
  (run 'hg update' to get a working copy)
  $ hg pull -r 2
  pulling from http://localhost:$HGPORT2/
  searching for changes
  adding changesets
  adding manifests
  adding file changes
  added 1 changesets with 1 changes to 1 files (+1 heads)
  new changesets effea6de0384
  (run 'hg heads' to see heads, 'hg merge' to merge)
  $ cd ..
  $ killdaemons.py
  $ grep 'sending pullbundle ' repo/.hg/blackbox.log
  * sending pullbundle "0.hg" (glob)
  * sending pullbundle "1.hg" (glob)
  * sending pullbundle "2.hg" (glob)
  $ rm repo/.hg/blackbox.log

Test pullbundle functionality for incremental pulls

  $ cd repo
  $ hg --config blackbox.track=debug --debug serve -p $HGPORT2 -d --pid-file=../repo.pid
  listening at http://*:$HGPORT2/ (bound to $LOCALIP:$HGPORT2) (glob) (?)
  $ cat ../repo.pid >> $DAEMON_PIDS
  $ cd ..
  $ hg clone http://localhost:$HGPORT2/ repo.pullbundle2
  requesting all changes
  adding changesets
  adding manifests
  adding file changes
  added 1 changesets with 1 changes to 1 files
  adding changesets
  adding manifests
  adding file changes
  added 1 changesets with 1 changes to 1 files
  adding changesets
  adding manifests
  adding file changes
  added 1 changesets with 1 changes to 1 files (+1 heads)
  new changesets bbd179dfa0a7:ed1b79f46b9a
  updating to branch default
  1 files updated, 0 files merged, 0 files removed, 0 files unresolved
  $ killdaemons.py
  $ grep 'sending pullbundle ' repo/.hg/blackbox.log
  * sending pullbundle "0.hg" (glob)
  * sending pullbundle "2.hg" (glob)
  * sending pullbundle "1.hg" (glob)
  $ rm repo/.hg/blackbox.log

Test recovery from misconfigured server sending no new data

  $ cd repo
  $ cat <<EOF > .hg/pullbundles.manifest
  > 0.hg heads=ed1b79f46b9a29f5a6efa59cf12fcfca43bead5a bases=bbd179dfa0a71671c253b3ae0aa1513b60d199fa
  > 0.hg heads=bbd179dfa0a71671c253b3ae0aa1513b60d199fa
  > EOF
  $ hg --config blackbox.track=debug --debug serve -p $HGPORT2 -d --pid-file=../repo.pid
  listening at http://*:$HGPORT2/ (bound to $LOCALIP:$HGPORT2) (glob) (?)
  $ cat ../repo.pid >> $DAEMON_PIDS
  $ cd ..
  $ hg clone -r 0 http://localhost:$HGPORT2/ repo.pullbundle3
  adding changesets
  adding manifests
  adding file changes
  added 1 changesets with 1 changes to 1 files
  new changesets bbd179dfa0a7
  updating to branch default
  1 files updated, 0 files merged, 0 files removed, 0 files unresolved
  $ cd repo.pullbundle3
  $ hg pull -r 1
  pulling from http://localhost:$HGPORT2/
  searching for changes
  adding changesets
  adding manifests
  adding file changes
  added 0 changesets with 0 changes to 1 files
  abort: 00changelog.i@ed1b79f46b9a: no node!
  [255]
  $ cd ..
  $ killdaemons.py
  $ grep 'sending pullbundle ' repo/.hg/blackbox.log
  * sending pullbundle "0.hg" (glob)
  * sending pullbundle "0.hg" (glob)
  $ rm repo/.hg/blackbox.log
