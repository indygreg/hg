#require no-reposimplestore

In this test, we want to test LFS bundle application on both LFS and non-LFS
repos.

To make it more interesting, the file revisions will contain hg filelog
metadata ('\1\n'). The bundle will have 1 file revision overlapping with the
destination repo.

#  rev      1          2         3
#  repo:    yes        yes       no
#  bundle:  no (base)  yes       yes (deltabase: 2 if possible)

It is interesting because rev 2 could have been stored as LFS in the repo, and
non-LFS in the bundle; or vice-versa.

Init

  $ cat >> $HGRCPATH << EOF
  > [extensions]
  > lfs=
  > drawdag=$TESTDIR/drawdag.py
  > [lfs]
  > url=file:$TESTTMP/lfs-remote
  > EOF

Helper functions

  $ commitxy() {
  > hg debugdrawdag "$@" <<'EOS'
  >  Y  # Y/X=\1\nAAAA\nE\nF
  >  |  # Y/Y=\1\nAAAA\nG\nH
  >  X  # X/X=\1\nAAAA\nC\n
  >     # X/Y=\1\nAAAA\nD\n
  > EOS
  > }

  $ commitz() {
  > hg debugdrawdag "$@" <<'EOS'
  >  Z  # Z/X=\1\nAAAA\nI\n
  >  |  # Z/Y=\1\nAAAA\nJ\n
  >  |  # Z/Z=\1\nZ
  >  Y
  > EOS
  > }

  $ enablelfs() {
  >   cat >> .hg/hgrc <<EOF
  > [lfs]
  > track=all()
  > EOF
  > }

Generate bundles

  $ for i in normal lfs; do
  >   NAME=src-$i
  >   hg init $TESTTMP/$NAME
  >   cd $TESTTMP/$NAME
  >   [ $i = lfs ] && enablelfs
  >   commitxy
  >   commitz
  >   hg bundle -q --base X -r Y+Z $TESTTMP/$NAME.bundle
  >   SRCNAMES="$SRCNAMES $NAME"
  > done

Prepare destination repos

  $ for i in normal lfs; do
  >   NAME=dst-$i
  >   hg init $TESTTMP/$NAME
  >   cd $TESTTMP/$NAME
  >   [ $i = lfs ] && enablelfs
  >   commitxy
  >   DSTNAMES="$DSTNAMES $NAME"
  > done

Apply bundles

  $ for i in $SRCNAMES; do
  >   for j in $DSTNAMES; do
  >     echo ---- Applying $i.bundle to $j ----
  >     cp -R $TESTTMP/$j $TESTTMP/tmp-$i-$j
  >     cd $TESTTMP/tmp-$i-$j
  >     if hg unbundle $TESTTMP/$i.bundle -q 2>/dev/null; then
  >       hg verify -q && echo OK
  >     else
  >       echo CRASHED
  >     fi
  >   done
  > done
  ---- Applying src-normal.bundle to dst-normal ----
  OK
  ---- Applying src-normal.bundle to dst-lfs ----
  OK
  ---- Applying src-lfs.bundle to dst-normal ----
  OK
  ---- Applying src-lfs.bundle to dst-lfs ----
  OK
