#require serve

#testcases stream-legacy stream-bundle2

#if stream-bundle2
  $ cat << EOF >> $HGRCPATH
  > [experimental]
  > bundle2.stream = yes
  > EOF
#endif

Initialize repository
the status call is to check for issue5130

  $ hg init server
  $ cd server
  $ touch foo
  $ hg -q commit -A -m initial
  >>> for i in range(1024):
  ...     with open(str(i), 'wb') as fh:
  ...         fh.write(str(i))
  $ hg -q commit -A -m 'add a lot of files'
  $ hg st
  $ hg serve -p $HGPORT -d --pid-file=hg.pid
  $ cat hg.pid >> $DAEMON_PIDS
  $ cd ..

Basic clone

#if stream-legacy
  $ hg clone --stream -U http://localhost:$HGPORT clone1
  streaming all changes
  1027 files to transfer, 96.3 KB of data
  transferred 96.3 KB in * seconds (*/sec) (glob)
  searching for changes
  no changes found
#endif
#if stream-bundle2
  $ hg clone --stream -U http://localhost:$HGPORT clone1
  streaming all changes
  1030 files to transfer, 96.4 KB of data
  transferred 96.4 KB in * seconds (* */sec) (glob)

  $ ls -1 clone1/.hg/cache
  branch2-served
  rbc-names-v1
  rbc-revs-v1
#endif

getbundle requests with stream=1 are uncompressed

  $ get-with-headers.py $LOCALIP:$HGPORT '?cmd=getbundle' content-type --bodyfile body --hgproto '0.1 0.2 comp=zlib,none' --requestheader "x-hgarg-1=bundlecaps=HG20%2Cbundle2%3DHG20%250Abookmarks%250Achangegroup%253D01%252C02%250Adigests%253Dmd5%252Csha1%252Csha512%250Aerror%253Dabort%252Cunsupportedcontent%252Cpushraced%252Cpushkey%250Ahgtagsfnodes%250Alistkeys%250Aphases%253Dheads%250Apushkey%250Aremote-changegroup%253Dhttp%252Chttps&cg=0&common=0000000000000000000000000000000000000000&heads=c17445101a72edac06facd130d14808dfbd5c7c2&stream=1"
  200 Script output follows
  content-type: application/mercurial-0.2
  

  $ f --size --hex --bytes 256 body
  body: size=112328
  0000: 04 6e 6f 6e 65 48 47 32 30 00 00 00 00 00 00 00 |.noneHG20.......|
  0010: 72 06 53 54 52 45 41 4d 00 00 00 00 04 00 09 05 |r.STREAM........|
  0020: 09 04 0c 2d 07 02 62 79 74 65 63 6f 75 6e 74 39 |...-..bytecount9|
  0030: 38 37 35 38 66 69 6c 65 63 6f 75 6e 74 31 30 33 |8758filecount103|
  0040: 30 72 65 71 75 69 72 65 6d 65 6e 74 73 64 6f 74 |0requirementsdot|
  0050: 65 6e 63 6f 64 65 20 66 6e 63 61 63 68 65 20 67 |encode fncache g|
  0060: 65 6e 65 72 61 6c 64 65 6c 74 61 20 72 65 76 6c |eneraldelta revl|
  0070: 6f 67 76 31 20 73 74 6f 72 65 76 65 72 73 69 6f |ogv1 storeversio|
  0080: 6e 76 32 00 00 10 00 73 08 42 64 61 74 61 2f 30 |nv2....s.Bdata/0|
  0090: 2e 69 00 03 00 01 00 00 00 00 00 00 00 02 00 00 |.i..............|
  00a0: 00 01 00 00 00 00 00 00 00 01 ff ff ff ff ff ff |................|
  00b0: ff ff 80 29 63 a0 49 d3 23 87 bf ce fe 56 67 92 |...)c.I.#....Vg.|
  00c0: 67 2c 69 d1 ec 39 00 00 00 00 00 00 00 00 00 00 |g,i..9..........|
  00d0: 00 00 75 30 73 08 42 64 61 74 61 2f 31 2e 69 00 |..u0s.Bdata/1.i.|
  00e0: 03 00 01 00 00 00 00 00 00 00 02 00 00 00 01 00 |................|
  00f0: 00 00 00 00 00 00 01 ff ff ff ff ff ff ff ff f9 |................|

--uncompressed is an alias to --stream

#if stream-legacy
  $ hg clone --uncompressed -U http://localhost:$HGPORT clone1-uncompressed
  streaming all changes
  1027 files to transfer, 96.3 KB of data
  transferred 96.3 KB in * seconds (*/sec) (glob)
  searching for changes
  no changes found
#endif
#if stream-bundle2
  $ hg clone --uncompressed -U http://localhost:$HGPORT clone1-uncompressed
  streaming all changes
  1030 files to transfer, 96.4 KB of data
  transferred 96.4 KB in * seconds (* */sec) (glob)
#endif

Clone with background file closing enabled

#if stream-legacy
  $ hg --debug --config worker.backgroundclose=true --config worker.backgroundcloseminfilecount=1 clone --stream -U http://localhost:$HGPORT clone-background | grep -v adding
  using http://localhost:$HGPORT/
  sending capabilities command
  sending branchmap command
  streaming all changes
  sending stream_out command
  1027 files to transfer, 96.3 KB of data
  starting 4 threads for background file closing
  transferred 96.3 KB in * seconds (*/sec) (glob)
  query 1; heads
  sending batch command
  searching for changes
  all remote heads known locally
  no changes found
  sending getbundle command
  bundle2-input-bundle: with-transaction
  bundle2-input-part: "listkeys" (params: 1 mandatory) supported
  bundle2-input-part: "phase-heads" supported
  bundle2-input-part: total payload size 24
  bundle2-input-bundle: 1 parts total
  checking for updated bookmarks
#endif
#if stream-bundle2
  $ hg --debug --config worker.backgroundclose=true --config worker.backgroundcloseminfilecount=1 clone --stream -U http://localhost:$HGPORT clone-background | grep -v adding
  using http://localhost:$HGPORT/
  sending capabilities command
  query 1; heads
  sending batch command
  streaming all changes
  sending getbundle command
  bundle2-input-bundle: with-transaction
  bundle2-input-part: "stream" (params: 4 mandatory) supported
  applying stream bundle
  1030 files to transfer, 96.4 KB of data
  starting 4 threads for background file closing
  starting 4 threads for background file closing
  transferred 96.4 KB in * seconds (* */sec) (glob)
  bundle2-input-part: total payload size 112077
  bundle2-input-part: "listkeys" (params: 1 mandatory) supported
  bundle2-input-bundle: 1 parts total
  checking for updated bookmarks
#endif

Cannot stream clone when there are secret changesets

  $ hg -R server phase --force --secret -r tip
  $ hg clone --stream -U http://localhost:$HGPORT secret-denied
  warning: stream clone requested but server has them disabled
  requesting all changes
  adding changesets
  adding manifests
  adding file changes
  added 1 changesets with 1 changes to 1 files
  new changesets 96ee1d7354c4

  $ killdaemons.py

Streaming of secrets can be overridden by server config

  $ cd server
  $ hg serve --config server.uncompressedallowsecret=true -p $HGPORT -d --pid-file=hg.pid
  $ cat hg.pid > $DAEMON_PIDS
  $ cd ..

#if stream-legacy
  $ hg clone --stream -U http://localhost:$HGPORT secret-allowed
  streaming all changes
  1027 files to transfer, 96.3 KB of data
  transferred 96.3 KB in * seconds (*/sec) (glob)
  searching for changes
  no changes found
#endif
#if stream-bundle2
  $ hg clone --stream -U http://localhost:$HGPORT secret-allowed
  streaming all changes
  1030 files to transfer, 96.4 KB of data
  transferred 96.4 KB in * seconds (* */sec) (glob)
#endif

  $ killdaemons.py

Verify interaction between preferuncompressed and secret presence

  $ cd server
  $ hg serve --config server.preferuncompressed=true -p $HGPORT -d --pid-file=hg.pid
  $ cat hg.pid > $DAEMON_PIDS
  $ cd ..

  $ hg clone -U http://localhost:$HGPORT preferuncompressed-secret
  requesting all changes
  adding changesets
  adding manifests
  adding file changes
  added 1 changesets with 1 changes to 1 files
  new changesets 96ee1d7354c4

  $ killdaemons.py

Clone not allowed when full bundles disabled and can't serve secrets

  $ cd server
  $ hg serve --config server.disablefullbundle=true -p $HGPORT -d --pid-file=hg.pid
  $ cat hg.pid > $DAEMON_PIDS
  $ cd ..

  $ hg clone --stream http://localhost:$HGPORT secret-full-disabled
  warning: stream clone requested but server has them disabled
  requesting all changes
  remote: abort: server has pull-based clones disabled
  abort: pull failed on remote
  (remove --pull if specified or upgrade Mercurial)
  [255]

Local stream clone with secrets involved
(This is just a test over behavior: if you have access to the repo's files,
there is no security so it isn't important to prevent a clone here.)

  $ hg clone -U --stream server local-secret
  warning: stream clone requested but server has them disabled
  requesting all changes
  adding changesets
  adding manifests
  adding file changes
  added 1 changesets with 1 changes to 1 files
  new changesets 96ee1d7354c4

Stream clone while repo is changing:

  $ mkdir changing
  $ cd changing

extension for delaying the server process so we reliably can modify the repo
while cloning

  $ cat > delayer.py <<EOF
  > import time
  > from mercurial import extensions, vfs
  > def __call__(orig, self, path, *args, **kwargs):
  >     if path == 'data/f1.i':
  >         time.sleep(2)
  >     return orig(self, path, *args, **kwargs)
  > extensions.wrapfunction(vfs.vfs, '__call__', __call__)
  > EOF

prepare repo with small and big file to cover both code paths in emitrevlogdata

  $ hg init repo
  $ touch repo/f1
  $ $TESTDIR/seq.py 50000 > repo/f2
  $ hg -R repo ci -Aqm "0"
  $ hg serve -R repo -p $HGPORT1 -d --pid-file=hg.pid --config extensions.delayer=delayer.py
  $ cat hg.pid >> $DAEMON_PIDS

clone while modifying the repo between stating file with write lock and
actually serving file content

  $ hg clone -q --stream -U http://localhost:$HGPORT1 clone &
  $ sleep 1
  $ echo >> repo/f1
  $ echo >> repo/f2
  $ hg -R repo ci -m "1"
  $ wait
  $ hg -R clone id
  000000000000
  $ cd ..

Stream repository with bookmarks
--------------------------------

(revert introduction of secret changeset)

  $ hg -R server phase --draft 'secret()'

add a bookmark

  $ hg -R server bookmark -r tip some-bookmark

clone it

#if stream-legacy
  $ hg clone --stream http://localhost:$HGPORT with-bookmarks
  streaming all changes
  1027 files to transfer, 96.3 KB of data
  transferred 96.3 KB in * seconds (*) (glob)
  searching for changes
  no changes found
  updating to branch default
  1025 files updated, 0 files merged, 0 files removed, 0 files unresolved
#endif
#if stream-bundle2
  $ hg clone --stream http://localhost:$HGPORT with-bookmarks
  streaming all changes
  1033 files to transfer, 96.6 KB of data
  transferred 96.6 KB in * seconds (* */sec) (glob)
  updating to branch default
  1025 files updated, 0 files merged, 0 files removed, 0 files unresolved
#endif
  $ hg -R with-bookmarks bookmarks
     some-bookmark             1:c17445101a72

Stream repository with phases
-----------------------------

Clone as publishing

  $ hg -R server phase -r 'all()'
  0: draft
  1: draft

#if stream-legacy
  $ hg clone --stream http://localhost:$HGPORT phase-publish
  streaming all changes
  1027 files to transfer, 96.3 KB of data
  transferred 96.3 KB in * seconds (*) (glob)
  searching for changes
  no changes found
  updating to branch default
  1025 files updated, 0 files merged, 0 files removed, 0 files unresolved
#endif
#if stream-bundle2
  $ hg clone --stream http://localhost:$HGPORT phase-publish
  streaming all changes
  1033 files to transfer, 96.6 KB of data
  transferred 96.6 KB in * seconds (* */sec) (glob)
  updating to branch default
  1025 files updated, 0 files merged, 0 files removed, 0 files unresolved
#endif
  $ hg -R phase-publish phase -r 'all()'
  0: public
  1: public

Clone as non publishing

  $ cat << EOF >> server/.hg/hgrc
  > [phases]
  > publish = False
  > EOF
  $ killdaemons.py
  $ hg -R server serve -p $HGPORT -d --pid-file=hg.pid
  $ cat hg.pid >> $DAEMON_PIDS

#if stream-legacy
  $ hg clone --stream http://localhost:$HGPORT phase-no-publish
  streaming all changes
  1027 files to transfer, 96.3 KB of data
  transferred 96.3 KB in * seconds (*) (glob)
  searching for changes
  no changes found
  updating to branch default
  1025 files updated, 0 files merged, 0 files removed, 0 files unresolved
  $ hg -R phase-no-publish phase -r 'all()'
  0: public
  1: public
#endif
#if stream-bundle2
  $ hg clone --stream http://localhost:$HGPORT phase-no-publish
  streaming all changes
  1034 files to transfer, 96.7 KB of data
  transferred 96.7 KB in * seconds (* */sec) (glob)
  updating to branch default
  1025 files updated, 0 files merged, 0 files removed, 0 files unresolved
  $ hg -R phase-no-publish phase -r 'all()'
  0: draft
  1: draft
#endif

  $ killdaemons.py
