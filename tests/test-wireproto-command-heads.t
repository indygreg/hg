  $ . $TESTDIR/wireprotohelpers.sh

  $ hg init server
  $ enablehttpv2 server
  $ cd server
  $ hg debugdrawdag << EOF
  > H I J
  > | | |
  > E F G
  > | |/
  > C D
  > |/
  > B
  > |
  > A
  > EOF

  $ hg phase --force --secret J
  $ hg phase --public E

  $ hg log -r 'E + H + I + G + J' -T '{rev}:{node} {desc} {phase}\n'
  4:78d2dca436b2f5b188ac267e29b81e07266d38fc E public
  7:ae492e36b0c8339ffaf328d00b85b4525de1165e H draft
  8:1d6f6b91d44aaba6d5e580bc30a9948530dbe00b I draft
  6:29446d2dc5419c5f97447a8bc062e4cc328bf241 G draft
  9:dec04b246d7cbb670c6689806c05ad17c835284e J secret

  $ hg serve -p $HGPORT -d --pid-file hg.pid -E error.log
  $ cat hg.pid > $DAEMON_PIDS

All non-secret heads returned by default

  $ sendhttpv2peer << EOF
  > command heads
  > EOF
  creating http peer for wire protocol version 2
  sending heads command
  response: [
    b'\x1dok\x91\xd4J\xab\xa6\xd5\xe5\x80\xbc0\xa9\x94\x850\xdb\xe0\x0b',
    b'\xaeI.6\xb0\xc83\x9f\xfa\xf3(\xd0\x0b\x85\xb4R]\xe1\x16^',
    b')Dm-\xc5A\x9c_\x97Dz\x8b\xc0b\xe4\xcc2\x8b\xf2A'
  ]

Requesting just the public heads works

  $ sendhttpv2peer << EOF
  > command heads
  >     publiconly 1
  > EOF
  creating http peer for wire protocol version 2
  sending heads command
  response: [
    b'x\xd2\xdc\xa46\xb2\xf5\xb1\x88\xac&~)\xb8\x1e\x07&m8\xfc'
  ]

  $ cat error.log
