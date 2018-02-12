  $ . "$TESTDIR/narrow-library.sh"

  $ hg init master
  $ cd master
  $ cat >> .hg/hgrc <<EOF
  > [narrow]
  > serveellipses=True
  > EOF
  $ for x in `$TESTDIR/seq.py 10`
  > do
  >   echo $x > "f$x"
  >   hg add "f$x"
  >   hg commit -m "Commit f$x"
  > done
  $ cd ..

narrow clone a couple files, f2 and f8

  $ hg clone --narrow ssh://user@dummy/master narrow --include "f2" --include "f8"
  requesting all changes
  adding changesets
  adding manifests
  adding file changes
  added 5 changesets with 2 changes to 2 files
  new changesets *:* (glob)
  updating to branch default
  2 files updated, 0 files merged, 0 files removed, 0 files unresolved
  $ cd narrow
  $ ls
  f2
  f8
  $ cat f2 f8
  2
  8

  $ cd ..

change every upstream file twice

  $ cd master
  $ for x in `$TESTDIR/seq.py 10`
  > do
  >   echo "update#1 $x" >> "f$x"
  >   hg commit -m "Update#1 to f$x" "f$x"
  > done
  $ for x in `$TESTDIR/seq.py 10`
  > do
  >   echo "update#2 $x" >> "f$x"
  >   hg commit -m "Update#2 to f$x" "f$x"
  > done
  $ cd ..

look for incoming changes

  $ cd narrow
  $ hg incoming --limit 3
  comparing with ssh://user@dummy/master
  searching for changes
  changeset:   5:ddc055582556
  user:        test
  date:        Thu Jan 01 00:00:00 1970 +0000
  summary:     Update#1 to f1
  
  changeset:   6:f66eb5ad621d
  user:        test
  date:        Thu Jan 01 00:00:00 1970 +0000
  summary:     Update#1 to f2
  
  changeset:   7:c42ecff04e99
  user:        test
  date:        Thu Jan 01 00:00:00 1970 +0000
  summary:     Update#1 to f3
  

Interrupting the pull is safe
  $ hg --config hooks.pretxnchangegroup.bad=false pull -q
  transaction abort!
  rollback completed
  abort: pretxnchangegroup.bad hook exited with status 1
  [255]
  $ hg id
  223311e70a6f tip

pull new changes down to the narrow clone. Should get 8 new changesets: 4
relevant to the narrow spec, and 4 ellipsis nodes gluing them all together.

  $ hg pull
  pulling from ssh://user@dummy/master
  searching for changes
  adding changesets
  adding manifests
  adding file changes
  added 9 changesets with 4 changes to 2 files
  new changesets *:* (glob)
  (run 'hg update' to get a working copy)
  $ hg log -T '{rev}: {desc}\n'
  13: Update#2 to f10
  12: Update#2 to f8
  11: Update#2 to f7
  10: Update#2 to f2
  9: Update#2 to f1
  8: Update#1 to f8
  7: Update#1 to f7
  6: Update#1 to f2
  5: Update#1 to f1
  4: Commit f10
  3: Commit f8
  2: Commit f7
  1: Commit f2
  0: Commit f1
  $ hg update tip
  2 files updated, 0 files merged, 0 files removed, 0 files unresolved

add a change and push it

  $ echo "update#3 2" >> f2
  $ hg commit -m "Update#3 to f2" f2
  $ hg log f2 -T '{rev}: {desc}\n'
  14: Update#3 to f2
  10: Update#2 to f2
  6: Update#1 to f2
  1: Commit f2
  $ hg push
  pushing to ssh://user@dummy/master
  searching for changes
  remote: adding changesets
  remote: adding manifests
  remote: adding file changes
  remote: added 1 changesets with 1 changes to 1 files
  $ cd ..

  $ cd master
  $ hg log f2 -T '{rev}: {desc}\n'
  30: Update#3 to f2
  21: Update#2 to f2
  11: Update#1 to f2
  1: Commit f2
  $ hg log -l 3 -T '{rev}: {desc}\n'
  30: Update#3 to f2
  29: Update#2 to f10
  28: Update#2 to f9

Can pull into repo with a single commit

  $ cd ..
  $ hg clone -q --narrow ssh://user@dummy/master narrow2 --include "f1" -r 0
  $ cd narrow2
  $ hg pull -q -r 1
  transaction abort!
  rollback completed
  abort: pull failed on remote
  [255]

Can use 'hg share':
  $ cat >> $HGRCPATH <<EOF
  > [extensions]
  > share=
  > EOF

  $ cd ..
  $ hg share narrow2 narrow2-share
  updating working directory
  1 files updated, 0 files merged, 0 files removed, 0 files unresolved
  $ cd narrow2-share
  $ hg status

We should also be able to unshare without breaking everything:
  $ hg unshare
  devel-warn: write with no wlock: "narrowspec" at: */hgext/narrow/narrowrepo.py:* (unsharenarrowspec) (glob)
  $ hg verify
  checking changesets
  checking manifests
  crosschecking files in changesets and manifests
  checking files
  1 files, 1 changesets, 1 total revisions
