#require lfs-test-server

  $ LFS_LISTEN="tcp://:$HGPORT"
  $ LFS_HOST="localhost:$HGPORT"
  $ LFS_PUBLIC=1
  $ export LFS_LISTEN LFS_HOST LFS_PUBLIC
#if no-windows
  $ lfs-test-server &> lfs-server.log &
  $ echo $! >> $DAEMON_PIDS
#else
  $ cat >> $TESTTMP/spawn.py <<EOF
  > import os
  > import subprocess
  > import sys
  > 
  > for path in os.environ["PATH"].split(os.pathsep):
  >     exe = os.path.join(path, 'lfs-test-server.exe')
  >     if os.path.exists(exe):
  >         with open('lfs-server.log', 'wb') as out:
  >             p = subprocess.Popen(exe, stdout=out, stderr=out)
  >             sys.stdout.write('%s\n' % p.pid)
  >             sys.exit(0)
  > sys.exit(1)
  > EOF
  $ $PYTHON $TESTTMP/spawn.py >> $DAEMON_PIDS
#endif

  $ cat >> $HGRCPATH <<EOF
  > [extensions]
  > lfs=
  > [lfs]
  > url=http://foo:bar@$LFS_HOST/
  > track=all()
  > EOF

  $ hg init repo1
  $ cd repo1
  $ echo THIS-IS-LFS > a
  $ hg commit -m a -A a

A push can be serviced directly from the usercache if it isn't in the local
store.

  $ hg init ../repo2
  $ mv .hg/store/lfs .hg/store/lfs_
  $ hg push ../repo2 -v
  pushing to ../repo2
  searching for changes
  lfs: uploading 31cf46fbc4ecd458a0943c5b4881f1f5a6dd36c53d6167d5b69ac45149b38e5b (12 bytes)
  lfs: processed: 31cf46fbc4ecd458a0943c5b4881f1f5a6dd36c53d6167d5b69ac45149b38e5b
  1 changesets found
  uncompressed size of bundle content:
       * (changelog) (glob)
       * (manifests) (glob)
       *  a (glob)
  adding changesets
  adding manifests
  adding file changes
  added 1 changesets with 1 changes to 1 files
  calling hook pretxnchangegroup.lfs: hgext.lfs.checkrequireslfs
  $ mv .hg/store/lfs_ .hg/store/lfs

Clear the cache to force a download
  $ rm -rf `hg config lfs.usercache`
  $ cd ../repo2
  $ hg update tip -v
  resolving manifests
  getting a
  lfs: downloading 31cf46fbc4ecd458a0943c5b4881f1f5a6dd36c53d6167d5b69ac45149b38e5b (12 bytes)
  lfs: adding 31cf46fbc4ecd458a0943c5b4881f1f5a6dd36c53d6167d5b69ac45149b38e5b to the usercache
  lfs: processed: 31cf46fbc4ecd458a0943c5b4881f1f5a6dd36c53d6167d5b69ac45149b38e5b
  lfs: found 31cf46fbc4ecd458a0943c5b4881f1f5a6dd36c53d6167d5b69ac45149b38e5b in the local lfs store
  1 files updated, 0 files merged, 0 files removed, 0 files unresolved

When the server has some blobs already

  $ hg mv a b
  $ echo ANOTHER-LARGE-FILE > c
  $ echo ANOTHER-LARGE-FILE2 > d
  $ hg commit -m b-and-c -A b c d
  $ hg push ../repo1 -v | grep -v '^  '
  pushing to ../repo1
  searching for changes
  lfs: need to transfer 2 objects (39 bytes)
  lfs: uploading 37a65ab78d5ecda767e8622c248b5dbff1e68b1678ab0e730d5eb8601ec8ad19 (20 bytes)
  lfs: processed: 37a65ab78d5ecda767e8622c248b5dbff1e68b1678ab0e730d5eb8601ec8ad19
  lfs: uploading d11e1a642b60813aee592094109b406089b8dff4cb157157f753418ec7857998 (19 bytes)
  lfs: processed: d11e1a642b60813aee592094109b406089b8dff4cb157157f753418ec7857998
  1 changesets found
  uncompressed size of bundle content:
  adding changesets
  adding manifests
  adding file changes
  added 1 changesets with 3 changes to 3 files

Clear the cache to force a download
  $ rm -rf `hg config lfs.usercache`
  $ hg --repo ../repo1 update tip -v
  resolving manifests
  getting b
  lfs: found 31cf46fbc4ecd458a0943c5b4881f1f5a6dd36c53d6167d5b69ac45149b38e5b in the local lfs store
  getting c
  lfs: downloading d11e1a642b60813aee592094109b406089b8dff4cb157157f753418ec7857998 (19 bytes)
  lfs: adding d11e1a642b60813aee592094109b406089b8dff4cb157157f753418ec7857998 to the usercache
  lfs: processed: d11e1a642b60813aee592094109b406089b8dff4cb157157f753418ec7857998
  lfs: found d11e1a642b60813aee592094109b406089b8dff4cb157157f753418ec7857998 in the local lfs store
  getting d
  lfs: downloading 37a65ab78d5ecda767e8622c248b5dbff1e68b1678ab0e730d5eb8601ec8ad19 (20 bytes)
  lfs: adding 37a65ab78d5ecda767e8622c248b5dbff1e68b1678ab0e730d5eb8601ec8ad19 to the usercache
  lfs: processed: 37a65ab78d5ecda767e8622c248b5dbff1e68b1678ab0e730d5eb8601ec8ad19
  lfs: found 37a65ab78d5ecda767e8622c248b5dbff1e68b1678ab0e730d5eb8601ec8ad19 in the local lfs store
  3 files updated, 0 files merged, 0 files removed, 0 files unresolved

Test a corrupt file download, but clear the cache first to force a download.

  $ rm -rf `hg config lfs.usercache`
  $ cp $TESTTMP/lfs-content/d1/1e/1a642b60813aee592094109b406089b8dff4cb157157f753418ec7857998 blob
  $ echo 'damage' > $TESTTMP/lfs-content/d1/1e/1a642b60813aee592094109b406089b8dff4cb157157f753418ec7857998
  $ rm ../repo1/.hg/store/lfs/objects/d1/1e1a642b60813aee592094109b406089b8dff4cb157157f753418ec7857998
  $ rm ../repo1/*

  $ hg --repo ../repo1 update -C tip -v
  resolving manifests
  getting a
  lfs: found 31cf46fbc4ecd458a0943c5b4881f1f5a6dd36c53d6167d5b69ac45149b38e5b in the local lfs store
  getting b
  lfs: found 31cf46fbc4ecd458a0943c5b4881f1f5a6dd36c53d6167d5b69ac45149b38e5b in the local lfs store
  getting c
  lfs: downloading d11e1a642b60813aee592094109b406089b8dff4cb157157f753418ec7857998 (19 bytes)
  abort: corrupt remote lfs object: d11e1a642b60813aee592094109b406089b8dff4cb157157f753418ec7857998
  [255]

The corrupted blob is not added to the usercache or local store

  $ test -f ../repo1/.hg/store/lfs/objects/d1/1e1a642b60813aee592094109b406089b8dff4cb157157f753418ec7857998
  [1]
  $ test -f `hg config lfs.usercache`/d1/1e1a642b60813aee592094109b406089b8dff4cb157157f753418ec7857998
  [1]
  $ cp blob $TESTTMP/lfs-content/d1/1e/1a642b60813aee592094109b406089b8dff4cb157157f753418ec7857998

Test a corrupted file upload

  $ echo 'another lfs blob' > b
  $ hg ci -m 'another blob'
  $ echo 'damage' > .hg/store/lfs/objects/e6/59058e26b07b39d2a9c7145b3f99b41f797b6621c8076600e9cb7ee88291f0
  $ hg push -v ../repo1
  pushing to ../repo1
  searching for changes
  lfs: uploading e659058e26b07b39d2a9c7145b3f99b41f797b6621c8076600e9cb7ee88291f0 (17 bytes)
  abort: detected corrupt lfs object: e659058e26b07b39d2a9c7145b3f99b41f797b6621c8076600e9cb7ee88291f0
  (run hg verify)
  [255]

Check error message when the remote missed a blob:

  $ echo FFFFF > b
  $ hg commit -m b -A b
  $ echo FFFFF >> b
  $ hg commit -m b b
  $ rm -rf .hg/store/lfs
  $ rm -rf `hg config lfs.usercache`
  $ hg update -C '.^'
  abort: LFS server error. Remote object for "b" not found:(.*)! (re)
  [255]

Check error message when object does not exist:

  $ cd $TESTTMP
  $ hg init test && cd test
  $ echo "[extensions]" >> .hg/hgrc
  $ echo "lfs=" >> .hg/hgrc
  $ echo "[lfs]" >> .hg/hgrc
  $ echo "threshold=1" >> .hg/hgrc
  $ echo a > a
  $ hg add a
  $ hg commit -m 'test'
  $ echo aaaaa > a
  $ hg commit -m 'largefile'
  $ hg debugdata .hg/store/data/a.i 1 # verify this is no the file content but includes "oid", the LFS "pointer".
  version https://git-lfs.github.com/spec/v1
  oid sha256:bdc26931acfb734b142a8d675f205becf27560dc461f501822de13274fe6fc8a
  size 6
  x-is-binary 0
  $ cd ..
  $ rm -rf `hg config lfs.usercache`

(Restart the server in a different location so it no longer has the content)

  $ $PYTHON $RUNTESTDIR/killdaemons.py $DAEMON_PIDS
  $ rm $DAEMON_PIDS
  $ mkdir $TESTTMP/lfs-server2
  $ cd $TESTTMP/lfs-server2
#if no-windows
  $ lfs-test-server &> lfs-server.log &
  $ echo $! >> $DAEMON_PIDS
#else
  $ $PYTHON $TESTTMP/spawn.py >> $DAEMON_PIDS
#endif

  $ cd $TESTTMP
  $ hg clone test test2
  updating to branch default
  abort: LFS server error. Remote object for "a" not found:(.*)! (re)
  [255]

  $ $PYTHON $RUNTESTDIR/killdaemons.py $DAEMON_PIDS
