#require killdaemons

Preparing the subrepository 'sub'

  $ hg init sub
  $ echo sub > sub/sub
  $ hg add -R sub
  adding sub/sub
  $ hg commit -R sub -m "sub import"

Preparing the 'main' repo which depends on the subrepo 'sub'

  $ hg init main
  $ echo main > main/main
  $ echo "sub = ../sub" > main/.hgsub
  $ hg clone sub main/sub
  updating to branch default
  1 files updated, 0 files merged, 0 files removed, 0 files unresolved
  $ hg add -R main
  adding main/.hgsub
  adding main/main
  $ hg commit -R main -m "main import"

Cleaning both repositories, just as a clone -U

  $ hg up -C -R sub null
  0 files updated, 0 files merged, 1 files removed, 0 files unresolved
  $ hg up -C -R main null
  0 files updated, 0 files merged, 3 files removed, 0 files unresolved
  $ rm -rf main/sub

hide outer repo
  $ hg init

Serving them both using hgweb

  $ printf '[paths]\n/main = main\nsub = sub\n' > webdir.conf
  $ hg serve --webdir-conf webdir.conf -a localhost -p $HGPORT \
  >    -A /dev/null -E /dev/null --pid-file hg.pid -d
  $ cat hg.pid >> $DAEMON_PIDS

Clone main from hgweb

  $ hg clone "http://localhost:$HGPORT/main" cloned
  requesting all changes
  adding changesets
  adding manifests
  adding file changes
  added 1 changesets with 3 changes to 3 files
  new changesets fdfeeb3e979e
  updating to branch default
  cloning subrepo sub from http://localhost:$HGPORT/sub
  requesting all changes
  adding changesets
  adding manifests
  adding file changes
  added 1 changesets with 1 changes to 1 files
  new changesets 863c1745b441
  3 files updated, 0 files merged, 0 files removed, 0 files unresolved

Checking cloned repo ids

  $ hg id -R cloned
  fdfeeb3e979e tip
  $ hg id -R cloned/sub
  863c1745b441 tip

subrepo debug for 'main' clone

  $ hg debugsub -R cloned
  path sub
   source   ../sub
   revision 863c1745b441bd97a8c4a096e87793073f4fb215

Test sharing with a remote URL reference

  $ hg init absolute_subrepo
  $ cd absolute_subrepo
  $ echo foo > foo.txt
  $ hg ci -Am 'initial commit'
  adding foo.txt
  $ echo "sub = http://localhost:$HGPORT/sub" > .hgsub
  $ hg ci -Am 'add absolute subrepo'
  adding .hgsub
  $ cd ..

BUG: Remote subrepos cannot be shared, and pooled repos don't have their
relative subrepos in the relative location stated in .hgsub.

  $ hg --config extensions.share= --config share.pool=$TESTTMP/pool \
  >    clone absolute_subrepo cloned_from_abs
  (sharing from new pooled repository 8d6a2f1e993b34b6557de0042cfe825ae12a8dae)
  requesting all changes
  adding changesets
  adding manifests
  adding file changes
  added 2 changesets with 3 changes to 3 files
  new changesets 8d6a2f1e993b:c6d0e6ebd1c9
  searching for changes
  no changes found
  updating working directory
  sharing subrepo sub from http://localhost:$HGPORT/sub
  abort: can only share local repositories (in subrepository "sub")
  [255]

  $ hg --config extensions.share= share absolute_subrepo shared_from_abs
  updating working directory
  sharing subrepo sub from http://localhost:$HGPORT/sub
  abort: can only share local repositories (in subrepository "sub")
  [255]

  $ hg --config extensions.share= share -U absolute_subrepo shared_from_abs2
  $ hg -R shared_from_abs2 update -r tip
  sharing subrepo sub from http://localhost:$HGPORT/sub
  abort: can only share local repositories (in subrepository "sub")
  [255]

BUG: A repo without its subrepo available locally should be sharable if the
subrepo is referenced by absolute path.

  $ hg clone -U absolute_subrepo cloned_null_from_abs
  $ hg --config extensions.share= share cloned_null_from_abs shared_from_null_abs
  updating working directory
  sharing subrepo sub from http://localhost:$HGPORT/sub
  abort: can only share local repositories (in subrepository "sub")
  [255]

  $ killdaemons.py

subrepo paths with ssh urls

  $ hg clone -e "\"$PYTHON\" \"$TESTDIR/dummyssh\"" ssh://user@dummy/cloned sshclone
  requesting all changes
  adding changesets
  adding manifests
  adding file changes
  added 1 changesets with 3 changes to 3 files
  new changesets fdfeeb3e979e
  updating to branch default
  cloning subrepo sub from ssh://user@dummy/sub
  requesting all changes
  adding changesets
  adding manifests
  adding file changes
  added 1 changesets with 1 changes to 1 files
  new changesets 863c1745b441
  3 files updated, 0 files merged, 0 files removed, 0 files unresolved

  $ hg -R sshclone push -e "\"$PYTHON\" \"$TESTDIR/dummyssh\"" ssh://user@dummy/`pwd`/cloned
  pushing to ssh://user@dummy/$TESTTMP/cloned
  pushing subrepo sub to ssh://user@dummy/$TESTTMP/sub
  searching for changes
  no changes found
  searching for changes
  no changes found
  [1]

  $ cat dummylog
  Got arguments 1:user@dummy 2:hg -R cloned serve --stdio
  Got arguments 1:user@dummy 2:hg -R sub serve --stdio
  Got arguments 1:user@dummy 2:hg -R $TESTTMP/cloned serve --stdio
  Got arguments 1:user@dummy 2:hg -R $TESTTMP/sub serve --stdio
