#require bzr

N.B. bzr 1.13 has a bug that breaks this test.  If you see this
test fail, check your bzr version.  Upgrading to bzr 1.13.1
should fix it.

  $ . "$TESTDIR/bzr-definitions"

test multiple merges at once

  $ mkdir test-multimerge
  $ cd test-multimerge
  $ bzr init -q source
  $ cd source
  $ echo content > file
  $ bzr add -q file
  $ bzr commit -q -m 'Initial add' '--commit-time=2009-10-10 08:00:00 +0100'
  $ cd ..
  $ bzr branch -q source source-branch1
  $ cd source-branch1
  $ echo morecontent >> file
  $ echo evenmorecontent > file-branch1
  $ bzr add -q file-branch1
  $ bzr commit -q -m 'Added branch1 file' '--commit-time=2009-10-10 08:00:01 +0100'
  $ cd ../source
  $ sleep 1
  $ echo content > file-parent
  $ bzr add -q file-parent
  $ bzr commit -q -m 'Added parent file' '--commit-time=2009-10-10 08:00:02 +0100'
  $ cd ..
  $ bzr branch -q source source-branch2
  $ cd source-branch2
  $ echo somecontent > file-branch2
  $ bzr add -q file-branch2
  $ bzr commit -q -m 'Added brach2 file' '--commit-time=2009-10-10 08:00:03 +0100'
  $ sleep 1
  $ cd ../source
  $ bzr merge -q ../source-branch1
  $ bzr merge -q --force ../source-branch2
  $ bzr commit -q -m 'Merged branches' '--commit-time=2009-10-10 08:00:04 +0100'
  $ cd ..
  $ hg convert --datesort --config convert.bzr.saverev=False source source-hg
  initializing destination source-hg repository
  scanning source...
  sorting...
  converting...
  4 Initial add
  3 Added branch1 file
  2 Added parent file
  1 Added brach2 file
  0 Merged branches
  $ glog -R source-hg
  o    5@source "(octopus merge fixup)" files:
  |\
  | o    4@source "Merged branches" files: file-branch2
  | |\
  o---+  3@source-branch2 "Added brach2 file" files: file-branch2
   / /
  | o  2@source "Added parent file" files: file-parent
  | |
  o |  1@source-branch1 "Added branch1 file" files: file file-branch1
  |/
  o  0@source "Initial add" files: file
  
  $ manifest source-hg tip
  % manifest of tip
  644   file
  644   file-branch1
  644   file-branch2
  644   file-parent

  $ cd ..
