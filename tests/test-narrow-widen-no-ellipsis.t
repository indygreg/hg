#testcases tree flat
  $ . "$TESTDIR/narrow-library.sh"

#if tree
  $ cat << EOF >> $HGRCPATH
  > [experimental]
  > treemanifest = 1
  > EOF
#endif

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

  $ hg clone --narrow ssh://user@dummy/master narrow
  requesting all changes
  adding changesets
  adding manifests
  adding file changes
  added 3 changesets with 0 changes to 0 files
  new changesets *:* (glob)
  updating to branch default
  0 files updated, 0 files merged, 0 files removed, 0 files unresolved
  $ cd narrow
  $ hg tracked
  $ hg files
  [1]

widen from an empty clone

  $ hg tracked --addinclude inside
  comparing with ssh://user@dummy/master
  searching for changes
  adding changesets
  adding manifests
  adding file changes
  added 0 changesets with 1 changes to 1 files
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

  $ hg log -T "{if(ellipsis, '...')}{rev}: {desc}\n"
  7: update widest v4
  6: add outside2
  5: update inside
  4: update widest v3
  3: add wider, update widest
  2: add outside
  1: add widest
  0: add inside

  $ cd ..

Widen the narrow spec to see the widest file. This should not get the newly
added upstream revisions.

  $ cd narrow
  $ hg id -n
  2

  $ hg tracked --addinclude widest/f --debug
  comparing with ssh://user@dummy/master
  running python "*dummyssh" *user@dummy* *hg -R master serve --stdio* (glob)
  sending hello command
  sending between command
  remote: * (glob)
  remote: capabilities: * (glob)
  remote: 1
  sending protocaps command
  query 1; heads
  sending batch command
  searching for changes
  all local heads known remotely
  sending narrow_widen command
  bundle2-input-bundle: with-transaction
  bundle2-input-part: "changegroup" (params: * mandatory) supported (glob)
  adding changesets
  adding manifests
  adding widest/ revisions (tree !)
  adding file changes
  adding widest/f revisions (tree !)
  added 0 changesets with 1 changes to 1 files
  bundle2-input-part: total payload size * (glob)
  bundle2-input-bundle: 0 parts total
   widest/f: add from widened narrow clone -> g
  getting widest/f
  $ hg tracked
  I path:inside
  I path:widest/f

  $ cat widest/f
  widest

  $ hg id -n
  2

Pull down the newly added upstream revision.

  $ hg pull
  pulling from ssh://user@dummy/master
  searching for changes
  adding changesets
  adding manifests
  adding file changes
  added 5 changesets with 4 changes to 2 files
  new changesets *:* (glob)
  (run 'hg update' to get a working copy)
  $ hg update -r 'desc("add wider")'
  1 files updated, 0 files merged, 0 files removed, 0 files unresolved

  $ cat widest/f
  widest v2

  $ hg update -r 'desc("update inside")'
  2 files updated, 0 files merged, 0 files removed, 0 files unresolved
  $ cat widest/f
  widest v3
  $ cat inside/f
  inside v2

  $ hg log -T "{if(ellipsis, '...')}{rev}: {desc}\n"
  7: update widest v4
  6: add outside2
  5: update inside
  4: update widest v3
  3: add wider, update widest
  2: add outside
  1: add widest
  0: add inside

Check that widening with a newline fails

  $ hg tracked --addinclude 'widest
  > '
  abort: newlines are not allowed in narrowspec paths
  [255]

widen the narrow spec to include the wider file

  $ hg tracked --addinclude wider
  comparing with ssh://user@dummy/master
  searching for changes
  adding changesets
  adding manifests
  adding file changes
  added 0 changesets with 1 changes to 1 files
  $ hg tracked
  I path:inside
  I path:wider
  I path:widest/f
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

  $ hg log -T "{if(ellipsis, '...')}{rev}: {desc}\n"
  7: update widest v4
  6: add outside2
  5: update inside
  4: update widest v3
  3: add wider, update widest
  2: add outside
  1: add widest
  0: add inside

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
  $ hg log -T "{rev}: {desc}\n"
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
  checking directory manifests (tree !)
  crosschecking files in changesets and manifests
  checking files
  checked 11 changesets with 4 changes to 4 files
  $ hg log -T "{if(ellipsis, '...')}{rev}: {desc}\n"
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
  $ hg tracked --addinclude d1
  comparing with ssh://user@dummy/upstream
  searching for changes
  adding changesets
  adding manifests
  adding file changes
  added 0 changesets with 1 changes to 1 files
  $ hg tracked
  I path:d0
  I path:d1
  I path:d3
  I path:d6
  I path:d9
  $ hg log -T "{if(ellipsis, '...')}{rev}: {desc}\n"
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

Verify shouldn't claim the repo is corrupt after a widen.

  $ hg verify
  checking changesets
  checking manifests
  checking directory manifests (tree !)
  crosschecking files in changesets and manifests
  checking files
  checked 11 changesets with 5 changes to 5 files

Widening preserves parent of local commit

  $ cd ..
  $ hg clone -q --narrow ssh://user@dummy/upstream narrow3 --include d2 -r 2
  $ cd narrow3
  $ hg log -T "{if(ellipsis, '...')}{rev}: {desc}\n"
  2: add d2/f
  1: add d1/f
  0: add d0/f
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
   * bookmark                  11:* (glob)
  $ hg -q tracked --addinclude d2
  $ hg bookmarks
   * bookmark                  11:* (glob)
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
  adding changesets
  adding manifests
  adding file changes
  added 0 changesets with 1 changes to 1 files
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
   * bookmark                  11:* (glob)
  $ hg unbundle .hg/strip-backup/*-widen.hg
  abort: .hg/strip-backup/*-widen.hg: $ENOTDIR$ (windows !)
  abort: $ENOENT$: .hg/strip-backup/*-widen.hg (no-windows !)
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
   * bookmark                  11:* (glob)
