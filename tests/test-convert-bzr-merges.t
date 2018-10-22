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
  $ echo text > rename_me
  $ bzr add -q file rename_me
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
  $ bzr mv -q rename_me renamed
  $ echo change > renamed
  $ bzr commit -q -m 'Added brach2 file' '--commit-time=2009-10-10 08:00:03 +0100'
  $ sleep 1
  $ cd ../source
  $ bzr merge -q ../source-branch1
  $ bzr merge -q --force ../source-branch2
  $ bzr commit -q -m 'Merged branches' '--commit-time=2009-10-10 08:00:04 +0100'
  $ cd ..

BUG: file-branch2 should not be added in rev 4, and the rename_me -> renamed
move should be recorded in the fixup merge.
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
  warning: can't find ancestor for 'renamed' copied from 'rename_me'!
  $ glog -R source-hg
  o    5@source "(octopus merge fixup)" files+: [], files-: [], files: [renamed]
  |\
  | o    4@source "Merged branches" files+: [file-branch1 file-branch2 renamed], files-: [rename_me], files: [file]
  | |\
  o---+  3@source-branch2 "Added brach2 file" files+: [file-branch2 renamed], files-: [rename_me], files: []
   / /
  | o  2@source "Added parent file" files+: [file-parent], files-: [], files: []
  | |
  o |  1@source-branch1 "Added branch1 file" files+: [file-branch1], files-: [], files: [file]
  |/
  o  0@source "Initial add" files+: [file rename_me], files-: [], files: []
  
  $ manifest source-hg tip
  % manifest of tip
  644   file
  644   file-branch1
  644   file-branch2
  644   file-parent
  644   renamed

  $ hg convert source-hg hg2hg
  initializing destination hg2hg repository
  scanning source...
  sorting...
  converting...
  5 Initial add
  4 Added branch1 file
  3 Added parent file
  2 Added brach2 file
  1 Merged branches
  0 (octopus merge fixup)

BUG: The manifest entries should be the same for matching revisions, and
nothing should be outgoing

  $ hg -R source-hg manifest --debug -r tip | grep renamed
  67109fdebf6c556eb0a9d5696dd98c8420520405 644   renamed
  $ hg -R hg2hg manifest --debug -r tip | grep renamed
  27c968376d7c3afd095ecb9c7697919b933448c8 644   renamed
  $ hg -R source-hg manifest --debug -r 'tip^' | grep renamed
  27c968376d7c3afd095ecb9c7697919b933448c8 644   renamed
  $ hg -R hg2hg manifest --debug -r 'tip^' | grep renamed
  27c968376d7c3afd095ecb9c7697919b933448c8 644   renamed

BUG: The revisions found should be the same in both repos

  $ hg --cwd source-hg log -r 'file("renamed")' -G -Tcompact
  o    5[tip]:4,3   6652429c300a   2009-10-10 08:00 +0100   foo
  |\     (octopus merge fixup)
  | |
  | o    4:2,1   e0ae8af3503a   2009-10-10 08:00 +0100   foo
  | |\     Merged branches
  | ~ ~
  o  3   138bed2e14be   2009-10-10 08:00 +0100   foo
  |    Added brach2 file
  ~
  $ hg --cwd hg2hg log -r 'file("renamed")' -G -Tcompact
  o    4:2,1   e0ae8af3503a   2009-10-10 08:00 +0100   foo
  |\     Merged branches
  ~ ~
  o  3   138bed2e14be   2009-10-10 08:00 +0100   foo
  |    Added brach2 file
  ~

BUG(?): The move seems to be recorded in rev 4, so it should probably show up
there.  It's not recorded as a move in rev 5, even in source-hg.

  $ hg -R source-hg up -q tip
  $ hg -R hg2hg up -q tip
  $ hg --cwd source-hg log -r 'follow("renamed")' -G -Tcompact
  @    5[tip]:4,3   6652429c300a   2009-10-10 08:00 +0100   foo
  |\     (octopus merge fixup)
  | :
  o :  3   138bed2e14be   2009-10-10 08:00 +0100   foo
  :/     Added brach2 file
  :
  o  0   18b86f5df51b   2009-10-10 08:00 +0100   foo
       Initial add
  
  $ hg --cwd hg2hg log -r 'follow("renamed")' -G -Tcompact
  o  3   138bed2e14be   2009-10-10 08:00 +0100   foo
  :    Added brach2 file
  :
  o  0   18b86f5df51b   2009-10-10 08:00 +0100   foo
       Initial add
  

  $ hg -R hg2hg out source-hg -T compact
  comparing with source-hg
  searching for changes
  5[tip]:4,3   3be2299ccd31   2009-10-10 08:00 +0100   foo
    (octopus merge fixup)
  

  $ glog -R hg2hg
  @    5@source "(octopus merge fixup)" files+: [], files-: [], files: []
  |\
  | o    4@source "Merged branches" files+: [file-branch1 file-branch2 renamed], files-: [rename_me], files: [file]
  | |\
  o---+  3@source-branch2 "Added brach2 file" files+: [file-branch2 renamed], files-: [rename_me], files: []
   / /
  | o  2@source "Added parent file" files+: [file-parent], files-: [], files: []
  | |
  o |  1@source-branch1 "Added branch1 file" files+: [file-branch1], files-: [], files: [file]
  |/
  o  0@source "Initial add" files+: [file rename_me], files-: [], files: []
  

  $ hg -R source-hg log --debug -r tip
  changeset:   5:6652429c300ab66fdeaf2e730945676a00b53231
  branch:      source
  tag:         tip
  phase:       draft
  parent:      4:e0ae8af3503af9bbffb0b29268a02744cc61a561
  parent:      3:138bed2e14be415a2692b02e41405b2864f758b4
  manifest:    5:1eabd5f5d4b985784cf2c45c717ff053eca14b0d
  user:        Foo Bar <foo.bar@example.com>
  date:        Sat Oct 10 08:00:04 2009 +0100
  files:       renamed
  extra:       branch=source
  description:
  (octopus merge fixup)
  
  
  $ hg -R hg2hg log --debug -r tip
  changeset:   5:3be2299ccd315ff9aab2b49bdb0d14e3244435e8
  branch:      source
  tag:         tip
  phase:       draft
  parent:      4:e0ae8af3503af9bbffb0b29268a02744cc61a561
  parent:      3:138bed2e14be415a2692b02e41405b2864f758b4
  manifest:    4:3ece3c7f2cc6df15b3cbbf3273c69869fc7c3ab0
  user:        Foo Bar <foo.bar@example.com>
  date:        Sat Oct 10 08:00:04 2009 +0100
  extra:       branch=source
  description:
  (octopus merge fixup)
  
  
  $ hg -R source-hg manifest --debug -r tip
  cdf31ed9242b209cd94697112160e2c5b37a667d 644   file
  5108144f585149b29779d7c7e51d61dd22303ffe 644   file-branch1
  80753c4a9ac3806858405b96b24a907b309e3616 644   file-branch2
  7108421418404a937c684d2479a34a24d2ce4757 644   file-parent
  67109fdebf6c556eb0a9d5696dd98c8420520405 644   renamed
  $ hg -R source-hg manifest --debug -r 'tip^'
  cdf31ed9242b209cd94697112160e2c5b37a667d 644   file
  5108144f585149b29779d7c7e51d61dd22303ffe 644   file-branch1
  80753c4a9ac3806858405b96b24a907b309e3616 644   file-branch2
  7108421418404a937c684d2479a34a24d2ce4757 644   file-parent
  27c968376d7c3afd095ecb9c7697919b933448c8 644   renamed

  $ hg -R hg2hg manifest --debug -r tip
  cdf31ed9242b209cd94697112160e2c5b37a667d 644   file
  5108144f585149b29779d7c7e51d61dd22303ffe 644   file-branch1
  80753c4a9ac3806858405b96b24a907b309e3616 644   file-branch2
  7108421418404a937c684d2479a34a24d2ce4757 644   file-parent
  27c968376d7c3afd095ecb9c7697919b933448c8 644   renamed
  $ hg -R hg2hg manifest --debug -r 'tip^'
  cdf31ed9242b209cd94697112160e2c5b37a667d 644   file
  5108144f585149b29779d7c7e51d61dd22303ffe 644   file-branch1
  80753c4a9ac3806858405b96b24a907b309e3616 644   file-branch2
  7108421418404a937c684d2479a34a24d2ce4757 644   file-parent
  27c968376d7c3afd095ecb9c7697919b933448c8 644   renamed

  $ cd ..
