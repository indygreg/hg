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
  > EOF

  $ echo a0 > a
  $ echo b0 > b
  $ hg -q commit -A -m 'commit 0'
  $ echo a1 > a
  $ hg commit -m 'commit 1'
  $ echo b1 > b
  $ hg commit -m 'commit 2'
  $ echo a2 > a
  $ echo b2 > b
  $ hg commit -m 'commit 3'

  $ hg log -G -T '{rev}:{node} {desc}'
  @  3:50590a86f3ff5d1e9a1624a7a6957884565cc8e8 commit 3
  |
  o  2:4d01eda50c6ac5f7e89cbe1880143a32f559c302 commit 2
  |
  o  1:4432d83626e8a98655f062ec1f2a43b07f7fbbb0 commit 1
  |
  o  0:3390ef850073fbc2f0dfff2244342c8e9229013a commit 0
  

  $ hg --debug debugindex -m
     rev linkrev nodeid                                   p1                                       p2
       0       0 992f4779029a3df8d0666d00bb924f69634e2641 0000000000000000000000000000000000000000 0000000000000000000000000000000000000000
       1       1 a988fb43583e871d1ed5750ee074c6d840bbbfc8 992f4779029a3df8d0666d00bb924f69634e2641 0000000000000000000000000000000000000000
       2       2 a8853dafacfca6fc807055a660d8b835141a3bb4 a988fb43583e871d1ed5750ee074c6d840bbbfc8 0000000000000000000000000000000000000000
       3       3 3fe11dfbb13645782b0addafbe75a87c210ffddc a8853dafacfca6fc807055a660d8b835141a3bb4 0000000000000000000000000000000000000000

  $ hg serve -p $HGPORT -d --pid-file hg.pid -E error.log
  $ cat hg.pid > $DAEMON_PIDS

Performing the same request should result in same result, with 2nd response
coming from cache.

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
  s>     content-length: 83\r\n
  s>     host: $LOCALIP:$HGPORT\r\n (glob)
  s>     user-agent: Mercurial debugwireproto\r\n
  s>     \r\n
  s>     K\x00\x00\x01\x00\x01\x01\x11\xa2Dargs\xa3Ffields\x81GparentsEnodes\x81T\x99/Gy\x02\x9a=\xf8\xd0fm\x00\xbb\x92OicN&ADtree@DnameLmanifestdata
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
  s>     content-length: 83\r\n
  s>     host: $LOCALIP:$HGPORT\r\n (glob)
  s>     user-agent: Mercurial debugwireproto\r\n
  s>     \r\n
  s>     K\x00\x00\x01\x00\x01\x01\x11\xa2Dargs\xa3Ffields\x81GparentsEnodes\x81T\x99/Gy\x02\x9a=\xf8\xd0fm\x00\xbb\x92OicN&ADtree@DnameLmanifestdata
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

Sending different request doesn't yield cache hit.

  $ sendhttpv2peer << EOF
  > command manifestdata
  >     nodes eval:[b'\x99\x2f\x47\x79\x02\x9a\x3d\xf8\xd0\x66\x6d\x00\xbb\x92\x4f\x69\x63\x4e\x26\x41', b'\xa9\x88\xfb\x43\x58\x3e\x87\x1d\x1e\xd5\x75\x0e\xe0\x74\xc6\xd8\x40\xbb\xbf\xc8']
  >     tree eval:b''
  >     fields eval:[b'parents']
  > EOF
  creating http peer for wire protocol version 2
  sending manifestdata command
  s>     POST /api/exp-http-v2-0002/ro/manifestdata HTTP/1.1\r\n
  s>     Accept-Encoding: identity\r\n
  s>     accept: application/mercurial-exp-framing-0005\r\n
  s>     content-type: application/mercurial-exp-framing-0005\r\n
  s>     content-length: 104\r\n
  s>     host: $LOCALIP:$HGPORT\r\n (glob)
  s>     user-agent: Mercurial debugwireproto\r\n
  s>     \r\n
  s>     `\x00\x00\x01\x00\x01\x01\x11\xa2Dargs\xa3Ffields\x81GparentsEnodes\x82T\x99/Gy\x02\x9a=\xf8\xd0fm\x00\xbb\x92OicN&AT\xa9\x88\xfbCX>\x87\x1d\x1e\xd5u\x0e\xe0t\xc6\xd8@\xbb\xbf\xc8Dtree@DnameLmanifestdata
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
  s>     b1\r\n
  s>     \xa9\x00\x00\x01\x00\x02\x001
  s>     \xa1Jtotalitems\x02\xa2DnodeT\x99/Gy\x02\x9a=\xf8\xd0fm\x00\xbb\x92OicN&AGparents\x82T\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00T\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\xa2DnodeT\xa9\x88\xfbCX>\x87\x1d\x1e\xd5u\x0e\xe0t\xc6\xd8@\xbb\xbf\xc8Gparents\x82T\x99/Gy\x02\x9a=\xf8\xd0fm\x00\xbb\x92OicN&AT\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00
  s>     \r\n
  received frame(size=169; request=1; stream=2; streamflags=; type=command-response; flags=continuation)
  s>     8\r\n
  s>     \x00\x00\x00\x01\x00\x02\x002
  s>     \r\n
  s>     0\r\n
  s>     \r\n
  received frame(size=0; request=1; stream=2; streamflags=; type=command-response; flags=eos)
  response: gen[
    {
      b'totalitems': 2
    },
    {
      b'node': b'\x99/Gy\x02\x9a=\xf8\xd0fm\x00\xbb\x92OicN&A',
      b'parents': [
        b'\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00',
        b'\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00'
      ]
    },
    {
      b'node': b'\xa9\x88\xfbCX>\x87\x1d\x1e\xd5u\x0e\xe0t\xc6\xd8@\xbb\xbf\xc8',
      b'parents': [
        b'\x99/Gy\x02\x9a=\xf8\xd0fm\x00\xbb\x92OicN&A',
        b'\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00'
      ]
    }
  ]

  $ cat .hg/blackbox.log
  *> cacher constructed for manifestdata (glob)
  *> cache miss for c045a581599d58608efd3d93d8129841f2af04a0 (glob)
  *> storing cache entry for c045a581599d58608efd3d93d8129841f2af04a0 (glob)
  *> cacher constructed for manifestdata (glob)
  *> cache hit for c045a581599d58608efd3d93d8129841f2af04a0 (glob)
  *> cacher constructed for manifestdata (glob)
  *> cache miss for 6ed2f740a1cdd12c9e99c4f27695543143c26a11 (glob)
  *> storing cache entry for 6ed2f740a1cdd12c9e99c4f27695543143c26a11 (glob)

  $ cat error.log

  $ killdaemons.py
  $ rm .hg/blackbox.log

Try with object caching mode

  $ cat >> .hg/hgrc << EOF
  > [simplecache]
  > cacheobjects = true
  > EOF

  $ hg serve -p $HGPORT -d --pid-file hg.pid -E error.log
  $ cat hg.pid > $DAEMON_PIDS

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
  s>     content-length: 83\r\n
  s>     host: $LOCALIP:$HGPORT\r\n (glob)
  s>     user-agent: Mercurial debugwireproto\r\n
  s>     \r\n
  s>     K\x00\x00\x01\x00\x01\x01\x11\xa2Dargs\xa3Ffields\x81GparentsEnodes\x81T\x99/Gy\x02\x9a=\xf8\xd0fm\x00\xbb\x92OicN&ADtree@DnameLmanifestdata
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
  s>     content-length: 83\r\n
  s>     host: $LOCALIP:$HGPORT\r\n (glob)
  s>     user-agent: Mercurial debugwireproto\r\n
  s>     \r\n
  s>     K\x00\x00\x01\x00\x01\x01\x11\xa2Dargs\xa3Ffields\x81GparentsEnodes\x81T\x99/Gy\x02\x9a=\xf8\xd0fm\x00\xbb\x92OicN&ADtree@DnameLmanifestdata
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

  $ cat .hg/blackbox.log
  *> cacher constructed for manifestdata (glob)
  *> cache miss for c045a581599d58608efd3d93d8129841f2af04a0 (glob)
  *> storing cache entry for c045a581599d58608efd3d93d8129841f2af04a0 (glob)
  *> cacher constructed for manifestdata (glob)
  *> cache hit for c045a581599d58608efd3d93d8129841f2af04a0 (glob)

  $ cat error.log

  $ killdaemons.py
  $ rm .hg/blackbox.log

A non-cacheable command does not instantiate cacher

  $ hg serve -p $HGPORT -d --pid-file hg.pid -E error.log
  $ cat hg.pid > $DAEMON_PIDS
  $ sendhttpv2peer << EOF
  > command capabilities
  > EOF
  creating http peer for wire protocol version 2
  sending capabilities command
  s>     POST /api/exp-http-v2-0002/ro/capabilities HTTP/1.1\r\n
  s>     Accept-Encoding: identity\r\n
  s>     accept: application/mercurial-exp-framing-0005\r\n
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
  s>     13\r\n
  s>     \x0b\x00\x00\x01\x00\x02\x011
  s>     \xa1FstatusBok
  s>     \r\n
  received frame(size=11; request=1; stream=2; streamflags=stream-begin; type=command-response; flags=continuation)
  s>     52b\r\n
  s>     #\x05\x00\x01\x00\x02\x001
  s>     \xa5Hcommands\xaaIbranchmap\xa2Dargs\xa0Kpermissions\x81DpullLcapabilities\xa2Dargs\xa0Kpermissions\x81DpullMchangesetdata\xa2Dargs\xa4Ffields\xa4Gdefault\xd9\x01\x02\x80Hrequired\xf4DtypeCsetKvalidvalues\xd9\x01\x02\x84IbookmarksGparentsEphaseHrevisionInoderange\xa3Gdefault\xf6Hrequired\xf4DtypeDlistEnodes\xa3Gdefault\xf6Hrequired\xf4DtypeDlistJnodesdepth\xa3Gdefault\xf6Hrequired\xf4DtypeCintKpermissions\x81DpullHfiledata\xa2Dargs\xa4Ffields\xa4Gdefault\xd9\x01\x02\x80Hrequired\xf4DtypeCsetKvalidvalues\xd9\x01\x02\x82GparentsHrevisionKhaveparents\xa3Gdefault\xf4Hrequired\xf4DtypeDboolEnodes\xa2Hrequired\xf5DtypeDlistDpath\xa2Hrequired\xf5DtypeEbytesKpermissions\x81DpullEheads\xa2Dargs\xa1Jpubliconly\xa3Gdefault\xf4Hrequired\xf4DtypeDboolKpermissions\x81DpullEknown\xa2Dargs\xa1Enodes\xa3Gdefault\x80Hrequired\xf4DtypeDlistKpermissions\x81DpullHlistkeys\xa2Dargs\xa1Inamespace\xa2Hrequired\xf5DtypeEbytesKpermissions\x81DpullFlookup\xa2Dargs\xa1Ckey\xa2Hrequired\xf5DtypeEbytesKpermissions\x81DpullLmanifestdata\xa2Dargs\xa4Ffields\xa4Gdefault\xd9\x01\x02\x80Hrequired\xf4DtypeCsetKvalidvalues\xd9\x01\x02\x82GparentsHrevisionKhaveparents\xa3Gdefault\xf4Hrequired\xf4DtypeDboolEnodes\xa2Hrequired\xf5DtypeDlistDtree\xa2Hrequired\xf5DtypeEbytesKpermissions\x81DpullGpushkey\xa2Dargs\xa4Ckey\xa2Hrequired\xf5DtypeEbytesInamespace\xa2Hrequired\xf5DtypeEbytesCnew\xa2Hrequired\xf5DtypeEbytesCold\xa2Hrequired\xf5DtypeEbytesKpermissions\x81DpushKcompression\x82\xa1DnameDzstd\xa1DnameDzlibQframingmediatypes\x81X&application/mercurial-exp-framing-0005Rpathfilterprefixes\xd9\x01\x02\x82Epath:Lrootfilesin:Nrawrepoformats\x82LgeneraldeltaHrevlogv1
  s>     \r\n
  received frame(size=1315; request=1; stream=2; streamflags=; type=command-response; flags=continuation)
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
      ]
    }
  ]

  $ test -f .hg/blackbox.log
  [1]

An error is not cached

  $ sendhttpv2peer << EOF
  > command manifestdata
  >     nodes eval:[b'\xaa\xaa\xaa\xaa\xaa\xaa\xaa\xaa\xaa\xaa\xaa\xaa\xaa\xaa\xaa\xaa\xaa\xaa\xaa\xaa']
  >     tree eval:b''
  >     fields eval:[b'parents']
  > EOF
  creating http peer for wire protocol version 2
  sending manifestdata command
  s>     POST /api/exp-http-v2-0002/ro/manifestdata HTTP/1.1\r\n
  s>     Accept-Encoding: identity\r\n
  s>     accept: application/mercurial-exp-framing-0005\r\n
  s>     content-type: application/mercurial-exp-framing-0005\r\n
  s>     content-length: 83\r\n
  s>     host: $LOCALIP:$HGPORT\r\n (glob)
  s>     user-agent: Mercurial debugwireproto\r\n
  s>     \r\n
  s>     K\x00\x00\x01\x00\x01\x01\x11\xa2Dargs\xa3Ffields\x81GparentsEnodes\x81T\xaa\xaa\xaa\xaa\xaa\xaa\xaa\xaa\xaa\xaa\xaa\xaa\xaa\xaa\xaa\xaa\xaa\xaa\xaa\xaaDtree@DnameLmanifestdata
  s> makefile('rb', None)
  s>     HTTP/1.1 200 OK\r\n
  s>     Server: testing stub value\r\n
  s>     Date: $HTTP_DATE$\r\n
  s>     Content-Type: application/mercurial-exp-framing-0005\r\n
  s>     Transfer-Encoding: chunked\r\n
  s>     \r\n
  s>     51\r\n
  s>     I\x00\x00\x01\x00\x02\x012
  s>     \xa2Eerror\xa2Dargs\x81T\xaa\xaa\xaa\xaa\xaa\xaa\xaa\xaa\xaa\xaa\xaa\xaa\xaa\xaa\xaa\xaa\xaa\xaa\xaa\xaaGmessagePunknown node: %sFstatusEerror
  s>     \r\n
  received frame(size=73; request=1; stream=2; streamflags=stream-begin; type=command-response; flags=eos)
  s>     0\r\n
  s>     \r\n
  abort: unknown node: \xaa\xaa\xaa\xaa\xaa\xaa\xaa\xaa\xaa\xaa\xaa\xaa\xaa\xaa\xaa\xaa\xaa\xaa\xaa\xaa! (esc)
  [255]

  $ cat .hg/blackbox.log
  *> cacher constructed for manifestdata (glob)
  *> cache miss for 9d1bb421d99e913d45f2d099aa49728514292dd2 (glob)
  *> cacher exiting due to error (glob)

  $ killdaemons.py
  $ rm .hg/blackbox.log
