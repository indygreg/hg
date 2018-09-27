  $ . $TESTDIR/wireprotohelpers.sh

  $ cat >> $HGRCPATH << EOF
  > [extensions]
  > blackbox =
  > [blackbox]
  > track = simplecache
  > EOF

  $ hg init server
  $ enablehttpv2 server
  $ cd server
  $ cat >> .hg/hgrc << EOF
  > [extensions]
  > simplecache = $TESTDIR/wireprotosimplecache.py
  > [simplecache]
  > cacheapi = true
  > EOF

  $ echo a0 > a
  $ echo b0 > b
  $ hg -q commit -A -m 'commit 0'
  $ echo a1 > a
  $ hg commit -m 'commit 1'

  $ hg --debug debugindex -m
     rev linkrev nodeid                                   p1                                       p2
       0       0 992f4779029a3df8d0666d00bb924f69634e2641 0000000000000000000000000000000000000000 0000000000000000000000000000000000000000
       1       1 a988fb43583e871d1ed5750ee074c6d840bbbfc8 992f4779029a3df8d0666d00bb924f69634e2641 0000000000000000000000000000000000000000

  $ hg --config simplecache.redirectsfile=redirects.py serve -p $HGPORT -d --pid-file hg.pid -E error.log
  $ cat hg.pid > $DAEMON_PIDS

  $ cat > redirects.py << EOF
  > [
  >   {
  >     b'name': b'target-a',
  >     b'protocol': b'http',
  >     b'snirequired': False,
  >     b'tlsversions': [b'1.2', b'1.3'],
  >     b'uris': [b'http://example.com/'],
  >   },
  > ]
  > EOF

Redirect targets advertised when configured

  $ sendhttpv2peerhandshake << EOF
  > command capabilities
  > EOF
  creating http peer for wire protocol version 2
  s>     GET /?cmd=capabilities HTTP/1.1\r\n
  s>     Accept-Encoding: identity\r\n
  s>     vary: X-HgProto-1,X-HgUpgrade-1\r\n
  s>     x-hgproto-1: cbor\r\n
  s>     x-hgupgrade-1: exp-http-v2-0002\r\n
  s>     accept: application/mercurial-0.1\r\n
  s>     host: $LOCALIP:$HGPORT\r\n (glob)
  s>     user-agent: Mercurial debugwireproto\r\n
  s>     \r\n
  s> makefile('rb', None)
  s>     HTTP/1.1 200 OK\r\n
  s>     Server: testing stub value\r\n
  s>     Date: $HTTP_DATE$\r\n
  s>     Content-Type: application/mercurial-cbor\r\n
  s>     Content-Length: 1970\r\n
  s>     \r\n
  s>     \xa3GapibaseDapi/Dapis\xa1Pexp-http-v2-0002\xa6Hcommands\xaaIbranchmap\xa2Dargs\xa0Kpermissions\x81DpullLcapabilities\xa2Dargs\xa0Kpermissions\x81DpullMchangesetdata\xa2Dargs\xa4Ffields\xa4Gdefault\xd9\x01\x02\x80Hrequired\xf4DtypeCsetKvalidvalues\xd9\x01\x02\x84IbookmarksGparentsEphaseHrevisionInoderange\xa3Gdefault\xf6Hrequired\xf4DtypeDlistEnodes\xa3Gdefault\xf6Hrequired\xf4DtypeDlistJnodesdepth\xa3Gdefault\xf6Hrequired\xf4DtypeCintKpermissions\x81DpullHfiledata\xa2Dargs\xa4Ffields\xa4Gdefault\xd9\x01\x02\x80Hrequired\xf4DtypeCsetKvalidvalues\xd9\x01\x02\x82GparentsHrevisionKhaveparents\xa3Gdefault\xf4Hrequired\xf4DtypeDboolEnodes\xa2Hrequired\xf5DtypeDlistDpath\xa2Hrequired\xf5DtypeEbytesKpermissions\x81DpullEheads\xa2Dargs\xa1Jpubliconly\xa3Gdefault\xf4Hrequired\xf4DtypeDboolKpermissions\x81DpullEknown\xa2Dargs\xa1Enodes\xa3Gdefault\x80Hrequired\xf4DtypeDlistKpermissions\x81DpullHlistkeys\xa2Dargs\xa1Inamespace\xa2Hrequired\xf5DtypeEbytesKpermissions\x81DpullFlookup\xa2Dargs\xa1Ckey\xa2Hrequired\xf5DtypeEbytesKpermissions\x81DpullLmanifestdata\xa2Dargs\xa4Ffields\xa4Gdefault\xd9\x01\x02\x80Hrequired\xf4DtypeCsetKvalidvalues\xd9\x01\x02\x82GparentsHrevisionKhaveparents\xa3Gdefault\xf4Hrequired\xf4DtypeDboolEnodes\xa2Hrequired\xf5DtypeDlistDtree\xa2Hrequired\xf5DtypeEbytesKpermissions\x81DpullGpushkey\xa2Dargs\xa4Ckey\xa2Hrequired\xf5DtypeEbytesInamespace\xa2Hrequired\xf5DtypeEbytesCnew\xa2Hrequired\xf5DtypeEbytesCold\xa2Hrequired\xf5DtypeEbytesKpermissions\x81DpushKcompression\x82\xa1DnameDzstd\xa1DnameDzlibQframingmediatypes\x81X&application/mercurial-exp-framing-0005Rpathfilterprefixes\xd9\x01\x02\x82Epath:Lrootfilesin:Nrawrepoformats\x82LgeneraldeltaHrevlogv1Hredirect\xa2Fhashes\x82Fsha256Dsha1Gtargets\x81\xa5DnameHtarget-aHprotocolDhttpKsnirequired\xf4Ktlsversions\x82C1.2C1.3Duris\x81Shttp://example.com/Nv1capabilitiesY\x01\xd8batch branchmap $USUAL_BUNDLE2_CAPS$ changegroupsubset compression=$BUNDLE2_COMPRESSIONS$ getbundle httpheader=1024 httpmediatype=0.1rx,0.1tx,0.2tx known lookup pushkey streamreqs=generaldelta,revlogv1 unbundle=HG10GZ,HG10BZ,HG10UN unbundlehash
  (remote redirect target target-a is compatible)
  sending capabilities command
  s>     POST /api/exp-http-v2-0002/ro/capabilities HTTP/1.1\r\n
  s>     Accept-Encoding: identity\r\n
  s>     accept: application/mercurial-exp-framing-0005\r\n
  s>     content-type: application/mercurial-exp-framing-0005\r\n
  s>     content-length: 75\r\n
  s>     host: $LOCALIP:$HGPORT\r\n (glob)
  s>     user-agent: Mercurial debugwireproto\r\n
  s>     \r\n
  s>     C\x00\x00\x01\x00\x01\x01\x11\xa2DnameLcapabilitiesHredirect\xa2Fhashes\x82Fsha256Dsha1Gtargets\x81Htarget-a
  s> makefile('rb', None)
  s>     HTTP/1.1 200 OK\r\n
  s>     Server: testing stub value\r\n
  s>     Date: $HTTP_DATE$\r\n
  s>     Content-Type: application/mercurial-exp-framing-0005\r\n
  s>     Transfer-Encoding: chunked\r\n
  s>     \r\n
  s>     13\r\n
  s>     \x0b\x00\x00\x01\x00\x02\x011
  s>     \xa1FstatusBok
  s>     \r\n
  received frame(size=11; request=1; stream=2; streamflags=stream-begin; type=command-response; flags=continuation)
  s>     5ab\r\n
  s>     \xa3\x05\x00\x01\x00\x02\x001
  s>     \xa6Hcommands\xaaIbranchmap\xa2Dargs\xa0Kpermissions\x81DpullLcapabilities\xa2Dargs\xa0Kpermissions\x81DpullMchangesetdata\xa2Dargs\xa4Ffields\xa4Gdefault\xd9\x01\x02\x80Hrequired\xf4DtypeCsetKvalidvalues\xd9\x01\x02\x84IbookmarksGparentsEphaseHrevisionInoderange\xa3Gdefault\xf6Hrequired\xf4DtypeDlistEnodes\xa3Gdefault\xf6Hrequired\xf4DtypeDlistJnodesdepth\xa3Gdefault\xf6Hrequired\xf4DtypeCintKpermissions\x81DpullHfiledata\xa2Dargs\xa4Ffields\xa4Gdefault\xd9\x01\x02\x80Hrequired\xf4DtypeCsetKvalidvalues\xd9\x01\x02\x82GparentsHrevisionKhaveparents\xa3Gdefault\xf4Hrequired\xf4DtypeDboolEnodes\xa2Hrequired\xf5DtypeDlistDpath\xa2Hrequired\xf5DtypeEbytesKpermissions\x81DpullEheads\xa2Dargs\xa1Jpubliconly\xa3Gdefault\xf4Hrequired\xf4DtypeDboolKpermissions\x81DpullEknown\xa2Dargs\xa1Enodes\xa3Gdefault\x80Hrequired\xf4DtypeDlistKpermissions\x81DpullHlistkeys\xa2Dargs\xa1Inamespace\xa2Hrequired\xf5DtypeEbytesKpermissions\x81DpullFlookup\xa2Dargs\xa1Ckey\xa2Hrequired\xf5DtypeEbytesKpermissions\x81DpullLmanifestdata\xa2Dargs\xa4Ffields\xa4Gdefault\xd9\x01\x02\x80Hrequired\xf4DtypeCsetKvalidvalues\xd9\x01\x02\x82GparentsHrevisionKhaveparents\xa3Gdefault\xf4Hrequired\xf4DtypeDboolEnodes\xa2Hrequired\xf5DtypeDlistDtree\xa2Hrequired\xf5DtypeEbytesKpermissions\x81DpullGpushkey\xa2Dargs\xa4Ckey\xa2Hrequired\xf5DtypeEbytesInamespace\xa2Hrequired\xf5DtypeEbytesCnew\xa2Hrequired\xf5DtypeEbytesCold\xa2Hrequired\xf5DtypeEbytesKpermissions\x81DpushKcompression\x82\xa1DnameDzstd\xa1DnameDzlibQframingmediatypes\x81X&application/mercurial-exp-framing-0005Rpathfilterprefixes\xd9\x01\x02\x82Epath:Lrootfilesin:Nrawrepoformats\x82LgeneraldeltaHrevlogv1Hredirect\xa2Fhashes\x82Fsha256Dsha1Gtargets\x81\xa5DnameHtarget-aHprotocolDhttpKsnirequired\xf4Ktlsversions\x82C1.2C1.3Duris\x81Shttp://example.com/
  s>     \r\n
  received frame(size=1443; request=1; stream=2; streamflags=; type=command-response; flags=continuation)
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
            b'noderange': {
              b'default': None,
              b'required': False,
              b'type': b'list'
            },
            b'nodes': {
              b'default': None,
              b'required': False,
              b'type': b'list'
            },
            b'nodesdepth': {
              b'default': None,
              b'required': False,
              b'type': b'int'
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
          ]
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
        }
      },
      b'compression': [
        {
          b'name': b'zstd'
        },
        {
          b'name': b'zlib'
        }
      ],
      b'framingmediatypes': [
        b'application/mercurial-exp-framing-0005'
      ],
      b'pathfilterprefixes': set([
        b'path:',
        b'rootfilesin:'
      ]),
      b'rawrepoformats': [
        b'generaldelta',
        b'revlogv1'
      ],
      b'redirect': {
        b'hashes': [
          b'sha256',
          b'sha1'
        ],
        b'targets': [
          {
            b'name': b'target-a',
            b'protocol': b'http',
            b'snirequired': False,
            b'tlsversions': [
              b'1.2',
              b'1.3'
            ],
            b'uris': [
              b'http://example.com/'
            ]
          }
        ]
      }
    }
  ]

Unknown protocol is filtered from compatible targets

  $ cat > redirects.py << EOF
  > [
  >   {
  >     b'name': b'target-a',
  >     b'protocol': b'http',
  >     b'uris': [b'http://example.com/'],
  >   },
  >   {
  >     b'name': b'target-b',
  >     b'protocol': b'unknown',
  >     b'uris': [b'unknown://example.com/'],
  >   },
  > ]
  > EOF

  $ sendhttpv2peerhandshake << EOF
  > command capabilities
  > EOF
  creating http peer for wire protocol version 2
  s>     GET /?cmd=capabilities HTTP/1.1\r\n
  s>     Accept-Encoding: identity\r\n
  s>     vary: X-HgProto-1,X-HgUpgrade-1\r\n
  s>     x-hgproto-1: cbor\r\n
  s>     x-hgupgrade-1: exp-http-v2-0002\r\n
  s>     accept: application/mercurial-0.1\r\n
  s>     host: $LOCALIP:$HGPORT\r\n (glob)
  s>     user-agent: Mercurial debugwireproto\r\n
  s>     \r\n
  s> makefile('rb', None)
  s>     HTTP/1.1 200 OK\r\n
  s>     Server: testing stub value\r\n
  s>     Date: $HTTP_DATE$\r\n
  s>     Content-Type: application/mercurial-cbor\r\n
  s>     Content-Length: 1997\r\n
  s>     \r\n
  s>     \xa3GapibaseDapi/Dapis\xa1Pexp-http-v2-0002\xa6Hcommands\xaaIbranchmap\xa2Dargs\xa0Kpermissions\x81DpullLcapabilities\xa2Dargs\xa0Kpermissions\x81DpullMchangesetdata\xa2Dargs\xa4Ffields\xa4Gdefault\xd9\x01\x02\x80Hrequired\xf4DtypeCsetKvalidvalues\xd9\x01\x02\x84IbookmarksGparentsEphaseHrevisionInoderange\xa3Gdefault\xf6Hrequired\xf4DtypeDlistEnodes\xa3Gdefault\xf6Hrequired\xf4DtypeDlistJnodesdepth\xa3Gdefault\xf6Hrequired\xf4DtypeCintKpermissions\x81DpullHfiledata\xa2Dargs\xa4Ffields\xa4Gdefault\xd9\x01\x02\x80Hrequired\xf4DtypeCsetKvalidvalues\xd9\x01\x02\x82GparentsHrevisionKhaveparents\xa3Gdefault\xf4Hrequired\xf4DtypeDboolEnodes\xa2Hrequired\xf5DtypeDlistDpath\xa2Hrequired\xf5DtypeEbytesKpermissions\x81DpullEheads\xa2Dargs\xa1Jpubliconly\xa3Gdefault\xf4Hrequired\xf4DtypeDboolKpermissions\x81DpullEknown\xa2Dargs\xa1Enodes\xa3Gdefault\x80Hrequired\xf4DtypeDlistKpermissions\x81DpullHlistkeys\xa2Dargs\xa1Inamespace\xa2Hrequired\xf5DtypeEbytesKpermissions\x81DpullFlookup\xa2Dargs\xa1Ckey\xa2Hrequired\xf5DtypeEbytesKpermissions\x81DpullLmanifestdata\xa2Dargs\xa4Ffields\xa4Gdefault\xd9\x01\x02\x80Hrequired\xf4DtypeCsetKvalidvalues\xd9\x01\x02\x82GparentsHrevisionKhaveparents\xa3Gdefault\xf4Hrequired\xf4DtypeDboolEnodes\xa2Hrequired\xf5DtypeDlistDtree\xa2Hrequired\xf5DtypeEbytesKpermissions\x81DpullGpushkey\xa2Dargs\xa4Ckey\xa2Hrequired\xf5DtypeEbytesInamespace\xa2Hrequired\xf5DtypeEbytesCnew\xa2Hrequired\xf5DtypeEbytesCold\xa2Hrequired\xf5DtypeEbytesKpermissions\x81DpushKcompression\x82\xa1DnameDzstd\xa1DnameDzlibQframingmediatypes\x81X&application/mercurial-exp-framing-0005Rpathfilterprefixes\xd9\x01\x02\x82Epath:Lrootfilesin:Nrawrepoformats\x82LgeneraldeltaHrevlogv1Hredirect\xa2Fhashes\x82Fsha256Dsha1Gtargets\x82\xa3DnameHtarget-aHprotocolDhttpDuris\x81Shttp://example.com/\xa3DnameHtarget-bHprotocolGunknownDuris\x81Vunknown://example.com/Nv1capabilitiesY\x01\xd8batch branchmap $USUAL_BUNDLE2_CAPS$ changegroupsubset compression=$BUNDLE2_COMPRESSIONS$ getbundle httpheader=1024 httpmediatype=0.1rx,0.1tx,0.2tx known lookup pushkey streamreqs=generaldelta,revlogv1 unbundle=HG10GZ,HG10BZ,HG10UN unbundlehash
  (remote redirect target target-a is compatible)
  (remote redirect target target-b uses unsupported protocol: unknown)
  sending capabilities command
  s>     POST /api/exp-http-v2-0002/ro/capabilities HTTP/1.1\r\n
  s>     Accept-Encoding: identity\r\n
  s>     accept: application/mercurial-exp-framing-0005\r\n
  s>     content-type: application/mercurial-exp-framing-0005\r\n
  s>     content-length: 75\r\n
  s>     host: $LOCALIP:$HGPORT\r\n (glob)
  s>     user-agent: Mercurial debugwireproto\r\n
  s>     \r\n
  s>     C\x00\x00\x01\x00\x01\x01\x11\xa2DnameLcapabilitiesHredirect\xa2Fhashes\x82Fsha256Dsha1Gtargets\x81Htarget-a
  s> makefile('rb', None)
  s>     HTTP/1.1 200 OK\r\n
  s>     Server: testing stub value\r\n
  s>     Date: $HTTP_DATE$\r\n
  s>     Content-Type: application/mercurial-exp-framing-0005\r\n
  s>     Transfer-Encoding: chunked\r\n
  s>     \r\n
  s>     13\r\n
  s>     \x0b\x00\x00\x01\x00\x02\x011
  s>     \xa1FstatusBok
  s>     \r\n
  received frame(size=11; request=1; stream=2; streamflags=stream-begin; type=command-response; flags=continuation)
  s>     5c6\r\n
  s>     \xbe\x05\x00\x01\x00\x02\x001
  s>     \xa6Hcommands\xaaIbranchmap\xa2Dargs\xa0Kpermissions\x81DpullLcapabilities\xa2Dargs\xa0Kpermissions\x81DpullMchangesetdata\xa2Dargs\xa4Ffields\xa4Gdefault\xd9\x01\x02\x80Hrequired\xf4DtypeCsetKvalidvalues\xd9\x01\x02\x84IbookmarksGparentsEphaseHrevisionInoderange\xa3Gdefault\xf6Hrequired\xf4DtypeDlistEnodes\xa3Gdefault\xf6Hrequired\xf4DtypeDlistJnodesdepth\xa3Gdefault\xf6Hrequired\xf4DtypeCintKpermissions\x81DpullHfiledata\xa2Dargs\xa4Ffields\xa4Gdefault\xd9\x01\x02\x80Hrequired\xf4DtypeCsetKvalidvalues\xd9\x01\x02\x82GparentsHrevisionKhaveparents\xa3Gdefault\xf4Hrequired\xf4DtypeDboolEnodes\xa2Hrequired\xf5DtypeDlistDpath\xa2Hrequired\xf5DtypeEbytesKpermissions\x81DpullEheads\xa2Dargs\xa1Jpubliconly\xa3Gdefault\xf4Hrequired\xf4DtypeDboolKpermissions\x81DpullEknown\xa2Dargs\xa1Enodes\xa3Gdefault\x80Hrequired\xf4DtypeDlistKpermissions\x81DpullHlistkeys\xa2Dargs\xa1Inamespace\xa2Hrequired\xf5DtypeEbytesKpermissions\x81DpullFlookup\xa2Dargs\xa1Ckey\xa2Hrequired\xf5DtypeEbytesKpermissions\x81DpullLmanifestdata\xa2Dargs\xa4Ffields\xa4Gdefault\xd9\x01\x02\x80Hrequired\xf4DtypeCsetKvalidvalues\xd9\x01\x02\x82GparentsHrevisionKhaveparents\xa3Gdefault\xf4Hrequired\xf4DtypeDboolEnodes\xa2Hrequired\xf5DtypeDlistDtree\xa2Hrequired\xf5DtypeEbytesKpermissions\x81DpullGpushkey\xa2Dargs\xa4Ckey\xa2Hrequired\xf5DtypeEbytesInamespace\xa2Hrequired\xf5DtypeEbytesCnew\xa2Hrequired\xf5DtypeEbytesCold\xa2Hrequired\xf5DtypeEbytesKpermissions\x81DpushKcompression\x82\xa1DnameDzstd\xa1DnameDzlibQframingmediatypes\x81X&application/mercurial-exp-framing-0005Rpathfilterprefixes\xd9\x01\x02\x82Epath:Lrootfilesin:Nrawrepoformats\x82LgeneraldeltaHrevlogv1Hredirect\xa2Fhashes\x82Fsha256Dsha1Gtargets\x82\xa3DnameHtarget-aHprotocolDhttpDuris\x81Shttp://example.com/\xa3DnameHtarget-bHprotocolGunknownDuris\x81Vunknown://example.com/
  s>     \r\n
  received frame(size=1470; request=1; stream=2; streamflags=; type=command-response; flags=continuation)
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
            b'noderange': {
              b'default': None,
              b'required': False,
              b'type': b'list'
            },
            b'nodes': {
              b'default': None,
              b'required': False,
              b'type': b'list'
            },
            b'nodesdepth': {
              b'default': None,
              b'required': False,
              b'type': b'int'
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
          ]
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
        }
      },
      b'compression': [
        {
          b'name': b'zstd'
        },
        {
          b'name': b'zlib'
        }
      ],
      b'framingmediatypes': [
        b'application/mercurial-exp-framing-0005'
      ],
      b'pathfilterprefixes': set([
        b'path:',
        b'rootfilesin:'
      ]),
      b'rawrepoformats': [
        b'generaldelta',
        b'revlogv1'
      ],
      b'redirect': {
        b'hashes': [
          b'sha256',
          b'sha1'
        ],
        b'targets': [
          {
            b'name': b'target-a',
            b'protocol': b'http',
            b'uris': [
              b'http://example.com/'
            ]
          },
          {
            b'name': b'target-b',
            b'protocol': b'unknown',
            b'uris': [
              b'unknown://example.com/'
            ]
          }
        ]
      }
    }
  ]

Missing SNI support filters targets that require SNI

  $ cat > nosni.py << EOF
  > from mercurial import sslutil
  > sslutil.hassni = False
  > EOF
  $ cat >> $HGRCPATH << EOF
  > [extensions]
  > nosni=`pwd`/nosni.py
  > EOF

  $ cat > redirects.py << EOF
  > [
  >   {
  >     b'name': b'target-bad-tls',
  >     b'protocol': b'https',
  >     b'uris': [b'https://example.com/'],
  >     b'snirequired': True,
  >   },
  > ]
  > EOF

  $ sendhttpv2peerhandshake << EOF
  > command capabilities
  > EOF
  creating http peer for wire protocol version 2
  s>     GET /?cmd=capabilities HTTP/1.1\r\n
  s>     Accept-Encoding: identity\r\n
  s>     vary: X-HgProto-1,X-HgUpgrade-1\r\n
  s>     x-hgproto-1: cbor\r\n
  s>     x-hgupgrade-1: exp-http-v2-0002\r\n
  s>     accept: application/mercurial-0.1\r\n
  s>     host: $LOCALIP:$HGPORT\r\n (glob)
  s>     user-agent: Mercurial debugwireproto\r\n
  s>     \r\n
  s> makefile('rb', None)
  s>     HTTP/1.1 200 OK\r\n
  s>     Server: testing stub value\r\n
  s>     Date: $HTTP_DATE$\r\n
  s>     Content-Type: application/mercurial-cbor\r\n
  s>     Content-Length: 1957\r\n
  s>     \r\n
  s>     \xa3GapibaseDapi/Dapis\xa1Pexp-http-v2-0002\xa6Hcommands\xaaIbranchmap\xa2Dargs\xa0Kpermissions\x81DpullLcapabilities\xa2Dargs\xa0Kpermissions\x81DpullMchangesetdata\xa2Dargs\xa4Ffields\xa4Gdefault\xd9\x01\x02\x80Hrequired\xf4DtypeCsetKvalidvalues\xd9\x01\x02\x84IbookmarksGparentsEphaseHrevisionInoderange\xa3Gdefault\xf6Hrequired\xf4DtypeDlistEnodes\xa3Gdefault\xf6Hrequired\xf4DtypeDlistJnodesdepth\xa3Gdefault\xf6Hrequired\xf4DtypeCintKpermissions\x81DpullHfiledata\xa2Dargs\xa4Ffields\xa4Gdefault\xd9\x01\x02\x80Hrequired\xf4DtypeCsetKvalidvalues\xd9\x01\x02\x82GparentsHrevisionKhaveparents\xa3Gdefault\xf4Hrequired\xf4DtypeDboolEnodes\xa2Hrequired\xf5DtypeDlistDpath\xa2Hrequired\xf5DtypeEbytesKpermissions\x81DpullEheads\xa2Dargs\xa1Jpubliconly\xa3Gdefault\xf4Hrequired\xf4DtypeDboolKpermissions\x81DpullEknown\xa2Dargs\xa1Enodes\xa3Gdefault\x80Hrequired\xf4DtypeDlistKpermissions\x81DpullHlistkeys\xa2Dargs\xa1Inamespace\xa2Hrequired\xf5DtypeEbytesKpermissions\x81DpullFlookup\xa2Dargs\xa1Ckey\xa2Hrequired\xf5DtypeEbytesKpermissions\x81DpullLmanifestdata\xa2Dargs\xa4Ffields\xa4Gdefault\xd9\x01\x02\x80Hrequired\xf4DtypeCsetKvalidvalues\xd9\x01\x02\x82GparentsHrevisionKhaveparents\xa3Gdefault\xf4Hrequired\xf4DtypeDboolEnodes\xa2Hrequired\xf5DtypeDlistDtree\xa2Hrequired\xf5DtypeEbytesKpermissions\x81DpullGpushkey\xa2Dargs\xa4Ckey\xa2Hrequired\xf5DtypeEbytesInamespace\xa2Hrequired\xf5DtypeEbytesCnew\xa2Hrequired\xf5DtypeEbytesCold\xa2Hrequired\xf5DtypeEbytesKpermissions\x81DpushKcompression\x82\xa1DnameDzstd\xa1DnameDzlibQframingmediatypes\x81X&application/mercurial-exp-framing-0005Rpathfilterprefixes\xd9\x01\x02\x82Epath:Lrootfilesin:Nrawrepoformats\x82LgeneraldeltaHrevlogv1Hredirect\xa2Fhashes\x82Fsha256Dsha1Gtargets\x81\xa4DnameNtarget-bad-tlsHprotocolEhttpsKsnirequired\xf5Duris\x81Thttps://example.com/Nv1capabilitiesY\x01\xd8batch branchmap $USUAL_BUNDLE2_CAPS$ changegroupsubset compression=$BUNDLE2_COMPRESSIONS$ getbundle httpheader=1024 httpmediatype=0.1rx,0.1tx,0.2tx known lookup pushkey streamreqs=generaldelta,revlogv1 unbundle=HG10GZ,HG10BZ,HG10UN unbundlehash
  (redirect target target-bad-tls requires SNI, which is unsupported)
  sending capabilities command
  s>     POST /api/exp-http-v2-0002/ro/capabilities HTTP/1.1\r\n
  s>     Accept-Encoding: identity\r\n
  s>     accept: application/mercurial-exp-framing-0005\r\n
  s>     content-type: application/mercurial-exp-framing-0005\r\n
  s>     content-length: 66\r\n
  s>     host: $LOCALIP:$HGPORT\r\n (glob)
  s>     user-agent: Mercurial debugwireproto\r\n
  s>     \r\n
  s>     :\x00\x00\x01\x00\x01\x01\x11\xa2DnameLcapabilitiesHredirect\xa2Fhashes\x82Fsha256Dsha1Gtargets\x80
  s> makefile('rb', None)
  s>     HTTP/1.1 200 OK\r\n
  s>     Server: testing stub value\r\n
  s>     Date: $HTTP_DATE$\r\n
  s>     Content-Type: application/mercurial-exp-framing-0005\r\n
  s>     Transfer-Encoding: chunked\r\n
  s>     \r\n
  s>     13\r\n
  s>     \x0b\x00\x00\x01\x00\x02\x011
  s>     \xa1FstatusBok
  s>     \r\n
  received frame(size=11; request=1; stream=2; streamflags=stream-begin; type=command-response; flags=continuation)
  s>     59e\r\n
  s>     \x96\x05\x00\x01\x00\x02\x001
  s>     \xa6Hcommands\xaaIbranchmap\xa2Dargs\xa0Kpermissions\x81DpullLcapabilities\xa2Dargs\xa0Kpermissions\x81DpullMchangesetdata\xa2Dargs\xa4Ffields\xa4Gdefault\xd9\x01\x02\x80Hrequired\xf4DtypeCsetKvalidvalues\xd9\x01\x02\x84IbookmarksGparentsEphaseHrevisionInoderange\xa3Gdefault\xf6Hrequired\xf4DtypeDlistEnodes\xa3Gdefault\xf6Hrequired\xf4DtypeDlistJnodesdepth\xa3Gdefault\xf6Hrequired\xf4DtypeCintKpermissions\x81DpullHfiledata\xa2Dargs\xa4Ffields\xa4Gdefault\xd9\x01\x02\x80Hrequired\xf4DtypeCsetKvalidvalues\xd9\x01\x02\x82GparentsHrevisionKhaveparents\xa3Gdefault\xf4Hrequired\xf4DtypeDboolEnodes\xa2Hrequired\xf5DtypeDlistDpath\xa2Hrequired\xf5DtypeEbytesKpermissions\x81DpullEheads\xa2Dargs\xa1Jpubliconly\xa3Gdefault\xf4Hrequired\xf4DtypeDboolKpermissions\x81DpullEknown\xa2Dargs\xa1Enodes\xa3Gdefault\x80Hrequired\xf4DtypeDlistKpermissions\x81DpullHlistkeys\xa2Dargs\xa1Inamespace\xa2Hrequired\xf5DtypeEbytesKpermissions\x81DpullFlookup\xa2Dargs\xa1Ckey\xa2Hrequired\xf5DtypeEbytesKpermissions\x81DpullLmanifestdata\xa2Dargs\xa4Ffields\xa4Gdefault\xd9\x01\x02\x80Hrequired\xf4DtypeCsetKvalidvalues\xd9\x01\x02\x82GparentsHrevisionKhaveparents\xa3Gdefault\xf4Hrequired\xf4DtypeDboolEnodes\xa2Hrequired\xf5DtypeDlistDtree\xa2Hrequired\xf5DtypeEbytesKpermissions\x81DpullGpushkey\xa2Dargs\xa4Ckey\xa2Hrequired\xf5DtypeEbytesInamespace\xa2Hrequired\xf5DtypeEbytesCnew\xa2Hrequired\xf5DtypeEbytesCold\xa2Hrequired\xf5DtypeEbytesKpermissions\x81DpushKcompression\x82\xa1DnameDzstd\xa1DnameDzlibQframingmediatypes\x81X&application/mercurial-exp-framing-0005Rpathfilterprefixes\xd9\x01\x02\x82Epath:Lrootfilesin:Nrawrepoformats\x82LgeneraldeltaHrevlogv1Hredirect\xa2Fhashes\x82Fsha256Dsha1Gtargets\x81\xa4DnameNtarget-bad-tlsHprotocolEhttpsKsnirequired\xf5Duris\x81Thttps://example.com/
  s>     \r\n
  received frame(size=1430; request=1; stream=2; streamflags=; type=command-response; flags=continuation)
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
            b'noderange': {
              b'default': None,
              b'required': False,
              b'type': b'list'
            },
            b'nodes': {
              b'default': None,
              b'required': False,
              b'type': b'list'
            },
            b'nodesdepth': {
              b'default': None,
              b'required': False,
              b'type': b'int'
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
          ]
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
        }
      },
      b'compression': [
        {
          b'name': b'zstd'
        },
        {
          b'name': b'zlib'
        }
      ],
      b'framingmediatypes': [
        b'application/mercurial-exp-framing-0005'
      ],
      b'pathfilterprefixes': set([
        b'path:',
        b'rootfilesin:'
      ]),
      b'rawrepoformats': [
        b'generaldelta',
        b'revlogv1'
      ],
      b'redirect': {
        b'hashes': [
          b'sha256',
          b'sha1'
        ],
        b'targets': [
          {
            b'name': b'target-bad-tls',
            b'protocol': b'https',
            b'snirequired': True,
            b'uris': [
              b'https://example.com/'
            ]
          }
        ]
      }
    }
  ]

  $ cat >> $HGRCPATH << EOF
  > [extensions]
  > nosni=!
  > EOF

Unknown tls value is filtered from compatible targets

  $ cat > redirects.py << EOF
  > [
  >   {
  >     b'name': b'target-bad-tls',
  >     b'protocol': b'https',
  >     b'uris': [b'https://example.com/'],
  >     b'tlsversions': [b'42', b'39'],
  >   },
  > ]
  > EOF

  $ sendhttpv2peerhandshake << EOF
  > command capabilities
  > EOF
  creating http peer for wire protocol version 2
  s>     GET /?cmd=capabilities HTTP/1.1\r\n
  s>     Accept-Encoding: identity\r\n
  s>     vary: X-HgProto-1,X-HgUpgrade-1\r\n
  s>     x-hgproto-1: cbor\r\n
  s>     x-hgupgrade-1: exp-http-v2-0002\r\n
  s>     accept: application/mercurial-0.1\r\n
  s>     host: $LOCALIP:$HGPORT\r\n (glob)
  s>     user-agent: Mercurial debugwireproto\r\n
  s>     \r\n
  s> makefile('rb', None)
  s>     HTTP/1.1 200 OK\r\n
  s>     Server: testing stub value\r\n
  s>     Date: $HTTP_DATE$\r\n
  s>     Content-Type: application/mercurial-cbor\r\n
  s>     Content-Length: 1963\r\n
  s>     \r\n
  s>     \xa3GapibaseDapi/Dapis\xa1Pexp-http-v2-0002\xa6Hcommands\xaaIbranchmap\xa2Dargs\xa0Kpermissions\x81DpullLcapabilities\xa2Dargs\xa0Kpermissions\x81DpullMchangesetdata\xa2Dargs\xa4Ffields\xa4Gdefault\xd9\x01\x02\x80Hrequired\xf4DtypeCsetKvalidvalues\xd9\x01\x02\x84IbookmarksGparentsEphaseHrevisionInoderange\xa3Gdefault\xf6Hrequired\xf4DtypeDlistEnodes\xa3Gdefault\xf6Hrequired\xf4DtypeDlistJnodesdepth\xa3Gdefault\xf6Hrequired\xf4DtypeCintKpermissions\x81DpullHfiledata\xa2Dargs\xa4Ffields\xa4Gdefault\xd9\x01\x02\x80Hrequired\xf4DtypeCsetKvalidvalues\xd9\x01\x02\x82GparentsHrevisionKhaveparents\xa3Gdefault\xf4Hrequired\xf4DtypeDboolEnodes\xa2Hrequired\xf5DtypeDlistDpath\xa2Hrequired\xf5DtypeEbytesKpermissions\x81DpullEheads\xa2Dargs\xa1Jpubliconly\xa3Gdefault\xf4Hrequired\xf4DtypeDboolKpermissions\x81DpullEknown\xa2Dargs\xa1Enodes\xa3Gdefault\x80Hrequired\xf4DtypeDlistKpermissions\x81DpullHlistkeys\xa2Dargs\xa1Inamespace\xa2Hrequired\xf5DtypeEbytesKpermissions\x81DpullFlookup\xa2Dargs\xa1Ckey\xa2Hrequired\xf5DtypeEbytesKpermissions\x81DpullLmanifestdata\xa2Dargs\xa4Ffields\xa4Gdefault\xd9\x01\x02\x80Hrequired\xf4DtypeCsetKvalidvalues\xd9\x01\x02\x82GparentsHrevisionKhaveparents\xa3Gdefault\xf4Hrequired\xf4DtypeDboolEnodes\xa2Hrequired\xf5DtypeDlistDtree\xa2Hrequired\xf5DtypeEbytesKpermissions\x81DpullGpushkey\xa2Dargs\xa4Ckey\xa2Hrequired\xf5DtypeEbytesInamespace\xa2Hrequired\xf5DtypeEbytesCnew\xa2Hrequired\xf5DtypeEbytesCold\xa2Hrequired\xf5DtypeEbytesKpermissions\x81DpushKcompression\x82\xa1DnameDzstd\xa1DnameDzlibQframingmediatypes\x81X&application/mercurial-exp-framing-0005Rpathfilterprefixes\xd9\x01\x02\x82Epath:Lrootfilesin:Nrawrepoformats\x82LgeneraldeltaHrevlogv1Hredirect\xa2Fhashes\x82Fsha256Dsha1Gtargets\x81\xa4DnameNtarget-bad-tlsHprotocolEhttpsKtlsversions\x82B42B39Duris\x81Thttps://example.com/Nv1capabilitiesY\x01\xd8batch branchmap $USUAL_BUNDLE2_CAPS$ changegroupsubset compression=$BUNDLE2_COMPRESSIONS$ getbundle httpheader=1024 httpmediatype=0.1rx,0.1tx,0.2tx known lookup pushkey streamreqs=generaldelta,revlogv1 unbundle=HG10GZ,HG10BZ,HG10UN unbundlehash
  (remote redirect target target-bad-tls requires unsupported TLS versions: 39, 42)
  sending capabilities command
  s>     POST /api/exp-http-v2-0002/ro/capabilities HTTP/1.1\r\n
  s>     Accept-Encoding: identity\r\n
  s>     accept: application/mercurial-exp-framing-0005\r\n
  s>     content-type: application/mercurial-exp-framing-0005\r\n
  s>     content-length: 66\r\n
  s>     host: $LOCALIP:$HGPORT\r\n (glob)
  s>     user-agent: Mercurial debugwireproto\r\n
  s>     \r\n
  s>     :\x00\x00\x01\x00\x01\x01\x11\xa2DnameLcapabilitiesHredirect\xa2Fhashes\x82Fsha256Dsha1Gtargets\x80
  s> makefile('rb', None)
  s>     HTTP/1.1 200 OK\r\n
  s>     Server: testing stub value\r\n
  s>     Date: $HTTP_DATE$\r\n
  s>     Content-Type: application/mercurial-exp-framing-0005\r\n
  s>     Transfer-Encoding: chunked\r\n
  s>     \r\n
  s>     13\r\n
  s>     \x0b\x00\x00\x01\x00\x02\x011
  s>     \xa1FstatusBok
  s>     \r\n
  received frame(size=11; request=1; stream=2; streamflags=stream-begin; type=command-response; flags=continuation)
  s>     5a4\r\n
  s>     \x9c\x05\x00\x01\x00\x02\x001
  s>     \xa6Hcommands\xaaIbranchmap\xa2Dargs\xa0Kpermissions\x81DpullLcapabilities\xa2Dargs\xa0Kpermissions\x81DpullMchangesetdata\xa2Dargs\xa4Ffields\xa4Gdefault\xd9\x01\x02\x80Hrequired\xf4DtypeCsetKvalidvalues\xd9\x01\x02\x84IbookmarksGparentsEphaseHrevisionInoderange\xa3Gdefault\xf6Hrequired\xf4DtypeDlistEnodes\xa3Gdefault\xf6Hrequired\xf4DtypeDlistJnodesdepth\xa3Gdefault\xf6Hrequired\xf4DtypeCintKpermissions\x81DpullHfiledata\xa2Dargs\xa4Ffields\xa4Gdefault\xd9\x01\x02\x80Hrequired\xf4DtypeCsetKvalidvalues\xd9\x01\x02\x82GparentsHrevisionKhaveparents\xa3Gdefault\xf4Hrequired\xf4DtypeDboolEnodes\xa2Hrequired\xf5DtypeDlistDpath\xa2Hrequired\xf5DtypeEbytesKpermissions\x81DpullEheads\xa2Dargs\xa1Jpubliconly\xa3Gdefault\xf4Hrequired\xf4DtypeDboolKpermissions\x81DpullEknown\xa2Dargs\xa1Enodes\xa3Gdefault\x80Hrequired\xf4DtypeDlistKpermissions\x81DpullHlistkeys\xa2Dargs\xa1Inamespace\xa2Hrequired\xf5DtypeEbytesKpermissions\x81DpullFlookup\xa2Dargs\xa1Ckey\xa2Hrequired\xf5DtypeEbytesKpermissions\x81DpullLmanifestdata\xa2Dargs\xa4Ffields\xa4Gdefault\xd9\x01\x02\x80Hrequired\xf4DtypeCsetKvalidvalues\xd9\x01\x02\x82GparentsHrevisionKhaveparents\xa3Gdefault\xf4Hrequired\xf4DtypeDboolEnodes\xa2Hrequired\xf5DtypeDlistDtree\xa2Hrequired\xf5DtypeEbytesKpermissions\x81DpullGpushkey\xa2Dargs\xa4Ckey\xa2Hrequired\xf5DtypeEbytesInamespace\xa2Hrequired\xf5DtypeEbytesCnew\xa2Hrequired\xf5DtypeEbytesCold\xa2Hrequired\xf5DtypeEbytesKpermissions\x81DpushKcompression\x82\xa1DnameDzstd\xa1DnameDzlibQframingmediatypes\x81X&application/mercurial-exp-framing-0005Rpathfilterprefixes\xd9\x01\x02\x82Epath:Lrootfilesin:Nrawrepoformats\x82LgeneraldeltaHrevlogv1Hredirect\xa2Fhashes\x82Fsha256Dsha1Gtargets\x81\xa4DnameNtarget-bad-tlsHprotocolEhttpsKtlsversions\x82B42B39Duris\x81Thttps://example.com/
  s>     \r\n
  received frame(size=1436; request=1; stream=2; streamflags=; type=command-response; flags=continuation)
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
            b'noderange': {
              b'default': None,
              b'required': False,
              b'type': b'list'
            },
            b'nodes': {
              b'default': None,
              b'required': False,
              b'type': b'list'
            },
            b'nodesdepth': {
              b'default': None,
              b'required': False,
              b'type': b'int'
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
          ]
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
        }
      },
      b'compression': [
        {
          b'name': b'zstd'
        },
        {
          b'name': b'zlib'
        }
      ],
      b'framingmediatypes': [
        b'application/mercurial-exp-framing-0005'
      ],
      b'pathfilterprefixes': set([
        b'path:',
        b'rootfilesin:'
      ]),
      b'rawrepoformats': [
        b'generaldelta',
        b'revlogv1'
      ],
      b'redirect': {
        b'hashes': [
          b'sha256',
          b'sha1'
        ],
        b'targets': [
          {
            b'name': b'target-bad-tls',
            b'protocol': b'https',
            b'tlsversions': [
              b'42',
              b'39'
            ],
            b'uris': [
              b'https://example.com/'
            ]
          }
        ]
      }
    }
  ]

Set up the server to issue content redirects to its built-in API server.

  $ cat > redirects.py << EOF
  > [
  >   {
  >     b'name': b'local',
  >     b'protocol': b'http',
  >     b'uris': [b'http://example.com/'],
  >   },
  > ]
  > EOF

Request to eventual cache URL should return 404 (validating the cache server works)

  $ sendhttpraw << EOF
  > httprequest GET api/simplecache/missingkey
  >     user-agent: test
  > EOF
  using raw connection to peer
  s>     GET /api/simplecache/missingkey HTTP/1.1\r\n
  s>     Accept-Encoding: identity\r\n
  s>     user-agent: test\r\n
  s>     host: $LOCALIP:$HGPORT\r\n (glob)
  s>     \r\n
  s> makefile('rb', None)
  s>     HTTP/1.1 404 Not Found\r\n
  s>     Server: testing stub value\r\n
  s>     Date: $HTTP_DATE$\r\n
  s>     Content-Type: text/plain\r\n
  s>     Content-Length: 22\r\n
  s>     \r\n
  s>     key not found in cache

Send a cacheable request

  $ sendhttpv2peer << EOF
  > command manifestdata
  >     nodes eval:[b'\x99\x2f\x47\x79\x02\x9a\x3d\xf8\xd0\x66\x6d\x00\xbb\x92\x4f\x69\x63\x4e\x26\x41']
  >     tree eval:b''
  >     fields eval:[b'parents']
  > EOF
  creating http peer for wire protocol version 2
  sending manifestdata command
  s>     POST /api/exp-http-v2-0002/ro/manifestdata HTTP/1.1\r\n
  s>     Accept-Encoding: identity\r\n
  s>     accept: application/mercurial-exp-framing-0005\r\n
  s>     content-type: application/mercurial-exp-framing-0005\r\n
  s>     content-length: 128\r\n
  s>     host: $LOCALIP:$HGPORT\r\n (glob)
  s>     user-agent: Mercurial debugwireproto\r\n
  s>     \r\n
  s>     x\x00\x00\x01\x00\x01\x01\x11\xa3Dargs\xa3Ffields\x81GparentsEnodes\x81T\x99/Gy\x02\x9a=\xf8\xd0fm\x00\xbb\x92OicN&ADtree@DnameLmanifestdataHredirect\xa2Fhashes\x82Fsha256Dsha1Gtargets\x81Elocal
  s> makefile('rb', None)
  s>     HTTP/1.1 200 OK\r\n
  s>     Server: testing stub value\r\n
  s>     Date: $HTTP_DATE$\r\n
  s>     Content-Type: application/mercurial-exp-framing-0005\r\n
  s>     Transfer-Encoding: chunked\r\n
  s>     \r\n
  s>     13\r\n
  s>     \x0b\x00\x00\x01\x00\x02\x011
  s>     \xa1FstatusBok
  s>     \r\n
  received frame(size=11; request=1; stream=2; streamflags=stream-begin; type=command-response; flags=continuation)
  s>     63\r\n
  s>     [\x00\x00\x01\x00\x02\x001
  s>     \xa1Jtotalitems\x01\xa2DnodeT\x99/Gy\x02\x9a=\xf8\xd0fm\x00\xbb\x92OicN&AGparents\x82T\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00T\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00
  s>     \r\n
  received frame(size=91; request=1; stream=2; streamflags=; type=command-response; flags=continuation)
  s>     8\r\n
  s>     \x00\x00\x00\x01\x00\x02\x002
  s>     \r\n
  s>     0\r\n
  s>     \r\n
  received frame(size=0; request=1; stream=2; streamflags=; type=command-response; flags=eos)
  response: gen[
    {
      b'totalitems': 1
    },
    {
      b'node': b'\x99/Gy\x02\x9a=\xf8\xd0fm\x00\xbb\x92OicN&A',
      b'parents': [
        b'\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00',
        b'\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00'
      ]
    }
  ]

Cached entry should be available on server

  $ sendhttpraw << EOF
  > httprequest GET api/simplecache/c045a581599d58608efd3d93d8129841f2af04a0
  >     user-agent: test
  > EOF
  using raw connection to peer
  s>     GET /api/simplecache/c045a581599d58608efd3d93d8129841f2af04a0 HTTP/1.1\r\n
  s>     Accept-Encoding: identity\r\n
  s>     user-agent: test\r\n
  s>     host: $LOCALIP:$HGPORT\r\n (glob)
  s>     \r\n
  s> makefile('rb', None)
  s>     HTTP/1.1 200 OK\r\n
  s>     Server: testing stub value\r\n
  s>     Date: $HTTP_DATE$\r\n
  s>     Content-Type: application/mercurial-cbor\r\n
  s>     Content-Length: 91\r\n
  s>     \r\n
  s>     \xa1Jtotalitems\x01\xa2DnodeT\x99/Gy\x02\x9a=\xf8\xd0fm\x00\xbb\x92OicN&AGparents\x82T\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00T\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00
  cbor> [
    {
      b'totalitems': 1
    },
    {
      b'node': b'\x99/Gy\x02\x9a=\xf8\xd0fm\x00\xbb\x92OicN&A',
      b'parents': [
        b'\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00',
        b'\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00'
      ]
    }
  ]

2nd request should result in content redirect response

  $ sendhttpv2peer << EOF
  > command manifestdata
  >     nodes eval:[b'\x99\x2f\x47\x79\x02\x9a\x3d\xf8\xd0\x66\x6d\x00\xbb\x92\x4f\x69\x63\x4e\x26\x41']
  >     tree eval:b''
  >     fields eval:[b'parents']
  > EOF
  creating http peer for wire protocol version 2
  sending manifestdata command
  s>     POST /api/exp-http-v2-0002/ro/manifestdata HTTP/1.1\r\n
  s>     Accept-Encoding: identity\r\n
  s>     accept: application/mercurial-exp-framing-0005\r\n
  s>     content-type: application/mercurial-exp-framing-0005\r\n
  s>     content-length: 128\r\n
  s>     host: $LOCALIP:$HGPORT\r\n (glob)
  s>     user-agent: Mercurial debugwireproto\r\n
  s>     \r\n
  s>     x\x00\x00\x01\x00\x01\x01\x11\xa3Dargs\xa3Ffields\x81GparentsEnodes\x81T\x99/Gy\x02\x9a=\xf8\xd0fm\x00\xbb\x92OicN&ADtree@DnameLmanifestdataHredirect\xa2Fhashes\x82Fsha256Dsha1Gtargets\x81Elocal
  s> makefile('rb', None)
  s>     HTTP/1.1 200 OK\r\n
  s>     Server: testing stub value\r\n
  s>     Date: $HTTP_DATE$\r\n
  s>     Content-Type: application/mercurial-exp-framing-0005\r\n
  s>     Transfer-Encoding: chunked\r\n
  s>     \r\n
  s>     *\r\n (glob)
  s>     \x*\x00\x00\x01\x00\x02\x011 (glob)
  s>     \xa2Hlocation\xa2ImediatypeX\x1aapplication/mercurial-cborCurl*http://*:$HGPORT/api/simplecache/c045a581599d58608efd3d93d8129841f2af04a0FstatusHredirect (glob)
  s>     \r\n
  received frame(size=*; request=1; stream=2; streamflags=stream-begin; type=command-response; flags=continuation) (glob)
  s>     8\r\n
  s>     \x00\x00\x00\x01\x00\x02\x001
  s>     \r\n
  s>     8\r\n
  received frame(size=0; request=1; stream=2; streamflags=; type=command-response; flags=continuation)
  s>     \x00\x00\x00\x01\x00\x02\x002
  s>     \r\n
  s>     0\r\n
  s>     \r\n
  received frame(size=0; request=1; stream=2; streamflags=; type=command-response; flags=eos)
  (following redirect to http://*:$HGPORT/api/simplecache/c045a581599d58608efd3d93d8129841f2af04a0) (glob)
  s>     GET /api/simplecache/c045a581599d58608efd3d93d8129841f2af04a0 HTTP/1.1\r\n
  s>     Accept-Encoding: identity\r\n
  s>     accept: application/mercurial-cbor\r\n
  s>     host: *:$HGPORT\r\n (glob)
  s>     user-agent: Mercurial debugwireproto\r\n
  s>     \r\n
  s> makefile('rb', None)
  s>     HTTP/1.1 200 OK\r\n
  s>     Server: testing stub value\r\n
  s>     Date: $HTTP_DATE$\r\n
  s>     Content-Type: application/mercurial-cbor\r\n
  s>     Content-Length: 91\r\n
  s>     \r\n
  s>     \xa1Jtotalitems\x01\xa2DnodeT\x99/Gy\x02\x9a=\xf8\xd0fm\x00\xbb\x92OicN&AGparents\x82T\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00T\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00
  response: gen[
    {
      b'totalitems': 1
    },
    {
      b'node': b'\x99/Gy\x02\x9a=\xf8\xd0fm\x00\xbb\x92OicN&A',
      b'parents': [
        b'\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00',
        b'\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00'
      ]
    }
  ]

  $ cat error.log
  $ killdaemons.py

  $ cat .hg/blackbox.log
  *> cacher constructed for manifestdata (glob)
  *> cache miss for c045a581599d58608efd3d93d8129841f2af04a0 (glob)
  *> storing cache entry for c045a581599d58608efd3d93d8129841f2af04a0 (glob)
  *> cacher constructed for manifestdata (glob)
  *> cache hit for c045a581599d58608efd3d93d8129841f2af04a0 (glob)
  *> sending content redirect for c045a581599d58608efd3d93d8129841f2af04a0 to http://*:$HGPORT/api/simplecache/c045a581599d58608efd3d93d8129841f2af04a0 (glob)
