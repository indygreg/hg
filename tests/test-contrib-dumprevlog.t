#require reporevlogstore

  $ CONTRIBDIR="$TESTDIR/../contrib"

  $ hg init repo-a
  $ cd repo-a

  $ echo this is file a > a
  $ hg add a
  $ hg commit -m first

  $ echo adding to file a >> a
  $ hg commit -m second

  $ echo adding more to file a >> a
  $ hg commit -m third
  $ hg verify
  checking changesets
  checking manifests
  crosschecking files in changesets and manifests
  checking files
  checked 3 changesets with 3 changes to 1 files

Dumping revlog of file a to stdout:
  $ "$PYTHON" "$CONTRIBDIR/dumprevlog" .hg/store/data/a.i
  file: .hg/store/data/a.i
  node: 183d2312b35066fb6b3b449b84efc370d50993d0
  linkrev: 0
  parents: 0000000000000000000000000000000000000000 0000000000000000000000000000000000000000
  length: 15
  -start-
  this is file a
  
  -end-
  node: b1047953b6e6b633c0d8197eaa5116fbdfd3095b
  linkrev: 1
  parents: 183d2312b35066fb6b3b449b84efc370d50993d0 0000000000000000000000000000000000000000
  length: 32
  -start-
  this is file a
  adding to file a
  
  -end-
  node: 8c4fd1f7129b8cdec6c7f58bf48fb5237a4030c1
  linkrev: 2
  parents: b1047953b6e6b633c0d8197eaa5116fbdfd3095b 0000000000000000000000000000000000000000
  length: 54
  -start-
  this is file a
  adding to file a
  adding more to file a
  
  -end-

Dump all revlogs to file repo.dump:

  $ find .hg/store -name "*.i" | sort | xargs "$PYTHON" "$CONTRIBDIR/dumprevlog" > ../repo.dump
  $ cd ..

Undumping into repo-b:

  $ hg init repo-b
  $ cd repo-b
  $ "$PYTHON" "$CONTRIBDIR/undumprevlog" < ../repo.dump
  .hg/store/00changelog.i
  .hg/store/00manifest.i
  .hg/store/data/a.i
  $ cd ..

Rebuild fncache with clone --pull:

  $ hg clone --pull -U repo-b repo-c
  requesting all changes
  adding changesets
  adding manifests
  adding file changes
  added 3 changesets with 3 changes to 1 files
  new changesets de1da620e7d8:46946d278c50

Verify:

  $ hg -R repo-c verify
  checking changesets
  checking manifests
  crosschecking files in changesets and manifests
  checking files
  checked 3 changesets with 3 changes to 1 files

Compare repos:

  $ hg -R repo-c incoming repo-a
  comparing with repo-a
  searching for changes
  no changes found
  [1]

  $ hg -R repo-a incoming repo-c
  comparing with repo-c
  searching for changes
  no changes found
  [1]
