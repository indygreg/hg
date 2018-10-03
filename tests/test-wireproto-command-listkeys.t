  $ . $TESTDIR/wireprotohelpers.sh

  $ hg init server
  $ enablehttpv2 server
  $ cd server
  $ hg debugdrawdag << EOF
  > C D
  > |/
  > B
  > |
  > A
  > EOF

  $ hg phase --public -r C
  $ hg book -r C @

  $ hg log -T '{rev}:{node} {desc}\n'
  3:be0ef73c17ade3fc89dc41701eb9fc3a91b58282 D
  2:26805aba1e600a82e93661149f2313866a221a7b C
  1:112478962961147124edd43549aedd1a335e44bf B
  0:426bada5c67598ca65036d57d9e4b64b0c1ce7a0 A

  $ hg serve -p $HGPORT -d --pid-file hg.pid -E error.log
  $ cat hg.pid > $DAEMON_PIDS

Request for namespaces works

  $ sendhttpv2peer << EOF
  > command listkeys
  >     namespace namespaces
  > EOF
  creating http peer for wire protocol version 2
  sending listkeys command
  response: {
    b'bookmarks': b'',
    b'namespaces': b'',
    b'phases': b''
  }

Request for phases works

  $ sendhttpv2peer << EOF
  > command listkeys
  >     namespace phases
  > EOF
  creating http peer for wire protocol version 2
  sending listkeys command
  response: {
    b'be0ef73c17ade3fc89dc41701eb9fc3a91b58282': b'1',
    b'publishing': b'True'
  }

Request for bookmarks works

  $ sendhttpv2peer << EOF
  > command listkeys
  >     namespace bookmarks
  > EOF
  creating http peer for wire protocol version 2
  sending listkeys command
  response: {
    b'@': b'26805aba1e600a82e93661149f2313866a221a7b'
  }

  $ cat error.log
