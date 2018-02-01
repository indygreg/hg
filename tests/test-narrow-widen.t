#testcases flat tree
  $ . "$TESTDIR/narrow-library.sh"

#if tree
  $ cat << EOF >> $HGRCPATH
  > [experimental]
  > treemanifest = 1
  > EOF
#endif

  $ hg init master
  $ cd master
  $ cat >> .hg/hgrc <<EOF
  > [narrow]
  > serveellipses=True
  > EOF

  $ mkdir inside
  $ echo 'inside' > inside/f
  $ hg add inside/f
  $ hg commit -m 'add inside'

  $ mkdir widest
  $ echo 'widest' > widest/f
  $ hg add widest/f
  $ hg commit -m 'add widest'

  $ mkdir outside
  $ echo 'outside' > outside/f
  $ hg add outside/f
  $ hg commit -m 'add outside'

  $ cd ..

narrow clone the inside file

  $ hg clone --narrow ssh://user@dummy/master narrow --include inside
  requesting all changes
  adding changesets
  adding manifests
  adding file changes
  added 2 changesets with 1 changes to 1 files
  new changesets *:* (glob)
  updating to branch default
  1 files updated, 0 files merged, 0 files removed, 0 files unresolved
  $ cd narrow
  $ hg tracked
  I path:inside
  $ ls
  inside
  $ cat inside/f
  inside
  $ cd ..

add more upstream files which we will include in a wider narrow spec

  $ cd master

  $ mkdir wider
  $ echo 'wider' > wider/f
  $ hg add wider/f
  $ echo 'widest v2' > widest/f
  $ hg commit -m 'add wider, update widest'

  $ echo 'widest v3' > widest/f
  $ hg commit -m 'update widest v3'

  $ echo 'inside v2' > inside/f
  $ hg commit -m 'update inside'

  $ mkdir outside2
  $ echo 'outside2' > outside2/f
  $ hg add outside2/f
  $ hg commit -m 'add outside2'

  $ echo 'widest v4' > widest/f
  $ hg commit -m 'update widest v4'

  $ hg log -T "{if(ellipsis, '...')}{node|short}: {desc}\n"
  *: update widest v4 (glob)
  *: add outside2 (glob)
  *: update inside (glob)
  *: update widest v3 (glob)
  *: add wider, update widest (glob)
  *: add outside (glob)
  *: add widest (glob)
  *: add inside (glob)

  $ cd ..

Widen the narrow spec to see the wider file. This should not get the newly
added upstream revisions.

  $ cd narrow
  $ hg tracked --addinclude wider/f
  comparing with ssh://user@dummy/master
  searching for changes
  no changes found
  saved backup bundle to $TESTTMP/narrow/.hg/strip-backup/*-widen.hg (glob)
  adding changesets
  adding manifests
  adding file changes
  added 2 changesets with 1 changes to 1 files
  new changesets *:* (glob)
  $ hg tracked
  I path:inside
  I path:wider/f

Pull down the newly added upstream revision.

  $ hg pull
  pulling from ssh://user@dummy/master
  searching for changes
  adding changesets
  adding manifests
  adding file changes
  added 4 changesets with 2 changes to 2 files
  new changesets *:* (glob)
  (run 'hg update' to get a working copy)
  $ hg update -r 'desc("add wider")'
  1 files updated, 0 files merged, 0 files removed, 0 files unresolved
  $ cat wider/f
  wider

  $ hg update -r 'desc("update inside")'
  1 files updated, 0 files merged, 0 files removed, 0 files unresolved
  $ cat wider/f
  wider
  $ cat inside/f
  inside v2

  $ hg log -T "{if(ellipsis, '...')}{node|short}: {desc}\n"
  ...*: update widest v4 (glob)
  *: update inside (glob)
  ...*: update widest v3 (glob)
  *: add wider, update widest (glob)
  ...*: add outside (glob)
  *: add inside (glob)

Check that widening with a newline fails

  $ hg tracked --addinclude 'widest
  > '
  abort: newlines are not allowed in narrowspec paths
  [255]

widen the narrow spec to include the widest file

  $ hg tracked --addinclude widest
  comparing with ssh://user@dummy/master
  searching for changes
  no changes found
  saved backup bundle to $TESTTMP/narrow/.hg/strip-backup/*-widen.hg (glob)
  adding changesets
  adding manifests
  adding file changes
  added 8 changesets with 7 changes to 3 files
  new changesets *:* (glob)
  $ hg tracked
  I path:inside
  I path:wider/f
  I path:widest
  $ hg update 'desc("add widest")'
  2 files updated, 0 files merged, 1 files removed, 0 files unresolved
  $ cat widest/f
  widest
  $ hg update 'desc("add wider, update widest")'
  2 files updated, 0 files merged, 0 files removed, 0 files unresolved
  $ cat wider/f
  wider
  $ cat widest/f
  widest v2
  $ hg update 'desc("update widest v3")'
  1 files updated, 0 files merged, 0 files removed, 0 files unresolved
  $ cat widest/f
  widest v3
  $ hg update 'desc("update widest v4")'
  2 files updated, 0 files merged, 0 files removed, 0 files unresolved
  $ cat widest/f
  widest v4

  $ hg log -T "{if(ellipsis, '...')}{node|short}: {desc}\n"
  *: update widest v4 (glob)
  ...*: add outside2 (glob)
  *: update inside (glob)
  *: update widest v3 (glob)
  *: add wider, update widest (glob)
  ...*: add outside (glob)
  *: add widest (glob)
  *: add inside (glob)

separate suite of tests: files from 0-10 modified in changes 0-10. This allows
more obvious precise tests tickling particular corner cases.

  $ cd ..
  $ hg init upstream
  $ cd upstream
  $ cat >> .hg/hgrc <<EOF
  > [narrow]
  > serveellipses=True
  > EOF
  $ for x in `$TESTDIR/seq.py 0 10`
  > do
  >   mkdir d$x
  >   echo $x > d$x/f
  >   hg add d$x/f
  >   hg commit -m "add d$x/f"
  > done
  $ hg log -T "{node|short}: {desc}\n"
  *: add d10/f (glob)
  *: add d9/f (glob)
  *: add d8/f (glob)
  *: add d7/f (glob)
  *: add d6/f (glob)
  *: add d5/f (glob)
  *: add d4/f (glob)
  *: add d3/f (glob)
  *: add d2/f (glob)
  *: add d1/f (glob)
  *: add d0/f (glob)

make narrow clone with every third node.

  $ cd ..
  $ hg clone --narrow ssh://user@dummy/upstream narrow2 --include d0 --include d3 --include d6 --include d9
  requesting all changes
  adding changesets
  adding manifests
  adding file changes
  added 8 changesets with 4 changes to 4 files
  new changesets *:* (glob)
  updating to branch default
  4 files updated, 0 files merged, 0 files removed, 0 files unresolved
  $ cd narrow2
  $ hg tracked
  I path:d0
  I path:d3
  I path:d6
  I path:d9
  $ hg verify
  checking changesets
  checking manifests
  checking directory manifests (tree !)
  crosschecking files in changesets and manifests
  checking files
  4 files, 8 changesets, 4 total revisions
  $ hg log -T "{if(ellipsis, '...')}{node|short}: {desc}\n"
  ...*: add d10/f (glob)
  *: add d9/f (glob)
  ...*: add d8/f (glob)
  *: add d6/f (glob)
  ...*: add d5/f (glob)
  *: add d3/f (glob)
  ...*: add d2/f (glob)
  *: add d0/f (glob)
  $ hg tracked --addinclude d1
  comparing with ssh://user@dummy/upstream
  searching for changes
  no changes found
  saved backup bundle to $TESTTMP/narrow2/.hg/strip-backup/*-widen.hg (glob)
  adding changesets
  adding manifests
  adding file changes
  added 9 changesets with 5 changes to 5 files
  new changesets *:* (glob)
  $ hg tracked
  I path:d0
  I path:d1
  I path:d3
  I path:d6
  I path:d9
  $ hg log -T "{if(ellipsis, '...')}{node|short}: {desc}\n"
  ...*: add d10/f (glob)
  *: add d9/f (glob)
  ...*: add d8/f (glob)
  *: add d6/f (glob)
  ...*: add d5/f (glob)
  *: add d3/f (glob)
  ...*: add d2/f (glob)
  *: add d1/f (glob)
  *: add d0/f (glob)

Verify shouldn't claim the repo is corrupt after a widen.

  $ hg verify
  checking changesets
  checking manifests
  checking directory manifests (tree !)
  crosschecking files in changesets and manifests
  checking files
  5 files, 9 changesets, 5 total revisions

Widening preserves parent of local commit

  $ cd ..
  $ hg clone -q --narrow ssh://user@dummy/upstream narrow3 --include d2 -r 2
  $ cd narrow3
  $ hg log -T "{if(ellipsis, '...')}{node|short}: {desc}\n"
  *: add d2/f (glob)
  ...*: add d1/f (glob)
  $ hg pull -q -r 3
  $ hg co -q tip
  $ hg pull -q -r 4
  $ echo local > d2/f
  $ hg ci -m local
  created new head
  $ hg tracked -q --addinclude d0 --addinclude d9

Widening preserves bookmarks

  $ cd ..
  $ hg clone -q --narrow ssh://user@dummy/upstream narrow-bookmarks --include d4
  $ cd narrow-bookmarks
  $ echo local > d4/f
  $ hg ci -m local
  $ hg bookmarks bookmark
  $ hg bookmarks
   * bookmark                  3:* (glob)
  $ hg -q tracked --addinclude d2
  $ hg bookmarks
   * bookmark                  5:* (glob)
  $ hg log -r bookmark -T '{desc}\n'
  local

Widening that fails can be recovered from

  $ cd ..
  $ hg clone -q --narrow ssh://user@dummy/upstream interrupted --include d0
  $ cd interrupted
  $ echo local > d0/f
  $ hg ci -m local
  $ hg log -T "{if(ellipsis, '...')}{rev}: {desc}\n"
  2: local
  ...1: add d10/f
  0: add d0/f
  $ hg bookmarks bookmark
  $ hg --config hooks.pretxnchangegroup.bad=false tracked --addinclude d1
  comparing with ssh://user@dummy/upstream
  searching for changes
  no changes found
  saved backup bundle to $TESTTMP/interrupted/.hg/strip-backup/*-widen.hg (glob)
  adding changesets
  adding manifests
  adding file changes
  added 3 changesets with 2 changes to 2 files
  transaction abort!
  rollback completed
  abort: pretxnchangegroup.bad hook exited with status 1
  [255]
  $ hg log -T "{if(ellipsis, '...')}{rev}: {desc}\n"
  $ hg bookmarks
  no bookmarks set
  $ hg unbundle .hg/strip-backup/*-widen.hg
  adding changesets
  adding manifests
  adding file changes
  added 3 changesets with 2 changes to 1 files
  new changesets *:* (glob)
  (run 'hg update' to get a working copy)
  $ hg log -T "{if(ellipsis, '...')}{rev}: {desc}\n"
  2: local
  ...1: add d10/f
  0: add d0/f
  $ hg bookmarks
   * bookmark                  2:* (glob)
