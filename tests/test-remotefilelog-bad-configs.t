#require no-windows

  $ . "$TESTDIR/remotefilelog-library.sh"

  $ hg init master
  $ cd master
  $ cat >> .hg/hgrc <<EOF
  > [remotefilelog]
  > server=True
  > EOF
  $ echo x > x
  $ echo y > y
  $ echo z > z
  $ hg commit -qAm xy

  $ cd ..

  $ hgcloneshallow ssh://user@dummy/master shallow -q
  3 files fetched over 1 fetches - (3 misses, 0.00% hit ratio) over *s (glob)
  $ cd shallow

Verify error message when noc achepath specified
  $ hg up -q null
  $ cp $HGRCPATH $HGRCPATH.bak
  $ grep -v cachepath < $HGRCPATH.bak > tmp
  $ mv tmp $HGRCPATH
  $ hg up tip
  abort: could not find config option remotefilelog.cachepath
  [255]
  $ mv $HGRCPATH.bak $HGRCPATH

Verify error message when no fallback specified

  $ hg up -q null
  $ rm .hg/hgrc
  $ clearcache
  $ hg up tip
  3 files fetched over 1 fetches - (3 misses, 0.00% hit ratio) over *s (glob)
  abort: no remotefilelog server configured - is your .hg/hgrc trusted?
  [255]
