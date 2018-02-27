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
  $ cd ..

Test a normal behaving server, for sanity

  $ hg --debug debugpeer ssh://user@dummy/server
  running * "*/tests/dummyssh" 'user@dummy' 'hg -R server serve --stdio' (glob) (no-windows !)
  running * "*\tests/dummyssh" "user@dummy" "hg -R server serve --stdio" (glob) (windows !)
  devel-peer-request: hello
  sending hello command
  devel-peer-request: between
  devel-peer-request:   pairs: 81 bytes
  sending between command
  remote: 384
  remote: capabilities: lookup changegroupsubset branchmap pushkey known getbundle unbundlehash batch streamreqs=generaldelta,revlogv1 $USUAL_BUNDLE2_CAPS_SERVER$ unbundle=HG10GZ,HG10BZ,HG10UN
  remote: 1
  url: ssh://user@dummy/server
  local: no
  pushable: yes

Server should answer the "hello" command in isolation

  $ hg -R server serve --stdio << EOF
  > hello
  > EOF
  384
  capabilities: lookup changegroupsubset branchmap pushkey known getbundle unbundlehash batch streamreqs=generaldelta,revlogv1 $USUAL_BUNDLE2_CAPS_SERVER$ unbundle=HG10GZ,HG10BZ,HG10UN

`hg debugserve --sshstdio` works

  $ cd server
  $ hg debugserve --sshstdio << EOF
  > hello
  > EOF
  384
  capabilities: lookup changegroupsubset branchmap pushkey known getbundle unbundlehash batch streamreqs=generaldelta,revlogv1 $USUAL_BUNDLE2_CAPS_SERVER$ unbundle=HG10GZ,HG10BZ,HG10UN

I/O logging works

  $ hg debugserve --sshstdio --logiofd 1 << EOF
  > hello
  > EOF
  o> write(4) -> None:
  o>     384\n
  o> write(384) -> None:
  o>     capabilities: lookup changegroupsubset branchmap pushkey known getbundle unbundlehash batch streamreqs=generaldelta,revlogv1 $USUAL_BUNDLE2_CAPS_SERVER$ unbundle=HG10GZ,HG10BZ,HG10UN\n
  384
  capabilities: lookup changegroupsubset branchmap pushkey known getbundle unbundlehash batch streamreqs=generaldelta,revlogv1 $USUAL_BUNDLE2_CAPS_SERVER$ unbundle=HG10GZ,HG10BZ,HG10UN
  o> flush() -> None

  $ hg debugserve --sshstdio --logiofile $TESTTMP/io << EOF
  > hello
  > EOF
  384
  capabilities: lookup changegroupsubset branchmap pushkey known getbundle unbundlehash batch streamreqs=generaldelta,revlogv1 $USUAL_BUNDLE2_CAPS_SERVER$ unbundle=HG10GZ,HG10BZ,HG10UN

  $ cat $TESTTMP/io
  o> write(4) -> None:
  o>     384\n
  o> write(384) -> None:
  o>     capabilities: lookup changegroupsubset branchmap pushkey known getbundle unbundlehash batch streamreqs=generaldelta,revlogv1 $USUAL_BUNDLE2_CAPS_SERVER$ unbundle=HG10GZ,HG10BZ,HG10UN\n
  o> flush() -> None

  $ cd ..

>=0.9.1 clients send a "hello" + "between" for the null range as part of handshake.
Server should reply with capabilities and should send "1\n\n" as a successful
reply with empty response to the "between".

  $ hg -R server serve --stdio << EOF
  > hello
  > between
  > pairs 81
  > 0000000000000000000000000000000000000000-0000000000000000000000000000000000000000
  > EOF
  384
  capabilities: lookup changegroupsubset branchmap pushkey known getbundle unbundlehash batch streamreqs=generaldelta,revlogv1 $USUAL_BUNDLE2_CAPS_SERVER$ unbundle=HG10GZ,HG10BZ,HG10UN
  1
  

SSH banner is not printed by default, ignored by clients

  $ SSHSERVERMODE=banner hg debugpeer ssh://user@dummy/server
  url: ssh://user@dummy/server
  local: no
  pushable: yes

--debug will print the banner

  $ SSHSERVERMODE=banner hg --debug debugpeer ssh://user@dummy/server
  running * "*/tests/dummyssh" 'user@dummy' 'hg -R server serve --stdio' (glob) (no-windows !)
  running * "*\tests/dummyssh" "user@dummy" "hg -R server serve --stdio" (glob) (windows !)
  devel-peer-request: hello
  sending hello command
  devel-peer-request: between
  devel-peer-request:   pairs: 81 bytes
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
  remote: 384
  remote: capabilities: lookup changegroupsubset branchmap pushkey known getbundle unbundlehash batch streamreqs=generaldelta,revlogv1 $USUAL_BUNDLE2_CAPS_SERVER$ unbundle=HG10GZ,HG10BZ,HG10UN
  remote: 1
  url: ssh://user@dummy/server
  local: no
  pushable: yes

And test the banner with the raw protocol

  $ SSHSERVERMODE=banner hg -R server serve --stdio << EOF
  > hello
  > between
  > pairs 81
  > 0000000000000000000000000000000000000000-0000000000000000000000000000000000000000
  > EOF
  banner: line 0
  banner: line 1
  banner: line 2
  banner: line 3
  banner: line 4
  banner: line 5
  banner: line 6
  banner: line 7
  banner: line 8
  banner: line 9
  384
  capabilities: lookup changegroupsubset branchmap pushkey known getbundle unbundlehash batch streamreqs=generaldelta,revlogv1 $USUAL_BUNDLE2_CAPS_SERVER$ unbundle=HG10GZ,HG10BZ,HG10UN
  1
  

Connecting to a <0.9.1 server that doesn't support the hello command.
The client should refuse, as we dropped support for connecting to such
servers.

  $ SSHSERVERMODE=no-hello hg --debug debugpeer ssh://user@dummy/server
  running * "*/tests/dummyssh" 'user@dummy' 'hg -R server serve --stdio' (glob) (no-windows !)
  running * "*\tests/dummyssh" "user@dummy" "hg -R server serve --stdio" (glob) (windows !)
  devel-peer-request: hello
  sending hello command
  devel-peer-request: between
  devel-peer-request:   pairs: 81 bytes
  sending between command
  remote: 0
  remote: 1
  abort: no suitable response from remote hg!
  [255]

Sending an unknown command to the server results in an empty response to that command

  $ hg -R server serve --stdio << EOF
  > pre-hello
  > hello
  > between
  > pairs 81
  > 0000000000000000000000000000000000000000-0000000000000000000000000000000000000000
  > EOF
  0
  384
  capabilities: lookup changegroupsubset branchmap pushkey known getbundle unbundlehash batch streamreqs=generaldelta,revlogv1 $USUAL_BUNDLE2_CAPS_SERVER$ unbundle=HG10GZ,HG10BZ,HG10UN
  1
  

  $ hg --config sshpeer.mode=extra-handshake-commands --config sshpeer.handshake-mode=pre-no-args --debug debugpeer ssh://user@dummy/server
  running * "*/tests/dummyssh" 'user@dummy' 'hg -R server serve --stdio' (glob) (no-windows !)
  running * "*\tests/dummyssh" "user@dummy" "hg -R server serve --stdio" (glob) (windows !)
  sending no-args command
  devel-peer-request: hello
  sending hello command
  devel-peer-request: between
  devel-peer-request:   pairs: 81 bytes
  sending between command
  remote: 0
  remote: 384
  remote: capabilities: lookup changegroupsubset branchmap pushkey known getbundle unbundlehash batch streamreqs=generaldelta,revlogv1 $USUAL_BUNDLE2_CAPS_SERVER$ unbundle=HG10GZ,HG10BZ,HG10UN
  remote: 1
  url: ssh://user@dummy/server
  local: no
  pushable: yes

Send multiple unknown commands before hello

  $ hg -R server serve --stdio << EOF
  > unknown1
  > unknown2
  > unknown3
  > hello
  > between
  > pairs 81
  > 0000000000000000000000000000000000000000-0000000000000000000000000000000000000000
  > EOF
  0
  0
  0
  384
  capabilities: lookup changegroupsubset branchmap pushkey known getbundle unbundlehash batch streamreqs=generaldelta,revlogv1 $USUAL_BUNDLE2_CAPS_SERVER$ unbundle=HG10GZ,HG10BZ,HG10UN
  1
  

  $ hg --config sshpeer.mode=extra-handshake-commands --config sshpeer.handshake-mode=pre-multiple-no-args --debug debugpeer ssh://user@dummy/server
  running * "*/tests/dummyssh" 'user@dummy' 'hg -R server serve --stdio' (glob) (no-windows !)
  running * "*\tests/dummyssh" "user@dummy" "hg -R server serve --stdio" (glob) (windows !)
  sending unknown1 command
  sending unknown2 command
  sending unknown3 command
  devel-peer-request: hello
  sending hello command
  devel-peer-request: between
  devel-peer-request:   pairs: 81 bytes
  sending between command
  remote: 0
  remote: 0
  remote: 0
  remote: 384
  remote: capabilities: lookup changegroupsubset branchmap pushkey known getbundle unbundlehash batch streamreqs=generaldelta,revlogv1 $USUAL_BUNDLE2_CAPS_SERVER$ unbundle=HG10GZ,HG10BZ,HG10UN
  remote: 1
  url: ssh://user@dummy/server
  local: no
  pushable: yes

Send an unknown command before hello that has arguments

  $ hg -R server serve --stdio << EOF
  > with-args
  > foo 13
  > value for foo
  > bar 13
  > value for bar
  > hello
  > between
  > pairs 81
  > 0000000000000000000000000000000000000000-0000000000000000000000000000000000000000
  > EOF
  0
  0
  0
  0
  0
  384
  capabilities: lookup changegroupsubset branchmap pushkey known getbundle unbundlehash batch streamreqs=generaldelta,revlogv1 $USUAL_BUNDLE2_CAPS_SERVER$ unbundle=HG10GZ,HG10BZ,HG10UN
  1
  

Send an unknown command having an argument that looks numeric

  $ hg -R server serve --stdio << EOF
  > unknown
  > foo 1
  > 0
  > hello
  > between
  > pairs 81
  > 0000000000000000000000000000000000000000-0000000000000000000000000000000000000000
  > EOF
  0
  0
  0
  384
  capabilities: lookup changegroupsubset branchmap pushkey known getbundle unbundlehash batch streamreqs=generaldelta,revlogv1 $USUAL_BUNDLE2_CAPS_SERVER$ unbundle=HG10GZ,HG10BZ,HG10UN
  1
  

  $ hg -R server serve --stdio << EOF
  > unknown
  > foo 1
  > 1
  > hello
  > between
  > pairs 81
  > 0000000000000000000000000000000000000000-0000000000000000000000000000000000000000
  > EOF
  0
  0
  0
  384
  capabilities: lookup changegroupsubset branchmap pushkey known getbundle unbundlehash batch streamreqs=generaldelta,revlogv1 $USUAL_BUNDLE2_CAPS_SERVER$ unbundle=HG10GZ,HG10BZ,HG10UN
  1
  

When sending a dict argument value, it is serialized to
"<arg> <item count>" followed by "<key> <len>\n<value>" for each item
in the dict.

Dictionary value for unknown command

  $ hg -R server serve --stdio << EOF
  > unknown
  > dict 3
  > key1 3
  > foo
  > key2 3
  > bar
  > key3 3
  > baz
  > hello
  > EOF
  0
  0
  0
  0
  0
  0
  0
  0
  384
  capabilities: lookup changegroupsubset branchmap pushkey known getbundle unbundlehash batch streamreqs=generaldelta,revlogv1 $USUAL_BUNDLE2_CAPS_SERVER$ unbundle=HG10GZ,HG10BZ,HG10UN

Incomplete dictionary send

  $ hg -R server serve --stdio << EOF
  > unknown
  > dict 3
  > key1 3
  > foo
  > EOF
  0
  0
  0
  0

Incomplete value send

  $ hg -R server serve --stdio << EOF
  > unknown
  > dict 3
  > key1 3
  > fo
  > EOF
  0
  0
  0
  0

Send a command line with spaces

  $ hg -R server serve --stdio << EOF
  > unknown withspace
  > hello
  > between
  > pairs 81
  > 0000000000000000000000000000000000000000-0000000000000000000000000000000000000000
  > EOF
  0
  384
  capabilities: lookup changegroupsubset branchmap pushkey known getbundle unbundlehash batch streamreqs=generaldelta,revlogv1 $USUAL_BUNDLE2_CAPS_SERVER$ unbundle=HG10GZ,HG10BZ,HG10UN
  1
  

  $ hg -R server serve --stdio << EOF
  > unknown with multiple spaces
  > hello
  > between
  > pairs 81
  > 0000000000000000000000000000000000000000-0000000000000000000000000000000000000000
  > EOF
  0
  384
  capabilities: lookup changegroupsubset branchmap pushkey known getbundle unbundlehash batch streamreqs=generaldelta,revlogv1 $USUAL_BUNDLE2_CAPS_SERVER$ unbundle=HG10GZ,HG10BZ,HG10UN
  1
  

  $ hg -R server serve --stdio << EOF
  > unknown with spaces
  > key 10
  > some value
  > hello
  > between
  > pairs 81
  > 0000000000000000000000000000000000000000-0000000000000000000000000000000000000000
  > EOF
  0
  0
  0
  384
  capabilities: lookup changegroupsubset branchmap pushkey known getbundle unbundlehash batch streamreqs=generaldelta,revlogv1 $USUAL_BUNDLE2_CAPS_SERVER$ unbundle=HG10GZ,HG10BZ,HG10UN
  1
  

Send an unknown command after the "between"

  $ hg -R server serve --stdio << EOF
  > hello
  > between
  > pairs 81
  > 0000000000000000000000000000000000000000-0000000000000000000000000000000000000000unknown
  > EOF
  384
  capabilities: lookup changegroupsubset branchmap pushkey known getbundle unbundlehash batch streamreqs=generaldelta,revlogv1 $USUAL_BUNDLE2_CAPS_SERVER$ unbundle=HG10GZ,HG10BZ,HG10UN
  1
  
  0

And one with arguments

  $ hg -R server serve --stdio << EOF
  > hello
  > between
  > pairs 81
  > 0000000000000000000000000000000000000000-0000000000000000000000000000000000000000unknown
  > foo 5
  > value
  > bar 3
  > baz
  > EOF
  384
  capabilities: lookup changegroupsubset branchmap pushkey known getbundle unbundlehash batch streamreqs=generaldelta,revlogv1 $USUAL_BUNDLE2_CAPS_SERVER$ unbundle=HG10GZ,HG10BZ,HG10UN
  1
  
  0
  0
  0
  0
  0

Send a valid command before the handshake

  $ hg -R server serve --stdio << EOF
  > heads
  > hello
  > between
  > pairs 81
  > 0000000000000000000000000000000000000000-0000000000000000000000000000000000000000
  > EOF
  41
  68986213bd4485ea51533535e3fc9e78007a711f
  384
  capabilities: lookup changegroupsubset branchmap pushkey known getbundle unbundlehash batch streamreqs=generaldelta,revlogv1 $USUAL_BUNDLE2_CAPS_SERVER$ unbundle=HG10GZ,HG10BZ,HG10UN
  1
  

And a variation that doesn't send the between command

  $ hg -R server serve --stdio << EOF
  > heads
  > hello
  > EOF
  41
  68986213bd4485ea51533535e3fc9e78007a711f
  384
  capabilities: lookup changegroupsubset branchmap pushkey known getbundle unbundlehash batch streamreqs=generaldelta,revlogv1 $USUAL_BUNDLE2_CAPS_SERVER$ unbundle=HG10GZ,HG10BZ,HG10UN

Send an upgrade request to a server that doesn't support that command

  $ hg -R server serve --stdio << EOF
  > upgrade 2e82ab3f-9ce3-4b4e-8f8c-6fd1c0e9e23a proto=irrelevant1%2Cirrelevant2
  > hello
  > between
  > pairs 81
  > 0000000000000000000000000000000000000000-0000000000000000000000000000000000000000
  > EOF
  0
  384
  capabilities: lookup changegroupsubset branchmap pushkey known getbundle unbundlehash batch streamreqs=generaldelta,revlogv1 $USUAL_BUNDLE2_CAPS_SERVER$ unbundle=HG10GZ,HG10BZ,HG10UN
  1
  

  $ hg --config experimental.sshpeer.advertise-v2=true --debug debugpeer ssh://user@dummy/server
  running * "*/tests/dummyssh" 'user@dummy' 'hg -R server serve --stdio' (glob) (no-windows !)
  running * "*\tests/dummyssh" "user@dummy" "hg -R server serve --stdio" (glob) (windows !)
  sending upgrade request: * proto=exp-ssh-v2-0001 (glob)
  devel-peer-request: hello
  sending hello command
  devel-peer-request: between
  devel-peer-request:   pairs: 81 bytes
  sending between command
  remote: 0
  remote: 384
  remote: capabilities: lookup changegroupsubset branchmap pushkey known getbundle unbundlehash batch streamreqs=generaldelta,revlogv1 $USUAL_BUNDLE2_CAPS_SERVER$ unbundle=HG10GZ,HG10BZ,HG10UN
  remote: 1
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

  >>> with open('payload', 'wb') as fh:
  ...     fh.write(b'upgrade this-is-some-token proto=exp-ssh-v2-0001\n')
  ...     fh.write(b'hello\n')
  ...     fh.write(b'between\n')
  ...     fh.write(b'pairs 81\n')
  ...     fh.write(b'0000000000000000000000000000000000000000-0000000000000000000000000000000000000000')

  $ hg -R server serve --stdio < payload
  upgraded this-is-some-token exp-ssh-v2-0001
  383
  capabilities: lookup changegroupsubset branchmap pushkey known getbundle unbundlehash batch streamreqs=generaldelta,revlogv1 $USUAL_BUNDLE2_CAPS_SERVER$ unbundle=HG10GZ,HG10BZ,HG10UN

  $ hg --config experimental.sshpeer.advertise-v2=true --debug debugpeer ssh://user@dummy/server
  running * "*/tests/dummyssh" 'user@dummy' 'hg -R server serve --stdio' (glob) (no-windows !)
  running * "*\tests/dummyssh" "user@dummy" "hg -R server serve --stdio" (glob) (windows !)
  sending upgrade request: * proto=exp-ssh-v2-0001 (glob)
  devel-peer-request: hello
  sending hello command
  devel-peer-request: between
  devel-peer-request:   pairs: 81 bytes
  sending between command
  protocol upgraded to exp-ssh-v2-0001
  remote: capabilities: lookup changegroupsubset branchmap pushkey known getbundle unbundlehash batch streamreqs=generaldelta,revlogv1 $USUAL_BUNDLE2_CAPS_SERVER$ unbundle=HG10GZ,HG10BZ,HG10UN
  url: ssh://user@dummy/server
  local: no
  pushable: yes

Verify the peer has capabilities

  $ hg --config experimental.sshpeer.advertise-v2=true --debug debugcapabilities ssh://user@dummy/server
  running * "*/tests/dummyssh" 'user@dummy' 'hg -R server serve --stdio' (glob) (no-windows !)
  running * "*\tests/dummyssh" "user@dummy" "hg -R server serve --stdio" (glob) (windows !)
  sending upgrade request: * proto=exp-ssh-v2-0001 (glob)
  devel-peer-request: hello
  sending hello command
  devel-peer-request: between
  devel-peer-request:   pairs: 81 bytes
  sending between command
  protocol upgraded to exp-ssh-v2-0001
  remote: capabilities: lookup changegroupsubset branchmap pushkey known getbundle unbundlehash batch streamreqs=generaldelta,revlogv1 $USUAL_BUNDLE2_CAPS_SERVER$ unbundle=HG10GZ,HG10BZ,HG10UN
  Main capabilities:
    batch
    branchmap
    $USUAL_BUNDLE2_CAPS_SERVER$
    changegroupsubset
    getbundle
    known
    lookup
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

Command after upgrade to version 2 is processed

  >>> with open('payload', 'wb') as fh:
  ...     fh.write(b'upgrade this-is-some-token proto=exp-ssh-v2-0001\n')
  ...     fh.write(b'hello\n')
  ...     fh.write(b'between\n')
  ...     fh.write(b'pairs 81\n')
  ...     fh.write(b'0000000000000000000000000000000000000000-0000000000000000000000000000000000000000')
  ...     fh.write(b'hello\n')
  $ hg -R server serve --stdio < payload
  upgraded this-is-some-token exp-ssh-v2-0001
  383
  capabilities: lookup changegroupsubset branchmap pushkey known getbundle unbundlehash batch streamreqs=generaldelta,revlogv1 $USUAL_BUNDLE2_CAPS_SERVER$ unbundle=HG10GZ,HG10BZ,HG10UN
  384
  capabilities: lookup changegroupsubset branchmap pushkey known getbundle unbundlehash batch streamreqs=generaldelta,revlogv1 $USUAL_BUNDLE2_CAPS_SERVER$ unbundle=HG10GZ,HG10BZ,HG10UN

Multiple upgrades is not allowed

  >>> with open('payload', 'wb') as fh:
  ...     fh.write(b'upgrade this-is-some-token proto=exp-ssh-v2-0001\n')
  ...     fh.write(b'hello\n')
  ...     fh.write(b'between\n')
  ...     fh.write(b'pairs 81\n')
  ...     fh.write(b'0000000000000000000000000000000000000000-0000000000000000000000000000000000000000')
  ...     fh.write(b'upgrade another-token proto=irrelevant\n')
  ...     fh.write(b'hello\n')
  $ hg -R server serve --stdio < payload
  upgraded this-is-some-token exp-ssh-v2-0001
  383
  capabilities: lookup changegroupsubset branchmap pushkey known getbundle unbundlehash batch streamreqs=generaldelta,revlogv1 $USUAL_BUNDLE2_CAPS_SERVER$ unbundle=HG10GZ,HG10BZ,HG10UN
  cannot upgrade protocols multiple times
  -
  

Malformed upgrade request line (not exactly 3 space delimited tokens)

  $ hg -R server serve --stdio << EOF
  > upgrade
  > EOF
  0

  $ hg -R server serve --stdio << EOF
  > upgrade token
  > EOF
  0

  $ hg -R server serve --stdio << EOF
  > upgrade token foo=bar extra-token
  > EOF
  0

Upgrade request to unsupported protocol is ignored

  $ hg -R server serve --stdio << EOF
  > upgrade this-is-some-token proto=unknown1,unknown2
  > hello
  > between
  > pairs 81
  > 0000000000000000000000000000000000000000-0000000000000000000000000000000000000000
  > EOF
  0
  384
  capabilities: lookup changegroupsubset branchmap pushkey known getbundle unbundlehash batch streamreqs=generaldelta,revlogv1 $USUAL_BUNDLE2_CAPS_SERVER$ unbundle=HG10GZ,HG10BZ,HG10UN
  1
  

Upgrade request must be followed by hello + between

  $ hg -R server serve --stdio << EOF
  > upgrade token proto=exp-ssh-v2-0001
  > invalid
  > EOF
  malformed handshake protocol: missing hello
  -
  

  $ hg -R server serve --stdio << EOF
  > upgrade token proto=exp-ssh-v2-0001
  > hello
  > invalid
  > EOF
  malformed handshake protocol: missing between
  -
  

  $ hg -R server serve --stdio << EOF
  > upgrade token proto=exp-ssh-v2-0001
  > hello
  > between
  > invalid
  > EOF
  malformed handshake protocol: missing pairs 81
  -
  
