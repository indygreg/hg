  $ . $TESTDIR/wireprotohelpers.sh

  $ hg init server
  $ enablehttpv2 server
  $ cd server
  $ hg debugdrawdag << EOF
  > H I J
  > | | |
  > E F G
  > | |/
  > C D
  > |/
  > B
  > |
  > A
  > EOF

  $ hg phase --force --secret J
  $ hg phase --public E

  $ hg log -r 'E + H + I + G + J' -T '{rev}:{node} {desc} {phase}\n'
  4:78d2dca436b2f5b188ac267e29b81e07266d38fc E public
  7:ae492e36b0c8339ffaf328d00b85b4525de1165e H draft
  8:1d6f6b91d44aaba6d5e580bc30a9948530dbe00b I draft
  6:29446d2dc5419c5f97447a8bc062e4cc328bf241 G draft
  9:dec04b246d7cbb670c6689806c05ad17c835284e J secret

  $ hg serve -p $HGPORT -d --pid-file hg.pid -E error.log
  $ cat hg.pid > $DAEMON_PIDS

All non-secret heads returned by default

  $ sendhttpv2peer << EOF
  > command heads
  > EOF
  creating http peer for wire protocol version 2
  s>     GET /?cmd=capabilities HTTP/1.1\r\n
  s>     Accept-Encoding: identity\r\n
  s>     vary: X-HgProto-1,X-HgUpgrade-1\r\n
  s>     x-hgproto-1: cbor\r\n
  s>     x-hgupgrade-1: exp-http-v2-0001\r\n
  s>     accept: application/mercurial-0.1\r\n
  s>     host: $LOCALIP:$HGPORT\r\n (glob)
  s>     user-agent: Mercurial debugwireproto\r\n
  s>     \r\n
  s> makefile('rb', None)
  s>     HTTP/1.1 200 OK\r\n
  s>     Server: testing stub value\r\n
  s>     Date: $HTTP_DATE$\r\n
  s>     Content-Type: application/mercurial-cbor\r\n
  s>     Content-Length: *\r\n (glob)
  s>     \r\n
  s>     \xa3Dapis\xa1Pexp-http-v2-0001\xa3Hcommands\xa7Eheads\xa2Dargs\xa1Jpubliconly\xf4Kpermissions\x81DpullEknown\xa2Dargs\xa1Enodes\x81HdeadbeefKpermissions\x81DpullFlookup\xa2Dargs\xa1CkeyCfooKpermissions\x81DpullGpushkey\xa2Dargs\xa4CkeyCkeyCnewCnewColdColdInamespaceBnsKpermissions\x81DpushHlistkeys\xa2Dargs\xa1InamespaceBnsKpermissions\x81DpullIbranchmap\xa2Dargs\xa0Kpermissions\x81DpullLcapabilities\xa2Dargs\xa0Kpermissions\x81DpullKcompression\x82\xa1DnameDzstd\xa1DnameDzlibQframingmediatypes\x81X&application/mercurial-exp-framing-0003GapibaseDapi/Nv1capabilitiesY\x01\xa9batch branchmap $USUAL_BUNDLE2_CAPS_SERVER$ changegroupsubset compression=$BUNDLE2_COMPRESSIONS$ getbundle httpheader=1024 httpmediatype=0.1rx,0.1tx,0.2tx known lookup pushkey unbundle=HG10GZ,HG10BZ,HG10UN unbundlehash
  sending heads command
  s>     POST /api/exp-http-v2-0001/ro/heads HTTP/1.1\r\n
  s>     Accept-Encoding: identity\r\n
  s>     accept: application/mercurial-exp-framing-0003\r\n
  s>     content-type: application/mercurial-exp-framing-0003\r\n
  s>     content-length: 20\r\n
  s>     host: $LOCALIP:$HGPORT\r\n (glob)
  s>     user-agent: Mercurial debugwireproto\r\n
  s>     \r\n
  s>     \x0c\x00\x00\x01\x00\x01\x01\x11\xa1DnameEheads
  s> makefile('rb', None)
  s>     HTTP/1.1 200 OK\r\n
  s>     Server: testing stub value\r\n
  s>     Date: $HTTP_DATE$\r\n
  s>     Content-Type: application/mercurial-exp-framing-0003\r\n
  s>     Transfer-Encoding: chunked\r\n
  s>     \r\n
  s>     48\r\n
  s>     @\x00\x00\x01\x00\x02\x01F
  s>     \x83T\x1dok\x91\xd4J\xab\xa6\xd5\xe5\x80\xbc0\xa9\x94\x850\xdb\xe0\x0bT\xaeI.6\xb0\xc83\x9f\xfa\xf3(\xd0\x0b\x85\xb4R]\xe1\x16^T)Dm-\xc5A\x9c_\x97Dz\x8b\xc0b\xe4\xcc2\x8b\xf2A
  s>     \r\n
  received frame(size=64; request=1; stream=2; streamflags=stream-begin; type=bytes-response; flags=eos|cbor)
  s>     0\r\n
  s>     \r\n
  response: [[b'\x1dok\x91\xd4J\xab\xa6\xd5\xe5\x80\xbc0\xa9\x94\x850\xdb\xe0\x0b', b'\xaeI.6\xb0\xc83\x9f\xfa\xf3(\xd0\x0b\x85\xb4R]\xe1\x16^', b')Dm-\xc5A\x9c_\x97Dz\x8b\xc0b\xe4\xcc2\x8b\xf2A']]

Requesting just the public heads works

  $ sendhttpv2peer << EOF
  > command heads
  >     publiconly 1
  > EOF
  creating http peer for wire protocol version 2
  s>     GET /?cmd=capabilities HTTP/1.1\r\n
  s>     Accept-Encoding: identity\r\n
  s>     vary: X-HgProto-1,X-HgUpgrade-1\r\n
  s>     x-hgproto-1: cbor\r\n
  s>     x-hgupgrade-1: exp-http-v2-0001\r\n
  s>     accept: application/mercurial-0.1\r\n
  s>     host: $LOCALIP:$HGPORT\r\n (glob)
  s>     user-agent: Mercurial debugwireproto\r\n
  s>     \r\n
  s> makefile('rb', None)
  s>     HTTP/1.1 200 OK\r\n
  s>     Server: testing stub value\r\n
  s>     Date: $HTTP_DATE$\r\n
  s>     Content-Type: application/mercurial-cbor\r\n
  s>     Content-Length: *\r\n (glob)
  s>     \r\n
  s>     \xa3Dapis\xa1Pexp-http-v2-0001\xa3Hcommands\xa7Eheads\xa2Dargs\xa1Jpubliconly\xf4Kpermissions\x81DpullEknown\xa2Dargs\xa1Enodes\x81HdeadbeefKpermissions\x81DpullFlookup\xa2Dargs\xa1CkeyCfooKpermissions\x81DpullGpushkey\xa2Dargs\xa4CkeyCkeyCnewCnewColdColdInamespaceBnsKpermissions\x81DpushHlistkeys\xa2Dargs\xa1InamespaceBnsKpermissions\x81DpullIbranchmap\xa2Dargs\xa0Kpermissions\x81DpullLcapabilities\xa2Dargs\xa0Kpermissions\x81DpullKcompression\x82\xa1DnameDzstd\xa1DnameDzlibQframingmediatypes\x81X&application/mercurial-exp-framing-0003GapibaseDapi/Nv1capabilitiesY\x01\xa9batch branchmap $USUAL_BUNDLE2_CAPS_SERVER$ changegroupsubset compression=$BUNDLE2_COMPRESSIONS$ getbundle httpheader=1024 httpmediatype=0.1rx,0.1tx,0.2tx known lookup pushkey unbundle=HG10GZ,HG10BZ,HG10UN unbundlehash
  sending heads command
  s>     POST /api/exp-http-v2-0001/ro/heads HTTP/1.1\r\n
  s>     Accept-Encoding: identity\r\n
  s>     accept: application/mercurial-exp-framing-0003\r\n
  s>     content-type: application/mercurial-exp-framing-0003\r\n
  s>     content-length: 39\r\n
  s>     host: $LOCALIP:$HGPORT\r\n (glob)
  s>     user-agent: Mercurial debugwireproto\r\n
  s>     \r\n
  s>     \x1f\x00\x00\x01\x00\x01\x01\x11\xa2Dargs\xa1JpubliconlyA1DnameEheads
  s> makefile('rb', None)
  s>     HTTP/1.1 200 OK\r\n
  s>     Server: testing stub value\r\n
  s>     Date: $HTTP_DATE$\r\n
  s>     Content-Type: application/mercurial-exp-framing-0003\r\n
  s>     Transfer-Encoding: chunked\r\n
  s>     \r\n
  s>     1e\r\n
  s>     \x16\x00\x00\x01\x00\x02\x01F
  s>     \x81Tx\xd2\xdc\xa46\xb2\xf5\xb1\x88\xac&~)\xb8\x1e\x07&m8\xfc
  s>     \r\n
  received frame(size=22; request=1; stream=2; streamflags=stream-begin; type=bytes-response; flags=eos|cbor)
  s>     0\r\n
  s>     \r\n
  response: [[b'x\xd2\xdc\xa46\xb2\xf5\xb1\x88\xac&~)\xb8\x1e\x07&m8\xfc']]

  $ cat error.log
