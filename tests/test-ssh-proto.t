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
  running * "*/tests/dummyssh" 'user@dummy' 'hg -R server serve --stdio' (glob)
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
  running * "*/tests/dummyssh" 'user@dummy' 'hg -R server serve --stdio' (glob)
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
  

Connecting to a <0.9.1 server that doesn't support the hello command

  $ SSHSERVERMODE=no-hello hg --debug debugpeer ssh://user@dummy/server
  running * "*/tests/dummyssh" 'user@dummy' 'hg -R server serve --stdio' (glob)
  devel-peer-request: hello
  sending hello command
  devel-peer-request: between
  devel-peer-request:   pairs: 81 bytes
  sending between command
  remote: 0
  remote: 1
  url: ssh://user@dummy/server
  local: no
  pushable: yes

The client should interpret this as no capabilities

  $ SSHSERVERMODE=no-hello hg debugcapabilities ssh://user@dummy/server
  Main capabilities:

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
  running * "*/tests/dummyssh" 'user@dummy' 'hg -R server serve --stdio' (glob)
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
  running * "*/tests/dummyssh" 'user@dummy' 'hg -R server serve --stdio' (glob)
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
