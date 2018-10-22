#testcases flat tree
#testcases lfs-on lfs-off

#if lfs-on
  $ cat >> $HGRCPATH <<EOF
  > [extensions]
  > lfs =
  > EOF
#endif

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
  $ cat >> .hg/hgrc <<EOF
  > [narrow]
  > serveellipses=True
  > EOF

  $ mkdir inside
  $ echo inside > inside/f1
  $ mkdir outside
  $ echo outside > outside/f1
  $ hg ci -Aqm 'initial'

  $ echo modified > inside/f1
  $ hg ci -qm 'modify inside'

  $ hg co -q 0
  $ echo modified > outside/f1
  $ hg ci -qm 'modify outside'

  $ echo modified again >> outside/f1
  $ hg ci -qm 'modify outside again'

  $ cd ..

  $ hg clone --narrow ssh://user@dummy/master narrow --include inside
  requesting all changes
  adding changesets
  adding manifests
  adding file changes
  added 3 changesets with 2 changes to 1 files (+1 heads)
  new changesets *:* (glob)
  updating to branch default
  1 files updated, 0 files merged, 0 files removed, 0 files unresolved
  $ cd narrow
  $ cat >> $HGRCPATH <<EOF
  > [extensions]
  > strip=
  > EOF

Can strip and recover changesets affecting only files within narrow spec

  $ hg co -r 'desc("modify inside")'
  1 files updated, 0 files merged, 0 files removed, 0 files unresolved
  $ rm -f .hg/strip-backup/*-backup.hg
  $ hg strip .
  1 files updated, 0 files merged, 0 files removed, 0 files unresolved
  saved backup bundle to $TESTTMP/narrow/.hg/strip-backup/*-backup.hg (glob)
  $ hg unbundle .hg/strip-backup/*-backup.hg
  adding changesets
  adding manifests
  adding file changes
  added 1 changesets with 1 changes to 1 files (+1 heads)
  new changesets * (glob)
  (run 'hg heads' to see heads, 'hg merge' to merge)

Can strip and recover changesets affecting files outside of narrow spec

  $ hg co -r 'desc("modify outside")'
  0 files updated, 0 files merged, 0 files removed, 0 files unresolved
  $ hg log -G -T '{rev} {desc}\n'
  o  2 modify inside
  |
  | @  1 modify outside again
  |/
  o  0 initial
  
  $ hg debugdata -m 1
  inside/f1\x004d6a634d5ba06331a60c29ee0db8412490a54fcd (esc) (flat !)
  outside/f1\x0084ba604d54dee1f13310ce3d4ac2e8a36636691a (esc) (flat !)
  inside\x006a8bc41df94075d501f9740587a0c0e13c170dc5t (esc) (tree !)
  outside\x00255c2627ebdd3c7dcaa6945246f9b9f02bd45a09t (esc) (tree !)

  $ rm -f .hg/strip-backup/*-backup.hg
  $ hg strip .
  0 files updated, 0 files merged, 0 files removed, 0 files unresolved
  saved backup bundle to $TESTTMP/narrow/.hg/strip-backup/*-backup.hg (glob)
  $ hg unbundle .hg/strip-backup/*-backup.hg
  adding changesets
  adding manifests
  adding file changes
  added 1 changesets with 0 changes to 0 files (+1 heads)
  new changesets * (glob)
  (run 'hg heads' to see heads, 'hg merge' to merge)
  $ hg log -G -T '{rev} {desc}\n'
  o  2 modify outside again
  |
  | o  1 modify inside
  |/
  @  0 initial
  
Check that hash of file outside narrow spec got restored
  $ hg debugdata -m 2
  inside/f1\x004d6a634d5ba06331a60c29ee0db8412490a54fcd (esc) (flat !)
  outside/f1\x0084ba604d54dee1f13310ce3d4ac2e8a36636691a (esc) (flat !)
  inside\x006a8bc41df94075d501f9740587a0c0e13c170dc5t (esc) (tree !)
  outside\x00255c2627ebdd3c7dcaa6945246f9b9f02bd45a09t (esc) (tree !)

Also verify we can apply the bundle with 'hg pull':
  $ hg co -r 'desc("modify inside")'
  1 files updated, 0 files merged, 0 files removed, 0 files unresolved
  $ rm .hg/strip-backup/*-backup.hg
  $ hg strip .
  1 files updated, 0 files merged, 0 files removed, 0 files unresolved
  saved backup bundle to $TESTTMP/narrow/.hg/strip-backup/*-backup.hg (glob)
#if repobundlerepo
  $ hg pull .hg/strip-backup/*-backup.hg
  pulling from .hg/strip-backup/*-backup.hg (glob)
  searching for changes
  adding changesets
  adding manifests
  adding file changes
  added 1 changesets with 1 changes to 1 files (+1 heads)
  new changesets * (glob)
  (run 'hg heads' to see heads, 'hg merge' to merge)

  $ rm .hg/strip-backup/*-backup.hg
  $ hg strip 0
  0 files updated, 0 files merged, 1 files removed, 0 files unresolved
  saved backup bundle to $TESTTMP/narrow/.hg/strip-backup/*-backup.hg (glob)

  $ hg incoming .hg/strip-backup/*-backup.hg
  comparing with .hg/strip-backup/*-backup.hg (glob)
  changeset:   0:* (glob)
  user:        test
  date:        Thu Jan 01 00:00:00 1970 +0000
  summary:     initial
  
  changeset:   1:9e48d953700d (flat !)
  changeset:   1:3888164bccf0 (tree !)
  user:        test
  date:        Thu Jan 01 00:00:00 1970 +0000
  summary:     modify outside again
  
  changeset:   2:f505d5e96aa8 (flat !)
  changeset:   2:40b66f95a209 (tree !)
  tag:         tip
  parent:      0:a99f4d53924d (flat !)
  parent:      0:c2a5fabcca3c (tree !)
  user:        test
  date:        Thu Jan 01 00:00:00 1970 +0000
  summary:     modify inside
  
  $ hg pull .hg/strip-backup/*-backup.hg
  pulling from .hg/strip-backup/*-backup.hg (glob)
  requesting all changes
  adding changesets
  adding manifests
  adding file changes
  added 3 changesets with 2 changes to 1 files (+1 heads)
  new changesets *:* (glob)
  (run 'hg heads' to see heads, 'hg merge' to merge)
#endif
