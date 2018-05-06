  $ cat > hgrc-sshv2 << EOF
  > %include $HGRCPATH
  > [experimental]
  > sshpeer.advertise-v2 = true
  > sshserver.support-v2 = true
  > EOF

Helper function to run protocol tests against multiple protocol versions.
This is easier than using #testcases because managing differences between
protocols with inline conditional output is hard to read.

  $ debugwireproto() {
  >   commands=`cat -`
  >   echo 'testing ssh1'
  >   echo "${commands}" | hg --verbose debugwireproto --localssh
  >   echo ""
  >   echo 'testing ssh2'
  >   echo "${commands}" | HGRCPATH=$TESTTMP/hgrc-sshv2 hg --verbose debugwireproto --localssh
  > }

  $ cat >> $HGRCPATH << EOF
  > [ui]
  > ssh = $PYTHON "$TESTDIR/dummyssh"
  > [devel]
  > debug.peer-request = true
  > [extensions]
  > sshprotoext = $TESTDIR/sshprotoext.py
  > EOF

  $ hg init server
  $ cd server
  $ echo 0 > foo
  $ hg -q add foo
  $ hg commit -m initial

A no-op connection performs a handshake

  $ hg debugwireproto --localssh << EOF
  > EOF
  creating ssh peer from handshake results

Raw peers don't perform any activity

  $ hg debugwireproto --localssh --peer raw << EOF
  > EOF
  using raw connection to peer
  $ hg debugwireproto --localssh --peer ssh1 << EOF
  > EOF
  creating ssh peer for wire protocol version 1
  $ hg debugwireproto --localssh --peer ssh2 << EOF
  > EOF
  creating ssh peer for wire protocol version 2

Test a normal behaving server, for sanity

  $ cd ..

  $ hg --debug debugpeer ssh://user@dummy/server
  running * "*/tests/dummyssh" 'user@dummy' 'hg -R server serve --stdio' (glob) (no-windows !)
  running * "*\tests/dummyssh" "user@dummy" "hg -R server serve --stdio" (glob) (windows !)
  devel-peer-request: hello+between
  devel-peer-request:   pairs: 81 bytes
  sending hello command
  sending between command
  remote: 413
  remote: capabilities: batch branchmap $USUAL_BUNDLE2_CAPS_SERVER$ changegroupsubset getbundle known lookup protocaps pushkey streamreqs=generaldelta,revlogv1 unbundle=HG10GZ,HG10BZ,HG10UN unbundlehash
  remote: 1
  devel-peer-request: protocaps
  devel-peer-request:   caps: * bytes (glob)
  sending protocaps command
  url: ssh://user@dummy/server
  local: no
  pushable: yes

Server should answer the "hello" command in isolation

  $ hg -R server debugwireproto --localssh --peer raw << EOF
  > raw
  >     hello\n
  > readline
  > readline
  > EOF
  using raw connection to peer
  i> write(6) -> 6:
  i>     hello\n
  o> readline() -> 4:
  o>     413\n
  o> readline() -> 413:
  o>     capabilities: batch branchmap $USUAL_BUNDLE2_CAPS_SERVER$ changegroupsubset getbundle known lookup protocaps pushkey streamreqs=generaldelta,revlogv1 unbundle=HG10GZ,HG10BZ,HG10UN unbundlehash\n

`hg debugserve --sshstdio` works

  $ cd server
  $ hg debugserve --sshstdio << EOF
  > hello
  > EOF
  413
  capabilities: batch branchmap $USUAL_BUNDLE2_CAPS_SERVER$ changegroupsubset getbundle known lookup protocaps pushkey streamreqs=generaldelta,revlogv1 unbundle=HG10GZ,HG10BZ,HG10UN unbundlehash

I/O logging works

  $ hg debugserve --sshstdio --logiofd 1 << EOF
  > hello
  > EOF
  o> write(4) -> 4:
  o>     413\n
  o> write(413) -> 413:
  o>     capabilities: batch branchmap $USUAL_BUNDLE2_CAPS_SERVER$ changegroupsubset getbundle known lookup protocaps pushkey streamreqs=generaldelta,revlogv1 unbundle=HG10GZ,HG10BZ,HG10UN unbundlehash\n
  413
  capabilities: batch branchmap $USUAL_BUNDLE2_CAPS_SERVER$ changegroupsubset getbundle known lookup protocaps pushkey streamreqs=generaldelta,revlogv1 unbundle=HG10GZ,HG10BZ,HG10UN unbundlehash
  o> flush() -> None

  $ hg debugserve --sshstdio --logiofile $TESTTMP/io << EOF
  > hello
  > EOF
  413
  capabilities: batch branchmap $USUAL_BUNDLE2_CAPS_SERVER$ changegroupsubset getbundle known lookup protocaps pushkey streamreqs=generaldelta,revlogv1 unbundle=HG10GZ,HG10BZ,HG10UN unbundlehash

  $ cat $TESTTMP/io
  o> write(4) -> 4:
  o>     413\n
  o> write(413) -> 413:
  o>     capabilities: batch branchmap $USUAL_BUNDLE2_CAPS_SERVER$ changegroupsubset getbundle known lookup protocaps pushkey streamreqs=generaldelta,revlogv1 unbundle=HG10GZ,HG10BZ,HG10UN unbundlehash\n
  o> flush() -> None

  $ cd ..

>=0.9.1 clients send a "hello" + "between" for the null range as part of handshake.
Server should reply with capabilities and should send "1\n\n" as a successful
reply with empty response to the "between".

  $ hg -R server debugwireproto --localssh --peer raw << EOF
  > raw
  >     hello\n
  > readline
  > readline
  > raw
  >     between\n
  >     pairs 81\n
  >     0000000000000000000000000000000000000000-0000000000000000000000000000000000000000
  > readline
  > readline
  > EOF
  using raw connection to peer
  i> write(6) -> 6:
  i>     hello\n
  o> readline() -> 4:
  o>     413\n
  o> readline() -> 413:
  o>     capabilities: batch branchmap $USUAL_BUNDLE2_CAPS_SERVER$ changegroupsubset getbundle known lookup protocaps pushkey streamreqs=generaldelta,revlogv1 unbundle=HG10GZ,HG10BZ,HG10UN unbundlehash\n
  i> write(98) -> 98:
  i>     between\n
  i>     pairs 81\n
  i>     0000000000000000000000000000000000000000-0000000000000000000000000000000000000000
  o> readline() -> 2:
  o>     1\n
  o> readline() -> 1:
  o>     \n

SSH banner is not printed by default, ignored by clients

  $ SSHSERVERMODE=banner hg debugpeer ssh://user@dummy/server
  url: ssh://user@dummy/server
  local: no
  pushable: yes

--debug will print the banner

  $ SSHSERVERMODE=banner hg --debug debugpeer ssh://user@dummy/server
  running * "*/tests/dummyssh" 'user@dummy' 'hg -R server serve --stdio' (glob) (no-windows !)
  running * "*\tests/dummyssh" "user@dummy" "hg -R server serve --stdio" (glob) (windows !)
  devel-peer-request: hello+between
  devel-peer-request:   pairs: 81 bytes
  sending hello command
  sending between command
  remote: banner: line 0
  remote: banner: line 1
  remote: banner: line 2
  remote: banner: line 3
  remote: banner: line 4
  remote: banner: line 5
  remote: banner: line 6
  remote: banner: line 7
  remote: banner: line 8
  remote: banner: line 9
  remote: 413
  remote: capabilities: batch branchmap $USUAL_BUNDLE2_CAPS_SERVER$ changegroupsubset getbundle known lookup protocaps pushkey streamreqs=generaldelta,revlogv1 unbundle=HG10GZ,HG10BZ,HG10UN unbundlehash
  remote: 1
  devel-peer-request: protocaps
  devel-peer-request:   caps: * bytes (glob)
  sending protocaps command
  url: ssh://user@dummy/server
  local: no
  pushable: yes

And test the banner with the raw protocol

  $ SSHSERVERMODE=banner hg -R server debugwireproto --localssh --peer raw << EOF
  > raw
  >     hello\n
  > readline
  > readline
  > readline
  > readline
  > readline
  > readline
  > readline
  > readline
  > readline
  > readline
  > readline
  > readline
  > raw
  >     between\n
  >     pairs 81\n
  >     0000000000000000000000000000000000000000-0000000000000000000000000000000000000000
  > readline
  > readline
  > EOF
  using raw connection to peer
  i> write(6) -> 6:
  i>     hello\n
  o> readline() -> 15:
  o>     banner: line 0\n
  o> readline() -> 15:
  o>     banner: line 1\n
  o> readline() -> 15:
  o>     banner: line 2\n
  o> readline() -> 15:
  o>     banner: line 3\n
  o> readline() -> 15:
  o>     banner: line 4\n
  o> readline() -> 15:
  o>     banner: line 5\n
  o> readline() -> 15:
  o>     banner: line 6\n
  o> readline() -> 15:
  o>     banner: line 7\n
  o> readline() -> 15:
  o>     banner: line 8\n
  o> readline() -> 15:
  o>     banner: line 9\n
  o> readline() -> 4:
  o>     413\n
  o> readline() -> 413:
  o>     capabilities: batch branchmap $USUAL_BUNDLE2_CAPS_SERVER$ changegroupsubset getbundle known lookup protocaps pushkey streamreqs=generaldelta,revlogv1 unbundle=HG10GZ,HG10BZ,HG10UN unbundlehash\n
  i> write(98) -> 98:
  i>     between\n
  i>     pairs 81\n
  i>     0000000000000000000000000000000000000000-0000000000000000000000000000000000000000
  o> readline() -> 2:
  o>     1\n
  o> readline() -> 1:
  o>     \n

Connecting to a <0.9.1 server that doesn't support the hello command.
The client should refuse, as we dropped support for connecting to such
servers.

  $ SSHSERVERMODE=no-hello hg --debug debugpeer ssh://user@dummy/server
  running * "*/tests/dummyssh" 'user@dummy' 'hg -R server serve --stdio' (glob) (no-windows !)
  running * "*\tests/dummyssh" "user@dummy" "hg -R server serve --stdio" (glob) (windows !)
  devel-peer-request: hello+between
  devel-peer-request:   pairs: 81 bytes
  sending hello command
  sending between command
  remote: 0
  remote: 1
  abort: no suitable response from remote hg!
  [255]

Sending an unknown command to the server results in an empty response to that command

  $ hg -R server debugwireproto --localssh --peer raw << EOF
  > raw
  >     pre-hello\n
  > readline
  > raw
  >     hello\n
  > readline
  > raw
  >     between\n
  >     pairs 81\n
  >     0000000000000000000000000000000000000000-0000000000000000000000000000000000000000
  > readline
  > readline
  > EOF
  using raw connection to peer
  i> write(10) -> 10:
  i>     pre-hello\n
  o> readline() -> 2:
  o>     0\n
  i> write(6) -> 6:
  i>     hello\n
  o> readline() -> 4:
  o>     413\n
  i> write(98) -> 98:
  i>     between\n
  i>     pairs 81\n
  i>     0000000000000000000000000000000000000000-0000000000000000000000000000000000000000
  o> readline() -> 413:
  o>     capabilities: batch branchmap $USUAL_BUNDLE2_CAPS_SERVER$ changegroupsubset getbundle known lookup protocaps pushkey streamreqs=generaldelta,revlogv1 unbundle=HG10GZ,HG10BZ,HG10UN unbundlehash\n
  o> readline() -> 2:
  o>     1\n

  $ hg --config sshpeer.mode=extra-handshake-commands --config sshpeer.handshake-mode=pre-no-args --debug debugpeer ssh://user@dummy/server
  running * "*/tests/dummyssh" 'user@dummy' 'hg -R server serve --stdio' (glob) (no-windows !)
  running * "*\tests/dummyssh" "user@dummy" "hg -R server serve --stdio" (glob) (windows !)
  sending no-args command
  devel-peer-request: hello+between
  devel-peer-request:   pairs: 81 bytes
  sending hello command
  sending between command
  remote: 0
  remote: 413
  remote: capabilities: batch branchmap $USUAL_BUNDLE2_CAPS_SERVER$ changegroupsubset getbundle known lookup protocaps pushkey streamreqs=generaldelta,revlogv1 unbundle=HG10GZ,HG10BZ,HG10UN unbundlehash
  remote: 1
  devel-peer-request: protocaps
  devel-peer-request:   caps: * bytes (glob)
  sending protocaps command
  url: ssh://user@dummy/server
  local: no
  pushable: yes

Send multiple unknown commands before hello

  $ hg -R server debugwireproto --localssh --peer raw << EOF
  > raw
  >     unknown1\n
  > readline
  > raw
  >     unknown2\n
  > readline
  > raw
  >     unknown3\n
  > readline
  > raw
  >     hello\n
  > readline
  > readline
  > raw
  >     between\n
  >     pairs 81\n
  >     0000000000000000000000000000000000000000-0000000000000000000000000000000000000000
  > readline
  > readline
  > EOF
  using raw connection to peer
  i> write(9) -> 9:
  i>     unknown1\n
  o> readline() -> 2:
  o>     0\n
  i> write(9) -> 9:
  i>     unknown2\n
  o> readline() -> 2:
  o>     0\n
  i> write(9) -> 9:
  i>     unknown3\n
  o> readline() -> 2:
  o>     0\n
  i> write(6) -> 6:
  i>     hello\n
  o> readline() -> 4:
  o>     413\n
  o> readline() -> 413:
  o>     capabilities: batch branchmap $USUAL_BUNDLE2_CAPS_SERVER$ changegroupsubset getbundle known lookup protocaps pushkey streamreqs=generaldelta,revlogv1 unbundle=HG10GZ,HG10BZ,HG10UN unbundlehash\n
  i> write(98) -> 98:
  i>     between\n
  i>     pairs 81\n
  i>     0000000000000000000000000000000000000000-0000000000000000000000000000000000000000
  o> readline() -> 2:
  o>     1\n
  o> readline() -> 1:
  o>     \n

  $ hg --config sshpeer.mode=extra-handshake-commands --config sshpeer.handshake-mode=pre-multiple-no-args --debug debugpeer ssh://user@dummy/server
  running * "*/tests/dummyssh" 'user@dummy' 'hg -R server serve --stdio' (glob) (no-windows !)
  running * "*\tests/dummyssh" "user@dummy" "hg -R server serve --stdio" (glob) (windows !)
  sending unknown1 command
  sending unknown2 command
  sending unknown3 command
  devel-peer-request: hello+between
  devel-peer-request:   pairs: 81 bytes
  sending hello command
  sending between command
  remote: 0
  remote: 0
  remote: 0
  remote: 413
  remote: capabilities: batch branchmap $USUAL_BUNDLE2_CAPS_SERVER$ changegroupsubset getbundle known lookup protocaps pushkey streamreqs=generaldelta,revlogv1 unbundle=HG10GZ,HG10BZ,HG10UN unbundlehash
  remote: 1
  devel-peer-request: protocaps
  devel-peer-request:   caps: * bytes (glob)
  sending protocaps command
  url: ssh://user@dummy/server
  local: no
  pushable: yes

Send an unknown command before hello that has arguments

  $ cd server

  $ hg debugwireproto --localssh --peer raw << EOF
  > raw
  >     with-args\n
  >     foo 13\n
  >     value for foo\n
  >     bar 13\n
  >     value for bar\n
  > readline
  > readline
  > readline
  > readline
  > readline
  > raw
  >     hello\n
  > readline
  > readline
  > raw
  >     between\n
  >     pairs 81\n
  >     0000000000000000000000000000000000000000-0000000000000000000000000000000000000000
  > readline
  > readline
  > EOF
  using raw connection to peer
  i> write(52) -> 52:
  i>     with-args\n
  i>     foo 13\n
  i>     value for foo\n
  i>     bar 13\n
  i>     value for bar\n
  o> readline() -> 2:
  o>     0\n
  o> readline() -> 2:
  o>     0\n
  o> readline() -> 2:
  o>     0\n
  o> readline() -> 2:
  o>     0\n
  o> readline() -> 2:
  o>     0\n
  i> write(6) -> 6:
  i>     hello\n
  o> readline() -> 4:
  o>     413\n
  o> readline() -> 413:
  o>     capabilities: batch branchmap $USUAL_BUNDLE2_CAPS_SERVER$ changegroupsubset getbundle known lookup protocaps pushkey streamreqs=generaldelta,revlogv1 unbundle=HG10GZ,HG10BZ,HG10UN unbundlehash\n
  i> write(98) -> 98:
  i>     between\n
  i>     pairs 81\n
  i>     0000000000000000000000000000000000000000-0000000000000000000000000000000000000000
  o> readline() -> 2:
  o>     1\n
  o> readline() -> 1:
  o>     \n

Send an unknown command having an argument that looks numeric

  $ hg debugwireproto --localssh --peer raw << EOF
  > raw
  >     unknown\n
  >     foo 1\n
  >     0\n
  > readline
  > readline
  > readline
  > raw
  >     hello\n
  > readline
  > readline
  > raw
  >     between\n
  >     pairs 81\n
  >     0000000000000000000000000000000000000000-0000000000000000000000000000000000000000
  > readline
  > readline
  > EOF
  using raw connection to peer
  i> write(16) -> 16:
  i>     unknown\n
  i>     foo 1\n
  i>     0\n
  o> readline() -> 2:
  o>     0\n
  o> readline() -> 2:
  o>     0\n
  o> readline() -> 2:
  o>     0\n
  i> write(6) -> 6:
  i>     hello\n
  o> readline() -> 4:
  o>     413\n
  o> readline() -> 413:
  o>     capabilities: batch branchmap $USUAL_BUNDLE2_CAPS_SERVER$ changegroupsubset getbundle known lookup protocaps pushkey streamreqs=generaldelta,revlogv1 unbundle=HG10GZ,HG10BZ,HG10UN unbundlehash\n
  i> write(98) -> 98:
  i>     between\n
  i>     pairs 81\n
  i>     0000000000000000000000000000000000000000-0000000000000000000000000000000000000000
  o> readline() -> 2:
  o>     1\n
  o> readline() -> 1:
  o>     \n

  $ hg debugwireproto --localssh --peer raw << EOF
  > raw
  >     unknown\n
  >     foo 1\n
  >     1\n
  > readline
  > readline
  > readline
  > raw
  >     hello\n
  > readline
  > readline
  > raw
  >     between\n
  >     pairs 81\n
  >     0000000000000000000000000000000000000000-0000000000000000000000000000000000000000
  > readline
  > readline
  > EOF
  using raw connection to peer
  i> write(16) -> 16:
  i>     unknown\n
  i>     foo 1\n
  i>     1\n
  o> readline() -> 2:
  o>     0\n
  o> readline() -> 2:
  o>     0\n
  o> readline() -> 2:
  o>     0\n
  i> write(6) -> 6:
  i>     hello\n
  o> readline() -> 4:
  o>     413\n
  o> readline() -> 413:
  o>     capabilities: batch branchmap $USUAL_BUNDLE2_CAPS_SERVER$ changegroupsubset getbundle known lookup protocaps pushkey streamreqs=generaldelta,revlogv1 unbundle=HG10GZ,HG10BZ,HG10UN unbundlehash\n
  i> write(98) -> 98:
  i>     between\n
  i>     pairs 81\n
  i>     0000000000000000000000000000000000000000-0000000000000000000000000000000000000000
  o> readline() -> 2:
  o>     1\n
  o> readline() -> 1:
  o>     \n

When sending a dict argument value, it is serialized to
"<arg> <item count>" followed by "<key> <len>\n<value>" for each item
in the dict.

Dictionary value for unknown command

  $ hg debugwireproto --localssh --peer raw << EOF
  > raw
  >     unknown\n
  >     dict 3\n
  >     key1 3\n
  >     foo\n
  >     key2 3\n
  >     bar\n
  >     key3 3\n
  >     baz\n
  > readline
  > readline
  > readline
  > readline
  > readline
  > readline
  > readline
  > readline
  > raw
  >     hello\n
  > readline
  > readline
  > EOF
  using raw connection to peer
  i> write(48) -> 48:
  i>     unknown\n
  i>     dict 3\n
  i>     key1 3\n
  i>     foo\n
  i>     key2 3\n
  i>     bar\n
  i>     key3 3\n
  i>     baz\n
  o> readline() -> 2:
  o>     0\n
  o> readline() -> 2:
  o>     0\n
  o> readline() -> 2:
  o>     0\n
  o> readline() -> 2:
  o>     0\n
  o> readline() -> 2:
  o>     0\n
  o> readline() -> 2:
  o>     0\n
  o> readline() -> 2:
  o>     0\n
  o> readline() -> 2:
  o>     0\n
  i> write(6) -> 6:
  i>     hello\n
  o> readline() -> 4:
  o>     413\n
  o> readline() -> 413:
  o>     capabilities: batch branchmap $USUAL_BUNDLE2_CAPS_SERVER$ changegroupsubset getbundle known lookup protocaps pushkey streamreqs=generaldelta,revlogv1 unbundle=HG10GZ,HG10BZ,HG10UN unbundlehash\n

Incomplete dictionary send

  $ hg debugwireproto --localssh --peer raw << EOF
  > raw
  >     unknown\n
  >     dict 3\n
  >     key1 3\n
  >     foo\n
  > readline
  > readline
  > readline
  > readline
  > EOF
  using raw connection to peer
  i> write(26) -> 26:
  i>     unknown\n
  i>     dict 3\n
  i>     key1 3\n
  i>     foo\n
  o> readline() -> 2:
  o>     0\n
  o> readline() -> 2:
  o>     0\n
  o> readline() -> 2:
  o>     0\n
  o> readline() -> 2:
  o>     0\n

Incomplete value send

  $ hg debugwireproto --localssh --peer raw << EOF
  > raw
  >     unknown\n
  >     dict 3\n
  >     key1 3\n
  >     fo
  > readline
  > readline
  > readline
  > EOF
  using raw connection to peer
  i> write(24) -> 24:
  i>     unknown\n
  i>     dict 3\n
  i>     key1 3\n
  i>     fo
  o> readline() -> 2:
  o>     0\n
  o> readline() -> 2:
  o>     0\n
  o> readline() -> 2:
  o>     0\n

Send a command line with spaces

  $ hg debugwireproto --localssh --peer raw << EOF
  > raw
  >     unknown withspace\n
  > readline
  > raw
  >     hello\n
  > readline
  > readline
  > raw
  >     between\n
  >     pairs 81\n
  >     0000000000000000000000000000000000000000-0000000000000000000000000000000000000000
  > readline
  > readline
  > EOF
  using raw connection to peer
  i> write(18) -> 18:
  i>     unknown withspace\n
  o> readline() -> 2:
  o>     0\n
  i> write(6) -> 6:
  i>     hello\n
  o> readline() -> 4:
  o>     413\n
  o> readline() -> 413:
  o>     capabilities: batch branchmap $USUAL_BUNDLE2_CAPS_SERVER$ changegroupsubset getbundle known lookup protocaps pushkey streamreqs=generaldelta,revlogv1 unbundle=HG10GZ,HG10BZ,HG10UN unbundlehash\n
  i> write(98) -> 98:
  i>     between\n
  i>     pairs 81\n
  i>     0000000000000000000000000000000000000000-0000000000000000000000000000000000000000
  o> readline() -> 2:
  o>     1\n
  o> readline() -> 1:
  o>     \n

  $ hg debugwireproto --localssh --peer raw << EOF
  > raw
  >     unknown with multiple spaces\n
  > readline
  > raw
  >     hello\n
  > readline
  > readline
  > raw
  >     between\n
  >     pairs 81\n
  >     0000000000000000000000000000000000000000-0000000000000000000000000000000000000000
  > readline
  > EOF
  using raw connection to peer
  i> write(29) -> 29:
  i>     unknown with multiple spaces\n
  o> readline() -> 2:
  o>     0\n
  i> write(6) -> 6:
  i>     hello\n
  o> readline() -> 4:
  o>     413\n
  o> readline() -> 413:
  o>     capabilities: batch branchmap $USUAL_BUNDLE2_CAPS_SERVER$ changegroupsubset getbundle known lookup protocaps pushkey streamreqs=generaldelta,revlogv1 unbundle=HG10GZ,HG10BZ,HG10UN unbundlehash\n
  i> write(98) -> 98:
  i>     between\n
  i>     pairs 81\n
  i>     0000000000000000000000000000000000000000-0000000000000000000000000000000000000000
  o> readline() -> 2:
  o>     1\n

  $ hg debugwireproto --localssh --peer raw << EOF
  > raw
  >     unknown with spaces\n
  >     key 10\n
  >     some value\n
  > readline
  > readline
  > readline
  > raw
  >     hello\n
  > readline
  > readline
  > raw
  >     between\n
  >     pairs 81\n
  >     0000000000000000000000000000000000000000-0000000000000000000000000000000000000000
  > readline
  > readline
  > EOF
  using raw connection to peer
  i> write(38) -> 38:
  i>     unknown with spaces\n
  i>     key 10\n
  i>     some value\n
  o> readline() -> 2:
  o>     0\n
  o> readline() -> 2:
  o>     0\n
  o> readline() -> 2:
  o>     0\n
  i> write(6) -> 6:
  i>     hello\n
  o> readline() -> 4:
  o>     413\n
  o> readline() -> 413:
  o>     capabilities: batch branchmap $USUAL_BUNDLE2_CAPS_SERVER$ changegroupsubset getbundle known lookup protocaps pushkey streamreqs=generaldelta,revlogv1 unbundle=HG10GZ,HG10BZ,HG10UN unbundlehash\n
  i> write(98) -> 98:
  i>     between\n
  i>     pairs 81\n
  i>     0000000000000000000000000000000000000000-0000000000000000000000000000000000000000
  o> readline() -> 2:
  o>     1\n
  o> readline() -> 1:
  o>     \n
Send an unknown command after the "between"

  $ hg debugwireproto --localssh --peer raw << EOF
  > raw
  >     hello\n
  > readline
  > readline
  > raw
  >     between\n
  >     pairs 81\n
  >     0000000000000000000000000000000000000000-0000000000000000000000000000000000000000unknown
  > readline
  > readline
  > EOF
  using raw connection to peer
  i> write(6) -> 6:
  i>     hello\n
  o> readline() -> 4:
  o>     413\n
  o> readline() -> 413:
  o>     capabilities: batch branchmap $USUAL_BUNDLE2_CAPS_SERVER$ changegroupsubset getbundle known lookup protocaps pushkey streamreqs=generaldelta,revlogv1 unbundle=HG10GZ,HG10BZ,HG10UN unbundlehash\n
  i> write(105) -> 105:
  i>     between\n
  i>     pairs 81\n
  i>     0000000000000000000000000000000000000000-0000000000000000000000000000000000000000unknown
  o> readline() -> 2:
  o>     1\n
  o> readline() -> 1:
  o>     \n

And one with arguments

  $ hg debugwireproto --localssh --peer raw << EOF
  > raw
  >     hello\n
  >     between\n
  >     pairs 81\n
  >     0000000000000000000000000000000000000000-0000000000000000000000000000000000000000
  > readline
  > readline
  > readline
  > readline
  > raw
  >     unknown\n
  >     foo 5\n
  >     \nvalue\n
  >     bar 3\n
  >     baz\n
  > readline
  > readline
  > readline
  > EOF
  using raw connection to peer
  i> write(104) -> 104:
  i>     hello\n
  i>     between\n
  i>     pairs 81\n
  i>     0000000000000000000000000000000000000000-0000000000000000000000000000000000000000
  o> readline() -> 4:
  o>     413\n
  o> readline() -> 413:
  o>     capabilities: batch branchmap $USUAL_BUNDLE2_CAPS_SERVER$ changegroupsubset getbundle known lookup protocaps pushkey streamreqs=generaldelta,revlogv1 unbundle=HG10GZ,HG10BZ,HG10UN unbundlehash\n
  o> readline() -> 2:
  o>     1\n
  o> readline() -> 1:
  o>     \n
  i> write(31) -> 31:
  i>     unknown\n
  i>     foo 5\n
  i>     \n
  i>     value\n
  i>     bar 3\n
  i>     baz\n
  o> readline() -> 2:
  o>     0\n
  o> readline() -> 2:
  o>     0\n
  o> readline() -> 0: 

Send a valid command before the handshake

  $ hg debugwireproto --localssh --peer raw << EOF
  > raw
  >     heads\n
  > readline
  > raw
  >     hello\n
  >     between\n
  >     pairs 81\n
  >     0000000000000000000000000000000000000000-0000000000000000000000000000000000000000
  > readline
  > readline
  > readline
  > readline
  > EOF
  using raw connection to peer
  i> write(6) -> 6:
  i>     heads\n
  o> readline() -> 3:
  o>     41\n
  i> write(104) -> 104:
  i>     hello\n
  i>     between\n
  i>     pairs 81\n
  i>     0000000000000000000000000000000000000000-0000000000000000000000000000000000000000
  o> readline() -> 41:
  o>     68986213bd4485ea51533535e3fc9e78007a711f\n
  o> readline() -> 4:
  o>     413\n
  o> readline() -> 413:
  o>     capabilities: batch branchmap $USUAL_BUNDLE2_CAPS_SERVER$ changegroupsubset getbundle known lookup protocaps pushkey streamreqs=generaldelta,revlogv1 unbundle=HG10GZ,HG10BZ,HG10UN unbundlehash\n
  o> readline() -> 2:
  o>     1\n

And a variation that doesn't send the between command

  $ hg debugwireproto --localssh --peer raw << EOF
  > raw
  >     heads\n
  > readline
  > raw
  >     hello\n
  > readline
  > readline
  > EOF
  using raw connection to peer
  i> write(6) -> 6:
  i>     heads\n
  o> readline() -> 3:
  o>     41\n
  i> write(6) -> 6:
  i>     hello\n
  o> readline() -> 41:
  o>     68986213bd4485ea51533535e3fc9e78007a711f\n
  o> readline() -> 4:
  o>     413\n

Send an upgrade request to a server that doesn't support that command

  $ hg debugwireproto --localssh --peer raw << EOF
  > raw
  >     upgrade 2e82ab3f-9ce3-4b4e-8f8c-6fd1c0e9e23a proto=irrelevant1%2Cirrelevant2\n
  > readline
  > raw
  >     hello\n
  >     between\n
  >     pairs 81\n
  >     0000000000000000000000000000000000000000-0000000000000000000000000000000000000000
  > readline
  > readline
  > readline
  > readline
  > EOF
  using raw connection to peer
  i> write(77) -> 77:
  i>     upgrade 2e82ab3f-9ce3-4b4e-8f8c-6fd1c0e9e23a proto=irrelevant1%2Cirrelevant2\n
  o> readline() -> 2:
  o>     0\n
  i> write(104) -> 104:
  i>     hello\n
  i>     between\n
  i>     pairs 81\n
  i>     0000000000000000000000000000000000000000-0000000000000000000000000000000000000000
  o> readline() -> 4:
  o>     413\n
  o> readline() -> 413:
  o>     capabilities: batch branchmap $USUAL_BUNDLE2_CAPS_SERVER$ changegroupsubset getbundle known lookup protocaps pushkey streamreqs=generaldelta,revlogv1 unbundle=HG10GZ,HG10BZ,HG10UN unbundlehash\n
  o> readline() -> 2:
  o>     1\n
  o> readline() -> 1:
  o>     \n

  $ cd ..

  $ hg --config experimental.sshpeer.advertise-v2=true --debug debugpeer ssh://user@dummy/server
  running * "*/tests/dummyssh" 'user@dummy' 'hg -R server serve --stdio' (glob) (no-windows !)
  running * "*\tests/dummyssh" "user@dummy" "hg -R server serve --stdio" (glob) (windows !)
  sending upgrade request: * proto=exp-ssh-v2-0001 (glob)
  devel-peer-request: hello+between
  devel-peer-request:   pairs: 81 bytes
  sending hello command
  sending between command
  remote: 0
  remote: 413
  remote: capabilities: batch branchmap $USUAL_BUNDLE2_CAPS_SERVER$ changegroupsubset getbundle known lookup protocaps pushkey streamreqs=generaldelta,revlogv1 unbundle=HG10GZ,HG10BZ,HG10UN unbundlehash
  remote: 1
  devel-peer-request: protocaps
  devel-peer-request:   caps: * bytes (glob)
  sending protocaps command
  url: ssh://user@dummy/server
  local: no
  pushable: yes

Enable version 2 support on server. We need to do this in hgrc because we can't
use --config with `hg serve --stdio`.

  $ cat >> server/.hg/hgrc << EOF
  > [experimental]
  > sshserver.support-v2 = true
  > EOF

Send an upgrade request to a server that supports upgrade

  $ cd server

  $ hg debugwireproto --localssh --peer raw << EOF
  > raw
  >     upgrade this-is-some-token proto=exp-ssh-v2-0001\n
  >     hello\n
  >     between\n
  >     pairs 81\n
  >     0000000000000000000000000000000000000000-0000000000000000000000000000000000000000
  > readline
  > readline
  > readline
  > EOF
  using raw connection to peer
  i> write(153) -> 153:
  i>     upgrade this-is-some-token proto=exp-ssh-v2-0001\n
  i>     hello\n
  i>     between\n
  i>     pairs 81\n
  i>     0000000000000000000000000000000000000000-0000000000000000000000000000000000000000
  o> readline() -> 44:
  o>     upgraded this-is-some-token exp-ssh-v2-0001\n
  o> readline() -> 4:
  o>     412\n
  o> readline() -> 413:
  o>     capabilities: batch branchmap $USUAL_BUNDLE2_CAPS_SERVER$ changegroupsubset getbundle known lookup protocaps pushkey streamreqs=generaldelta,revlogv1 unbundle=HG10GZ,HG10BZ,HG10UN unbundlehash\n

  $ cd ..

  $ hg --config experimental.sshpeer.advertise-v2=true --debug debugpeer ssh://user@dummy/server
  running * "*/tests/dummyssh" 'user@dummy' 'hg -R server serve --stdio' (glob) (no-windows !)
  running * "*\tests/dummyssh" "user@dummy" "hg -R server serve --stdio" (glob) (windows !)
  sending upgrade request: * proto=exp-ssh-v2-0001 (glob)
  devel-peer-request: hello+between
  devel-peer-request:   pairs: 81 bytes
  sending hello command
  sending between command
  protocol upgraded to exp-ssh-v2-0001
  remote: capabilities: batch branchmap $USUAL_BUNDLE2_CAPS_SERVER$ changegroupsubset getbundle known lookup protocaps pushkey streamreqs=generaldelta,revlogv1 unbundle=HG10GZ,HG10BZ,HG10UN unbundlehash
  devel-peer-request: protocaps
  devel-peer-request:   caps: * bytes (glob)
  sending protocaps command
  url: ssh://user@dummy/server
  local: no
  pushable: yes

Verify the peer has capabilities

  $ hg --config experimental.sshpeer.advertise-v2=true --debug debugcapabilities ssh://user@dummy/server
  running * "*/tests/dummyssh" 'user@dummy' 'hg -R server serve --stdio' (glob) (no-windows !)
  running * "*\tests/dummyssh" "user@dummy" "hg -R server serve --stdio" (glob) (windows !)
  sending upgrade request: * proto=exp-ssh-v2-0001 (glob)
  devel-peer-request: hello+between
  devel-peer-request:   pairs: 81 bytes
  sending hello command
  sending between command
  protocol upgraded to exp-ssh-v2-0001
  remote: capabilities: batch branchmap $USUAL_BUNDLE2_CAPS_SERVER$ changegroupsubset getbundle known lookup protocaps pushkey streamreqs=generaldelta,revlogv1 unbundle=HG10GZ,HG10BZ,HG10UN unbundlehash
  devel-peer-request: protocaps
  devel-peer-request:   caps: * bytes (glob)
  sending protocaps command
  Main capabilities:
    batch
    branchmap
    $USUAL_BUNDLE2_CAPS_SERVER$
    changegroupsubset
    getbundle
    known
    lookup
    protocaps
    pushkey
    streamreqs=generaldelta,revlogv1
    unbundle=HG10GZ,HG10BZ,HG10UN
    unbundlehash
  Bundle2 capabilities:
    HG20
    bookmarks
    changegroup
      01
      02
    digests
      md5
      sha1
      sha512
    error
      abort
      unsupportedcontent
      pushraced
      pushkey
    hgtagsfnodes
    listkeys
    phases
      heads
    pushkey
    remote-changegroup
      http
      https
    rev-branch-cache

Command after upgrade to version 2 is processed

  $ cd server

  $ hg debugwireproto --localssh --peer raw << EOF
  > raw
  >      upgrade this-is-some-token proto=exp-ssh-v2-0001\n
  >      hello\n
  >      between\n
  >      pairs 81\n
  >      0000000000000000000000000000000000000000-0000000000000000000000000000000000000000
  > readline
  > readline
  > readline
  > raw
  >      hello\n
  > readline
  > readline
  > EOF
  using raw connection to peer
  i> write(153) -> 153:
  i>     upgrade this-is-some-token proto=exp-ssh-v2-0001\n
  i>     hello\n
  i>     between\n
  i>     pairs 81\n
  i>     0000000000000000000000000000000000000000-0000000000000000000000000000000000000000
  o> readline() -> 44:
  o>     upgraded this-is-some-token exp-ssh-v2-0001\n
  o> readline() -> 4:
  o>     412\n
  o> readline() -> 413:
  o>     capabilities: batch branchmap $USUAL_BUNDLE2_CAPS_SERVER$ changegroupsubset getbundle known lookup protocaps pushkey streamreqs=generaldelta,revlogv1 unbundle=HG10GZ,HG10BZ,HG10UN unbundlehash\n
  i> write(6) -> 6:
  i>     hello\n
  o> readline() -> 4:
  o>     397\n
  o> readline() -> 397:
  o>     capabilities: branchmap $USUAL_BUNDLE2_CAPS_SERVER$ changegroupsubset getbundle known lookup pushkey streamreqs=generaldelta,revlogv1 unbundle=HG10GZ,HG10BZ,HG10UN unbundlehash\n

Multiple upgrades is not allowed

  $ hg debugwireproto --localssh --peer raw << EOF
  > raw
  >     upgrade this-is-some-token proto=exp-ssh-v2-0001\n
  >     hello\n
  >     between\n
  >     pairs 81\n
  >     0000000000000000000000000000000000000000-0000000000000000000000000000000000000000
  > readline
  > readline
  > readline
  > raw
  >     upgrade another-token proto=irrelevant\n
  >     hello\n
  > readline
  > readavailable
  > EOF
  using raw connection to peer
  i> write(153) -> 153:
  i>     upgrade this-is-some-token proto=exp-ssh-v2-0001\n
  i>     hello\n
  i>     between\n
  i>     pairs 81\n
  i>     0000000000000000000000000000000000000000-0000000000000000000000000000000000000000
  o> readline() -> 44:
  o>     upgraded this-is-some-token exp-ssh-v2-0001\n
  o> readline() -> 4:
  o>     412\n
  o> readline() -> 413:
  o>     capabilities: batch branchmap $USUAL_BUNDLE2_CAPS_SERVER$ changegroupsubset getbundle known lookup protocaps pushkey streamreqs=generaldelta,revlogv1 unbundle=HG10GZ,HG10BZ,HG10UN unbundlehash\n
  i> write(45) -> 45:
  i>     upgrade another-token proto=irrelevant\n
  i>     hello\n
  o> readline() -> 1:
  o>     \n
  o> read(-1) -> 0: 
  e> read(-1) -> 42:
  e>     cannot upgrade protocols multiple times\n
  e>     -\n

Malformed upgrade request line (not exactly 3 space delimited tokens)

  $ hg debugwireproto --localssh --peer raw << EOF
  > raw
  >     upgrade\n
  > readline
  > EOF
  using raw connection to peer
  i> write(8) -> 8:
  i>     upgrade\n
  o> readline() -> 2:
  o>     0\n

  $ hg debugwireproto --localssh --peer raw << EOF
  > raw
  >     upgrade token\n
  > readline
  > EOF
  using raw connection to peer
  i> write(14) -> 14:
  i>     upgrade token\n
  o> readline() -> 2:
  o>     0\n

  $ hg debugwireproto --localssh --peer raw << EOF
  > raw
  >     upgrade token foo=bar extra-token\n
  > readline
  > EOF
  using raw connection to peer
  i> write(34) -> 34:
  i>     upgrade token foo=bar extra-token\n
  o> readline() -> 2:
  o>     0\n

Upgrade request to unsupported protocol is ignored

  $ hg debugwireproto --localssh --peer raw << EOF
  > raw
  >     upgrade this-is-some-token proto=unknown1,unknown2\n
  > readline
  > raw
  >     hello\n
  > readline
  > readline
  > raw
  >     between\n
  >     pairs 81\n
  >     0000000000000000000000000000000000000000-0000000000000000000000000000000000000000
  > readline
  > readline
  > EOF
  using raw connection to peer
  i> write(51) -> 51:
  i>     upgrade this-is-some-token proto=unknown1,unknown2\n
  o> readline() -> 2:
  o>     0\n
  i> write(6) -> 6:
  i>     hello\n
  o> readline() -> 4:
  o>     413\n
  o> readline() -> 413:
  o>     capabilities: batch branchmap $USUAL_BUNDLE2_CAPS_SERVER$ changegroupsubset getbundle known lookup protocaps pushkey streamreqs=generaldelta,revlogv1 unbundle=HG10GZ,HG10BZ,HG10UN unbundlehash\n
  i> write(98) -> 98:
  i>     between\n
  i>     pairs 81\n
  i>     0000000000000000000000000000000000000000-0000000000000000000000000000000000000000
  o> readline() -> 2:
  o>     1\n
  o> readline() -> 1:
  o>     \n

Upgrade request must be followed by hello + between

  $ hg debugwireproto --localssh --peer raw << EOF
  > raw
  >     upgrade token proto=exp-ssh-v2-0001\n
  >     invalid\n
  > readline
  > readavailable
  > EOF
  using raw connection to peer
  i> write(44) -> 44:
  i>     upgrade token proto=exp-ssh-v2-0001\n
  i>     invalid\n
  o> readline() -> 1:
  o>     \n
  o> read(-1) -> 0: 
  e> read(-1) -> 46:
  e>     malformed handshake protocol: missing hello\n
  e>     -\n

  $ hg debugwireproto --localssh --peer raw << EOF
  > raw
  >     upgrade token proto=exp-ssh-v2-0001\n
  >     hello\n
  >     invalid\n
  > readline
  > readavailable
  > EOF
  using raw connection to peer
  i> write(50) -> 50:
  i>     upgrade token proto=exp-ssh-v2-0001\n
  i>     hello\n
  i>     invalid\n
  o> readline() -> 1:
  o>     \n
  o> read(-1) -> 0: 
  e> read(-1) -> 48:
  e>     malformed handshake protocol: missing between\n
  e>     -\n

  $ hg debugwireproto --localssh --peer raw << EOF
  > raw
  >     upgrade token proto=exp-ssh-v2-0001\n
  >     hello\n
  >     between\n
  >     invalid\n
  > readline
  > readavailable
  > EOF
  using raw connection to peer
  i> write(58) -> 58:
  i>     upgrade token proto=exp-ssh-v2-0001\n
  i>     hello\n
  i>     between\n
  i>     invalid\n
  o> readline() -> 1:
  o>     \n
  o> read(-1) -> 0: 
  e> read(-1) -> 49:
  e>     malformed handshake protocol: missing pairs 81\n
  e>     -\n

Legacy commands are not exposed to version 2 of protocol

TODO re-enable these once we're back to actually using v2 commands

$ hg --config experimental.sshpeer.advertise-v2=true debugwireproto --localssh << EOF
> command branches
>     nodes 0000000000000000000000000000000000000000
> EOF
creating ssh peer from handshake results
sending branches command
response:

$ hg --config experimental.sshpeer.advertise-v2=true debugwireproto --localssh << EOF
> command changegroup
>     roots 0000000000000000000000000000000000000000
> EOF
creating ssh peer from handshake results
sending changegroup command
response:

$ hg --config experimental.sshpeer.advertise-v2=true debugwireproto --localssh << EOF
> command changegroupsubset
>     bases 0000000000000000000000000000000000000000
>     heads 0000000000000000000000000000000000000000
> EOF
creating ssh peer from handshake results
sending changegroupsubset command
response:

  $ cd ..

Test listkeys for listing namespaces

  $ hg init empty
  $ cd empty
  $ debugwireproto << EOF
  > command listkeys
  >     namespace namespaces
  > EOF
  testing ssh1
  creating ssh peer from handshake results
  i> write(104) -> 104:
  i>     hello\n
  i>     between\n
  i>     pairs 81\n
  i>     0000000000000000000000000000000000000000-0000000000000000000000000000000000000000
  i> flush() -> None
  o> readline() -> 4:
  o>     413\n
  o> readline() -> 413:
  o>     capabilities: batch branchmap $USUAL_BUNDLE2_CAPS_SERVER$ changegroupsubset getbundle known lookup protocaps pushkey streamreqs=generaldelta,revlogv1 unbundle=HG10GZ,HG10BZ,HG10UN unbundlehash\n
  o> readline() -> 2:
  o>     1\n
  o> readline() -> 1:
  o>     \n
  sending listkeys command
  i> write(9) -> 9:
  i>     listkeys\n
  i> write(13) -> 13:
  i>     namespace 10\n
  i> write(10) -> 10: namespaces
  i> flush() -> None
  o> bufferedreadline() -> 3:
  o>     30\n
  o> bufferedread(30) -> 30:
  o>     bookmarks\t\n
  o>     namespaces\t\n
  o>     phases\t
  response: {b'bookmarks': b'', b'namespaces': b'', b'phases': b''}
  
  testing ssh2
  creating ssh peer from handshake results
  i> write(171) -> 171:
  i>     upgrade * proto=exp-ssh-v2-0001\n (glob)
  i>     hello\n
  i>     between\n
  i>     pairs 81\n
  i>     0000000000000000000000000000000000000000-0000000000000000000000000000000000000000
  i> flush() -> None
  o> readline() -> 62:
  o>     upgraded * exp-ssh-v2-0001\n (glob)
  o> readline() -> 4:
  o>     412\n
  o> read(412) -> 412: capabilities: batch branchmap $USUAL_BUNDLE2_CAPS_SERVER$ changegroupsubset getbundle known lookup protocaps pushkey streamreqs=generaldelta,revlogv1 unbundle=HG10GZ,HG10BZ,HG10UN unbundlehash
  o> read(1) -> 1:
  o>     \n
  sending listkeys command
  i> write(9) -> 9:
  i>     listkeys\n
  i> write(13) -> 13:
  i>     namespace 10\n
  i> write(10) -> 10: namespaces
  i> flush() -> None
  o> bufferedreadline() -> 3:
  o>     30\n
  o> bufferedread(30) -> 30:
  o>     bookmarks\t\n
  o>     namespaces\t\n
  o>     phases\t
  response: {b'bookmarks': b'', b'namespaces': b'', b'phases': b''}

  $ cd ..

Test listkeys for bookmarks

  $ hg init bookmarkrepo
  $ cd bookmarkrepo
  $ echo 0 > foo
  $ hg add foo
  $ hg -q commit -m initial
  $ echo 1 > foo
  $ hg commit -m second

With no bookmarks set

  $ debugwireproto << EOF
  > command listkeys
  >     namespace bookmarks
  > EOF
  testing ssh1
  creating ssh peer from handshake results
  i> write(104) -> 104:
  i>     hello\n
  i>     between\n
  i>     pairs 81\n
  i>     0000000000000000000000000000000000000000-0000000000000000000000000000000000000000
  i> flush() -> None
  o> readline() -> 4:
  o>     413\n
  o> readline() -> 413:
  o>     capabilities: batch branchmap $USUAL_BUNDLE2_CAPS_SERVER$ changegroupsubset getbundle known lookup protocaps pushkey streamreqs=generaldelta,revlogv1 unbundle=HG10GZ,HG10BZ,HG10UN unbundlehash\n
  o> readline() -> 2:
  o>     1\n
  o> readline() -> 1:
  o>     \n
  sending listkeys command
  i> write(9) -> 9:
  i>     listkeys\n
  i> write(12) -> 12:
  i>     namespace 9\n
  i> write(9) -> 9: bookmarks
  i> flush() -> None
  o> bufferedreadline() -> 2:
  o>     0\n
  response: {}
  
  testing ssh2
  creating ssh peer from handshake results
  i> write(171) -> 171:
  i>     upgrade * proto=exp-ssh-v2-0001\n (glob)
  i>     hello\n
  i>     between\n
  i>     pairs 81\n
  i>     0000000000000000000000000000000000000000-0000000000000000000000000000000000000000
  i> flush() -> None
  o> readline() -> 62:
  o>     upgraded * exp-ssh-v2-0001\n (glob)
  o> readline() -> 4:
  o>     412\n
  o> read(412) -> 412: capabilities: batch branchmap $USUAL_BUNDLE2_CAPS_SERVER$ changegroupsubset getbundle known lookup protocaps pushkey streamreqs=generaldelta,revlogv1 unbundle=HG10GZ,HG10BZ,HG10UN unbundlehash
  o> read(1) -> 1:
  o>     \n
  sending listkeys command
  i> write(9) -> 9:
  i>     listkeys\n
  i> write(12) -> 12:
  i>     namespace 9\n
  i> write(9) -> 9: bookmarks
  i> flush() -> None
  o> bufferedreadline() -> 2:
  o>     0\n
  response: {}

With a single bookmark set

  $ hg book -r 0 bookA
  $ debugwireproto << EOF
  > command listkeys
  >     namespace bookmarks
  > EOF
  testing ssh1
  creating ssh peer from handshake results
  i> write(104) -> 104:
  i>     hello\n
  i>     between\n
  i>     pairs 81\n
  i>     0000000000000000000000000000000000000000-0000000000000000000000000000000000000000
  i> flush() -> None
  o> readline() -> 4:
  o>     413\n
  o> readline() -> 413:
  o>     capabilities: batch branchmap $USUAL_BUNDLE2_CAPS_SERVER$ changegroupsubset getbundle known lookup protocaps pushkey streamreqs=generaldelta,revlogv1 unbundle=HG10GZ,HG10BZ,HG10UN unbundlehash\n
  o> readline() -> 2:
  o>     1\n
  o> readline() -> 1:
  o>     \n
  sending listkeys command
  i> write(9) -> 9:
  i>     listkeys\n
  i> write(12) -> 12:
  i>     namespace 9\n
  i> write(9) -> 9: bookmarks
  i> flush() -> None
  o> bufferedreadline() -> 3:
  o>     46\n
  o> bufferedread(46) -> 46: bookA\t68986213bd4485ea51533535e3fc9e78007a711f
  response: {b'bookA': b'68986213bd4485ea51533535e3fc9e78007a711f'}
  
  testing ssh2
  creating ssh peer from handshake results
  i> write(171) -> 171:
  i>     upgrade * proto=exp-ssh-v2-0001\n (glob)
  i>     hello\n
  i>     between\n
  i>     pairs 81\n
  i>     0000000000000000000000000000000000000000-0000000000000000000000000000000000000000
  i> flush() -> None
  o> readline() -> 62:
  o>     upgraded * exp-ssh-v2-0001\n (glob)
  o> readline() -> 4:
  o>     412\n
  o> read(412) -> 412: capabilities: batch branchmap $USUAL_BUNDLE2_CAPS_SERVER$ changegroupsubset getbundle known lookup protocaps pushkey streamreqs=generaldelta,revlogv1 unbundle=HG10GZ,HG10BZ,HG10UN unbundlehash
  o> read(1) -> 1:
  o>     \n
  sending listkeys command
  i> write(9) -> 9:
  i>     listkeys\n
  i> write(12) -> 12:
  i>     namespace 9\n
  i> write(9) -> 9: bookmarks
  i> flush() -> None
  o> bufferedreadline() -> 3:
  o>     46\n
  o> bufferedread(46) -> 46: bookA\t68986213bd4485ea51533535e3fc9e78007a711f
  response: {b'bookA': b'68986213bd4485ea51533535e3fc9e78007a711f'}

With multiple bookmarks set

  $ hg book -r 1 bookB
  $ debugwireproto << EOF
  > command listkeys
  >     namespace bookmarks
  > EOF
  testing ssh1
  creating ssh peer from handshake results
  i> write(104) -> 104:
  i>     hello\n
  i>     between\n
  i>     pairs 81\n
  i>     0000000000000000000000000000000000000000-0000000000000000000000000000000000000000
  i> flush() -> None
  o> readline() -> 4:
  o>     413\n
  o> readline() -> 413:
  o>     capabilities: batch branchmap $USUAL_BUNDLE2_CAPS_SERVER$ changegroupsubset getbundle known lookup protocaps pushkey streamreqs=generaldelta,revlogv1 unbundle=HG10GZ,HG10BZ,HG10UN unbundlehash\n
  o> readline() -> 2:
  o>     1\n
  o> readline() -> 1:
  o>     \n
  sending listkeys command
  i> write(9) -> 9:
  i>     listkeys\n
  i> write(12) -> 12:
  i>     namespace 9\n
  i> write(9) -> 9: bookmarks
  i> flush() -> None
  o> bufferedreadline() -> 3:
  o>     93\n
  o> bufferedread(93) -> 93:
  o>     bookA\t68986213bd4485ea51533535e3fc9e78007a711f\n
  o>     bookB\t1880f3755e2e52e3199e0ee5638128b08642f34d
  response: {b'bookA': b'68986213bd4485ea51533535e3fc9e78007a711f', b'bookB': b'1880f3755e2e52e3199e0ee5638128b08642f34d'}
  
  testing ssh2
  creating ssh peer from handshake results
  i> write(171) -> 171:
  i>     upgrade * proto=exp-ssh-v2-0001\n (glob)
  i>     hello\n
  i>     between\n
  i>     pairs 81\n
  i>     0000000000000000000000000000000000000000-0000000000000000000000000000000000000000
  i> flush() -> None
  o> readline() -> 62:
  o>     upgraded * exp-ssh-v2-0001\n (glob)
  o> readline() -> 4:
  o>     412\n
  o> read(412) -> 412: capabilities: batch branchmap $USUAL_BUNDLE2_CAPS_SERVER$ changegroupsubset getbundle known lookup protocaps pushkey streamreqs=generaldelta,revlogv1 unbundle=HG10GZ,HG10BZ,HG10UN unbundlehash
  o> read(1) -> 1:
  o>     \n
  sending listkeys command
  i> write(9) -> 9:
  i>     listkeys\n
  i> write(12) -> 12:
  i>     namespace 9\n
  i> write(9) -> 9: bookmarks
  i> flush() -> None
  o> bufferedreadline() -> 3:
  o>     93\n
  o> bufferedread(93) -> 93:
  o>     bookA\t68986213bd4485ea51533535e3fc9e78007a711f\n
  o>     bookB\t1880f3755e2e52e3199e0ee5638128b08642f34d
  response: {b'bookA': b'68986213bd4485ea51533535e3fc9e78007a711f', b'bookB': b'1880f3755e2e52e3199e0ee5638128b08642f34d'}

Test pushkey for bookmarks

  $ debugwireproto << EOF
  > command pushkey
  >     namespace bookmarks
  >     key remote
  >     old
  >     new 68986213bd4485ea51533535e3fc9e78007a711f
  > EOF
  testing ssh1
  creating ssh peer from handshake results
  i> write(104) -> 104:
  i>     hello\n
  i>     between\n
  i>     pairs 81\n
  i>     0000000000000000000000000000000000000000-0000000000000000000000000000000000000000
  i> flush() -> None
  o> readline() -> 4:
  o>     413\n
  o> readline() -> 413:
  o>     capabilities: batch branchmap $USUAL_BUNDLE2_CAPS_SERVER$ changegroupsubset getbundle known lookup protocaps pushkey streamreqs=generaldelta,revlogv1 unbundle=HG10GZ,HG10BZ,HG10UN unbundlehash\n
  o> readline() -> 2:
  o>     1\n
  o> readline() -> 1:
  o>     \n
  sending pushkey command
  i> write(8) -> 8:
  i>     pushkey\n
  i> write(6) -> 6:
  i>     key 6\n
  i> write(6) -> 6: remote
  i> write(12) -> 12:
  i>     namespace 9\n
  i> write(9) -> 9: bookmarks
  i> write(7) -> 7:
  i>     new 40\n
  i> write(40) -> 40: 68986213bd4485ea51533535e3fc9e78007a711f
  i> write(6) -> 6:
  i>     old 0\n
  i> flush() -> None
  o> bufferedreadline() -> 2:
  o>     2\n
  o> bufferedread(2) -> 2:
  o>     1\n
  response: True
  
  testing ssh2
  creating ssh peer from handshake results
  i> write(171) -> 171:
  i>     upgrade * proto=exp-ssh-v2-0001\n (glob)
  i>     hello\n
  i>     between\n
  i>     pairs 81\n
  i>     0000000000000000000000000000000000000000-0000000000000000000000000000000000000000
  i> flush() -> None
  o> readline() -> 62:
  o>     upgraded * exp-ssh-v2-0001\n (glob)
  o> readline() -> 4:
  o>     412\n
  o> read(412) -> 412: capabilities: batch branchmap $USUAL_BUNDLE2_CAPS_SERVER$ changegroupsubset getbundle known lookup protocaps pushkey streamreqs=generaldelta,revlogv1 unbundle=HG10GZ,HG10BZ,HG10UN unbundlehash
  o> read(1) -> 1:
  o>     \n
  sending pushkey command
  i> write(8) -> 8:
  i>     pushkey\n
  i> write(6) -> 6:
  i>     key 6\n
  i> write(6) -> 6: remote
  i> write(12) -> 12:
  i>     namespace 9\n
  i> write(9) -> 9: bookmarks
  i> write(7) -> 7:
  i>     new 40\n
  i> write(40) -> 40: 68986213bd4485ea51533535e3fc9e78007a711f
  i> write(6) -> 6:
  i>     old 0\n
  i> flush() -> None
  o> bufferedreadline() -> 2:
  o>     2\n
  o> bufferedread(2) -> 2:
  o>     1\n
  response: True

  $ hg bookmarks
     bookA                     0:68986213bd44
     bookB                     1:1880f3755e2e
     remote                    0:68986213bd44

  $ cd ..

Test listkeys for phases

  $ hg init phasesrepo
  $ cd phasesrepo

Phases on empty repo

  $ debugwireproto << EOF
  > command listkeys
  >     namespace phases
  > EOF
  testing ssh1
  creating ssh peer from handshake results
  i> write(104) -> 104:
  i>     hello\n
  i>     between\n
  i>     pairs 81\n
  i>     0000000000000000000000000000000000000000-0000000000000000000000000000000000000000
  i> flush() -> None
  o> readline() -> 4:
  o>     413\n
  o> readline() -> 413:
  o>     capabilities: batch branchmap $USUAL_BUNDLE2_CAPS_SERVER$ changegroupsubset getbundle known lookup protocaps pushkey streamreqs=generaldelta,revlogv1 unbundle=HG10GZ,HG10BZ,HG10UN unbundlehash\n
  o> readline() -> 2:
  o>     1\n
  o> readline() -> 1:
  o>     \n
  sending listkeys command
  i> write(9) -> 9:
  i>     listkeys\n
  i> write(12) -> 12:
  i>     namespace 6\n
  i> write(6) -> 6: phases
  i> flush() -> None
  o> bufferedreadline() -> 3:
  o>     15\n
  o> bufferedread(15) -> 15: publishing\tTrue
  response: {b'publishing': b'True'}
  
  testing ssh2
  creating ssh peer from handshake results
  i> write(171) -> 171:
  i>     upgrade * proto=exp-ssh-v2-0001\n (glob)
  i>     hello\n
  i>     between\n
  i>     pairs 81\n
  i>     0000000000000000000000000000000000000000-0000000000000000000000000000000000000000
  i> flush() -> None
  o> readline() -> 62:
  o>     upgraded * exp-ssh-v2-0001\n (glob)
  o> readline() -> 4:
  o>     412\n
  o> read(412) -> 412: capabilities: batch branchmap $USUAL_BUNDLE2_CAPS_SERVER$ changegroupsubset getbundle known lookup protocaps pushkey streamreqs=generaldelta,revlogv1 unbundle=HG10GZ,HG10BZ,HG10UN unbundlehash
  o> read(1) -> 1:
  o>     \n
  sending listkeys command
  i> write(9) -> 9:
  i>     listkeys\n
  i> write(12) -> 12:
  i>     namespace 6\n
  i> write(6) -> 6: phases
  i> flush() -> None
  o> bufferedreadline() -> 3:
  o>     15\n
  o> bufferedread(15) -> 15: publishing\tTrue
  response: {b'publishing': b'True'}

Create some commits

  $ echo 0 > foo
  $ hg add foo
  $ hg -q commit -m initial
  $ hg phase --public
  $ echo 1 > foo
  $ hg commit -m 'head 1 commit 1'
  $ echo 2 > foo
  $ hg commit -m 'head 1 commit 2'
  $ hg -q up 0
  $ echo 1a > foo
  $ hg commit -m 'head 2 commit 1'
  created new head
  $ echo 2a > foo
  $ hg commit -m 'head 2 commit 2'

Two draft heads

  $ debugwireproto << EOF
  > command listkeys
  >     namespace phases
  > EOF
  testing ssh1
  creating ssh peer from handshake results
  i> write(104) -> 104:
  i>     hello\n
  i>     between\n
  i>     pairs 81\n
  i>     0000000000000000000000000000000000000000-0000000000000000000000000000000000000000
  i> flush() -> None
  o> readline() -> 4:
  o>     413\n
  o> readline() -> 413:
  o>     capabilities: batch branchmap $USUAL_BUNDLE2_CAPS_SERVER$ changegroupsubset getbundle known lookup protocaps pushkey streamreqs=generaldelta,revlogv1 unbundle=HG10GZ,HG10BZ,HG10UN unbundlehash\n
  o> readline() -> 2:
  o>     1\n
  o> readline() -> 1:
  o>     \n
  sending listkeys command
  i> write(9) -> 9:
  i>     listkeys\n
  i> write(12) -> 12:
  i>     namespace 6\n
  i> write(6) -> 6: phases
  i> flush() -> None
  o> bufferedreadline() -> 4:
  o>     101\n
  o> bufferedread(101) -> 101:
  o>     20b8a89289d80036e6c4e87c2083e3bea1586637\t1\n
  o>     c4750011d906c18ea2f0527419cbc1a544435150\t1\n
  o>     publishing\tTrue
  response: {b'20b8a89289d80036e6c4e87c2083e3bea1586637': b'1', b'c4750011d906c18ea2f0527419cbc1a544435150': b'1', b'publishing': b'True'}
  
  testing ssh2
  creating ssh peer from handshake results
  i> write(171) -> 171:
  i>     upgrade * proto=exp-ssh-v2-0001\n (glob)
  i>     hello\n
  i>     between\n
  i>     pairs 81\n
  i>     0000000000000000000000000000000000000000-0000000000000000000000000000000000000000
  i> flush() -> None
  o> readline() -> 62:
  o>     upgraded * exp-ssh-v2-0001\n (glob)
  o> readline() -> 4:
  o>     412\n
  o> read(412) -> 412: capabilities: batch branchmap $USUAL_BUNDLE2_CAPS_SERVER$ changegroupsubset getbundle known lookup protocaps pushkey streamreqs=generaldelta,revlogv1 unbundle=HG10GZ,HG10BZ,HG10UN unbundlehash
  o> read(1) -> 1:
  o>     \n
  sending listkeys command
  i> write(9) -> 9:
  i>     listkeys\n
  i> write(12) -> 12:
  i>     namespace 6\n
  i> write(6) -> 6: phases
  i> flush() -> None
  o> bufferedreadline() -> 4:
  o>     101\n
  o> bufferedread(101) -> 101:
  o>     20b8a89289d80036e6c4e87c2083e3bea1586637\t1\n
  o>     c4750011d906c18ea2f0527419cbc1a544435150\t1\n
  o>     publishing\tTrue
  response: {b'20b8a89289d80036e6c4e87c2083e3bea1586637': b'1', b'c4750011d906c18ea2f0527419cbc1a544435150': b'1', b'publishing': b'True'}

Single draft head

  $ hg phase --public -r 2
  $ debugwireproto << EOF
  > command listkeys
  >     namespace phases
  > EOF
  testing ssh1
  creating ssh peer from handshake results
  i> write(104) -> 104:
  i>     hello\n
  i>     between\n
  i>     pairs 81\n
  i>     0000000000000000000000000000000000000000-0000000000000000000000000000000000000000
  i> flush() -> None
  o> readline() -> 4:
  o>     413\n
  o> readline() -> 413:
  o>     capabilities: batch branchmap $USUAL_BUNDLE2_CAPS_SERVER$ changegroupsubset getbundle known lookup protocaps pushkey streamreqs=generaldelta,revlogv1 unbundle=HG10GZ,HG10BZ,HG10UN unbundlehash\n
  o> readline() -> 2:
  o>     1\n
  o> readline() -> 1:
  o>     \n
  sending listkeys command
  i> write(9) -> 9:
  i>     listkeys\n
  i> write(12) -> 12:
  i>     namespace 6\n
  i> write(6) -> 6: phases
  i> flush() -> None
  o> bufferedreadline() -> 3:
  o>     58\n
  o> bufferedread(58) -> 58:
  o>     c4750011d906c18ea2f0527419cbc1a544435150\t1\n
  o>     publishing\tTrue
  response: {b'c4750011d906c18ea2f0527419cbc1a544435150': b'1', b'publishing': b'True'}
  
  testing ssh2
  creating ssh peer from handshake results
  i> write(171) -> 171:
  i>     upgrade * proto=exp-ssh-v2-0001\n (glob)
  i>     hello\n
  i>     between\n
  i>     pairs 81\n
  i>     0000000000000000000000000000000000000000-0000000000000000000000000000000000000000
  i> flush() -> None
  o> readline() -> 62:
  o>     upgraded * exp-ssh-v2-0001\n (glob)
  o> readline() -> 4:
  o>     412\n
  o> read(412) -> 412: capabilities: batch branchmap $USUAL_BUNDLE2_CAPS_SERVER$ changegroupsubset getbundle known lookup protocaps pushkey streamreqs=generaldelta,revlogv1 unbundle=HG10GZ,HG10BZ,HG10UN unbundlehash
  o> read(1) -> 1:
  o>     \n
  sending listkeys command
  i> write(9) -> 9:
  i>     listkeys\n
  i> write(12) -> 12:
  i>     namespace 6\n
  i> write(6) -> 6: phases
  i> flush() -> None
  o> bufferedreadline() -> 3:
  o>     58\n
  o> bufferedread(58) -> 58:
  o>     c4750011d906c18ea2f0527419cbc1a544435150\t1\n
  o>     publishing\tTrue
  response: {b'c4750011d906c18ea2f0527419cbc1a544435150': b'1', b'publishing': b'True'}

All public heads

  $ hg phase --public -r 4
  $ debugwireproto << EOF
  > command listkeys
  >     namespace phases
  > EOF
  testing ssh1
  creating ssh peer from handshake results
  i> write(104) -> 104:
  i>     hello\n
  i>     between\n
  i>     pairs 81\n
  i>     0000000000000000000000000000000000000000-0000000000000000000000000000000000000000
  i> flush() -> None
  o> readline() -> 4:
  o>     413\n
  o> readline() -> 413:
  o>     capabilities: batch branchmap $USUAL_BUNDLE2_CAPS_SERVER$ changegroupsubset getbundle known lookup protocaps pushkey streamreqs=generaldelta,revlogv1 unbundle=HG10GZ,HG10BZ,HG10UN unbundlehash\n
  o> readline() -> 2:
  o>     1\n
  o> readline() -> 1:
  o>     \n
  sending listkeys command
  i> write(9) -> 9:
  i>     listkeys\n
  i> write(12) -> 12:
  i>     namespace 6\n
  i> write(6) -> 6: phases
  i> flush() -> None
  o> bufferedreadline() -> 3:
  o>     15\n
  o> bufferedread(15) -> 15: publishing\tTrue
  response: {b'publishing': b'True'}
  
  testing ssh2
  creating ssh peer from handshake results
  i> write(171) -> 171:
  i>     upgrade * proto=exp-ssh-v2-0001\n (glob)
  i>     hello\n
  i>     between\n
  i>     pairs 81\n
  i>     0000000000000000000000000000000000000000-0000000000000000000000000000000000000000
  i> flush() -> None
  o> readline() -> 62:
  o>     upgraded * exp-ssh-v2-0001\n (glob)
  o> readline() -> 4:
  o>     412\n
  o> read(412) -> 412: capabilities: batch branchmap $USUAL_BUNDLE2_CAPS_SERVER$ changegroupsubset getbundle known lookup protocaps pushkey streamreqs=generaldelta,revlogv1 unbundle=HG10GZ,HG10BZ,HG10UN unbundlehash
  o> read(1) -> 1:
  o>     \n
  sending listkeys command
  i> write(9) -> 9:
  i>     listkeys\n
  i> write(12) -> 12:
  i>     namespace 6\n
  i> write(6) -> 6: phases
  i> flush() -> None
  o> bufferedreadline() -> 3:
  o>     15\n
  o> bufferedread(15) -> 15: publishing\tTrue
  response: {b'publishing': b'True'}

Setting public phase via pushkey

  $ hg phase --draft --force -r .

  $ debugwireproto << EOF
  > command pushkey
  >     namespace phases
  >     key 7127240a084fd9dc86fe8d1f98e26229161ec82b
  >     old 1
  >     new 0
  > EOF
  testing ssh1
  creating ssh peer from handshake results
  i> write(104) -> 104:
  i>     hello\n
  i>     between\n
  i>     pairs 81\n
  i>     0000000000000000000000000000000000000000-0000000000000000000000000000000000000000
  i> flush() -> None
  o> readline() -> 4:
  o>     413\n
  o> readline() -> 413:
  o>     capabilities: batch branchmap $USUAL_BUNDLE2_CAPS_SERVER$ changegroupsubset getbundle known lookup protocaps pushkey streamreqs=generaldelta,revlogv1 unbundle=HG10GZ,HG10BZ,HG10UN unbundlehash\n
  o> readline() -> 2:
  o>     1\n
  o> readline() -> 1:
  o>     \n
  sending pushkey command
  i> write(8) -> 8:
  i>     pushkey\n
  i> write(7) -> 7:
  i>     key 40\n
  i> write(40) -> 40: 7127240a084fd9dc86fe8d1f98e26229161ec82b
  i> write(12) -> 12:
  i>     namespace 6\n
  i> write(6) -> 6: phases
  i> write(6) -> 6:
  i>     new 1\n
  i> write(1) -> 1: 0
  i> write(6) -> 6:
  i>     old 1\n
  i> write(1) -> 1: 1
  i> flush() -> None
  o> bufferedreadline() -> 2:
  o>     2\n
  o> bufferedread(2) -> 2:
  o>     1\n
  response: True
  
  testing ssh2
  creating ssh peer from handshake results
  i> write(171) -> 171:
  i>     upgrade * proto=exp-ssh-v2-0001\n (glob)
  i>     hello\n
  i>     between\n
  i>     pairs 81\n
  i>     0000000000000000000000000000000000000000-0000000000000000000000000000000000000000
  i> flush() -> None
  o> readline() -> 62:
  o>     upgraded * exp-ssh-v2-0001\n (glob)
  o> readline() -> 4:
  o>     412\n
  o> read(412) -> 412: capabilities: batch branchmap $USUAL_BUNDLE2_CAPS_SERVER$ changegroupsubset getbundle known lookup protocaps pushkey streamreqs=generaldelta,revlogv1 unbundle=HG10GZ,HG10BZ,HG10UN unbundlehash
  o> read(1) -> 1:
  o>     \n
  sending pushkey command
  i> write(8) -> 8:
  i>     pushkey\n
  i> write(7) -> 7:
  i>     key 40\n
  i> write(40) -> 40: 7127240a084fd9dc86fe8d1f98e26229161ec82b
  i> write(12) -> 12:
  i>     namespace 6\n
  i> write(6) -> 6: phases
  i> write(6) -> 6:
  i>     new 1\n
  i> write(1) -> 1: 0
  i> write(6) -> 6:
  i>     old 1\n
  i> write(1) -> 1: 1
  i> flush() -> None
  o> bufferedreadline() -> 2:
  o>     2\n
  o> bufferedread(2) -> 2:
  o>     1\n
  response: True

  $ hg phase .
  4: public

  $ cd ..

Test batching of requests

  $ hg init batching
  $ cd batching
  $ echo 0 > foo
  $ hg add foo
  $ hg -q commit -m initial
  $ hg phase --public
  $ echo 1 > foo
  $ hg commit -m 'commit 1'
  $ hg -q up 0
  $ echo 2 > foo
  $ hg commit -m 'commit 2'
  created new head
  $ hg book -r 1 bookA
  $ hg book -r 2 bookB

  $ debugwireproto << EOF
  > batchbegin
  > command heads
  > command listkeys
  >     namespace bookmarks
  > command listkeys
  >     namespace phases
  > batchsubmit
  > EOF
  testing ssh1
  creating ssh peer from handshake results
  i> write(104) -> 104:
  i>     hello\n
  i>     between\n
  i>     pairs 81\n
  i>     0000000000000000000000000000000000000000-0000000000000000000000000000000000000000
  i> flush() -> None
  o> readline() -> 4:
  o>     413\n
  o> readline() -> 413:
  o>     capabilities: batch branchmap $USUAL_BUNDLE2_CAPS_SERVER$ changegroupsubset getbundle known lookup protocaps pushkey streamreqs=generaldelta,revlogv1 unbundle=HG10GZ,HG10BZ,HG10UN unbundlehash\n
  o> readline() -> 2:
  o>     1\n
  o> readline() -> 1:
  o>     \n
  sending batch with 3 sub-commands
  i> write(6) -> 6:
  i>     batch\n
  i> write(4) -> 4:
  i>     * 0\n
  i> write(8) -> 8:
  i>     cmds 61\n
  i> write(61) -> 61: heads ;listkeys namespace=bookmarks;listkeys namespace=phases
  i> flush() -> None
  o> bufferedreadline() -> 4:
  o>     278\n
  o> bufferedread(278) -> 278:
  o>     bfebe6bd38eebc6f8202e419c1171268987ea6a6 4ee3fcef1c800fa2bf23e20af7c83ff111d9c7ab\n
  o>     ;bookA\t4ee3fcef1c800fa2bf23e20af7c83ff111d9c7ab\n
  o>     bookB\tbfebe6bd38eebc6f8202e419c1171268987ea6a6;4ee3fcef1c800fa2bf23e20af7c83ff111d9c7ab\t1\n
  o>     bfebe6bd38eebc6f8202e419c1171268987ea6a6\t1\n
  o>     publishing\tTrue
  response #0: bfebe6bd38eebc6f8202e419c1171268987ea6a6 4ee3fcef1c800fa2bf23e20af7c83ff111d9c7ab\n
  response #1: bookA\t4ee3fcef1c800fa2bf23e20af7c83ff111d9c7ab\nbookB\tbfebe6bd38eebc6f8202e419c1171268987ea6a6
  response #2: 4ee3fcef1c800fa2bf23e20af7c83ff111d9c7ab\t1\nbfebe6bd38eebc6f8202e419c1171268987ea6a6\t1\npublishing\tTrue
  
  testing ssh2
  creating ssh peer from handshake results
  i> write(171) -> 171:
  i>     upgrade * proto=exp-ssh-v2-0001\n (glob)
  i>     hello\n
  i>     between\n
  i>     pairs 81\n
  i>     0000000000000000000000000000000000000000-0000000000000000000000000000000000000000
  i> flush() -> None
  o> readline() -> 62:
  o>     upgraded * exp-ssh-v2-0001\n (glob)
  o> readline() -> 4:
  o>     412\n
  o> read(412) -> 412: capabilities: batch branchmap $USUAL_BUNDLE2_CAPS_SERVER$ changegroupsubset getbundle known lookup protocaps pushkey streamreqs=generaldelta,revlogv1 unbundle=HG10GZ,HG10BZ,HG10UN unbundlehash
  o> read(1) -> 1:
  o>     \n
  sending batch with 3 sub-commands
  i> write(6) -> 6:
  i>     batch\n
  i> write(4) -> 4:
  i>     * 0\n
  i> write(8) -> 8:
  i>     cmds 61\n
  i> write(61) -> 61: heads ;listkeys namespace=bookmarks;listkeys namespace=phases
  i> flush() -> None
  o> bufferedreadline() -> 4:
  o>     278\n
  o> bufferedread(278) -> 278:
  o>     bfebe6bd38eebc6f8202e419c1171268987ea6a6 4ee3fcef1c800fa2bf23e20af7c83ff111d9c7ab\n
  o>     ;bookA\t4ee3fcef1c800fa2bf23e20af7c83ff111d9c7ab\n
  o>     bookB\tbfebe6bd38eebc6f8202e419c1171268987ea6a6;4ee3fcef1c800fa2bf23e20af7c83ff111d9c7ab\t1\n
  o>     bfebe6bd38eebc6f8202e419c1171268987ea6a6\t1\n
  o>     publishing\tTrue
  response #0: bfebe6bd38eebc6f8202e419c1171268987ea6a6 4ee3fcef1c800fa2bf23e20af7c83ff111d9c7ab\n
  response #1: bookA\t4ee3fcef1c800fa2bf23e20af7c83ff111d9c7ab\nbookB\tbfebe6bd38eebc6f8202e419c1171268987ea6a6
  response #2: 4ee3fcef1c800fa2bf23e20af7c83ff111d9c7ab\t1\nbfebe6bd38eebc6f8202e419c1171268987ea6a6\t1\npublishing\tTrue
