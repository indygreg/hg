#testcases flat tree

  $ . "$TESTDIR/narrow-library.sh"

#if tree
  $ cat << EOF >> $HGRCPATH
  > [experimental]
  > treemanifest = 1
  > EOF
#endif

create full repo

  $ hg init master
  $ cd master

  $ mkdir inside
  $ echo inside > inside/f1
  $ mkdir outside
  $ echo outside > outside/f1
  $ hg ci -Aqm 'initial'

  $ echo modified > inside/f1
  $ hg ci -qm 'modify inside'

  $ echo modified > outside/f1
  $ hg ci -qm 'modify outside'

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
  $ cd narrow

Can show patch touching paths outside

  $ hg log -p
  changeset:   2:* (glob)
  tag:         tip
  user:        test
  date:        Thu Jan 01 00:00:00 1970 +0000
  summary:     modify outside
  
  
  changeset:   1:* (glob)
  user:        test
  date:        Thu Jan 01 00:00:00 1970 +0000
  summary:     modify inside
  
  diff -r * -r * inside/f1 (glob)
  --- a/inside/f1	Thu Jan 01 00:00:00 1970 +0000
  +++ b/inside/f1	Thu Jan 01 00:00:00 1970 +0000
  @@ -1,1 +1,1 @@
  -inside
  +modified
  
  changeset:   0:* (glob)
  user:        test
  date:        Thu Jan 01 00:00:00 1970 +0000
  summary:     initial
  
  diff -r 000000000000 -r * inside/f1 (glob)
  --- /dev/null	Thu Jan 01 00:00:00 1970 +0000
  +++ b/inside/f1	Thu Jan 01 00:00:00 1970 +0000
  @@ -0,0 +1,1 @@
  +inside
  

  $ hg status --rev 1 --rev 2

Can show copies inside the narrow clone

  $ hg cp inside/f1 inside/f2
  $ hg diff --git
  diff --git a/inside/f1 b/inside/f2
  copy from inside/f1
  copy to inside/f2
