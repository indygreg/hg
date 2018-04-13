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
  s>     \xa3Dapis\xa1Pexp-http-v2-0001\xa3Hcommands\xa7Eheads\xa2Dargs\xa1Jpubliconly\xf4Kpermissions\x81DpullEknown\xa2Dargs\xa1Enodes\x81HdeadbeefKpermissions\x81DpullFlookup\xa2Dargs\xa1CkeyCfooKpermissions\x81DpullGpushkey\xa2Dargs\xa4CkeyCkeyCnewCnewColdColdInamespaceBnsKpermissions\x81DpushHlistkeys\xa2Dargs\xa1InamespaceBnsKpermissions\x81DpullIbranchmap\xa2Dargs\xa0Kpermissions\x81DpullLcapabilities\xa2Dargs\xa0Kpermissions\x81DpullKcompression\x82\xa1DnameDzstd\xa1DnameDzlibQframingmediatypes\x81X&application/mercurial-exp-framing-0003GapibaseDapi/Nv1capabilitiesY\x01\xcabatch branchmap $USUAL_BUNDLE2_CAPS_SERVER$ changegroupsubset compression=$BUNDLE2_COMPRESSIONS$ getbundle httpheader=1024 httpmediatype=0.1rx,0.1tx,0.2tx known lookup pushkey streamreqs=generaldelta,revlogv1 unbundle=HG10GZ,HG10BZ,HG10UN unbundlehash
  sending listkeys command
  s>     POST /api/exp-http-v2-0001/ro/listkeys HTTP/1.1\r\n
  s>     Accept-Encoding: identity\r\n
  s>     accept: application/mercurial-exp-framing-0003\r\n
  s>     content-type: application/mercurial-exp-framing-0003\r\n
  s>     content-length: 50\r\n
  s>     host: $LOCALIP:$HGPORT\r\n (glob)
  s>     user-agent: Mercurial debugwireproto\r\n
  s>     \r\n
  s>     *\x00\x00\x01\x00\x01\x01\x11\xa2Dargs\xa1InamespaceJnamespacesDnameHlistkeys
  s> makefile('rb', None)
  s>     HTTP/1.1 200 OK\r\n
  s>     Server: testing stub value\r\n
  s>     Date: $HTTP_DATE$\r\n
  s>     Content-Type: application/mercurial-exp-framing-0003\r\n
  s>     Transfer-Encoding: chunked\r\n
  s>     \r\n
  s>     28\r\n
  s>      \x00\x00\x01\x00\x02\x01F
  s>     \xa3Fphases@Ibookmarks@Jnamespaces@
  s>     \r\n
  received frame(size=32; request=1; stream=2; streamflags=stream-begin; type=bytes-response; flags=eos|cbor)
  s>     0\r\n
  s>     \r\n
  response: [{b'bookmarks': b'', b'namespaces': b'', b'phases': b''}]

Request for phases works

  $ sendhttpv2peer << EOF
  > command listkeys
  >     namespace phases
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
  s>     \xa3Dapis\xa1Pexp-http-v2-0001\xa3Hcommands\xa7Eheads\xa2Dargs\xa1Jpubliconly\xf4Kpermissions\x81DpullEknown\xa2Dargs\xa1Enodes\x81HdeadbeefKpermissions\x81DpullFlookup\xa2Dargs\xa1CkeyCfooKpermissions\x81DpullGpushkey\xa2Dargs\xa4CkeyCkeyCnewCnewColdColdInamespaceBnsKpermissions\x81DpushHlistkeys\xa2Dargs\xa1InamespaceBnsKpermissions\x81DpullIbranchmap\xa2Dargs\xa0Kpermissions\x81DpullLcapabilities\xa2Dargs\xa0Kpermissions\x81DpullKcompression\x82\xa1DnameDzstd\xa1DnameDzlibQframingmediatypes\x81X&application/mercurial-exp-framing-0003GapibaseDapi/Nv1capabilitiesY\x01\xcabatch branchmap $USUAL_BUNDLE2_CAPS_SERVER$ changegroupsubset compression=$BUNDLE2_COMPRESSIONS$ getbundle httpheader=1024 httpmediatype=0.1rx,0.1tx,0.2tx known lookup pushkey streamreqs=generaldelta,revlogv1 unbundle=HG10GZ,HG10BZ,HG10UN unbundlehash
  sending listkeys command
  s>     POST /api/exp-http-v2-0001/ro/listkeys HTTP/1.1\r\n
  s>     Accept-Encoding: identity\r\n
  s>     accept: application/mercurial-exp-framing-0003\r\n
  s>     content-type: application/mercurial-exp-framing-0003\r\n
  s>     content-length: 46\r\n
  s>     host: $LOCALIP:$HGPORT\r\n (glob)
  s>     user-agent: Mercurial debugwireproto\r\n
  s>     \r\n
  s>     &\x00\x00\x01\x00\x01\x01\x11\xa2Dargs\xa1InamespaceFphasesDnameHlistkeys
  s> makefile('rb', None)
  s>     HTTP/1.1 200 OK\r\n
  s>     Server: testing stub value\r\n
  s>     Date: $HTTP_DATE$\r\n
  s>     Content-Type: application/mercurial-exp-framing-0003\r\n
  s>     Transfer-Encoding: chunked\r\n
  s>     \r\n
  s>     45\r\n
  s>     =\x00\x00\x01\x00\x02\x01F
  s>     \xa2JpublishingDTrueX(be0ef73c17ade3fc89dc41701eb9fc3a91b58282A1
  s>     \r\n
  received frame(size=61; request=1; stream=2; streamflags=stream-begin; type=bytes-response; flags=eos|cbor)
  s>     0\r\n
  s>     \r\n
  response: [{b'be0ef73c17ade3fc89dc41701eb9fc3a91b58282': b'1', b'publishing': b'True'}]

Request for bookmarks works

  $ sendhttpv2peer << EOF
  > command listkeys
  >     namespace bookmarks
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
  s>     \xa3Dapis\xa1Pexp-http-v2-0001\xa3Hcommands\xa7Eheads\xa2Dargs\xa1Jpubliconly\xf4Kpermissions\x81DpullEknown\xa2Dargs\xa1Enodes\x81HdeadbeefKpermissions\x81DpullFlookup\xa2Dargs\xa1CkeyCfooKpermissions\x81DpullGpushkey\xa2Dargs\xa4CkeyCkeyCnewCnewColdColdInamespaceBnsKpermissions\x81DpushHlistkeys\xa2Dargs\xa1InamespaceBnsKpermissions\x81DpullIbranchmap\xa2Dargs\xa0Kpermissions\x81DpullLcapabilities\xa2Dargs\xa0Kpermissions\x81DpullKcompression\x82\xa1DnameDzstd\xa1DnameDzlibQframingmediatypes\x81X&application/mercurial-exp-framing-0003GapibaseDapi/Nv1capabilitiesY\x01\xcabatch branchmap $USUAL_BUNDLE2_CAPS_SERVER$ changegroupsubset compression=$BUNDLE2_COMPRESSIONS$ getbundle httpheader=1024 httpmediatype=0.1rx,0.1tx,0.2tx known lookup pushkey streamreqs=generaldelta,revlogv1 unbundle=HG10GZ,HG10BZ,HG10UN unbundlehash
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
  s>     \xa1A@X(26805aba1e600a82e93661149f2313866a221a7b
  s>     \r\n
  received frame(size=45; request=1; stream=2; streamflags=stream-begin; type=bytes-response; flags=eos|cbor)
  s>     0\r\n
  s>     \r\n
  response: [{b'@': b'26805aba1e600a82e93661149f2313866a221a7b'}]

  $ cat error.log
