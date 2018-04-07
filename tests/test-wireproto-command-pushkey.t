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
  s>     *\r\n (glob)
  s>     Accept-Encoding: identity\r\n
  s>     accept: application/mercurial-exp-framing-0003\r\n
  s>     content-type: application/mercurial-exp-framing-0003\r\n
  s>     content-length: 105\r\n
  s>     host: $LOCALIP:$HGPORT\r\n (glob)
  s>     user-agent: Mercurial debugwireproto\r\n
  s>     \r\n
  s>     a\x00\x00\x01\x00\x01\x01\x11\xa2Dargs\xa4CkeyA@CnewX(426bada5c67598ca65036d57d9e4b64b0c1ce7a0Cold@InamespaceIbookmarksDnameGpushkey
  s> makefile('rb', None)
  s>     HTTP/1.1 200 OK\r\n
  s>     Server: testing stub value\r\n
  s>     Date: $HTTP_DATE$\r\n
  s>     Content-Type: application/mercurial-exp-framing-0003\r\n
  s>     Transfer-Encoding: chunked\r\n
  s>     \r\n
  s>     9\r\n
  s>     *\x00\x01\x00\x02\x01F (glob)
  s>     \xf5
  s>     \r\n
  received frame(size=*; request=1; stream=2; streamflags=stream-begin; type=bytes-response; flags=eos|cbor) (glob)
  s>     0\r\n
  s>     \r\n
  response: []

  $ sendhttpv2peer << EOF
  > command listkeys
  >     namespace bookmarks
  > EOF
  creating http peer for wire protocol version 2
  sending listkeys command
  s>     POST /api/exp-http-v2-0001/ro/listkeys HTTP/1.1\r\n
  s>     Accept-Encoding: identity\r\n
  s>     accept: application/mercurial-exp-framing-0003\r\n
  s>     content-type: application/mercurial-exp-framing-0003\r\n
  s>     content-length: 49\r\n
  s>     host: $LOCALIP:$HGPORT\r\n (glob)
  s>     user-agent: Mercurial debugwireproto\r\n
  s>     \r\n
  s>     )\x00\x00\x01\x00\x01\x01\x11\xa2Dargs\xa1InamespaceIbookmarksDnameHlistkeys
  s> makefile('rb', None)
  s>     HTTP/1.1 200 OK\r\n
  s>     Server: testing stub value\r\n
  s>     Date: $HTTP_DATE$\r\n
  s>     Content-Type: application/mercurial-exp-framing-0003\r\n
  s>     Transfer-Encoding: chunked\r\n
  s>     \r\n
  s>     35\r\n
  s>     -\x00\x00\x01\x00\x02\x01F
  s>     \xa1A@X(426bada5c67598ca65036d57d9e4b64b0c1ce7a0
  s>     \r\n
  received frame(size=45; request=1; stream=2; streamflags=stream-begin; type=bytes-response; flags=eos|cbor)
  s>     0\r\n
  s>     \r\n
  response: [{b'@': b'426bada5c67598ca65036d57d9e4b64b0c1ce7a0'}]

  $ cat error.log
