#testcases git-server hg-server

#if git-server
#require lfs-test-server
#else
#require serve
#endif

#if git-server
  $ LFS_LISTEN="tcp://:$HGPORT"
  $ LFS_HOST="localhost:$HGPORT"
  $ LFS_PUBLIC=1
  $ export LFS_LISTEN LFS_HOST LFS_PUBLIC
#else
  $ LFS_HOST="localhost:$HGPORT/.git/info/lfs"
#endif

#if no-windows git-server
  $ lfs-test-server &> lfs-server.log &
  $ echo $! >> $DAEMON_PIDS
#endif

#if windows git-server
  $ cat >> $TESTTMP/spawn.py <<EOF
  > import os
  > import subprocess
  > import sys
  > 
  > for path in os.environ["PATH"].split(os.pathsep):
  >     exe = os.path.join(path, 'lfs-test-server.exe')
  >     if os.path.exists(exe):
  >         with open('lfs-server.log', 'wb') as out:
  >             p = subprocess.Popen(exe, stdout=out, stderr=out)
  >             sys.stdout.write('%s\n' % p.pid)
  >             sys.exit(0)
  > sys.exit(1)
  > EOF
  $ $PYTHON $TESTTMP/spawn.py >> $DAEMON_PIDS
#endif

  $ cat >> $HGRCPATH <<EOF
  > [extensions]
  > lfs=
  > [lfs]
  > url=http://foo:bar@$LFS_HOST
  > track=all()
  > [web]
  > push_ssl = False
  > allow-push = *
  > EOF

Use a separate usercache, otherwise the server sees what the client commits, and
never requests a transfer.

#if hg-server
  $ hg init server
  $ hg --config "lfs.usercache=$TESTTMP/servercache" -R server serve -d \
  >    -p $HGPORT --pid-file=hg.pid -A $TESTTMP/access.log -E $TESTTMP/errors.log
  $ cat hg.pid >> $DAEMON_PIDS
#endif

  $ hg init repo1
  $ cd repo1
  $ echo THIS-IS-LFS > a
  $ hg commit -m a -A a

A push can be serviced directly from the usercache if it isn't in the local
store.

  $ hg init ../repo2
  $ mv .hg/store/lfs .hg/store/lfs_
  $ hg push ../repo2 --debug
  http auth: user foo, password ***
  pushing to ../repo2
  http auth: user foo, password ***
  query 1; heads
  searching for changes
  1 total queries in *s (glob)
  listing keys for "phases"
  checking for updated bookmarks
  listing keys for "bookmarks"
  lfs: computing set of blobs to upload
  Status: 200
  Content-Length: 309 (git-server !)
  Content-Length: 350 (hg-server !)
  Content-Type: application/vnd.git-lfs+json
  Date: $HTTP_DATE$
  Server: testing stub value (hg-server !)
  {
    "objects": [
      {
        "actions": {
          "upload": {
            "expires_at": "$ISO_8601_DATE_TIME$"
            "header": {
              "Accept": "application/vnd.git-lfs"
            }
            "href": "http://localhost:$HGPORT/objects/31cf46fbc4ecd458a0943c5b4881f1f5a6dd36c53d6167d5b69ac45149b38e5b" (git-server !)
            "href": "http://localhost:$HGPORT/.hg/lfs/objects/31cf46fbc4ecd458a0943c5b4881f1f5a6dd36c53d6167d5b69ac45149b38e5b" (hg-server !)
          }
        }
        "oid": "31cf46fbc4ecd458a0943c5b4881f1f5a6dd36c53d6167d5b69ac45149b38e5b"
        "size": 12
      }
    ]
    "transfer": "basic" (hg-server !)
  }
  lfs: uploading 31cf46fbc4ecd458a0943c5b4881f1f5a6dd36c53d6167d5b69ac45149b38e5b (12 bytes)
  Status: 200 (git-server !)
  Status: 201 (hg-server !)
  Content-Length: 0
  Content-Type: text/plain; charset=utf-8
  Date: $HTTP_DATE$
  Server: testing stub value (hg-server !)
  lfs: processed: 31cf46fbc4ecd458a0943c5b4881f1f5a6dd36c53d6167d5b69ac45149b38e5b
  lfs: uploaded 1 files (12 bytes)
  1 changesets found
  list of changesets:
  99a7098854a3984a5c9eab0fc7a2906697b7cb5c
  bundle2-output-bundle: "HG20", 4 parts total
  bundle2-output-part: "replycaps" * bytes payload (glob)
  bundle2-output-part: "check:heads" streamed payload
  bundle2-output-part: "changegroup" (params: 1 mandatory) streamed payload
  bundle2-output-part: "phase-heads" 24 bytes payload
  bundle2-input-bundle: with-transaction
  bundle2-input-part: "replycaps" supported
  bundle2-input-part: total payload size * (glob)
  bundle2-input-part: "check:heads" supported
  bundle2-input-part: total payload size 20
  bundle2-input-part: "changegroup" (params: 1 mandatory) supported
  adding changesets
  add changeset 99a7098854a3
  adding manifests
  adding file changes
  adding a revisions
  added 1 changesets with 1 changes to 1 files
  calling hook pretxnchangegroup.lfs: hgext.lfs.checkrequireslfs
  bundle2-input-part: total payload size 617
  bundle2-input-part: "phase-heads" supported
  bundle2-input-part: total payload size 24
  bundle2-input-bundle: 3 parts total
  updating the branch cache
  bundle2-output-bundle: "HG20", 1 parts total
  bundle2-output-part: "reply:changegroup" (advisory) (params: 0 advisory) empty payload
  bundle2-input-bundle: no-transaction
  bundle2-input-part: "reply:changegroup" (advisory) (params: 0 advisory) supported
  bundle2-input-bundle: 0 parts total
  listing keys for "phases"
  $ mv .hg/store/lfs_ .hg/store/lfs

Clear the cache to force a download
  $ rm -rf `hg config lfs.usercache`
  $ cd ../repo2
  $ hg update tip --debug
  http auth: user foo, password ***
  resolving manifests
   branchmerge: False, force: False, partial: False
   ancestor: 000000000000, local: 000000000000+, remote: 99a7098854a3
  Status: 200
  Content-Length: 311 (git-server !)
  Content-Length: 352 (hg-server !)
  Content-Type: application/vnd.git-lfs+json
  Date: $HTTP_DATE$
  Server: testing stub value (hg-server !)
  {
    "objects": [
      {
        "actions": {
          "download": {
            "expires_at": "$ISO_8601_DATE_TIME$"
            "header": {
              "Accept": "application/vnd.git-lfs"
            }
            "href": "http://localhost:$HGPORT/*/31cf46fbc4ecd458a0943c5b4881f1f5a6dd36c53d6167d5b69ac45149b38e5b" (glob)
          }
        }
        "oid": "31cf46fbc4ecd458a0943c5b4881f1f5a6dd36c53d6167d5b69ac45149b38e5b"
        "size": 12
      }
    ]
    "transfer": "basic" (hg-server !)
  }
  lfs: downloading 31cf46fbc4ecd458a0943c5b4881f1f5a6dd36c53d6167d5b69ac45149b38e5b (12 bytes)
  Status: 200
  Content-Length: 12
  Content-Type: text/plain; charset=utf-8 (git-server !)
  Content-Type: application/octet-stream (hg-server !)
  Date: $HTTP_DATE$
  Server: testing stub value (hg-server !)
  lfs: adding 31cf46fbc4ecd458a0943c5b4881f1f5a6dd36c53d6167d5b69ac45149b38e5b to the usercache
  lfs: processed: 31cf46fbc4ecd458a0943c5b4881f1f5a6dd36c53d6167d5b69ac45149b38e5b
   a: remote created -> g
  getting a
  lfs: found 31cf46fbc4ecd458a0943c5b4881f1f5a6dd36c53d6167d5b69ac45149b38e5b in the local lfs store
  1 files updated, 0 files merged, 0 files removed, 0 files unresolved

When the server has some blobs already.  `hg serve` doesn't offer to upload
blobs that it already knows about.  Note that lfs-test-server is simply
toggling the action to 'download'.  The Batch API spec says it should omit the
actions property completely.

  $ hg mv a b
  $ echo ANOTHER-LARGE-FILE > c
  $ echo ANOTHER-LARGE-FILE2 > d
  $ hg commit -m b-and-c -A b c d
  $ hg push ../repo1 --debug
  http auth: user foo, password ***
  pushing to ../repo1
  http auth: user foo, password ***
  query 1; heads
  searching for changes
  all remote heads known locally
  listing keys for "phases"
  checking for updated bookmarks
  listing keys for "bookmarks"
  listing keys for "bookmarks"
  lfs: computing set of blobs to upload
  Status: 200
  Content-Length: 901 (git-server !)
  Content-Length: 755 (hg-server !)
  Content-Type: application/vnd.git-lfs+json
  Date: $HTTP_DATE$
  Server: testing stub value (hg-server !)
  {
    "objects": [
      {
        "actions": { (git-server !)
          "download": { (git-server !)
            "expires_at": "$ISO_8601_DATE_TIME$" (git-server !)
            "header": { (git-server !)
              "Accept": "application/vnd.git-lfs" (git-server !)
            } (git-server !)
            "href": "http://localhost:$HGPORT/objects/31cf46fbc4ecd458a0943c5b4881f1f5a6dd36c53d6167d5b69ac45149b38e5b" (git-server !)
          } (git-server !)
        } (git-server !)
        "oid": "31cf46fbc4ecd458a0943c5b4881f1f5a6dd36c53d6167d5b69ac45149b38e5b"
        "size": 12
      }
      {
        "actions": {
          "upload": {
            "expires_at": "$ISO_8601_DATE_TIME$"
            "header": {
              "Accept": "application/vnd.git-lfs"
            }
            "href": "http://localhost:$HGPORT/*/37a65ab78d5ecda767e8622c248b5dbff1e68b1678ab0e730d5eb8601ec8ad19" (glob)
          }
        }
        "oid": "37a65ab78d5ecda767e8622c248b5dbff1e68b1678ab0e730d5eb8601ec8ad19"
        "size": 20
      }
      {
        "actions": {
          "upload": {
            "expires_at": "$ISO_8601_DATE_TIME$"
            "header": {
              "Accept": "application/vnd.git-lfs"
            }
            "href": "http://localhost:$HGPORT/*/d11e1a642b60813aee592094109b406089b8dff4cb157157f753418ec7857998" (glob)
          }
        }
        "oid": "d11e1a642b60813aee592094109b406089b8dff4cb157157f753418ec7857998"
        "size": 19
      }
    ]
    "transfer": "basic" (hg-server !)
  }
  lfs: need to transfer 2 objects (39 bytes)
  lfs: uploading 37a65ab78d5ecda767e8622c248b5dbff1e68b1678ab0e730d5eb8601ec8ad19 (20 bytes)
  Status: 200 (git-server !)
  Status: 201 (hg-server !)
  Content-Length: 0
  Content-Type: text/plain; charset=utf-8
  Date: $HTTP_DATE$
  Server: testing stub value (hg-server !)
  lfs: processed: 37a65ab78d5ecda767e8622c248b5dbff1e68b1678ab0e730d5eb8601ec8ad19
  lfs: uploading d11e1a642b60813aee592094109b406089b8dff4cb157157f753418ec7857998 (19 bytes)
  Status: 200 (git-server !)
  Status: 201 (hg-server !)
  Content-Length: 0
  Content-Type: text/plain; charset=utf-8
  Date: $HTTP_DATE$
  Server: testing stub value (hg-server !)
  lfs: processed: d11e1a642b60813aee592094109b406089b8dff4cb157157f753418ec7857998
  lfs: uploaded 2 files (39 bytes)
  1 changesets found
  list of changesets:
  dfca2c9e2ef24996aa61ba2abd99277d884b3d63
  bundle2-output-bundle: "HG20", 5 parts total
  bundle2-output-part: "replycaps" * bytes payload (glob)
  bundle2-output-part: "check:phases" 24 bytes payload
  bundle2-output-part: "check:heads" streamed payload
  bundle2-output-part: "changegroup" (params: 1 mandatory) streamed payload
  bundle2-output-part: "phase-heads" 24 bytes payload
  bundle2-input-bundle: with-transaction
  bundle2-input-part: "replycaps" supported
  bundle2-input-part: total payload size * (glob)
  bundle2-input-part: "check:phases" supported
  bundle2-input-part: total payload size 24
  bundle2-input-part: "check:heads" supported
  bundle2-input-part: total payload size 20
  bundle2-input-part: "changegroup" (params: 1 mandatory) supported
  adding changesets
  add changeset dfca2c9e2ef2
  adding manifests
  adding file changes
  adding b revisions
  adding c revisions
  adding d revisions
  added 1 changesets with 3 changes to 3 files
  bundle2-input-part: total payload size 1315
  bundle2-input-part: "phase-heads" supported
  bundle2-input-part: total payload size 24
  bundle2-input-bundle: 4 parts total
  updating the branch cache
  bundle2-output-bundle: "HG20", 1 parts total
  bundle2-output-part: "reply:changegroup" (advisory) (params: 0 advisory) empty payload
  bundle2-input-bundle: no-transaction
  bundle2-input-part: "reply:changegroup" (advisory) (params: 0 advisory) supported
  bundle2-input-bundle: 0 parts total
  listing keys for "phases"

Clear the cache to force a download
  $ rm -rf `hg config lfs.usercache`
  $ hg --repo ../repo1 update tip --debug
  http auth: user foo, password ***
  resolving manifests
   branchmerge: False, force: False, partial: False
   ancestor: 99a7098854a3, local: 99a7098854a3+, remote: dfca2c9e2ef2
  Status: 200
  Content-Length: 608 (git-server !)
  Content-Length: 670 (hg-server !)
  Content-Type: application/vnd.git-lfs+json
  Date: $HTTP_DATE$
  Server: testing stub value (hg-server !)
  {
    "objects": [
      {
        "actions": {
          "download": {
            "expires_at": "$ISO_8601_DATE_TIME$"
            "header": {
              "Accept": "application/vnd.git-lfs"
            }
            "href": "http://localhost:$HGPORT/*/37a65ab78d5ecda767e8622c248b5dbff1e68b1678ab0e730d5eb8601ec8ad19" (glob)
          }
        }
        "oid": "37a65ab78d5ecda767e8622c248b5dbff1e68b1678ab0e730d5eb8601ec8ad19"
        "size": 20
      }
      {
        "actions": {
          "download": {
            "expires_at": "$ISO_8601_DATE_TIME$"
            "header": {
              "Accept": "application/vnd.git-lfs"
            }
            "href": "http://localhost:$HGPORT/*/d11e1a642b60813aee592094109b406089b8dff4cb157157f753418ec7857998" (glob)
          }
        }
        "oid": "d11e1a642b60813aee592094109b406089b8dff4cb157157f753418ec7857998"
        "size": 19
      }
    ]
    "transfer": "basic" (hg-server !)
  }
  lfs: need to transfer 2 objects (39 bytes)
  lfs: downloading 37a65ab78d5ecda767e8622c248b5dbff1e68b1678ab0e730d5eb8601ec8ad19 (20 bytes)
  Status: 200
  Content-Length: 20
  Content-Type: text/plain; charset=utf-8 (git-server !)
  Content-Type: application/octet-stream (hg-server !)
  Date: $HTTP_DATE$
  Server: testing stub value (hg-server !)
  lfs: adding 37a65ab78d5ecda767e8622c248b5dbff1e68b1678ab0e730d5eb8601ec8ad19 to the usercache
  lfs: processed: 37a65ab78d5ecda767e8622c248b5dbff1e68b1678ab0e730d5eb8601ec8ad19
  lfs: downloading d11e1a642b60813aee592094109b406089b8dff4cb157157f753418ec7857998 (19 bytes)
  Status: 200
  Content-Length: 19
  Content-Type: text/plain; charset=utf-8 (git-server !)
  Content-Type: application/octet-stream (hg-server !)
  Date: $HTTP_DATE$
  Server: testing stub value (hg-server !)
  lfs: adding d11e1a642b60813aee592094109b406089b8dff4cb157157f753418ec7857998 to the usercache
  lfs: processed: d11e1a642b60813aee592094109b406089b8dff4cb157157f753418ec7857998
   b: remote created -> g
  getting b
  lfs: found 31cf46fbc4ecd458a0943c5b4881f1f5a6dd36c53d6167d5b69ac45149b38e5b in the local lfs store
   c: remote created -> g
  getting c
  lfs: found d11e1a642b60813aee592094109b406089b8dff4cb157157f753418ec7857998 in the local lfs store
   d: remote created -> g
  getting d
  lfs: found 37a65ab78d5ecda767e8622c248b5dbff1e68b1678ab0e730d5eb8601ec8ad19 in the local lfs store
  3 files updated, 0 files merged, 0 files removed, 0 files unresolved

Test a corrupt file download, but clear the cache first to force a download.
`hg serve` indicates a corrupt file without transferring it, unlike
lfs-test-server.

  $ rm -rf `hg config lfs.usercache`
#if git-server
  $ cp $TESTTMP/lfs-content/d1/1e/1a642b60813aee592094109b406089b8dff4cb157157f753418ec7857998 blob
  $ echo 'damage' > $TESTTMP/lfs-content/d1/1e/1a642b60813aee592094109b406089b8dff4cb157157f753418ec7857998
#else
  $ cp $TESTTMP/server/.hg/store/lfs/objects/d1/1e1a642b60813aee592094109b406089b8dff4cb157157f753418ec7857998 blob
  $ echo 'damage' > $TESTTMP/server/.hg/store/lfs/objects/d1/1e1a642b60813aee592094109b406089b8dff4cb157157f753418ec7857998
#endif
  $ rm ../repo1/.hg/store/lfs/objects/d1/1e1a642b60813aee592094109b406089b8dff4cb157157f753418ec7857998
  $ rm ../repo1/*

TODO: give the proper error indication from `hg serve`

  $ hg --repo ../repo1 update -C tip --debug
  http auth: user foo, password ***
  resolving manifests
   branchmerge: False, force: True, partial: False
   ancestor: dfca2c9e2ef2+, local: dfca2c9e2ef2+, remote: dfca2c9e2ef2
  Status: 200
  Content-Length: 311 (git-server !)
  Content-Length: 183 (hg-server !)
  Content-Type: application/vnd.git-lfs+json
  Date: $HTTP_DATE$
  Server: testing stub value (hg-server !)
  {
    "objects": [
      {
        "actions": { (git-server !)
          "download": { (git-server !)
            "expires_at": "$ISO_8601_DATE_TIME$" (git-server !)
            "header": { (git-server !)
              "Accept": "application/vnd.git-lfs" (git-server !)
            } (git-server !)
            "href": "http://localhost:$HGPORT/objects/d11e1a642b60813aee592094109b406089b8dff4cb157157f753418ec7857998" (git-server !)
          } (git-server !)
        "error": { (hg-server !)
          "code": 422 (hg-server !)
          "message": "The object is corrupt" (hg-server !)
        }
        "oid": "d11e1a642b60813aee592094109b406089b8dff4cb157157f753418ec7857998"
        "size": 19
      }
    ]
    "transfer": "basic" (hg-server !)
  }
  lfs: downloading d11e1a642b60813aee592094109b406089b8dff4cb157157f753418ec7857998 (19 bytes) (git-server !)
  Status: 200 (git-server !)
  Content-Length: 7 (git-server !)
  Content-Type: text/plain; charset=utf-8 (git-server !)
  Date: $HTTP_DATE$ (git-server !)
  abort: corrupt remote lfs object: d11e1a642b60813aee592094109b406089b8dff4cb157157f753418ec7857998 (git-server !)
  abort: LFS server error. Remote object for "c" not found: *! (glob) (hg-server !)
  [255]

The corrupted blob is not added to the usercache or local store

  $ test -f ../repo1/.hg/store/lfs/objects/d1/1e1a642b60813aee592094109b406089b8dff4cb157157f753418ec7857998
  [1]
  $ test -f `hg config lfs.usercache`/d1/1e1a642b60813aee592094109b406089b8dff4cb157157f753418ec7857998
  [1]
#if git-server
  $ cp blob $TESTTMP/lfs-content/d1/1e/1a642b60813aee592094109b406089b8dff4cb157157f753418ec7857998
#else
  $ cp blob $TESTTMP/server/.hg/store/lfs/objects/d1/1e1a642b60813aee592094109b406089b8dff4cb157157f753418ec7857998
#endif

Test a corrupted file upload

  $ echo 'another lfs blob' > b
  $ hg ci -m 'another blob'
  $ echo 'damage' > .hg/store/lfs/objects/e6/59058e26b07b39d2a9c7145b3f99b41f797b6621c8076600e9cb7ee88291f0
  $ hg push --debug ../repo1
  http auth: user foo, password ***
  pushing to ../repo1
  http auth: user foo, password ***
  query 1; heads
  searching for changes
  all remote heads known locally
  listing keys for "phases"
  checking for updated bookmarks
  listing keys for "bookmarks"
  listing keys for "bookmarks"
  lfs: computing set of blobs to upload
  Status: 200
  Content-Length: 309 (git-server !)
  Content-Length: 350 (hg-server !)
  Content-Type: application/vnd.git-lfs+json
  Date: $HTTP_DATE$
  Server: testing stub value (hg-server !)
  {
    "objects": [
      {
        "actions": {
          "upload": {
            "expires_at": "$ISO_8601_DATE_TIME$"
            "header": {
              "Accept": "application/vnd.git-lfs"
            }
            "href": "http://localhost:$HGPORT/*/e659058e26b07b39d2a9c7145b3f99b41f797b6621c8076600e9cb7ee88291f0" (glob)
          }
        }
        "oid": "e659058e26b07b39d2a9c7145b3f99b41f797b6621c8076600e9cb7ee88291f0"
        "size": 17
      }
    ]
    "transfer": "basic" (hg-server !)
  }
  lfs: uploading e659058e26b07b39d2a9c7145b3f99b41f797b6621c8076600e9cb7ee88291f0 (17 bytes)
  abort: detected corrupt lfs object: e659058e26b07b39d2a9c7145b3f99b41f797b6621c8076600e9cb7ee88291f0
  (run hg verify)
  [255]

Archive will prefetch blobs in a group

  $ rm -rf .hg/store/lfs `hg config lfs.usercache`
  $ hg archive --debug -r 1 ../archive
  http auth: user foo, password ***
  Status: 200
  Content-Length: 905 (git-server !)
  Content-Length: 988 (hg-server !)
  Content-Type: application/vnd.git-lfs+json
  Date: $HTTP_DATE$
  Server: testing stub value (hg-server !)
  {
    "objects": [
      {
        "actions": {
          "download": {
            "expires_at": "$ISO_8601_DATE_TIME$"
            "header": {
              "Accept": "application/vnd.git-lfs"
            }
            "href": "http://localhost:$HGPORT/*/31cf46fbc4ecd458a0943c5b4881f1f5a6dd36c53d6167d5b69ac45149b38e5b" (glob)
          }
        }
        "oid": "31cf46fbc4ecd458a0943c5b4881f1f5a6dd36c53d6167d5b69ac45149b38e5b"
        "size": 12
      }
      {
        "actions": {
          "download": {
            "expires_at": "$ISO_8601_DATE_TIME$"
            "header": {
              "Accept": "application/vnd.git-lfs"
            }
            "href": "http://localhost:$HGPORT/*/37a65ab78d5ecda767e8622c248b5dbff1e68b1678ab0e730d5eb8601ec8ad19" (glob)
          }
        }
        "oid": "37a65ab78d5ecda767e8622c248b5dbff1e68b1678ab0e730d5eb8601ec8ad19"
        "size": 20
      }
      {
        "actions": {
          "download": {
            "expires_at": "$ISO_8601_DATE_TIME$"
            "header": {
              "Accept": "application/vnd.git-lfs"
            }
            "href": "http://localhost:$HGPORT/*/d11e1a642b60813aee592094109b406089b8dff4cb157157f753418ec7857998" (glob)
          }
        }
        "oid": "d11e1a642b60813aee592094109b406089b8dff4cb157157f753418ec7857998"
        "size": 19
      }
    ]
    "transfer": "basic" (hg-server !)
  }
  lfs: need to transfer 3 objects (51 bytes)
  lfs: downloading 31cf46fbc4ecd458a0943c5b4881f1f5a6dd36c53d6167d5b69ac45149b38e5b (12 bytes)
  Status: 200
  Content-Length: 12
  Content-Type: text/plain; charset=utf-8 (git-server !)
  Content-Type: application/octet-stream (hg-server !)
  Date: $HTTP_DATE$
  Server: testing stub value (hg-server !)
  lfs: adding 31cf46fbc4ecd458a0943c5b4881f1f5a6dd36c53d6167d5b69ac45149b38e5b to the usercache
  lfs: processed: 31cf46fbc4ecd458a0943c5b4881f1f5a6dd36c53d6167d5b69ac45149b38e5b
  lfs: downloading 37a65ab78d5ecda767e8622c248b5dbff1e68b1678ab0e730d5eb8601ec8ad19 (20 bytes)
  Status: 200
  Content-Length: 20
  Content-Type: text/plain; charset=utf-8 (git-server !)
  Content-Type: application/octet-stream (hg-server !)
  Date: $HTTP_DATE$
  Server: testing stub value (hg-server !)
  lfs: adding 37a65ab78d5ecda767e8622c248b5dbff1e68b1678ab0e730d5eb8601ec8ad19 to the usercache
  lfs: processed: 37a65ab78d5ecda767e8622c248b5dbff1e68b1678ab0e730d5eb8601ec8ad19
  lfs: downloading d11e1a642b60813aee592094109b406089b8dff4cb157157f753418ec7857998 (19 bytes)
  Status: 200
  Content-Length: 19
  Content-Type: text/plain; charset=utf-8 (git-server !)
  Content-Type: application/octet-stream (hg-server !)
  Date: $HTTP_DATE$
  Server: testing stub value (hg-server !)
  lfs: adding d11e1a642b60813aee592094109b406089b8dff4cb157157f753418ec7857998 to the usercache
  lfs: processed: d11e1a642b60813aee592094109b406089b8dff4cb157157f753418ec7857998
  lfs: found 31cf46fbc4ecd458a0943c5b4881f1f5a6dd36c53d6167d5b69ac45149b38e5b in the local lfs store
  lfs: found 31cf46fbc4ecd458a0943c5b4881f1f5a6dd36c53d6167d5b69ac45149b38e5b in the local lfs store
  lfs: found d11e1a642b60813aee592094109b406089b8dff4cb157157f753418ec7857998 in the local lfs store
  lfs: found 37a65ab78d5ecda767e8622c248b5dbff1e68b1678ab0e730d5eb8601ec8ad19 in the local lfs store
  $ find ../archive | sort
  ../archive
  ../archive/.hg_archival.txt
  ../archive/a
  ../archive/b
  ../archive/c
  ../archive/d

Cat will prefetch blobs in a group

  $ rm -rf .hg/store/lfs `hg config lfs.usercache`
  $ hg cat --debug -r 1 a b c
  http auth: user foo, password ***
  Status: 200
  Content-Length: 608 (git-server !)
  Content-Length: 670 (hg-server !)
  Content-Type: application/vnd.git-lfs+json
  Date: $HTTP_DATE$
  Server: testing stub value (hg-server !)
  {
    "objects": [
      {
        "actions": {
          "download": {
            "expires_at": "$ISO_8601_DATE_TIME$"
            "header": {
              "Accept": "application/vnd.git-lfs"
            }
            "href": "http://localhost:$HGPORT/*/31cf46fbc4ecd458a0943c5b4881f1f5a6dd36c53d6167d5b69ac45149b38e5b" (glob)
          }
        }
        "oid": "31cf46fbc4ecd458a0943c5b4881f1f5a6dd36c53d6167d5b69ac45149b38e5b"
        "size": 12
      }
      {
        "actions": {
          "download": {
            "expires_at": "$ISO_8601_DATE_TIME$"
            "header": {
              "Accept": "application/vnd.git-lfs"
            }
            "href": "http://localhost:$HGPORT/*/d11e1a642b60813aee592094109b406089b8dff4cb157157f753418ec7857998" (glob)
          }
        }
        "oid": "d11e1a642b60813aee592094109b406089b8dff4cb157157f753418ec7857998"
        "size": 19
      }
    ]
    "transfer": "basic" (hg-server !)
  }
  lfs: need to transfer 2 objects (31 bytes)
  lfs: downloading 31cf46fbc4ecd458a0943c5b4881f1f5a6dd36c53d6167d5b69ac45149b38e5b (12 bytes)
  Status: 200
  Content-Length: 12
  Content-Type: text/plain; charset=utf-8 (git-server !)
  Content-Type: application/octet-stream (hg-server !)
  Date: $HTTP_DATE$
  Server: testing stub value (hg-server !)
  lfs: adding 31cf46fbc4ecd458a0943c5b4881f1f5a6dd36c53d6167d5b69ac45149b38e5b to the usercache
  lfs: processed: 31cf46fbc4ecd458a0943c5b4881f1f5a6dd36c53d6167d5b69ac45149b38e5b
  lfs: downloading d11e1a642b60813aee592094109b406089b8dff4cb157157f753418ec7857998 (19 bytes)
  Status: 200
  Content-Length: 19
  Content-Type: text/plain; charset=utf-8 (git-server !)
  Content-Type: application/octet-stream (hg-server !)
  Date: $HTTP_DATE$
  Server: testing stub value (hg-server !)
  lfs: adding d11e1a642b60813aee592094109b406089b8dff4cb157157f753418ec7857998 to the usercache
  lfs: processed: d11e1a642b60813aee592094109b406089b8dff4cb157157f753418ec7857998
  lfs: found 31cf46fbc4ecd458a0943c5b4881f1f5a6dd36c53d6167d5b69ac45149b38e5b in the local lfs store
  THIS-IS-LFS
  lfs: found 31cf46fbc4ecd458a0943c5b4881f1f5a6dd36c53d6167d5b69ac45149b38e5b in the local lfs store
  THIS-IS-LFS
  lfs: found d11e1a642b60813aee592094109b406089b8dff4cb157157f753418ec7857998 in the local lfs store
  ANOTHER-LARGE-FILE

Revert will prefetch blobs in a group

  $ rm -rf .hg/store/lfs
  $ rm -rf `hg config lfs.usercache`
  $ rm *
  $ hg revert --all -r 1 --debug
  http auth: user foo, password ***
  adding a
  reverting b
  reverting c
  reverting d
  Status: 200
  Content-Length: 905 (git-server !)
  Content-Length: 988 (hg-server !)
  Content-Type: application/vnd.git-lfs+json
  Date: $HTTP_DATE$
  Server: testing stub value (hg-server !)
  {
    "objects": [
      {
        "actions": {
          "download": {
            "expires_at": "$ISO_8601_DATE_TIME$"
            "header": {
              "Accept": "application/vnd.git-lfs"
            }
            "href": "http://localhost:$HGPORT/*/31cf46fbc4ecd458a0943c5b4881f1f5a6dd36c53d6167d5b69ac45149b38e5b" (glob)
          }
        }
        "oid": "31cf46fbc4ecd458a0943c5b4881f1f5a6dd36c53d6167d5b69ac45149b38e5b"
        "size": 12
      }
      {
        "actions": {
          "download": {
            "expires_at": "$ISO_8601_DATE_TIME$"
            "header": {
              "Accept": "application/vnd.git-lfs"
            }
            "href": "http://localhost:$HGPORT/*/37a65ab78d5ecda767e8622c248b5dbff1e68b1678ab0e730d5eb8601ec8ad19" (glob)
          }
        }
        "oid": "37a65ab78d5ecda767e8622c248b5dbff1e68b1678ab0e730d5eb8601ec8ad19"
        "size": 20
      }
      {
        "actions": {
          "download": {
            "expires_at": "$ISO_8601_DATE_TIME$"
            "header": {
              "Accept": "application/vnd.git-lfs"
            }
            "href": "http://localhost:$HGPORT/*/d11e1a642b60813aee592094109b406089b8dff4cb157157f753418ec7857998" (glob)
          }
        }
        "oid": "d11e1a642b60813aee592094109b406089b8dff4cb157157f753418ec7857998"
        "size": 19
      }
    ]
    "transfer": "basic" (hg-server !)
  }
  lfs: need to transfer 3 objects (51 bytes)
  lfs: downloading 31cf46fbc4ecd458a0943c5b4881f1f5a6dd36c53d6167d5b69ac45149b38e5b (12 bytes)
  Status: 200
  Content-Length: 12
  Content-Type: text/plain; charset=utf-8 (git-server !)
  Content-Type: application/octet-stream (hg-server !)
  Date: $HTTP_DATE$
  Server: testing stub value (hg-server !)
  lfs: adding 31cf46fbc4ecd458a0943c5b4881f1f5a6dd36c53d6167d5b69ac45149b38e5b to the usercache
  lfs: processed: 31cf46fbc4ecd458a0943c5b4881f1f5a6dd36c53d6167d5b69ac45149b38e5b
  lfs: downloading 37a65ab78d5ecda767e8622c248b5dbff1e68b1678ab0e730d5eb8601ec8ad19 (20 bytes)
  Status: 200
  Content-Length: 20
  Content-Type: text/plain; charset=utf-8 (git-server !)
  Content-Type: application/octet-stream (hg-server !)
  Date: $HTTP_DATE$
  Server: testing stub value (hg-server !)
  lfs: adding 37a65ab78d5ecda767e8622c248b5dbff1e68b1678ab0e730d5eb8601ec8ad19 to the usercache
  lfs: processed: 37a65ab78d5ecda767e8622c248b5dbff1e68b1678ab0e730d5eb8601ec8ad19
  lfs: downloading d11e1a642b60813aee592094109b406089b8dff4cb157157f753418ec7857998 (19 bytes)
  Status: 200
  Content-Length: 19
  Content-Type: text/plain; charset=utf-8 (git-server !)
  Content-Type: application/octet-stream (hg-server !)
  Date: $HTTP_DATE$
  Server: testing stub value (hg-server !)
  lfs: adding d11e1a642b60813aee592094109b406089b8dff4cb157157f753418ec7857998 to the usercache
  lfs: processed: d11e1a642b60813aee592094109b406089b8dff4cb157157f753418ec7857998
  lfs: found 31cf46fbc4ecd458a0943c5b4881f1f5a6dd36c53d6167d5b69ac45149b38e5b in the local lfs store
  lfs: found d11e1a642b60813aee592094109b406089b8dff4cb157157f753418ec7857998 in the local lfs store
  lfs: found 37a65ab78d5ecda767e8622c248b5dbff1e68b1678ab0e730d5eb8601ec8ad19 in the local lfs store
  lfs: found 31cf46fbc4ecd458a0943c5b4881f1f5a6dd36c53d6167d5b69ac45149b38e5b in the local lfs store

Check error message when the remote missed a blob:

  $ echo FFFFF > b
  $ hg commit -m b -A b
  $ echo FFFFF >> b
  $ hg commit -m b b
  $ rm -rf .hg/store/lfs
  $ rm -rf `hg config lfs.usercache`
  $ hg update -C '.^' --debug
  http auth: user foo, password ***
  resolving manifests
   branchmerge: False, force: True, partial: False
   ancestor: 62fdbaf221c6+, local: 62fdbaf221c6+, remote: ef0564edf47e
  Status: 200
  Content-Length: 308 (git-server !)
  Content-Length: 186 (hg-server !)
  Content-Type: application/vnd.git-lfs+json
  Date: $HTTP_DATE$
  Server: testing stub value (hg-server !)
  {
    "objects": [
      {
        "actions": { (git-server !)
          "upload": { (git-server !)
            "expires_at": "$ISO_8601_DATE_TIME$" (git-server !)
            "header": { (git-server !)
              "Accept": "application/vnd.git-lfs" (git-server !)
            } (git-server !)
            "href": "http://localhost:$HGPORT/objects/8e6ea5f6c066b44a0efa43bcce86aea73f17e6e23f0663df0251e7524e140a13" (git-server !)
          } (git-server !)
        "error": { (hg-server !)
          "code": 404 (hg-server !)
          "message": "The object does not exist" (hg-server !)
        }
        "oid": "8e6ea5f6c066b44a0efa43bcce86aea73f17e6e23f0663df0251e7524e140a13"
        "size": 6
      }
    ]
    "transfer": "basic" (hg-server !)
  }
  abort: LFS server error. Remote object for "b" not found:(.*)! (re)
  [255]

Check error message when object does not exist:

  $ cd $TESTTMP
  $ hg init test && cd test
  $ echo "[extensions]" >> .hg/hgrc
  $ echo "lfs=" >> .hg/hgrc
  $ echo "[lfs]" >> .hg/hgrc
  $ echo "threshold=1" >> .hg/hgrc
  $ echo a > a
  $ hg add a
  $ hg commit -m 'test'
  $ echo aaaaa > a
  $ hg commit -m 'largefile'
  $ hg debugdata .hg/store/data/a.i 1 # verify this is no the file content but includes "oid", the LFS "pointer".
  version https://git-lfs.github.com/spec/v1
  oid sha256:bdc26931acfb734b142a8d675f205becf27560dc461f501822de13274fe6fc8a
  size 6
  x-is-binary 0
  $ cd ..
  $ rm -rf `hg config lfs.usercache`

(Restart the server in a different location so it no longer has the content)

  $ $PYTHON $RUNTESTDIR/killdaemons.py $DAEMON_PIDS

#if hg-server
  $ cat $TESTTMP/access.log $TESTTMP/errors.log
  $LOCALIP - - [$LOGDATE$] "POST /.git/info/lfs/objects/batch HTTP/1.1" 200 - (glob)
  $LOCALIP - - [$LOGDATE$] "PUT /.hg/lfs/objects/31cf46fbc4ecd458a0943c5b4881f1f5a6dd36c53d6167d5b69ac45149b38e5b HTTP/1.1" 201 - (glob)
  $LOCALIP - - [$LOGDATE$] "POST /.git/info/lfs/objects/batch HTTP/1.1" 200 - (glob)
  $LOCALIP - - [$LOGDATE$] "GET /.hg/lfs/objects/31cf46fbc4ecd458a0943c5b4881f1f5a6dd36c53d6167d5b69ac45149b38e5b HTTP/1.1" 200 - (glob)
  $LOCALIP - - [$LOGDATE$] "POST /.git/info/lfs/objects/batch HTTP/1.1" 200 - (glob)
  $LOCALIP - - [$LOGDATE$] "PUT /.hg/lfs/objects/37a65ab78d5ecda767e8622c248b5dbff1e68b1678ab0e730d5eb8601ec8ad19 HTTP/1.1" 201 - (glob)
  $LOCALIP - - [$LOGDATE$] "PUT /.hg/lfs/objects/d11e1a642b60813aee592094109b406089b8dff4cb157157f753418ec7857998 HTTP/1.1" 201 - (glob)
  $LOCALIP - - [$LOGDATE$] "POST /.git/info/lfs/objects/batch HTTP/1.1" 200 - (glob)
  $LOCALIP - - [$LOGDATE$] "GET /.hg/lfs/objects/37a65ab78d5ecda767e8622c248b5dbff1e68b1678ab0e730d5eb8601ec8ad19 HTTP/1.1" 200 - (glob)
  $LOCALIP - - [$LOGDATE$] "GET /.hg/lfs/objects/d11e1a642b60813aee592094109b406089b8dff4cb157157f753418ec7857998 HTTP/1.1" 200 - (glob)
  $LOCALIP - - [$LOGDATE$] "POST /.git/info/lfs/objects/batch HTTP/1.1" 200 - (glob)
  $LOCALIP - - [$LOGDATE$] "POST /.git/info/lfs/objects/batch HTTP/1.1" 200 - (glob)
  $LOCALIP - - [$LOGDATE$] "POST /.git/info/lfs/objects/batch HTTP/1.1" 200 - (glob)
  $LOCALIP - - [$LOGDATE$] "GET /.hg/lfs/objects/31cf46fbc4ecd458a0943c5b4881f1f5a6dd36c53d6167d5b69ac45149b38e5b HTTP/1.1" 200 - (glob)
  $LOCALIP - - [$LOGDATE$] "GET /.hg/lfs/objects/37a65ab78d5ecda767e8622c248b5dbff1e68b1678ab0e730d5eb8601ec8ad19 HTTP/1.1" 200 - (glob)
  $LOCALIP - - [$LOGDATE$] "GET /.hg/lfs/objects/d11e1a642b60813aee592094109b406089b8dff4cb157157f753418ec7857998 HTTP/1.1" 200 - (glob)
  $LOCALIP - - [$LOGDATE$] "POST /.git/info/lfs/objects/batch HTTP/1.1" 200 - (glob)
  $LOCALIP - - [$LOGDATE$] "GET /.hg/lfs/objects/31cf46fbc4ecd458a0943c5b4881f1f5a6dd36c53d6167d5b69ac45149b38e5b HTTP/1.1" 200 - (glob)
  $LOCALIP - - [$LOGDATE$] "GET /.hg/lfs/objects/d11e1a642b60813aee592094109b406089b8dff4cb157157f753418ec7857998 HTTP/1.1" 200 - (glob)
  $LOCALIP - - [$LOGDATE$] "POST /.git/info/lfs/objects/batch HTTP/1.1" 200 - (glob)
  $LOCALIP - - [$LOGDATE$] "GET /.hg/lfs/objects/31cf46fbc4ecd458a0943c5b4881f1f5a6dd36c53d6167d5b69ac45149b38e5b HTTP/1.1" 200 - (glob)
  $LOCALIP - - [$LOGDATE$] "GET /.hg/lfs/objects/37a65ab78d5ecda767e8622c248b5dbff1e68b1678ab0e730d5eb8601ec8ad19 HTTP/1.1" 200 - (glob)
  $LOCALIP - - [$LOGDATE$] "GET /.hg/lfs/objects/d11e1a642b60813aee592094109b406089b8dff4cb157157f753418ec7857998 HTTP/1.1" 200 - (glob)
  $LOCALIP - - [$LOGDATE$] "POST /.git/info/lfs/objects/batch HTTP/1.1" 200 - (glob)
#endif

  $ rm $DAEMON_PIDS
  $ mkdir $TESTTMP/lfs-server2
  $ cd $TESTTMP/lfs-server2
#if no-windows git-server
  $ lfs-test-server &> lfs-server.log &
  $ echo $! >> $DAEMON_PIDS
#endif

#if windows git-server
  $ $PYTHON $TESTTMP/spawn.py >> $DAEMON_PIDS
#endif

#if hg-server
  $ hg init server2
  $ hg --config "lfs.usercache=$TESTTMP/servercache2" -R server2 serve -d \
  >    -p $HGPORT --pid-file=hg.pid -A $TESTTMP/access.log -E $TESTTMP/errors.log
  $ cat hg.pid >> $DAEMON_PIDS
#endif

  $ cd $TESTTMP
  $ hg --debug clone test test2
  http auth: user foo, password ***
  linked 6 files
  http auth: user foo, password ***
  updating to branch default
  resolving manifests
   branchmerge: False, force: False, partial: False
   ancestor: 000000000000, local: 000000000000+, remote: d2a338f184a8
  Status: 200
  Content-Length: 308 (git-server !)
  Content-Length: 186 (hg-server !)
  Content-Type: application/vnd.git-lfs+json
  Date: $HTTP_DATE$
  Server: testing stub value (hg-server !)
  {
    "objects": [
      {
        "actions": { (git-server !)
          "upload": { (git-server !)
            "expires_at": "$ISO_8601_DATE_TIME$" (git-server !)
            "header": { (git-server !)
              "Accept": "application/vnd.git-lfs" (git-server !)
            } (git-server !)
            "href": "http://localhost:$HGPORT/objects/bdc26931acfb734b142a8d675f205becf27560dc461f501822de13274fe6fc8a" (git-server !)
          } (git-server !)
        "error": { (hg-server !)
          "code": 404 (hg-server !)
          "message": "The object does not exist" (hg-server !)
        }
        "oid": "bdc26931acfb734b142a8d675f205becf27560dc461f501822de13274fe6fc8a"
        "size": 6
      }
    ]
    "transfer": "basic" (hg-server !)
  }
  abort: LFS server error. Remote object for "a" not found:(.*)! (re)
  [255]

  $ $PYTHON $RUNTESTDIR/killdaemons.py $DAEMON_PIDS
