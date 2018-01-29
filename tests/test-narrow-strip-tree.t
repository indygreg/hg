  $ cd $TESTDIR && python $RUNTESTDIR/run-tests.py \
  >   --extra-config-opt experimental.treemanifest=1 test-narrow-strip.t 2>&1 | \
  > grep -v 'unexpected mercurial lib' | egrep -v '\(expected'
  
  --- */test-narrow-strip.t (glob)
  +++ */test-narrow-strip.t.err (glob)
  @@ -\d+,\d+ \+\d+,\d+ @@ (re)
     o  0 initial
     
     $ hg debugdata -m 1
  -  inside/f1\x004d6a634d5ba06331a60c29ee0db8412490a54fcd (esc)
  -  outside/f1\x0084ba604d54dee1f13310ce3d4ac2e8a36636691a (esc)
  +  inside\x006a8bc41df94075d501f9740587a0c0e13c170dc5t (esc)
  +  outside\x00255c2627ebdd3c7dcaa6945246f9b9f02bd45a09t (esc)
   
     $ rm -f $TESTTMP/narrow/.hg/strip-backup/*-backup.hg
     $ hg strip .
  @@ -\d+,\d+ \+\d+,\d+ @@ (re)
     
   Check that hash of file outside narrow spec got restored
     $ hg debugdata -m 2
  -  inside/f1\x004d6a634d5ba06331a60c29ee0db8412490a54fcd (esc)
  -  outside/f1\x0084ba604d54dee1f13310ce3d4ac2e8a36636691a (esc)
  +  inside\x006a8bc41df94075d501f9740587a0c0e13c170dc5t (esc)
  +  outside\x00255c2627ebdd3c7dcaa6945246f9b9f02bd45a09t (esc)
   
   Also verify we can apply the bundle with 'hg pull':
     $ hg co -r 'desc("modify inside")'
  @@ -\d+,\d+ \+\d+,\d+ @@ (re)
     date:        Thu Jan 01 00:00:00 1970 +0000
     summary:     initial
     
  -  changeset:   1:9e48d953700d
  +  changeset:   1:3888164bccf0
     user:        test
     date:        Thu Jan 01 00:00:00 1970 +0000
     summary:     modify outside again
     
  -  changeset:   2:f505d5e96aa8
  +  changeset:   2:40b66f95a209
     tag:         tip
  -  parent:      0:a99f4d53924d
  +  parent:      0:c2a5fabcca3c
     user:        test
     date:        Thu Jan 01 00:00:00 1970 +0000
     summary:     modify inside
  
  ERROR: test-narrow-strip.t output changed
  !
  Failed test-narrow-strip.t: output changed
  # Ran 1 tests, 0 skipped, 1 failed.
  python hash seed: * (glob)
