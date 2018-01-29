  $ cd $TESTDIR && python $RUNTESTDIR/run-tests.py \
  >   --extra-config-opt experimental.treemanifest=1 test-patch.t 2>&1 | \
  > grep -v 'unexpected mercurial lib' | egrep -v '\(expected'
  .
  # Ran 1 tests, 0 skipped, 0 failed.
