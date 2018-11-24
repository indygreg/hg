#require no-windows

  $ . "$TESTDIR/remotefilelog-library.sh"

  $ cat >> $HGRCPATH <<EOF
  > [extensions]
  > remotefilelog=
  > share=
  > EOF

  $ hg init master
  $ cd master
  $ cat >> .hg/hgrc <<EOF
  > [remotefilelog]
  > server=True
  > EOF
  $ echo x > x
  $ hg commit -qAm x

  $ cd ..


  $ hgcloneshallow ssh://user@dummy/master source --noupdate -q
  $ hg share source dest
  updating working directory
  1 files updated, 0 files merged, 0 files removed, 0 files unresolved
  $ hg -R dest unshare
