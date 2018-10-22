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

  $ hg up B
  2 files updated, 0 files merged, 0 files removed, 0 files unresolved
  $ hg branch branch1
  marked working directory as branch branch1
  (branches are permanent and global, did you want a bookmark?)
  $ echo b1 > foo
  $ hg -q commit -A -m 'branch 1'
  $ hg up B
  0 files updated, 0 files merged, 1 files removed, 0 files unresolved
  $ hg branch branch2
  marked working directory as branch branch2
  $ echo b2 > foo
  $ hg -q commit -A -m 'branch 2'

  $ hg log -T '{rev}:{node} {branch} {desc}\n'
  5:224161c7589aa48fa83a48feff5e95b56ae327fc branch2 branch 2
  4:b5faacdfd2633768cb3152336cc0953381266688 branch1 branch 1
  3:be0ef73c17ade3fc89dc41701eb9fc3a91b58282 default D
  2:26805aba1e600a82e93661149f2313866a221a7b default C
  1:112478962961147124edd43549aedd1a335e44bf default B
  0:426bada5c67598ca65036d57d9e4b64b0c1ce7a0 default A

  $ hg serve -p $HGPORT -d --pid-file hg.pid -E error.log
  $ cat hg.pid > $DAEMON_PIDS

No arguments returns something reasonable

  $ sendhttpv2peer << EOF
  > command branchmap
  > EOF
  creating http peer for wire protocol version 2
  sending branchmap command
  response: {
    b'branch1': [
      b'\xb5\xfa\xac\xdf\xd2c7h\xcb1R3l\xc0\x953\x81&f\x88'
    ],
    b'branch2': [
      b'"Aa\xc7X\x9a\xa4\x8f\xa8:H\xfe\xff^\x95\xb5j\xe3\'\xfc'
    ],
    b'default': [
      b'&\x80Z\xba\x1e`\n\x82\xe96a\x14\x9f#\x13\x86j"\x1a{',
      b'\xbe\x0e\xf7<\x17\xad\xe3\xfc\x89\xdcAp\x1e\xb9\xfc:\x91\xb5\x82\x82'
    ]
  }

  $ cat error.log
