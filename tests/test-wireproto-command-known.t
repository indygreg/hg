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

  $ hg log -T '{rev}:{node} {desc}\n'
  3:be0ef73c17ade3fc89dc41701eb9fc3a91b58282 D
  2:26805aba1e600a82e93661149f2313866a221a7b C
  1:112478962961147124edd43549aedd1a335e44bf B
  0:426bada5c67598ca65036d57d9e4b64b0c1ce7a0 A

  $ hg serve -p $HGPORT -d --pid-file hg.pid -E error.log
  $ cat hg.pid > $DAEMON_PIDS

No arguments returns something reasonable

  $ sendhttpv2peer << EOF
  > command known
  > EOF
  creating http peer for wire protocol version 2
  sending known command
  response: []

Single known node works

  $ sendhttpv2peer << EOF
  > command known
  >     nodes eval:[b'\x42\x6b\xad\xa5\xc6\x75\x98\xca\x65\x03\x6d\x57\xd9\xe4\xb6\x4b\x0c\x1c\xe7\xa0']
  > EOF
  creating http peer for wire protocol version 2
  sending known command
  response: [
    True
  ]

Multiple nodes works

  $ sendhttpv2peer << EOF
  > command known
  >     nodes eval:[b'\x42\x6b\xad\xa5\xc6\x75\x98\xca\x65\x03\x6d\x57\xd9\xe4\xb6\x4b\x0c\x1c\xe7\xa0', b'00000000000000000000', b'\x11\x24\x78\x96\x29\x61\x14\x71\x24\xed\xd4\x35\x49\xae\xdd\x1a\x33\x5e\x44\xbf']
  > EOF
  creating http peer for wire protocol version 2
  sending known command
  response: [
    True,
    False,
    True
  ]

  $ cat error.log
