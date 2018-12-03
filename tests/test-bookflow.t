initialize
  $ make_changes() {
  >     d=`pwd`
  >     [ ! -z $1 ] && cd $1
  >     echo "test `basename \`pwd\``" >> test
  >     hg commit -Am"${2:-test}"
  >     r=$?
  >     cd $d
  >     return $r
  > }
  $ ls -1a
  .
  ..
  $ hg init a
  $ cd a
  $ echo 'test' > test; hg commit -Am'test'
  adding test

clone to b

  $ mkdir ../b
  $ cd ../b
  $ hg clone ../a .
  updating to branch default
  1 files updated, 0 files merged, 0 files removed, 0 files unresolved
  $ echo "[extensions]" >> .hg/hgrc
  $ echo "bookflow=" >> .hg/hgrc
  $ hg branch X
  abort: creating named branches is disabled and you should use bookmarks
  (see 'hg help bookflow')
  [255]
  $ hg bookmark X
  $ hg bookmarks
  * X                         0:* (glob)
  $ hg bookmark X
  abort: bookmark X already exists, to move use the --rev option
  [255]
  $ make_changes
  $ hg push ../a -q

  $ hg bookmarks
   \* X                         1:* (glob)

change a
  $ cd ../a
  $ hg up
  1 files updated, 0 files merged, 0 files removed, 0 files unresolved
  $ echo 'test' >> test; hg commit -Am'test'


pull in b
  $ cd ../b
  $ hg pull -u
  pulling from $TESTTMP/a
  searching for changes
  adding changesets
  adding manifests
  adding file changes
  added 1 changesets with 1 changes to 1 files
  new changesets * (glob)
  1 files updated, 0 files merged, 0 files removed, 0 files unresolved
  (leaving bookmark X)
  $ hg status
  $ hg bookmarks
     X                         1:* (glob)

check protection of @ bookmark
  $ hg bookmark @
  $ hg bookmarks
   \* @                         2:* (glob)
     X                         1:* (glob)
  $ make_changes
  abort: cannot commit, bookmark @ is protected
  [255]

  $ hg status
  M test
  $ hg bookmarks
   \* @                         2:* (glob)
     X                         1:* (glob)

  $ hg --config bookflow.protect= commit  -Am"Updated test"

  $ hg bookmarks
   \* @                         3:* (glob)
     X                         1:* (glob)

check requirement for an active bookmark
  $ hg bookmark -i
  $ hg bookmarks
     @                         3:* (glob)
     X                         1:* (glob)
  $ make_changes
  abort: cannot commit without an active bookmark
  [255]
  $ hg revert test
  $ rm test.orig
  $ hg status


make the bookmark move by updating it on a, and then pulling
# add a commit to a
  $ cd ../a
  $ hg bookmark X
  $ hg bookmarks
   \* X                         2:* (glob)
  $ make_changes
  $ hg bookmarks
   * X                         3:81af7977fdb9

# go back to b, and check out X
  $ cd ../b
  $ hg up X
  1 files updated, 0 files merged, 0 files removed, 0 files unresolved
  (activating bookmark X)
  $ hg bookmarks
     @                         3:* (glob)
   \* X                         1:* (glob)

# pull, this should move the bookmark forward, because it was changed remotely
  $ hg pull -u | grep "updating to active bookmark X"
  updating to active bookmark X

  $ hg bookmarks
     @                         3:* (glob)
   * X                         4:81af7977fdb9

the bookmark should not move if it diverged from remote
  $ hg -R ../a status
  $ hg -R ../b status
  $ make_changes ../a
  $ make_changes ../b
  $ hg -R ../a status
  $ hg -R ../b status
  $ hg -R ../a bookmarks
   * X                         4:238292f60a57
  $ hg -R ../b bookmarks
     @                         3:* (glob)
   * X                         5:096f7e86892d
  $ cd ../b
  $ # make sure we cannot push after bookmarks diverged
  $ hg push -B X | grep abort
  abort: push creates new remote head * with bookmark 'X'! (glob)
  (pull and merge or see 'hg help push' for details about pushing new heads)
  [1]
  $ hg pull -u | grep divergent
  divergent bookmark X stored as X@default
  1 other divergent bookmarks for "X"
  $ hg bookmarks
     @                         3:* (glob)
   * X                         5:096f7e86892d
     X@default                 6:238292f60a57
  $ hg id -in
  096f7e86892d 5
  $ make_changes
  $ hg status
  $ hg bookmarks
     @                         3:* (glob)
   * X                         7:227f941aeb07
     X@default                 6:238292f60a57

now merge with the remote bookmark
  $ hg merge X@default --tool :local -q
  $ hg status
  M test
  $ hg commit -m"Merged with X@default"
  $ hg bookmarks
     @                         3:* (glob)
   * X                         8:26fed9bb3219
  $ hg push -B X | grep bookmark
  pushing to $TESTTMP/a (?)
  updating bookmark X
  $ cd ../a
  $ hg up -q
  $ hg bookmarks
   * X                         7:26fed9bb3219

test hg pull when there is more than one descendant
  $ cd ../a
  $ hg bookmark Z
  $ hg bookmark Y
  $ make_changes . YY
  $ hg up Z -q
  $ make_changes . ZZ
  created new head
  $ hg bookmarks
     X                         7:26fed9bb3219
     Y                         8:131e663dbd2a
   * Z                         9:b74a4149df25
  $ hg log -r 'p1(Y)' -r 'p1(Z)' -T '{rev}\n' # prove that Y and Z share the same parent
  7
  $ hg log -r 'Y%Z' -T '{rev}\n'  # revs in Y but not in Z
  8
  $ hg log -r 'Z%Y' -T '{rev}\n'  # revs in Z but not in Y
  9
  $ cd ../b
  $ hg pull -uq
  $ hg id
  b74a4149df25 tip Z
  $ hg bookmarks | grep \*  # no active bookmark
  [1]


test shelving
  $ cd ../a
  $ echo anotherfile > anotherfile # this change should not conflict
  $ hg add anotherfile
  $ hg commit -m"Change in a"
  $ cd ../b
  $ hg up Z | grep Z
  (activating bookmark Z)
  $ hg book | grep \* # make sure active bookmark
   \* Z                         10:* (glob)
  $ echo "test b" >> test
  $ hg diff --stat
   test |  1 +
   1 files changed, 1 insertions(+), 0 deletions(-)
  $ hg --config extensions.shelve= shelve
  shelved as Z
  1 files updated, 0 files merged, 0 files removed, 0 files unresolved
  $ hg pull -uq
  $ hg --trace --config extensions.shelve= unshelve
  unshelving change 'Z'
  rebasing shelved changes
  $ hg diff --stat
   test |  1 +
   1 files changed, 1 insertions(+), 0 deletions(-)


make the bookmark move by updating it on a, and then pulling with a local change
# add a commit to a
  $ cd ../a
  $ hg up -C X |fgrep  "activating bookmark X"
  (activating bookmark X)
# go back to b, and check out X
  $ cd ../b
  $ hg up -C X |fgrep  "activating bookmark X"
  (activating bookmark X)
# update and push from a
  $ make_changes ../a
  created new head
  $ echo "more" >> test
  $ hg pull -u 2>&1 | fgrep -v TESTTMP| fgrep -v "searching for changes" | fgrep -v adding
  pulling from $TESTTMP/a
  added 1 changesets with 0 changes to 0 files (+1 heads)
  updating bookmark X
  new changesets * (glob)
  updating to active bookmark X
  merging test
  warning: conflicts while merging test! (edit, then use 'hg resolve --mark')
  0 files updated, 0 files merged, 0 files removed, 1 files unresolved
  use 'hg resolve' to retry unresolved file merges
  $ hg update -Cq
  $ rm test.orig

make sure that commits aren't possible if working directory is not pointing to active bookmark
  $ hg -R ../a status
  $ hg -R ../b status
  $ hg -R ../a id -i
  36a6e592ec06
  $ hg -R ../a book | grep X
   \* X                         \d+:36a6e592ec06 (re)
  $ hg -R ../b id -i
  36a6e592ec06
  $ hg -R ../b book | grep X
   \* X                         \d+:36a6e592ec06 (re)
  $ make_changes ../a
  $ hg -R ../a book | grep X
   \* X                         \d+:f73a71c992b8 (re)
  $ cd ../b
  $ hg pull  2>&1 | grep -v add | grep -v pulling | grep -v searching | grep -v changeset
  updating bookmark X
  (run 'hg update' to get a working copy)
  working directory out of sync with active bookmark, run 'hg up X'
  $ hg id -i # we're still on the old commit
  36a6e592ec06
  $ hg book | grep X # while the bookmark moved
   \* X                         \d+:f73a71c992b8 (re)
  $ make_changes
  abort: cannot commit, working directory out of sync with active bookmark
  (run 'hg up X')
  [255]
  $ hg up -Cq -r .  # cleanup local changes
  $ hg status
  $ hg id -i # we're still on the old commit
  36a6e592ec06
  $ hg up X -q
  $ hg id -i # now we're on X
  f73a71c992b8
  $ hg book | grep X
   \* X                         \d+:f73a71c992b8 (re)

