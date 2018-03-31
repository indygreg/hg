Testing the case when there is no infinitepush extension present on the client
side and the server routes each push to bundlestore. This case is very much
similar to CI use case.

Setup
-----

  $ . "$TESTDIR/library-infinitepush.sh"
  $ cat >> $HGRCPATH <<EOF
  > [alias]
  > glog = log -GT "{rev}:{node|short} {desc}\n{phase}"
  > EOF
  $ cp $HGRCPATH $TESTTMP/defaulthgrc
  $ hg init repo
  $ cd repo
  $ setupserver
  $ echo "pushtobundlestore = True" >> .hg/hgrc
  $ echo "[extensions]" >> .hg/hgrc
  $ echo "infinitepush=" >> .hg/hgrc
  $ echo initialcommit > initialcommit
  $ hg ci -Aqm "initialcommit"
  $ hg phase --public .

  $ cd ..
  $ hg clone repo client -q
  $ hg clone repo client2 -q
  $ cd client

Pushing a new commit from the client to the server
-----------------------------------------------------

  $ echo foobar > a
  $ hg ci -Aqm "added a"
  $ hg glog
  @  1:6cb0989601f1 added a
  |  draft
  o  0:67145f466344 initialcommit
     public

  $ hg push
  pushing to $TESTTMP/repo
  searching for changes
  storing changesets on the bundlestore
  pushing 1 commit:
      6cb0989601f1  added a

  $ scratchnodes
  6cb0989601f1fb5805238edfb16f3606713d9a0b a4c202c147a9c4bb91bbadb56321fc5f3950f7f2

Understanding how data is stored on the bundlestore in server
-------------------------------------------------------------

There are two things, filebundlestore and index
  $ ls ../repo/.hg/scratchbranches
  filebundlestore
  index

filebundlestore stores the bundles
  $ ls ../repo/.hg/scratchbranches/filebundlestore/a4/c2/
  a4c202c147a9c4bb91bbadb56321fc5f3950f7f2

index/nodemap stores a map of node id and file in which bundle is stored in filebundlestore
  $ ls ../repo/.hg/scratchbranches/index/
  nodemap
  $ ls ../repo/.hg/scratchbranches/index/nodemap/
  6cb0989601f1fb5805238edfb16f3606713d9a0b

  $ cd ../repo

Checking that the commit was not applied to revlog on the server
------------------------------------------------------------------

  $ hg glog
  @  0:67145f466344 initialcommit
     public

Applying the changeset from the bundlestore
--------------------------------------------

  $ hg unbundle .hg/scratchbranches/filebundlestore/a4/c2/a4c202c147a9c4bb91bbadb56321fc5f3950f7f2
  adding changesets
  adding manifests
  adding file changes
  added 1 changesets with 1 changes to 1 files
  new changesets 6cb0989601f1
  (run 'hg update' to get a working copy)

  $ hg glog
  o  1:6cb0989601f1 added a
  |  public
  @  0:67145f466344 initialcommit
     public

Pushing more changesets from the local repo
--------------------------------------------

  $ cd ../client
  $ echo b > b
  $ hg ci -Aqm "added b"
  $ echo c > c
  $ hg ci -Aqm "added c"
  $ hg glog
  @  3:bf8a6e3011b3 added c
  |  draft
  o  2:eaba929e866c added b
  |  draft
  o  1:6cb0989601f1 added a
  |  public
  o  0:67145f466344 initialcommit
     public

  $ hg push
  pushing to $TESTTMP/repo
  searching for changes
  storing changesets on the bundlestore
  pushing 2 commits:
      eaba929e866c  added b
      bf8a6e3011b3  added c

Checking that changesets are not applied on the server
------------------------------------------------------

  $ hg glog -R ../repo
  o  1:6cb0989601f1 added a
  |  public
  @  0:67145f466344 initialcommit
     public

Both of the new changesets are stored in a single bundle-file
  $ scratchnodes
  6cb0989601f1fb5805238edfb16f3606713d9a0b a4c202c147a9c4bb91bbadb56321fc5f3950f7f2
  bf8a6e3011b345146bbbedbcb1ebd4837571492a ee41a41cefb7817cbfb235b4f6e9f27dbad6ca1f
  eaba929e866c59bc9a6aada5a9dd2f6990db83c0 ee41a41cefb7817cbfb235b4f6e9f27dbad6ca1f

Pushing more changesets to the server
-------------------------------------

  $ echo d > d
  $ hg ci -Aqm "added d"
  $ echo e > e
  $ hg ci -Aqm "added e"

XXX: we should have pushed only the parts which are not in bundlestore
  $ hg push
  pushing to $TESTTMP/repo
  searching for changes
  storing changesets on the bundlestore
  pushing 4 commits:
      eaba929e866c  added b
      bf8a6e3011b3  added c
      1bb96358eda2  added d
      b4e4bce66051  added e

Sneak peek into the bundlestore at the server
  $ scratchnodes
  1bb96358eda285b536c6d1c66846a7cdb2336cea 57e00c0d4f26e2a2a72b751b63d9abc4f3eb28e7
  6cb0989601f1fb5805238edfb16f3606713d9a0b a4c202c147a9c4bb91bbadb56321fc5f3950f7f2
  b4e4bce660512ad3e71189e14588a70ac8e31fef 57e00c0d4f26e2a2a72b751b63d9abc4f3eb28e7
  bf8a6e3011b345146bbbedbcb1ebd4837571492a 57e00c0d4f26e2a2a72b751b63d9abc4f3eb28e7
  eaba929e866c59bc9a6aada5a9dd2f6990db83c0 57e00c0d4f26e2a2a72b751b63d9abc4f3eb28e7

Checking if `hg pull` pulls something or `hg incoming` shows something
-----------------------------------------------------------------------

  $ hg incoming
  comparing with $TESTTMP/repo
  searching for changes
  no changes found
  [1]

  $ hg pull
  pulling from $TESTTMP/repo
  searching for changes
  no changes found

Pulling from second client to test `hg pull -r <rev>`
------------------------------------------------------

Pulling the revision which is applied

  $ cd ../client2
  $ hg pull -r 6cb0989601f1
  pulling from $TESTTMP/repo
  searching for changes
  adding changesets
  adding manifests
  adding file changes
  added 1 changesets with 1 changes to 1 files
  new changesets 6cb0989601f1
  (run 'hg update' to get a working copy)
  $ hg glog
  o  1:6cb0989601f1 added a
  |  public
  @  0:67145f466344 initialcommit
     public

Pulling the revision which is in bundlestore
XXX: we should support pulling revisions from bundlestore without client side
wrapping

  $ hg pull -r b4e4bce660512ad3e71189e14588a70ac8e31fef
  pulling from $TESTTMP/repo
  abort: unknown revision 'b4e4bce660512ad3e71189e14588a70ac8e31fef'!
  [255]
  $ hg glog
  o  1:6cb0989601f1 added a
  |  public
  @  0:67145f466344 initialcommit
     public

  $ cd ../client

Checking storage of phase information with the bundle on bundlestore
---------------------------------------------------------------------

creating a draft commit
  $ cat >> $HGRCPATH <<EOF
  > [phases]
  > publish = False
  > EOF
  $ echo f > f
  $ hg ci -Aqm "added f"
  $ hg glog -r '.^::'
  @  6:9b42578d4447 added f
  |  draft
  o  5:b4e4bce66051 added e
  |  public
  ~

  $ hg push
  pushing to $TESTTMP/repo
  searching for changes
  storing changesets on the bundlestore
  pushing 5 commits:
      eaba929e866c  added b
      bf8a6e3011b3  added c
      1bb96358eda2  added d
      b4e4bce66051  added e
      9b42578d4447  added f

XXX: the phase of 9b42578d4447 should not be changed here
  $ hg glog -r .
  @  6:9b42578d4447 added f
  |  public
  ~

applying the bundle on the server to check preservation of phase-information

  $ cd ../repo
  $ scratchnodes
  1bb96358eda285b536c6d1c66846a7cdb2336cea 0a6e70ecd5b98d22382f69b93909f557ac6a9927
  6cb0989601f1fb5805238edfb16f3606713d9a0b a4c202c147a9c4bb91bbadb56321fc5f3950f7f2
  9b42578d44473575994109161430d65dd147d16d 0a6e70ecd5b98d22382f69b93909f557ac6a9927
  b4e4bce660512ad3e71189e14588a70ac8e31fef 0a6e70ecd5b98d22382f69b93909f557ac6a9927
  bf8a6e3011b345146bbbedbcb1ebd4837571492a 0a6e70ecd5b98d22382f69b93909f557ac6a9927
  eaba929e866c59bc9a6aada5a9dd2f6990db83c0 0a6e70ecd5b98d22382f69b93909f557ac6a9927

  $ hg unbundle .hg/scratchbranches/filebundlestore/0a/6e/0a6e70ecd5b98d22382f69b93909f557ac6a9927
  adding changesets
  adding manifests
  adding file changes
  added 5 changesets with 5 changes to 5 files
  new changesets eaba929e866c:9b42578d4447
  (run 'hg update' to get a working copy)

  $ hg glog
  o  6:9b42578d4447 added f
  |  draft
  o  5:b4e4bce66051 added e
  |  public
  o  4:1bb96358eda2 added d
  |  public
  o  3:bf8a6e3011b3 added c
  |  public
  o  2:eaba929e866c added b
  |  public
  o  1:6cb0989601f1 added a
  |  public
  @  0:67145f466344 initialcommit
     public

Checking storage of obsmarkers in the bundlestore
--------------------------------------------------

enabling obsmarkers and rebase extension

  $ cat >> $HGRCPATH << EOF
  > [experimental]
  > evolution = all
  > [extensions]
  > rebase =
  > EOF

  $ cd ../client

  $ hg phase -r . --draft --force
  $ hg rebase -r 6 -d 3
  rebasing 6:9b42578d4447 "added f" (tip)

  $ hg glog
  @  7:99949238d9ac added f
  |  draft
  | o  5:b4e4bce66051 added e
  | |  public
  | o  4:1bb96358eda2 added d
  |/   public
  o  3:bf8a6e3011b3 added c
  |  public
  o  2:eaba929e866c added b
  |  public
  o  1:6cb0989601f1 added a
  |  public
  o  0:67145f466344 initialcommit
     public

  $ hg push -f
  pushing to $TESTTMP/repo
  searching for changes
  storing changesets on the bundlestore
  pushing 1 commit:
      99949238d9ac  added f

XXX: the phase should not have changed here
  $ hg glog -r .
  @  7:99949238d9ac added f
  |  public
  ~

Unbundling on server to see obsmarkers being applied

  $ cd ../repo

  $ scratchnodes
  1bb96358eda285b536c6d1c66846a7cdb2336cea 0a6e70ecd5b98d22382f69b93909f557ac6a9927
  6cb0989601f1fb5805238edfb16f3606713d9a0b a4c202c147a9c4bb91bbadb56321fc5f3950f7f2
  99949238d9ac7f2424a33a46dface6f866afd059 090a24fe63f31d3b4bee714447f835c8c362ff57
  9b42578d44473575994109161430d65dd147d16d 0a6e70ecd5b98d22382f69b93909f557ac6a9927
  b4e4bce660512ad3e71189e14588a70ac8e31fef 0a6e70ecd5b98d22382f69b93909f557ac6a9927
  bf8a6e3011b345146bbbedbcb1ebd4837571492a 0a6e70ecd5b98d22382f69b93909f557ac6a9927
  eaba929e866c59bc9a6aada5a9dd2f6990db83c0 0a6e70ecd5b98d22382f69b93909f557ac6a9927

  $ hg glog
  o  6:9b42578d4447 added f
  |  draft
  o  5:b4e4bce66051 added e
  |  public
  o  4:1bb96358eda2 added d
  |  public
  o  3:bf8a6e3011b3 added c
  |  public
  o  2:eaba929e866c added b
  |  public
  o  1:6cb0989601f1 added a
  |  public
  @  0:67145f466344 initialcommit
     public

  $ hg unbundle .hg/scratchbranches/filebundlestore/09/0a/090a24fe63f31d3b4bee714447f835c8c362ff57
  adding changesets
  adding manifests
  adding file changes
  added 1 changesets with 0 changes to 1 files (+1 heads)
  1 new obsolescence markers
  obsoleted 1 changesets
  new changesets 99949238d9ac
  (run 'hg heads' to see heads, 'hg merge' to merge)

  $ hg glog
  o  7:99949238d9ac added f
  |  draft
  | o  5:b4e4bce66051 added e
  | |  public
  | o  4:1bb96358eda2 added d
  |/   public
  o  3:bf8a6e3011b3 added c
  |  public
  o  2:eaba929e866c added b
  |  public
  o  1:6cb0989601f1 added a
  |  public
  @  0:67145f466344 initialcommit
     public
