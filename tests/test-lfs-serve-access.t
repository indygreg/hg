#require serve no-reposimplestore

  $ cat >> $HGRCPATH <<EOF
  > [extensions]
  > lfs=
  > [lfs]
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

  $ hg clone --debug http://localhost:$HGPORT/subdir/mount/point cloned2
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
  lfs: assuming remote store: http://localhost:$HGPORT/subdir/mount/point/.git/info/lfs
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
  lfs: downloaded 1 files (20 bytes)
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

  $ cat >> $TESTTMP/lfsstoreerror.py <<EOF
  > import errno
  > from hgext.lfs import blobstore
  > 
  > _numverifies = 0
  > _readerr = True
  > 
  > def reposetup(ui, repo):
  >     # Nothing to do with a remote repo
  >     if not repo.local():
  >         return
  > 
  >     store = repo.svfs.lfslocalblobstore
  >     class badstore(store.__class__):
  >         def download(self, oid, src):
  >             '''Called in the server to handle reading from the client in a
  >             PUT request.'''
  >             origread = src.read
  >             def _badread(nbytes):
  >                 # Simulate bad data/checksum failure from the client
  >                 return b'0' * len(origread(nbytes))
  >             src.read = _badread
  >             super(badstore, self).download(oid, src)
  > 
  >         def _read(self, vfs, oid, verify):
  >             '''Called in the server to read data for a GET request, and then
  >             calls self._verify() on it before returning.'''
  >             global _readerr
  >             # One time simulation of a read error
  >             if _readerr:
  >                 _readerr = False
  >                 raise IOError(errno.EIO, '%s: I/O error' % oid)
  >             # Simulate corrupt content on client download
  >             blobstore._verify(oid, 'dummy content')
  > 
  >         def verify(self, oid):
  >             '''Called in the server to populate the Batch API response,
  >             letting the client re-upload if the file is corrupt.'''
  >             # Fail verify in Batch API for one clone command and one push
  >             # command with an IOError.  Then let it through to access other
  >             # functions.  Checksum failure is tested elsewhere.
  >             global _numverifies
  >             _numverifies += 1
  >             if _numverifies <= 2:
  >                 raise IOError(errno.EIO, '%s: I/O error' % oid)
  >             return super(badstore, self).verify(oid)
  > 
  >     store.__class__ = badstore
  > EOF

  $ rm -rf `hg config lfs.usercache`
  $ rm -f $TESTTMP/access.log $TESTTMP/errors.log
  $ hg --config "lfs.usercache=$TESTTMP/servercache" \
  >    --config extensions.lfsstoreerror=$TESTTMP/lfsstoreerror.py \
  >    -R server serve -d \
  >    -p $HGPORT1 --pid-file=hg.pid -A $TESTTMP/access.log -E $TESTTMP/errors.log
  $ cat hg.pid >> $DAEMON_PIDS

Test an I/O error in localstore.verify() (Batch API) with GET

  $ hg clone http://localhost:$HGPORT1 httpclone2
  requesting all changes
  adding changesets
  adding manifests
  adding file changes
  added 1 changesets with 1 changes to 1 files
  new changesets 525251863cad
  updating to branch default
  abort: LFS server error for "lfs.bin": Internal server error!
  [255]

Test an I/O error in localstore.verify() (Batch API) with PUT

  $ echo foo > client/lfs.bin
  $ hg -R client ci -m 'mod lfs'
  $ hg -R client push http://localhost:$HGPORT1
  pushing to http://localhost:$HGPORT1/
  searching for changes
  abort: LFS server error for "unknown": Internal server error!
  [255]
TODO: figure out how to associate the file name in the error above

Test a bad checksum sent by the client in the transfer API

  $ hg -R client push http://localhost:$HGPORT1
  pushing to http://localhost:$HGPORT1/
  searching for changes
  abort: HTTP error: HTTP Error 422: corrupt blob (oid=b5bb9d8014a0f9b1d61e21e796d78dccdf1352f23cd32812f4850b878ae4944c, action=upload)!
  [255]

  $ echo 'test lfs file' > server/lfs3.bin
  $ hg --config experimental.lfs.disableusercache=True \
  >    -R server ci -Aqm 'another lfs file'
  $ hg -R client pull -q http://localhost:$HGPORT1

Test an I/O error during the processing of the GET request

  $ hg --config lfs.url=http://localhost:$HGPORT1/.git/info/lfs \
  >    -R client update -r tip
  abort: HTTP error: HTTP Error 500: Internal Server Error (oid=276f73cfd75f9fb519810df5f5d96d6594ca2521abd86cbcd92122f7d51a1f3d, action=download)!
  [255]

Test a checksum failure during the processing of the GET request

  $ hg --config lfs.url=http://localhost:$HGPORT1/.git/info/lfs \
  >    -R client update -r tip
  abort: HTTP error: HTTP Error 422: corrupt blob (oid=276f73cfd75f9fb519810df5f5d96d6594ca2521abd86cbcd92122f7d51a1f3d, action=download)!
  [255]

  $ $PYTHON $RUNTESTDIR/killdaemons.py $DAEMON_PIDS

  $ cat $TESTTMP/access.log
  $LOCALIP - - [$LOGDATE$] "GET /?cmd=capabilities HTTP/1.1" 200 - (glob)
  $LOCALIP - - [$LOGDATE$] "GET /?cmd=batch HTTP/1.1" 200 - x-hgarg-1:cmds=heads+%3Bknown+nodes%3D x-hgproto-1:0.1 0.2 comp=$USUAL_COMPRESSIONS$ partial-pull (glob)
  $LOCALIP - - [$LOGDATE$] "GET /?cmd=getbundle HTTP/1.1" 200 - x-hgarg-1:bookmarks=1&bundlecaps=HG20%2Cbundle2%3DHG20%250Abookmarks%250Achangegroup%253D01%252C02%252C03%250Adigests%253Dmd5%252Csha1%252Csha512%250Aerror%253Dabort%252Cunsupportedcontent%252Cpushraced%252Cpushkey%250Ahgtagsfnodes%250Alistkeys%250Aphases%253Dheads%250Apushkey%250Aremote-changegroup%253Dhttp%252Chttps%250Arev-branch-cache%250Astream%253Dv2&cg=1&common=0000000000000000000000000000000000000000&heads=525251863cad618e55d483555f3d00a2ca99597e&listkeys=bookmarks&phases=1 x-hgproto-1:0.1 0.2 comp=$USUAL_COMPRESSIONS$ partial-pull (glob)
  $LOCALIP - - [$LOGDATE$] "POST /.git/info/lfs/objects/batch HTTP/1.1" 200 - (glob)
  $LOCALIP - - [$LOGDATE$] "GET /?cmd=capabilities HTTP/1.1" 200 - (glob)
  $LOCALIP - - [$LOGDATE$] "GET /?cmd=batch HTTP/1.1" 200 - x-hgarg-1:cmds=heads+%3Bknown+nodes%3D392c05922088bacf8e68a6939b480017afbf245d x-hgproto-1:0.1 0.2 comp=$USUAL_COMPRESSIONS$ partial-pull (glob)
  $LOCALIP - - [$LOGDATE$] "GET /?cmd=listkeys HTTP/1.1" 200 - x-hgarg-1:namespace=phases x-hgproto-1:0.1 0.2 comp=$USUAL_COMPRESSIONS$ partial-pull (glob)
  $LOCALIP - - [$LOGDATE$] "GET /?cmd=listkeys HTTP/1.1" 200 - x-hgarg-1:namespace=bookmarks x-hgproto-1:0.1 0.2 comp=$USUAL_COMPRESSIONS$ partial-pull (glob)
  $LOCALIP - - [$LOGDATE$] "GET /?cmd=branchmap HTTP/1.1" 200 - x-hgproto-1:0.1 0.2 comp=$USUAL_COMPRESSIONS$ partial-pull (glob)
  $LOCALIP - - [$LOGDATE$] "GET /?cmd=listkeys HTTP/1.1" 200 - x-hgarg-1:namespace=bookmarks x-hgproto-1:0.1 0.2 comp=$USUAL_COMPRESSIONS$ partial-pull (glob)
  $LOCALIP - - [$LOGDATE$] "POST /.git/info/lfs/objects/batch HTTP/1.1" 200 - (glob)
  $LOCALIP - - [$LOGDATE$] "GET /?cmd=capabilities HTTP/1.1" 200 - (glob)
  $LOCALIP - - [$LOGDATE$] "GET /?cmd=batch HTTP/1.1" 200 - x-hgarg-1:cmds=heads+%3Bknown+nodes%3D392c05922088bacf8e68a6939b480017afbf245d x-hgproto-1:0.1 0.2 comp=$USUAL_COMPRESSIONS$ partial-pull (glob)
  $LOCALIP - - [$LOGDATE$] "GET /?cmd=listkeys HTTP/1.1" 200 - x-hgarg-1:namespace=phases x-hgproto-1:0.1 0.2 comp=$USUAL_COMPRESSIONS$ partial-pull (glob)
  $LOCALIP - - [$LOGDATE$] "GET /?cmd=listkeys HTTP/1.1" 200 - x-hgarg-1:namespace=bookmarks x-hgproto-1:0.1 0.2 comp=$USUAL_COMPRESSIONS$ partial-pull (glob)
  $LOCALIP - - [$LOGDATE$] "GET /?cmd=branchmap HTTP/1.1" 200 - x-hgproto-1:0.1 0.2 comp=$USUAL_COMPRESSIONS$ partial-pull (glob)
  $LOCALIP - - [$LOGDATE$] "GET /?cmd=listkeys HTTP/1.1" 200 - x-hgarg-1:namespace=bookmarks x-hgproto-1:0.1 0.2 comp=$USUAL_COMPRESSIONS$ partial-pull (glob)
  $LOCALIP - - [$LOGDATE$] "POST /.git/info/lfs/objects/batch HTTP/1.1" 200 - (glob)
  $LOCALIP - - [$LOGDATE$] "PUT /.hg/lfs/objects/b5bb9d8014a0f9b1d61e21e796d78dccdf1352f23cd32812f4850b878ae4944c HTTP/1.1" 422 - (glob)
  $LOCALIP - - [$LOGDATE$] "GET /?cmd=capabilities HTTP/1.1" 200 - (glob)
  $LOCALIP - - [$LOGDATE$] "GET /?cmd=batch HTTP/1.1" 200 - x-hgarg-1:cmds=heads+%3Bknown+nodes%3D392c05922088bacf8e68a6939b480017afbf245d x-hgproto-1:0.1 0.2 comp=$USUAL_COMPRESSIONS$ partial-pull (glob)
  $LOCALIP - - [$LOGDATE$] "GET /?cmd=getbundle HTTP/1.1" 200 - x-hgarg-1:bookmarks=1&bundlecaps=HG20%2Cbundle2%3DHG20%250Abookmarks%250Achangegroup%253D01%252C02%252C03%250Adigests%253Dmd5%252Csha1%252Csha512%250Aerror%253Dabort%252Cunsupportedcontent%252Cpushraced%252Cpushkey%250Ahgtagsfnodes%250Alistkeys%250Aphases%253Dheads%250Apushkey%250Aremote-changegroup%253Dhttp%252Chttps%250Arev-branch-cache%250Astream%253Dv2&cg=1&common=525251863cad618e55d483555f3d00a2ca99597e&heads=506bf3d83f78c54b89e81c6411adee19fdf02156+525251863cad618e55d483555f3d00a2ca99597e&listkeys=bookmarks&phases=1 x-hgproto-1:0.1 0.2 comp=$USUAL_COMPRESSIONS$ partial-pull (glob)
  $LOCALIP - - [$LOGDATE$] "POST /.git/info/lfs/objects/batch HTTP/1.1" 200 - (glob)
  $LOCALIP - - [$LOGDATE$] "GET /.hg/lfs/objects/276f73cfd75f9fb519810df5f5d96d6594ca2521abd86cbcd92122f7d51a1f3d HTTP/1.1" 500 - (glob)
  $LOCALIP - - [$LOGDATE$] "POST /.git/info/lfs/objects/batch HTTP/1.1" 200 - (glob)
  $LOCALIP - - [$LOGDATE$] "GET /.hg/lfs/objects/276f73cfd75f9fb519810df5f5d96d6594ca2521abd86cbcd92122f7d51a1f3d HTTP/1.1" 422 - (glob)

  $ grep -v '  File "' $TESTTMP/errors.log
  $LOCALIP - - [$ERRDATE$] HG error:  Exception happened while processing request '/.git/info/lfs/objects/batch': (glob)
  $LOCALIP - - [$ERRDATE$] HG error:  Traceback (most recent call last): (glob)
  $LOCALIP - - [$ERRDATE$] HG error:      verifies = store.verify(oid) (glob)
  $LOCALIP - - [$ERRDATE$] HG error:      raise IOError(errno.EIO, '%s: I/O error' % oid) (glob)
  $LOCALIP - - [$ERRDATE$] HG error:  IOError: [Errno 5] f03217a32529a28a42d03b1244fe09b6e0f9fd06d7b966d4d50567be2abe6c0e: I/O error (glob)
  $LOCALIP - - [$ERRDATE$] HG error:   (glob)
  $LOCALIP - - [$ERRDATE$] HG error:  Exception happened while processing request '/.git/info/lfs/objects/batch': (glob)
  $LOCALIP - - [$ERRDATE$] HG error:  Traceback (most recent call last): (glob)
  $LOCALIP - - [$ERRDATE$] HG error:      verifies = store.verify(oid) (glob)
  $LOCALIP - - [$ERRDATE$] HG error:      raise IOError(errno.EIO, '%s: I/O error' % oid) (glob)
  $LOCALIP - - [$ERRDATE$] HG error:  IOError: [Errno 5] b5bb9d8014a0f9b1d61e21e796d78dccdf1352f23cd32812f4850b878ae4944c: I/O error (glob)
  $LOCALIP - - [$ERRDATE$] HG error:   (glob)
  $LOCALIP - - [$ERRDATE$] HG error:  Exception happened while processing request '/.hg/lfs/objects/b5bb9d8014a0f9b1d61e21e796d78dccdf1352f23cd32812f4850b878ae4944c': (glob)
  $LOCALIP - - [$ERRDATE$] HG error:  Traceback (most recent call last): (glob)
  $LOCALIP - - [$ERRDATE$] HG error:      localstore.download(oid, req.bodyfh) (glob)
  $LOCALIP - - [$ERRDATE$] HG error:      super(badstore, self).download(oid, src) (glob)
  $LOCALIP - - [$ERRDATE$] HG error:      % oid) (glob)
  $LOCALIP - - [$ERRDATE$] HG error:  LfsCorruptionError: corrupt remote lfs object: b5bb9d8014a0f9b1d61e21e796d78dccdf1352f23cd32812f4850b878ae4944c (glob)
  $LOCALIP - - [$ERRDATE$] HG error:   (glob)
  $LOCALIP - - [$ERRDATE$] Exception happened during processing request '/.hg/lfs/objects/276f73cfd75f9fb519810df5f5d96d6594ca2521abd86cbcd92122f7d51a1f3d': (glob)
  Traceback (most recent call last):
      self.do_write()
      self.do_hgweb()
      for chunk in self.server.application(env, self._start_response):
      for r in self._runwsgi(req, res, repo):
      rctx, req, res, self.check_perm)
      return func(*(args + a), **kw)
      lambda perm:
      res.setbodybytes(localstore.read(oid))
      blob = self._read(self.vfs, oid, verify)
      raise IOError(errno.EIO, '%s: I/O error' % oid)
  IOError: [Errno 5] 276f73cfd75f9fb519810df5f5d96d6594ca2521abd86cbcd92122f7d51a1f3d: I/O error
  
  $LOCALIP - - [$ERRDATE$] HG error:  Exception happened while processing request '/.hg/lfs/objects/276f73cfd75f9fb519810df5f5d96d6594ca2521abd86cbcd92122f7d51a1f3d': (glob)
  $LOCALIP - - [$ERRDATE$] HG error:  Traceback (most recent call last): (glob)
  $LOCALIP - - [$ERRDATE$] HG error:      res.setbodybytes(localstore.read(oid)) (glob)
  $LOCALIP - - [$ERRDATE$] HG error:      blob = self._read(self.vfs, oid, verify) (glob)
  $LOCALIP - - [$ERRDATE$] HG error:      blobstore._verify(oid, 'dummy content') (glob)
  $LOCALIP - - [$ERRDATE$] HG error:      hint=_('run hg verify')) (glob)
  $LOCALIP - - [$ERRDATE$] HG error:  LfsCorruptionError: detected corrupt lfs object: 276f73cfd75f9fb519810df5f5d96d6594ca2521abd86cbcd92122f7d51a1f3d (glob)
  $LOCALIP - - [$ERRDATE$] HG error:   (glob)

Basic Authorization headers are returned by the Batch API, and sent back with
the GET/PUT request.

  $ rm -f $TESTTMP/access.log $TESTTMP/errors.log

  $ cat >> $HGRCPATH << EOF
  > [experimental]
  > lfs.disableusercache = True
  > [auth]
  > l.schemes=http
  > l.prefix=lo
  > l.username=user
  > l.password=pass
  > EOF

  $ cat << EOF > userpass.py
  > import base64
  > from mercurial.hgweb import common
  > def perform_authentication(hgweb, req, op):
  >     auth = req.headers.get(b'Authorization')
  >     if not auth:
  >         raise common.ErrorResponse(common.HTTP_UNAUTHORIZED, b'who',
  >                 [(b'WWW-Authenticate', b'Basic Realm="mercurial"')])
  >     if base64.b64decode(auth.split()[1]).split(b':', 1) != [b'user',
  >                                                             b'pass']:
  >         raise common.ErrorResponse(common.HTTP_FORBIDDEN, b'no')
  > def extsetup():
  >     common.permhooks.insert(0, perform_authentication)
  > EOF

  $ hg --config extensions.x=$TESTTMP/userpass.py \
  >    -R server serve -d -p $HGPORT1 --pid-file=hg.pid \
  >    -A $TESTTMP/access.log -E $TESTTMP/errors.log
  $ mv hg.pid $DAEMON_PIDS

  $ hg clone --debug http://localhost:$HGPORT1 auth_clone | egrep '^[{}]|  '
  {
    "objects": [
      {
        "actions": {
          "download": {
            "expires_at": "$ISO_8601_DATE_TIME$"
            "header": {
              "Accept": "application/vnd.git-lfs"
              "Authorization": "Basic dXNlcjpwYXNz"
            }
            "href": "http://localhost:$HGPORT1/.hg/lfs/objects/276f73cfd75f9fb519810df5f5d96d6594ca2521abd86cbcd92122f7d51a1f3d"
          }
        }
        "oid": "276f73cfd75f9fb519810df5f5d96d6594ca2521abd86cbcd92122f7d51a1f3d"
        "size": 14
      }
    ]
    "transfer": "basic"
  }

  $ echo 'another blob' > auth_clone/lfs.blob
  $ hg -R auth_clone ci -Aqm 'add blob'
  $ hg -R auth_clone --debug push | egrep '^[{}]|  '
  {
    "objects": [
      {
        "actions": {
          "upload": {
            "expires_at": "$ISO_8601_DATE_TIME$"
            "header": {
              "Accept": "application/vnd.git-lfs"
              "Authorization": "Basic dXNlcjpwYXNz"
            }
            "href": "http://localhost:$HGPORT1/.hg/lfs/objects/df14287d8d75f076a6459e7a3703ca583ca9fb3f4918caed10c77ac8622d49b3"
          }
        }
        "oid": "df14287d8d75f076a6459e7a3703ca583ca9fb3f4918caed10c77ac8622d49b3"
        "size": 13
      }
    ]
    "transfer": "basic"
  }

  $ $PYTHON $RUNTESTDIR/killdaemons.py $DAEMON_PIDS

  $ cat $TESTTMP/access.log $TESTTMP/errors.log
  $LOCALIP - - [$LOGDATE$] "GET /?cmd=capabilities HTTP/1.1" 401 - (glob)
  $LOCALIP - - [$LOGDATE$] "GET /?cmd=capabilities HTTP/1.1" 200 - (glob)
  $LOCALIP - - [$LOGDATE$] "GET /?cmd=batch HTTP/1.1" 200 - x-hgarg-1:cmds=heads+%3Bknown+nodes%3D x-hgproto-1:0.1 0.2 comp=$USUAL_COMPRESSIONS$ partial-pull (glob)
  $LOCALIP - - [$LOGDATE$] "GET /?cmd=getbundle HTTP/1.1" 200 - x-hgarg-1:bookmarks=1&bundlecaps=HG20%2Cbundle2%3DHG20%250Abookmarks%250Achangegroup%253D01%252C02%252C03%250Adigests%253Dmd5%252Csha1%252Csha512%250Aerror%253Dabort%252Cunsupportedcontent%252Cpushraced%252Cpushkey%250Ahgtagsfnodes%250Alistkeys%250Aphases%253Dheads%250Apushkey%250Aremote-changegroup%253Dhttp%252Chttps%250Arev-branch-cache%250Astream%253Dv2&cg=1&common=0000000000000000000000000000000000000000&heads=506bf3d83f78c54b89e81c6411adee19fdf02156+525251863cad618e55d483555f3d00a2ca99597e&listkeys=bookmarks&phases=1 x-hgproto-1:0.1 0.2 comp=$USUAL_COMPRESSIONS$ partial-pull (glob)
  $LOCALIP - - [$LOGDATE$] "POST /.git/info/lfs/objects/batch HTTP/1.1" 401 - (glob)
  $LOCALIP - - [$LOGDATE$] "POST /.git/info/lfs/objects/batch HTTP/1.1" 200 - (glob)
  $LOCALIP - - [$LOGDATE$] "GET /.hg/lfs/objects/276f73cfd75f9fb519810df5f5d96d6594ca2521abd86cbcd92122f7d51a1f3d HTTP/1.1" 200 - (glob)
  $LOCALIP - - [$LOGDATE$] "GET /?cmd=capabilities HTTP/1.1" 401 - (glob)
  $LOCALIP - - [$LOGDATE$] "GET /?cmd=capabilities HTTP/1.1" 200 - (glob)
  $LOCALIP - - [$LOGDATE$] "GET /?cmd=batch HTTP/1.1" 200 - x-hgarg-1:cmds=heads+%3Bknown+nodes%3D525251863cad618e55d483555f3d00a2ca99597e+4d9397055dc0c205f3132f331f36353ab1a525a3 x-hgproto-1:0.1 0.2 comp=$USUAL_COMPRESSIONS$ partial-pull (glob)
  $LOCALIP - - [$LOGDATE$] "GET /?cmd=listkeys HTTP/1.1" 200 - x-hgarg-1:namespace=phases x-hgproto-1:0.1 0.2 comp=$USUAL_COMPRESSIONS$ partial-pull (glob)
  $LOCALIP - - [$LOGDATE$] "GET /?cmd=listkeys HTTP/1.1" 200 - x-hgarg-1:namespace=bookmarks x-hgproto-1:0.1 0.2 comp=$USUAL_COMPRESSIONS$ partial-pull (glob)
  $LOCALIP - - [$LOGDATE$] "GET /?cmd=branchmap HTTP/1.1" 200 - x-hgproto-1:0.1 0.2 comp=$USUAL_COMPRESSIONS$ partial-pull (glob)
  $LOCALIP - - [$LOGDATE$] "GET /?cmd=listkeys HTTP/1.1" 200 - x-hgarg-1:namespace=bookmarks x-hgproto-1:0.1 0.2 comp=$USUAL_COMPRESSIONS$ partial-pull (glob)
  $LOCALIP - - [$LOGDATE$] "POST /.git/info/lfs/objects/batch HTTP/1.1" 401 - (glob)
  $LOCALIP - - [$LOGDATE$] "POST /.git/info/lfs/objects/batch HTTP/1.1" 200 - (glob)
  $LOCALIP - - [$LOGDATE$] "PUT /.hg/lfs/objects/df14287d8d75f076a6459e7a3703ca583ca9fb3f4918caed10c77ac8622d49b3 HTTP/1.1" 201 - (glob)
  $LOCALIP - - [$LOGDATE$] "POST /?cmd=unbundle HTTP/1.1" 200 - x-hgarg-1:heads=666f726365 x-hgproto-1:0.1 0.2 comp=$USUAL_COMPRESSIONS$ partial-pull (glob)
  $LOCALIP - - [$LOGDATE$] "GET /?cmd=listkeys HTTP/1.1" 200 - x-hgarg-1:namespace=phases x-hgproto-1:0.1 0.2 comp=$USUAL_COMPRESSIONS$ partial-pull (glob)
