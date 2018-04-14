#testcases lfsremote-on lfsremote-off
#require serve no-reposimplestore

This test splits `hg serve` with and without using the extension into separate
tests cases.  The tests are broken down as follows, where "LFS"/"No-LFS"
indicates whether or not there are commits that use an LFS file, and "D"/"E"
indicates whether or not the extension is loaded.  The "X" cases are not tested
individually, because the lfs requirement causes the process to bail early if
the extension is disabled.

.                        Server
.
.                    No-LFS        LFS
.            +----------------------------+
.            |   ||  D  |  E  |  D  |  E  |
.            |---++=======================|
.  C         | D || N/A | #1  |  X  | #4  |
.  l    No   +---++-----------------------|
.  i    LFS  | E || #2  | #2  |  X  | #5  |
.  e         +---++-----------------------|
.  n         | D ||  X  |  X  |  X  |  X  |
.  t    LFS  |---++-----------------------|
.            | E || #3  | #3  |  X  | #6  |
.            |---++-----------------------+

  $ hg init server
  $ SERVER_REQUIRES="$TESTTMP/server/.hg/requires"

Skip the experimental.changegroup3=True config.  Failure to agree on this comes
first, and causes a "ValueError: no common changegroup version" or "abort:
HTTP Error 500: Internal Server Error", if the extension is only loaded on one
side.  If that *is* enabled, the subsequent failure is "abort: missing processor
for flag '0x2000'!" if the extension is only loaded on one side (possibly also
masked by the Internal Server Error message).
  $ cat >> $HGRCPATH <<EOF
  > [experimental]
  > lfs.disableusercache = True
  > [lfs]
  > threshold=10
  > [web]
  > allow_push=*
  > push_ssl=False
  > EOF

#if lfsremote-on
  $ hg --config extensions.lfs= -R server \
  >    serve -p $HGPORT -d --pid-file=hg.pid --errorlog=$TESTTMP/errors.log
#else
  $ hg --config extensions.lfs=! -R server \
  >    serve -p $HGPORT -d --pid-file=hg.pid --errorlog=$TESTTMP/errors.log
#endif

  $ cat hg.pid >> $DAEMON_PIDS
  $ hg clone -q http://localhost:$HGPORT client
  $ grep 'lfs' client/.hg/requires $SERVER_REQUIRES
  [1]

--------------------------------------------------------------------------------
Case #1: client with non-lfs content and the extension disabled; server with
non-lfs content, and the extension enabled.

  $ cd client
  $ echo 'non-lfs' > nonlfs.txt
  $ hg ci -Aqm 'non-lfs'
  $ grep 'lfs' .hg/requires $SERVER_REQUIRES
  [1]

#if lfsremote-on

  $ hg push -q
  $ grep 'lfs' .hg/requires $SERVER_REQUIRES
  [1]

  $ hg clone -q http://localhost:$HGPORT $TESTTMP/client1_clone
  $ grep 'lfs' $TESTTMP/client1_clone/.hg/requires $SERVER_REQUIRES
  [1]

  $ hg init $TESTTMP/client1_pull
  $ hg -R $TESTTMP/client1_pull pull -q http://localhost:$HGPORT
  $ grep 'lfs' $TESTTMP/client1_pull/.hg/requires $SERVER_REQUIRES
  [1]

  $ hg identify http://localhost:$HGPORT
  d437e1d24fbd

#endif

--------------------------------------------------------------------------------
Case #2: client with non-lfs content and the extension enabled; server with
non-lfs content, and the extension state controlled by #testcases.

  $ cat >> $HGRCPATH <<EOF
  > [extensions]
  > lfs =
  > EOF
  $ echo 'non-lfs' > nonlfs2.txt
  $ hg ci -Aqm 'non-lfs file with lfs client'

Since no lfs content has been added yet, the push is allowed, even when the
extension is not enabled remotely.

  $ hg push -q
  $ grep 'lfs' .hg/requires $SERVER_REQUIRES
  [1]

  $ hg clone -q http://localhost:$HGPORT $TESTTMP/client2_clone
  $ grep 'lfs' $TESTTMP/client2_clone/.hg/requires $SERVER_REQUIRES
  [1]

  $ hg init $TESTTMP/client2_pull
  $ hg -R $TESTTMP/client2_pull pull -q http://localhost:$HGPORT
  $ grep 'lfs' $TESTTMP/client2_pull/.hg/requires $SERVER_REQUIRES
  [1]

  $ hg identify http://localhost:$HGPORT
  1477875038c6

--------------------------------------------------------------------------------
Case #3: client with lfs content and the extension enabled; server with
non-lfs content, and the extension state controlled by #testcases.  The server
should have an 'lfs' requirement after it picks up its first commit with a blob.

  $ echo 'this is a big lfs file' > lfs.bin
  $ hg ci -Aqm 'lfs'
  $ grep 'lfs' .hg/requires $SERVER_REQUIRES
  .hg/requires:lfs

#if lfsremote-off
  $ hg push -q
  abort: required features are not supported in the destination: lfs
  (enable the lfs extension on the server)
  [255]
#else
  $ hg push -q
#endif
  $ grep 'lfs' .hg/requires $SERVER_REQUIRES
  .hg/requires:lfs
  $TESTTMP/server/.hg/requires:lfs (lfsremote-on !)

  $ hg clone -q http://localhost:$HGPORT $TESTTMP/client3_clone
  $ grep 'lfs' $TESTTMP/client3_clone/.hg/requires $SERVER_REQUIRES || true
  $TESTTMP/client3_clone/.hg/requires:lfs (lfsremote-on !)
  $TESTTMP/server/.hg/requires:lfs (lfsremote-on !)

  $ hg init $TESTTMP/client3_pull
  $ hg -R $TESTTMP/client3_pull pull -q http://localhost:$HGPORT
  $ grep 'lfs' $TESTTMP/client3_pull/.hg/requires $SERVER_REQUIRES || true
  $TESTTMP/client3_pull/.hg/requires:lfs (lfsremote-on !)
  $TESTTMP/server/.hg/requires:lfs (lfsremote-on !)

The difference here is the push failed above when the extension isn't
enabled on the server.
  $ hg identify http://localhost:$HGPORT
  8374dc4052cb (lfsremote-on !)
  1477875038c6 (lfsremote-off !)

Don't bother testing the lfsremote-off cases- the server won't be able
to launch if there's lfs content and the extension is disabled.

#if lfsremote-on

--------------------------------------------------------------------------------
Case #4: client with non-lfs content and the extension disabled; server with
lfs content, and the extension enabled.

  $ cat >> $HGRCPATH <<EOF
  > [extensions]
  > lfs = !
  > EOF

  $ hg init $TESTTMP/client4
  $ cd $TESTTMP/client4
  $ cat >> .hg/hgrc <<EOF
  > [paths]
  > default = http://localhost:$HGPORT
  > EOF
  $ echo 'non-lfs' > nonlfs2.txt
  $ hg ci -Aqm 'non-lfs'
  $ grep 'lfs' .hg/requires $SERVER_REQUIRES
  $TESTTMP/server/.hg/requires:lfs

  $ hg push -q --force
  warning: repository is unrelated
  $ grep 'lfs' .hg/requires $SERVER_REQUIRES
  $TESTTMP/server/.hg/requires:lfs

TODO: fail more gracefully.

  $ hg clone -q http://localhost:$HGPORT $TESTTMP/client4_clone
  abort: HTTP Error 500: Internal Server Error
  [255]
  $ grep 'lfs' $TESTTMP/client4_clone/.hg/requires $SERVER_REQUIRES
  grep: $TESTTMP/client4_clone/.hg/requires: $ENOENT$
  $TESTTMP/server/.hg/requires:lfs
  [2]

TODO: fail more gracefully.

  $ hg init $TESTTMP/client4_pull
  $ hg -R $TESTTMP/client4_pull pull -q http://localhost:$HGPORT
  abort: HTTP Error 500: Internal Server Error
  [255]
  $ grep 'lfs' $TESTTMP/client4_pull/.hg/requires $SERVER_REQUIRES
  $TESTTMP/server/.hg/requires:lfs

  $ hg identify http://localhost:$HGPORT
  03b080fa9d93

--------------------------------------------------------------------------------
Case #5: client with non-lfs content and the extension enabled; server with
lfs content, and the extension enabled.

  $ cat >> $HGRCPATH <<EOF
  > [extensions]
  > lfs =
  > EOF
  $ echo 'non-lfs' > nonlfs3.txt
  $ hg ci -Aqm 'non-lfs file with lfs client'

  $ hg push -q
  $ grep 'lfs' .hg/requires $SERVER_REQUIRES
  $TESTTMP/server/.hg/requires:lfs

  $ hg clone -q http://localhost:$HGPORT $TESTTMP/client5_clone
  $ grep 'lfs' $TESTTMP/client5_clone/.hg/requires $SERVER_REQUIRES
  $TESTTMP/client5_clone/.hg/requires:lfs
  $TESTTMP/server/.hg/requires:lfs

  $ hg init $TESTTMP/client5_pull
  $ hg -R $TESTTMP/client5_pull pull -q http://localhost:$HGPORT
  $ grep 'lfs' $TESTTMP/client5_pull/.hg/requires $SERVER_REQUIRES
  $TESTTMP/client5_pull/.hg/requires:lfs
  $TESTTMP/server/.hg/requires:lfs

  $ hg identify http://localhost:$HGPORT
  c729025cc5e3

--------------------------------------------------------------------------------
Case #6: client with lfs content and the extension enabled; server with
lfs content, and the extension enabled.

  $ echo 'this is another lfs file' > lfs2.txt
  $ hg ci -Aqm 'lfs file with lfs client'

  $ hg --config paths.default= push -v http://localhost:$HGPORT
  pushing to http://localhost:$HGPORT/
  lfs: assuming remote store: http://localhost:$HGPORT/.git/info/lfs
  searching for changes
  remote has heads on branch 'default' that are not known locally: 8374dc4052cb
  lfs: uploading a82f1c5cea0d40e3bb3a849686bb4e6ae47ca27e614de55c1ed0325698ef68de (25 bytes)
  lfs: processed: a82f1c5cea0d40e3bb3a849686bb4e6ae47ca27e614de55c1ed0325698ef68de
  lfs: uploaded 1 files (25 bytes)
  1 changesets found
  uncompressed size of bundle content:
       206 (changelog)
       172 (manifests)
       275  lfs2.txt
  remote: adding changesets
  remote: adding manifests
  remote: adding file changes
  remote: added 1 changesets with 1 changes to 1 files
  $ grep 'lfs' .hg/requires $SERVER_REQUIRES
  .hg/requires:lfs
  $TESTTMP/server/.hg/requires:lfs

  $ hg clone -q http://localhost:$HGPORT $TESTTMP/client6_clone
  $ grep 'lfs' $TESTTMP/client6_clone/.hg/requires $SERVER_REQUIRES
  $TESTTMP/client6_clone/.hg/requires:lfs
  $TESTTMP/server/.hg/requires:lfs

  $ hg init $TESTTMP/client6_pull
  $ hg -R $TESTTMP/client6_pull pull -u -v http://localhost:$HGPORT
  pulling from http://localhost:$HGPORT/
  requesting all changes
  adding changesets
  adding manifests
  adding file changes
  added 6 changesets with 5 changes to 5 files (+1 heads)
  calling hook pretxnchangegroup.lfs: hgext.lfs.checkrequireslfs
  new changesets d437e1d24fbd:d3b84d50eacb
  resolving manifests
  lfs: assuming remote store: http://localhost:$HGPORT/.git/info/lfs
  lfs: downloading a82f1c5cea0d40e3bb3a849686bb4e6ae47ca27e614de55c1ed0325698ef68de (25 bytes)
  lfs: processed: a82f1c5cea0d40e3bb3a849686bb4e6ae47ca27e614de55c1ed0325698ef68de
  getting lfs2.txt
  lfs: found a82f1c5cea0d40e3bb3a849686bb4e6ae47ca27e614de55c1ed0325698ef68de in the local lfs store
  getting nonlfs2.txt
  getting nonlfs3.txt
  3 files updated, 0 files merged, 0 files removed, 0 files unresolved
  updated to "d3b84d50eacb: lfs file with lfs client"
  1 other heads for branch "default"
  $ grep 'lfs' $TESTTMP/client6_pull/.hg/requires $SERVER_REQUIRES
  $TESTTMP/client6_pull/.hg/requires:lfs
  $TESTTMP/server/.hg/requires:lfs

  $ hg identify http://localhost:$HGPORT
  d3b84d50eacb

--------------------------------------------------------------------------------
Misc: process dies early if a requirement exists and the extension is disabled

  $ hg --config extensions.lfs=! summary
  abort: repository requires features unknown to this Mercurial: lfs!
  (see https://mercurial-scm.org/wiki/MissingRequirement for more information)
  [255]

  $ echo 'this is an lfs file' > $TESTTMP/client6_clone/lfspair1.bin
  $ echo 'this is an lfs file too' > $TESTTMP/client6_clone/lfspair2.bin
  $ hg -R $TESTTMP/client6_clone ci -Aqm 'add lfs pair'
  $ hg -R $TESTTMP/client6_clone push -q

  $ hg clone -qU http://localhost:$HGPORT $TESTTMP/bulkfetch

Export will prefetch all needed files across all needed revisions

  $ hg -R $TESTTMP/bulkfetch -v export -r 0:tip -o all.export
  lfs: assuming remote store: http://localhost:$HGPORT/.git/info/lfs
  exporting patches:
  lfs: assuming remote store: http://localhost:$HGPORT/.git/info/lfs
  lfs: need to transfer 4 objects (92 bytes)
  lfs: downloading a82f1c5cea0d40e3bb3a849686bb4e6ae47ca27e614de55c1ed0325698ef68de (25 bytes)
  lfs: processed: a82f1c5cea0d40e3bb3a849686bb4e6ae47ca27e614de55c1ed0325698ef68de
  lfs: downloading bed80f00180ac404b843628ab56a1c1984d6145c391cd1628a7dd7d2598d71fc (23 bytes)
  lfs: processed: bed80f00180ac404b843628ab56a1c1984d6145c391cd1628a7dd7d2598d71fc
  lfs: downloading cf1b2787b74e66547d931b6ebe28ff63303e803cb2baa14a8f57c4383d875782 (20 bytes)
  lfs: processed: cf1b2787b74e66547d931b6ebe28ff63303e803cb2baa14a8f57c4383d875782
  lfs: downloading d96eda2c74b56e95cfb5ffb66b6503e198cc6fc4a09dc877de925feebc65786e (24 bytes)
  lfs: processed: d96eda2c74b56e95cfb5ffb66b6503e198cc6fc4a09dc877de925feebc65786e
  all.export
  lfs: found bed80f00180ac404b843628ab56a1c1984d6145c391cd1628a7dd7d2598d71fc in the local lfs store
  lfs: found a82f1c5cea0d40e3bb3a849686bb4e6ae47ca27e614de55c1ed0325698ef68de in the local lfs store
  lfs: found cf1b2787b74e66547d931b6ebe28ff63303e803cb2baa14a8f57c4383d875782 in the local lfs store
  lfs: found d96eda2c74b56e95cfb5ffb66b6503e198cc6fc4a09dc877de925feebc65786e in the local lfs store

Export with selected files is used with `extdiff --patch`

  $ rm -r $TESTTMP/bulkfetch/.hg/store/lfs
  $ hg --config extensions.extdiff= \
  >    -R $TESTTMP/bulkfetch -v extdiff -r 2:tip --patch $TESTTMP/bulkfetch/lfs.bin
  lfs: assuming remote store: http://localhost:$HGPORT/.git/info/lfs
  lfs: assuming remote store: http://localhost:$HGPORT/.git/info/lfs
  lfs: downloading bed80f00180ac404b843628ab56a1c1984d6145c391cd1628a7dd7d2598d71fc (23 bytes)
  lfs: processed: bed80f00180ac404b843628ab56a1c1984d6145c391cd1628a7dd7d2598d71fc
  */hg-8374dc4052cb.patch (glob)
  lfs: found bed80f00180ac404b843628ab56a1c1984d6145c391cd1628a7dd7d2598d71fc in the local lfs store
  */hg-9640b57e77b1.patch (glob)
  --- */hg-8374dc4052cb.patch	* (glob)
  +++ */hg-9640b57e77b1.patch	* (glob)
  @@ -2,12 +2,7 @@
   # User test
   # Date 0 0
   #      Thu Jan 01 00:00:00 1970 +0000
  -# Node ID 8374dc4052cbd388e79d9dc4ddb29784097aa354
  -# Parent  1477875038c60152e391238920a16381c627b487
  -lfs
  +# Node ID 9640b57e77b14c3a0144fb4478b6cc13e13ea0d1
  +# Parent  d3b84d50eacbd56638e11abce6b8616aaba54420
  +add lfs pair
   
  -diff -r 1477875038c6 -r 8374dc4052cb lfs.bin
  ---- /dev/null	Thu Jan 01 00:00:00 1970 +0000
  -+++ b/lfs.bin	Thu Jan 01 00:00:00 1970 +0000
  -@@ -0,0 +1,1 @@
  -+this is a big lfs file
  cleaning up temp directory
  [1]

#endif

  $ $PYTHON $TESTDIR/killdaemons.py $DAEMON_PIDS

#if lfsremote-on
  $ cat $TESTTMP/errors.log | grep '^[A-Z]'
  Traceback (most recent call last):
  ValueError: no common changegroup version
  Traceback (most recent call last):
  ValueError: no common changegroup version
#else
  $ cat $TESTTMP/errors.log
#endif
