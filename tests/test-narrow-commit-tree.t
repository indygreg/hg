  $ cd $TESTDIR && python $RUNTESTDIR/run-tests.py \
  >   --extra-config-opt experimental.treemanifest=1 test-narrow-commit.t 2>&1 | \
  > grep -v 'unexpected mercurial lib' | egrep -v '\(expected'
  
  --- */tests/test-narrow-commit.t (glob)
  +++ */tests/test-narrow-commit.t.err (glob)
  @@ -\d+,\d+ \+\d+,\d+ @@ (re)
     created new head
     $ hg files -r .
     inside/f1
  -  outside/f1
  +  outside/
   Some filesystems (notably FAT/exFAT only store timestamps with 2
   seconds of precision, so by sleeping for 3 seconds, we can ensure that
   the timestamps of files stored by dirstate will appear older than the
  
  ERROR: test-narrow-commit.t output changed
  !
  Failed test-narrow-commit.t: output changed
  # Ran 1 tests, 0 skipped, 1 failed.
  python hash seed: * (glob)
