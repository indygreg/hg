#require no-reposimplestore

# Initial setup

  $ cat >> $HGRCPATH << EOF
  > [extensions]
  > lfs=
  > [lfs]
  > # Test deprecated config
  > threshold=1000B
  > EOF

  $ LONG=AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAABBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCC

# Prepare server and enable extension
  $ hg init server
  $ hg clone -q server client
  $ cd client

# Commit small file
  $ echo s > smallfile
  $ echo '**.py = LF' > .hgeol
  $ hg --config lfs.track='"size(\">1000B\")"' commit -Aqm "add small file"
  hg: parse error: unsupported file pattern: size(">1000B")
  (paths must be prefixed with "path:")
  [255]
  $ hg --config lfs.track='size(">1000B")' commit -Aqm "add small file"

# Commit large file
  $ echo $LONG > largefile
  $ grep lfs .hg/requires
  [1]
  $ hg commit --traceback -Aqm "add large file"
  $ grep lfs .hg/requires
  lfs

# Ensure metadata is stored
  $ hg debugdata largefile 0
  version https://git-lfs.github.com/spec/v1
  oid sha256:f11e77c257047a398492d8d6cb9f6acf3aa7c4384bb23080b43546053e183e4b
  size 1501
  x-is-binary 0

# Check the blobstore is populated
  $ find .hg/store/lfs/objects | sort
  .hg/store/lfs/objects
  .hg/store/lfs/objects/f1
  .hg/store/lfs/objects/f1/1e77c257047a398492d8d6cb9f6acf3aa7c4384bb23080b43546053e183e4b

# Check the blob stored contains the actual contents of the file
  $ cat .hg/store/lfs/objects/f1/1e77c257047a398492d8d6cb9f6acf3aa7c4384bb23080b43546053e183e4b
  AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAABBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCC

# Push changes to the server

  $ hg push
  pushing to $TESTTMP/server
  searching for changes
  abort: lfs.url needs to be configured
  [255]

  $ cat >> $HGRCPATH << EOF
  > [lfs]
  > url=file:$TESTTMP/dummy-remote/
  > EOF

Push to a local non-lfs repo with the extension enabled will add the
lfs requirement

  $ grep lfs $TESTTMP/server/.hg/requires
  [1]
  $ hg push -v | egrep -v '^(uncompressed| )'
  pushing to $TESTTMP/server
  searching for changes
  lfs: found f11e77c257047a398492d8d6cb9f6acf3aa7c4384bb23080b43546053e183e4b in the local lfs store
  2 changesets found
  adding changesets
  adding manifests
  adding file changes
  added 2 changesets with 3 changes to 3 files
  calling hook pretxnchangegroup.lfs: hgext.lfs.checkrequireslfs
  $ grep lfs $TESTTMP/server/.hg/requires
  lfs

# Unknown URL scheme

  $ hg push --config lfs.url=ftp://foobar
  abort: lfs: unknown url scheme: ftp
  [255]

  $ cd ../

# Initialize new client (not cloning) and setup extension
  $ hg init client2
  $ cd client2
  $ cat >> .hg/hgrc <<EOF
  > [paths]
  > default = $TESTTMP/server
  > EOF

# Pull from server

Pulling a local lfs repo into a local non-lfs repo with the extension
enabled adds the lfs requirement

  $ grep lfs .hg/requires $TESTTMP/server/.hg/requires
  $TESTTMP/server/.hg/requires:lfs
  $ hg pull default
  pulling from $TESTTMP/server
  requesting all changes
  adding changesets
  adding manifests
  adding file changes
  added 2 changesets with 3 changes to 3 files
  new changesets 0ead593177f7:b88141481348
  (run 'hg update' to get a working copy)
  $ grep lfs .hg/requires $TESTTMP/server/.hg/requires
  .hg/requires:lfs
  $TESTTMP/server/.hg/requires:lfs

# Check the blobstore is not yet populated
  $ [ -d .hg/store/lfs/objects ]
  [1]

# Update to the last revision containing the large file
  $ hg update
  3 files updated, 0 files merged, 0 files removed, 0 files unresolved

# Check the blobstore has been populated on update
  $ find .hg/store/lfs/objects | sort
  .hg/store/lfs/objects
  .hg/store/lfs/objects/f1
  .hg/store/lfs/objects/f1/1e77c257047a398492d8d6cb9f6acf3aa7c4384bb23080b43546053e183e4b

# Check the contents of the file are fetched from blobstore when requested
  $ hg cat -r . largefile
  AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAABBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCC

# Check the file has been copied in the working copy
  $ cat largefile
  AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAABBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCC

  $ cd ..

# Check rename, and switch between large and small files

  $ hg init repo3
  $ cd repo3
  $ cat >> .hg/hgrc << EOF
  > [lfs]
  > track=size(">10B")
  > EOF

  $ echo LONGER-THAN-TEN-BYTES-WILL-TRIGGER-LFS > large
  $ echo SHORTER > small
  $ hg add . -q
  $ hg commit -m 'commit with lfs content'

  $ hg files -r . 'set:added()'
  large
  small
  $ hg files -r . 'set:added() & lfs()'
  large

  $ hg mv large l
  $ hg mv small s
  $ hg status 'set:removed()'
  R large
  R small
  $ hg status 'set:removed() & lfs()'
  R large
  $ hg commit -m 'renames'

  $ hg files -r . 'set:copied()'
  l
  s
  $ hg files -r . 'set:copied() & lfs()'
  l
  $ hg status --change . 'set:removed()'
  R large
  R small
  $ hg status --change . 'set:removed() & lfs()'
  R large

  $ echo SHORT > l
  $ echo BECOME-LARGER-FROM-SHORTER > s
  $ hg commit -m 'large to small, small to large'

  $ echo 1 >> l
  $ echo 2 >> s
  $ hg commit -m 'random modifications'

  $ echo RESTORE-TO-BE-LARGE > l
  $ echo SHORTER > s
  $ hg commit -m 'switch large and small again'

# Test lfs_files template

  $ hg log -r 'all()' -T '{rev} {join(lfs_files, ", ")}\n'
  0 large
  1 l, large
  2 s
  3 s
  4 l

# Push and pull the above repo

  $ hg --cwd .. init repo4
  $ hg push ../repo4
  pushing to ../repo4
  searching for changes
  adding changesets
  adding manifests
  adding file changes
  added 5 changesets with 10 changes to 4 files

  $ hg --cwd .. init repo5
  $ hg --cwd ../repo5 pull ../repo3
  pulling from ../repo3
  requesting all changes
  adding changesets
  adding manifests
  adding file changes
  added 5 changesets with 10 changes to 4 files
  new changesets fd47a419c4f7:5adf850972b9
  (run 'hg update' to get a working copy)

  $ cd ..

# Test clone

  $ hg init repo6
  $ cd repo6
  $ cat >> .hg/hgrc << EOF
  > [lfs]
  > track=size(">30B")
  > EOF

  $ echo LARGE-BECAUSE-IT-IS-MORE-THAN-30-BYTES > large
  $ echo SMALL > small
  $ hg commit -Aqm 'create a lfs file' large small
  $ hg debuglfsupload -r 'all()' -v
  lfs: found 8e92251415339ae9b148c8da89ed5ec665905166a1ab11b09dca8fad83344738 in the local lfs store

  $ cd ..

  $ hg clone repo6 repo7
  updating to branch default
  2 files updated, 0 files merged, 0 files removed, 0 files unresolved
  $ cd repo7
  $ hg config extensions --debug | grep lfs
  $TESTTMP/repo7/.hg/hgrc:*: extensions.lfs= (glob)
  $ cat large
  LARGE-BECAUSE-IT-IS-MORE-THAN-30-BYTES
  $ cat small
  SMALL

  $ cd ..

  $ hg --config extensions.share= share repo7 sharedrepo
  updating working directory
  2 files updated, 0 files merged, 0 files removed, 0 files unresolved
  $ hg -R sharedrepo config extensions --debug | grep lfs
  $TESTTMP/sharedrepo/.hg/hgrc:*: extensions.lfs= (glob)

# Test rename and status

  $ hg init repo8
  $ cd repo8
  $ cat >> .hg/hgrc << EOF
  > [lfs]
  > track=size(">10B")
  > EOF

  $ echo THIS-IS-LFS-BECAUSE-10-BYTES > a1
  $ echo SMALL > a2
  $ hg commit -m a -A a1 a2
  $ hg status
  $ hg mv a1 b1
  $ hg mv a2 a1
  $ hg mv b1 a2
  $ hg commit -m b
  $ hg status
  >>> with open('a2', 'wb') as f:
  ...     f.write(b'\1\nSTART-WITH-HG-FILELOG-METADATA')
  >>> with open('a1', 'wb') as f:
  ...     f.write(b'\1\nMETA\n')
  $ hg commit -m meta
  $ hg status
  $ hg log -T '{rev}: {file_copies} | {file_dels} | {file_adds}\n'
  2:  |  | 
  1: a1 (a2)a2 (a1) |  | 
  0:  |  | a1 a2

  $ for n in a1 a2; do
  >   for r in 0 1 2; do
  >     printf '\n%s @ %s\n' $n $r
  >     hg debugdata $n $r
  >   done
  > done
  
  a1 @ 0
  version https://git-lfs.github.com/spec/v1
  oid sha256:5bb8341bee63b3649f222b2215bde37322bea075a30575aa685d8f8d21c77024
  size 29
  x-is-binary 0
  
  a1 @ 1
  \x01 (esc)
  copy: a2
  copyrev: 50470ad23cf937b1f4b9f80bfe54df38e65b50d9
  \x01 (esc)
  SMALL
  
  a1 @ 2
  \x01 (esc)
  \x01 (esc)
  \x01 (esc)
  META
  
  a2 @ 0
  SMALL
  
  a2 @ 1
  version https://git-lfs.github.com/spec/v1
  oid sha256:5bb8341bee63b3649f222b2215bde37322bea075a30575aa685d8f8d21c77024
  size 29
  x-hg-copy a1
  x-hg-copyrev be23af27908a582af43e5cda209a5a9b319de8d4
  x-is-binary 0
  
  a2 @ 2
  version https://git-lfs.github.com/spec/v1
  oid sha256:876dadc86a8542f9798048f2c47f51dbf8e4359aed883e8ec80c5db825f0d943
  size 32
  x-is-binary 0

# Verify commit hashes include rename metadata

  $ hg log -T '{rev}:{node|short} {desc}\n'
  2:0fae949de7fa meta
  1:9cd6bdffdac0 b
  0:7f96794915f7 a

  $ cd ..

# Test bundle

  $ hg init repo9
  $ cd repo9
  $ cat >> .hg/hgrc << EOF
  > [lfs]
  > track=size(">10B")
  > [diff]
  > git=1
  > EOF

  $ for i in 0 single two three 4; do
  >   echo 'THIS-IS-LFS-'$i > a
  >   hg commit -m a-$i -A a
  > done

  $ hg update 2 -q
  $ echo 'THIS-IS-LFS-2-CHILD' > a
  $ hg commit -m branching -q

  $ hg bundle --base 1 bundle.hg -v
  lfs: found 5ab7a3739a5feec94a562d070a14f36dba7cad17e5484a4a89eea8e5f3166888 in the local lfs store
  lfs: found a9c7d1cd6ce2b9bbdf46ed9a862845228717b921c089d0d42e3bcaed29eb612e in the local lfs store
  lfs: found f693890c49c409ec33673b71e53f297681f76c1166daf33b2ad7ebf8b1d3237e in the local lfs store
  lfs: found fda198fea753eb66a252e9856915e1f5cddbe41723bd4b695ece2604ad3c9f75 in the local lfs store
  4 changesets found
  uncompressed size of bundle content:
       * (changelog) (glob)
       * (manifests) (glob)
      * a (glob)
  $ hg --config extensions.strip= strip -r 2 --no-backup --force -q
  $ hg -R bundle.hg log -p -T '{rev} {desc}\n' a
  5 branching
  diff --git a/a b/a
  --- a/a
  +++ b/a
  @@ -1,1 +1,1 @@
  -THIS-IS-LFS-two
  +THIS-IS-LFS-2-CHILD
  
  4 a-4
  diff --git a/a b/a
  --- a/a
  +++ b/a
  @@ -1,1 +1,1 @@
  -THIS-IS-LFS-three
  +THIS-IS-LFS-4
  
  3 a-three
  diff --git a/a b/a
  --- a/a
  +++ b/a
  @@ -1,1 +1,1 @@
  -THIS-IS-LFS-two
  +THIS-IS-LFS-three
  
  2 a-two
  diff --git a/a b/a
  --- a/a
  +++ b/a
  @@ -1,1 +1,1 @@
  -THIS-IS-LFS-single
  +THIS-IS-LFS-two
  
  1 a-single
  diff --git a/a b/a
  --- a/a
  +++ b/a
  @@ -1,1 +1,1 @@
  -THIS-IS-LFS-0
  +THIS-IS-LFS-single
  
  0 a-0
  diff --git a/a b/a
  new file mode 100644
  --- /dev/null
  +++ b/a
  @@ -0,0 +1,1 @@
  +THIS-IS-LFS-0
  
  $ hg bundle -R bundle.hg --base 1 bundle-again.hg -q
  $ hg -R bundle-again.hg log -p -T '{rev} {desc}\n' a
  5 branching
  diff --git a/a b/a
  --- a/a
  +++ b/a
  @@ -1,1 +1,1 @@
  -THIS-IS-LFS-two
  +THIS-IS-LFS-2-CHILD
  
  4 a-4
  diff --git a/a b/a
  --- a/a
  +++ b/a
  @@ -1,1 +1,1 @@
  -THIS-IS-LFS-three
  +THIS-IS-LFS-4
  
  3 a-three
  diff --git a/a b/a
  --- a/a
  +++ b/a
  @@ -1,1 +1,1 @@
  -THIS-IS-LFS-two
  +THIS-IS-LFS-three
  
  2 a-two
  diff --git a/a b/a
  --- a/a
  +++ b/a
  @@ -1,1 +1,1 @@
  -THIS-IS-LFS-single
  +THIS-IS-LFS-two
  
  1 a-single
  diff --git a/a b/a
  --- a/a
  +++ b/a
  @@ -1,1 +1,1 @@
  -THIS-IS-LFS-0
  +THIS-IS-LFS-single
  
  0 a-0
  diff --git a/a b/a
  new file mode 100644
  --- /dev/null
  +++ b/a
  @@ -0,0 +1,1 @@
  +THIS-IS-LFS-0
  
  $ cd ..

# Test isbinary

  $ hg init repo10
  $ cd repo10
  $ cat >> .hg/hgrc << EOF
  > [extensions]
  > lfs=
  > [lfs]
  > track=all()
  > EOF
  $ $PYTHON <<'EOF'
  > def write(path, content):
  >     with open(path, 'wb') as f:
  >         f.write(content)
  > write('a', b'\0\0')
  > write('b', b'\1\n')
  > write('c', b'\1\n\0')
  > write('d', b'xx')
  > EOF
  $ hg add a b c d
  $ hg diff --stat
   a |  Bin 
   b |    1 +
   c |  Bin 
   d |    1 +
   4 files changed, 2 insertions(+), 0 deletions(-)
  $ hg commit -m binarytest
  $ cat > $TESTTMP/dumpbinary.py << EOF
  > def reposetup(ui, repo):
  >     for n in 'abcd':
  >         ui.write(('%s: binary=%s\n') % (n, repo['.'][n].isbinary()))
  > EOF
  $ hg --config extensions.dumpbinary=$TESTTMP/dumpbinary.py id --trace
  a: binary=True
  b: binary=False
  c: binary=True
  d: binary=False
  b55353847f02 tip

  $ cd ..

# Test fctx.cmp fastpath - diff without LFS blobs

  $ hg init repo12
  $ cd repo12
  $ cat >> .hg/hgrc <<EOF
  > [lfs]
  > threshold=1
  > EOF
  $ cat > ../patch.diff <<EOF
  > # HG changeset patch
  > 2
  > 
  > diff --git a/a b/a
  > old mode 100644
  > new mode 100755
  > EOF

  $ for i in 1 2 3; do
  >     cp ../repo10/a a
  >     if [ $i = 3 ]; then
  >         # make a content-only change
  >         hg import -q --bypass ../patch.diff
  >         hg update -q
  >         rm ../patch.diff
  >     else
  >         echo $i >> a
  >         hg commit -m $i -A a
  >     fi
  > done
  $ [ -d .hg/store/lfs/objects ]

  $ cd ..

  $ hg clone repo12 repo13 --noupdate
  $ cd repo13
  $ hg log --removed -p a -T '{desc}\n' --config diff.nobinary=1 --git
  2
  diff --git a/a b/a
  old mode 100644
  new mode 100755
  
  2
  diff --git a/a b/a
  Binary file a has changed
  
  1
  diff --git a/a b/a
  new file mode 100644
  Binary file a has changed
  
  $ [ -d .hg/store/lfs/objects ]
  [1]

  $ cd ..

# Test filter

  $ hg init repo11
  $ cd repo11
  $ cat >> .hg/hgrc << EOF
  > [lfs]
  > track=(**.a & size(">5B")) | (**.b & !size(">5B"))
  >      | (**.c & "path:d" & !"path:d/c.c") | size(">10B")
  > EOF

  $ mkdir a
  $ echo aaaaaa > a/1.a
  $ echo a > a/2.a
  $ echo aaaaaa > 1.b
  $ echo a > 2.b
  $ echo a > 1.c
  $ mkdir d
  $ echo a > d/c.c
  $ echo a > d/d.c
  $ echo aaaaaaaaaaaa > x
  $ hg add . -q
  $ hg commit -m files

  $ for p in a/1.a a/2.a 1.b 2.b 1.c d/c.c d/d.c x; do
  >   if hg debugdata $p 0 2>&1 | grep git-lfs >/dev/null; then
  >     echo "${p}: is lfs"
  >   else
  >     echo "${p}: not lfs"
  >   fi
  > done
  a/1.a: is lfs
  a/2.a: not lfs
  1.b: not lfs
  2.b: is lfs
  1.c: not lfs
  d/c.c: not lfs
  d/d.c: is lfs
  x: is lfs

  $ cd ..

# Verify the repos

  $ cat > $TESTTMP/dumpflog.py << EOF
  > # print raw revision sizes, flags, and hashes for certain files
  > import hashlib
  > from mercurial.node import short
  > from mercurial import revlog
  > def hash(rawtext):
  >     h = hashlib.sha512()
  >     h.update(rawtext)
  >     return h.hexdigest()[:4]
  > def reposetup(ui, repo):
  >     # these 2 files are interesting
  >     for name in ['l', 's']:
  >         fl = repo.file(name)
  >         if len(fl) == 0:
  >             continue
  >         sizes = [revlog.revlog.rawsize(fl, i) for i in fl]
  >         texts = [fl.revision(i, raw=True) for i in fl]
  >         flags = [int(fl.flags(i)) for i in fl]
  >         hashes = [hash(t) for t in texts]
  >         print('  %s: rawsizes=%r flags=%r hashes=%r'
  >               % (name, sizes, flags, hashes))
  > EOF

  $ for i in client client2 server repo3 repo4 repo5 repo6 repo7 repo8 repo9 \
  >          repo10; do
  >   echo 'repo:' $i
  >   hg --cwd $i verify --config extensions.dumpflog=$TESTTMP/dumpflog.py -q
  > done
  repo: client
  repo: client2
  repo: server
  repo: repo3
    l: rawsizes=[211, 6, 8, 141] flags=[8192, 0, 0, 8192] hashes=['d2b8', '948c', 'cc88', '724d']
    s: rawsizes=[74, 141, 141, 8] flags=[0, 8192, 8192, 0] hashes=['3c80', 'fce0', '874a', '826b']
  repo: repo4
    l: rawsizes=[211, 6, 8, 141] flags=[8192, 0, 0, 8192] hashes=['d2b8', '948c', 'cc88', '724d']
    s: rawsizes=[74, 141, 141, 8] flags=[0, 8192, 8192, 0] hashes=['3c80', 'fce0', '874a', '826b']
  repo: repo5
    l: rawsizes=[211, 6, 8, 141] flags=[8192, 0, 0, 8192] hashes=['d2b8', '948c', 'cc88', '724d']
    s: rawsizes=[74, 141, 141, 8] flags=[0, 8192, 8192, 0] hashes=['3c80', 'fce0', '874a', '826b']
  repo: repo6
  repo: repo7
  repo: repo8
  repo: repo9
  repo: repo10

repo13 doesn't have any cached lfs files and its source never pushed its
files.  Therefore, the files don't exist in the remote store.  Use the files in
the user cache.

  $ test -d $TESTTMP/repo13/.hg/store/lfs/objects
  [1]

  $ hg --config extensions.share= share repo13 repo14
  updating working directory
  1 files updated, 0 files merged, 0 files removed, 0 files unresolved
  $ hg -R repo14 -q verify

  $ hg clone repo13 repo15
  updating to branch default
  1 files updated, 0 files merged, 0 files removed, 0 files unresolved
  $ hg -R repo15 -q verify

If the source repo doesn't have the blob (maybe it was pulled or cloned with
--noupdate), the blob is still accessible via the global cache to send to the
remote store.

  $ rm -rf $TESTTMP/repo15/.hg/store/lfs
  $ hg init repo16
  $ hg -R repo15 push repo16
  pushing to repo16
  searching for changes
  adding changesets
  adding manifests
  adding file changes
  added 3 changesets with 2 changes to 1 files
  $ hg -R repo15 -q verify

Test damaged file scenarios.  (This also damages the usercache because of the
hardlinks.)

  $ echo 'damage' >> repo5/.hg/store/lfs/objects/66/100b384bf761271b407d79fc30cdd0554f3b2c5d944836e936d584b88ce88e

Repo with damaged lfs objects in any revision will fail verification.

  $ hg -R repo5 verify
  checking changesets
  checking manifests
  crosschecking files in changesets and manifests
  checking files
   l@1: unpacking 46a2f24864bc: integrity check failed on data/l.i:0
   large@0: unpacking 2c531e0992ff: integrity check failed on data/large.i:0
  4 files, 5 changesets, 10 total revisions
  2 integrity errors encountered!
  (first damaged changeset appears to be 0)
  [1]

Updates work after cloning a damaged repo, if the damaged lfs objects aren't in
the update destination.  Those objects won't be added to the new repo's store
because they aren't accessed.

  $ hg clone -v repo5 fromcorrupt
  updating to branch default
  resolving manifests
  getting l
  lfs: found 22f66a3fc0b9bf3f012c814303995ec07099b3a9ce02a7af84b5970811074a3b in the usercache
  getting s
  2 files updated, 0 files merged, 0 files removed, 0 files unresolved
  $ test -f fromcorrupt/.hg/store/lfs/objects/66/100b384bf761271b407d79fc30cdd0554f3b2c5d944836e936d584b88ce88e
  [1]

Verify will copy/link all lfs objects into the local store that aren't already
present.  Bypass the corrupted usercache to show that verify works when fed by
the (uncorrupted) remote store.

  $ hg -R fromcorrupt --config lfs.usercache=emptycache verify -v
  repository uses revlog format 1
  checking changesets
  checking manifests
  crosschecking files in changesets and manifests
  checking files
  lfs: adding 66100b384bf761271b407d79fc30cdd0554f3b2c5d944836e936d584b88ce88e to the usercache
  lfs: found 66100b384bf761271b407d79fc30cdd0554f3b2c5d944836e936d584b88ce88e in the local lfs store
  lfs: found 22f66a3fc0b9bf3f012c814303995ec07099b3a9ce02a7af84b5970811074a3b in the local lfs store
  lfs: found 66100b384bf761271b407d79fc30cdd0554f3b2c5d944836e936d584b88ce88e in the local lfs store
  lfs: adding 89b6070915a3d573ff3599d1cda305bc5e38549b15c4847ab034169da66e1ca8 to the usercache
  lfs: found 89b6070915a3d573ff3599d1cda305bc5e38549b15c4847ab034169da66e1ca8 in the local lfs store
  lfs: adding b1a6ea88da0017a0e77db139a54618986e9a2489bee24af9fe596de9daac498c to the usercache
  lfs: found b1a6ea88da0017a0e77db139a54618986e9a2489bee24af9fe596de9daac498c in the local lfs store
  4 files, 5 changesets, 10 total revisions

Verify will not copy/link a corrupted file from the usercache into the local
store, and poison it.  (The verify with a good remote now works.)

  $ rm -r fromcorrupt/.hg/store/lfs/objects/66/100b384bf761271b407d79fc30cdd0554f3b2c5d944836e936d584b88ce88e
  $ hg -R fromcorrupt verify -v
  repository uses revlog format 1
  checking changesets
  checking manifests
  crosschecking files in changesets and manifests
  checking files
   l@1: unpacking 46a2f24864bc: integrity check failed on data/l.i:0
  lfs: found 22f66a3fc0b9bf3f012c814303995ec07099b3a9ce02a7af84b5970811074a3b in the local lfs store
   large@0: unpacking 2c531e0992ff: integrity check failed on data/large.i:0
  lfs: found 89b6070915a3d573ff3599d1cda305bc5e38549b15c4847ab034169da66e1ca8 in the local lfs store
  lfs: found b1a6ea88da0017a0e77db139a54618986e9a2489bee24af9fe596de9daac498c in the local lfs store
  4 files, 5 changesets, 10 total revisions
  2 integrity errors encountered!
  (first damaged changeset appears to be 0)
  [1]
  $ hg -R fromcorrupt --config lfs.usercache=emptycache verify -v
  repository uses revlog format 1
  checking changesets
  checking manifests
  crosschecking files in changesets and manifests
  checking files
  lfs: found 66100b384bf761271b407d79fc30cdd0554f3b2c5d944836e936d584b88ce88e in the usercache
  lfs: found 22f66a3fc0b9bf3f012c814303995ec07099b3a9ce02a7af84b5970811074a3b in the local lfs store
  lfs: found 66100b384bf761271b407d79fc30cdd0554f3b2c5d944836e936d584b88ce88e in the local lfs store
  lfs: found 89b6070915a3d573ff3599d1cda305bc5e38549b15c4847ab034169da66e1ca8 in the local lfs store
  lfs: found b1a6ea88da0017a0e77db139a54618986e9a2489bee24af9fe596de9daac498c in the local lfs store
  4 files, 5 changesets, 10 total revisions

Damaging a file required by the update destination fails the update.

  $ echo 'damage' >> $TESTTMP/dummy-remote/22/f66a3fc0b9bf3f012c814303995ec07099b3a9ce02a7af84b5970811074a3b
  $ hg --config lfs.usercache=emptycache clone -v repo5 fromcorrupt2
  updating to branch default
  resolving manifests
  abort: corrupt remote lfs object: 22f66a3fc0b9bf3f012c814303995ec07099b3a9ce02a7af84b5970811074a3b
  [255]

A corrupted lfs blob is not transferred from a file://remotestore to the
usercache or local store.

  $ test -f emptycache/22/f66a3fc0b9bf3f012c814303995ec07099b3a9ce02a7af84b5970811074a3b
  [1]
  $ test -f fromcorrupt2/.hg/store/lfs/objects/22/f66a3fc0b9bf3f012c814303995ec07099b3a9ce02a7af84b5970811074a3b
  [1]

  $ hg -R fromcorrupt2 verify
  checking changesets
  checking manifests
  crosschecking files in changesets and manifests
  checking files
   l@1: unpacking 46a2f24864bc: integrity check failed on data/l.i:0
   large@0: unpacking 2c531e0992ff: integrity check failed on data/large.i:0
  4 files, 5 changesets, 10 total revisions
  2 integrity errors encountered!
  (first damaged changeset appears to be 0)
  [1]

Corrupt local files are not sent upstream.  (The alternate dummy remote
avoids the corrupt lfs object in the original remote.)

  $ mkdir $TESTTMP/dummy-remote2
  $ hg init dest
  $ hg -R fromcorrupt2 --config lfs.url=file:///$TESTTMP/dummy-remote2 push -v dest
  pushing to dest
  searching for changes
  lfs: found 22f66a3fc0b9bf3f012c814303995ec07099b3a9ce02a7af84b5970811074a3b in the local lfs store
  lfs: found 89b6070915a3d573ff3599d1cda305bc5e38549b15c4847ab034169da66e1ca8 in the local lfs store
  lfs: found b1a6ea88da0017a0e77db139a54618986e9a2489bee24af9fe596de9daac498c in the local lfs store
  abort: detected corrupt lfs object: 66100b384bf761271b407d79fc30cdd0554f3b2c5d944836e936d584b88ce88e
  (run hg verify)
  [255]

  $ hg -R fromcorrupt2 --config lfs.url=file:///$TESTTMP/dummy-remote2 verify -v
  repository uses revlog format 1
  checking changesets
  checking manifests
  crosschecking files in changesets and manifests
  checking files
   l@1: unpacking 46a2f24864bc: integrity check failed on data/l.i:0
  lfs: found 22f66a3fc0b9bf3f012c814303995ec07099b3a9ce02a7af84b5970811074a3b in the local lfs store
   large@0: unpacking 2c531e0992ff: integrity check failed on data/large.i:0
  lfs: found 89b6070915a3d573ff3599d1cda305bc5e38549b15c4847ab034169da66e1ca8 in the local lfs store
  lfs: found b1a6ea88da0017a0e77db139a54618986e9a2489bee24af9fe596de9daac498c in the local lfs store
  4 files, 5 changesets, 10 total revisions
  2 integrity errors encountered!
  (first damaged changeset appears to be 0)
  [1]

  $ cat $TESTTMP/dummy-remote2/22/f66a3fc0b9bf3f012c814303995ec07099b3a9ce02a7af84b5970811074a3b | $TESTDIR/f --sha256
  sha256=22f66a3fc0b9bf3f012c814303995ec07099b3a9ce02a7af84b5970811074a3b
  $ cat fromcorrupt2/.hg/store/lfs/objects/22/f66a3fc0b9bf3f012c814303995ec07099b3a9ce02a7af84b5970811074a3b | $TESTDIR/f --sha256
  sha256=22f66a3fc0b9bf3f012c814303995ec07099b3a9ce02a7af84b5970811074a3b
  $ test -f $TESTTMP/dummy-remote2/66/100b384bf761271b407d79fc30cdd0554f3b2c5d944836e936d584b88ce88e
  [1]

Accessing a corrupt file will complain

  $ hg --cwd fromcorrupt2 cat -r 0 large
  abort: integrity check failed on data/large.i:0!
  [255]

lfs -> normal -> lfs round trip conversions are possible.  The 'none()'
predicate on the command line will override whatever is configured globally and
locally, and ensures everything converts to a regular file.  For lfs -> normal,
there's no 'lfs' destination repo requirement.  For normal -> lfs, there is.

  $ hg --config extensions.convert= --config 'lfs.track=none()' \
  >    convert repo8 convert_normal
  initializing destination convert_normal repository
  scanning source...
  sorting...
  converting...
  2 a
  1 b
  0 meta
  $ grep 'lfs' convert_normal/.hg/requires
  [1]
  $ hg --cwd convert_normal cat a1 -r 0 -T '{rawdata}'
  THIS-IS-LFS-BECAUSE-10-BYTES

  $ hg --config extensions.convert= --config lfs.threshold=10B \
  >    convert convert_normal convert_lfs
  initializing destination convert_lfs repository
  scanning source...
  sorting...
  converting...
  2 a
  1 b
  0 meta

  $ hg --cwd convert_lfs cat -r 0 a1 -T '{rawdata}'
  version https://git-lfs.github.com/spec/v1
  oid sha256:5bb8341bee63b3649f222b2215bde37322bea075a30575aa685d8f8d21c77024
  size 29
  x-is-binary 0
  $ hg --cwd convert_lfs debugdata a1 0
  version https://git-lfs.github.com/spec/v1
  oid sha256:5bb8341bee63b3649f222b2215bde37322bea075a30575aa685d8f8d21c77024
  size 29
  x-is-binary 0
  $ hg --cwd convert_lfs log -r 0 -T "{lfs_files % '{lfspointer % '{key}={value}\n'}'}"
  version=https://git-lfs.github.com/spec/v1
  oid=sha256:5bb8341bee63b3649f222b2215bde37322bea075a30575aa685d8f8d21c77024
  size=29
  x-is-binary=0
  $ hg --cwd convert_lfs log -r 0 \
  >    -T '{lfs_files % "{get(lfspointer, "oid")}\n"}{lfs_files % "{lfspointer.oid}\n"}'
  sha256:5bb8341bee63b3649f222b2215bde37322bea075a30575aa685d8f8d21c77024
  sha256:5bb8341bee63b3649f222b2215bde37322bea075a30575aa685d8f8d21c77024
  $ hg --cwd convert_lfs log -r 0 -T '{lfs_files % "{lfspointer}\n"}'
  version=https://git-lfs.github.com/spec/v1 oid=sha256:5bb8341bee63b3649f222b2215bde37322bea075a30575aa685d8f8d21c77024 size=29 x-is-binary=0
  $ hg --cwd convert_lfs \
  >     log -r 'all()' -T '{rev}: {lfs_files % "{file}: {lfsoid}\n"}'
  0: a1: 5bb8341bee63b3649f222b2215bde37322bea075a30575aa685d8f8d21c77024
  1: a2: 5bb8341bee63b3649f222b2215bde37322bea075a30575aa685d8f8d21c77024
  2: a2: 876dadc86a8542f9798048f2c47f51dbf8e4359aed883e8ec80c5db825f0d943

  $ grep 'lfs' convert_lfs/.hg/requires
  lfs

The hashes in all stages of the conversion are unchanged.

  $ hg -R repo8 log -T '{node|short}\n'
  0fae949de7fa
  9cd6bdffdac0
  7f96794915f7
  $ hg -R convert_normal log -T '{node|short}\n'
  0fae949de7fa
  9cd6bdffdac0
  7f96794915f7
  $ hg -R convert_lfs log -T '{node|short}\n'
  0fae949de7fa
  9cd6bdffdac0
  7f96794915f7

This convert is trickier, because it contains deleted files (via `hg mv`)

  $ hg --config extensions.convert= --config lfs.threshold=1000M \
  >    convert repo3 convert_normal2
  initializing destination convert_normal2 repository
  scanning source...
  sorting...
  converting...
  4 commit with lfs content
  3 renames
  2 large to small, small to large
  1 random modifications
  0 switch large and small again
  $ grep 'lfs' convert_normal2/.hg/requires
  [1]
  $ hg --cwd convert_normal2 debugdata large 0
  LONGER-THAN-TEN-BYTES-WILL-TRIGGER-LFS

  $ hg --config extensions.convert= --config lfs.threshold=10B \
  >    convert convert_normal2 convert_lfs2
  initializing destination convert_lfs2 repository
  scanning source...
  sorting...
  converting...
  4 commit with lfs content
  3 renames
  2 large to small, small to large
  1 random modifications
  0 switch large and small again
  $ grep 'lfs' convert_lfs2/.hg/requires
  lfs
  $ hg --cwd convert_lfs2 debugdata large 0
  version https://git-lfs.github.com/spec/v1
  oid sha256:66100b384bf761271b407d79fc30cdd0554f3b2c5d944836e936d584b88ce88e
  size 39
  x-is-binary 0

  $ hg -R convert_lfs2 config --debug extensions | grep lfs
  $TESTTMP/convert_lfs2/.hg/hgrc:*: extensions.lfs= (glob)

Committing deleted files works:

  $ hg init $TESTTMP/repo-del
  $ cd $TESTTMP/repo-del
  $ echo 1 > A
  $ hg commit -m 'add A' -A A
  $ hg rm A
  $ hg commit -m 'rm A'

Bad .hglfs files will block the commit with a useful message

  $ cat > .hglfs << EOF
  > [track]
  > **.test = size(">5B")
  > bad file ... no commit
  > EOF

  $ echo x > file.txt
  $ hg ci -Aqm 'should fail'
  hg: parse error at .hglfs:3: bad file ... no commit
  [255]

  $ cat > .hglfs << EOF
  > [track]
  > **.test = size(">5B")
  > ** = nonexistent()
  > EOF

  $ hg ci -Aqm 'should fail'
  abort: parse error in .hglfs: unknown identifier: nonexistent
  [255]

'**' works out to mean all files.

  $ cat > .hglfs << EOF
  > [track]
  > path:.hglfs = none()
  > **.test = size(">5B")
  > **.exclude = none()
  > ** = size(">10B")
  > EOF

The LFS policy takes effect without tracking the .hglfs file

  $ echo 'largefile' > lfs.test
  $ echo '012345678901234567890' > nolfs.exclude
  $ echo '01234567890123456' > lfs.catchall
  $ hg add *
  $ hg ci -qm 'before add .hglfs'
  $ hg log -r . -T '{rev}: {lfs_files % "{file}: {lfsoid}\n"}\n'
  2: lfs.catchall: d4ec46c2869ba22eceb42a729377432052d9dd75d82fc40390ebaadecee87ee9
  lfs.test: 5489e6ced8c36a7b267292bde9fd5242a5f80a7482e8f23fa0477393dfaa4d6c
  
The .hglfs file works when tracked

  $ echo 'largefile2' > lfs.test
  $ echo '012345678901234567890a' > nolfs.exclude
  $ echo '01234567890123456a' > lfs.catchall
  $ hg ci -Aqm 'after adding .hglfs'
  $ hg log -r . -T '{rev}: {lfs_files % "{file}: {lfsoid}\n"}\n'
  3: lfs.catchall: 31f43b9c62b540126b0ad5884dc013d21a61c9329b77de1fceeae2fc58511573
  lfs.test: 8acd23467967bc7b8cc5a280056589b0ba0b17ff21dbd88a7b6474d6290378a6
  
The LFS policy stops when the .hglfs is gone

  $ mv .hglfs .hglfs_
  $ echo 'largefile3' > lfs.test
  $ echo '012345678901234567890abc' > nolfs.exclude
  $ echo '01234567890123456abc' > lfs.catchall
  $ hg ci -qm 'file test' -X .hglfs
  $ hg log -r . -T '{rev}: {lfs_files % "{file}: {lfsoid}\n"}\n'
  4: 

  $ mv .hglfs_ .hglfs
  $ echo '012345678901234567890abc' > lfs.test
  $ hg ci -m 'back to lfs'
  $ hg rm lfs.test
  $ hg ci -qm 'remove lfs'

{lfs_files} will list deleted files too

  $ hg log -T "{lfs_files % '{rev} {file}: {lfspointer.oid}\n'}"
  6 lfs.test: 
  5 lfs.test: sha256:43f8f41171b6f62a6b61ba4ce98a8a6c1649240a47ebafd43120aa215ac9e7f6
  3 lfs.catchall: sha256:31f43b9c62b540126b0ad5884dc013d21a61c9329b77de1fceeae2fc58511573
  3 lfs.test: sha256:8acd23467967bc7b8cc5a280056589b0ba0b17ff21dbd88a7b6474d6290378a6
  2 lfs.catchall: sha256:d4ec46c2869ba22eceb42a729377432052d9dd75d82fc40390ebaadecee87ee9
  2 lfs.test: sha256:5489e6ced8c36a7b267292bde9fd5242a5f80a7482e8f23fa0477393dfaa4d6c

  $ hg log -r 'file("set:lfs()")' -T '{rev} {join(lfs_files, ", ")}\n'
  2 lfs.catchall, lfs.test
  3 lfs.catchall, lfs.test
  5 lfs.test
  6 lfs.test

  $ cd ..

Unbundling adds a requirement to a non-lfs repo, if necessary.

  $ hg bundle -R $TESTTMP/repo-del -qr 0 --base null nolfs.hg
  $ hg bundle -R convert_lfs2 -qr tip --base null lfs.hg
  $ hg init unbundle
  $ hg pull -R unbundle -q nolfs.hg
  $ grep lfs unbundle/.hg/requires
  [1]
  $ hg pull -R unbundle -q lfs.hg
  $ grep lfs unbundle/.hg/requires
  lfs

  $ hg init no_lfs
  $ cat >> no_lfs/.hg/hgrc <<EOF
  > [experimental]
  > changegroup3 = True
  > [extensions]
  > lfs=!
  > EOF
  $ cp -R no_lfs no_lfs2

Pushing from a local lfs repo to a local repo without an lfs requirement and
with lfs disabled, fails.

  $ hg push -R convert_lfs2 no_lfs
  pushing to no_lfs
  abort: required features are not supported in the destination: lfs
  [255]
  $ grep lfs no_lfs/.hg/requires
  [1]

Pulling from a local lfs repo to a local repo without an lfs requirement and
with lfs disabled, fails.

  $ hg pull -R no_lfs2 convert_lfs2
  pulling from convert_lfs2
  abort: required features are not supported in the destination: lfs
  [255]
  $ grep lfs no_lfs2/.hg/requires
  [1]
