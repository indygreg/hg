  $ . $TESTDIR/wireprotohelpers.sh

  $ hg init server

zstd isn't present in plain builds. Make tests easier by removing
zstd from the equation.

  $ cat >> server/.hg/hgrc << EOF
  > [server]
  > compressionengines = zlib
  > EOF

  $ hg -R server serve -p $HGPORT -d --pid-file hg.pid -E error.log
  $ cat hg.pid > $DAEMON_PIDS

A normal capabilities request is serviced for version 1

  $ sendhttpraw << EOF
  > httprequest GET ?cmd=capabilities
  >     user-agent: test
  > EOF
  using raw connection to peer
  s>     GET /?cmd=capabilities HTTP/1.1\r\n
  s>     Accept-Encoding: identity\r\n
  s>     user-agent: test\r\n
  s>     host: $LOCALIP:$HGPORT\r\n (glob)
  s>     \r\n
  s> makefile('rb', None)
  s>     HTTP/1.1 200 Script output follows\r\n
  s>     Server: testing stub value\r\n
  s>     Date: $HTTP_DATE$\r\n
  s>     Content-Type: application/mercurial-0.1\r\n
  s>     Content-Length: *\r\n (glob)
  s>     \r\n
  s>     batch branchmap $USUAL_BUNDLE2_CAPS_SERVER$ changegroupsubset compression=$BUNDLE2_COMPRESSIONS$ getbundle httpheader=1024 httpmediatype=0.1rx,0.1tx,0.2tx known lookup pushkey streamreqs=generaldelta,revlogv1 unbundle=HG10GZ,HG10BZ,HG10UN unbundlehash

A proper request without the API server enabled returns the legacy response

  $ sendhttpraw << EOF
  > httprequest GET ?cmd=capabilities
  >    user-agent: test
  >    x-hgupgrade-1: foo
  >    x-hgproto-1: cbor
  > EOF
  using raw connection to peer
  s>     GET /?cmd=capabilities HTTP/1.1\r\n
  s>     Accept-Encoding: identity\r\n
  s>     user-agent: test\r\n
  s>     x-hgproto-1: cbor\r\n
  s>     x-hgupgrade-1: foo\r\n
  s>     host: $LOCALIP:$HGPORT\r\n (glob)
  s>     \r\n
  s> makefile('rb', None)
  s>     HTTP/1.1 200 Script output follows\r\n
  s>     Server: testing stub value\r\n
  s>     Date: $HTTP_DATE$\r\n
  s>     Content-Type: application/mercurial-0.1\r\n
  s>     Content-Length: *\r\n (glob)
  s>     \r\n
  s>     batch branchmap $USUAL_BUNDLE2_CAPS_SERVER$ changegroupsubset compression=$BUNDLE2_COMPRESSIONS$ getbundle httpheader=1024 httpmediatype=0.1rx,0.1tx,0.2tx known lookup pushkey streamreqs=generaldelta,revlogv1 unbundle=HG10GZ,HG10BZ,HG10UN unbundlehash

Restart with just API server enabled. This enables serving the new format.

  $ killdaemons.py
  $ cat error.log

  $ cat >> server/.hg/hgrc << EOF
  > [experimental]
  > web.apiserver = true
  > EOF

  $ hg -R server serve -p $HGPORT -d --pid-file hg.pid -E error.log
  $ cat hg.pid > $DAEMON_PIDS

X-HgUpgrade-<N> without CBOR advertisement uses legacy response

  $ sendhttpraw << EOF
  > httprequest GET ?cmd=capabilities
  >    user-agent: test
  >    x-hgupgrade-1: foo bar
  > EOF
  using raw connection to peer
  s>     GET /?cmd=capabilities HTTP/1.1\r\n
  s>     Accept-Encoding: identity\r\n
  s>     user-agent: test\r\n
  s>     x-hgupgrade-1: foo bar\r\n
  s>     host: $LOCALIP:$HGPORT\r\n (glob)
  s>     \r\n
  s> makefile('rb', None)
  s>     HTTP/1.1 200 Script output follows\r\n
  s>     Server: testing stub value\r\n
  s>     Date: $HTTP_DATE$\r\n
  s>     Content-Type: application/mercurial-0.1\r\n
  s>     Content-Length: *\r\n (glob)
  s>     \r\n
  s>     batch branchmap $USUAL_BUNDLE2_CAPS_SERVER$ changegroupsubset compression=$BUNDLE2_COMPRESSIONS$ getbundle httpheader=1024 httpmediatype=0.1rx,0.1tx,0.2tx known lookup pushkey streamreqs=generaldelta,revlogv1 unbundle=HG10GZ,HG10BZ,HG10UN unbundlehash

X-HgUpgrade-<N> without known serialization in X-HgProto-<N> uses legacy response

  $ sendhttpraw << EOF
  > httprequest GET ?cmd=capabilities
  >    user-agent: test
  >    x-hgupgrade-1: foo bar
  >    x-hgproto-1: some value
  > EOF
  using raw connection to peer
  s>     GET /?cmd=capabilities HTTP/1.1\r\n
  s>     Accept-Encoding: identity\r\n
  s>     user-agent: test\r\n
  s>     x-hgproto-1: some value\r\n
  s>     x-hgupgrade-1: foo bar\r\n
  s>     host: $LOCALIP:$HGPORT\r\n (glob)
  s>     \r\n
  s> makefile('rb', None)
  s>     HTTP/1.1 200 Script output follows\r\n
  s>     Server: testing stub value\r\n
  s>     Date: $HTTP_DATE$\r\n
  s>     Content-Type: application/mercurial-0.1\r\n
  s>     Content-Length: *\r\n (glob)
  s>     \r\n
  s>     batch branchmap $USUAL_BUNDLE2_CAPS_SERVER$ changegroupsubset compression=$BUNDLE2_COMPRESSIONS$ getbundle httpheader=1024 httpmediatype=0.1rx,0.1tx,0.2tx known lookup pushkey streamreqs=generaldelta,revlogv1 unbundle=HG10GZ,HG10BZ,HG10UN unbundlehash

X-HgUpgrade-<N> + X-HgProto-<N> headers trigger new response format

  $ sendhttpraw << EOF
  > httprequest GET ?cmd=capabilities
  >    user-agent: test
  >    x-hgupgrade-1: foo bar
  >    x-hgproto-1: cbor
  > EOF
  using raw connection to peer
  s>     GET /?cmd=capabilities HTTP/1.1\r\n
  s>     Accept-Encoding: identity\r\n
  s>     user-agent: test\r\n
  s>     x-hgproto-1: cbor\r\n
  s>     x-hgupgrade-1: foo bar\r\n
  s>     host: $LOCALIP:$HGPORT\r\n (glob)
  s>     \r\n
  s> makefile('rb', None)
  s>     HTTP/1.1 200 OK\r\n
  s>     Server: testing stub value\r\n
  s>     Date: $HTTP_DATE$\r\n
  s>     Content-Type: application/mercurial-cbor\r\n
  s>     Content-Length: *\r\n (glob)
  s>     \r\n
  s>     \xa3Dapis\xa0GapibaseDapi/Nv1capabilitiesY\x01\xc5batch branchmap $USUAL_BUNDLE2_CAPS_SERVER$ changegroupsubset compression=$BUNDLE2_COMPRESSIONS$ getbundle httpheader=1024 httpmediatype=0.1rx,0.1tx,0.2tx known lookup pushkey streamreqs=generaldelta,revlogv1 unbundle=HG10GZ,HG10BZ,HG10UN unbundlehash
  cbor> {b'apibase': b'api/', b'apis': {}, b'v1capabilities': b'batch branchmap $USUAL_BUNDLE2_CAPS_SERVER$ changegroupsubset compression=$BUNDLE2_COMPRESSIONS$ getbundle httpheader=1024 httpmediatype=0.1rx,0.1tx,0.2tx known lookup pushkey streamreqs=generaldelta,revlogv1 unbundle=HG10GZ,HG10BZ,HG10UN unbundlehash'}

Restart server to enable HTTPv2

  $ killdaemons.py
  $ enablehttpv2 server
  $ hg -R server serve -p $HGPORT -d --pid-file hg.pid -E error.log
  $ cat hg.pid > $DAEMON_PIDS

Only requested API services are returned

  $ sendhttpraw << EOF
  > httprequest GET ?cmd=capabilities
  >    user-agent: test
  >    x-hgupgrade-1: foo bar
  >    x-hgproto-1: cbor
  > EOF
  using raw connection to peer
  s>     GET /?cmd=capabilities HTTP/1.1\r\n
  s>     Accept-Encoding: identity\r\n
  s>     user-agent: test\r\n
  s>     x-hgproto-1: cbor\r\n
  s>     x-hgupgrade-1: foo bar\r\n
  s>     host: $LOCALIP:$HGPORT\r\n (glob)
  s>     \r\n
  s> makefile('rb', None)
  s>     HTTP/1.1 200 OK\r\n
  s>     Server: testing stub value\r\n
  s>     Date: $HTTP_DATE$\r\n
  s>     Content-Type: application/mercurial-cbor\r\n
  s>     Content-Length: *\r\n (glob)
  s>     \r\n
  s>     \xa3Dapis\xa0GapibaseDapi/Nv1capabilitiesY\x01\xc5batch branchmap $USUAL_BUNDLE2_CAPS_SERVER$ changegroupsubset compression=$BUNDLE2_COMPRESSIONS$ getbundle httpheader=1024 httpmediatype=0.1rx,0.1tx,0.2tx known lookup pushkey streamreqs=generaldelta,revlogv1 unbundle=HG10GZ,HG10BZ,HG10UN unbundlehash
  cbor> {b'apibase': b'api/', b'apis': {}, b'v1capabilities': b'batch branchmap $USUAL_BUNDLE2_CAPS_SERVER$ changegroupsubset compression=$BUNDLE2_COMPRESSIONS$ getbundle httpheader=1024 httpmediatype=0.1rx,0.1tx,0.2tx known lookup pushkey streamreqs=generaldelta,revlogv1 unbundle=HG10GZ,HG10BZ,HG10UN unbundlehash'}

Request for HTTPv2 service returns information about it

  $ sendhttpraw << EOF
  > httprequest GET ?cmd=capabilities
  >    user-agent: test
  >    x-hgupgrade-1: exp-http-v2-0001 foo bar
  >    x-hgproto-1: cbor
  > EOF
  using raw connection to peer
  s>     GET /?cmd=capabilities HTTP/1.1\r\n
  s>     Accept-Encoding: identity\r\n
  s>     user-agent: test\r\n
  s>     x-hgproto-1: cbor\r\n
  s>     x-hgupgrade-1: exp-http-v2-0001 foo bar\r\n
  s>     host: $LOCALIP:$HGPORT\r\n (glob)
  s>     \r\n
  s> makefile('rb', None)
  s>     HTTP/1.1 200 OK\r\n
  s>     Server: testing stub value\r\n
  s>     Date: $HTTP_DATE$\r\n
  s>     Content-Type: application/mercurial-cbor\r\n
  s>     Content-Length: *\r\n (glob)
  s>     \r\n
  s>     \xa3Dapis\xa1Pexp-http-v2-0001\xa4Hcommands\xa7Eheads\xa2Dargs\xa1Jpubliconly\xf4Kpermissions\x81DpullEknown\xa2Dargs\xa1Enodes\x81HdeadbeefKpermissions\x81DpullFlookup\xa2Dargs\xa1CkeyCfooKpermissions\x81DpullGpushkey\xa2Dargs\xa4CkeyCkeyCnewCnewColdColdInamespaceBnsKpermissions\x81DpushHlistkeys\xa2Dargs\xa1InamespaceBnsKpermissions\x81DpullIbranchmap\xa2Dargs\xa0Kpermissions\x81DpullLcapabilities\xa2Dargs\xa0Kpermissions\x81DpullKcompression\x81\xa1DnameDzlibNrawrepoformats\x82LgeneraldeltaHrevlogv1Qframingmediatypes\x81X&application/mercurial-exp-framing-0005GapibaseDapi/Nv1capabilitiesY\x01\xc5batch branchmap $USUAL_BUNDLE2_CAPS_SERVER$ changegroupsubset compression=$BUNDLE2_COMPRESSIONS$ getbundle httpheader=1024 httpmediatype=0.1rx,0.1tx,0.2tx known lookup pushkey streamreqs=generaldelta,revlogv1 unbundle=HG10GZ,HG10BZ,HG10UN unbundlehash
  cbor> {b'apibase': b'api/', b'apis': {b'exp-http-v2-0001': {b'commands': {b'branchmap': {b'args': {}, b'permissions': [b'pull']}, b'capabilities': {b'args': {}, b'permissions': [b'pull']}, b'heads': {b'args': {b'publiconly': False}, b'permissions': [b'pull']}, b'known': {b'args': {b'nodes': [b'deadbeef']}, b'permissions': [b'pull']}, b'listkeys': {b'args': {b'namespace': b'ns'}, b'permissions': [b'pull']}, b'lookup': {b'args': {b'key': b'foo'}, b'permissions': [b'pull']}, b'pushkey': {b'args': {b'key': b'key', b'namespace': b'ns', b'new': b'new', b'old': b'old'}, b'permissions': [b'push']}}, b'compression': [{b'name': b'zlib'}], b'framingmediatypes': [b'application/mercurial-exp-framing-0005'], b'rawrepoformats': [b'generaldelta', b'revlogv1']}}, b'v1capabilities': b'batch branchmap $USUAL_BUNDLE2_CAPS_SERVER$ changegroupsubset compression=$BUNDLE2_COMPRESSIONS$ getbundle httpheader=1024 httpmediatype=0.1rx,0.1tx,0.2tx known lookup pushkey streamreqs=generaldelta,revlogv1 unbundle=HG10GZ,HG10BZ,HG10UN unbundlehash'}

capabilities command returns expected info

  $ sendhttpv2peerhandshake << EOF
  > command capabilities
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
  s>     \xa3Dapis\xa1Pexp-http-v2-0001\xa4Hcommands\xa7Eheads\xa2Dargs\xa1Jpubliconly\xf4Kpermissions\x81DpullEknown\xa2Dargs\xa1Enodes\x81HdeadbeefKpermissions\x81DpullFlookup\xa2Dargs\xa1CkeyCfooKpermissions\x81DpullGpushkey\xa2Dargs\xa4CkeyCkeyCnewCnewColdColdInamespaceBnsKpermissions\x81DpushHlistkeys\xa2Dargs\xa1InamespaceBnsKpermissions\x81DpullIbranchmap\xa2Dargs\xa0Kpermissions\x81DpullLcapabilities\xa2Dargs\xa0Kpermissions\x81DpullKcompression\x81\xa1DnameDzlibNrawrepoformats\x82LgeneraldeltaHrevlogv1Qframingmediatypes\x81X&application/mercurial-exp-framing-0005GapibaseDapi/Nv1capabilitiesY\x01\xc5batch branchmap $USUAL_BUNDLE2_CAPS_SERVER$ changegroupsubset compression=$BUNDLE2_COMPRESSIONS$ getbundle httpheader=1024 httpmediatype=0.1rx,0.1tx,0.2tx known lookup pushkey streamreqs=generaldelta,revlogv1 unbundle=HG10GZ,HG10BZ,HG10UN unbundlehash
  sending capabilities command
  s>     POST /api/exp-http-v2-0001/ro/capabilities HTTP/1.1\r\n
  s>     Accept-Encoding: identity\r\n
  s>     *\r\n (glob)
  s>     content-type: application/mercurial-exp-framing-0005\r\n
  s>     content-length: 27\r\n
  s>     host: $LOCALIP:$HGPORT\r\n (glob)
  s>     user-agent: Mercurial debugwireproto\r\n
  s>     \r\n
  s>     \x13\x00\x00\x01\x00\x01\x01\x11\xa1DnameLcapabilities
  s> makefile('rb', None)
  s>     HTTP/1.1 200 OK\r\n
  s>     Server: testing stub value\r\n
  s>     Date: $HTTP_DATE$\r\n
  s>     Content-Type: application/mercurial-exp-framing-0005\r\n
  s>     Transfer-Encoding: chunked\r\n
  s>     \r\n
  s>     1d7\r\n
  s>     \xcf\x01\x00\x01\x00\x02\x012
  s>     \xa1FstatusBok\xa4Hcommands\xa7Eheads\xa2Dargs\xa1Jpubliconly\xf4Kpermissions\x81DpullEknown\xa2Dargs\xa1Enodes\x81HdeadbeefKpermissions\x81DpullFlookup\xa2Dargs\xa1CkeyCfooKpermissions\x81DpullGpushkey\xa2Dargs\xa4CkeyCkeyCnewCnewColdColdInamespaceBnsKpermissions\x81DpushHlistkeys\xa2Dargs\xa1InamespaceBnsKpermissions\x81DpullIbranchmap\xa2Dargs\xa0Kpermissions\x81DpullLcapabilities\xa2Dargs\xa0Kpermissions\x81DpullKcompression\x81\xa1DnameDzlibNrawrepoformats\x82LgeneraldeltaHrevlogv1Qframingmediatypes\x81X&application/mercurial-exp-framing-0005
  s>     \r\n
  received frame(size=463; request=1; stream=2; streamflags=stream-begin; type=command-response; flags=eos)
  s>     0\r\n
  s>     \r\n
  response: [{b'status': b'ok'}, {b'commands': {b'branchmap': {b'args': {}, b'permissions': [b'pull']}, b'capabilities': {b'args': {}, b'permissions': [b'pull']}, b'heads': {b'args': {b'publiconly': False}, b'permissions': [b'pull']}, b'known': {b'args': {b'nodes': [b'deadbeef']}, b'permissions': [b'pull']}, b'listkeys': {b'args': {b'namespace': b'ns'}, b'permissions': [b'pull']}, b'lookup': {b'args': {b'key': b'foo'}, b'permissions': [b'pull']}, b'pushkey': {b'args': {b'key': b'key', b'namespace': b'ns', b'new': b'new', b'old': b'old'}, b'permissions': [b'push']}}, b'compression': [{b'name': b'zlib'}], b'framingmediatypes': [b'application/mercurial-exp-framing-0005'], b'rawrepoformats': [b'generaldelta', b'revlogv1']}]

  $ cat error.log
