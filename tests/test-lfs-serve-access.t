#require serve no-reposimplestore

  $ cat >> $HGRCPATH <<EOF
  > [extensions]
  > lfs=
  > [lfs]
  > url=http://localhost:$HGPORT/.git/info/lfs
  > track=all()
  > [web]
  > push_ssl = False
  > allow-push = *
  > EOF

Serving LFS files can experimentally be turned off.  The long term solution is
to support the 'verify' action in both client and server, so that the server can
tell the client to store files elsewhere.

  $ hg init server
  $ hg --config "lfs.usercache=$TESTTMP/servercache" \
  >    --config experimental.lfs.serve=False -R server serve -d \
  >    -p $HGPORT --pid-file=hg.pid -A $TESTTMP/access.log -E $TESTTMP/errors.log
  $ cat hg.pid >> $DAEMON_PIDS

Uploads fail...

  $ hg init client
  $ echo 'this-is-an-lfs-file' > client/lfs.bin
  $ hg -R client ci -Am 'initial commit'
  adding lfs.bin
  $ hg -R client push http://localhost:$HGPORT
  pushing to http://localhost:$HGPORT/
  searching for changes
  abort: LFS HTTP error: HTTP Error 400: no such method: .git (action=upload)!
  [255]

... so do a local push to make the data available.  Remove the blob from the
default cache, so it attempts to download.
  $ hg --config "lfs.usercache=$TESTTMP/servercache" \
  >    --config "lfs.url=null://" \
  >    -R client push -q server
  $ mv `hg config lfs.usercache` $TESTTMP/servercache

Downloads fail...

  $ hg clone http://localhost:$HGPORT httpclone
  requesting all changes
  adding changesets
  adding manifests
  adding file changes
  added 1 changesets with 1 changes to 1 files
  new changesets 525251863cad
  updating to branch default
  abort: LFS HTTP error: HTTP Error 400: no such method: .git (action=download)!
  [255]

  $ $PYTHON $RUNTESTDIR/killdaemons.py $DAEMON_PIDS

  $ cat $TESTTMP/access.log $TESTTMP/errors.log
  $LOCALIP - - [$LOGDATE$] "GET /?cmd=capabilities HTTP/1.1" 200 - (glob)
  $LOCALIP - - [$LOGDATE$] "GET /?cmd=batch HTTP/1.1" 200 - x-hgarg-1:cmds=heads+%3Bknown+nodes%3D525251863cad618e55d483555f3d00a2ca99597e x-hgproto-1:0.1 0.2 comp=$USUAL_COMPRESSIONS$ partial-pull (glob)
  $LOCALIP - - [$LOGDATE$] "GET /?cmd=listkeys HTTP/1.1" 200 - x-hgarg-1:namespace=phases x-hgproto-1:0.1 0.2 comp=$USUAL_COMPRESSIONS$ partial-pull (glob)
  $LOCALIP - - [$LOGDATE$] "GET /?cmd=listkeys HTTP/1.1" 200 - x-hgarg-1:namespace=bookmarks x-hgproto-1:0.1 0.2 comp=$USUAL_COMPRESSIONS$ partial-pull (glob)
  $LOCALIP - - [$LOGDATE$] "POST /.git/info/lfs/objects/batch HTTP/1.1" 400 - (glob)
  $LOCALIP - - [$LOGDATE$] "GET /?cmd=capabilities HTTP/1.1" 200 - (glob)
  $LOCALIP - - [$LOGDATE$] "GET /?cmd=batch HTTP/1.1" 200 - x-hgarg-1:cmds=heads+%3Bknown+nodes%3D x-hgproto-1:0.1 0.2 comp=$USUAL_COMPRESSIONS$ partial-pull (glob)
  $LOCALIP - - [$LOGDATE$] "GET /?cmd=getbundle HTTP/1.1" 200 - x-hgarg-1:bookmarks=1&bundlecaps=HG20%2Cbundle2%3DHG20%250Abookmarks%250Achangegroup%253D01%252C02%252C03%250Adigests%253Dmd5%252Csha1%252Csha512%250Aerror%253Dabort%252Cunsupportedcontent%252Cpushraced%252Cpushkey%250Ahgtagsfnodes%250Alistkeys%250Aphases%253Dheads%250Apushkey%250Aremote-changegroup%253Dhttp%252Chttps%250Arev-branch-cache%250Astream%253Dv2&cg=1&common=0000000000000000000000000000000000000000&heads=525251863cad618e55d483555f3d00a2ca99597e&listkeys=bookmarks&phases=1 x-hgproto-1:0.1 0.2 comp=$USUAL_COMPRESSIONS$ partial-pull (glob)
  $LOCALIP - - [$LOGDATE$] "POST /.git/info/lfs/objects/batch HTTP/1.1" 400 - (glob)

Blob URIs are correct when --prefix is used

  $ rm -f $TESTTMP/access.log $TESTTMP/errors.log
  $ hg --config "lfs.usercache=$TESTTMP/servercache" -R server serve -d \
  >    -p $HGPORT --pid-file=hg.pid --prefix=subdir/mount/point \
  >    -A $TESTTMP/access.log -E $TESTTMP/errors.log
  $ cat hg.pid >> $DAEMON_PIDS

  $ hg --config lfs.url=http://localhost:$HGPORT/subdir/mount/point/.git/info/lfs \
  >    clone --debug http://localhost:$HGPORT/subdir/mount/point cloned2
  using http://localhost:$HGPORT/subdir/mount/point
  sending capabilities command
  query 1; heads
  sending batch command
  requesting all changes
  sending getbundle command
  bundle2-input-bundle: with-transaction
  bundle2-input-part: "changegroup" (params: 1 mandatory 1 advisory) supported
  adding changesets
  add changeset 525251863cad
  adding manifests
  adding file changes
  adding lfs.bin revisions
  added 1 changesets with 1 changes to 1 files
  calling hook pretxnchangegroup.lfs: hgext.lfs.checkrequireslfs
  bundle2-input-part: total payload size 648
  bundle2-input-part: "listkeys" (params: 1 mandatory) supported
  bundle2-input-part: "phase-heads" supported
  bundle2-input-part: total payload size 24
  bundle2-input-part: "cache:rev-branch-cache" supported
  bundle2-input-part: total payload size 39
  bundle2-input-bundle: 3 parts total
  checking for updated bookmarks
  updating the branch cache
  new changesets 525251863cad
  updating to branch default
  resolving manifests
   branchmerge: False, force: False, partial: False
   ancestor: 000000000000, local: 000000000000+, remote: 525251863cad
  Status: 200
  Content-Length: 371
  Content-Type: application/vnd.git-lfs+json
  Date: $HTTP_DATE$
  Server: testing stub value
  {
    "objects": [
      {
        "actions": {
          "download": {
            "expires_at": "$ISO_8601_DATE_TIME$"
            "header": {
              "Accept": "application/vnd.git-lfs"
            }
            "href": "http://localhost:$HGPORT/subdir/mount/point/.hg/lfs/objects/f03217a32529a28a42d03b1244fe09b6e0f9fd06d7b966d4d50567be2abe6c0e"
          }
        }
        "oid": "f03217a32529a28a42d03b1244fe09b6e0f9fd06d7b966d4d50567be2abe6c0e"
        "size": 20
      }
    ]
    "transfer": "basic"
  }
  lfs: downloading f03217a32529a28a42d03b1244fe09b6e0f9fd06d7b966d4d50567be2abe6c0e (20 bytes)
  Status: 200
  Content-Length: 20
  Content-Type: application/octet-stream
  Date: $HTTP_DATE$
  Server: testing stub value
  lfs: adding f03217a32529a28a42d03b1244fe09b6e0f9fd06d7b966d4d50567be2abe6c0e to the usercache
  lfs: processed: f03217a32529a28a42d03b1244fe09b6e0f9fd06d7b966d4d50567be2abe6c0e
   lfs.bin: remote created -> g
  getting lfs.bin
  lfs: found f03217a32529a28a42d03b1244fe09b6e0f9fd06d7b966d4d50567be2abe6c0e in the local lfs store
  1 files updated, 0 files merged, 0 files removed, 0 files unresolved

  $ $PYTHON $RUNTESTDIR/killdaemons.py $DAEMON_PIDS

  $ cat $TESTTMP/access.log $TESTTMP/errors.log
  $LOCALIP - - [$LOGDATE$] "GET /subdir/mount/point?cmd=capabilities HTTP/1.1" 200 - (glob)
  $LOCALIP - - [$LOGDATE$] "GET /subdir/mount/point?cmd=batch HTTP/1.1" 200 - x-hgarg-1:cmds=heads+%3Bknown+nodes%3D x-hgproto-1:0.1 0.2 comp=$USUAL_COMPRESSIONS$ partial-pull (glob)
  $LOCALIP - - [$LOGDATE$] "GET /subdir/mount/point?cmd=getbundle HTTP/1.1" 200 - x-hgarg-1:bookmarks=1&bundlecaps=HG20%2Cbundle2%3DHG20%250Abookmarks%250Achangegroup%253D01%252C02%252C03%250Adigests%253Dmd5%252Csha1%252Csha512%250Aerror%253Dabort%252Cunsupportedcontent%252Cpushraced%252Cpushkey%250Ahgtagsfnodes%250Alistkeys%250Aphases%253Dheads%250Apushkey%250Aremote-changegroup%253Dhttp%252Chttps%250Arev-branch-cache%250Astream%253Dv2&cg=1&common=0000000000000000000000000000000000000000&heads=525251863cad618e55d483555f3d00a2ca99597e&listkeys=bookmarks&phases=1 x-hgproto-1:0.1 0.2 comp=$USUAL_COMPRESSIONS$ partial-pull (glob)
  $LOCALIP - - [$LOGDATE$] "POST /subdir/mount/point/.git/info/lfs/objects/batch HTTP/1.1" 200 - (glob)
  $LOCALIP - - [$LOGDATE$] "GET /subdir/mount/point/.hg/lfs/objects/f03217a32529a28a42d03b1244fe09b6e0f9fd06d7b966d4d50567be2abe6c0e HTTP/1.1" 200 - (glob)
