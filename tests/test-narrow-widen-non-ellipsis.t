  $ . "$TESTDIR/narrow-library.sh"

  $ cat << EOF >> $HGRCPATH
  > [experimental]
  > treemanifest = 1
  > EOF

  $ hg init master
  $ cd master

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
  added 3 changesets with 1 changes to 1 files
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
  3 local changesets published
  $ hg tracked
  I path:inside

Pull down the newly added upstream revision.

  $ hg pull
  pulling from ssh://user@dummy/master
  searching for changes
  adding changesets
  adding manifests
  adding file changes
  added 5 changesets with 1 changes to 1 files
  new changesets *:* (glob)
  (run 'hg update' to get a working copy)
  $ hg update -r 'desc("add wider")'
  0 files updated, 0 files merged, 0 files removed, 0 files unresolved
  $ cat wider/f
  cat: wider/f: $ENOENT$
  [1]

  $ hg update -r 'desc("update inside")'
  1 files updated, 0 files merged, 0 files removed, 0 files unresolved
  $ cat wider/f
  cat: wider/f: $ENOENT$
  [1]
  $ cat inside/f
  inside v2

  $ hg log -T "{if(ellipsis, '...')}{node|short}: {desc}\n"
  45662f0793c7: update widest v4
  1dd1364b566e: add outside2
  *: update inside (glob)
  be0600e3ccba: update widest v3
  *: add wider, update widest (glob)
  4922ea71b958: add outside
  40e0ea6c8cd7: add widest
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
  5 local changesets published
  abort: path ends in directory separator: widest/
  [255]
  $ hg tracked
  I path:inside
  $ hg update 'desc("add widest")'
  1 files updated, 0 files merged, 0 files removed, 0 files unresolved
  $ cat widest/f
  cat: widest/f: $ENOENT$
  [1]
  $ hg update 'desc("add wider, update widest")'
  0 files updated, 0 files merged, 0 files removed, 0 files unresolved
  $ cat wider/f
  cat: wider/f: $ENOENT$
  [1]
  $ cat widest/f
  cat: widest/f: $ENOENT$
  [1]
  $ hg update 'desc("update widest v3")'
  0 files updated, 0 files merged, 0 files removed, 0 files unresolved
  $ cat widest/f
  cat: widest/f: $ENOENT$
  [1]
  $ hg update 'desc("update widest v4")'
  1 files updated, 0 files merged, 0 files removed, 0 files unresolved
  $ cat widest/f
  cat: widest/f: $ENOENT$
  [1]

  $ hg log -T "{if(ellipsis, '...')}{node|short}: {desc}\n"
  *: update widest v4 (glob)
  1dd1364b566e: add outside2
  *: update inside (glob)
  *: update widest v3 (glob)
  *: add wider, update widest (glob)
  4922ea71b958: add outside
  *: add widest (glob)
  *: add inside (glob)

separate suite of tests: files from 0-10 modified in changes 0-10. This allows
more obvious precise tests tickling particular corner cases.

  $ cd ..
  $ hg init upstream
  $ cd upstream
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
  added 11 changesets with 4 changes to 4 files
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
  checking directory manifests
  crosschecking files in changesets and manifests
  checking files
  4 files, 11 changesets, 4 total revisions
  $ hg log -T "{if(ellipsis, '...')}{node|short}: {desc}\n"
  5dcf948d1e26: add d10/f
  *: add d9/f (glob)
  ed07d334af10: add d8/f
  472749d2eed8: add d7/f
  *: add d6/f (glob)
  47c482f555ec: add d5/f
  3c6772db7d10: add d4/f
  *: add d3/f (glob)
  a68ce05aaaed: add d2/f
  5934322a52dd: add d1/f
  *: add d0/f (glob)
  $ hg tracked --addinclude d1
  comparing with ssh://user@dummy/upstream
  searching for changes
  no changes found
  11 local changesets published
  abort: path ends in directory separator: d1/
  [255]
  $ hg tracked
  I path:d0
  I path:d3
  I path:d6
  I path:d9
  $ hg log -T "{if(ellipsis, '...')}{node|short}: {desc}\n"
  5dcf948d1e26: add d10/f
  *: add d9/f (glob)
  ed07d334af10: add d8/f
  472749d2eed8: add d7/f
  *: add d6/f (glob)
  47c482f555ec: add d5/f
  3c6772db7d10: add d4/f
  *: add d3/f (glob)
  a68ce05aaaed: add d2/f
  *: add d1/f (glob)
  *: add d0/f (glob)

Verify shouldn't claim the repo is corrupt after a widen.

  $ hg verify
  checking changesets
  checking manifests
  checking directory manifests
  crosschecking files in changesets and manifests
  checking files
  4 files, 11 changesets, 4 total revisions

Widening preserves parent of local commit

  $ cd ..
  $ hg clone -q --narrow ssh://user@dummy/upstream narrow3 --include d2 -r 2
  $ cd narrow3
  $ hg log -T "{if(ellipsis, '...')}{node|short}: {desc}\n"
  *: add d2/f (glob)
  5934322a52dd: add d1/f
  44d97ac7c511: add d0/f
  $ hg pull -q -r 3
  $ hg co -q tip
  $ hg pull -q -r 4
  $ echo local > d2/f
  $ hg ci -m local
  created new head
  $ hg tracked -q --addinclude d0 --addinclude d9
  abort: path ends in directory separator: d0/
  [255]

Widening preserves bookmarks

  $ cd ..
  $ hg clone -q --narrow ssh://user@dummy/upstream narrow-bookmarks --include d4
  $ cd narrow-bookmarks
  $ echo local > d4/f
  $ hg ci -m local
  $ hg bookmarks bookmark
  $ hg bookmarks
   * bookmark                  11:42aed9c63197
  $ hg -q tracked --addinclude d2
  abort: path ends in directory separator: d2/
  [255]
  $ hg bookmarks
   * bookmark                  11:42aed9c63197
  $ hg log -r bookmark -T '{desc}\n'
  local

Widening that fails can be recovered from

  $ cd ..
  $ hg clone -q --narrow ssh://user@dummy/upstream interrupted --include d0
  $ cd interrupted
  $ echo local > d0/f
  $ hg ci -m local
  $ hg log -T "{if(ellipsis, '...')}{rev}: {desc}\n"
  11: local
  10: add d10/f
  9: add d9/f
  8: add d8/f
  7: add d7/f
  6: add d6/f
  5: add d5/f
  4: add d4/f
  3: add d3/f
  2: add d2/f
  1: add d1/f
  0: add d0/f
  $ hg bookmarks bookmark
  $ hg --config hooks.pretxnchangegroup.bad=false tracked --addinclude d1
  comparing with ssh://user@dummy/upstream
  searching for changes
  no changes found
  11 local changesets published
  abort: path ends in directory separator: d1/
  [255]
  $ hg log -T "{if(ellipsis, '...')}{rev}: {desc}\n"
  11: local
  10: add d10/f
  9: add d9/f
  8: add d8/f
  7: add d7/f
  6: add d6/f
  5: add d5/f
  4: add d4/f
  3: add d3/f
  2: add d2/f
  1: add d1/f
  0: add d0/f
  $ hg bookmarks
   * bookmark                  11:b7ce3df41eca
  $ hg unbundle .hg/strip-backup/*-widen.hg
  abort: $ENOENT$: .hg/strip-backup/*-widen.hg
  [255]
  $ hg log -T "{if(ellipsis, '...')}{rev}: {desc}\n"
  11: local
  10: add d10/f
  9: add d9/f
  8: add d8/f
  7: add d7/f
  6: add d6/f
  5: add d5/f
  4: add d4/f
  3: add d3/f
  2: add d2/f
  1: add d1/f
  0: add d0/f
  $ hg bookmarks
   * bookmark                  11:b7ce3df41eca
