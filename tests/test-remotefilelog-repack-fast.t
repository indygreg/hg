#require no-windows

  $ . "$TESTDIR/remotefilelog-library.sh"

  $ cat >> $HGRCPATH <<EOF
  > [remotefilelog]
  > fastdatapack=True
  > EOF

  $ hg init master
  $ cd master
  $ cat >> .hg/hgrc <<EOF
  > [remotefilelog]
  > server=True
  > serverexpiration=-1
  > EOF
  $ echo x > x
  $ hg commit -qAm x
  $ echo x >> x
  $ hg commit -qAm x2
  $ cd ..

  $ hgcloneshallow ssh://user@dummy/master shallow -q
  1 files fetched over 1 fetches - (1 misses, 0.00% hit ratio) over *s (glob)

# Set the prefetchdays config to zero so that all commits are prefetched
# no matter what their creation date is.
  $ cd shallow
  $ cat >> .hg/hgrc <<EOF
  > [remotefilelog]
  > prefetchdays=0
  > EOF
  $ cd ..

# Test that repack cleans up the old files and creates new packs

  $ cd shallow
  $ find $CACHEDIR | sort
  $TESTTMP/hgcache
  $TESTTMP/hgcache/master
  $TESTTMP/hgcache/master/11
  $TESTTMP/hgcache/master/11/f6ad8ec52a2984abaafd7c3b516503785c2072
  $TESTTMP/hgcache/master/11/f6ad8ec52a2984abaafd7c3b516503785c2072/aee31534993a501858fb6dd96a065671922e7d51
  $TESTTMP/hgcache/repos

  $ hg repack

  $ find $CACHEDIR | sort
  $TESTTMP/hgcache
  $TESTTMP/hgcache/master
  $TESTTMP/hgcache/master/packs
  $TESTTMP/hgcache/master/packs/1e91b207daf5d7b48f1be9c587d6b5ae654ce78c.histidx
  $TESTTMP/hgcache/master/packs/1e91b207daf5d7b48f1be9c587d6b5ae654ce78c.histpack
  $TESTTMP/hgcache/master/packs/b1e0cfc7f345e408a7825e3081501959488d59ce.dataidx
  $TESTTMP/hgcache/master/packs/b1e0cfc7f345e408a7825e3081501959488d59ce.datapack
  $TESTTMP/hgcache/master/packs/repacklock
  $TESTTMP/hgcache/repos

# Test that the packs are readonly
  $ ls_l $CACHEDIR/master/packs
  -r--r--r--    1145 1e91b207daf5d7b48f1be9c587d6b5ae654ce78c.histidx
  -r--r--r--     172 1e91b207daf5d7b48f1be9c587d6b5ae654ce78c.histpack
  -r--r--r--    1074 b1e0cfc7f345e408a7825e3081501959488d59ce.dataidx
  -r--r--r--      72 b1e0cfc7f345e408a7825e3081501959488d59ce.datapack
  -rw-r--r--       0 repacklock

# Test that the data in the new packs is accessible
  $ hg cat -r . x
  x
  x

# Test that adding new data and repacking it results in the loose data and the
# old packs being combined.

  $ cd ../master
  $ echo x >> x
  $ hg commit -m x3
  $ cd ../shallow
  $ hg pull -q
  $ hg up -q tip
  1 files fetched over 1 fetches - (1 misses, 0.00% hit ratio) over * (glob)

  $ find $CACHEDIR -type f | sort
  $TESTTMP/hgcache/master/11/f6ad8ec52a2984abaafd7c3b516503785c2072/d4a3ed9310e5bd9887e3bf779da5077efab28216
  $TESTTMP/hgcache/master/packs/1e91b207daf5d7b48f1be9c587d6b5ae654ce78c.histidx
  $TESTTMP/hgcache/master/packs/1e91b207daf5d7b48f1be9c587d6b5ae654ce78c.histpack
  $TESTTMP/hgcache/master/packs/b1e0cfc7f345e408a7825e3081501959488d59ce.dataidx
  $TESTTMP/hgcache/master/packs/b1e0cfc7f345e408a7825e3081501959488d59ce.datapack
  $TESTTMP/hgcache/master/packs/repacklock
  $TESTTMP/hgcache/repos

  $ hg repack --traceback

  $ find $CACHEDIR -type f | sort
  $TESTTMP/hgcache/master/packs/78840d69389c7404327f7477e3931c89945c37d1.dataidx
  $TESTTMP/hgcache/master/packs/78840d69389c7404327f7477e3931c89945c37d1.datapack
  $TESTTMP/hgcache/master/packs/8abe7889aae389337d12ebe6085d4ee13854c7c9.histidx
  $TESTTMP/hgcache/master/packs/8abe7889aae389337d12ebe6085d4ee13854c7c9.histpack
  $TESTTMP/hgcache/master/packs/repacklock
  $TESTTMP/hgcache/repos

# Verify all the file data is still available
  $ hg cat -r . x
  x
  x
  x
  $ hg cat -r '.^' x
  x
  x

# Test that repacking again without new data does not delete the pack files
# and did not change the pack names
  $ hg repack
  $ find $CACHEDIR -type f | sort
  $TESTTMP/hgcache/master/packs/78840d69389c7404327f7477e3931c89945c37d1.dataidx
  $TESTTMP/hgcache/master/packs/78840d69389c7404327f7477e3931c89945c37d1.datapack
  $TESTTMP/hgcache/master/packs/8abe7889aae389337d12ebe6085d4ee13854c7c9.histidx
  $TESTTMP/hgcache/master/packs/8abe7889aae389337d12ebe6085d4ee13854c7c9.histpack
  $TESTTMP/hgcache/master/packs/repacklock
  $TESTTMP/hgcache/repos

# Run two repacks at once
  $ hg repack --config "hooks.prerepack=sleep 3" &
  $ sleep 1
  $ hg repack
  skipping repack - another repack is already running
  $ hg debugwaitonrepack >/dev/null 2>&1

# Run repack in the background
  $ cd ../master
  $ echo x >> x
  $ hg commit -m x4
  $ cd ../shallow
  $ hg pull -q
  $ hg up -q tip
  1 files fetched over 1 fetches - (1 misses, 0.00% hit ratio) over * (glob)
  $ find $CACHEDIR -type f | sort
  $TESTTMP/hgcache/master/11/f6ad8ec52a2984abaafd7c3b516503785c2072/1bb2e6237e035c8f8ef508e281f1ce075bc6db72
  $TESTTMP/hgcache/master/packs/78840d69389c7404327f7477e3931c89945c37d1.dataidx
  $TESTTMP/hgcache/master/packs/78840d69389c7404327f7477e3931c89945c37d1.datapack
  $TESTTMP/hgcache/master/packs/8abe7889aae389337d12ebe6085d4ee13854c7c9.histidx
  $TESTTMP/hgcache/master/packs/8abe7889aae389337d12ebe6085d4ee13854c7c9.histpack
  $TESTTMP/hgcache/master/packs/repacklock
  $TESTTMP/hgcache/repos

  $ hg repack --background
  (running background repack)
  $ sleep 0.5
  $ hg debugwaitonrepack >/dev/null 2>&1
  $ find $CACHEDIR -type f | sort
  $TESTTMP/hgcache/master/packs/39443fa1064182e93d968b5cba292eb5283260d0.dataidx
  $TESTTMP/hgcache/master/packs/39443fa1064182e93d968b5cba292eb5283260d0.datapack
  $TESTTMP/hgcache/master/packs/604552d403a1381749faf656feca0ca265a6d52c.histidx
  $TESTTMP/hgcache/master/packs/604552d403a1381749faf656feca0ca265a6d52c.histpack
  $TESTTMP/hgcache/master/packs/repacklock
  $TESTTMP/hgcache/repos

# Test debug commands

  $ hg debugdatapack $TESTTMP/hgcache/master/packs/*.datapack
  $TESTTMP/hgcache/master/packs/39443fa1064182e93d968b5cba292eb5283260d0:
  x:
  Node          Delta Base    Delta Length  Blob Size
  1bb2e6237e03  000000000000  8             8
  d4a3ed9310e5  1bb2e6237e03  12            6
  aee31534993a  d4a3ed9310e5  12            4
  
  Total:                      32            18        (77.8% bigger)
  $ hg debugdatapack --long $TESTTMP/hgcache/master/packs/*.datapack
  $TESTTMP/hgcache/master/packs/39443fa1064182e93d968b5cba292eb5283260d0:
  x:
  Node                                      Delta Base                                Delta Length  Blob Size
  1bb2e6237e035c8f8ef508e281f1ce075bc6db72  0000000000000000000000000000000000000000  8             8
  d4a3ed9310e5bd9887e3bf779da5077efab28216  1bb2e6237e035c8f8ef508e281f1ce075bc6db72  12            6
  aee31534993a501858fb6dd96a065671922e7d51  d4a3ed9310e5bd9887e3bf779da5077efab28216  12            4
  
  Total:                                                                              32            18        (77.8% bigger)
  $ hg debugdatapack $TESTTMP/hgcache/master/packs/*.datapack --node d4a3ed9310e5bd9887e3bf779da5077efab28216
  $TESTTMP/hgcache/master/packs/39443fa1064182e93d968b5cba292eb5283260d0:
  
  x
  Node                                      Delta Base                                Delta SHA1                                Delta Length
  d4a3ed9310e5bd9887e3bf779da5077efab28216  1bb2e6237e035c8f8ef508e281f1ce075bc6db72  77029ab56e83ea2115dd53ff87483682abe5d7ca  12
  Node                                      Delta Base                                Delta SHA1                                Delta Length
  1bb2e6237e035c8f8ef508e281f1ce075bc6db72  0000000000000000000000000000000000000000  7ca8c71a64f7b56380e77573da2f7a5fdd2ecdb5  8
  $ hg debughistorypack $TESTTMP/hgcache/master/packs/*.histidx
  
  x
  Node          P1 Node       P2 Node       Link Node     Copy From
  1bb2e6237e03  d4a3ed9310e5  000000000000  0b03bbc9e1e7  
  d4a3ed9310e5  aee31534993a  000000000000  421535db10b6  
  aee31534993a  1406e7411862  000000000000  a89d614e2364  
  1406e7411862  000000000000  000000000000  b292c1e3311f  

# Test copy tracing from a pack
  $ cd ../master
  $ hg mv x y
  $ hg commit -m 'move x to y'
  $ cd ../shallow
  $ hg pull -q
  $ hg up -q tip
  1 files fetched over 1 fetches - (1 misses, 0.00% hit ratio) over * (glob)
  $ hg repack
  $ hg log -f y -T '{desc}\n'
  move x to y
  x4
  x3
  x2
  x

# Test copy trace across rename and back
  $ cp -R $TESTTMP/hgcache/master/packs $TESTTMP/backuppacks
  $ cd ../master
  $ hg mv y x
  $ hg commit -m 'move y back to x'
  $ hg revert -r 0 x
  $ mv x y
  $ hg add y
  $ echo >> y
  $ hg revert x
  $ hg commit -m 'add y back without metadata'
  $ cd ../shallow
  $ hg pull -q
  $ hg up -q tip
  2 files fetched over 2 fetches - (2 misses, 0.00% hit ratio) over * (glob)
  $ hg repack
  $ ls $TESTTMP/hgcache/master/packs
  bfd60adb76018bb952e27cd23fc151bf94865d7d.histidx
  bfd60adb76018bb952e27cd23fc151bf94865d7d.histpack
  fb3aa57b22789ebcc45706c352e2d6af099c5816.dataidx
  fb3aa57b22789ebcc45706c352e2d6af099c5816.datapack
  repacklock
  $ hg debughistorypack $TESTTMP/hgcache/master/packs/*.histidx
  
  x
  Node          P1 Node       P2 Node       Link Node     Copy From
  cd410a44d584  577959738234  000000000000  609547eda446  y
  1bb2e6237e03  d4a3ed9310e5  000000000000  0b03bbc9e1e7  
  d4a3ed9310e5  aee31534993a  000000000000  421535db10b6  
  aee31534993a  1406e7411862  000000000000  a89d614e2364  
  1406e7411862  000000000000  000000000000  b292c1e3311f  
  
  y
  Node          P1 Node       P2 Node       Link Node     Copy From
  577959738234  1bb2e6237e03  000000000000  c7faf2fc439a  x
  21f46f2721e7  000000000000  000000000000  d6868642b790  
  $ hg strip -r '.^'
  1 files updated, 0 files merged, 1 files removed, 0 files unresolved
  saved backup bundle to $TESTTMP/shallow/.hg/strip-backup/609547eda446-b26b56a8-backup.hg (glob)
  $ hg -R ../master strip -r '.^'
  1 files updated, 0 files merged, 1 files removed, 0 files unresolved
  saved backup bundle to $TESTTMP/master/.hg/strip-backup/609547eda446-b26b56a8-backup.hg (glob)

  $ rm -rf $TESTTMP/hgcache/master/packs
  $ cp -R $TESTTMP/backuppacks $TESTTMP/hgcache/master/packs

# Test repacking datapack without history
  $ rm -rf $CACHEDIR/master/packs/*hist*
  $ hg repack
  $ hg debugdatapack $TESTTMP/hgcache/master/packs/*.datapack
  $TESTTMP/hgcache/master/packs/922aca43dbbeda4d250565372e8892ec7b08da6a:
  x:
  Node          Delta Base    Delta Length  Blob Size
  1bb2e6237e03  000000000000  8             8
  d4a3ed9310e5  1bb2e6237e03  12            6
  aee31534993a  d4a3ed9310e5  12            4
  
  Total:                      32            18        (77.8% bigger)
  y:
  Node          Delta Base    Delta Length  Blob Size
  577959738234  000000000000  70            8
  
  Total:                      70            8         (775.0% bigger)

  $ hg cat -r ".^" x
  x
  x
  x
  x

Incremental repack
  $ rm -rf $CACHEDIR/master/packs/*
  $ cat >> .hg/hgrc <<EOF
  > [remotefilelog]
  > data.generations=60
  >   150
  > EOF

Single pack - repack does nothing
  $ hg prefetch -r 0
  1 files fetched over 1 fetches - (1 misses, 0.00% hit ratio) over * (glob)
  $ ls_l $TESTTMP/hgcache/master/packs/ | grep datapack
  [1]
  $ ls_l $TESTTMP/hgcache/master/packs/ | grep histpack
  [1]
  $ hg repack --incremental
  $ ls_l $TESTTMP/hgcache/master/packs/ | grep datapack
  -r--r--r--      70 052643fdcdebbd42d7c180a651a30d46098e6fe1.datapack
  $ ls_l $TESTTMP/hgcache/master/packs/ | grep histpack
  -r--r--r--      90 955a622173324b2d8b53e1147f209f1cf125302e.histpack

3 gen1 packs, 1 gen0 pack - packs 3 gen1 into 1
  $ hg prefetch -r 1
  1 files fetched over 1 fetches - (1 misses, 0.00% hit ratio) over * (glob)
  $ hg prefetch -r 2
  1 files fetched over 1 fetches - (1 misses, 0.00% hit ratio) over * (glob)
  $ hg prefetch -r 3
  1 files fetched over 1 fetches - (1 misses, 0.00% hit ratio) over * (glob)
  $ ls_l $TESTTMP/hgcache/master/packs/ | grep datapack
  -r--r--r--      70 052643fdcdebbd42d7c180a651a30d46098e6fe1.datapack
  $ ls_l $TESTTMP/hgcache/master/packs/ | grep histpack
  -r--r--r--      90 955a622173324b2d8b53e1147f209f1cf125302e.histpack
  $ hg repack --incremental
  $ ls_l $TESTTMP/hgcache/master/packs/ | grep datapack
  -r--r--r--      70 052643fdcdebbd42d7c180a651a30d46098e6fe1.datapack
  -r--r--r--     226 39443fa1064182e93d968b5cba292eb5283260d0.datapack
  $ ls_l $TESTTMP/hgcache/master/packs/ | grep histpack
  -r--r--r--     336 604552d403a1381749faf656feca0ca265a6d52c.histpack
  -r--r--r--      90 955a622173324b2d8b53e1147f209f1cf125302e.histpack

1 gen3 pack, 1 gen0 pack - does nothing
  $ hg repack --incremental
  $ ls_l $TESTTMP/hgcache/master/packs/ | grep datapack
  -r--r--r--      70 052643fdcdebbd42d7c180a651a30d46098e6fe1.datapack
  -r--r--r--     226 39443fa1064182e93d968b5cba292eb5283260d0.datapack
  $ ls_l $TESTTMP/hgcache/master/packs/ | grep histpack
  -r--r--r--     336 604552d403a1381749faf656feca0ca265a6d52c.histpack
  -r--r--r--      90 955a622173324b2d8b53e1147f209f1cf125302e.histpack

Pull should run background repack
  $ cat >> .hg/hgrc <<EOF
  > [remotefilelog]
  > backgroundrepack=True
  > EOF
  $ clearcache
  $ hg prefetch -r 0
  1 files fetched over 1 fetches - (1 misses, 0.00% hit ratio) over * (glob)
  $ hg prefetch -r 1
  1 files fetched over 1 fetches - (1 misses, 0.00% hit ratio) over * (glob)
  $ hg prefetch -r 2
  1 files fetched over 1 fetches - (1 misses, 0.00% hit ratio) over * (glob)
  $ hg prefetch -r 3
  1 files fetched over 1 fetches - (1 misses, 0.00% hit ratio) over * (glob)

  $ hg pull
  pulling from ssh://user@dummy/master
  searching for changes
  no changes found
  (running background incremental repack)
  $ sleep 0.5
  $ hg debugwaitonrepack >/dev/null 2>&1
  $ ls_l $TESTTMP/hgcache/master/packs/ | grep datapack
  -r--r--r--     303 156a6c1c83aeb69422d7936e0a46ba9bc06a71c0.datapack
  $ ls_l $TESTTMP/hgcache/master/packs/ | grep histpack
  -r--r--r--     336 604552d403a1381749faf656feca0ca265a6d52c.histpack

Test environment variable resolution
  $ CACHEPATH=$TESTTMP/envcache hg prefetch --config 'remotefilelog.cachepath=$CACHEPATH'
  1 files fetched over 1 fetches - (1 misses, 0.00% hit ratio) over * (glob)
  $ find $TESTTMP/envcache | sort
  $TESTTMP/envcache
  $TESTTMP/envcache/master
  $TESTTMP/envcache/master/95
  $TESTTMP/envcache/master/95/cb0bfd2977c761298d9624e4b4d4c72a39974a
  $TESTTMP/envcache/master/95/cb0bfd2977c761298d9624e4b4d4c72a39974a/577959738234a1eb241ed3ed4b22a575833f56e0
  $TESTTMP/envcache/repos

Test local remotefilelog blob is correct when based on a pack
  $ hg prefetch -r .
  1 files fetched over 1 fetches - (1 misses, 0.00% hit ratio) over * (glob)
  $ echo >> y
  $ hg commit -m y2
  $ hg debugremotefilelog .hg/store/data/95cb0bfd2977c761298d9624e4b4d4c72a39974a/b70860edba4f8242a1d52f2a94679dd23cb76808
  size: 9 bytes
  path: .hg/store/data/95cb0bfd2977c761298d9624e4b4d4c72a39974a/b70860edba4f8242a1d52f2a94679dd23cb76808 
  key: b70860edba4f 
  
          node =>           p1            p2      linknode     copyfrom
  b70860edba4f => 577959738234  000000000000  08d3fbc98c48  
  577959738234 => 1bb2e6237e03  000000000000  c7faf2fc439a  x
  1bb2e6237e03 => d4a3ed9310e5  000000000000  0b03bbc9e1e7  
  d4a3ed9310e5 => aee31534993a  000000000000  421535db10b6  
  aee31534993a => 1406e7411862  000000000000  a89d614e2364  
  1406e7411862 => 000000000000  000000000000  b292c1e3311f  
