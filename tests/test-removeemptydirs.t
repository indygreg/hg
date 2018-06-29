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
  current directory was removed
  (consider changing to repo root: $TESTTMP/hgrebase)
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

  $ cat >> $HGRCPATH <<EOF
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

  $ hg histedit --commands /dev/stdin <<EOF
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

Now test that again with experimental.removeemptydirs=false:
  $ hg init issue5826_norm
  $ cd issue5826_norm

  $ cat >> $HGRCPATH <<EOF
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

  $ hg histedit --commands /dev/stdin <<EOF
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
