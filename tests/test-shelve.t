#testcases stripbased phasebased

  $ cat <<EOF >> $HGRCPATH
  > [extensions]
  > mq =
  > shelve =
  > [defaults]
  > diff = --nodates --git
  > qnew = --date '0 0'
  > [shelve]
  > maxbackups = 2
  > EOF

#if phasebased

  $ cat <<EOF >> $HGRCPATH
  > [format]
  > internal-phase = yes
  > EOF

#endif

  $ hg init repo
  $ cd repo
  $ mkdir a b
  $ echo a > a/a
  $ echo b > b/b
  $ echo c > c
  $ echo d > d
  $ echo x > x
  $ hg addremove -q

shelve has a help message
  $ hg shelve -h
  hg shelve [OPTION]... [FILE]...
  
  save and set aside changes from the working directory
  
      Shelving takes files that "hg status" reports as not clean, saves the
      modifications to a bundle (a shelved change), and reverts the files so
      that their state in the working directory becomes clean.
  
      To restore these changes to the working directory, using "hg unshelve";
      this will work even if you switch to a different commit.
  
      When no files are specified, "hg shelve" saves all not-clean files. If
      specific files or directories are named, only changes to those files are
      shelved.
  
      In bare shelve (when no files are specified, without interactive, include
      and exclude option), shelving remembers information if the working
      directory was on newly created branch, in other words working directory
      was on different branch than its first parent. In this situation
      unshelving restores branch information to the working directory.
  
      Each shelved change has a name that makes it easier to find later. The
      name of a shelved change defaults to being based on the active bookmark,
      or if there is no active bookmark, the current named branch.  To specify a
      different name, use "--name".
  
      To see a list of existing shelved changes, use the "--list" option. For
      each shelved change, this will print its name, age, and description; use "
      --patch" or "--stat" for more details.
  
      To delete specific shelved changes, use "--delete". To delete all shelved
      changes, use "--cleanup".
  
  (use 'hg help -e shelve' to show help for the shelve extension)
  
  options ([+] can be repeated):
  
   -A --addremove           mark new/missing files as added/removed before
                            shelving
   -u --unknown             store unknown files in the shelve
      --cleanup             delete all shelved changes
      --date DATE           shelve with the specified commit date
   -d --delete              delete the named shelved change(s)
   -e --edit                invoke editor on commit messages
   -l --list                list current shelves
   -m --message TEXT        use text as shelve message
   -n --name NAME           use the given name for the shelved commit
   -p --patch               output patches for changes (provide the names of the
                            shelved changes as positional arguments)
   -i --interactive         interactive mode, only works while creating a shelve
      --stat                output diffstat-style summary of changes (provide
                            the names of the shelved changes as positional
                            arguments)
   -I --include PATTERN [+] include names matching the given patterns
   -X --exclude PATTERN [+] exclude names matching the given patterns
      --mq                  operate on patch repository
  
  (some details hidden, use --verbose to show complete help)

shelving in an empty repo should be possible
(this tests also that editor is not invoked, if '--edit' is not
specified)

  $ HGEDITOR=cat hg shelve
  shelved as default
  0 files updated, 0 files merged, 5 files removed, 0 files unresolved

  $ hg unshelve
  unshelving change 'default'

  $ hg commit -q -m 'initial commit'

  $ hg shelve
  nothing changed
  [1]

make sure shelve files were backed up

  $ ls .hg/shelve-backup
  default.hg
  default.patch
  default.shelve

checks to make sure we dont create a directory or
hidden file while choosing a new shelve name

when we are given a name

  $ hg shelve -n foo/bar
  abort: shelved change names can not contain slashes
  [255]
  $ hg shelve -n .baz
  abort: shelved change names can not start with '.'
  [255]
  $ hg shelve -n foo\\bar
  abort: shelved change names can not contain slashes
  [255]

when shelve has to choose itself

  $ hg branch x/y -q
  $ hg commit -q -m "Branch commit 0"
  $ hg shelve
  nothing changed
  [1]
  $ hg branch .x -q
  $ hg commit -q -m "Branch commit 1"
  $ hg shelve
  nothing changed
  [1]
  $ hg branch x\\y -q
  $ hg commit -q -m "Branch commit 2"
  $ hg shelve
  nothing changed
  [1]

cleaning the branches made for name checking tests

  $ hg up default -q
  $ hg strip e9177275307e+6a6d231f43d+882bae7c62c2 -q

create an mq patch - shelving should work fine with a patch applied

  $ echo n > n
  $ hg add n
  $ hg commit n -m second
  $ hg qnew second.patch

shelve a change that we will delete later

  $ echo a >> a/a
  $ hg shelve
  shelved as default
  1 files updated, 0 files merged, 0 files removed, 0 files unresolved

set up some more complex changes to shelve

  $ echo a >> a/a
  $ hg mv b b.rename
  moving b/b to b.rename/b
  $ hg cp c c.copy
  $ hg status -C
  M a/a
  A b.rename/b
    b/b
  A c.copy
    c
  R b/b

the common case - no options or filenames

  $ hg shelve
  shelved as default-01
  2 files updated, 0 files merged, 2 files removed, 0 files unresolved
  $ hg status -C

ensure that our shelved changes exist

  $ hg shelve -l
  default-01      (*)* changes to: [mq]: second.patch (glob)
  default         (*)* changes to: [mq]: second.patch (glob)

  $ hg shelve -l -p default
  default         (*)* changes to: [mq]: second.patch (glob)
  
  diff --git a/a/a b/a/a
  --- a/a/a
  +++ b/a/a
  @@ -1,1 +1,2 @@
   a
  +a

  $ hg shelve --list --addremove
  abort: options '--list' and '--addremove' may not be used together
  [255]

delete our older shelved change

  $ hg shelve -d default
  $ hg qfinish -a -q

ensure shelve backups aren't overwritten

  $ ls .hg/shelve-backup/
  default-1.hg
  default-1.patch
  default-1.shelve
  default.hg
  default.patch
  default.shelve

local edits should not prevent a shelved change from applying

  $ printf "z\na\n" > a/a
  $ hg unshelve --keep
  unshelving change 'default-01'
  temporarily committing pending changes (restore with 'hg unshelve --abort')
  rebasing shelved changes
  merging a/a

  $ hg revert --all -q
  $ rm a/a.orig b.rename/b c.copy

apply it and make sure our state is as expected

(this also tests that same timestamp prevents backups from being
removed, even though there are more than 'maxbackups' backups)

  $ f -t .hg/shelve-backup/default.patch
  .hg/shelve-backup/default.patch: file
  $ touch -t 200001010000 .hg/shelve-backup/default.patch
  $ f -t .hg/shelve-backup/default-1.patch
  .hg/shelve-backup/default-1.patch: file
  $ touch -t 200001010000 .hg/shelve-backup/default-1.patch

  $ hg unshelve
  unshelving change 'default-01'
  $ hg status -C
  M a/a
  A b.rename/b
    b/b
  A c.copy
    c
  R b/b
  $ hg shelve -l

(both of default.hg and default-1.hg should be still kept, because it
is difficult to decide actual order of them from same timestamp)

  $ ls .hg/shelve-backup/
  default-01.hg
  default-01.patch
  default-01.shelve
  default-1.hg
  default-1.patch
  default-1.shelve
  default.hg
  default.patch
  default.shelve

  $ hg unshelve
  abort: no shelved changes to apply!
  [255]
  $ hg unshelve foo
  abort: shelved change 'foo' not found
  [255]

named shelves, specific filenames, and "commit messages" should all work
(this tests also that editor is invoked, if '--edit' is specified)

  $ hg status -C
  M a/a
  A b.rename/b
    b/b
  A c.copy
    c
  R b/b
  $ HGEDITOR=cat hg shelve -q -n wibble -m wat -e a
  wat
  
  
  HG: Enter commit message.  Lines beginning with 'HG:' are removed.
  HG: Leave message empty to abort commit.
  HG: --
  HG: user: shelve@localhost
  HG: branch 'default'
  HG: changed a/a

expect "a" to no longer be present, but status otherwise unchanged

  $ hg status -C
  A b.rename/b
    b/b
  A c.copy
    c
  R b/b
  $ hg shelve -l --stat
  wibble          (*)    wat (glob)
   a/a |  1 +
   1 files changed, 1 insertions(+), 0 deletions(-)

and now "a/a" should reappear

  $ cd a
  $ hg unshelve -q wibble
  $ cd ..
  $ hg status -C
  M a/a
  A b.rename/b
    b/b
  A c.copy
    c
  R b/b

ensure old shelve backups are being deleted automatically

  $ ls .hg/shelve-backup/
  default-01.hg
  default-01.patch
  default-01.shelve
  wibble.hg
  wibble.patch
  wibble.shelve

cause unshelving to result in a merge with 'a' conflicting

  $ hg shelve -q
  $ echo c>>a/a
  $ hg commit -m second
  $ hg tip --template '{files}\n'
  a/a

add an unrelated change that should be preserved

  $ mkdir foo
  $ echo foo > foo/foo
  $ hg add foo/foo

force a conflicted merge to occur

  $ hg unshelve
  unshelving change 'default'
  temporarily committing pending changes (restore with 'hg unshelve --abort')
  rebasing shelved changes
  merging a/a
  warning: conflicts while merging a/a! (edit, then use 'hg resolve --mark')
  unresolved conflicts (see 'hg resolve', then 'hg unshelve --continue')
  [1]
  $ hg status -v
  M a/a
  M b.rename/b
  M c.copy
  R b/b
  ? a/a.orig
  # The repository is in an unfinished *unshelve* state.
  
  # Unresolved merge conflicts:
  # 
  #     a/a
  # 
  # To mark files as resolved:  hg resolve --mark FILE
  
  # To continue:    hg unshelve --continue
  # To abort:       hg unshelve --abort
  

ensure that we have a merge with unresolved conflicts

#if phasebased
  $ hg heads -q --template '{rev}\n'
  8
  5
  $ hg parents -q --template '{rev}\n'
  8
  5
#endif

#if stripbased
  $ hg heads -q --template '{rev}\n'
  5
  4
  $ hg parents -q --template '{rev}\n'
  4
  5
#endif

  $ hg status
  M a/a
  M b.rename/b
  M c.copy
  R b/b
  ? a/a.orig
  $ hg diff
  diff --git a/a/a b/a/a
  --- a/a/a
  +++ b/a/a
  @@ -1,2 +1,6 @@
   a
  +<<<<<<< shelve:       2377350b6337 - shelve: pending changes temporary commit
   c
  +=======
  +a
  +>>>>>>> working-copy: a68ec3400638 - shelve: changes to: [mq]: second.patch
  diff --git a/b/b b/b.rename/b
  rename from b/b
  rename to b.rename/b
  diff --git a/c b/c.copy
  copy from c
  copy to c.copy
  $ hg resolve -l
  U a/a

  $ hg shelve
  abort: unshelve already in progress
  (use 'hg unshelve --continue' or 'hg unshelve --abort')
  [255]

abort the unshelve and be happy

  $ hg status
  M a/a
  M b.rename/b
  M c.copy
  R b/b
  ? a/a.orig
  $ hg unshelve -a
  unshelve of 'default' aborted
  $ hg heads -q
  [37]:2e69b451d1ea (re)
  $ hg parents
  changeset:   [37]:2e69b451d1ea (re)
  tag:         tip
  parent:      3:509104101065 (?)
  user:        test
  date:        Thu Jan 01 00:00:00 1970 +0000
  summary:     second
  
  $ hg resolve -l
  $ hg status
  A foo/foo
  ? a/a.orig

try to continue with no unshelve underway

  $ hg unshelve -c
  abort: no unshelve in progress
  [255]
  $ hg status
  A foo/foo
  ? a/a.orig

redo the unshelve to get a conflict

  $ hg unshelve -q
  warning: conflicts while merging a/a! (edit, then use 'hg resolve --mark')
  unresolved conflicts (see 'hg resolve', then 'hg unshelve --continue')
  [1]

attempt to continue

  $ hg unshelve -c
  abort: unresolved conflicts, can't continue
  (see 'hg resolve', then 'hg unshelve --continue')
  [255]

  $ hg revert -r . a/a
  $ hg resolve -m a/a
  (no more unresolved files)
  continue: hg unshelve --continue

  $ hg commit -m 'commit while unshelve in progress'
  abort: unshelve already in progress
  (use 'hg unshelve --continue' or 'hg unshelve --abort')
  [255]

  $ hg graft --continue
  abort: no graft in progress
  (continue: hg unshelve --continue)
  [255]
  $ hg unshelve -c
  unshelve of 'default' complete

ensure the repo is as we hope

  $ hg parents
  changeset:   [37]:2e69b451d1ea (re)
  tag:         tip
  parent:      3:509104101065 (?)
  user:        test
  date:        Thu Jan 01 00:00:00 1970 +0000
  summary:     second
  
  $ hg heads -q
  [37]:2e69b451d1ea (re)

  $ hg status -C
  A b.rename/b
    b/b
  A c.copy
    c
  A foo/foo
  R b/b
  ? a/a.orig

there should be no shelves left

  $ hg shelve -l

#if execbit

ensure that metadata-only changes are shelved

  $ chmod +x a/a
  $ hg shelve -q -n execbit a/a
  $ hg status a/a
  $ hg unshelve -q execbit
  $ hg status a/a
  M a/a
  $ hg revert a/a

#else

Dummy shelve op, to keep rev numbers aligned

  $ echo foo > a/a
  $ hg shelve -q -n dummy a/a
  $ hg unshelve -q dummy
  $ hg revert a/a

#endif

#if symlink

  $ rm a/a
  $ ln -s foo a/a
  $ hg shelve -q -n symlink a/a
  $ hg status a/a
  $ hg unshelve -q -n symlink
  $ hg status a/a
  M a/a
  $ hg revert a/a

#else

Dummy shelve op, to keep rev numbers aligned

  $ echo bar > a/a
  $ hg shelve -q -n dummy a/a
  $ hg unshelve -q dummy
  $ hg revert a/a

#endif

set up another conflict between a commit and a shelved change

  $ hg revert -q -C -a
  $ rm a/a.orig b.rename/b c.copy
  $ echo a >> a/a
  $ hg shelve -q
  $ echo x >> a/a
  $ hg ci -m 'create conflict'
  $ hg add foo/foo

if we resolve a conflict while unshelving, the unshelve should succeed

  $ hg unshelve --tool :merge-other --keep
  unshelving change 'default'
  temporarily committing pending changes (restore with 'hg unshelve --abort')
  rebasing shelved changes
  merging a/a
  $ hg parents -q
  (4|13):33f7f61e6c5e (re)
  $ hg shelve -l
  default         (*)* changes to: second (glob)
  $ hg status
  M a/a
  A foo/foo
  $ cat a/a
  a
  c
  a
  $ cat > a/a << EOF
  > a
  > c
  > x
  > EOF

  $ HGMERGE=true hg unshelve
  unshelving change 'default'
  temporarily committing pending changes (restore with 'hg unshelve --abort')
  rebasing shelved changes
  merging a/a
  note: unshelved changes already existed in the working copy
  $ hg parents -q
  (4|13):33f7f61e6c5e (re)
  $ hg shelve -l
  $ hg status
  A foo/foo
  $ cat a/a
  a
  c
  x

test keep and cleanup

  $ hg shelve
  shelved as default
  0 files updated, 0 files merged, 1 files removed, 0 files unresolved
  $ hg shelve --list
  default         (*)* changes to: create conflict (glob)
  $ hg unshelve -k
  unshelving change 'default'
  $ hg shelve --list
  default         (*)* changes to: create conflict (glob)
  $ hg shelve --cleanup
  $ hg shelve --list

  $ hg shelve --cleanup --delete
  abort: options '--cleanup' and '--delete' may not be used together
  [255]
  $ hg shelve --cleanup --patch
  abort: options '--cleanup' and '--patch' may not be used together
  [255]
  $ hg shelve --cleanup --message MESSAGE
  abort: options '--cleanup' and '--message' may not be used together
  [255]

test bookmarks

  $ hg bookmark test
  $ hg bookmark
   \* test                      (4|13):33f7f61e6c5e (re)
  $ hg shelve
  shelved as test
  0 files updated, 0 files merged, 1 files removed, 0 files unresolved
  $ hg bookmark
   \* test                      (4|13):33f7f61e6c5e (re)
  $ hg unshelve
  unshelving change 'test'
  $ hg bookmark
   \* test                      (4|13):33f7f61e6c5e (re)

shelve should still work even if mq is disabled

  $ hg --config extensions.mq=! shelve
  shelved as test
  0 files updated, 0 files merged, 1 files removed, 0 files unresolved
  $ hg --config extensions.mq=! shelve --list
  test            (*)* changes to: create conflict (glob)
  $ hg bookmark
   \* test                      (4|13):33f7f61e6c5e (re)
  $ hg --config extensions.mq=! unshelve
  unshelving change 'test'
  $ hg bookmark
   \* test                      (4|13):33f7f61e6c5e (re)

Recreate some conflict again

  $ hg up -C -r 2e69b451d1ea
  1 files updated, 0 files merged, 0 files removed, 0 files unresolved
  (leaving bookmark test)
  $ echo y >> a/a
  $ hg shelve
  shelved as default
  1 files updated, 0 files merged, 0 files removed, 0 files unresolved
  $ hg up test
  1 files updated, 0 files merged, 0 files removed, 0 files unresolved
  (activating bookmark test)
  $ hg bookmark
   \* test                      (4|13):33f7f61e6c5e (re)
  $ hg unshelve
  unshelving change 'default'
  rebasing shelved changes
  merging a/a
  warning: conflicts while merging a/a! (edit, then use 'hg resolve --mark')
  unresolved conflicts (see 'hg resolve', then 'hg unshelve --continue')
  [1]
  $ hg bookmark
     test                      (4|13):33f7f61e6c5e (re)

Test that resolving all conflicts in one direction (so that the rebase
is a no-op), works (issue4398)

  $ hg revert -a -r .
  reverting a/a
  $ hg resolve -m a/a
  (no more unresolved files)
  continue: hg unshelve --continue
  $ hg unshelve -c
  note: unshelved changes already existed in the working copy
  unshelve of 'default' complete
  $ hg bookmark
   \* test                      (4|13):33f7f61e6c5e (re)
  $ hg diff
  $ hg status
  ? a/a.orig
  ? foo/foo
  $ hg summary
  parent: (4|13):33f7f61e6c5e tip (re)
   create conflict
  branch: default
  bookmarks: *test
  commit: 2 unknown (clean)
  update: (current)
  phases: 5 draft

  $ hg shelve --delete --stat
  abort: options '--delete' and '--stat' may not be used together
  [255]
  $ hg shelve --delete --name NAME
  abort: options '--delete' and '--name' may not be used together
  [255]

Test interactive shelve
  $ cat <<EOF >> $HGRCPATH
  > [ui]
  > interactive = true
  > EOF
  $ echo 'a' >> a/b
  $ cat a/a >> a/b
  $ echo 'x' >> a/b
  $ mv a/b a/a
  $ echo 'a' >> foo/foo
  $ hg st
  M a/a
  ? a/a.orig
  ? foo/foo
  $ cat a/a
  a
  a
  c
  x
  x
  $ cat foo/foo
  foo
  a
  $ hg shelve --interactive --config ui.interactive=false
  abort: running non-interactively
  [255]
  $ hg shelve --interactive << EOF
  > y
  > y
  > n
  > EOF
  diff --git a/a/a b/a/a
  2 hunks, 2 lines changed
  examine changes to 'a/a'? [Ynesfdaq?] y
  
  @@ -1,3 +1,4 @@
  +a
   a
   c
   x
  record change 1/2 to 'a/a'? [Ynesfdaq?] y
  
  @@ -1,3 +2,4 @@
   a
   c
   x
  +x
  record change 2/2 to 'a/a'? [Ynesfdaq?] n
  
  shelved as test
  merging a/a
  0 files updated, 1 files merged, 0 files removed, 0 files unresolved
  $ cat a/a
  a
  c
  x
  x
  $ cat foo/foo
  foo
  a
  $ hg st
  M a/a
  ? foo/foo
  $ hg bookmark
   \* test                      (4|13):33f7f61e6c5e (re)
  $ hg unshelve
  unshelving change 'test'
  temporarily committing pending changes (restore with 'hg unshelve --abort')
  rebasing shelved changes
  merging a/a
  $ hg bookmark
   \* test                      (4|13):33f7f61e6c5e (re)
  $ cat a/a
  a
  a
  c
  x
  x

shelve --patch and shelve --stat should work with valid shelfnames

  $ hg up --clean .
  1 files updated, 0 files merged, 0 files removed, 0 files unresolved
  (leaving bookmark test)
  $ hg shelve --list
  $ echo 'patch a' > shelf-patch-a
  $ hg add shelf-patch-a
  $ hg shelve
  shelved as default
  0 files updated, 0 files merged, 1 files removed, 0 files unresolved
  $ echo 'patch b' > shelf-patch-b
  $ hg add shelf-patch-b
  $ hg shelve
  shelved as default-01
  0 files updated, 0 files merged, 1 files removed, 0 files unresolved
  $ hg shelve --patch default default-01
  default-01      (*)* changes to: create conflict (glob)
  
  diff --git a/shelf-patch-b b/shelf-patch-b
  new file mode 100644
  --- /dev/null
  +++ b/shelf-patch-b
  @@ -0,0 +1,1 @@
  +patch b
  default         (*)* changes to: create conflict (glob)
  
  diff --git a/shelf-patch-a b/shelf-patch-a
  new file mode 100644
  --- /dev/null
  +++ b/shelf-patch-a
  @@ -0,0 +1,1 @@
  +patch a
  $ hg shelve --stat default default-01
  default-01      (*)* changes to: create conflict (glob)
   shelf-patch-b |  1 +
   1 files changed, 1 insertions(+), 0 deletions(-)
  default         (*)* changes to: create conflict (glob)
   shelf-patch-a |  1 +
   1 files changed, 1 insertions(+), 0 deletions(-)
  $ hg shelve --patch default
  default         (*)* changes to: create conflict (glob)
  
  diff --git a/shelf-patch-a b/shelf-patch-a
  new file mode 100644
  --- /dev/null
  +++ b/shelf-patch-a
  @@ -0,0 +1,1 @@
  +patch a
  $ hg shelve --stat default
  default         (*)* changes to: create conflict (glob)
   shelf-patch-a |  1 +
   1 files changed, 1 insertions(+), 0 deletions(-)
  $ hg shelve --patch nonexistentshelf
  abort: cannot find shelf nonexistentshelf
  [255]
  $ hg shelve --stat nonexistentshelf
  abort: cannot find shelf nonexistentshelf
  [255]
  $ hg shelve --patch default nonexistentshelf
  abort: cannot find shelf nonexistentshelf
  [255]

when the user asks for a patch, we assume they want the most recent shelve if
they don't provide a shelve name

  $ hg shelve --patch
  default-01      (*)* changes to: create conflict (glob)
  
  diff --git a/shelf-patch-b b/shelf-patch-b
  new file mode 100644
  --- /dev/null
  +++ b/shelf-patch-b
  @@ -0,0 +1,1 @@
  +patch b

  $ cd ..

Shelve from general delta repo uses bundle2 on disk
--------------------------------------------------

no general delta

  $ hg clone --pull repo bundle1 --config format.usegeneraldelta=0
  requesting all changes
  adding changesets
  adding manifests
  adding file changes
  added 5 changesets with 8 changes to 6 files
  new changesets cc01e2b0c59f:33f7f61e6c5e
  updating to branch default
  6 files updated, 0 files merged, 0 files removed, 0 files unresolved
  $ cd bundle1
  $ echo babar > jungle
  $ hg add jungle
  $ hg shelve
  shelved as default
  0 files updated, 0 files merged, 1 files removed, 0 files unresolved
  $ hg debugbundle .hg/shelved/*.hg
  330882a04d2ce8487636b1fb292e5beea77fa1e3
  $ cd ..

with general delta

  $ hg clone --pull repo bundle2 --config format.usegeneraldelta=1
  requesting all changes
  adding changesets
  adding manifests
  adding file changes
  added 5 changesets with 8 changes to 6 files
  new changesets cc01e2b0c59f:33f7f61e6c5e
  updating to branch default
  6 files updated, 0 files merged, 0 files removed, 0 files unresolved
  $ cd bundle2
  $ echo babar > jungle
  $ hg add jungle
  $ hg shelve
  shelved as default
  0 files updated, 0 files merged, 1 files removed, 0 files unresolved
  $ hg debugbundle .hg/shelved/*.hg
  Stream params: {Compression: BZ}
  changegroup -- {nbchanges: 1, version: 02} (mandatory: True)
      330882a04d2ce8487636b1fb292e5beea77fa1e3
  $ cd ..

Test visibility of in-memory changes inside transaction to external hook
------------------------------------------------------------------------

  $ cd repo

  $ echo xxxx >> x
  $ hg commit -m "#5: changes to invoke rebase"

  $ cat > $TESTTMP/checkvisibility.sh <<EOF
  > echo "==== \$1:"
  > hg parents --template "VISIBLE {rev}:{node|short}\n"
  > # test that pending changes are hidden
  > unset HG_PENDING
  > hg parents --template "ACTUAL  {rev}:{node|short}\n"
  > echo "===="
  > EOF

  $ cat >> .hg/hgrc <<EOF
  > [defaults]
  > # to fix hash id of temporary revisions
  > unshelve = --date '0 0'
  > EOF

"hg unshelve" at REV5 implies steps below:

(1) commit changes in the working directory (REV6)
(2) unbundle shelved revision (REV7)
(3) rebase: merge REV7 into REV6 (REV6 => REV6, REV7)
(4) rebase: commit merged revision (REV8)
(5) rebase: update to REV6 (REV8 => REV6)
(6) update to REV5 (REV6 => REV5)
(7) abort transaction

== test visibility to external preupdate hook

  $ cat >> .hg/hgrc <<EOF
  > [hooks]
  > preupdate.visibility = sh $TESTTMP/checkvisibility.sh preupdate
  > EOF

  $ echo nnnn >> n

  $ sh $TESTTMP/checkvisibility.sh before-unshelving
  ==== before-unshelving:
  VISIBLE (5|19):703117a2acfb (re)
  ACTUAL  (5|19):703117a2acfb (re)
  ====

  $ hg unshelve --keep default
  temporarily committing pending changes (restore with 'hg unshelve --abort')
  rebasing shelved changes
  ==== preupdate:
  VISIBLE (6|20):54c00d20fb3f (re)
  ACTUAL  (5|19):703117a2acfb (re)
  ====
  ==== preupdate:
  VISIBLE (8|21):8efe6f7537dc (re)
  ACTUAL  (5|19):703117a2acfb (re)
  ====
  ==== preupdate:
  VISIBLE (6|20):54c00d20fb3f (re)
  ACTUAL  (5|19):703117a2acfb (re)
  ====

  $ cat >> .hg/hgrc <<EOF
  > [hooks]
  > preupdate.visibility =
  > EOF

  $ sh $TESTTMP/checkvisibility.sh after-unshelving
  ==== after-unshelving:
  VISIBLE (5|19):703117a2acfb (re)
  ACTUAL  (5|19):703117a2acfb (re)
  ====

== test visibility to external update hook

  $ hg update -q -C 703117a2acfb

  $ cat >> .hg/hgrc <<EOF
  > [hooks]
  > update.visibility = sh $TESTTMP/checkvisibility.sh update
  > EOF

  $ echo nnnn >> n

  $ sh $TESTTMP/checkvisibility.sh before-unshelving
  ==== before-unshelving:
  VISIBLE (5|19):703117a2acfb (re)
  ACTUAL  (5|19):703117a2acfb (re)
  ====

  $ hg unshelve --keep default
  temporarily committing pending changes (restore with 'hg unshelve --abort')
  rebasing shelved changes
  ==== update:
  VISIBLE (6|20):54c00d20fb3f (re)
  VISIBLE 1?7:492ed9d705e5 (re)
  ACTUAL  (5|19):703117a2acfb (re)
  ====
  ==== update:
  VISIBLE (6|20):54c00d20fb3f (re)
  ACTUAL  (5|19):703117a2acfb (re)
  ====
  ==== update:
  VISIBLE (5|19):703117a2acfb (re)
  ACTUAL  (5|19):703117a2acfb (re)
  ====

  $ cat >> .hg/hgrc <<EOF
  > [hooks]
  > update.visibility =
  > EOF

  $ sh $TESTTMP/checkvisibility.sh after-unshelving
  ==== after-unshelving:
  VISIBLE (5|19):703117a2acfb (re)
  ACTUAL  (5|19):703117a2acfb (re)
  ====

  $ cd ..

Keep active bookmark while (un)shelving even on shared repo (issue4940)
-----------------------------------------------------------------------

  $ cat <<EOF >> $HGRCPATH
  > [extensions]
  > share =
  > EOF

  $ hg bookmarks -R repo
     test                      (4|13):33f7f61e6c5e (re)
  $ hg share -B repo share
  updating working directory
  6 files updated, 0 files merged, 0 files removed, 0 files unresolved
  $ cd share

  $ hg bookmarks
     test                      (4|13):33f7f61e6c5e (re)
  $ hg bookmarks foo
  $ hg bookmarks
   \* foo                       (5|19):703117a2acfb (re)
     test                      (4|13):33f7f61e6c5e (re)
  $ echo x >> x
  $ hg shelve
  shelved as foo
  1 files updated, 0 files merged, 0 files removed, 0 files unresolved
  $ hg bookmarks
   \* foo                       (5|19):703117a2acfb (re)
     test                      (4|13):33f7f61e6c5e (re)

  $ hg unshelve
  unshelving change 'foo'
  $ hg bookmarks
   \* foo                       (5|19):703117a2acfb (re)
     test                      (4|13):33f7f61e6c5e (re)

  $ cd ..
