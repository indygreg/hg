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

lookup for known node works

  $ sendhttpv2peer << EOF
  > command lookup
  >     key 426bada5c67598ca65036d57d9e4b64b0c1ce7a0
  > EOF
  creating http peer for wire protocol version 2
  sending lookup command
  s>     *\r\n (glob)
  s>     Accept-Encoding: identity\r\n
  s>     accept: application/mercurial-exp-framing-0003\r\n
  s>     content-type: application/mercurial-exp-framing-0003\r\n
  s>     content-length: 73\r\n
  s>     host: $LOCALIP:$HGPORT\r\n (glob)
  s>     user-agent: Mercurial debugwireproto\r\n
  s>     \r\n
  s>     A\x00\x00\x01\x00\x01\x01\x11\xa2Dargs\xa1CkeyX(426bada5c67598ca65036d57d9e4b64b0c1ce7a0DnameFlookup
  s> makefile('rb', None)
  s>     HTTP/1.1 200 OK\r\n
  s>     Server: testing stub value\r\n
  s>     Date: $HTTP_DATE$\r\n
  s>     Content-Type: application/mercurial-exp-framing-0003\r\n
  s>     Transfer-Encoding: chunked\r\n
  s>     \r\n
  s>     1d\r\n
  s>     *\x00\x01\x00\x02\x01F (glob)
  s>     TBk\xad\xa5\xc6u\x98\xcae\x03mW\xd9\xe4\xb6K\x0c\x1c\xe7\xa0
  s>     \r\n
  received frame(size=*; request=1; stream=2; streamflags=stream-begin; type=bytes-response; flags=eos|cbor) (glob)
  s>     0\r\n
  s>     \r\n
  response: b'Bk\xad\xa5\xc6u\x98\xcae\x03mW\xd9\xe4\xb6K\x0c\x1c\xe7\xa0'

  $ cat error.log
