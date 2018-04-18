  $ . "$TESTDIR/narrow-library.sh"

initialize nested directories to validate complex include/exclude patterns

  $ hg init master
  $ cd master
  $ cat >> .hg/hgrc <<EOF
  > [narrow]
  > serveellipses=True
  > EOF

  $ echo root > root
  $ hg add root
  $ hg commit -m 'add root'

  $ for d in dir1 dir2 dir1/dirA dir1/dirB dir2/dirA dir2/dirB
  > do
  >   mkdir -p $d
  >   echo $d/foo > $d/foo
  >   hg add $d/foo
  >   hg commit -m "add $d/foo"
  >   echo $d/bar > $d/bar
  >   hg add $d/bar
  >   hg commit -m "add $d/bar"
  > done
#if execbit
  $ chmod +x dir1/dirA/foo
  $ hg commit -m "make dir1/dirA/foo executable"
#else
  $ hg import --bypass - <<EOF
  > # HG changeset patch
  > make dir1/dirA/foo executable
  > 
  > diff --git a/dir1/dirA/foo b/dir1/dirA/foo
  > old mode 100644
  > new mode 100755
  > EOF
  applying patch from stdin
  $ hg update -qr tip
#endif
  $ hg log -G -T '{rev} {node|short} {files}\n'
  @  13 c87ca422d521 dir1/dirA/foo
  |
  o  12 951b8a83924e dir2/dirB/bar
  |
  o  11 01ae5a51b563 dir2/dirB/foo
  |
  o  10 5eababdf0ac5 dir2/dirA/bar
  |
  o  9 99d690663739 dir2/dirA/foo
  |
  o  8 8e80155d5445 dir1/dirB/bar
  |
  o  7 406760310428 dir1/dirB/foo
  |
  o  6 623466a5f475 dir1/dirA/bar
  |
  o  5 06ff3a5be997 dir1/dirA/foo
  |
  o  4 33227af02764 dir2/bar
  |
  o  3 5e1f9d8d7c69 dir2/foo
  |
  o  2 594bc4b13d4a dir1/bar
  |
  o  1 47f480a08324 dir1/foo
  |
  o  0 2a4f0c3b67da root
  
  $ cd ..

clone a narrow portion of the master, such that we can widen it later

  $ hg clone --narrow ssh://user@dummy/master narrow \
  > --include dir1 \
  > --include dir2 \
  > --exclude dir1/dirA \
  > --exclude dir1/dirB \
  > --exclude dir2/dirA \
  > --exclude dir2/dirB
  requesting all changes
  adding changesets
  adding manifests
  adding file changes
  added 6 changesets with 4 changes to 4 files
  new changesets *:* (glob)
  updating to branch default
  4 files updated, 0 files merged, 0 files removed, 0 files unresolved

  $ cd narrow
  $ cat .hg/narrowspec
  [includes]
  path:dir1
  path:dir2
  [excludes]
  path:dir1/dirA
  path:dir1/dirB
  path:dir2/dirA
  path:dir2/dirB
  $ hg manifest -r tip
  dir1/bar
  dir1/dirA/bar
  dir1/dirA/foo
  dir1/dirB/bar
  dir1/dirB/foo
  dir1/foo
  dir2/bar
  dir2/dirA/bar
  dir2/dirA/foo
  dir2/dirB/bar
  dir2/dirB/foo
  dir2/foo
  root
  $ find * | sort
  dir1
  dir1/bar
  dir1/foo
  dir2
  dir2/bar
  dir2/foo
  $ hg log -G -T '{rev} {node|short}{if(ellipsis, "...")} {files}\n'
  @  5 c87ca422d521... dir1/dirA/foo
  |
  o  4 33227af02764 dir2/bar
  |
  o  3 5e1f9d8d7c69 dir2/foo
  |
  o  2 594bc4b13d4a dir1/bar
  |
  o  1 47f480a08324 dir1/foo
  |
  o  0 2a4f0c3b67da... root
  

widen the narrow checkout

  $ hg tracked --removeexclude dir1/dirA
  comparing with ssh://user@dummy/master
  searching for changes
  no changes found
  saved backup bundle to $TESTTMP/narrow/.hg/strip-backup/*-widen.hg (glob)
  adding changesets
  adding manifests
  adding file changes
  added 9 changesets with 6 changes to 6 files
  new changesets *:* (glob)
  $ cat .hg/narrowspec
  [includes]
  path:dir1
  path:dir2
  [excludes]
  path:dir1/dirB
  path:dir2/dirA
  path:dir2/dirB
  $ find * | sort
  dir1
  dir1/bar
  dir1/dirA
  dir1/dirA/bar
  dir1/dirA/foo
  dir1/foo
  dir2
  dir2/bar
  dir2/foo

#if execbit
  $ test -x dir1/dirA/foo && echo executable
  executable
  $ test -x dir1/dirA/bar || echo not executable
  not executable
#endif

  $ hg log -G -T '{rev} {node|short}{if(ellipsis, "...")} {files}\n'
  @  8 c87ca422d521 dir1/dirA/foo
  |
  o  7 951b8a83924e... dir2/dirB/bar
  |
  o  6 623466a5f475 dir1/dirA/bar
  |
  o  5 06ff3a5be997 dir1/dirA/foo
  |
  o  4 33227af02764 dir2/bar
  |
  o  3 5e1f9d8d7c69 dir2/foo
  |
  o  2 594bc4b13d4a dir1/bar
  |
  o  1 47f480a08324 dir1/foo
  |
  o  0 2a4f0c3b67da... root
  

widen narrow spec again, but exclude a file in previously included spec

  $ hg tracked --removeexclude dir2/dirB --addexclude dir1/dirA/bar
  comparing with ssh://user@dummy/master
  searching for changes
  looking for local changes to affected paths
  deleting data/dir1/dirA/bar.i (reporevlogstore !)
  deleting data/dir1/dirA/bar/0eca1d0cbdaea4651d1d04d71976a6d2d9bfaae5 (reposimplestore !)
  deleting data/dir1/dirA/bar/index (reposimplestore !)
  no changes found
  saved backup bundle to $TESTTMP/narrow/.hg/strip-backup/*-widen.hg (glob)
  adding changesets
  adding manifests
  adding file changes
  added 11 changesets with 7 changes to 7 files
  new changesets *:* (glob)
  $ cat .hg/narrowspec
  [includes]
  path:dir1
  path:dir2
  [excludes]
  path:dir1/dirA/bar
  path:dir1/dirB
  path:dir2/dirA
  $ find * | sort
  dir1
  dir1/bar
  dir1/dirA
  dir1/dirA/foo
  dir1/foo
  dir2
  dir2/bar
  dir2/dirB
  dir2/dirB/bar
  dir2/dirB/foo
  dir2/foo
  $ hg log -G -T '{rev} {node|short}{if(ellipsis, "...")} {files}\n'
  @  10 c87ca422d521 dir1/dirA/foo
  |
  o  9 951b8a83924e dir2/dirB/bar
  |
  o  8 01ae5a51b563 dir2/dirB/foo
  |
  o  7 5eababdf0ac5... dir2/dirA/bar
  |
  o  6 623466a5f475... dir1/dirA/bar
  |
  o  5 06ff3a5be997 dir1/dirA/foo
  |
  o  4 33227af02764 dir2/bar
  |
  o  3 5e1f9d8d7c69 dir2/foo
  |
  o  2 594bc4b13d4a dir1/bar
  |
  o  1 47f480a08324 dir1/foo
  |
  o  0 2a4f0c3b67da... root
  

widen narrow spec yet again, excluding a directory in previous spec

  $ hg tracked --removeexclude dir2/dirA --addexclude dir1/dirA
  comparing with ssh://user@dummy/master
  searching for changes
  looking for local changes to affected paths
  deleting data/dir1/dirA/foo.i (reporevlogstore !)
  deleting data/dir1/dirA/foo/162caeb3d55dceb1fee793aa631ac8c73fcb8b5e (reposimplestore !)
  deleting data/dir1/dirA/foo/index (reposimplestore !)
  no changes found
  saved backup bundle to $TESTTMP/narrow/.hg/strip-backup/*-widen.hg (glob)
  adding changesets
  adding manifests
  adding file changes
  added 13 changesets with 8 changes to 8 files
  new changesets *:* (glob)
  $ cat .hg/narrowspec
  [includes]
  path:dir1
  path:dir2
  [excludes]
  path:dir1/dirA
  path:dir1/dirA/bar
  path:dir1/dirB
  $ find * | sort
  dir1
  dir1/bar
  dir1/foo
  dir2
  dir2/bar
  dir2/dirA
  dir2/dirA/bar
  dir2/dirA/foo
  dir2/dirB
  dir2/dirB/bar
  dir2/dirB/foo
  dir2/foo
  $ hg log -G -T '{rev} {node|short}{if(ellipsis, "...")} {files}\n'
  @  12 c87ca422d521... dir1/dirA/foo
  |
  o  11 951b8a83924e dir2/dirB/bar
  |
  o  10 01ae5a51b563 dir2/dirB/foo
  |
  o  9 5eababdf0ac5 dir2/dirA/bar
  |
  o  8 99d690663739 dir2/dirA/foo
  |
  o  7 8e80155d5445... dir1/dirB/bar
  |
  o  6 623466a5f475... dir1/dirA/bar
  |
  o  5 06ff3a5be997... dir1/dirA/foo
  |
  o  4 33227af02764 dir2/bar
  |
  o  3 5e1f9d8d7c69 dir2/foo
  |
  o  2 594bc4b13d4a dir1/bar
  |
  o  1 47f480a08324 dir1/foo
  |
  o  0 2a4f0c3b67da... root
  

include a directory that was previously explicitly excluded

  $ hg tracked --removeexclude dir1/dirA
  comparing with ssh://user@dummy/master
  searching for changes
  no changes found
  saved backup bundle to $TESTTMP/narrow/.hg/strip-backup/*-widen.hg (glob)
  adding changesets
  adding manifests
  adding file changes
  added 13 changesets with 9 changes to 9 files
  new changesets *:* (glob)
  $ cat .hg/narrowspec
  [includes]
  path:dir1
  path:dir2
  [excludes]
  path:dir1/dirA/bar
  path:dir1/dirB
  $ find * | sort
  dir1
  dir1/bar
  dir1/dirA
  dir1/dirA/foo
  dir1/foo
  dir2
  dir2/bar
  dir2/dirA
  dir2/dirA/bar
  dir2/dirA/foo
  dir2/dirB
  dir2/dirB/bar
  dir2/dirB/foo
  dir2/foo
  $ hg log -G -T '{rev} {node|short}{if(ellipsis, "...")} {files}\n'
  @  12 c87ca422d521 dir1/dirA/foo
  |
  o  11 951b8a83924e dir2/dirB/bar
  |
  o  10 01ae5a51b563 dir2/dirB/foo
  |
  o  9 5eababdf0ac5 dir2/dirA/bar
  |
  o  8 99d690663739 dir2/dirA/foo
  |
  o  7 8e80155d5445... dir1/dirB/bar
  |
  o  6 623466a5f475... dir1/dirA/bar
  |
  o  5 06ff3a5be997 dir1/dirA/foo
  |
  o  4 33227af02764 dir2/bar
  |
  o  3 5e1f9d8d7c69 dir2/foo
  |
  o  2 594bc4b13d4a dir1/bar
  |
  o  1 47f480a08324 dir1/foo
  |
  o  0 2a4f0c3b67da... root
  

  $ cd ..

clone a narrow portion of the master, such that we can widen it later

  $ hg clone --narrow ssh://user@dummy/master narrow2 --include dir1/dirA
  requesting all changes
  adding changesets
  adding manifests
  adding file changes
  added 5 changesets with 2 changes to 2 files
  new changesets *:* (glob)
  updating to branch default
  2 files updated, 0 files merged, 0 files removed, 0 files unresolved
  $ cd narrow2
  $ find * | sort
  dir1
  dir1/dirA
  dir1/dirA/bar
  dir1/dirA/foo
  $ hg tracked --addinclude dir1
  comparing with ssh://user@dummy/master
  searching for changes
  no changes found
  saved backup bundle to $TESTTMP/narrow2/.hg/strip-backup/*-widen.hg (glob)
  adding changesets
  adding manifests
  adding file changes
  added 10 changesets with 6 changes to 6 files
  new changesets *:* (glob)
  $ find * | sort
  dir1
  dir1/bar
  dir1/dirA
  dir1/dirA/bar
  dir1/dirA/foo
  dir1/dirB
  dir1/dirB/bar
  dir1/dirB/foo
  dir1/foo
  $ hg log -G -T '{rev} {node|short}{if(ellipsis, "...")} {files}\n'
  @  9 c87ca422d521 dir1/dirA/foo
  |
  o  8 951b8a83924e... dir2/dirB/bar
  |
  o  7 8e80155d5445 dir1/dirB/bar
  |
  o  6 406760310428 dir1/dirB/foo
  |
  o  5 623466a5f475 dir1/dirA/bar
  |
  o  4 06ff3a5be997 dir1/dirA/foo
  |
  o  3 33227af02764... dir2/bar
  |
  o  2 594bc4b13d4a dir1/bar
  |
  o  1 47f480a08324 dir1/foo
  |
  o  0 2a4f0c3b67da... root
  
