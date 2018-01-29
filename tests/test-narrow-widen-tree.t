  $ cd $TESTDIR && python $RUNTESTDIR/run-tests.py \
  >   --extra-config-opt experimental.treemanifest=1 test-narrow-widen.t 2>&1 | \
  > grep -v 'unexpected mercurial lib' | egrep -v '\(expected'
  
  --- */test-narrow-widen.t (glob)
  +++ */test-narrow-widen.t.err (glob)
  @@ -\d+,\d+ \+\d+,\d+ @@ (re)
     $ hg verify
     checking changesets
     checking manifests
  +  checking directory manifests
     crosschecking files in changesets and manifests
     checking files
     4 files, 8 changesets, 4 total revisions
  @@ -\d+,\d+ \+\d+,\d+ @@ (re)
     $ hg verify
     checking changesets
     checking manifests
  +  checking directory manifests
     crosschecking files in changesets and manifests
     checking files
     5 files, 9 changesets, 5 total revisions
  
  ERROR: test-narrow-widen.t output changed
  !
  Failed test-narrow-widen.t: output changed
  # Ran 1 tests, 0 skipped, 1 failed.
  python hash seed: * (glob)
