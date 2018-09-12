Tests for wire protocol version 2 exchange.
Tests in this file should be folded into existing tests once protocol
v2 has enough features that it can be enabled via #testcase in existing
tests.

  $ . $TESTDIR/wireprotohelpers.sh
  $ enablehttpv2client

  $ hg init server-simple
  $ enablehttpv2 server-simple
  $ cd server-simple
  $ cat >> .hg/hgrc << EOF
  > [phases]
  > publish = false
  > EOF
  $ echo a0 > a
  $ echo b0 > b
  $ hg -q commit -A -m 'commit 0'

  $ echo a1 > a
  $ hg commit -m 'commit 1'
  $ hg phase --public -r .
  $ echo a2 > a
  $ hg commit -m 'commit 2'

  $ hg -q up -r 0
  $ echo b1 > b
  $ hg -q commit -m 'head 2 commit 1'
  $ echo b2 > b
  $ hg -q commit -m 'head 2 commit 2'

  $ hg serve -p $HGPORT -d --pid-file hg.pid -E error.log
  $ cat hg.pid > $DAEMON_PIDS

  $ cd ..

Test basic clone

  $ hg --debug clone -U http://localhost:$HGPORT client-simple
  using http://localhost:$HGPORT/
  sending capabilities command
  query 1; heads
  sending 2 commands
  sending command heads: {}
  sending command known: {
    'nodes': []
  }
  received frame(size=11; request=1; stream=2; streamflags=stream-begin; type=command-response; flags=continuation)
  received frame(size=43; request=1; stream=2; streamflags=; type=command-response; flags=continuation)
  received frame(size=0; request=1; stream=2; streamflags=; type=command-response; flags=eos)
  received frame(size=11; request=3; stream=2; streamflags=; type=command-response; flags=continuation)
  received frame(size=1; request=3; stream=2; streamflags=; type=command-response; flags=continuation)
  received frame(size=0; request=3; stream=2; streamflags=; type=command-response; flags=eos)
