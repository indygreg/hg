  $ send() {
  >   hg --verbose debugwireproto --peer raw http://$LOCALIP:$HGPORT/
  > }

  $ hg init server
  $ hg -R server serve -p $HGPORT -d --pid-file hg.pid
  $ cat hg.pid > $DAEMON_PIDS

Request to /api fails unless web.apiserver is enabled

  $ send << EOF
  > httprequest GET api
  >     user-agent: test
  > EOF
  using raw connection to peer
  s>     GET /api HTTP/1.1\r\n
  s>     Accept-Encoding: identity\r\n
  s>     user-agent: test\r\n
  s>     host: $LOCALIP:$HGPORT\r\n (glob)
  s>     \r\n
  s> makefile('rb', None)
  s>     HTTP/1.1 404 Not Found\r\n
  s>     Server: testing stub value\r\n
  s>     Date: $HTTP_DATE$\r\n
  s>     Content-Type: text/plain\r\n
  s>     Content-Length: 44\r\n
  s>     \r\n
  s>     Experimental API server endpoint not enabled

  $ send << EOF
  > httprequest GET api/
  >     user-agent: test
  > EOF
  using raw connection to peer
  s>     GET /api/ HTTP/1.1\r\n
  s>     Accept-Encoding: identity\r\n
  s>     user-agent: test\r\n
  s>     host: $LOCALIP:$HGPORT\r\n (glob)
  s>     \r\n
  s> makefile('rb', None)
  s>     HTTP/1.1 404 Not Found\r\n
  s>     Server: testing stub value\r\n
  s>     Date: $HTTP_DATE$\r\n
  s>     Content-Type: text/plain\r\n
  s>     Content-Length: 44\r\n
  s>     \r\n
  s>     Experimental API server endpoint not enabled

Restart server with support for API server

  $ killdaemons.py
  $ cat > server/.hg/hgrc << EOF
  > [experimental]
  > web.apiserver = true
  > EOF

  $ hg -R server serve -p $HGPORT -d --pid-file hg.pid
  $ cat hg.pid > $DAEMON_PIDS

/api lists available APIs (empty since none are available by default)

  $ send << EOF
  > httprequest GET api
  >     user-agent: test
  > EOF
  using raw connection to peer
  s>     GET /api HTTP/1.1\r\n
  s>     Accept-Encoding: identity\r\n
  s>     user-agent: test\r\n
  s>     host: $LOCALIP:$HGPORT\r\n (glob)
  s>     \r\n
  s> makefile('rb', None)
  s>     HTTP/1.1 200 OK\r\n
  s>     Server: testing stub value\r\n
  s>     Date: $HTTP_DATE$\r\n
  s>     Content-Type: text/plain\r\n
  s>     Content-Length: 100\r\n
  s>     \r\n
  s>     APIs can be accessed at /api/<name>, where <name> can be one of the following:\n
  s>     \n
  s>     (no available APIs)\n

  $ send << EOF
  > httprequest GET api/
  >     user-agent: test
  > EOF
  using raw connection to peer
  s>     GET /api/ HTTP/1.1\r\n
  s>     Accept-Encoding: identity\r\n
  s>     user-agent: test\r\n
  s>     host: $LOCALIP:$HGPORT\r\n (glob)
  s>     \r\n
  s> makefile('rb', None)
  s>     HTTP/1.1 200 OK\r\n
  s>     Server: testing stub value\r\n
  s>     Date: $HTTP_DATE$\r\n
  s>     Content-Type: text/plain\r\n
  s>     Content-Length: 100\r\n
  s>     \r\n
  s>     APIs can be accessed at /api/<name>, where <name> can be one of the following:\n
  s>     \n
  s>     (no available APIs)\n

Accessing an unknown API yields a 404

  $ send << EOF
  > httprequest GET api/unknown
  >     user-agent: test
  > EOF
  using raw connection to peer
  s>     GET /api/unknown HTTP/1.1\r\n
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
  s>     Unknown API: unknown\n
  s>     Known APIs: 

Accessing a known but not enabled API yields a different error

  $ send << EOF
  > httprequest GET api/exp-http-v2-0001
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

/api lists the HTTP v2 protocol as available

  $ send << EOF
  > httprequest GET api
  >     user-agent: test
  > EOF
  using raw connection to peer
  s>     GET /api HTTP/1.1\r\n
  s>     Accept-Encoding: identity\r\n
  s>     user-agent: test\r\n
  s>     host: $LOCALIP:$HGPORT\r\n (glob)
  s>     \r\n
  s> makefile('rb', None)
  s>     HTTP/1.1 200 OK\r\n
  s>     Server: testing stub value\r\n
  s>     Date: $HTTP_DATE$\r\n
  s>     Content-Type: text/plain\r\n
  s>     Content-Length: 96\r\n
  s>     \r\n
  s>     APIs can be accessed at /api/<name>, where <name> can be one of the following:\n
  s>     \n
  s>     exp-http-v2-0001

  $ send << EOF
  > httprequest GET api/
  >     user-agent: test
  > EOF
  using raw connection to peer
  s>     GET /api/ HTTP/1.1\r\n
  s>     Accept-Encoding: identity\r\n
  s>     user-agent: test\r\n
  s>     host: $LOCALIP:$HGPORT\r\n (glob)
  s>     \r\n
  s> makefile('rb', None)
  s>     HTTP/1.1 200 OK\r\n
  s>     Server: testing stub value\r\n
  s>     Date: $HTTP_DATE$\r\n
  s>     Content-Type: text/plain\r\n
  s>     Content-Length: 96\r\n
  s>     \r\n
  s>     APIs can be accessed at /api/<name>, where <name> can be one of the following:\n
  s>     \n
  s>     exp-http-v2-0001
