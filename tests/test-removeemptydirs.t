Tests for experimental.removeemptydirs

  $ NO_RM=--config=experimental.removeemptydirs=0
  $ isdir() { if [ -d $1 ]; then echo yes; else echo no; fi }
  $ isfile() { if [ -f $1 ]; then echo yes; else echo no; fi }

`hg rm` of the last file in a directory:
  $ hg init hgrm
  $ cd hgrm
  $ mkdir somedir
  $ echo hi > somedir/foo
  $ hg ci -qAm foo
  $ isdir somedir
  yes
  $ hg rm somedir/foo
  $ isdir somedir
  no
  $ hg revert -qa
  $ isdir somedir
  yes
  $ hg $NO_RM rm somedir/foo
  $ isdir somedir
  yes
  $ ls somedir
  $ cd $TESTTMP

`hg mv` of the last file in a directory:
  $ hg init hgmv
  $ cd hgmv
  $ mkdir somedir
  $ mkdir destdir
  $ echo hi > somedir/foo
  $ hg ci -qAm foo
  $ isdir somedir
  yes
  $ hg mv somedir/foo destdir/foo
  $ isdir somedir
  no
  $ hg revert -qa
(revert doesn't get rid of destdir/foo?)
  $ rm destdir/foo
  $ isdir somedir
  yes
  $ hg $NO_RM mv somedir/foo destdir/foo
  $ isdir somedir
  yes
  $ ls somedir
  $ cd $TESTTMP

Updating to a commit that doesn't have the directory:
  $ hg init hgupdate
  $ cd hgupdate
  $ echo hi > r0
  $ hg ci -qAm r0
  $ mkdir somedir
  $ echo hi > somedir/foo
  $ hg ci -qAm r1
  $ isdir somedir
  yes
  $ hg co -q -r ".^"
  $ isdir somedir
  no
  $ hg co -q tip
  $ isdir somedir
  yes
  $ hg $NO_RM co -q -r ".^"
  $ isdir somedir
  yes
  $ ls somedir
  $ cd $TESTTMP

Rebasing across a commit that doesn't have the directory, from inside the
directory:
  $ hg init hgrebase
  $ cd hgrebase
  $ echo hi > r0
  $ hg ci -qAm r0
  $ mkdir somedir
  $ echo hi > somedir/foo
  $ hg ci -qAm first_rebase_source
  $ hg $NO_RM co -q -r ".^"
  $ echo hi > somedir/bar
  $ hg ci -qAm first_rebase_dest
  $ hg $NO_RM co -q -r ".^"
  $ echo hi > somedir/baz
  $ hg ci -qAm second_rebase_dest
  $ hg co -qr 'desc(first_rebase_source)'
  $ cd $TESTTMP/hgrebase/somedir
  $ hg --config extensions.rebase= rebase -qr . -d 'desc(first_rebase_dest)'
  current directory was removed (rmcwd !)
  (consider changing to repo root: $TESTTMP/hgrebase) (rmcwd !)
  $ cd $TESTTMP/hgrebase/somedir
(The current node is the rebased first_rebase_source on top of
first_rebase_dest)
This should not output anything about current directory being removed:
  $ hg $NO_RM --config extensions.rebase= rebase -qr . -d 'desc(second_rebase_dest)'
  $ cd $TESTTMP

Histediting across a commit that doesn't have the directory, from inside the
directory (reordering nodes):
  $ hg init hghistedit
  $ cd hghistedit
  $ echo hi > r0
  $ hg ci -qAm r0
  $ echo hi > r1
  $ hg ci -qAm r1
  $ echo hi > r2
  $ hg ci -qAm r2
  $ mkdir somedir
  $ echo hi > somedir/foo
  $ hg ci -qAm migrating_revision
  $ cat > histedit_commands <<EOF
  > pick 89079fab8aee 0 r0
  > pick e6d271df3142 1 r1
  > pick 89e25aa83f0f 3 migrating_revision
  > pick b550aa12d873 2 r2
  > EOF
  $ cd $TESTTMP/hghistedit/somedir
  $ hg --config extensions.histedit= histedit -q --commands ../histedit_commands

histedit doesn't output anything when the current diretory is removed. We rely
on the tests being commonly run on machines where the current directory
disappearing from underneath us actually has an observable effect, such as an
error or no files listed
#if linuxormacos
  $ isfile foo
  no
#endif
  $ cd $TESTTMP/hghistedit/somedir
  $ isfile foo
  yes

  $ cd $TESTTMP/hghistedit
  $ cat > histedit_commands <<EOF
  > pick 89079fab8aee 0 r0
  > pick 7c7a22c6009f 3 migrating_revision
  > pick e6d271df3142 1 r1
  > pick 40a53c2d4276 2 r2
  > EOF
  $ cd $TESTTMP/hghistedit/somedir
  $ hg $NO_RM --config extensions.histedit= histedit -q --commands ../histedit_commands
Regardless of system, we should always get a 'yes' here.
  $ isfile foo
  yes
  $ cd $TESTTMP

This is essentially the exact test from issue5826, just cleaned up a little:

  $ hg init issue5826_withrm
  $ cd issue5826_withrm

Let's only turn this on for this repo so that we don't contaminate later tests.
  $ cat >> .hg/hgrc <<EOF
  > [extensions]
  > histedit =
  > EOF
Commit three revisions that each create a directory:

  $ mkdir foo
  $ touch foo/bar
  $ hg commit -qAm "add foo"

  $ mkdir bar
  $ touch bar/bar
  $ hg commit -qAm "add bar"

  $ mkdir baz
  $ touch baz/bar
  $ hg commit -qAm "add baz"

Enter the first directory:

  $ cd foo

Histedit doing 'pick, pick, fold':

#if rmcwd

  $ hg histedit --commands - <<EOF
  > pick 6274c77c93c3 1 add bar
  > pick ff70a87b588f 0 add foo
  > fold 9992bb0ac0db 2 add baz
  > EOF
  abort: $ENOENT$
  [255]

Go back to the repo root after losing it as part of that operation:
  $ cd $TESTTMP/issue5826_withrm

Note the lack of a non-zero exit code from this function - it exits
successfully, but doesn't really do anything.
  $ hg histedit --continue
  9992bb0ac0db: cannot fold - working copy is not a descendant of previous commit 5c806432464a
  saved backup bundle to $TESTTMP/issue5826_withrm/.hg/strip-backup/ff70a87b588f-e94f9789-histedit.hg

  $ hg log -T '{rev}:{node|short} {desc}\n'
  2:94e3f9fae1d6 fold-temp-revision 9992bb0ac0db
  1:5c806432464a add foo
  0:d17db4b0303a add bar

#else

  $ cd $TESTTMP/issue5826_withrm

  $ hg histedit --commands - <<EOF
  > pick 6274c77c93c3 1 add bar
  > pick ff70a87b588f 0 add foo
  > fold 9992bb0ac0db 2 add baz
  > EOF
  saved backup bundle to $TESTTMP/issue5826_withrm/.hg/strip-backup/5c806432464a-cd4c8d86-histedit.hg

  $ hg log -T '{rev}:{node|short} {desc}\n'
  1:b9eddaa97cbc add foo
  ***
  add baz
  0:d17db4b0303a add bar

#endif

Now test that again with experimental.removeemptydirs=false:
  $ hg init issue5826_norm
  $ cd issue5826_norm

Let's only turn this on for this repo so that we don't contaminate later tests.
  $ cat >> .hg/hgrc <<EOF
  > [extensions]
  > histedit =
  > [experimental]
  > removeemptydirs = false
  > EOF
Commit three revisions that each create a directory:

  $ mkdir foo
  $ touch foo/bar
  $ hg commit -qAm "add foo"

  $ mkdir bar
  $ touch bar/bar
  $ hg commit -qAm "add bar"

  $ mkdir baz
  $ touch baz/bar
  $ hg commit -qAm "add baz"

Enter the first directory:

  $ cd foo

Histedit doing 'pick, pick, fold':

  $ hg histedit --commands - <<EOF
  > pick 6274c77c93c3 1 add bar
  > pick ff70a87b588f 0 add foo
  > fold 9992bb0ac0db 2 add baz
  > EOF
  saved backup bundle to $TESTTMP/issue5826_withrm/issue5826_norm/.hg/strip-backup/5c806432464a-cd4c8d86-histedit.hg

Note the lack of a 'cd' being necessary here, and we don't need to 'histedit
--continue'

  $ hg log -T '{rev}:{node|short} {desc}\n'
  1:b9eddaa97cbc add foo
  ***
  add baz
  0:d17db4b0303a add bar

  $ cd $TESTTMP

Testing `hg split` being run from inside of a directory that was created in the
commit being split:

  $ hg init hgsplit
  $ cd hgsplit
  $ cat >> .hg/hgrc << EOF
  > [ui]
  > interactive = 1
  > [extensions]
  > split =
  > EOF
  $ echo anchor > anchor.txt
  $ hg ci -qAm anchor

Create a changeset with '/otherfile_in_root' and 'somedir/foo', then try to
split it.
  $ echo otherfile > otherfile_in_root
  $ mkdir somedir
  $ cd somedir
  $ echo hi > foo
  $ hg ci -qAm split_me
(Note: need to make this file not in this directory, or else the bug doesn't
reproduce; we're using a separate file due to concerns of portability on
`echo -e`)
  $ cat > ../split_commands << EOF
  > n
  > y
  > y
  > a
  > EOF

The split succeeds on no-rmcwd platforms, which alters the rest of the tests
#if rmcwd
  $ cat ../split_commands | hg split
  current directory was removed
  (consider changing to repo root: $TESTTMP/hgsplit)
  diff --git a/otherfile_in_root b/otherfile_in_root
  new file mode 100644
  examine changes to 'otherfile_in_root'? [Ynesfdaq?] n
  
  diff --git a/somedir/foo b/somedir/foo
  new file mode 100644
  examine changes to 'somedir/foo'? [Ynesfdaq?] y
  
  @@ -0,0 +1,1 @@
  +hi
  record change 2/2 to 'somedir/foo'? [Ynesfdaq?] y
  
  abort: $ENOENT$
  [255]
#endif

Let's try that again without the rmdir
  $ cd $TESTTMP/hgsplit/somedir
Show that the previous split didn't do anything
  $ hg log -T '{rev}:{node|short} {desc}\n'
  1:e26b22a4f0b7 split_me
  0:7e53273730c0 anchor
  $ hg status
  ? split_commands
Try again
  $ cat ../split_commands | hg $NO_RM split
  diff --git a/otherfile_in_root b/otherfile_in_root
  new file mode 100644
  examine changes to 'otherfile_in_root'? [Ynesfdaq?] n
  
  diff --git a/somedir/foo b/somedir/foo
  new file mode 100644
  examine changes to 'somedir/foo'? [Ynesfdaq?] y
  
  @@ -0,0 +1,1 @@
  +hi
  record change 2/2 to 'somedir/foo'? [Ynesfdaq?] y
  
  created new head
  diff --git a/otherfile_in_root b/otherfile_in_root
  new file mode 100644
  examine changes to 'otherfile_in_root'? [Ynesfdaq?] a
  
  saved backup bundle to $TESTTMP/hgsplit/.hg/strip-backup/*-split.hg (glob)
Show that this split did something
  $ hg log -T '{rev}:{node|short} {desc}\n'
  2:a440f24fca4f split_me
  1:c994f20276ab split_me
  0:7e53273730c0 anchor
  $ hg status
  ? split_commands
