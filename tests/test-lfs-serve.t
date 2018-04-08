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
  > [lfs]
  > usercache = null://
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

  $ hg push -q
  $ grep 'lfs' .hg/requires $SERVER_REQUIRES
  .hg/requires:lfs
  $TESTTMP/server/.hg/requires:lfs

  $ hg clone -q http://localhost:$HGPORT $TESTTMP/client6_clone
  $ grep 'lfs' $TESTTMP/client6_clone/.hg/requires $SERVER_REQUIRES
  $TESTTMP/client6_clone/.hg/requires:lfs
  $TESTTMP/server/.hg/requires:lfs

  $ hg init $TESTTMP/client6_pull
  $ hg -R $TESTTMP/client6_pull pull -q http://localhost:$HGPORT
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
