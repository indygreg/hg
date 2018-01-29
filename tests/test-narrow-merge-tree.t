  $ cd $TESTDIR && python $RUNTESTDIR/run-tests.py \
  >   --extra-config-opt experimental.treemanifest=1 test-narrow-merge.t 2>&1 | \
  > grep -v 'unexpected mercurial lib' | egrep -v '\(expected'
  
  --- */tests/test-narrow-merge.t (glob)
  +++ */tests/test-narrow-merge.t.err (glob)
  @@ -\d+,\d+ \+\d+,\d+ @@ (re)
   
     $ hg update -q 'desc("modify inside/f1")'
     $ hg merge 'desc("modify outside/f1")'
  -  abort: merge affects file 'outside/f1' outside narrow, which is not yet supported
  +  abort: merge affects file 'outside/' outside narrow, which is not yet supported
     (merging in the other direction may work)
     [255]
   
  @@ -\d+,\d+ \+\d+,\d+ @@ (re)
   
     $ hg update -q 'desc("modify outside/f1")'
     $ hg merge 'desc("conflicting outside/f1")'
  -  abort: conflict in file 'outside/f1' is outside narrow clone
  +  abort: conflict in file 'outside/' is outside narrow clone
     [255]
  
  ERROR: test-narrow-merge.t output changed
  !
  Failed test-narrow-merge.t: output changed
  # Ran 1 tests, 0 skipped, 1 failed.
  python hash seed: * (glob)
