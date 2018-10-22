  $ . $TESTDIR/wireprotohelpers.sh

  $ hg init server
  $ enablehttpv2 server
  $ cd server
  $ cat >> .hg/hgrc << EOF
  > [web]
  > push_ssl = false
  > allow-push = *
  > EOF
  $ hg debugdrawdag << EOF
  > C D
  > |/
  > B
  > |
  > A
  > EOF

  $ hg serve -p $HGPORT -d --pid-file hg.pid -E error.log
  $ cat hg.pid > $DAEMON_PIDS

pushkey for a bookmark works

  $ sendhttpv2peer << EOF
  > command pushkey
  >     namespace bookmarks
  >     key @
  >     old
  >     new 426bada5c67598ca65036d57d9e4b64b0c1ce7a0
  > EOF
  creating http peer for wire protocol version 2
  sending pushkey command
  response: True

  $ sendhttpv2peer << EOF
  > command listkeys
  >     namespace bookmarks
  > EOF
  creating http peer for wire protocol version 2
  sending listkeys command
  response: {
    b'@': b'426bada5c67598ca65036d57d9e4b64b0c1ce7a0'
  }

  $ cat error.log
