#require killdaemons

#testcases bundle1 bundle2

#if bundle1
  $ cat << EOF >> $HGRCPATH
  > [devel]
  > # This test is dedicated to interaction through old bundle
  > legacy.exchange = bundle1
  > EOF
#endif

  $ hg init test
  $ cd test
  $ echo a > a
  $ hg ci -Ama
  adding a
  $ cd ..
  $ hg clone test test2
  updating to branch default
  1 files updated, 0 files merged, 0 files removed, 0 files unresolved
  $ cd test2
  $ echo a >> a
  $ hg ci -mb
  $ req() {
  >     hg $1 serve -p $HGPORT -d --pid-file=hg.pid -E errors.log
  >     cat hg.pid >> $DAEMON_PIDS
  >     hg --cwd ../test2 push http://localhost:$HGPORT/
  >     exitstatus=$?
  >     killdaemons.py
  >     echo % serve errors
  >     cat errors.log
  >     return $exitstatus
  > }
  $ cd ../test

expect ssl error

  $ req
  pushing to http://localhost:$HGPORT/
  searching for changes
  abort: HTTP Error 403: ssl required
  % serve errors
  [255]

expect authorization error

  $ echo '[web]' > .hg/hgrc
  $ echo 'push_ssl = false' >> .hg/hgrc
  $ req
  pushing to http://localhost:$HGPORT/
  searching for changes
  abort: authorization failed
  % serve errors
  [255]

expect authorization error: must have authorized user

  $ echo 'allow_push = unperson' >> .hg/hgrc
  $ req
  pushing to http://localhost:$HGPORT/
  searching for changes
  abort: authorization failed
  % serve errors
  [255]

expect success

  $ cat > $TESTTMP/hook.sh <<'EOF'
  > echo "phase-move: $HG_NODE:  $HG_OLDPHASE -> $HG_PHASE"
  > EOF

#if bundle1
  $ cat >> .hg/hgrc <<EOF
  > allow_push = *
  > [hooks]
  > changegroup = sh -c "printenv.py changegroup 0"
  > pushkey = sh -c "printenv.py pushkey 0"
  > txnclose-phase.test = sh $TESTTMP/hook.sh 
  > EOF
  $ req "--debug --config extensions.blackbox="
  listening at http://localhost:$HGPORT/ (bound to $LOCALIP:$HGPORT)
  pushing to http://localhost:$HGPORT/
  searching for changes
  remote: redirecting incoming bundle to */hg-unbundle-* (glob)
  remote: adding changesets
  remote: add changeset ba677d0156c1
  remote: adding manifests
  remote: adding file changes
  remote: adding a revisions
  remote: added 1 changesets with 1 changes to 1 files
  remote: updating the branch cache
  remote: running hook txnclose-phase.test: sh $TESTTMP/hook.sh
  remote: phase-move: cb9a9f314b8b07ba71012fcdbc544b5a4d82ff5b:  draft -> public
  remote: running hook txnclose-phase.test: sh $TESTTMP/hook.sh
  remote: phase-move: ba677d0156c1196c1a699fa53f390dcfc3ce3872:   -> public
  remote: running hook changegroup: sh -c "printenv.py changegroup 0"
  remote: changegroup hook: HG_HOOKNAME=changegroup HG_HOOKTYPE=changegroup HG_NODE=ba677d0156c1196c1a699fa53f390dcfc3ce3872 HG_NODE_LAST=ba677d0156c1196c1a699fa53f390dcfc3ce3872 HG_SOURCE=serve HG_TXNID=TXN:$ID$ HG_URL=remote:http:$LOCALIP: (glob)
  % serve errors
  $ hg rollback
  repository tip rolled back to revision 0 (undo serve)
  $ req "--debug --config server.streamunbundle=True --config extensions.blackbox="
  listening at http://localhost:$HGPORT/ (bound to $LOCALIP:$HGPORT)
  pushing to http://localhost:$HGPORT/
  searching for changes
  remote: adding changesets
  remote: add changeset ba677d0156c1
  remote: adding manifests
  remote: adding file changes
  remote: adding a revisions
  remote: added 1 changesets with 1 changes to 1 files
  remote: updating the branch cache
  remote: running hook txnclose-phase.test: sh $TESTTMP/hook.sh
  remote: phase-move: cb9a9f314b8b07ba71012fcdbc544b5a4d82ff5b:  draft -> public
  remote: running hook txnclose-phase.test: sh $TESTTMP/hook.sh
  remote: phase-move: ba677d0156c1196c1a699fa53f390dcfc3ce3872:   -> public
  remote: running hook changegroup: sh -c "printenv.py changegroup 0"
  remote: changegroup hook: HG_HOOKNAME=changegroup HG_HOOKTYPE=changegroup HG_NODE=ba677d0156c1196c1a699fa53f390dcfc3ce3872 HG_NODE_LAST=ba677d0156c1196c1a699fa53f390dcfc3ce3872 HG_SOURCE=serve HG_TXNID=TXN:$ID$ HG_URL=remote:http:$LOCALIP: (glob)
  % serve errors
  $ hg rollback
  repository tip rolled back to revision 0 (undo serve)
#endif

#if bundle2
  $ cat >> .hg/hgrc <<EOF
  > allow_push = *
  > [hooks]
  > changegroup = sh -c "printenv.py changegroup 0"
  > pushkey = sh -c "printenv.py pushkey 0"
  > txnclose-phase.test = sh $TESTTMP/hook.sh 
  > EOF
  $ req
  pushing to http://localhost:$HGPORT/
  searching for changes
  remote: adding changesets
  remote: adding manifests
  remote: adding file changes
  remote: added 1 changesets with 1 changes to 1 files
  remote: phase-move: cb9a9f314b8b07ba71012fcdbc544b5a4d82ff5b:  draft -> public
  remote: phase-move: ba677d0156c1196c1a699fa53f390dcfc3ce3872:   -> public
  remote: changegroup hook: HG_BUNDLE2=1 HG_HOOKNAME=changegroup HG_HOOKTYPE=changegroup HG_NODE=ba677d0156c1196c1a699fa53f390dcfc3ce3872 HG_NODE_LAST=ba677d0156c1196c1a699fa53f390dcfc3ce3872 HG_SOURCE=serve HG_TXNID=TXN:$ID$ HG_URL=remote:http:$LOCALIP: (glob)
  % serve errors
  $ hg rollback
  repository tip rolled back to revision 0 (undo serve)
#endif

expect success, server lacks the httpheader capability

  $ CAP=httpheader
  $ . "$TESTDIR/notcapable"
  $ req
  pushing to http://localhost:$HGPORT/
  searching for changes
  remote: adding changesets
  remote: adding manifests
  remote: adding file changes
  remote: added 1 changesets with 1 changes to 1 files
  remote: phase-move: cb9a9f314b8b07ba71012fcdbc544b5a4d82ff5b:  draft -> public
  remote: phase-move: ba677d0156c1196c1a699fa53f390dcfc3ce3872:   -> public
  remote: changegroup hook: HG_HOOKNAME=changegroup HG_HOOKTYPE=changegroup HG_NODE=ba677d0156c1196c1a699fa53f390dcfc3ce3872 HG_NODE_LAST=ba677d0156c1196c1a699fa53f390dcfc3ce3872 HG_SOURCE=serve HG_TXNID=TXN:$ID$ HG_URL=remote:http:$LOCALIP: (glob) (bundle1 !)
  remote: changegroup hook: HG_BUNDLE2=1 HG_HOOKNAME=changegroup HG_HOOKTYPE=changegroup HG_NODE=ba677d0156c1196c1a699fa53f390dcfc3ce3872 HG_NODE_LAST=ba677d0156c1196c1a699fa53f390dcfc3ce3872 HG_SOURCE=serve HG_TXNID=TXN:$ID$ HG_URL=remote:http:$LOCALIP: (glob) (bundle2 !)
  % serve errors
  $ hg rollback
  repository tip rolled back to revision 0 (undo serve)

expect success, server lacks the unbundlehash capability

  $ CAP=unbundlehash
  $ . "$TESTDIR/notcapable"
  $ req
  pushing to http://localhost:$HGPORT/
  searching for changes
  remote: adding changesets
  remote: adding manifests
  remote: adding file changes
  remote: added 1 changesets with 1 changes to 1 files
  remote: phase-move: cb9a9f314b8b07ba71012fcdbc544b5a4d82ff5b:  draft -> public
  remote: phase-move: ba677d0156c1196c1a699fa53f390dcfc3ce3872:   -> public
  remote: changegroup hook: HG_HOOKNAME=changegroup HG_HOOKTYPE=changegroup HG_NODE=ba677d0156c1196c1a699fa53f390dcfc3ce3872 HG_NODE_LAST=ba677d0156c1196c1a699fa53f390dcfc3ce3872 HG_SOURCE=serve HG_TXNID=TXN:$ID$ HG_URL=remote:http:$LOCALIP: (glob) (bundle1 !)
  remote: changegroup hook: HG_BUNDLE2=1 HG_HOOKNAME=changegroup HG_HOOKTYPE=changegroup HG_NODE=ba677d0156c1196c1a699fa53f390dcfc3ce3872 HG_NODE_LAST=ba677d0156c1196c1a699fa53f390dcfc3ce3872 HG_SOURCE=serve HG_TXNID=TXN:$ID$ HG_URL=remote:http:$LOCALIP: (glob) (bundle2 !)
  % serve errors
  $ hg rollback
  repository tip rolled back to revision 0 (undo serve)

expect success, pre-d1b16a746db6 server supports the unbundle capability, but
has no parameter

  $ cat <<EOF > notcapable-unbundleparam.py
  > from mercurial import extensions, httppeer
  > def capable(orig, self, name):
  >     if name == 'unbundle':
  >         return True
  >     return orig(self, name)
  > def uisetup(ui):
  >     extensions.wrapfunction(httppeer.httppeer, 'capable', capable)
  > EOF
  $ cp $HGRCPATH $HGRCPATH.orig
  $ cat <<EOF >> $HGRCPATH
  > [extensions]
  > notcapable-unbundleparam = `pwd`/notcapable-unbundleparam.py
  > EOF
  $ req
  pushing to http://localhost:$HGPORT/
  searching for changes
  remote: adding changesets
  remote: adding manifests
  remote: adding file changes
  remote: added 1 changesets with 1 changes to 1 files
  remote: phase-move: cb9a9f314b8b07ba71012fcdbc544b5a4d82ff5b:  draft -> public
  remote: phase-move: ba677d0156c1196c1a699fa53f390dcfc3ce3872:   -> public
  remote: changegroup hook: * (glob)
  % serve errors
  $ hg rollback
  repository tip rolled back to revision 0 (undo serve)
  $ mv $HGRCPATH.orig $HGRCPATH

Test pushing to a publishing repository with a failing prepushkey hook

  $ cat > .hg/hgrc <<EOF
  > [web]
  > push_ssl = false
  > allow_push = *
  > [hooks]
  > prepushkey = sh -c "printenv.py prepushkey 1"
  > [devel]
  > legacy.exchange=phases
  > EOF

#if bundle1
Bundle1 works because a) phases are updated as part of changegroup application
and b) client checks phases after the "unbundle" command. Since it sees no
phase changes are necessary, it doesn't send the "pushkey" command and the
prepushkey hook never has to fire.

  $ req
  pushing to http://localhost:$HGPORT/
  searching for changes
  remote: adding changesets
  remote: adding manifests
  remote: adding file changes
  remote: added 1 changesets with 1 changes to 1 files
  % serve errors

#endif

#if bundle2
Bundle2 sends a "pushkey" bundle2 part. This runs as part of the transaction
and fails the entire push.
  $ req
  pushing to http://localhost:$HGPORT/
  searching for changes
  remote: adding changesets
  remote: adding manifests
  remote: adding file changes
  remote: added 1 changesets with 1 changes to 1 files
  remote: prepushkey hook: HG_BUNDLE2=1 HG_HOOKNAME=prepushkey HG_HOOKTYPE=prepushkey HG_KEY=ba677d0156c1196c1a699fa53f390dcfc3ce3872 HG_NAMESPACE=phases HG_NEW=0 HG_NODE=ba677d0156c1196c1a699fa53f390dcfc3ce3872 HG_NODE_LAST=ba677d0156c1196c1a699fa53f390dcfc3ce3872 HG_OLD=1 HG_PENDING=$TESTTMP/test HG_PHASES_MOVED=1 HG_SOURCE=serve HG_TXNID=TXN:$ID$ HG_URL=remote:http:$LOCALIP: (glob)
  remote: pushkey-abort: prepushkey hook exited with status 1
  remote: transaction abort!
  remote: rollback completed
  abort: updating ba677d0156c1 to public failed
  % serve errors
  [255]

#endif

Now remove the failing prepushkey hook.

  $ cat >> .hg/hgrc <<EOF
  > [hooks]
  > prepushkey = sh -c "printenv.py prepushkey 0"
  > EOF

We don't need to test bundle1 because it succeeded above.

#if bundle2
  $ req
  pushing to http://localhost:$HGPORT/
  searching for changes
  remote: adding changesets
  remote: adding manifests
  remote: adding file changes
  remote: added 1 changesets with 1 changes to 1 files
  remote: prepushkey hook: HG_BUNDLE2=1 HG_HOOKNAME=prepushkey HG_HOOKTYPE=prepushkey HG_KEY=ba677d0156c1196c1a699fa53f390dcfc3ce3872 HG_NAMESPACE=phases HG_NEW=0 HG_NODE=ba677d0156c1196c1a699fa53f390dcfc3ce3872 HG_NODE_LAST=ba677d0156c1196c1a699fa53f390dcfc3ce3872 HG_OLD=1 HG_PENDING=$TESTTMP/test HG_PHASES_MOVED=1 HG_SOURCE=serve HG_TXNID=TXN:$ID$ HG_URL=remote:http:$LOCALIP: (glob)
  % serve errors
#endif

  $ hg --config extensions.strip= strip -r 1:
  saved backup bundle to $TESTTMP/test/.hg/strip-backup/ba677d0156c1-eea704d7-backup.hg

Now do a variant of the above, except on a non-publishing repository

  $ cat >> .hg/hgrc <<EOF
  > [phases]
  > publish = false
  > [hooks]
  > prepushkey = sh -c "printenv.py prepushkey 1"
  > EOF

#if bundle1
  $ req
  pushing to http://localhost:$HGPORT/
  searching for changes
  remote: adding changesets
  remote: adding manifests
  remote: adding file changes
  remote: added 1 changesets with 1 changes to 1 files
  remote: prepushkey hook: HG_HOOKNAME=prepushkey HG_HOOKTYPE=prepushkey HG_KEY=ba677d0156c1196c1a699fa53f390dcfc3ce3872 HG_NAMESPACE=phases HG_NEW=0 HG_OLD=1
  remote: pushkey-abort: prepushkey hook exited with status 1
  updating ba677d0156c1 to public failed!
  % serve errors
#endif

#if bundle2
  $ req
  pushing to http://localhost:$HGPORT/
  searching for changes
  remote: adding changesets
  remote: adding manifests
  remote: adding file changes
  remote: added 1 changesets with 1 changes to 1 files
  remote: prepushkey hook: HG_BUNDLE2=1 HG_HOOKNAME=prepushkey HG_HOOKTYPE=prepushkey HG_KEY=ba677d0156c1196c1a699fa53f390dcfc3ce3872 HG_NAMESPACE=phases HG_NEW=0 HG_NODE=ba677d0156c1196c1a699fa53f390dcfc3ce3872 HG_NODE_LAST=ba677d0156c1196c1a699fa53f390dcfc3ce3872 HG_OLD=1 HG_PENDING=$TESTTMP/test HG_PHASES_MOVED=1 HG_SOURCE=serve HG_TXNID=TXN:$ID$ HG_URL=remote:http:$LOCALIP: (glob)
  remote: pushkey-abort: prepushkey hook exited with status 1
  remote: transaction abort!
  remote: rollback completed
  abort: updating ba677d0156c1 to public failed
  % serve errors
  [255]
#endif

Make phases updates work

  $ cat >> .hg/hgrc <<EOF
  > [hooks]
  > prepushkey = sh -c "printenv.py prepushkey 0"
  > EOF

#if bundle1
  $ req
  pushing to http://localhost:$HGPORT/
  searching for changes
  no changes found
  remote: prepushkey hook: HG_HOOKNAME=prepushkey HG_HOOKTYPE=prepushkey HG_KEY=ba677d0156c1196c1a699fa53f390dcfc3ce3872 HG_NAMESPACE=phases HG_NEW=0 HG_OLD=1
  % serve errors
  [1]
#endif

#if bundle2
  $ req
  pushing to http://localhost:$HGPORT/
  searching for changes
  remote: adding changesets
  remote: adding manifests
  remote: adding file changes
  remote: added 1 changesets with 1 changes to 1 files
  remote: prepushkey hook: HG_BUNDLE2=1 HG_HOOKNAME=prepushkey HG_HOOKTYPE=prepushkey HG_KEY=ba677d0156c1196c1a699fa53f390dcfc3ce3872 HG_NAMESPACE=phases HG_NEW=0 HG_NODE=ba677d0156c1196c1a699fa53f390dcfc3ce3872 HG_NODE_LAST=ba677d0156c1196c1a699fa53f390dcfc3ce3872 HG_OLD=1 HG_PENDING=$TESTTMP/test HG_PHASES_MOVED=1 HG_SOURCE=serve HG_TXNID=TXN:$ID$ HG_URL=remote:http:$LOCALIP: (glob)
  % serve errors
#endif

  $ hg --config extensions.strip= strip -r 1:
  saved backup bundle to $TESTTMP/test/.hg/strip-backup/ba677d0156c1-eea704d7-backup.hg

#if bundle2

  $ cat > .hg/hgrc <<EOF
  > [web]
  > push_ssl = false
  > allow_push = *
  > [experimental]
  > httppostargs=true
  > EOF
  $ req
  pushing to http://localhost:$HGPORT/
  searching for changes
  remote: adding changesets
  remote: adding manifests
  remote: adding file changes
  remote: added 1 changesets with 1 changes to 1 files
  % serve errors

#endif

  $ cd ..
