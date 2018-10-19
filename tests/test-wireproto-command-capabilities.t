#require no-chg

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
  s>     batch branchmap $USUAL_BUNDLE2_CAPS$ changegroupsubset compression=$BUNDLE2_COMPRESSIONS$ getbundle httpheader=1024 httpmediatype=0.1rx,0.1tx,0.2tx known lookup pushkey streamreqs=generaldelta,revlogv1 unbundle=HG10GZ,HG10BZ,HG10UN unbundlehash

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
  s>     batch branchmap $USUAL_BUNDLE2_CAPS$ changegroupsubset compression=$BUNDLE2_COMPRESSIONS$ getbundle httpheader=1024 httpmediatype=0.1rx,0.1tx,0.2tx known lookup pushkey streamreqs=generaldelta,revlogv1 unbundle=HG10GZ,HG10BZ,HG10UN unbundlehash

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
  s>     batch branchmap $USUAL_BUNDLE2_CAPS$ changegroupsubset compression=$BUNDLE2_COMPRESSIONS$ getbundle httpheader=1024 httpmediatype=0.1rx,0.1tx,0.2tx known lookup pushkey streamreqs=generaldelta,revlogv1 unbundle=HG10GZ,HG10BZ,HG10UN unbundlehash

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
  s>     batch branchmap $USUAL_BUNDLE2_CAPS$ changegroupsubset compression=$BUNDLE2_COMPRESSIONS$ getbundle httpheader=1024 httpmediatype=0.1rx,0.1tx,0.2tx known lookup pushkey streamreqs=generaldelta,revlogv1 unbundle=HG10GZ,HG10BZ,HG10UN unbundlehash

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
  s>     \xa3GapibaseDapi/Dapis\xa0Nv1capabilitiesY\x01\xd3batch branchmap $USUAL_BUNDLE2_CAPS$ changegroupsubset compression=$BUNDLE2_COMPRESSIONS$ getbundle httpheader=1024 httpmediatype=0.1rx,0.1tx,0.2tx known lookup pushkey streamreqs=generaldelta,revlogv1 unbundle=HG10GZ,HG10BZ,HG10UN unbundlehash
  cbor> [
    {
      b'apibase': b'api/',
      b'apis': {},
      b'v1capabilities': b'batch branchmap $USUAL_BUNDLE2_CAPS$ changegroupsubset compression=$BUNDLE2_COMPRESSIONS$ getbundle httpheader=1024 httpmediatype=0.1rx,0.1tx,0.2tx known lookup pushkey streamreqs=generaldelta,revlogv1 unbundle=HG10GZ,HG10BZ,HG10UN unbundlehash'
    }
  ]

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
  s>     \xa3GapibaseDapi/Dapis\xa0Nv1capabilitiesY\x01\xd3batch branchmap $USUAL_BUNDLE2_CAPS$ changegroupsubset compression=$BUNDLE2_COMPRESSIONS$ getbundle httpheader=1024 httpmediatype=0.1rx,0.1tx,0.2tx known lookup pushkey streamreqs=generaldelta,revlogv1 unbundle=HG10GZ,HG10BZ,HG10UN unbundlehash
  cbor> [
    {
      b'apibase': b'api/',
      b'apis': {},
      b'v1capabilities': b'batch branchmap $USUAL_BUNDLE2_CAPS$ changegroupsubset compression=$BUNDLE2_COMPRESSIONS$ getbundle httpheader=1024 httpmediatype=0.1rx,0.1tx,0.2tx known lookup pushkey streamreqs=generaldelta,revlogv1 unbundle=HG10GZ,HG10BZ,HG10UN unbundlehash'
    }
  ]

Request for HTTPv2 service returns information about it

  $ sendhttpraw << EOF
  > httprequest GET ?cmd=capabilities
  >    user-agent: test
  >    x-hgupgrade-1: exp-http-v2-0003 foo bar
  >    x-hgproto-1: cbor
  > EOF
  using raw connection to peer
  s>     GET /?cmd=capabilities HTTP/1.1\r\n
  s>     Accept-Encoding: identity\r\n
  s>     user-agent: test\r\n
  s>     x-hgproto-1: cbor\r\n
  s>     x-hgupgrade-1: exp-http-v2-0003 foo bar\r\n
  s>     host: $LOCALIP:$HGPORT\r\n (glob)
  s>     \r\n
  s> makefile('rb', None)
  s>     HTTP/1.1 200 OK\r\n
  s>     Server: testing stub value\r\n
  s>     Date: $HTTP_DATE$\r\n
  s>     Content-Type: application/mercurial-cbor\r\n
  s>     Content-Length: *\r\n (glob)
  s>     \r\n
  s>     \xa3GapibaseDapi/Dapis\xa1Pexp-http-v2-0003\xa4Hcommands\xacIbranchmap\xa2Dargs\xa0Kpermissions\x81DpullLcapabilities\xa2Dargs\xa0Kpermissions\x81DpullMchangesetdata\xa2Dargs\xa2Ffields\xa4Gdefault\xd9\x01\x02\x80Hrequired\xf4DtypeCsetKvalidvalues\xd9\x01\x02\x84IbookmarksGparentsEphaseHrevisionIrevisions\xa2Hrequired\xf5DtypeDlistKpermissions\x81DpullHfiledata\xa2Dargs\xa4Ffields\xa4Gdefault\xd9\x01\x02\x80Hrequired\xf4DtypeCsetKvalidvalues\xd9\x01\x02\x83HlinknodeGparentsHrevisionKhaveparents\xa3Gdefault\xf4Hrequired\xf4DtypeDboolEnodes\xa2Hrequired\xf5DtypeDlistDpath\xa2Hrequired\xf5DtypeEbytesKpermissions\x81DpullIfilesdata\xa3Dargs\xa4Ffields\xa4Gdefault\xd9\x01\x02\x80Hrequired\xf4DtypeCsetKvalidvalues\xd9\x01\x02\x84NfirstchangesetHlinknodeGparentsHrevisionKhaveparents\xa3Gdefault\xf4Hrequired\xf4DtypeDboolJpathfilter\xa3Gdefault\xf6Hrequired\xf4DtypeDdictIrevisions\xa2Hrequired\xf5DtypeDlistKpermissions\x81DpullTrecommendedbatchsize\x19\xc3PEheads\xa2Dargs\xa1Jpubliconly\xa3Gdefault\xf4Hrequired\xf4DtypeDboolKpermissions\x81DpullEknown\xa2Dargs\xa1Enodes\xa3Gdefault\x80Hrequired\xf4DtypeDlistKpermissions\x81DpullHlistkeys\xa2Dargs\xa1Inamespace\xa2Hrequired\xf5DtypeEbytesKpermissions\x81DpullFlookup\xa2Dargs\xa1Ckey\xa2Hrequired\xf5DtypeEbytesKpermissions\x81DpullLmanifestdata\xa3Dargs\xa4Ffields\xa4Gdefault\xd9\x01\x02\x80Hrequired\xf4DtypeCsetKvalidvalues\xd9\x01\x02\x82GparentsHrevisionKhaveparents\xa3Gdefault\xf4Hrequired\xf4DtypeDboolEnodes\xa2Hrequired\xf5DtypeDlistDtree\xa2Hrequired\xf5DtypeEbytesKpermissions\x81DpullTrecommendedbatchsize\x1a\x00\x01\x86\xa0Gpushkey\xa2Dargs\xa4Ckey\xa2Hrequired\xf5DtypeEbytesInamespace\xa2Hrequired\xf5DtypeEbytesCnew\xa2Hrequired\xf5DtypeEbytesCold\xa2Hrequired\xf5DtypeEbytesKpermissions\x81DpushPrawstorefiledata\xa2Dargs\xa2Efiles\xa2Hrequired\xf5DtypeDlistJpathfilter\xa3Gdefault\xf6Hrequired\xf4DtypeDlistKpermissions\x81DpullQframingmediatypes\x81X&application/mercurial-exp-framing-0006Rpathfilterprefixes\xd9\x01\x02\x82Epath:Lrootfilesin:Nrawrepoformats\x82LgeneraldeltaHrevlogv1Nv1capabilitiesY\x01\xd3batch branchmap $USUAL_BUNDLE2_CAPS$ changegroupsubset compression=$BUNDLE2_COMPRESSIONS$ getbundle httpheader=1024 httpmediatype=0.1rx,0.1tx,0.2tx known lookup pushkey streamreqs=generaldelta,revlogv1 unbundle=HG10GZ,HG10BZ,HG10UN unbundlehash
  cbor> [
    {
      b'apibase': b'api/',
      b'apis': {
        b'exp-http-v2-0003': {
          b'commands': {
            b'branchmap': {
              b'args': {},
              b'permissions': [
                b'pull'
              ]
            },
            b'capabilities': {
              b'args': {},
              b'permissions': [
                b'pull'
              ]
            },
            b'changesetdata': {
              b'args': {
                b'fields': {
                  b'default': set([]),
                  b'required': False,
                  b'type': b'set',
                  b'validvalues': set([
                    b'bookmarks',
                    b'parents',
                    b'phase',
                    b'revision'
                  ])
                },
                b'revisions': {
                  b'required': True,
                  b'type': b'list'
                }
              },
              b'permissions': [
                b'pull'
              ]
            },
            b'filedata': {
              b'args': {
                b'fields': {
                  b'default': set([]),
                  b'required': False,
                  b'type': b'set',
                  b'validvalues': set([
                    b'linknode',
                    b'parents',
                    b'revision'
                  ])
                },
                b'haveparents': {
                  b'default': False,
                  b'required': False,
                  b'type': b'bool'
                },
                b'nodes': {
                  b'required': True,
                  b'type': b'list'
                },
                b'path': {
                  b'required': True,
                  b'type': b'bytes'
                }
              },
              b'permissions': [
                b'pull'
              ]
            },
            b'filesdata': {
              b'args': {
                b'fields': {
                  b'default': set([]),
                  b'required': False,
                  b'type': b'set',
                  b'validvalues': set([
                    b'firstchangeset',
                    b'linknode',
                    b'parents',
                    b'revision'
                  ])
                },
                b'haveparents': {
                  b'default': False,
                  b'required': False,
                  b'type': b'bool'
                },
                b'pathfilter': {
                  b'default': None,
                  b'required': False,
                  b'type': b'dict'
                },
                b'revisions': {
                  b'required': True,
                  b'type': b'list'
                }
              },
              b'permissions': [
                b'pull'
              ],
              b'recommendedbatchsize': 50000
            },
            b'heads': {
              b'args': {
                b'publiconly': {
                  b'default': False,
                  b'required': False,
                  b'type': b'bool'
                }
              },
              b'permissions': [
                b'pull'
              ]
            },
            b'known': {
              b'args': {
                b'nodes': {
                  b'default': [],
                  b'required': False,
                  b'type': b'list'
                }
              },
              b'permissions': [
                b'pull'
              ]
            },
            b'listkeys': {
              b'args': {
                b'namespace': {
                  b'required': True,
                  b'type': b'bytes'
                }
              },
              b'permissions': [
                b'pull'
              ]
            },
            b'lookup': {
              b'args': {
                b'key': {
                  b'required': True,
                  b'type': b'bytes'
                }
              },
              b'permissions': [
                b'pull'
              ]
            },
            b'manifestdata': {
              b'args': {
                b'fields': {
                  b'default': set([]),
                  b'required': False,
                  b'type': b'set',
                  b'validvalues': set([
                    b'parents',
                    b'revision'
                  ])
                },
                b'haveparents': {
                  b'default': False,
                  b'required': False,
                  b'type': b'bool'
                },
                b'nodes': {
                  b'required': True,
                  b'type': b'list'
                },
                b'tree': {
                  b'required': True,
                  b'type': b'bytes'
                }
              },
              b'permissions': [
                b'pull'
              ],
              b'recommendedbatchsize': 100000
            },
            b'pushkey': {
              b'args': {
                b'key': {
                  b'required': True,
                  b'type': b'bytes'
                },
                b'namespace': {
                  b'required': True,
                  b'type': b'bytes'
                },
                b'new': {
                  b'required': True,
                  b'type': b'bytes'
                },
                b'old': {
                  b'required': True,
                  b'type': b'bytes'
                }
              },
              b'permissions': [
                b'push'
              ]
            },
            b'rawstorefiledata': {
              b'args': {
                b'files': {
                  b'required': True,
                  b'type': b'list'
                },
                b'pathfilter': {
                  b'default': None,
                  b'required': False,
                  b'type': b'list'
                }
              },
              b'permissions': [
                b'pull'
              ]
            }
          },
          b'framingmediatypes': [
            b'application/mercurial-exp-framing-0006'
          ],
          b'pathfilterprefixes': set([
            b'path:',
            b'rootfilesin:'
          ]),
          b'rawrepoformats': [
            b'generaldelta',
            b'revlogv1'
          ]
        }
      },
      b'v1capabilities': b'batch branchmap $USUAL_BUNDLE2_CAPS$ changegroupsubset compression=$BUNDLE2_COMPRESSIONS$ getbundle httpheader=1024 httpmediatype=0.1rx,0.1tx,0.2tx known lookup pushkey streamreqs=generaldelta,revlogv1 unbundle=HG10GZ,HG10BZ,HG10UN unbundlehash'
    }
  ]

capabilities command returns expected info

  $ sendhttpv2peerhandshake << EOF
  > command capabilities
  > EOF
  creating http peer for wire protocol version 2
  s>     GET /?cmd=capabilities HTTP/1.1\r\n
  s>     Accept-Encoding: identity\r\n
  s>     vary: X-HgProto-1,X-HgUpgrade-1\r\n
  s>     x-hgproto-1: cbor\r\n
  s>     x-hgupgrade-1: exp-http-v2-0003\r\n
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
  s>     \xa3GapibaseDapi/Dapis\xa1Pexp-http-v2-0003\xa4Hcommands\xacIbranchmap\xa2Dargs\xa0Kpermissions\x81DpullLcapabilities\xa2Dargs\xa0Kpermissions\x81DpullMchangesetdata\xa2Dargs\xa2Ffields\xa4Gdefault\xd9\x01\x02\x80Hrequired\xf4DtypeCsetKvalidvalues\xd9\x01\x02\x84IbookmarksGparentsEphaseHrevisionIrevisions\xa2Hrequired\xf5DtypeDlistKpermissions\x81DpullHfiledata\xa2Dargs\xa4Ffields\xa4Gdefault\xd9\x01\x02\x80Hrequired\xf4DtypeCsetKvalidvalues\xd9\x01\x02\x83HlinknodeGparentsHrevisionKhaveparents\xa3Gdefault\xf4Hrequired\xf4DtypeDboolEnodes\xa2Hrequired\xf5DtypeDlistDpath\xa2Hrequired\xf5DtypeEbytesKpermissions\x81DpullIfilesdata\xa3Dargs\xa4Ffields\xa4Gdefault\xd9\x01\x02\x80Hrequired\xf4DtypeCsetKvalidvalues\xd9\x01\x02\x84NfirstchangesetHlinknodeGparentsHrevisionKhaveparents\xa3Gdefault\xf4Hrequired\xf4DtypeDboolJpathfilter\xa3Gdefault\xf6Hrequired\xf4DtypeDdictIrevisions\xa2Hrequired\xf5DtypeDlistKpermissions\x81DpullTrecommendedbatchsize\x19\xc3PEheads\xa2Dargs\xa1Jpubliconly\xa3Gdefault\xf4Hrequired\xf4DtypeDboolKpermissions\x81DpullEknown\xa2Dargs\xa1Enodes\xa3Gdefault\x80Hrequired\xf4DtypeDlistKpermissions\x81DpullHlistkeys\xa2Dargs\xa1Inamespace\xa2Hrequired\xf5DtypeEbytesKpermissions\x81DpullFlookup\xa2Dargs\xa1Ckey\xa2Hrequired\xf5DtypeEbytesKpermissions\x81DpullLmanifestdata\xa3Dargs\xa4Ffields\xa4Gdefault\xd9\x01\x02\x80Hrequired\xf4DtypeCsetKvalidvalues\xd9\x01\x02\x82GparentsHrevisionKhaveparents\xa3Gdefault\xf4Hrequired\xf4DtypeDboolEnodes\xa2Hrequired\xf5DtypeDlistDtree\xa2Hrequired\xf5DtypeEbytesKpermissions\x81DpullTrecommendedbatchsize\x1a\x00\x01\x86\xa0Gpushkey\xa2Dargs\xa4Ckey\xa2Hrequired\xf5DtypeEbytesInamespace\xa2Hrequired\xf5DtypeEbytesCnew\xa2Hrequired\xf5DtypeEbytesCold\xa2Hrequired\xf5DtypeEbytesKpermissions\x81DpushPrawstorefiledata\xa2Dargs\xa2Efiles\xa2Hrequired\xf5DtypeDlistJpathfilter\xa3Gdefault\xf6Hrequired\xf4DtypeDlistKpermissions\x81DpullQframingmediatypes\x81X&application/mercurial-exp-framing-0006Rpathfilterprefixes\xd9\x01\x02\x82Epath:Lrootfilesin:Nrawrepoformats\x82LgeneraldeltaHrevlogv1Nv1capabilitiesY\x01\xd3batch branchmap $USUAL_BUNDLE2_CAPS$ changegroupsubset compression=$BUNDLE2_COMPRESSIONS$ getbundle httpheader=1024 httpmediatype=0.1rx,0.1tx,0.2tx known lookup pushkey streamreqs=generaldelta,revlogv1 unbundle=HG10GZ,HG10BZ,HG10UN unbundlehash
  sending capabilities command
  s>     POST /api/exp-http-v2-0003/ro/capabilities HTTP/1.1\r\n
  s>     Accept-Encoding: identity\r\n
  s>     accept: application/mercurial-exp-framing-0006\r\n
  s>     content-type: application/mercurial-exp-framing-0006\r\n
  s>     content-length: 63\r\n
  s>     host: $LOCALIP:$HGPORT\r\n (glob)
  s>     user-agent: Mercurial debugwireproto\r\n
  s>     \r\n
  s>     \x1c\x00\x00\x01\x00\x01\x01\x82\xa1Pcontentencodings\x81Hidentity\x13\x00\x00\x01\x00\x01\x00\x11\xa1DnameLcapabilities
  s> makefile('rb', None)
  s>     HTTP/1.1 200 OK\r\n
  s>     Server: testing stub value\r\n
  s>     Date: $HTTP_DATE$\r\n
  s>     Content-Type: application/mercurial-exp-framing-0006\r\n
  s>     Transfer-Encoding: chunked\r\n
  s>     \r\n
  s>     11\r\n
  s>     \t\x00\x00\x01\x00\x02\x01\x92
  s>     Hidentity
  s>     \r\n
  received frame(size=9; request=1; stream=2; streamflags=stream-begin; type=stream-settings; flags=eos)
  s>     13\r\n
  s>     \x0b\x00\x00\x01\x00\x02\x041
  s>     \xa1FstatusBok
  s>     \r\n
  received frame(size=11; request=1; stream=2; streamflags=encoded; type=command-response; flags=continuation)
  s>     651\r\n
  s>     I\x06\x00\x01\x00\x02\x041
  s>     \xa4Hcommands\xacIbranchmap\xa2Dargs\xa0Kpermissions\x81DpullLcapabilities\xa2Dargs\xa0Kpermissions\x81DpullMchangesetdata\xa2Dargs\xa2Ffields\xa4Gdefault\xd9\x01\x02\x80Hrequired\xf4DtypeCsetKvalidvalues\xd9\x01\x02\x84IbookmarksGparentsEphaseHrevisionIrevisions\xa2Hrequired\xf5DtypeDlistKpermissions\x81DpullHfiledata\xa2Dargs\xa4Ffields\xa4Gdefault\xd9\x01\x02\x80Hrequired\xf4DtypeCsetKvalidvalues\xd9\x01\x02\x83HlinknodeGparentsHrevisionKhaveparents\xa3Gdefault\xf4Hrequired\xf4DtypeDboolEnodes\xa2Hrequired\xf5DtypeDlistDpath\xa2Hrequired\xf5DtypeEbytesKpermissions\x81DpullIfilesdata\xa3Dargs\xa4Ffields\xa4Gdefault\xd9\x01\x02\x80Hrequired\xf4DtypeCsetKvalidvalues\xd9\x01\x02\x84NfirstchangesetHlinknodeGparentsHrevisionKhaveparents\xa3Gdefault\xf4Hrequired\xf4DtypeDboolJpathfilter\xa3Gdefault\xf6Hrequired\xf4DtypeDdictIrevisions\xa2Hrequired\xf5DtypeDlistKpermissions\x81DpullTrecommendedbatchsize\x19\xc3PEheads\xa2Dargs\xa1Jpubliconly\xa3Gdefault\xf4Hrequired\xf4DtypeDboolKpermissions\x81DpullEknown\xa2Dargs\xa1Enodes\xa3Gdefault\x80Hrequired\xf4DtypeDlistKpermissions\x81DpullHlistkeys\xa2Dargs\xa1Inamespace\xa2Hrequired\xf5DtypeEbytesKpermissions\x81DpullFlookup\xa2Dargs\xa1Ckey\xa2Hrequired\xf5DtypeEbytesKpermissions\x81DpullLmanifestdata\xa3Dargs\xa4Ffields\xa4Gdefault\xd9\x01\x02\x80Hrequired\xf4DtypeCsetKvalidvalues\xd9\x01\x02\x82GparentsHrevisionKhaveparents\xa3Gdefault\xf4Hrequired\xf4DtypeDboolEnodes\xa2Hrequired\xf5DtypeDlistDtree\xa2Hrequired\xf5DtypeEbytesKpermissions\x81DpullTrecommendedbatchsize\x1a\x00\x01\x86\xa0Gpushkey\xa2Dargs\xa4Ckey\xa2Hrequired\xf5DtypeEbytesInamespace\xa2Hrequired\xf5DtypeEbytesCnew\xa2Hrequired\xf5DtypeEbytesCold\xa2Hrequired\xf5DtypeEbytesKpermissions\x81DpushPrawstorefiledata\xa2Dargs\xa2Efiles\xa2Hrequired\xf5DtypeDlistJpathfilter\xa3Gdefault\xf6Hrequired\xf4DtypeDlistKpermissions\x81DpullQframingmediatypes\x81X&application/mercurial-exp-framing-0006Rpathfilterprefixes\xd9\x01\x02\x82Epath:Lrootfilesin:Nrawrepoformats\x82LgeneraldeltaHrevlogv1
  s>     \r\n
  received frame(size=1609; request=1; stream=2; streamflags=encoded; type=command-response; flags=continuation)
  s>     8\r\n
  s>     \x00\x00\x00\x01\x00\x02\x002
  s>     \r\n
  s>     0\r\n
  s>     \r\n
  received frame(size=0; request=1; stream=2; streamflags=; type=command-response; flags=eos)
  response: gen[
    {
      b'commands': {
        b'branchmap': {
          b'args': {},
          b'permissions': [
            b'pull'
          ]
        },
        b'capabilities': {
          b'args': {},
          b'permissions': [
            b'pull'
          ]
        },
        b'changesetdata': {
          b'args': {
            b'fields': {
              b'default': set([]),
              b'required': False,
              b'type': b'set',
              b'validvalues': set([
                b'bookmarks',
                b'parents',
                b'phase',
                b'revision'
              ])
            },
            b'revisions': {
              b'required': True,
              b'type': b'list'
            }
          },
          b'permissions': [
            b'pull'
          ]
        },
        b'filedata': {
          b'args': {
            b'fields': {
              b'default': set([]),
              b'required': False,
              b'type': b'set',
              b'validvalues': set([
                b'linknode',
                b'parents',
                b'revision'
              ])
            },
            b'haveparents': {
              b'default': False,
              b'required': False,
              b'type': b'bool'
            },
            b'nodes': {
              b'required': True,
              b'type': b'list'
            },
            b'path': {
              b'required': True,
              b'type': b'bytes'
            }
          },
          b'permissions': [
            b'pull'
          ]
        },
        b'filesdata': {
          b'args': {
            b'fields': {
              b'default': set([]),
              b'required': False,
              b'type': b'set',
              b'validvalues': set([
                b'firstchangeset',
                b'linknode',
                b'parents',
                b'revision'
              ])
            },
            b'haveparents': {
              b'default': False,
              b'required': False,
              b'type': b'bool'
            },
            b'pathfilter': {
              b'default': None,
              b'required': False,
              b'type': b'dict'
            },
            b'revisions': {
              b'required': True,
              b'type': b'list'
            }
          },
          b'permissions': [
            b'pull'
          ],
          b'recommendedbatchsize': 50000
        },
        b'heads': {
          b'args': {
            b'publiconly': {
              b'default': False,
              b'required': False,
              b'type': b'bool'
            }
          },
          b'permissions': [
            b'pull'
          ]
        },
        b'known': {
          b'args': {
            b'nodes': {
              b'default': [],
              b'required': False,
              b'type': b'list'
            }
          },
          b'permissions': [
            b'pull'
          ]
        },
        b'listkeys': {
          b'args': {
            b'namespace': {
              b'required': True,
              b'type': b'bytes'
            }
          },
          b'permissions': [
            b'pull'
          ]
        },
        b'lookup': {
          b'args': {
            b'key': {
              b'required': True,
              b'type': b'bytes'
            }
          },
          b'permissions': [
            b'pull'
          ]
        },
        b'manifestdata': {
          b'args': {
            b'fields': {
              b'default': set([]),
              b'required': False,
              b'type': b'set',
              b'validvalues': set([
                b'parents',
                b'revision'
              ])
            },
            b'haveparents': {
              b'default': False,
              b'required': False,
              b'type': b'bool'
            },
            b'nodes': {
              b'required': True,
              b'type': b'list'
            },
            b'tree': {
              b'required': True,
              b'type': b'bytes'
            }
          },
          b'permissions': [
            b'pull'
          ],
          b'recommendedbatchsize': 100000
        },
        b'pushkey': {
          b'args': {
            b'key': {
              b'required': True,
              b'type': b'bytes'
            },
            b'namespace': {
              b'required': True,
              b'type': b'bytes'
            },
            b'new': {
              b'required': True,
              b'type': b'bytes'
            },
            b'old': {
              b'required': True,
              b'type': b'bytes'
            }
          },
          b'permissions': [
            b'push'
          ]
        },
        b'rawstorefiledata': {
          b'args': {
            b'files': {
              b'required': True,
              b'type': b'list'
            },
            b'pathfilter': {
              b'default': None,
              b'required': False,
              b'type': b'list'
            }
          },
          b'permissions': [
            b'pull'
          ]
        }
      },
      b'framingmediatypes': [
        b'application/mercurial-exp-framing-0006'
      ],
      b'pathfilterprefixes': set([
        b'path:',
        b'rootfilesin:'
      ]),
      b'rawrepoformats': [
        b'generaldelta',
        b'revlogv1'
      ]
    }
  ]
  (sent 2 HTTP requests and * bytes; received * bytes in responses) (glob)

  $ cat error.log
