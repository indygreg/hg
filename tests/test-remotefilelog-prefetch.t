#require no-windows

  $ . "$TESTDIR/remotefilelog-library.sh"

  $ hg init master
  $ cd master
  $ cat >> .hg/hgrc <<EOF
  > [remotefilelog]
  > server=True
  > EOF
  $ echo x > x
  $ echo z > z
  $ hg commit -qAm x
  $ echo x2 > x
  $ echo y > y
  $ hg commit -qAm y
  $ hg bookmark foo

  $ cd ..

# prefetch a revision

  $ hgcloneshallow ssh://user@dummy/master shallow --noupdate
  streaming all changes
  2 files to transfer, 528 bytes of data
  transferred 528 bytes in * seconds (*/sec) (glob)
  searching for changes
  no changes found
  $ cd shallow

  $ hg prefetch -r 0
  2 files fetched over 1 fetches - (2 misses, 0.00% hit ratio) over *s (glob)

  $ hg cat -r 0 x
  x

# prefetch with base

  $ clearcache
  $ hg prefetch -r 0::1 -b 0
  2 files fetched over 1 fetches - (2 misses, 0.00% hit ratio) over *s (glob)

  $ hg cat -r 1 x
  x2
  $ hg cat -r 1 y
  y

  $ hg cat -r 0 x
  x
  1 files fetched over 1 fetches - (1 misses, 0.00% hit ratio) over *s (glob)

  $ hg cat -r 0 z
  z
  1 files fetched over 1 fetches - (1 misses, 0.00% hit ratio) over *s (glob)

  $ hg prefetch -r 0::1 --base 0
  $ hg prefetch -r 0::1 -b 1
  $ hg prefetch -r 0::1

# prefetch a range of revisions

  $ clearcache
  $ hg prefetch -r 0::1
  4 files fetched over 1 fetches - (4 misses, 0.00% hit ratio) over *s (glob)

  $ hg cat -r 0 x
  x
  $ hg cat -r 1 x
  x2

# prefetch certain files

  $ clearcache
  $ hg prefetch -r 1 x
  1 files fetched over 1 fetches - (1 misses, 0.00% hit ratio) over *s (glob)

  $ hg cat -r 1 x
  x2

  $ hg cat -r 1 y
  y
  1 files fetched over 1 fetches - (1 misses, 0.00% hit ratio) over *s (glob)

# prefetch on pull when configured

  $ printf "[remotefilelog]\npullprefetch=bookmark()\n" >> .hg/hgrc
  $ hg strip tip
  saved backup bundle to $TESTTMP/shallow/.hg/strip-backup/109c3a557a73-3f43405e-backup.hg (glob)

  $ clearcache
  $ hg pull
  pulling from ssh://user@dummy/master
  searching for changes
  adding changesets
  adding manifests
  adding file changes
  added 1 changesets with 0 changes to 0 files
  updating bookmark foo
  new changesets 109c3a557a73
  (run 'hg update' to get a working copy)
  prefetching file contents
  3 files fetched over 1 fetches - (3 misses, 0.00% hit ratio) over *s (glob)

  $ hg up tip
  3 files updated, 0 files merged, 0 files removed, 0 files unresolved

# prefetch only fetches changes not in working copy

  $ hg strip tip
  1 files updated, 0 files merged, 1 files removed, 0 files unresolved
  saved backup bundle to $TESTTMP/shallow/.hg/strip-backup/109c3a557a73-3f43405e-backup.hg (glob)
  1 files fetched over 1 fetches - (1 misses, 0.00% hit ratio) over *s (glob)
  $ clearcache

  $ hg pull
  pulling from ssh://user@dummy/master
  searching for changes
  adding changesets
  adding manifests
  adding file changes
  added 1 changesets with 0 changes to 0 files
  updating bookmark foo
  new changesets 109c3a557a73
  (run 'hg update' to get a working copy)
  prefetching file contents
  2 files fetched over 1 fetches - (2 misses, 0.00% hit ratio) over *s (glob)

# Make some local commits that produce the same file versions as are on the
# server. To simulate a situation where we have local commits that were somehow
# pushed, and we will soon pull.

  $ hg prefetch -r 'all()'
  2 files fetched over 1 fetches - (2 misses, 0.00% hit ratio) over *s (glob)
  $ hg strip -q -r 0
  $ echo x > x
  $ echo z > z
  $ hg commit -qAm x
  $ echo x2 > x
  $ echo y > y
  $ hg commit -qAm y

# prefetch server versions, even if local versions are available

  $ clearcache
  $ hg strip -q tip
  $ hg pull
  pulling from ssh://user@dummy/master
  searching for changes
  adding changesets
  adding manifests
  adding file changes
  added 1 changesets with 0 changes to 0 files
  updating bookmark foo
  new changesets 109c3a557a73
  1 local changesets published (?)
  (run 'hg update' to get a working copy)
  prefetching file contents
  2 files fetched over 1 fetches - (2 misses, 0.00% hit ratio) over *s (glob)

  $ cd ..

# Prefetch unknown files during checkout

  $ hgcloneshallow ssh://user@dummy/master shallow2
  streaming all changes
  2 files to transfer, 528 bytes of data
  transferred 528 bytes in * seconds * (glob)
  searching for changes
  no changes found
  updating to branch default
  3 files updated, 0 files merged, 0 files removed, 0 files unresolved
  1 files fetched over 1 fetches - (1 misses, 0.00% hit ratio) over * (glob)
  $ cd shallow2
  $ hg up -q null
  $ echo x > x
  $ echo y > y
  $ echo z > z
  $ clearcache
  $ hg up tip
  x: untracked file differs
  3 files fetched over 1 fetches - (3 misses, 0.00% hit ratio) over * (glob)
  abort: untracked files in working directory differ from files in requested revision
  [255]
  $ hg revert --all

# Test batch fetching of lookup files during hg status
  $ hg up --clean tip
  3 files updated, 0 files merged, 0 files removed, 0 files unresolved
  $ hg debugrebuilddirstate
  $ clearcache
  $ hg status
  3 files fetched over 1 fetches - (3 misses, 0.00% hit ratio) over * (glob)

# Prefetch during addrename detection
  $ hg up -q --clean tip
  $ hg revert --all
  $ mv x x2
  $ mv y y2
  $ mv z z2
  $ clearcache
  $ hg addremove -s 50 > /dev/null
  3 files fetched over 1 fetches - (3 misses, 0.00% hit ratio) over * (glob)
  $ hg revert --all
  forgetting x2
  forgetting y2
  forgetting z2
  undeleting x
  undeleting y
  undeleting z


# Revert across double renames. Note: the scary "abort", error is because
# https://bz.mercurial-scm.org/5419 .

  $ cd ../master
  $ hg mv z z2
  $ hg commit -m 'move z -> z2'
  $ cd ../shallow2
  $ hg pull -q
  $ clearcache
  $ hg mv y y2
  y2: not overwriting - file exists
  ('hg rename --after' to record the rename)
  [1]
  $ hg mv x x2
  x2: not overwriting - file exists
  ('hg rename --after' to record the rename)
  [1]
  $ hg mv z2 z3
  z2: not copying - file is not managed
  abort: no files to copy
  [255]
  $ hg revert -a -r 1 || true
  3 files fetched over 1 fetches - (3 misses, 0.00% hit ratio) over * (glob)
  abort: z2@109c3a557a73: not found in manifest! (?)
