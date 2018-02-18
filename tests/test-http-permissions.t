#require killdaemons

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
  $ cd ../test

expect authorization error: all users denied

  $ cat > .hg/hgrc <<EOF
  > [web]
  > push_ssl = false
  > deny_push = *
  > EOF

  $ hg serve -p $HGPORT -d --pid-file hg.pid
  $ cat hg.pid > $DAEMON_PIDS

  $ hg --cwd ../test2 push http://localhost:$HGPORT/
  pushing to http://localhost:$HGPORT/
  searching for changes
  abort: authorization failed
  [255]

  $ killdaemons.py

expect authorization error: some users denied, users must be authenticated

  $ cat > .hg/hgrc <<EOF
  > [web]
  > push_ssl = false
  > deny_push = unperson
  > EOF

  $ hg serve -p $HGPORT -d --pid-file hg.pid
  $ cat hg.pid > $DAEMON_PIDS
  $ hg --cwd ../test2 push http://localhost:$HGPORT/
  pushing to http://localhost:$HGPORT/
  searching for changes
  abort: authorization failed
  [255]

  $ killdaemons.py
