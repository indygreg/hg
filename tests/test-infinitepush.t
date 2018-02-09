Testing infinipush extension and the confi options provided by it

Setup

  $ . "$TESTDIR/library-infinitepush.sh"
  $ cp $HGRCPATH $TESTTMP/defaulthgrc
  $ setupcommon
  $ hg init repo
  $ cd repo
  $ setupserver
  $ echo initialcommit > initialcommit
  $ hg ci -Aqm "initialcommit"
  $ hg phase --public .

  $ cd ..
  $ hg clone ssh://user@dummy/repo client -q

Create two heads. Push first head alone, then two heads together. Make sure that
multihead push works.
  $ cd client
  $ echo multihead1 > multihead1
  $ hg add multihead1
  $ hg ci -m "multihead1"
  $ hg up null
  0 files updated, 0 files merged, 2 files removed, 0 files unresolved
  $ echo multihead2 > multihead2
  $ hg ci -Am "multihead2"
  adding multihead2
  created new head
  $ hg push -r . --bundle-store
  pushing to ssh://user@dummy/repo
  searching for changes
  remote: pushing 1 commit:
  remote:     ee4802bf6864  multihead2
  $ hg push -r '1:2' --bundle-store
  pushing to ssh://user@dummy/repo
  searching for changes
  remote: pushing 2 commits:
  remote:     bc22f9a30a82  multihead1
  remote:     ee4802bf6864  multihead2
  $ scratchnodes
  bc22f9a30a821118244deacbd732e394ed0b686c ab1bc557aa090a9e4145512c734b6e8a828393a5
  ee4802bf6864326a6b3dcfff5a03abc2a0a69b8f ab1bc557aa090a9e4145512c734b6e8a828393a5

Create two new scratch bookmarks
  $ hg up 0
  1 files updated, 0 files merged, 1 files removed, 0 files unresolved
  $ echo scratchfirstpart > scratchfirstpart
  $ hg ci -Am "scratchfirstpart"
  adding scratchfirstpart
  created new head
  $ hg push -r . -B scratch/firstpart
  pushing to ssh://user@dummy/repo
  searching for changes
  remote: pushing 1 commit:
  remote:     176993b87e39  scratchfirstpart
  $ hg up 0
  0 files updated, 0 files merged, 1 files removed, 0 files unresolved
  $ echo scratchsecondpart > scratchsecondpart
  $ hg ci -Am "scratchsecondpart"
  adding scratchsecondpart
  created new head
  $ hg push -r . -B scratch/secondpart
  pushing to ssh://user@dummy/repo
  searching for changes
  remote: pushing 1 commit:
  remote:     8db3891c220e  scratchsecondpart

Pull two bookmarks from the second client
  $ cd ..
  $ hg clone ssh://user@dummy/repo client2 -q
  $ cd client2
  $ hg pull -B scratch/firstpart -B scratch/secondpart
  pulling from ssh://user@dummy/repo
  searching for changes
  adding changesets
  adding manifests
  adding file changes
  added 1 changesets with 1 changes to 1 files
  adding changesets
  adding manifests
  adding file changes
  added 1 changesets with 1 changes to 1 files (+1 heads)
  new changesets * (glob)
  (run 'hg heads' to see heads, 'hg merge' to merge)
  $ hg log -r scratch/secondpart -T '{node}'
  8db3891c220e216f6da214e8254bd4371f55efca (no-eol)
  $ hg log -r scratch/firstpart -T '{node}'
  176993b87e39bd88d66a2cccadabe33f0b346339 (no-eol)
Make two commits to the scratch branch

  $ echo testpullbycommithash1 > testpullbycommithash1
  $ hg ci -Am "testpullbycommithash1"
  adding testpullbycommithash1
  created new head
  $ hg log -r '.' -T '{node}\n' > ../testpullbycommithash1
  $ echo testpullbycommithash2 > testpullbycommithash2
  $ hg ci -Aqm "testpullbycommithash2"
  $ hg push -r . -B scratch/mybranch -q

Create third client and pull by commit hash.
Make sure testpullbycommithash2 has not fetched
  $ cd ..
  $ hg clone ssh://user@dummy/repo client3 -q
  $ cd client3
  $ hg pull -r `cat ../testpullbycommithash1`
  pulling from ssh://user@dummy/repo
  searching for changes
  adding changesets
  adding manifests
  adding file changes
  added 1 changesets with 1 changes to 1 files
  new changesets 33910bfe6ffe
  (run 'hg update' to get a working copy)
  $ hg log -G -T '{desc} {phase} {bookmarks}'
  o  testpullbycommithash1 draft
  |
  @  initialcommit public
  
Make public commit in the repo and pull it.
Make sure phase on the client is public.
  $ cd ../repo
  $ echo publiccommit > publiccommit
  $ hg ci -Aqm "publiccommit"
  $ hg phase --public .
  $ cd ../client3
  $ hg pull
  pulling from ssh://user@dummy/repo
  searching for changes
  adding changesets
  adding manifests
  adding file changes
  added 1 changesets with 1 changes to 1 files (+1 heads)
  new changesets a79b6597f322
  (run 'hg heads' to see heads, 'hg merge' to merge)
  $ hg log -G -T '{desc} {phase} {bookmarks} {node|short}'
  o  publiccommit public  a79b6597f322
  |
  | o  testpullbycommithash1 draft  33910bfe6ffe
  |/
  @  initialcommit public  67145f466344
  
  $ hg up a79b6597f322
  1 files updated, 0 files merged, 0 files removed, 0 files unresolved
  $ echo scratchontopofpublic > scratchontopofpublic
  $ hg ci -Aqm "scratchontopofpublic"
  $ hg push -r . -B scratch/scratchontopofpublic
  pushing to ssh://user@dummy/repo
  searching for changes
  remote: pushing 1 commit:
  remote:     c70aee6da07d  scratchontopofpublic
  $ cd ../client2
  $ hg pull -B scratch/scratchontopofpublic
  pulling from ssh://user@dummy/repo
  searching for changes
  adding changesets
  adding manifests
  adding file changes
  added 1 changesets with 1 changes to 1 files (+1 heads)
  adding changesets
  adding manifests
  adding file changes
  added 1 changesets with 1 changes to 1 files
  new changesets a79b6597f322:c70aee6da07d
  (run 'hg heads .' to see heads, 'hg merge' to merge)
  $ hg log -r scratch/scratchontopofpublic -T '{phase}'
  draft (no-eol)
Strip scratchontopofpublic commit and do hg update
  $ hg log -r tip -T '{node}\n'
  c70aee6da07d7cdb9897375473690df3a8563339
  $ echo "[extensions]" >> .hg/hgrc
  $ echo "strip=" >> .hg/hgrc
  $ hg strip -q tip
  $ hg up c70aee6da07d7cdb9897375473690df3a8563339
  'c70aee6da07d7cdb9897375473690df3a8563339' does not exist locally - looking for it remotely...
  pulling from ssh://user@dummy/repo
  searching for changes
  adding changesets
  adding manifests
  adding file changes
  added 1 changesets with 1 changes to 1 files
  new changesets c70aee6da07d
  (run 'hg update' to get a working copy)
  'c70aee6da07d7cdb9897375473690df3a8563339' found remotely
  2 files updated, 0 files merged, 2 files removed, 0 files unresolved

Trying to pull from bad path
  $ hg strip -q tip
  $ hg --config paths.default=badpath up c70aee6da07d7cdb9897375473690df3a8563339
  'c70aee6da07d7cdb9897375473690df3a8563339' does not exist locally - looking for it remotely...
  pulling from $TESTTMP/client2/badpath (glob)
  pull failed: repository $TESTTMP/client2/badpath not found
  abort: unknown revision 'c70aee6da07d7cdb9897375473690df3a8563339'!
  [255]

Strip commit and pull it using hg update with bookmark name
  $ hg strip -q d8fde0ddfc96
  $ hg book -d scratch/mybranch
  $ hg up scratch/mybranch
  'scratch/mybranch' does not exist locally - looking for it remotely...
  pulling from ssh://user@dummy/repo
  searching for changes
  adding changesets
  adding manifests
  adding file changes
  added 1 changesets with 1 changes to 2 files
  new changesets d8fde0ddfc96
  (run 'hg update' to get a working copy)
  'scratch/mybranch' found remotely
  2 files updated, 0 files merged, 1 files removed, 0 files unresolved
  (activating bookmark scratch/mybranch)
  $ hg log -r scratch/mybranch -T '{node}'
  d8fde0ddfc962183977f92d2bc52d303b8840f9d (no-eol)

Test debugfillinfinitepushmetadata
  $ cd ../repo
  $ hg debugfillinfinitepushmetadata
  abort: nodes are not specified
  [255]
  $ hg debugfillinfinitepushmetadata --node randomnode
  abort: node randomnode is not found
  [255]
  $ hg debugfillinfinitepushmetadata --node d8fde0ddfc962183977f92d2bc52d303b8840f9d
  $ cat .hg/scratchbranches/index/nodemetadatamap/d8fde0ddfc962183977f92d2bc52d303b8840f9d
  {"changed_files": {"testpullbycommithash2": {"adds": 1, "isbinary": false, "removes": 0, "status": "added"}}} (no-eol)

  $ cd ../client
  $ hg up d8fde0ddfc962183977f92d2bc52d303b8840f9d
  'd8fde0ddfc962183977f92d2bc52d303b8840f9d' does not exist locally - looking for it remotely...
  pulling from ssh://user@dummy/repo
  searching for changes
  adding changesets
  adding manifests
  adding file changes
  added 2 changesets with 2 changes to 2 files (+1 heads)
  new changesets 33910bfe6ffe:d8fde0ddfc96
  (run 'hg heads .' to see heads, 'hg merge' to merge)
  'd8fde0ddfc962183977f92d2bc52d303b8840f9d' found remotely
  2 files updated, 0 files merged, 1 files removed, 0 files unresolved
  $ echo file > file
  $ hg add file
  $ hg rm testpullbycommithash2
  $ hg ci -m 'add and rm files'
  $ hg log -r . -T '{node}\n'
  3edfe7e9089ab9f728eb8e0d0c62a5d18cf19239
  $ hg cp file cpfile
  $ hg mv file mvfile
  $ hg ci -m 'cpfile and mvfile'
  $ hg log -r . -T '{node}\n'
  c7ac39f638c6b39bcdacf868fa21b6195670f8ae
  $ hg push -r . --bundle-store
  pushing to ssh://user@dummy/repo
  searching for changes
  remote: pushing 4 commits:
  remote:     33910bfe6ffe  testpullbycommithash1
  remote:     d8fde0ddfc96  testpullbycommithash2
  remote:     3edfe7e9089a  add and rm files
  remote:     c7ac39f638c6  cpfile and mvfile
  $ cd ../repo
  $ hg debugfillinfinitepushmetadata --node 3edfe7e9089ab9f728eb8e0d0c62a5d18cf19239 --node c7ac39f638c6b39bcdacf868fa21b6195670f8ae
  $ cat .hg/scratchbranches/index/nodemetadatamap/3edfe7e9089ab9f728eb8e0d0c62a5d18cf19239
  {"changed_files": {"file": {"adds": 1, "isbinary": false, "removes": 0, "status": "added"}, "testpullbycommithash2": {"adds": 0, "isbinary": false, "removes": 1, "status": "removed"}}} (no-eol)
  $ cat .hg/scratchbranches/index/nodemetadatamap/c7ac39f638c6b39bcdacf868fa21b6195670f8ae
  {"changed_files": {"cpfile": {"adds": 1, "copies": "file", "isbinary": false, "removes": 0, "status": "added"}, "file": {"adds": 0, "isbinary": false, "removes": 1, "status": "removed"}, "mvfile": {"adds": 1, "copies": "file", "isbinary": false, "removes": 0, "status": "added"}}} (no-eol)

Test infinitepush.metadatafilelimit number
  $ cd ../client
  $ echo file > file
  $ hg add file
  $ echo file1 > file1
  $ hg add file1
  $ echo file2 > file2
  $ hg add file2
  $ hg ci -m 'add many files'
  $ hg log -r . -T '{node}'
  09904fb20c53ff351bd3b1d47681f569a4dab7e5 (no-eol)
  $ hg push -r . --bundle-store
  pushing to ssh://user@dummy/repo
  searching for changes
  remote: pushing 5 commits:
  remote:     33910bfe6ffe  testpullbycommithash1
  remote:     d8fde0ddfc96  testpullbycommithash2
  remote:     3edfe7e9089a  add and rm files
  remote:     c7ac39f638c6  cpfile and mvfile
  remote:     09904fb20c53  add many files

  $ cd ../repo
  $ hg debugfillinfinitepushmetadata --node 09904fb20c53ff351bd3b1d47681f569a4dab7e5 --config infinitepush.metadatafilelimit=2
  $ cat .hg/scratchbranches/index/nodemetadatamap/09904fb20c53ff351bd3b1d47681f569a4dab7e5
  {"changed_files": {"file": {"adds": 1, "isbinary": false, "removes": 0, "status": "added"}, "file1": {"adds": 1, "isbinary": false, "removes": 0, "status": "added"}}, "changed_files_truncated": true} (no-eol)

Test infinitepush.fillmetadatabranchpattern
  $ cd ../repo
  $ cat >> .hg/hgrc << EOF
  > [infinitepush]
  > fillmetadatabranchpattern=re:scratch/fillmetadata/.*
  > EOF
  $ cd ../client
  $ echo tofillmetadata > tofillmetadata
  $ hg ci -Aqm "tofillmetadata"
  $ hg log -r . -T '{node}\n'
  d2b0410d4da084bc534b1d90df0de9eb21583496
  $ hg push -r . -B scratch/fillmetadata/fill
  pushing to ssh://user@dummy/repo
  searching for changes
  remote: pushing 6 commits:
  remote:     33910bfe6ffe  testpullbycommithash1
  remote:     d8fde0ddfc96  testpullbycommithash2
  remote:     3edfe7e9089a  add and rm files
  remote:     c7ac39f638c6  cpfile and mvfile
  remote:     09904fb20c53  add many files
  remote:     d2b0410d4da0  tofillmetadata

Make sure background process finished
  $ sleep 3
  $ cd ../repo
  $ cat .hg/scratchbranches/index/nodemetadatamap/d2b0410d4da084bc534b1d90df0de9eb21583496
  {"changed_files": {"tofillmetadata": {"adds": 1, "isbinary": false, "removes": 0, "status": "added"}}} (no-eol)
