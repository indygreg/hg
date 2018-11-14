#testcases lfs-on lfs-off

#if lfs-on
  $ cat >> $HGRCPATH <<EOF
  > [extensions]
  > lfs =
  > EOF
#endif

  $ . "$TESTDIR/narrow-library.sh"

create full repo

  $ hg init master
  $ cd master
  $ cat >> .hg/hgrc <<EOF
  > [narrow]
  > serveellipses=True
  > EOF

  $ mkdir inside
  $ echo 1 > inside/f
  $ mkdir inside2
  $ echo 1 > inside2/f
  $ mkdir outside
  $ echo 1 > outside/f
  $ hg ci -Aqm 'initial'

  $ echo 2 > inside/f
  $ hg ci -qm 'inside 2'

  $ echo 2 > inside2/f
  $ hg ci -qm 'inside2 2'

  $ echo 2 > outside/f
  $ hg ci -qm 'outside 2'

  $ cd ..

  $ hg clone --narrow ssh://user@dummy/master narrow --include inside
  requesting all changes
  adding changesets
  adding manifests
  adding file changes
  added 3 changesets with 2 changes to 1 files
  new changesets *:* (glob)
  updating to branch default
  1 files updated, 0 files merged, 0 files removed, 0 files unresolved

  $ hg clone --narrow ssh://user@dummy/master narrow2 --include inside --include inside2
  requesting all changes
  adding changesets
  adding manifests
  adding file changes
  added 4 changesets with 4 changes to 2 files
  new changesets *:* (glob)
  updating to branch default
  2 files updated, 0 files merged, 0 files removed, 0 files unresolved

Can push to wider repo if change does not affect paths in wider repo that are
not also in narrower repo

  $ cd narrow
  $ echo 3 > inside/f
  $ hg ci -m 'inside 3'
  $ hg push ssh://user@dummy/narrow2
  pushing to ssh://user@dummy/narrow2
  searching for changes
  remote: adding changesets
  remote: adding manifests
  remote: adding file changes
  remote: added 1 changesets with 1 changes to 1 files

Can push to narrower repo if change affects only paths within remote's
narrow spec

  $ cd ../narrow2
  $ cat >> .hg/hgrc <<EOF
  > [narrow]
  > serveellipses=True
  > EOF
  $ hg co -r 'desc("inside 3")'
  1 files updated, 0 files merged, 0 files removed, 0 files unresolved
  $ echo 4 > inside/f
  $ hg ci -m 'inside 4'
  $ hg push ssh://user@dummy/narrow
  pushing to ssh://user@dummy/narrow
  searching for changes
  remote: adding changesets
  remote: adding manifests
  remote: adding file changes
  remote: added 1 changesets with 1 changes to 1 files

Can push to narrow repo if change affects only paths outside remote's
narrow spec

  $ echo 3 > inside2/f
  $ hg ci -m 'inside2 3'
TODO: this should be successful
  $ hg push ssh://user@dummy/narrow
  pushing to ssh://user@dummy/narrow
  searching for changes
  remote: adding changesets
  remote: adding manifests
  remote: adding file changes
  remote: transaction abort!
  remote: rollback completed
  remote: abort: data/inside2/f.i@4a1aa07735e6: unknown parent! (reporevlogstore !)
  remote: abort: data/inside2/f/index@4a1aa07735e6: no node! (reposimplestore !)
  abort: stream ended unexpectedly (got 0 bytes, expected 4)
  [255]

Can pull from wider repo if change affects only paths outside remote's
narrow spec
  $ echo 4 > inside2/f
  $ hg ci -m 'inside2 4'
  $ hg log -G -T '{rev} {node|short} {files}\n'
  @  7 d78a96df731d inside2/f
  |
  o  6 8c26f5218962 inside2/f
  |
  o  5 ba3480e2f9de inside/f
  |
  o  4 4e5edd526618 inside/f
  |
  o  3 81e7e07b7ab0 outside/f
  |
  o  2 f3993b8c0c2b inside2/f
  |
  o  1 8cd66ca966b4 inside/f
  |
  o  0 c8057d6f53ab inside/f inside2/f outside/f
  
  $ cd ../narrow
  $ hg log -G -T '{rev} {node|short} {files}\n'
  o  4 ba3480e2f9de inside/f
  |
  @  3 4e5edd526618 inside/f
  |
  o  2 81e7e07b7ab0 outside/f
  |
  o  1 8cd66ca966b4 inside/f
  |
  o  0 c8057d6f53ab inside/f inside2/f outside/f
  
  $ hg pull ssh://user@dummy/narrow2
  pulling from ssh://user@dummy/narrow2
  searching for changes
  adding changesets
  adding manifests
  adding file changes
  added 1 changesets with 0 changes to 0 files
  new changesets d78a96df731d
  (run 'hg update' to get a working copy)

Check that the resulting history is valid in the full repo

  $ cd ../narrow2
  $ hg push ssh://user@dummy/master
  pushing to ssh://user@dummy/master
  searching for changes
  remote: adding changesets
  remote: adding manifests
  remote: adding file changes
  remote: added 4 changesets with 4 changes to 2 files
  $ cd ../master
  $ hg verify
  checking changesets
  checking manifests
  crosschecking files in changesets and manifests
  checking files
  checked 8 changesets with 10 changes to 3 files

Can not push to wider repo if change affects paths in wider repo that are
not also in narrower repo
  $ cd ../master
  $ hg co -r 'desc("inside2 4")'
  2 files updated, 0 files merged, 0 files removed, 0 files unresolved
  $ echo 5 > inside2/f
  $ hg ci -m 'inside2 5'
  $ hg log -G -T '{rev} {node|short} {files}\n'
  @  8 5970befb64ba inside2/f
  |
  o  7 d78a96df731d inside2/f
  |
  o  6 8c26f5218962 inside2/f
  |
  o  5 ba3480e2f9de inside/f
  |
  o  4 4e5edd526618 inside/f
  |
  o  3 81e7e07b7ab0 outside/f
  |
  o  2 f3993b8c0c2b inside2/f
  |
  o  1 8cd66ca966b4 inside/f
  |
  o  0 c8057d6f53ab inside/f inside2/f outside/f
  
  $ cd ../narrow
  $ hg pull
  pulling from ssh://user@dummy/master
  searching for changes
  adding changesets
  adding manifests
  adding file changes
  added 1 changesets with 0 changes to 0 files
  new changesets * (glob)
  (run 'hg update' to get a working copy)
TODO: this should tell the user that their narrow clone does not have the
necessary content to be able to push to the target

TODO: lfs shouldn't abort like this
  $ hg push ssh://user@dummy/narrow2 || true
  pushing to ssh://user@dummy/narrow2
  searching for changes
  remote: adding changesets
  remote: adding manifests
  remote: adding file changes
  remote: added 1 changesets with 0 changes to 0 files
  remote: error: pretxnchangegroup.lfs hook raised an exception: data/inside2/f.i@f59b4e021835: no match found (lfs-on !)
  remote: transaction abort! (lfs-on !)
  remote: rollback completed (lfs-on !)
  remote: abort: data/inside2/f.i@f59b4e021835: no match found! (lfs-on !)
  abort: stream ended unexpectedly (got 0 bytes, expected 4) (lfs-on !)
