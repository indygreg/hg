  $ HTTPV2=exp-http-v2-0001
  $ MEDIATYPE=application/mercurial-exp-framing-0002

  $ send() {
  >   hg --verbose debugwireproto --peer raw http://$LOCALIP:$HGPORT/
  > }

  $ cat > dummycommands.py << EOF
  > from mercurial import wireprototypes, wireproto
  > @wireproto.wireprotocommand('customreadonly', permission='pull')
  > def customreadonly(repo, proto):
  >     return wireprototypes.bytesresponse(b'customreadonly bytes response')
  > @wireproto.wireprotocommand('customreadwrite', permission='push')
  > def customreadwrite(repo, proto):
  >     return wireprototypes.bytesresponse(b'customreadwrite bytes response')
  > EOF

  $ cat >> $HGRCPATH << EOF
  > [extensions]
  > dummycommands = $TESTTMP/dummycommands.py
  > EOF

  $ hg init server
  $ cat > server/.hg/hgrc << EOF
  > [experimental]
  > web.apiserver = true
  > EOF
  $ hg -R server serve -p $HGPORT -d --pid-file hg.pid
  $ cat hg.pid > $DAEMON_PIDS

HTTP v2 protocol not enabled by default

  $ send << EOF
  > httprequest GET api/$HTTPV2
  >     user-agent: test
  > EOF
  using raw connection to peer
  s>     GET /api/exp-http-v2-0001 HTTP/1.1\r\n
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
  s>     API exp-http-v2-0001 not enabled\n

Restart server with support for HTTP v2 API

  $ killdaemons.py
  $ cat > server/.hg/hgrc << EOF
  > [experimental]
  > web.apiserver = true
  > web.api.http-v2 = true
  > EOF

  $ hg -R server serve -p $HGPORT -d --pid-file hg.pid
  $ cat hg.pid > $DAEMON_PIDS

Request to unknown command yields 404

  $ send << EOF
  > httprequest POST api/$HTTPV2/ro/badcommand
  >     user-agent: test
  > EOF
  using raw connection to peer
  s>     POST /api/exp-http-v2-0001/ro/badcommand HTTP/1.1\r\n
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

  $ send << EOF
  > httprequest GET api/$HTTPV2/ro/customreadonly
  >     user-agent: test
  > EOF
  using raw connection to peer
  s>     GET /api/exp-http-v2-0001/ro/customreadonly HTTP/1.1\r\n
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

  $ send << EOF
  > httprequest POST api/$HTTPV2/ro/customreadonly
  >     user-agent: test
  > EOF
  using raw connection to peer
  s>     POST /api/exp-http-v2-0001/ro/customreadonly HTTP/1.1\r\n
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
  s>     client MUST specify Accept header with value: application/mercurial-exp-framing-0002\n

Bad Accept header results in 406

  $ send << EOF
  > httprequest POST api/$HTTPV2/ro/customreadonly
  >     accept: invalid
  >     user-agent: test
  > EOF
  using raw connection to peer
  s>     POST /api/exp-http-v2-0001/ro/customreadonly HTTP/1.1\r\n
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
  s>     client MUST specify Accept header with value: application/mercurial-exp-framing-0002\n

Bad Content-Type header results in 415

  $ send << EOF
  > httprequest POST api/$HTTPV2/ro/customreadonly
  >     accept: $MEDIATYPE
  >     user-agent: test
  >     content-type: badmedia
  > EOF
  using raw connection to peer
  s>     POST /api/exp-http-v2-0001/ro/customreadonly HTTP/1.1\r\n
  s>     Accept-Encoding: identity\r\n
  s>     accept: application/mercurial-exp-framing-0002\r\n
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
  s>     client MUST send Content-Type header with value: application/mercurial-exp-framing-0002\n

Request to read-only command works out of the box

  $ send << EOF
  > httprequest POST api/$HTTPV2/ro/customreadonly
  >     accept: $MEDIATYPE
  >     content-type: $MEDIATYPE
  >     user-agent: test
  >     frame 1 command-name eos customreadonly
  > EOF
  using raw connection to peer
  s>     POST /api/exp-http-v2-0001/ro/customreadonly HTTP/1.1\r\n
  s>     Accept-Encoding: identity\r\n
  s>     accept: application/mercurial-exp-framing-0002\r\n
  s>     content-type: application/mercurial-exp-framing-0002\r\n
  s>     user-agent: test\r\n
  s>     *\r\n (glob)
  s>     host: $LOCALIP:$HGPORT\r\n (glob)
  s>     \r\n
  s>     \x0e\x00\x00\x01\x00\x11customreadonly
  s> makefile('rb', None)
  s>     HTTP/1.1 200 OK\r\n
  s>     Server: testing stub value\r\n
  s>     Date: $HTTP_DATE$\r\n
  s>     Content-Type: application/mercurial-exp-framing-0002\r\n
  s>     Transfer-Encoding: chunked\r\n
  s>     \r\n
  s>     23\r\n
  s>     \x1d\x00\x00\x01\x00Bcustomreadonly bytes response
  s>     \r\n
  s>     0\r\n
  s>     \r\n

Request to read-write command fails because server is read-only by default

GET to read-write request yields 405

  $ send << EOF
  > httprequest GET api/$HTTPV2/rw/customreadonly
  >     user-agent: test
  > EOF
  using raw connection to peer
  s>     GET /api/exp-http-v2-0001/rw/customreadonly HTTP/1.1\r\n
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

  $ send << EOF
  > httprequest GET api/$HTTPV2/rw/badcommand
  >     user-agent: test
  > EOF
  using raw connection to peer
  s>     GET /api/exp-http-v2-0001/rw/badcommand HTTP/1.1\r\n
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

  $ send << EOF
  > httprequest POST api/$HTTPV2/rw/customreadonly
  >     user-agent: test
  > EOF
  using raw connection to peer
  s>     POST /api/exp-http-v2-0001/rw/customreadonly HTTP/1.1\r\n
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

  $ send << EOF
  > httprequest POST api/$HTTPV2/rw/customreadonly
  >     user-agent: test
  >     accept: $MEDIATYPE
  >     content-type: $MEDIATYPE
  >     frame 1 command-name eos customreadonly
  > EOF
  using raw connection to peer
  s>     POST /api/exp-http-v2-0001/rw/customreadonly HTTP/1.1\r\n
  s>     Accept-Encoding: identity\r\n
  s>     accept: application/mercurial-exp-framing-0002\r\n
  s>     content-type: application/mercurial-exp-framing-0002\r\n
  s>     user-agent: test\r\n
  s>     content-length: 20\r\n
  s>     host: $LOCALIP:$HGPORT\r\n (glob)
  s>     \r\n
  s>     \x0e\x00\x00\x01\x00\x11customreadonly
  s> makefile('rb', None)
  s>     HTTP/1.1 200 OK\r\n
  s>     Server: testing stub value\r\n
  s>     Date: $HTTP_DATE$\r\n
  s>     Content-Type: application/mercurial-exp-framing-0002\r\n
  s>     Transfer-Encoding: chunked\r\n
  s>     \r\n
  s>     23\r\n
  s>     \x1d\x00\x00\x01\x00Bcustomreadonly bytes response
  s>     \r\n
  s>     0\r\n
  s>     \r\n

Authorized request for unknown command is rejected

  $ send << EOF
  > httprequest POST api/$HTTPV2/rw/badcommand
  >     user-agent: test
  >     accept: $MEDIATYPE
  > EOF
  using raw connection to peer
  s>     POST /api/exp-http-v2-0001/rw/badcommand HTTP/1.1\r\n
  s>     Accept-Encoding: identity\r\n
  s>     accept: application/mercurial-exp-framing-0002\r\n
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

  $ send << EOF
  > httprequest POST api/$HTTPV2/ro/debugreflect
  >     user-agent: test
  > EOF
  using raw connection to peer
  s>     POST /api/exp-http-v2-0001/ro/debugreflect HTTP/1.1\r\n
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

  $ send << EOF
  > httprequest POST api/$HTTPV2/ro/debugreflect
  >     accept: $MEDIATYPE
  >     content-type: $MEDIATYPE
  >     user-agent: test
  >     frame 1 command-name have-args command1
  >     frame 1 command-argument 0 \x03\x00\x04\x00fooval1
  >     frame 1 command-argument eoa \x04\x00\x03\x00bar1val
  > EOF
  using raw connection to peer
  s>     POST /api/exp-http-v2-0001/ro/debugreflect HTTP/1.1\r\n
  s>     Accept-Encoding: identity\r\n
  s>     accept: application/mercurial-exp-framing-0002\r\n
  s>     content-type: application/mercurial-exp-framing-0002\r\n
  s>     user-agent: test\r\n
  s>     content-length: 48\r\n
  s>     host: $LOCALIP:$HGPORT\r\n (glob)
  s>     \r\n
  s>     \x08\x00\x00\x01\x00\x12command1\x0b\x00\x00\x01\x00 \x03\x00\x04\x00fooval1\x0b\x00\x00\x01\x00"\x04\x00\x03\x00bar1val
  s> makefile('rb', None)
  s>     HTTP/1.1 200 OK\r\n
  s>     Server: testing stub value\r\n
  s>     Date: $HTTP_DATE$\r\n
  s>     Content-Type: text/plain\r\n
  s>     Content-Length: 322\r\n
  s>     \r\n
  s>     received: 1 2 1 command1\n
  s>     ["wantframe", {"state": "command-receiving"}]\n
  s>     received: 2 0 1 \x03\x00\x04\x00fooval1\n
  s>     ["wantframe", {"state": "command-receiving"}]\n
  s>     received: 2 2 1 \x04\x00\x03\x00bar1val\n
  s>     ["runcommand", {"args": {"bar1": "val", "foo": "val1"}, "command": "command1", "data": null, "requestid": 1}]\n
  s>     received: <no frame>\n
  s>     {"action": "noop"}

Multiple requests to regular command URL are not allowed

  $ send << EOF
  > httprequest POST api/$HTTPV2/ro/customreadonly
  >     accept: $MEDIATYPE
  >     content-type: $MEDIATYPE
  >     user-agent: test
  >     frame 1 command-name eos customreadonly
  >     frame 3 command-name eos customreadonly
  > EOF
  using raw connection to peer
  s>     POST /api/exp-http-v2-0001/ro/customreadonly HTTP/1.1\r\n
  s>     Accept-Encoding: identity\r\n
  s>     accept: application/mercurial-exp-framing-0002\r\n
  s>     content-type: application/mercurial-exp-framing-0002\r\n
  s>     user-agent: test\r\n
  s>     content-length: 40\r\n
  s>     host: $LOCALIP:$HGPORT\r\n (glob)
  s>     \r\n
  s>     \x0e\x00\x00\x01\x00\x11customreadonly\x0e\x00\x00\x03\x00\x11customreadonly
  s> makefile('rb', None)
  s>     HTTP/1.1 200 OK\r\n
  s>     Server: testing stub value\r\n
  s>     Date: $HTTP_DATE$\r\n
  s>     Content-Type: text/plain\r\n
  s>     Content-Length: 46\r\n
  s>     \r\n
  s>     multiple commands cannot be issued to this URL

Multiple requests to "multirequest" URL are allowed

  $ send << EOF
  > httprequest POST api/$HTTPV2/ro/multirequest
  >     accept: $MEDIATYPE
  >     content-type: $MEDIATYPE
  >     user-agent: test
  >     frame 1 command-name eos customreadonly
  >     frame 3 command-name eos customreadonly
  > EOF
  using raw connection to peer
  s>     POST /api/exp-http-v2-0001/ro/multirequest HTTP/1.1\r\n
  s>     Accept-Encoding: identity\r\n
  s>     accept: application/mercurial-exp-framing-0002\r\n
  s>     content-type: application/mercurial-exp-framing-0002\r\n
  s>     user-agent: test\r\n
  s>     *\r\n (glob)
  s>     host: $LOCALIP:$HGPORT\r\n (glob)
  s>     \r\n
  s>     \x0e\x00\x00\x01\x00\x11customreadonly\x0e\x00\x00\x03\x00\x11customreadonly
  s> makefile('rb', None)
  s>     HTTP/1.1 200 OK\r\n
  s>     Server: testing stub value\r\n
  s>     Date: $HTTP_DATE$\r\n
  s>     Content-Type: application/mercurial-exp-framing-0002\r\n
  s>     Transfer-Encoding: chunked\r\n
  s>     \r\n
  s>     *\r\n (glob)
  s>     \x1d\x00\x00\x01\x00Bcustomreadonly bytes response
  s>     \r\n
  s>     23\r\n
  s>     \x1d\x00\x00\x03\x00Bcustomreadonly bytes response
  s>     \r\n
  s>     0\r\n
  s>     \r\n

Interleaved requests to "multirequest" are processed

  $ send << EOF
  > httprequest POST api/$HTTPV2/ro/multirequest
  >     accept: $MEDIATYPE
  >     content-type: $MEDIATYPE
  >     user-agent: test
  >     frame 1 command-name have-args listkeys
  >     frame 3 command-name have-args listkeys
  >     frame 3 command-argument eoa \x09\x00\x09\x00namespacebookmarks
  >     frame 1 command-argument eoa \x09\x00\x0a\x00namespacenamespaces
  > EOF
  using raw connection to peer
  s>     POST /api/exp-http-v2-0001/ro/multirequest HTTP/1.1\r\n
  s>     Accept-Encoding: identity\r\n
  s>     accept: application/mercurial-exp-framing-0002\r\n
  s>     content-type: application/mercurial-exp-framing-0002\r\n
  s>     user-agent: test\r\n
  s>     content-length: 85\r\n
  s>     host: $LOCALIP:$HGPORT\r\n (glob)
  s>     \r\n
  s>     \x08\x00\x00\x01\x00\x12listkeys\x08\x00\x00\x03\x00\x12listkeys\x16\x00\x00\x03\x00"	\x00	\x00namespacebookmarks\x17\x00\x00\x01\x00"	\x00\n
  s>     \x00namespacenamespaces
  s> makefile('rb', None)
  s>     HTTP/1.1 200 OK\r\n
  s>     Server: testing stub value\r\n
  s>     Date: $HTTP_DATE$\r\n
  s>     Content-Type: application/mercurial-exp-framing-0002\r\n
  s>     Transfer-Encoding: chunked\r\n
  s>     \r\n
  s>     6\r\n
  s>     \x00\x00\x00\x03\x00B
  s>     \r\n
  s>     24\r\n
  s>     \x1e\x00\x00\x01\x00Bbookmarks	\n
  s>     namespaces	\n
  s>     phases	
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

  $ send << EOF
  > httprequest POST api/$HTTPV2/ro/multirequest
  >     accept: $MEDIATYPE
  >     content-type: $MEDIATYPE
  >     user-agent: test
  >     frame 1 command-name eos unbundle
  > EOF
  using raw connection to peer
  s>     POST /api/exp-http-v2-0001/ro/multirequest HTTP/1.1\r\n
  s>     Accept-Encoding: identity\r\n
  s>     accept: application/mercurial-exp-framing-0002\r\n
  s>     content-type: application/mercurial-exp-framing-0002\r\n
  s>     user-agent: test\r\n
  s>     content-length: 14\r\n
  s>     host: $LOCALIP:$HGPORT\r\n (glob)
  s>     \r\n
  s>     \x08\x00\x00\x01\x00\x11unbundle
  s> makefile('rb', None)
  s>     HTTP/1.1 403 Forbidden\r\n
  s>     Server: testing stub value\r\n
  s>     Date: $HTTP_DATE$\r\n
  s>     Content-Type: text/plain\r\n
  s>     Content-Length: 53\r\n
  s>     \r\n
  s>     insufficient permissions to execute command: unbundle

  $ cat error.log
