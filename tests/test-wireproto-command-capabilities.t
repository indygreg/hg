  $ . $TESTDIR/wireprotohelpers.sh

  $ hg init server
  $ enablehttpv2 server
  $ hg -R server serve -p $HGPORT -d --pid-file hg.pid -E error.log
  $ cat hg.pid > $DAEMON_PIDS

capabilities request returns an array of capability strings

  $ sendhttpv2peer << EOF
  > command capabilities
  > EOF
  creating http peer for wire protocol version 2
  sending capabilities command
  s>     POST /api/exp-http-v2-0001/ro/capabilities HTTP/1.1\r\n
  s>     Accept-Encoding: identity\r\n
  s>     accept: application/mercurial-exp-framing-0003\r\n
  s>     content-type: application/mercurial-exp-framing-0003\r\n
  s>     content-length: 27\r\n
  s>     host: $LOCALIP:$HGPORT\r\n (glob)
  s>     user-agent: Mercurial debugwireproto\r\n
  s>     \r\n
  s>     \x13\x00\x00\x01\x00\x01\x01\x11\xa1DnameLcapabilities
  s> makefile('rb', None)
  s>     HTTP/1.1 200 OK\r\n
  s>     Server: testing stub value\r\n
  s>     Date: $HTTP_DATE$\r\n
  s>     Content-Type: application/mercurial-exp-framing-0003\r\n
  s>     Transfer-Encoding: chunked\r\n
  s>     \r\n
  s>     *\r\n (glob)
  s>     *\x00\x01\x00\x02\x01F (glob)
  s>     \xa2Hcommands\xa9Eheads\xa2Dargs\xa1Jpubliconly\xf4Kpermissions\x81DpullEknown\xa2Dargs\xa1Enodes\x81HdeadbeefKpermissions\x81DpullFlookup\xa2Dargs\xa1CkeyFlegacyKpermissions\x81DpullGpushkey\xa2Dargs\xa4CkeyCkeyCnewCnewColdColdInamespaceBnsKpermissions\x81DpullHlistkeys\xa2Dargs\xa1InamespaceBnsKpermissions\x81DpullHunbundle\xa2Dargs\xa1EheadsFlegacyKpermissions\x81DpushIbranchmap\xa2Dargs\xa0Kpermissions\x81DpullIgetbundle\xa2Dargs\xa1A*FlegacyKpermissions\x81DpullLcapabilities\xa2Dargs\xa0Kpermissions\x81DpullKcompression\x82\xa1DnameDzstd\xa1DnameDzlib
  s>     \r\n
  received frame(size=*; request=1; stream=2; streamflags=stream-begin; type=bytes-response; flags=eos|cbor) (glob)
  s>     0\r\n
  s>     \r\n
  response: [{b'commands': {b'branchmap': {b'args': {}, b'permissions': [b'pull']}, b'capabilities': {b'args': {}, b'permissions': [b'pull']}, b'getbundle': {b'args': {b'*': b'legacy'}, b'permissions': [b'pull']}, b'heads': {b'args': {b'publiconly': False}, b'permissions': [b'pull']}, b'known': {b'args': {b'nodes': [b'deadbeef']}, b'permissions': [b'pull']}, b'listkeys': {b'args': {b'namespace': b'ns'}, b'permissions': [b'pull']}, b'lookup': {b'args': {b'key': b'legacy'}, b'permissions': [b'pull']}, b'pushkey': {b'args': {b'key': b'key', b'namespace': b'ns', b'new': b'new', b'old': b'old'}, b'permissions': [b'pull']}, b'unbundle': {b'args': {b'heads': b'legacy'}, b'permissions': [b'push']}}, b'compression': [{b'name': b'zstd'}, {b'name': b'zlib'}]}]

  $ cat error.log
