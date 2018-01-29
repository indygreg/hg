  $ cd $TESTDIR && python $RUNTESTDIR/run-tests.py \
  >   --extra-config-opt experimental.treemanifest=1 test-narrow-narrow.t 2>&1 | \
  > grep -v 'unexpected mercurial lib' | egrep -v '\(expected'
  
  --- /*/tests/test-narrow-narrow.t (glob)
  +++ /*/tests/test-narrow-narrow.t.err (glob)
  @@ -\d+,\d+ \+\d+,\d+ @@ (re)
     * (glob)
     * (glob)
     deleting data/d0/f.i
  +  deleting meta/d0/00manifest.i
     $ hg log -T "{node|short}: {desc} {outsidenarrow}\n"
     *: local change to d3  (glob)
     *: add d10/f outsidenarrow (glob)
  @@ -\d+,\d+ \+\d+,\d+ @@ (re)
     looking for local changes to affected paths
     saved backup bundle to $TESTTMP/narrow-local-changes/.hg/strip-backup/*-narrow.hg (glob)
     deleting data/d0/f.i
  +  deleting meta/d0/00manifest.i
   Updates off of stripped commit if necessary
     $ hg co -r 'desc("local change to d3")' -q
     $ echo local change >> d6/f
  @@ -\d+,\d+ \+\d+,\d+ @@ (re)
     2 files updated, 0 files merged, 0 files removed, 0 files unresolved
     saved backup bundle to $TESTTMP/narrow-local-changes/.hg/strip-backup/*-narrow.hg (glob)
     deleting data/d3/f.i
  +  deleting meta/d3/00manifest.i
     $ hg log -T '{desc}\n' -r .
     add d10/f
   Updates to nullid if necessary
  @@ -\d+,\d+ \+\d+,\d+ @@ (re)
     0 files updated, 0 files merged, 1 files removed, 0 files unresolved
     saved backup bundle to $TESTTMP/narrow-local-changes/.hg/strip-backup/*-narrow.hg (glob)
     deleting data/d3/f.i
  +  deleting meta/d3/00manifest.i
     $ hg id
     000000000000
     $ cd ..
  @@ -\d+,\d+ \+\d+,\d+ @@ (re)
     searching for changes
     looking for local changes to affected paths
     deleting data/d0/f.i
  +  deleting meta/d0/00manifest.i
     $ hg tracked
     $ hg files
     [1]
  @@ -\d+,\d+ \+\d+,\d+ @@ (re)
     searching for changes
     looking for local changes to affected paths
     deleting data/d6/f.i
  +  deleting meta/d6/00manifest.i
     $ hg tracked
     I path:d0
     I path:d3
  @@ -\d+,\d+ \+\d+,\d+ @@ (re)
     searching for changes
     looking for local changes to affected paths
     deleting data/d0/f.i
  +  deleting meta/d0/00manifest.i
     $ hg tracked
     I path:d3
     I path:d9
  
  ERROR: test-narrow-narrow.t output changed
  !
  Failed test-narrow-narrow.t: output changed
  # Ran 1 tests, 0 skipped, 1 failed.
  python hash seed: * (glob)
