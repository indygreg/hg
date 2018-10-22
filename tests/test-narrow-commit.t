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

(The lfs extension does nothing here, but this test ensures that its hook that
determines whether to add the lfs requirement, respects the narrow boundaries.)

  $ hg --config extensions.lfs= clone --narrow ssh://user@dummy/master narrow \
  >    --include inside
  requesting all changes
  adding changesets
  adding manifests
  adding file changes
  added 3 changesets with 2 changes to 1 files
  new changesets *:* (glob)
  updating to branch default
  1 files updated, 0 files merged, 0 files removed, 0 files unresolved
  $ cd narrow

  $ hg update -q 0

Can not modify dirstate outside

  $ mkdir outside
  $ touch outside/f1
  $ hg debugwalk -v -I 'relglob:f1'
  * matcher:
  <includematcher includes='(?:(?:|.*/)f1(?:/|$))'>
  f  inside/f1  inside/f1
  $ hg add .
  $ hg add outside/f1
  abort: cannot track 'outside/f1' - it is outside the narrow clone
  [255]
  $ touch outside/f3
  $ hg add outside/f3
  abort: cannot track 'outside/f3' - it is outside the narrow clone
  [255]

But adding a truly excluded file shouldn't count

  $ hg add outside/f3 -X outside/f3

  $ rm -r outside

Can modify dirstate inside

  $ echo modified > inside/f1
  $ touch inside/f3
  $ hg add inside/f3
  $ hg status
  M inside/f1
  A inside/f3
  $ hg revert -qC .
  $ rm inside/f3

Can commit changes inside. Leaves outside unchanged.

  $ hg update -q 'desc("initial")'
  $ echo modified2 > inside/f1
  $ hg manifest --debug
  4d6a634d5ba06331a60c29ee0db8412490a54fcd 644   inside/f1
  7fb3bb6356d28d4dc352c5ba52d7350a81b6bd46 644   outside/f1 (flat !)
  d0f2f706468ab0e8bec7af87446835fb1b13511b 755 d outside/ (tree !)
  $ hg commit -m 'modify inside/f1'
  created new head
  $ hg files -r .
  inside/f1
  $ hg manifest --debug
  3f4197b4a11b9016e77ebc47fe566944885fd11b 644   inside/f1
  7fb3bb6356d28d4dc352c5ba52d7350a81b6bd46 644   outside/f1 (flat !)
  d0f2f706468ab0e8bec7af87446835fb1b13511b 755 d outside/ (tree !)
Some filesystems (notably FAT/exFAT only store timestamps with 2
seconds of precision, so by sleeping for 3 seconds, we can ensure that
the timestamps of files stored by dirstate will appear older than the
dirstate file, and therefore we'll be able to get stable output from
debugdirstate. If we don't do this, the test can be slightly flaky.
  $ sleep 3
  $ hg status
  $ hg debugdirstate --no-dates
  n 644         10 set                 inside/f1
