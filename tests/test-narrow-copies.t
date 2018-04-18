
  $ . "$TESTDIR/narrow-library.sh"

create full repo

  $ hg init master
  $ cd master

  $ mkdir inside
  $ echo inside > inside/f1
  $ mkdir outside
  $ echo outside > outside/f2
  $ hg ci -Aqm 'initial'

  $ hg mv outside/f2 inside/f2
  $ hg ci -qm 'move f2 from outside'

  $ echo modified > inside/f2
  $ hg ci -qm 'modify inside/f2'

  $ cd ..

  $ hg clone --narrow ssh://user@dummy/master narrow --include inside
  requesting all changes
  adding changesets
  adding manifests
  adding file changes
  added 3 changesets with 3 changes to 2 files
  new changesets *:* (glob)
  updating to branch default
  2 files updated, 0 files merged, 0 files removed, 0 files unresolved
  $ cd narrow

  $ hg co 'desc("move f2")'
  1 files updated, 0 files merged, 0 files removed, 0 files unresolved
  $ hg status
  $ hg diff
  $ hg diff --change . --git
  diff --git a/inside/f2 b/inside/f2
  new file mode 100644
  --- /dev/null
  +++ b/inside/f2
  @@ -0,0 +1,1 @@
  +outside

  $ hg log --follow inside/f2 -r tip
  changeset:   2:bcfb756e0ca9
  tag:         tip
  user:        test
  date:        Thu Jan 01 00:00:00 1970 +0000
  summary:     modify inside/f2
  
  changeset:   1:5a016133b2bb
  user:        test
  date:        Thu Jan 01 00:00:00 1970 +0000
  summary:     move f2 from outside
  
