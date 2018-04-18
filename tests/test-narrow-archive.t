Make a narrow clone then archive it
  $ . "$TESTDIR/narrow-library.sh"

  $ hg init master
  $ cd master

  $ for x in `$TESTDIR/seq.py 3`; do
  >   echo $x > "f$x"
  >   hg add "f$x"
  >   hg commit -m "Add $x"
  > done

  $ hg serve -a localhost -p $HGPORT1 -d --pid-file=hg.pid
  $ cat hg.pid >> "$DAEMON_PIDS"

  $ cd ..
  $ hg clone --narrow --include f1 --include f2 http://localhost:$HGPORT1/ narrowclone1
  requesting all changes
  adding changesets
  adding manifests
  adding file changes
  added 3 changesets with 2 changes to 2 files
  new changesets * (glob)
  updating to branch default
  2 files updated, 0 files merged, 0 files removed, 0 files unresolved

The tar should only contain f1 and f2
  $ cd narrowclone1
  $ hg archive -t tgz repo.tgz
  $ tar tfz repo.tgz
  repo/f1
  repo/f2
