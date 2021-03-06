#require no-chg

  $ . $TESTDIR/wireprotohelpers.sh
  $ enabledummycommands

  $ hg init server
  $ cat > server/.hg/hgrc << EOF
  > [experimental]
  > web.apiserver = true
  > EOF
  $ hg -R server serve -p $HGPORT -d --pid-file hg.pid
  $ cat hg.pid > $DAEMON_PIDS

HTTP v2 protocol not enabled by default

  $ sendhttpraw << EOF
  > httprequest GET api/$HTTPV2
  >     user-agent: test
  > EOF
  using raw connection to peer
  s>     GET /api/exp-http-v2-0003 HTTP/1.1\r\n
  s>     Accept-Encoding: identity\r\n
  s>     user-agent: test\r\n
  s>     host: $LOCALIP:$HGPORT\r\n (glob)
  s>     \r\n
  s> makefile('rb', None)
  s>     HTTP/1.1 404 Not Found\r\n
  s>     Server: testing stub value\r\n
  s>     Date: $HTTP_DATE$\r\n
  s>     Content-Type: text/plain\r\n
  s>     Content-Length: 33\r\n
  s>     \r\n
  s>     API exp-http-v2-0003 not enabled\n

Restart server with support for HTTP v2 API

  $ killdaemons.py
  $ enablehttpv2 server
  $ hg -R server serve -p $HGPORT -d --pid-file hg.pid
  $ cat hg.pid > $DAEMON_PIDS

Request to unknown command yields 404

  $ sendhttpraw << EOF
  > httprequest POST api/$HTTPV2/ro/badcommand
  >     user-agent: test
  > EOF
  using raw connection to peer
  s>     POST /api/exp-http-v2-0003/ro/badcommand HTTP/1.1\r\n
  s>     Accept-Encoding: identity\r\n
  s>     user-agent: test\r\n
  s>     host: $LOCALIP:$HGPORT\r\n (glob)
  s>     \r\n
  s> makefile('rb', None)
  s>     HTTP/1.1 404 Not Found\r\n
  s>     Server: testing stub value\r\n
  s>     Date: $HTTP_DATE$\r\n
  s>     Content-Type: text/plain\r\n
  s>     Content-Length: 42\r\n
  s>     \r\n
  s>     unknown wire protocol command: badcommand\n

GET to read-only command yields a 405

  $ sendhttpraw << EOF
  > httprequest GET api/$HTTPV2/ro/customreadonly
  >     user-agent: test
  > EOF
  using raw connection to peer
  s>     GET /api/exp-http-v2-0003/ro/customreadonly HTTP/1.1\r\n
  s>     Accept-Encoding: identity\r\n
  s>     user-agent: test\r\n
  s>     host: $LOCALIP:$HGPORT\r\n (glob)
  s>     \r\n
  s> makefile('rb', None)
  s>     HTTP/1.1 405 Method Not Allowed\r\n
  s>     Server: testing stub value\r\n
  s>     Date: $HTTP_DATE$\r\n
  s>     Allow: POST\r\n
  s>     Content-Length: 30\r\n
  s>     \r\n
  s>     commands require POST requests

Missing Accept header results in 406

  $ sendhttpraw << EOF
  > httprequest POST api/$HTTPV2/ro/customreadonly
  >     user-agent: test
  > EOF
  using raw connection to peer
  s>     POST /api/exp-http-v2-0003/ro/customreadonly HTTP/1.1\r\n
  s>     Accept-Encoding: identity\r\n
  s>     user-agent: test\r\n
  s>     host: $LOCALIP:$HGPORT\r\n (glob)
  s>     \r\n
  s> makefile('rb', None)
  s>     HTTP/1.1 406 Not Acceptable\r\n
  s>     Server: testing stub value\r\n
  s>     Date: $HTTP_DATE$\r\n
  s>     Content-Type: text/plain\r\n
  s>     Content-Length: 85\r\n
  s>     \r\n
  s>     client MUST specify Accept header with value: application/mercurial-exp-framing-0006\n

Bad Accept header results in 406

  $ sendhttpraw << EOF
  > httprequest POST api/$HTTPV2/ro/customreadonly
  >     accept: invalid
  >     user-agent: test
  > EOF
  using raw connection to peer
  s>     POST /api/exp-http-v2-0003/ro/customreadonly HTTP/1.1\r\n
  s>     Accept-Encoding: identity\r\n
  s>     accept: invalid\r\n
  s>     user-agent: test\r\n
  s>     host: $LOCALIP:$HGPORT\r\n (glob)
  s>     \r\n
  s> makefile('rb', None)
  s>     HTTP/1.1 406 Not Acceptable\r\n
  s>     Server: testing stub value\r\n
  s>     Date: $HTTP_DATE$\r\n
  s>     Content-Type: text/plain\r\n
  s>     Content-Length: 85\r\n
  s>     \r\n
  s>     client MUST specify Accept header with value: application/mercurial-exp-framing-0006\n

Bad Content-Type header results in 415

  $ sendhttpraw << EOF
  > httprequest POST api/$HTTPV2/ro/customreadonly
  >     accept: $MEDIATYPE
  >     user-agent: test
  >     content-type: badmedia
  > EOF
  using raw connection to peer
  s>     POST /api/exp-http-v2-0003/ro/customreadonly HTTP/1.1\r\n
  s>     Accept-Encoding: identity\r\n
  s>     accept: application/mercurial-exp-framing-0006\r\n
  s>     content-type: badmedia\r\n
  s>     user-agent: test\r\n
  s>     host: $LOCALIP:$HGPORT\r\n (glob)
  s>     \r\n
  s> makefile('rb', None)
  s>     HTTP/1.1 415 Unsupported Media Type\r\n
  s>     Server: testing stub value\r\n
  s>     Date: $HTTP_DATE$\r\n
  s>     Content-Type: text/plain\r\n
  s>     Content-Length: 88\r\n
  s>     \r\n
  s>     client MUST send Content-Type header with value: application/mercurial-exp-framing-0006\n

Request to read-only command works out of the box

  $ sendhttpraw << EOF
  > httprequest POST api/$HTTPV2/ro/customreadonly
  >     accept: $MEDIATYPE
  >     content-type: $MEDIATYPE
  >     user-agent: test
  >     frame 1 1 stream-begin command-request new cbor:{b'name': b'customreadonly'}
  > EOF
  using raw connection to peer
  s>     POST /api/exp-http-v2-0003/ro/customreadonly HTTP/1.1\r\n
  s>     Accept-Encoding: identity\r\n
  s>     *\r\n (glob)
  s>     content-type: application/mercurial-exp-framing-0006\r\n
  s>     user-agent: test\r\n
  s>     content-length: 29\r\n
  s>     host: $LOCALIP:$HGPORT\r\n (glob)
  s>     \r\n
  s>     \x15\x00\x00\x01\x00\x01\x01\x11\xa1DnameNcustomreadonly
  s> makefile('rb', None)
  s>     HTTP/1.1 200 OK\r\n
  s>     Server: testing stub value\r\n
  s>     Date: $HTTP_DATE$\r\n
  s>     Content-Type: application/mercurial-exp-framing-0006\r\n
  s>     Transfer-Encoding: chunked\r\n
  s>     \r\n
  s>     11\r\n
  s>     \t\x00\x00\x01\x00\x02\x01\x92Hidentity
  s>     \r\n
  s>     13\r\n
  s>     \x0b\x00\x00\x01\x00\x02\x041\xa1FstatusBok
  s>     \r\n
  s>     27\r\n
  s>     \x1f\x00\x00\x01\x00\x02\x041X\x1dcustomreadonly bytes response
  s>     \r\n
  s>     8\r\n
  s>     \x00\x00\x00\x01\x00\x02\x002
  s>     \r\n
  s>     0\r\n
  s>     \r\n

  $ sendhttpv2peerverbose << EOF
  > command customreadonly
  > EOF
  creating http peer for wire protocol version 2
  sending customreadonly command
  s>     POST /api/exp-http-v2-0003/ro/customreadonly HTTP/1.1\r\n
  s>     Accept-Encoding: identity\r\n
  s>     accept: application/mercurial-exp-framing-0006\r\n
  s>     content-type: application/mercurial-exp-framing-0006\r\n
  s>     content-length: 65\r\n
  s>     host: $LOCALIP:$HGPORT\r\n (glob)
  s>     user-agent: Mercurial debugwireproto\r\n
  s>     \r\n
  s>     \x1c\x00\x00\x01\x00\x01\x01\x82\xa1Pcontentencodings\x81Hidentity\x15\x00\x00\x01\x00\x01\x00\x11\xa1DnameNcustomreadonly
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
  s>     27\r\n
  s>     \x1f\x00\x00\x01\x00\x02\x041
  s>     X\x1dcustomreadonly bytes response
  s>     \r\n
  received frame(size=31; request=1; stream=2; streamflags=encoded; type=command-response; flags=continuation)
  s>     8\r\n
  s>     \x00\x00\x00\x01\x00\x02\x002
  s>     \r\n
  s>     0\r\n
  s>     \r\n
  received frame(size=0; request=1; stream=2; streamflags=; type=command-response; flags=eos)
  response: gen[
    b'customreadonly bytes response'
  ]
  (sent 2 HTTP requests and * bytes; received * bytes in responses) (glob)

Request to read-write command fails because server is read-only by default

GET to read-write request yields 405

  $ sendhttpraw << EOF
  > httprequest GET api/$HTTPV2/rw/customreadonly
  >     user-agent: test
  > EOF
  using raw connection to peer
  s>     GET /api/exp-http-v2-0003/rw/customreadonly HTTP/1.1\r\n
  s>     Accept-Encoding: identity\r\n
  s>     user-agent: test\r\n
  s>     host: $LOCALIP:$HGPORT\r\n (glob)
  s>     \r\n
  s> makefile('rb', None)
  s>     HTTP/1.1 405 Method Not Allowed\r\n
  s>     Server: testing stub value\r\n
  s>     Date: $HTTP_DATE$\r\n
  s>     Allow: POST\r\n
  s>     Content-Length: 30\r\n
  s>     \r\n
  s>     commands require POST requests

Even for unknown commands

  $ sendhttpraw << EOF
  > httprequest GET api/$HTTPV2/rw/badcommand
  >     user-agent: test
  > EOF
  using raw connection to peer
  s>     GET /api/exp-http-v2-0003/rw/badcommand HTTP/1.1\r\n
  s>     Accept-Encoding: identity\r\n
  s>     user-agent: test\r\n
  s>     host: $LOCALIP:$HGPORT\r\n (glob)
  s>     \r\n
  s> makefile('rb', None)
  s>     HTTP/1.1 405 Method Not Allowed\r\n
  s>     Server: testing stub value\r\n
  s>     Date: $HTTP_DATE$\r\n
  s>     Allow: POST\r\n
  s>     Content-Length: 30\r\n
  s>     \r\n
  s>     commands require POST requests

SSL required by default

  $ sendhttpraw << EOF
  > httprequest POST api/$HTTPV2/rw/customreadonly
  >     user-agent: test
  > EOF
  using raw connection to peer
  s>     POST /api/exp-http-v2-0003/rw/customreadonly HTTP/1.1\r\n
  s>     Accept-Encoding: identity\r\n
  s>     user-agent: test\r\n
  s>     host: $LOCALIP:$HGPORT\r\n (glob)
  s>     \r\n
  s> makefile('rb', None)
  s>     HTTP/1.1 403 ssl required\r\n
  s>     Server: testing stub value\r\n
  s>     Date: $HTTP_DATE$\r\n
  s>     Content-Length: 17\r\n
  s>     \r\n
  s>     permission denied

Restart server to allow non-ssl read-write operations

  $ killdaemons.py
  $ cat > server/.hg/hgrc << EOF
  > [experimental]
  > web.apiserver = true
  > web.api.http-v2 = true
  > [web]
  > push_ssl = false
  > allow-push = *
  > EOF

  $ hg -R server serve -p $HGPORT -d --pid-file hg.pid -E error.log
  $ cat hg.pid > $DAEMON_PIDS

Authorized request for valid read-write command works

  $ sendhttpraw << EOF
  > httprequest POST api/$HTTPV2/rw/customreadonly
  >     user-agent: test
  >     accept: $MEDIATYPE
  >     content-type: $MEDIATYPE
  >     frame 1 1 stream-begin command-request new cbor:{b'name': b'customreadonly'}
  > EOF
  using raw connection to peer
  s>     POST /api/exp-http-v2-0003/rw/customreadonly HTTP/1.1\r\n
  s>     Accept-Encoding: identity\r\n
  s>     accept: application/mercurial-exp-framing-0006\r\n
  s>     content-type: application/mercurial-exp-framing-0006\r\n
  s>     user-agent: test\r\n
  s>     content-length: 29\r\n
  s>     host: $LOCALIP:$HGPORT\r\n (glob)
  s>     \r\n
  s>     \x15\x00\x00\x01\x00\x01\x01\x11\xa1DnameNcustomreadonly
  s> makefile('rb', None)
  s>     HTTP/1.1 200 OK\r\n
  s>     Server: testing stub value\r\n
  s>     Date: $HTTP_DATE$\r\n
  s>     Content-Type: application/mercurial-exp-framing-0006\r\n
  s>     Transfer-Encoding: chunked\r\n
  s>     \r\n
  s>     11\r\n
  s>     \t\x00\x00\x01\x00\x02\x01\x92Hidentity
  s>     \r\n
  s>     13\r\n
  s>     \x0b\x00\x00\x01\x00\x02\x041\xa1FstatusBok
  s>     \r\n
  s>     27\r\n
  s>     \x1f\x00\x00\x01\x00\x02\x041X\x1dcustomreadonly bytes response
  s>     \r\n
  s>     8\r\n
  s>     \x00\x00\x00\x01\x00\x02\x002
  s>     \r\n
  s>     0\r\n
  s>     \r\n

Authorized request for unknown command is rejected

  $ sendhttpraw << EOF
  > httprequest POST api/$HTTPV2/rw/badcommand
  >     user-agent: test
  >     accept: $MEDIATYPE
  > EOF
  using raw connection to peer
  s>     POST /api/exp-http-v2-0003/rw/badcommand HTTP/1.1\r\n
  s>     Accept-Encoding: identity\r\n
  s>     accept: application/mercurial-exp-framing-0006\r\n
  s>     user-agent: test\r\n
  s>     host: $LOCALIP:$HGPORT\r\n (glob)
  s>     \r\n
  s> makefile('rb', None)
  s>     HTTP/1.1 404 Not Found\r\n
  s>     Server: testing stub value\r\n
  s>     Date: $HTTP_DATE$\r\n
  s>     Content-Type: text/plain\r\n
  s>     Content-Length: 42\r\n
  s>     \r\n
  s>     unknown wire protocol command: badcommand\n

debugreflect isn't enabled by default

  $ sendhttpraw << EOF
  > httprequest POST api/$HTTPV2/ro/debugreflect
  >     user-agent: test
  > EOF
  using raw connection to peer
  s>     POST /api/exp-http-v2-0003/ro/debugreflect HTTP/1.1\r\n
  s>     Accept-Encoding: identity\r\n
  s>     user-agent: test\r\n
  s>     host: $LOCALIP:$HGPORT\r\n (glob)
  s>     \r\n
  s> makefile('rb', None)
  s>     HTTP/1.1 404 Not Found\r\n
  s>     Server: testing stub value\r\n
  s>     Date: $HTTP_DATE$\r\n
  s>     Content-Type: text/plain\r\n
  s>     Content-Length: 34\r\n
  s>     \r\n
  s>     debugreflect service not available

Restart server to get debugreflect endpoint

  $ killdaemons.py
  $ cat > server/.hg/hgrc << EOF
  > [experimental]
  > web.apiserver = true
  > web.api.debugreflect = true
  > web.api.http-v2 = true
  > [web]
  > push_ssl = false
  > allow-push = *
  > EOF

  $ hg -R server serve -p $HGPORT -d --pid-file hg.pid -E error.log
  $ cat hg.pid > $DAEMON_PIDS

Command frames can be reflected via debugreflect

  $ sendhttpraw << EOF
  > httprequest POST api/$HTTPV2/ro/debugreflect
  >     accept: $MEDIATYPE
  >     content-type: $MEDIATYPE
  >     user-agent: test
  >     frame 1 1 stream-begin command-request new cbor:{b'name': b'command1', b'args': {b'foo': b'val1', b'bar1': b'val'}}
  > EOF
  using raw connection to peer
  s>     POST /api/exp-http-v2-0003/ro/debugreflect HTTP/1.1\r\n
  s>     Accept-Encoding: identity\r\n
  s>     accept: application/mercurial-exp-framing-0006\r\n
  s>     content-type: application/mercurial-exp-framing-0006\r\n
  s>     user-agent: test\r\n
  s>     content-length: 47\r\n
  s>     host: $LOCALIP:$HGPORT\r\n (glob)
  s>     \r\n
  s>     \'\x00\x00\x01\x00\x01\x01\x11\xa2Dargs\xa2Dbar1CvalCfooDval1DnameHcommand1
  s> makefile('rb', None)
  s>     HTTP/1.1 200 OK\r\n
  s>     Server: testing stub value\r\n
  s>     Date: $HTTP_DATE$\r\n
  s>     Content-Type: text/plain\r\n
  s>     Content-Length: 223\r\n
  s>     \r\n
  s>     received: 1 1 1 \xa2Dargs\xa2Dbar1CvalCfooDval1DnameHcommand1\n
  s>     ["runcommand", {"args": {"bar1": "val", "foo": "val1"}, "command": "command1", "data": null, "redirect": null, "requestid": 1}]\n
  s>     received: <no frame>\n
  s>     {"action": "noop"}

Multiple requests to regular command URL are not allowed

  $ sendhttpraw << EOF
  > httprequest POST api/$HTTPV2/ro/customreadonly
  >     accept: $MEDIATYPE
  >     content-type: $MEDIATYPE
  >     user-agent: test
  >     frame 1 1 stream-begin command-request new cbor:{b'name': b'customreadonly'}
  > EOF
  using raw connection to peer
  s>     POST /api/exp-http-v2-0003/ro/customreadonly HTTP/1.1\r\n
  s>     Accept-Encoding: identity\r\n
  s>     accept: application/mercurial-exp-framing-0006\r\n
  s>     content-type: application/mercurial-exp-framing-0006\r\n
  s>     user-agent: test\r\n
  s>     content-length: 29\r\n
  s>     host: $LOCALIP:$HGPORT\r\n (glob)
  s>     \r\n
  s>     \x15\x00\x00\x01\x00\x01\x01\x11\xa1DnameNcustomreadonly
  s> makefile('rb', None)
  s>     HTTP/1.1 200 OK\r\n
  s>     Server: testing stub value\r\n
  s>     Date: $HTTP_DATE$\r\n
  s>     Content-Type: application/mercurial-exp-framing-0006\r\n
  s>     Transfer-Encoding: chunked\r\n
  s>     \r\n
  s>     11\r\n
  s>     \t\x00\x00\x01\x00\x02\x01\x92Hidentity
  s>     \r\n
  s>     13\r\n
  s>     \x0b\x00\x00\x01\x00\x02\x041\xa1FstatusBok
  s>     \r\n
  s>     27\r\n
  s>     \x1f\x00\x00\x01\x00\x02\x041X\x1dcustomreadonly bytes response
  s>     \r\n
  s>     8\r\n
  s>     \x00\x00\x00\x01\x00\x02\x002
  s>     \r\n
  s>     0\r\n
  s>     \r\n

Multiple requests to "multirequest" URL are allowed

  $ sendhttpraw << EOF
  > httprequest POST api/$HTTPV2/ro/multirequest
  >     accept: $MEDIATYPE
  >     content-type: $MEDIATYPE
  >     user-agent: test
  >     frame 1 1 stream-begin command-request new cbor:{b'name': b'customreadonly'}
  >     frame 3 1 0 command-request new cbor:{b'name': b'customreadonly'}
  > EOF
  using raw connection to peer
  s>     POST /api/exp-http-v2-0003/ro/multirequest HTTP/1.1\r\n
  s>     Accept-Encoding: identity\r\n
  s>     *\r\n (glob)
  s>     *\r\n (glob)
  s>     user-agent: test\r\n
  s>     content-length: 58\r\n
  s>     host: $LOCALIP:$HGPORT\r\n (glob)
  s>     \r\n
  s>     \x15\x00\x00\x01\x00\x01\x01\x11\xa1DnameNcustomreadonly\x15\x00\x00\x03\x00\x01\x00\x11\xa1DnameNcustomreadonly
  s> makefile('rb', None)
  s>     HTTP/1.1 200 OK\r\n
  s>     Server: testing stub value\r\n
  s>     Date: $HTTP_DATE$\r\n
  s>     Content-Type: application/mercurial-exp-framing-0006\r\n
  s>     Transfer-Encoding: chunked\r\n
  s>     \r\n
  s>     11\r\n
  s>     \t\x00\x00\x01\x00\x02\x01\x92Hidentity
  s>     \r\n
  s>     13\r\n
  s>     \x0b\x00\x00\x01\x00\x02\x041\xa1FstatusBok
  s>     \r\n
  s>     27\r\n
  s>     \x1f\x00\x00\x01\x00\x02\x041X\x1dcustomreadonly bytes response
  s>     \r\n
  s>     8\r\n
  s>     \x00\x00\x00\x01\x00\x02\x002
  s>     \r\n
  s>     13\r\n
  s>     \x0b\x00\x00\x03\x00\x02\x041\xa1FstatusBok
  s>     \r\n
  s>     27\r\n
  s>     \x1f\x00\x00\x03\x00\x02\x041X\x1dcustomreadonly bytes response
  s>     \r\n
  s>     8\r\n
  s>     \x00\x00\x00\x03\x00\x02\x002
  s>     \r\n
  s>     0\r\n
  s>     \r\n

Interleaved requests to "multirequest" are processed

  $ sendhttpraw << EOF
  > httprequest POST api/$HTTPV2/ro/multirequest
  >     accept: $MEDIATYPE
  >     content-type: $MEDIATYPE
  >     user-agent: test
  >     frame 1 1 stream-begin command-request new|more \xa2Dargs\xa1Inamespace
  >     frame 3 1 0 command-request new|more \xa2Dargs\xa1Inamespace
  >     frame 3 1 0 command-request continuation JnamespacesDnameHlistkeys
  >     frame 1 1 0 command-request continuation IbookmarksDnameHlistkeys
  > EOF
  using raw connection to peer
  s>     POST /api/exp-http-v2-0003/ro/multirequest HTTP/1.1\r\n
  s>     Accept-Encoding: identity\r\n
  s>     accept: application/mercurial-exp-framing-0006\r\n
  s>     content-type: application/mercurial-exp-framing-0006\r\n
  s>     user-agent: test\r\n
  s>     content-length: 115\r\n
  s>     host: $LOCALIP:$HGPORT\r\n (glob)
  s>     \r\n
  s>     \x11\x00\x00\x01\x00\x01\x01\x15\xa2Dargs\xa1Inamespace\x11\x00\x00\x03\x00\x01\x00\x15\xa2Dargs\xa1Inamespace\x19\x00\x00\x03\x00\x01\x00\x12JnamespacesDnameHlistkeys\x18\x00\x00\x01\x00\x01\x00\x12IbookmarksDnameHlistkeys
  s> makefile('rb', None)
  s>     HTTP/1.1 200 OK\r\n
  s>     Server: testing stub value\r\n
  s>     Date: $HTTP_DATE$\r\n
  s>     Content-Type: application/mercurial-exp-framing-0006\r\n
  s>     Transfer-Encoding: chunked\r\n
  s>     \r\n
  s>     11\r\n
  s>     \t\x00\x00\x03\x00\x02\x01\x92Hidentity
  s>     \r\n
  s>     13\r\n
  s>     \x0b\x00\x00\x03\x00\x02\x041\xa1FstatusBok
  s>     \r\n
  s>     28\r\n
  s>      \x00\x00\x03\x00\x02\x041\xa3Ibookmarks@Jnamespaces@Fphases@
  s>     \r\n
  s>     8\r\n
  s>     \x00\x00\x00\x03\x00\x02\x002
  s>     \r\n
  s>     13\r\n
  s>     \x0b\x00\x00\x01\x00\x02\x041\xa1FstatusBok
  s>     \r\n
  s>     9\r\n
  s>     \x01\x00\x00\x01\x00\x02\x041\xa0
  s>     \r\n
  s>     8\r\n
  s>     \x00\x00\x00\x01\x00\x02\x002
  s>     \r\n
  s>     0\r\n
  s>     \r\n

Restart server to disable read-write access

  $ killdaemons.py
  $ cat > server/.hg/hgrc << EOF
  > [experimental]
  > web.apiserver = true
  > web.api.debugreflect = true
  > web.api.http-v2 = true
  > [web]
  > push_ssl = false
  > EOF

  $ hg -R server serve -p $HGPORT -d --pid-file hg.pid -E error.log
  $ cat hg.pid > $DAEMON_PIDS

Attempting to run a read-write command via multirequest on read-only URL is not allowed

  $ sendhttpraw << EOF
  > httprequest POST api/$HTTPV2/ro/multirequest
  >     accept: $MEDIATYPE
  >     content-type: $MEDIATYPE
  >     user-agent: test
  >     frame 1 1 stream-begin command-request new cbor:{b'name': b'pushkey'}
  > EOF
  using raw connection to peer
  s>     POST /api/exp-http-v2-0003/ro/multirequest HTTP/1.1\r\n
  s>     Accept-Encoding: identity\r\n
  s>     accept: application/mercurial-exp-framing-0006\r\n
  s>     content-type: application/mercurial-exp-framing-0006\r\n
  s>     user-agent: test\r\n
  s>     content-length: 22\r\n
  s>     host: $LOCALIP:$HGPORT\r\n (glob)
  s>     \r\n
  s>     \x0e\x00\x00\x01\x00\x01\x01\x11\xa1DnameGpushkey
  s> makefile('rb', None)
  s>     HTTP/1.1 403 Forbidden\r\n
  s>     Server: testing stub value\r\n
  s>     Date: $HTTP_DATE$\r\n
  s>     Content-Type: text/plain\r\n
  s>     Content-Length: 52\r\n
  s>     \r\n
  s>     insufficient permissions to execute command: pushkey

Defining an invalid content encoding results in warning

  $ hg --config experimental.httppeer.v2-encoder-order=identity,badencoder --verbose debugwireproto --nologhandshake --peer http2 http://$LOCALIP:$HGPORT/ << EOF
  > command heads
  > EOF
  creating http peer for wire protocol version 2
  sending heads command
  wire protocol version 2 encoder referenced in config (badencoder) is not known; ignoring
  s>     POST /api/exp-http-v2-0003/ro/heads HTTP/1.1\r\n
  s>     Accept-Encoding: identity\r\n
  s>     accept: application/mercurial-exp-framing-0006\r\n
  s>     content-type: application/mercurial-exp-framing-0006\r\n
  s>     content-length: 56\r\n
  s>     host: $LOCALIP:$HGPORT\r\n (glob)
  s>     user-agent: Mercurial debugwireproto\r\n
  s>     \r\n
  s>     \x1c\x00\x00\x01\x00\x01\x01\x82\xa1Pcontentencodings\x81Hidentity\x0c\x00\x00\x01\x00\x01\x00\x11\xa1DnameEheads
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
  s>     1e\r\n
  s>     \x16\x00\x00\x01\x00\x02\x041
  s>     \x81T\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00
  s>     \r\n
  received frame(size=22; request=1; stream=2; streamflags=encoded; type=command-response; flags=continuation)
  s>     8\r\n
  s>     \x00\x00\x00\x01\x00\x02\x002
  s>     \r\n
  s>     0\r\n
  s>     \r\n
  received frame(size=0; request=1; stream=2; streamflags=; type=command-response; flags=eos)
  response: [
    b'\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00'
  ]
  (sent 2 HTTP requests and * bytes; received * bytes in responses) (glob)

#if zstd

  $ hg --verbose debugwireproto --nologhandshake --peer http2 http://$LOCALIP:$HGPORT/ << EOF
  > command heads
  > EOF
  creating http peer for wire protocol version 2
  sending heads command
  s>     POST /api/exp-http-v2-0003/ro/heads HTTP/1.1\r\n
  s>     Accept-Encoding: identity\r\n
  s>     accept: application/mercurial-exp-framing-0006\r\n
  s>     content-type: application/mercurial-exp-framing-0006\r\n
  s>     content-length: 70\r\n
  s>     host: $LOCALIP:$HGPORT\r\n (glob)
  s>     user-agent: Mercurial debugwireproto\r\n
  s>     \r\n
  s>     *\x00\x00\x01\x00\x01\x01\x82\xa1Pcontentencodings\x83Hzstd-8mbDzlibHidentity\x0c\x00\x00\x01\x00\x01\x00\x11\xa1DnameEheads
  s> makefile('rb', None)
  s>     HTTP/1.1 200 OK\r\n
  s>     Server: testing stub value\r\n
  s>     Date: $HTTP_DATE$\r\n
  s>     Content-Type: application/mercurial-exp-framing-0006\r\n
  s>     Transfer-Encoding: chunked\r\n
  s>     \r\n
  s>     11\r\n
  s>     \t\x00\x00\x01\x00\x02\x01\x92
  s>     Hzstd-8mb
  s>     \r\n
  received frame(size=9; request=1; stream=2; streamflags=stream-begin; type=stream-settings; flags=eos)
  s>     25\r\n
  s>     \x1d\x00\x00\x01\x00\x02\x042
  s>     (\xb5/\xfd\x00P\xa4\x00\x00p\xa1FstatusBok\x81T\x00\x01\x00\tP\x02
  s>     \r\n
  received frame(size=29; request=1; stream=2; streamflags=encoded; type=command-response; flags=eos)
  s>     0\r\n
  s>     \r\n
  response: [
    b'\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00'
  ]
  (sent 2 HTTP requests and * bytes; received * bytes in responses) (glob)

#endif

  $ cat error.log
