  $ HTTPV2=exp-http-v2-0001
  $ MEDIATYPE=application/mercurial-exp-framing-0001

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
  s>     client MUST specify Accept header with value: application/mercurial-exp-framing-0001\n

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
  s>     client MUST specify Accept header with value: application/mercurial-exp-framing-0001\n

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
  s>     accept: application/mercurial-exp-framing-0001\r\n
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
  s>     client MUST send Content-Type header with value: application/mercurial-exp-framing-0001\n

Request to read-only command works out of the box

  $ send << EOF
  > httprequest POST api/$HTTPV2/ro/customreadonly
  >     accept: $MEDIATYPE
  >     content-type: $MEDIATYPE
  >     user-agent: test
  >     frame command-name eos customreadonly
  > EOF
  using raw connection to peer
  s>     POST /api/exp-http-v2-0001/ro/customreadonly HTTP/1.1\r\n
  s>     Accept-Encoding: identity\r\n
  s>     accept: application/mercurial-exp-framing-0001\r\n
  s>     content-type: application/mercurial-exp-framing-0001\r\n
  s>     user-agent: test\r\n
  s>     content-length: 18\r\n
  s>     host: $LOCALIP:$HGPORT\r\n (glob)
  s>     \r\n
  s>     \x0e\x00\x00\x11customreadonly
  s> makefile('rb', None)
  s>     HTTP/1.1 200 OK\r\n
  s>     Server: testing stub value\r\n
  s>     Date: $HTTP_DATE$\r\n
  s>     Content-Type: text/plain\r\n
  s>     Content-Length: 29\r\n
  s>     \r\n
  s>     customreadonly bytes response

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
  >     frame command-name eos customreadonly
  > EOF
  using raw connection to peer
  s>     POST /api/exp-http-v2-0001/rw/customreadonly HTTP/1.1\r\n
  s>     Accept-Encoding: identity\r\n
  s>     accept: application/mercurial-exp-framing-0001\r\n
  s>     content-type: application/mercurial-exp-framing-0001\r\n
  s>     user-agent: test\r\n
  s>     content-length: 18\r\n
  s>     host: $LOCALIP:$HGPORT\r\n (glob)
  s>     \r\n
  s>     \x0e\x00\x00\x11customreadonly
  s> makefile('rb', None)
  s>     HTTP/1.1 200 OK\r\n
  s>     Server: testing stub value\r\n
  s>     Date: $HTTP_DATE$\r\n
  s>     Content-Type: text/plain\r\n
  s>     Content-Length: 29\r\n
  s>     \r\n
  s>     customreadonly bytes response

Authorized request for unknown command is rejected

  $ send << EOF
  > httprequest POST api/$HTTPV2/rw/badcommand
  >     user-agent: test
  >     accept: $MEDIATYPE
  > EOF
  using raw connection to peer
  s>     POST /api/exp-http-v2-0001/rw/badcommand HTTP/1.1\r\n
  s>     Accept-Encoding: identity\r\n
  s>     accept: application/mercurial-exp-framing-0001\r\n
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
  >     frame command-name have-args command1
  >     frame command-argument 0 \x03\x00\x04\x00fooval1
  >     frame command-argument eoa \x04\x00\x03\x00bar1val
  > EOF
  using raw connection to peer
  s>     POST /api/exp-http-v2-0001/ro/debugreflect HTTP/1.1\r\n
  s>     Accept-Encoding: identity\r\n
  s>     accept: application/mercurial-exp-framing-0001\r\n
  s>     content-type: application/mercurial-exp-framing-0001\r\n
  s>     user-agent: test\r\n
  s>     content-length: 42\r\n
  s>     host: $LOCALIP:$HGPORT\r\n (glob)
  s>     \r\n
  s>     \x08\x00\x00\x12command1\x0b\x00\x00 \x03\x00\x04\x00fooval1\x0b\x00\x00"\x04\x00\x03\x00bar1val
  s> makefile('rb', None)
  s>     HTTP/1.1 200 OK\r\n
  s>     Server: testing stub value\r\n
  s>     Date: $HTTP_DATE$\r\n
  s>     Content-Type: text/plain\r\n
  s>     Content-Length: 291\r\n
  s>     \r\n
  s>     received: 1 2 command1\n
  s>     ["wantframe", {"state": "command-receiving-args"}]\n
  s>     received: 2 0 \x03\x00\x04\x00fooval1\n
  s>     ["wantframe", {"state": "command-receiving-args"}]\n
  s>     received: 2 2 \x04\x00\x03\x00bar1val\n
  s>     ["runcommand", {"args": {"bar1": "val", "foo": "val1"}, "command": "command1", "data": null}]\n
  s>     received: <no frame>

  $ cat error.log
