  $ . "$TESTDIR/narrow-library.sh"
  $ hg init master
  $ cd master
  $ echo treemanifest >> .hg/requires
  $ echo 'contents of file' > file
  $ mkdir foo
  $ echo 'contents of foo/bar' > foo/bar
  $ hg ci -Am 'some change'
  adding file
  adding foo/bar

  $ cd ..
  $ hg clone --narrow ssh://user@dummy/master copy --include=foo
  requesting all changes
  adding changesets
  adding manifests
  adding file changes
  added 1 changesets with 1 changes to 1 files
  new changesets * (glob)
  updating to branch default
  1 files updated, 0 files merged, 0 files removed, 0 files unresolved
  $ cd copy

  $ hg debugdirstate --no-dates
  n *         20 *               foo/bar (glob)
  $ mv .hg/dirstate .hg/old_dirstate
  $ dd bs=40 count=1 if=.hg/old_dirstate of=.hg/dirstate 2>/dev/null
  $ hg debugdirstate
  $ hg debugrebuilddirstate
  $ hg debugdirstate
  n *         * unset               foo/bar (glob)
