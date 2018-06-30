#require symlink execbit
  $ cat << EOF >> $HGRCPATH
  > [extensions]
  > amend=
  > rebase=
  > debugdrawdag=$TESTDIR/drawdag.py
  > strip=
  > [rebase]
  > experimental.inmemory=1
  > [diff]
  > git=1
  > [alias]
  > tglog = log -G --template "{rev}: {node|short} '{desc}'\n"
  > EOF

Rebase a simple DAG:
  $ hg init repo1
  $ cd repo1
  $ hg debugdrawdag <<'EOS'
  > c b
  > |/
  > d
  > |
  > a
  > EOS
  $ hg up -C a
  1 files updated, 0 files merged, 0 files removed, 0 files unresolved
  $ hg tglog
  o  3: 814f6bd05178 'c'
  |
  | o  2: db0e82a16a62 'b'
  |/
  o  1: 02952614a83d 'd'
  |
  @  0: b173517d0057 'a'
  
  $ hg cat -r 3 c
  c (no-eol)
  $ hg cat -r 2 b
  b (no-eol)
  $ hg rebase --debug -r b -d c | grep rebasing
  rebasing in-memory
  rebasing 2:db0e82a16a62 "b" (b)
  $ hg tglog
  o  3: ca58782ad1e4 'b'
  |
  o  2: 814f6bd05178 'c'
  |
  o  1: 02952614a83d 'd'
  |
  @  0: b173517d0057 'a'
  
  $ hg cat -r 3 b
  b (no-eol)
  $ hg cat -r 2 c
  c (no-eol)

Case 2:
  $ hg init repo2
  $ cd repo2
  $ hg debugdrawdag <<'EOS'
  > c b
  > |/
  > d
  > |
  > a
  > EOS

Add a symlink and executable file:
  $ hg up -C c
  3 files updated, 0 files merged, 0 files removed, 0 files unresolved
  $ ln -s somefile e
  $ echo f > f
  $ chmod +x f
  $ hg add e f
  $ hg amend -q
  $ hg up -Cq a

Write files to the working copy, and ensure they're still there after the rebase
  $ echo "abc" > a
  $ ln -s def b
  $ echo "ghi" > c
  $ echo "jkl" > d
  $ echo "mno" > e
  $ hg tglog
  o  3: f56b71190a8f 'c'
  |
  | o  2: db0e82a16a62 'b'
  |/
  o  1: 02952614a83d 'd'
  |
  @  0: b173517d0057 'a'
  
  $ hg cat -r 3 c
  c (no-eol)
  $ hg cat -r 2 b
  b (no-eol)
  $ hg cat -r 3 e
  somefile (no-eol)
  $ hg rebase --debug -s b -d a | grep rebasing
  rebasing in-memory
  rebasing 2:db0e82a16a62 "b" (b)
  $ hg tglog
  o  3: fc055c3b4d33 'b'
  |
  | o  2: f56b71190a8f 'c'
  | |
  | o  1: 02952614a83d 'd'
  |/
  @  0: b173517d0057 'a'
  
  $ hg cat -r 2 c
  c (no-eol)
  $ hg cat -r 3 b
  b (no-eol)
  $ hg rebase --debug -s 1 -d 3 | grep rebasing
  rebasing in-memory
  rebasing 1:02952614a83d "d" (d)
  rebasing 2:f56b71190a8f "c"
  $ hg tglog
  o  3: 753feb6fd12a 'c'
  |
  o  2: 09c044d2cb43 'd'
  |
  o  1: fc055c3b4d33 'b'
  |
  @  0: b173517d0057 'a'
  
Ensure working copy files are still there:
  $ cat a
  abc
  $ readlink.py b
  b -> def
  $ cat e
  mno

Ensure symlink and executable files were rebased properly:
  $ hg up -Cq 3
  $ readlink.py e
  e -> somefile
  $ ls -l f | cut -c -10
  -rwxr-xr-x

Rebase the working copy parent
  $ hg up -C 3
  0 files updated, 0 files merged, 0 files removed, 0 files unresolved
  $ hg rebase -r 3 -d 0 --debug | grep rebasing
  rebasing in-memory
  rebasing 3:753feb6fd12a "c" (tip)
  $ hg tglog
  @  3: 844a7de3e617 'c'
  |
  | o  2: 09c044d2cb43 'd'
  | |
  | o  1: fc055c3b4d33 'b'
  |/
  o  0: b173517d0057 'a'
  
Test dry-run rebasing
  $ hg init repo3
  $ cd repo3
  $ echo a>a
  $ hg ci -Aqma
  $ echo b>b
  $ hg ci -Aqmb
  $ echo c>c
  $ hg ci -Aqmc
  $ echo d>d
  $ hg ci -Aqmd
  $ echo e>e
  $ hg ci -Aqme

  $ hg up 1 -q
  $ echo f>f
  $ hg ci -Amf
  adding f
  created new head
  $ echo g>g
  $ hg ci -Aqmg
  $ hg log -G --template "{rev}:{short(node)} {person(author)}\n{firstline(desc)} {topic}\n\n"
  @  6:baf10c5166d4 test
  |  g
  |
  o  5:6343ca3eff20 test
  |  f
  |
  | o  4:e860deea161a test
  | |  e
  | |
  | o  3:055a42cdd887 test
  | |  d
  | |
  | o  2:177f92b77385 test
  |/   c
  |
  o  1:d2ae7f538514 test
  |  b
  |
  o  0:cb9a9f314b8b test
     a
  
Make sure it throws error while passing --continue or --abort with --dry-run
  $ hg rebase -s 2 -d 6 -n --continue
  abort: cannot specify both --dry-run and --continue
  [255]
  $ hg rebase -s 2 -d 6 -n --abort
  abort: cannot specify both --dry-run and --abort
  [255]

Check dryrun gives correct results when there is no conflict in rebasing
  $ hg rebase -s 2 -d 6 -n
  starting dry-run rebase; repository will not be changed
  rebasing 2:177f92b77385 "c"
  rebasing 3:055a42cdd887 "d"
  rebasing 4:e860deea161a "e"
  dry-run rebase completed successfully; run without -n/--dry-run to perform this rebase

  $ hg diff
  $ hg status

  $ hg log -G --template "{rev}:{short(node)} {person(author)}\n{firstline(desc)} {topic}\n\n"
  @  6:baf10c5166d4 test
  |  g
  |
  o  5:6343ca3eff20 test
  |  f
  |
  | o  4:e860deea161a test
  | |  e
  | |
  | o  3:055a42cdd887 test
  | |  d
  | |
  | o  2:177f92b77385 test
  |/   c
  |
  o  1:d2ae7f538514 test
  |  b
  |
  o  0:cb9a9f314b8b test
     a
  
Check dryrun working with --collapse when there is no conflict
  $ hg rebase -s 2 -d 6 -n --collapse
  starting dry-run rebase; repository will not be changed
  rebasing 2:177f92b77385 "c"
  rebasing 3:055a42cdd887 "d"
  rebasing 4:e860deea161a "e"
  dry-run rebase completed successfully; run without -n/--dry-run to perform this rebase

Check dryrun gives correct results when there is conflict in rebasing
Make a conflict:
  $ hg up 6 -q
  $ echo conflict>e
  $ hg ci -Aqm "conflict with e"
  $ hg log -G --template "{rev}:{short(node)} {person(author)}\n{firstline(desc)} {topic}\n\n"
  @  7:d2c195b28050 test
  |  conflict with e
  |
  o  6:baf10c5166d4 test
  |  g
  |
  o  5:6343ca3eff20 test
  |  f
  |
  | o  4:e860deea161a test
  | |  e
  | |
  | o  3:055a42cdd887 test
  | |  d
  | |
  | o  2:177f92b77385 test
  |/   c
  |
  o  1:d2ae7f538514 test
  |  b
  |
  o  0:cb9a9f314b8b test
     a
  
  $ hg rebase -s 2 -d 7 -n
  starting dry-run rebase; repository will not be changed
  rebasing 2:177f92b77385 "c"
  rebasing 3:055a42cdd887 "d"
  rebasing 4:e860deea161a "e"
  merging e
  transaction abort!
  rollback completed
  hit a merge conflict
  [1]
  $ hg diff
  $ hg status
  $ hg log -G --template "{rev}:{short(node)} {person(author)}\n{firstline(desc)} {topic}\n\n"
  @  7:d2c195b28050 test
  |  conflict with e
  |
  o  6:baf10c5166d4 test
  |  g
  |
  o  5:6343ca3eff20 test
  |  f
  |
  | o  4:e860deea161a test
  | |  e
  | |
  | o  3:055a42cdd887 test
  | |  d
  | |
  | o  2:177f92b77385 test
  |/   c
  |
  o  1:d2ae7f538514 test
  |  b
  |
  o  0:cb9a9f314b8b test
     a
  
Check dryrun working with --collapse when there is conflicts
  $ hg rebase -s 2 -d 7 -n --collapse
  starting dry-run rebase; repository will not be changed
  rebasing 2:177f92b77385 "c"
  rebasing 3:055a42cdd887 "d"
  rebasing 4:e860deea161a "e"
  merging e
  hit a merge conflict
  [1]

==========================
Test for --confirm option|
==========================
  $ cd ..
  $ hg clone repo3 repo4 -q
  $ cd repo4
  $ hg strip 7 -q
  $ hg log -G --template "{rev}:{short(node)} {person(author)}\n{firstline(desc)} {topic}\n\n"
  @  6:baf10c5166d4 test
  |  g
  |
  o  5:6343ca3eff20 test
  |  f
  |
  | o  4:e860deea161a test
  | |  e
  | |
  | o  3:055a42cdd887 test
  | |  d
  | |
  | o  2:177f92b77385 test
  |/   c
  |
  o  1:d2ae7f538514 test
  |  b
  |
  o  0:cb9a9f314b8b test
     a
  
Check it gives error when both --dryrun and --confirm is used:
  $ hg rebase -s 2 -d . --confirm --dry-run
  abort: cannot specify both --confirm and --dry-run
  [255]
  $ hg rebase -s 2 -d . --confirm --abort
  abort: cannot specify both --confirm and --abort
  [255]
  $ hg rebase -s 2 -d . --confirm --continue
  abort: cannot specify both --confirm and --continue
  [255]

Test --confirm option when there are no conflicts:
  $ hg rebase -s 2 -d . --keep --config ui.interactive=True --confirm << EOF
  > n
  > EOF
  starting rebase...
  rebasing 2:177f92b77385 "c"
  rebasing 3:055a42cdd887 "d"
  rebasing 4:e860deea161a "e"
  rebase completed successfully
  apply changes (yn)? n
  $ hg log -G --template "{rev}:{short(node)} {person(author)}\n{firstline(desc)} {topic}\n\n"
  @  6:baf10c5166d4 test
  |  g
  |
  o  5:6343ca3eff20 test
  |  f
  |
  | o  4:e860deea161a test
  | |  e
  | |
  | o  3:055a42cdd887 test
  | |  d
  | |
  | o  2:177f92b77385 test
  |/   c
  |
  o  1:d2ae7f538514 test
  |  b
  |
  o  0:cb9a9f314b8b test
     a
  
  $ hg rebase -s 2 -d . --keep --config ui.interactive=True --confirm << EOF
  > y
  > EOF
  starting rebase...
  rebasing 2:177f92b77385 "c"
  rebasing 3:055a42cdd887 "d"
  rebasing 4:e860deea161a "e"
  rebase completed successfully
  apply changes (yn)? y
  $ hg log -G --template "{rev}:{short(node)} {person(author)}\n{firstline(desc)} {topic}\n\n"
  o  9:9fd28f55f6dc test
  |  e
  |
  o  8:12cbf031f469 test
  |  d
  |
  o  7:c83b1da5b1ae test
  |  c
  |
  @  6:baf10c5166d4 test
  |  g
  |
  o  5:6343ca3eff20 test
  |  f
  |
  | o  4:e860deea161a test
  | |  e
  | |
  | o  3:055a42cdd887 test
  | |  d
  | |
  | o  2:177f92b77385 test
  |/   c
  |
  o  1:d2ae7f538514 test
  |  b
  |
  o  0:cb9a9f314b8b test
     a
  
Test --confirm option when there is a conflict
  $ hg up tip -q
  $ echo ee>e
  $ hg ci --amend -m "conflict with e" -q
  $ hg log -G --template "{rev}:{short(node)} {person(author)}\n{firstline(desc)} {topic}\n\n"
  @  9:906d72f66a59 test
  |  conflict with e
  |
  o  8:12cbf031f469 test
  |  d
  |
  o  7:c83b1da5b1ae test
  |  c
  |
  o  6:baf10c5166d4 test
  |  g
  |
  o  5:6343ca3eff20 test
  |  f
  |
  | o  4:e860deea161a test
  | |  e
  | |
  | o  3:055a42cdd887 test
  | |  d
  | |
  | o  2:177f92b77385 test
  |/   c
  |
  o  1:d2ae7f538514 test
  |  b
  |
  o  0:cb9a9f314b8b test
     a
  
  $ hg rebase -s 4 -d . --keep --config ui.interactive=True --confirm << EOF
  > n
  > EOF
  starting rebase...
  rebasing 4:e860deea161a "e"
  merging e
  hit a merge conflict
  apply changes (yn)? n
  [1]
  $ hg log -G --template "{rev}:{short(node)} {person(author)}\n{firstline(desc)} {topic}\n\n"
  @  9:906d72f66a59 test
  |  conflict with e
  |
  o  8:12cbf031f469 test
  |  d
  |
  o  7:c83b1da5b1ae test
  |  c
  |
  o  6:baf10c5166d4 test
  |  g
  |
  o  5:6343ca3eff20 test
  |  f
  |
  | o  4:e860deea161a test
  | |  e
  | |
  | o  3:055a42cdd887 test
  | |  d
  | |
  | o  2:177f92b77385 test
  |/   c
  |
  o  1:d2ae7f538514 test
  |  b
  |
  o  0:cb9a9f314b8b test
     a
  

  $ hg rebase -s 4 -d . --keep --config ui.interactive=True --confirm << EOF
  > y
  > EOF
  starting rebase...
  rebasing 4:e860deea161a "e"
  merging e
  hit a merge conflict
  apply changes (yn)? y
  rebasing 4:e860deea161a "e"
  merging e
  warning: conflicts while merging e! (edit, then use 'hg resolve --mark')
  unresolved conflicts (see hg resolve, then hg rebase --continue)
  [1]

  $ echo e>e
  $ hg resolve --mark --all
  (no more unresolved files)
  continue: hg rebase --continue
  $ hg rebase --continue
  rebasing 4:e860deea161a "e"
  $ hg log -G --template "{rev}:{short(node)} {person(author)}\n{firstline(desc)} {topic}\n\n"
  o  10:9fa3731dd6df test
  |  e
  |
  @  9:906d72f66a59 test
  |  conflict with e
  |
  o  8:12cbf031f469 test
  |  d
  |
  o  7:c83b1da5b1ae test
  |  c
  |
  o  6:baf10c5166d4 test
  |  g
  |
  o  5:6343ca3eff20 test
  |  f
  |
  | o  4:e860deea161a test
  | |  e
  | |
  | o  3:055a42cdd887 test
  | |  d
  | |
  | o  2:177f92b77385 test
  |/   c
  |
  o  1:d2ae7f538514 test
  |  b
  |
  o  0:cb9a9f314b8b test
     a
  
