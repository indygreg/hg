#require killdaemons

  $ cat > fakeremoteuser.py << EOF
  > import os
  > from mercurial.hgweb import hgweb_mod
  > from mercurial import wireproto
  > class testenvhgweb(hgweb_mod.hgweb):
  >     def __call__(self, env, respond):
  >         # Allow REMOTE_USER to define authenticated user.
  >         if r'REMOTE_USER' in os.environ:
  >             env[r'REMOTE_USER'] = os.environ[r'REMOTE_USER']
  >         # Allow REQUEST_METHOD to override HTTP method
  >         if r'REQUEST_METHOD' in os.environ:
  >             env[r'REQUEST_METHOD'] = os.environ[r'REQUEST_METHOD']
  >         return super(testenvhgweb, self).__call__(env, respond)
  > hgweb_mod.hgweb = testenvhgweb
  > 
  > @wireproto.wireprotocommand('customreadnoperm')
  > def customread(repo, proto):
  >     return b'read-only command no defined permissions\n'
  > @wireproto.wireprotocommand('customwritenoperm')
  > def customwritenoperm(repo, proto):
  >     return b'write command no defined permissions\n'
  > wireproto.permissions['customreadwithperm'] = 'pull'
  > @wireproto.wireprotocommand('customreadwithperm')
  > def customreadwithperm(repo, proto):
  >     return b'read-only command w/ defined permissions\n'
  > wireproto.permissions['customwritewithperm'] = 'push'
  > @wireproto.wireprotocommand('customwritewithperm')
  > def customwritewithperm(repo, proto):
  >     return b'write command w/ defined permissions\n'
  > EOF

  $ cat >> $HGRCPATH << EOF
  > [extensions]
  > fakeremoteuser = $TESTTMP/fakeremoteuser.py
  > strip =
  > EOF

  $ hg init test
  $ cd test
  $ echo a > a
  $ hg ci -Ama
  adding a
  $ cd ..
  $ hg clone test test2
  updating to branch default
  1 files updated, 0 files merged, 0 files removed, 0 files unresolved
  $ cd test2
  $ echo a >> a
  $ hg ci -mb
  $ hg book bm -r 0
  $ cd ../test

web.deny_read=* prevents access to wire protocol for all users

  $ cat > .hg/hgrc <<EOF
  > [web]
  > deny_read = *
  > EOF

  $ hg serve -p $HGPORT -d --pid-file hg.pid
  $ cat hg.pid > $DAEMON_PIDS

  $ get-with-headers.py $LOCALIP:$HGPORT '?cmd=capabilities'
  401 read not authorized
  
  0
  read not authorized
  [1]

  $ get-with-headers.py $LOCALIP:$HGPORT '?cmd=stream_out'
  401 read not authorized
  
  0
  read not authorized
  [1]

  $ get-with-headers.py $LOCALIP:$HGPORT '?cmd=listkeys' --requestheader 'x-hgarg-1=namespace=phases'
  401 read not authorized
  
  0
  read not authorized
  [1]

  $ get-with-headers.py $LOCALIP:$HGPORT '?cmd=batch' --requestheader 'x-hgarg-1=cmds=listkeys+namespace%3Dphases'
  401 read not authorized
  
  0
  read not authorized
  [1]

TODO custom commands don't check permissions

  $ get-with-headers.py $LOCALIP:$HGPORT '?cmd=customreadnoperm'
  200 Script output follows
  
  read-only command no defined permissions

  $ get-with-headers.py $LOCALIP:$HGPORT '?cmd=customreadwithperm'
  401 read not authorized
  
  0
  read not authorized
  [1]

  $ get-with-headers.py $LOCALIP:$HGPORT '?cmd=customwritenoperm'
  200 Script output follows
  
  write command no defined permissions

  $ get-with-headers.py $LOCALIP:$HGPORT '?cmd=customwritewithperm'
  401 read not authorized
  
  0
  read not authorized
  [1]

  $ hg --cwd ../test2 pull http://localhost:$HGPORT/
  pulling from http://localhost:$HGPORT/
  abort: authorization failed
  [255]

  $ killdaemons.py

web.deny_read=* with REMOTE_USER set still locks out clients

  $ REMOTE_USER=authed_user hg serve -p $HGPORT -d --pid-file hg.pid
  $ cat hg.pid > $DAEMON_PIDS

  $ get-with-headers.py $LOCALIP:$HGPORT '?cmd=capabilities'
  401 read not authorized
  
  0
  read not authorized
  [1]

  $ get-with-headers.py $LOCALIP:$HGPORT '?cmd=stream_out'
  401 read not authorized
  
  0
  read not authorized
  [1]

  $ get-with-headers.py $LOCALIP:$HGPORT '?cmd=batch' --requestheader 'x-hgarg-1=cmds=listkeys+namespace%3Dphases'
  401 read not authorized
  
  0
  read not authorized
  [1]

TODO custom commands don't check permissions

  $ get-with-headers.py $LOCALIP:$HGPORT '?cmd=customreadnoperm'
  200 Script output follows
  
  read-only command no defined permissions

  $ get-with-headers.py $LOCALIP:$HGPORT '?cmd=customreadwithperm'
  401 read not authorized
  
  0
  read not authorized
  [1]

  $ get-with-headers.py $LOCALIP:$HGPORT '?cmd=customwritenoperm'
  200 Script output follows
  
  write command no defined permissions

  $ get-with-headers.py $LOCALIP:$HGPORT '?cmd=customwritewithperm'
  401 read not authorized
  
  0
  read not authorized
  [1]

  $ hg --cwd ../test2 pull http://localhost:$HGPORT/
  pulling from http://localhost:$HGPORT/
  abort: authorization failed
  [255]

  $ killdaemons.py

web.deny_read=<user> denies access to unauthenticated user

  $ cat > .hg/hgrc <<EOF
  > [web]
  > deny_read = baduser1,baduser2
  > EOF

  $ hg serve -p $HGPORT -d --pid-file hg.pid
  $ cat hg.pid > $DAEMON_PIDS

  $ get-with-headers.py $LOCALIP:$HGPORT '?cmd=listkeys' --requestheader 'x-hgarg-1=namespace=phases'
  401 read not authorized
  
  0
  read not authorized
  [1]

  $ get-with-headers.py $LOCALIP:$HGPORT '?cmd=batch' --requestheader 'x-hgarg-1=cmds=listkeys+namespace%3Dphases'
  401 read not authorized
  
  0
  read not authorized
  [1]

TODO custom commands don't check permissions

  $ get-with-headers.py $LOCALIP:$HGPORT '?cmd=customreadnoperm'
  200 Script output follows
  
  read-only command no defined permissions

  $ get-with-headers.py $LOCALIP:$HGPORT '?cmd=customreadwithperm'
  401 read not authorized
  
  0
  read not authorized
  [1]

  $ get-with-headers.py $LOCALIP:$HGPORT '?cmd=customwritenoperm'
  200 Script output follows
  
  write command no defined permissions

  $ get-with-headers.py $LOCALIP:$HGPORT '?cmd=customwritewithperm'
  401 read not authorized
  
  0
  read not authorized
  [1]

  $ hg --cwd ../test2 pull http://localhost:$HGPORT/
  pulling from http://localhost:$HGPORT/
  abort: authorization failed
  [255]

  $ killdaemons.py

web.deny_read=<user> denies access to users in deny list

  $ REMOTE_USER=baduser2 hg serve -p $HGPORT -d --pid-file hg.pid
  $ cat hg.pid > $DAEMON_PIDS

  $ get-with-headers.py $LOCALIP:$HGPORT '?cmd=listkeys' --requestheader 'x-hgarg-1=namespace=phases'
  401 read not authorized
  
  0
  read not authorized
  [1]

  $ get-with-headers.py $LOCALIP:$HGPORT '?cmd=batch' --requestheader 'x-hgarg-1=cmds=listkeys+namespace%3Dphases'
  401 read not authorized
  
  0
  read not authorized
  [1]

TODO custom commands don't check permissions

  $ get-with-headers.py $LOCALIP:$HGPORT '?cmd=customreadnoperm'
  200 Script output follows
  
  read-only command no defined permissions

  $ get-with-headers.py $LOCALIP:$HGPORT '?cmd=customreadwithperm'
  401 read not authorized
  
  0
  read not authorized
  [1]

  $ get-with-headers.py $LOCALIP:$HGPORT '?cmd=customwritenoperm'
  200 Script output follows
  
  write command no defined permissions

  $ get-with-headers.py $LOCALIP:$HGPORT '?cmd=customwritewithperm'
  401 read not authorized
  
  0
  read not authorized
  [1]

  $ hg --cwd ../test2 pull http://localhost:$HGPORT/
  pulling from http://localhost:$HGPORT/
  abort: authorization failed
  [255]

  $ killdaemons.py

web.deny_read=<user> allows access to authenticated users not in list

  $ REMOTE_USER=gooduser hg serve -p $HGPORT -d --pid-file hg.pid
  $ cat hg.pid > $DAEMON_PIDS

  $ get-with-headers.py $LOCALIP:$HGPORT '?cmd=listkeys' --requestheader 'x-hgarg-1=namespace=phases'
  200 Script output follows
  
  cb9a9f314b8b07ba71012fcdbc544b5a4d82ff5b	1
  publishing	True (no-eol)

  $ get-with-headers.py $LOCALIP:$HGPORT '?cmd=batch' --requestheader 'x-hgarg-1=cmds=listkeys+namespace%3Dphases'
  200 Script output follows
  
  cb9a9f314b8b07ba71012fcdbc544b5a4d82ff5b	1
  publishing	True (no-eol)

  $ get-with-headers.py $LOCALIP:$HGPORT '?cmd=customreadnoperm'
  200 Script output follows
  
  read-only command no defined permissions

  $ get-with-headers.py $LOCALIP:$HGPORT '?cmd=customreadwithperm'
  200 Script output follows
  
  read-only command w/ defined permissions

TODO custom commands don't check permissions

  $ get-with-headers.py $LOCALIP:$HGPORT '?cmd=customwritenoperm'
  200 Script output follows
  
  write command no defined permissions

  $ get-with-headers.py $LOCALIP:$HGPORT '?cmd=customwritewithperm'
  405 push requires POST request
  
  0
  push requires POST request
  [1]

  $ hg --cwd ../test2 pull http://localhost:$HGPORT/
  pulling from http://localhost:$HGPORT/
  searching for changes
  no changes found

  $ killdaemons.py

web.allow_read=* allows reads for unauthenticated users

  $ cat > .hg/hgrc <<EOF
  > [web]
  > allow_read = *
  > EOF

  $ hg serve -p $HGPORT -d --pid-file hg.pid
  $ cat hg.pid > $DAEMON_PIDS

  $ get-with-headers.py $LOCALIP:$HGPORT '?cmd=listkeys' --requestheader 'x-hgarg-1=namespace=phases'
  200 Script output follows
  
  cb9a9f314b8b07ba71012fcdbc544b5a4d82ff5b	1
  publishing	True (no-eol)

  $ get-with-headers.py $LOCALIP:$HGPORT '?cmd=batch' --requestheader 'x-hgarg-1=cmds=listkeys+namespace%3Dphases'
  200 Script output follows
  
  cb9a9f314b8b07ba71012fcdbc544b5a4d82ff5b	1
  publishing	True (no-eol)

  $ get-with-headers.py $LOCALIP:$HGPORT '?cmd=customreadnoperm'
  200 Script output follows
  
  read-only command no defined permissions

  $ get-with-headers.py $LOCALIP:$HGPORT '?cmd=customreadwithperm'
  200 Script output follows
  
  read-only command w/ defined permissions

TODO custom commands don't check permissions

  $ get-with-headers.py $LOCALIP:$HGPORT '?cmd=customwritenoperm'
  200 Script output follows
  
  write command no defined permissions

  $ get-with-headers.py $LOCALIP:$HGPORT '?cmd=customwritewithperm'
  405 push requires POST request
  
  0
  push requires POST request
  [1]

  $ hg --cwd ../test2 pull http://localhost:$HGPORT/
  pulling from http://localhost:$HGPORT/
  searching for changes
  no changes found

  $ killdaemons.py

web.allow_read=* allows read for authenticated user

  $ REMOTE_USER=authed_user hg serve -p $HGPORT -d --pid-file hg.pid
  $ cat hg.pid > $DAEMON_PIDS

  $ get-with-headers.py $LOCALIP:$HGPORT '?cmd=listkeys' --requestheader 'x-hgarg-1=namespace=phases'
  200 Script output follows
  
  cb9a9f314b8b07ba71012fcdbc544b5a4d82ff5b	1
  publishing	True (no-eol)

  $ get-with-headers.py $LOCALIP:$HGPORT '?cmd=batch' --requestheader 'x-hgarg-1=cmds=listkeys+namespace%3Dphases'
  200 Script output follows
  
  cb9a9f314b8b07ba71012fcdbc544b5a4d82ff5b	1
  publishing	True (no-eol)

  $ get-with-headers.py $LOCALIP:$HGPORT '?cmd=customreadnoperm'
  200 Script output follows
  
  read-only command no defined permissions

  $ get-with-headers.py $LOCALIP:$HGPORT '?cmd=customreadwithperm'
  200 Script output follows
  
  read-only command w/ defined permissions

TODO custom commands don't check permissions

  $ get-with-headers.py $LOCALIP:$HGPORT '?cmd=customwritenoperm'
  200 Script output follows
  
  write command no defined permissions

  $ get-with-headers.py $LOCALIP:$HGPORT '?cmd=customwritewithperm'
  405 push requires POST request
  
  0
  push requires POST request
  [1]

  $ hg --cwd ../test2 pull http://localhost:$HGPORT/
  pulling from http://localhost:$HGPORT/
  searching for changes
  no changes found

  $ killdaemons.py

web.allow_read=<user> does not allow unauthenticated users to read

  $ cat > .hg/hgrc <<EOF
  > [web]
  > allow_read = gooduser
  > EOF

  $ hg serve -p $HGPORT -d --pid-file hg.pid
  $ cat hg.pid > $DAEMON_PIDS

  $ get-with-headers.py $LOCALIP:$HGPORT '?cmd=listkeys' --requestheader 'x-hgarg-1=namespace=phases'
  401 read not authorized
  
  0
  read not authorized
  [1]

  $ get-with-headers.py $LOCALIP:$HGPORT '?cmd=batch' --requestheader 'x-hgarg-1=cmds=listkeys+namespace%3Dphases'
  401 read not authorized
  
  0
  read not authorized
  [1]

TODO custom commands don't check permissions

  $ get-with-headers.py $LOCALIP:$HGPORT '?cmd=customreadnoperm'
  200 Script output follows
  
  read-only command no defined permissions

  $ get-with-headers.py $LOCALIP:$HGPORT '?cmd=customreadwithperm'
  401 read not authorized
  
  0
  read not authorized
  [1]

  $ get-with-headers.py $LOCALIP:$HGPORT '?cmd=customwritenoperm'
  200 Script output follows
  
  write command no defined permissions

  $ get-with-headers.py $LOCALIP:$HGPORT '?cmd=customwritewithperm'
  401 read not authorized
  
  0
  read not authorized
  [1]

  $ hg --cwd ../test2 pull http://localhost:$HGPORT/
  pulling from http://localhost:$HGPORT/
  abort: authorization failed
  [255]

  $ killdaemons.py

web.allow_read=<user> does not allow user not in list to read

  $ REMOTE_USER=baduser hg serve -p $HGPORT -d --pid-file hg.pid
  $ cat hg.pid > $DAEMON_PIDS

  $ get-with-headers.py $LOCALIP:$HGPORT '?cmd=listkeys' --requestheader 'x-hgarg-1=namespace=phases'
  401 read not authorized
  
  0
  read not authorized
  [1]

  $ get-with-headers.py $LOCALIP:$HGPORT '?cmd=batch' --requestheader 'x-hgarg-1=cmds=listkeys+namespace%3Dphases'
  401 read not authorized
  
  0
  read not authorized
  [1]

TODO custom commands don't check permissions

  $ get-with-headers.py $LOCALIP:$HGPORT '?cmd=customreadnoperm'
  200 Script output follows
  
  read-only command no defined permissions

  $ get-with-headers.py $LOCALIP:$HGPORT '?cmd=customreadwithperm'
  401 read not authorized
  
  0
  read not authorized
  [1]

  $ get-with-headers.py $LOCALIP:$HGPORT '?cmd=customwritenoperm'
  200 Script output follows
  
  write command no defined permissions

  $ get-with-headers.py $LOCALIP:$HGPORT '?cmd=customwritewithperm'
  401 read not authorized
  
  0
  read not authorized
  [1]

  $ hg --cwd ../test2 pull http://localhost:$HGPORT/
  pulling from http://localhost:$HGPORT/
  abort: authorization failed
  [255]

  $ killdaemons.py

web.allow_read=<user> allows read from user in list

  $ REMOTE_USER=gooduser hg serve -p $HGPORT -d --pid-file hg.pid
  $ cat hg.pid > $DAEMON_PIDS

  $ get-with-headers.py $LOCALIP:$HGPORT '?cmd=listkeys' --requestheader 'x-hgarg-1=namespace=phases'
  200 Script output follows
  
  cb9a9f314b8b07ba71012fcdbc544b5a4d82ff5b	1
  publishing	True (no-eol)

  $ get-with-headers.py $LOCALIP:$HGPORT '?cmd=batch' --requestheader 'x-hgarg-1=cmds=listkeys+namespace%3Dphases'
  200 Script output follows
  
  cb9a9f314b8b07ba71012fcdbc544b5a4d82ff5b	1
  publishing	True (no-eol)

  $ get-with-headers.py $LOCALIP:$HGPORT '?cmd=customreadnoperm'
  200 Script output follows
  
  read-only command no defined permissions

  $ get-with-headers.py $LOCALIP:$HGPORT '?cmd=customreadwithperm'
  200 Script output follows
  
  read-only command w/ defined permissions

TODO custom commands don't check permissions

  $ get-with-headers.py $LOCALIP:$HGPORT '?cmd=customwritenoperm'
  200 Script output follows
  
  write command no defined permissions

  $ get-with-headers.py $LOCALIP:$HGPORT '?cmd=customwritewithperm'
  405 push requires POST request
  
  0
  push requires POST request
  [1]

  $ hg --cwd ../test2 pull http://localhost:$HGPORT/
  pulling from http://localhost:$HGPORT/
  searching for changes
  no changes found

  $ killdaemons.py

web.deny_read takes precedence over web.allow_read

  $ cat > .hg/hgrc <<EOF
  > [web]
  > allow_read = baduser
  > deny_read = baduser
  > EOF

  $ REMOTE_USER=baduser hg serve -p $HGPORT -d --pid-file hg.pid
  $ cat hg.pid > $DAEMON_PIDS

  $ get-with-headers.py $LOCALIP:$HGPORT '?cmd=listkeys' --requestheader 'x-hgarg-1=namespace=phases'
  401 read not authorized
  
  0
  read not authorized
  [1]

  $ get-with-headers.py $LOCALIP:$HGPORT '?cmd=batch' --requestheader 'x-hgarg-1=cmds=listkeys+namespace%3Dphases'
  401 read not authorized
  
  0
  read not authorized
  [1]

TODO custom commands don't check permissions

  $ get-with-headers.py $LOCALIP:$HGPORT '?cmd=customreadnoperm'
  200 Script output follows
  
  read-only command no defined permissions

  $ get-with-headers.py $LOCALIP:$HGPORT '?cmd=customreadwithperm'
  401 read not authorized
  
  0
  read not authorized
  [1]

  $ get-with-headers.py $LOCALIP:$HGPORT '?cmd=customwritenoperm'
  200 Script output follows
  
  write command no defined permissions

  $ get-with-headers.py $LOCALIP:$HGPORT '?cmd=customwritewithperm'
  401 read not authorized
  
  0
  read not authorized
  [1]

  $ hg --cwd ../test2 pull http://localhost:$HGPORT/
  pulling from http://localhost:$HGPORT/
  abort: authorization failed
  [255]

  $ killdaemons.py

web.allow-pull=false denies read access to repo

  $ cat > .hg/hgrc <<EOF
  > [web]
  > allow-pull = false
  > EOF

  $ hg serve -p $HGPORT -d --pid-file hg.pid
  $ cat hg.pid > $DAEMON_PIDS

  $ get-with-headers.py $LOCALIP:$HGPORT '?cmd=capabilities'
  401 pull not authorized
  
  0
  pull not authorized
  [1]

  $ get-with-headers.py $LOCALIP:$HGPORT '?cmd=listkeys' --requestheader 'x-hgarg-1=namespace=phases'
  401 pull not authorized
  
  0
  pull not authorized
  [1]

  $ get-with-headers.py $LOCALIP:$HGPORT '?cmd=batch' --requestheader 'x-hgarg-1=cmds=listkeys+namespace%3Dphases'
  401 pull not authorized
  
  0
  pull not authorized
  [1]

TODO custom commands don't check permissions

  $ get-with-headers.py $LOCALIP:$HGPORT '?cmd=customreadnoperm'
  200 Script output follows
  
  read-only command no defined permissions

  $ get-with-headers.py $LOCALIP:$HGPORT '?cmd=customreadwithperm'
  401 pull not authorized
  
  0
  pull not authorized
  [1]

  $ get-with-headers.py $LOCALIP:$HGPORT '?cmd=customwritenoperm'
  200 Script output follows
  
  write command no defined permissions

  $ get-with-headers.py $LOCALIP:$HGPORT '?cmd=customwritewithperm'
  405 push requires POST request
  
  0
  push requires POST request
  [1]

  $ hg --cwd ../test2 pull http://localhost:$HGPORT/
  pulling from http://localhost:$HGPORT/
  abort: authorization failed
  [255]

  $ killdaemons.py

Attempting a write command with HTTP GET fails

  $ cat > .hg/hgrc <<EOF
  > EOF

  $ REQUEST_METHOD=GET hg serve -p $HGPORT -d --pid-file hg.pid
  $ cat hg.pid > $DAEMON_PIDS

  $ get-with-headers.py $LOCALIP:$HGPORT '?cmd=pushkey' --requestheader 'x-hgarg-1=namespace=bookmarks&key=bm&old=&new=cb9a9f314b8b07ba71012fcdbc544b5a4d82ff5b'
  405 push requires POST request
  
  0
  push requires POST request
  [1]

  $ get-with-headers.py $LOCALIP:$HGPORT '?cmd=batch' --requestheader 'x-hgarg-1=cmds=pushkey+namespace%3Dbookmarks%2Ckey%3Dbm%2Cold%3D%2Cnew%3Dcb9a9f314b8b07ba71012fcdbc544b5a4d82ff5b'
  405 push requires POST request
  
  0
  push requires POST request
  [1]

  $ hg bookmarks
  no bookmarks set
  $ hg bookmark -d bm
  abort: bookmark 'bm' does not exist
  [255]

TODO custom commands don't check permissions

  $ get-with-headers.py $LOCALIP:$HGPORT '?cmd=customwritenoperm'
  200 Script output follows
  
  write command no defined permissions

  $ get-with-headers.py $LOCALIP:$HGPORT '?cmd=customwritewithperm'
  405 push requires POST request
  
  0
  push requires POST request
  [1]

  $ killdaemons.py

Attempting a write command with an unknown HTTP verb fails

  $ REQUEST_METHOD=someverb hg serve -p $HGPORT -d --pid-file hg.pid
  $ cat hg.pid > $DAEMON_PIDS

  $ get-with-headers.py $LOCALIP:$HGPORT '?cmd=pushkey' --requestheader 'x-hgarg-1=namespace=bookmarks&key=bm&old=&new=cb9a9f314b8b07ba71012fcdbc544b5a4d82ff5b'
  405 push requires POST request
  
  0
  push requires POST request
  [1]

  $ get-with-headers.py $LOCALIP:$HGPORT '?cmd=batch' --requestheader 'x-hgarg-1=cmds=pushkey+namespace%3Dbookmarks%2Ckey%3Dbm%2Cold%3D%2Cnew%3Dcb9a9f314b8b07ba71012fcdbc544b5a4d82ff5b'
  405 push requires POST request
  
  0
  push requires POST request
  [1]

  $ hg bookmarks
  no bookmarks set
  $ hg bookmark -d bm
  abort: bookmark 'bm' does not exist
  [255]

TODO custom commands don't check permissions

  $ get-with-headers.py $LOCALIP:$HGPORT '?cmd=customwritenoperm'
  200 Script output follows
  
  write command no defined permissions

  $ get-with-headers.py $LOCALIP:$HGPORT '?cmd=customwritewithperm'
  405 push requires POST request
  
  0
  push requires POST request
  [1]

  $ killdaemons.py

Pushing on a plaintext channel is disabled by default

  $ cat > .hg/hgrc <<EOF
  > EOF

  $ REQUEST_METHOD=POST hg serve -p $HGPORT -d --pid-file hg.pid
  $ cat hg.pid > $DAEMON_PIDS

  $ get-with-headers.py $LOCALIP:$HGPORT '?cmd=pushkey' --requestheader 'x-hgarg-1=namespace=bookmarks&key=bm&old=&new=cb9a9f314b8b07ba71012fcdbc544b5a4d82ff5b'
  403 ssl required
  
  0
  ssl required
  [1]

  $ get-with-headers.py $LOCALIP:$HGPORT '?cmd=batch' --requestheader 'x-hgarg-1=cmds=pushkey+namespace%3Dbookmarks%2Ckey%3Dbm%2Cold%3D%2Cnew%3Dcb9a9f314b8b07ba71012fcdbc544b5a4d82ff5b'
  403 ssl required
  
  0
  ssl required
  [1]

  $ hg bookmarks
  no bookmarks set

TODO custom commands don't check permissions

  $ get-with-headers.py $LOCALIP:$HGPORT '?cmd=customwritenoperm'
  200 Script output follows
  
  write command no defined permissions

  $ get-with-headers.py $LOCALIP:$HGPORT '?cmd=customwritewithperm'
  403 ssl required
  
  0
  ssl required
  [1]

Reset server to remove REQUEST_METHOD hack to test hg client

  $ killdaemons.py
  $ hg serve -p $HGPORT -d --pid-file hg.pid
  $ cat hg.pid > $DAEMON_PIDS

  $ hg --cwd ../test2 push -B bm http://localhost:$HGPORT/
  pushing to http://localhost:$HGPORT/
  searching for changes
  no changes found
  abort: HTTP Error 403: ssl required
  [255]

  $ hg --cwd ../test2 push http://localhost:$HGPORT/
  pushing to http://localhost:$HGPORT/
  searching for changes
  abort: HTTP Error 403: ssl required
  [255]

  $ killdaemons.py

web.deny_push=* denies pushing to unauthenticated users

  $ cat > .hg/hgrc <<EOF
  > [web]
  > push_ssl = false
  > deny_push = *
  > EOF

  $ REQUEST_METHOD=POST hg serve -p $HGPORT -d --pid-file hg.pid
  $ cat hg.pid > $DAEMON_PIDS

  $ get-with-headers.py $LOCALIP:$HGPORT '?cmd=pushkey' --requestheader 'x-hgarg-1=namespace=bookmarks&key=bm&old=&new=cb9a9f314b8b07ba71012fcdbc544b5a4d82ff5b'
  401 push not authorized
  
  0
  push not authorized
  [1]

  $ get-with-headers.py $LOCALIP:$HGPORT '?cmd=batch' --requestheader 'x-hgarg-1=cmds=pushkey+namespace%3Dbookmarks%2Ckey%3Dbm%2Cold%3D%2Cnew%3Dcb9a9f314b8b07ba71012fcdbc544b5a4d82ff5b'
  401 push not authorized
  
  0
  push not authorized
  [1]

  $ hg bookmarks
  no bookmarks set

TODO custom commands don't check permissions

  $ get-with-headers.py $LOCALIP:$HGPORT '?cmd=customwritenoperm'
  200 Script output follows
  
  write command no defined permissions

  $ get-with-headers.py $LOCALIP:$HGPORT '?cmd=customwritewithperm'
  401 push not authorized
  
  0
  push not authorized
  [1]

Reset server to remove REQUEST_METHOD hack to test hg client

  $ killdaemons.py
  $ hg serve -p $HGPORT -d --pid-file hg.pid
  $ cat hg.pid > $DAEMON_PIDS

  $ hg --cwd ../test2 push -B bm http://localhost:$HGPORT/
  pushing to http://localhost:$HGPORT/
  searching for changes
  no changes found
  abort: authorization failed
  [255]

  $ hg --cwd ../test2 push http://localhost:$HGPORT/
  pushing to http://localhost:$HGPORT/
  searching for changes
  abort: authorization failed
  [255]

  $ killdaemons.py

web.deny_push=* denies pushing to authenticated users

  $ REMOTE_USER=someuser REQUEST_METHOD=POST hg serve -p $HGPORT -d --pid-file hg.pid
  $ cat hg.pid > $DAEMON_PIDS

  $ get-with-headers.py $LOCALIP:$HGPORT '?cmd=pushkey' --requestheader 'x-hgarg-1=namespace=bookmarks&key=bm&old=&new=cb9a9f314b8b07ba71012fcdbc544b5a4d82ff5b'
  401 push not authorized
  
  0
  push not authorized
  [1]

  $ get-with-headers.py $LOCALIP:$HGPORT '?cmd=batch' --requestheader 'x-hgarg-1=cmds=pushkey+namespace%3Dbookmarks%2Ckey%3Dbm%2Cold%3D%2Cnew%3Dcb9a9f314b8b07ba71012fcdbc544b5a4d82ff5b'
  401 push not authorized
  
  0
  push not authorized
  [1]

  $ hg bookmarks
  no bookmarks set

TODO custom commands don't check permissions

  $ get-with-headers.py $LOCALIP:$HGPORT '?cmd=customwritenoperm'
  200 Script output follows
  
  write command no defined permissions

  $ get-with-headers.py $LOCALIP:$HGPORT '?cmd=customwritewithperm'
  401 push not authorized
  
  0
  push not authorized
  [1]

Reset server to remove REQUEST_METHOD hack to test hg client

  $ killdaemons.py
  $ REMOTE_USER=someuser hg serve -p $HGPORT -d --pid-file hg.pid
  $ cat hg.pid > $DAEMON_PIDS

  $ hg --cwd ../test2 push -B bm http://localhost:$HGPORT/
  pushing to http://localhost:$HGPORT/
  searching for changes
  no changes found
  abort: authorization failed
  [255]

  $ hg --cwd ../test2 push http://localhost:$HGPORT/
  pushing to http://localhost:$HGPORT/
  searching for changes
  abort: authorization failed
  [255]

  $ killdaemons.py

web.deny_push=<user> denies pushing to user in list

  $ cat > .hg/hgrc <<EOF
  > [web]
  > push_ssl = false
  > deny_push = baduser
  > EOF

  $ REMOTE_USER=baduser REQUEST_METHOD=POST hg serve -p $HGPORT -d --pid-file hg.pid
  $ cat hg.pid > $DAEMON_PIDS

  $ get-with-headers.py $LOCALIP:$HGPORT '?cmd=pushkey' --requestheader 'x-hgarg-1=namespace=bookmarks&key=bm&old=&new=cb9a9f314b8b07ba71012fcdbc544b5a4d82ff5b'
  401 push not authorized
  
  0
  push not authorized
  [1]

  $ get-with-headers.py $LOCALIP:$HGPORT '?cmd=batch' --requestheader 'x-hgarg-1=cmds=pushkey+namespace%3Dbookmarks%2Ckey%3Dbm%2Cold%3D%2Cnew%3Dcb9a9f314b8b07ba71012fcdbc544b5a4d82ff5b'
  401 push not authorized
  
  0
  push not authorized
  [1]

  $ hg bookmarks
  no bookmarks set

TODO custom commands don't check permissions

  $ get-with-headers.py $LOCALIP:$HGPORT '?cmd=customwritenoperm'
  200 Script output follows
  
  write command no defined permissions

  $ get-with-headers.py $LOCALIP:$HGPORT '?cmd=customwritewithperm'
  401 push not authorized
  
  0
  push not authorized
  [1]

Reset server to remove REQUEST_METHOD hack to test hg client

  $ killdaemons.py
  $ REMOTE_USER=baduser hg serve -p $HGPORT -d --pid-file hg.pid
  $ cat hg.pid > $DAEMON_PIDS

  $ hg --cwd ../test2 push -B bm http://localhost:$HGPORT/
  pushing to http://localhost:$HGPORT/
  searching for changes
  no changes found
  abort: authorization failed
  [255]

  $ hg --cwd ../test2 push http://localhost:$HGPORT/
  pushing to http://localhost:$HGPORT/
  searching for changes
  abort: authorization failed
  [255]

  $ killdaemons.py

web.deny_push=<user> denies pushing to user not in list because allow-push isn't set

  $ REMOTE_USER=gooduser REQUEST_METHOD=POST hg serve -p $HGPORT -d --pid-file hg.pid
  $ cat hg.pid > $DAEMON_PIDS

  $ get-with-headers.py $LOCALIP:$HGPORT '?cmd=pushkey' --requestheader 'x-hgarg-1=namespace=bookmarks&key=bm&old=&new=cb9a9f314b8b07ba71012fcdbc544b5a4d82ff5b'
  401 push not authorized
  
  0
  push not authorized
  [1]

  $ get-with-headers.py $LOCALIP:$HGPORT '?cmd=batch' --requestheader 'x-hgarg-1=cmds=pushkey+namespace%3Dbookmarks%2Ckey%3Dbm%2Cold%3D%2Cnew%3Dcb9a9f314b8b07ba71012fcdbc544b5a4d82ff5b'
  401 push not authorized
  
  0
  push not authorized
  [1]

  $ hg bookmarks
  no bookmarks set

TODO custom commands don't check permissions

  $ get-with-headers.py $LOCALIP:$HGPORT '?cmd=customwritenoperm'
  200 Script output follows
  
  write command no defined permissions

  $ get-with-headers.py $LOCALIP:$HGPORT '?cmd=customwritewithperm'
  401 push not authorized
  
  0
  push not authorized
  [1]

Reset server to remove REQUEST_METHOD hack to test hg client

  $ killdaemons.py
  $ REMOTE_USER=gooduser hg serve -p $HGPORT -d --pid-file hg.pid
  $ cat hg.pid > $DAEMON_PIDS

  $ hg --cwd ../test2 push -B bm http://localhost:$HGPORT/
  pushing to http://localhost:$HGPORT/
  searching for changes
  no changes found
  abort: authorization failed
  [255]

  $ hg --cwd ../test2 push http://localhost:$HGPORT/
  pushing to http://localhost:$HGPORT/
  searching for changes
  abort: authorization failed
  [255]

  $ killdaemons.py

web.allow-push=* allows pushes from unauthenticated users

  $ cat > .hg/hgrc <<EOF
  > [web]
  > push_ssl = false
  > allow-push = *
  > EOF

  $ REQUEST_METHOD=POST hg serve -p $HGPORT -d --pid-file hg.pid
  $ cat hg.pid > $DAEMON_PIDS

  $ get-with-headers.py $LOCALIP:$HGPORT '?cmd=pushkey' --requestheader 'x-hgarg-1=namespace=bookmarks&key=bm&old=&new=cb9a9f314b8b07ba71012fcdbc544b5a4d82ff5b'
  200 Script output follows
  
  1

  $ hg bookmarks
     bm                        0:cb9a9f314b8b
  $ hg book -d bm

  $ get-with-headers.py $LOCALIP:$HGPORT '?cmd=customwritenoperm'
  200 Script output follows
  
  write command no defined permissions

  $ get-with-headers.py $LOCALIP:$HGPORT '?cmd=customwritewithperm'
  200 Script output follows
  
  write command w/ defined permissions

Reset server to remove REQUEST_METHOD hack to test hg client

  $ killdaemons.py
  $ hg serve -p $HGPORT -d --pid-file hg.pid
  $ cat hg.pid > $DAEMON_PIDS

  $ hg --cwd ../test2 push -B bm http://localhost:$HGPORT/
  pushing to http://localhost:$HGPORT/
  searching for changes
  no changes found
  exporting bookmark bm
  [1]

  $ hg book -d bm

  $ hg --cwd ../test2 push http://localhost:$HGPORT/
  pushing to http://localhost:$HGPORT/
  searching for changes
  remote: adding changesets
  remote: adding manifests
  remote: adding file changes
  remote: added 1 changesets with 1 changes to 1 files

  $ hg strip -r 1:
  saved backup bundle to $TESTTMP/test/.hg/strip-backup/ba677d0156c1-eea704d7-backup.hg

  $ killdaemons.py

web.allow-push=* allows pushes from authenticated users

  $ REMOTE_USER=someuser REQUEST_METHOD=POST hg serve -p $HGPORT -d --pid-file hg.pid
  $ cat hg.pid > $DAEMON_PIDS

  $ get-with-headers.py $LOCALIP:$HGPORT '?cmd=pushkey' --requestheader 'x-hgarg-1=namespace=bookmarks&key=bm&old=&new=cb9a9f314b8b07ba71012fcdbc544b5a4d82ff5b'
  200 Script output follows
  
  1

  $ hg bookmarks
     bm                        0:cb9a9f314b8b
  $ hg book -d bm

  $ get-with-headers.py $LOCALIP:$HGPORT '?cmd=customwritenoperm'
  200 Script output follows
  
  write command no defined permissions

  $ get-with-headers.py $LOCALIP:$HGPORT '?cmd=customwritewithperm'
  200 Script output follows
  
  write command w/ defined permissions

Reset server to remove REQUEST_METHOD hack to test hg client

  $ killdaemons.py
  $ REMOTE_USER=someuser hg serve -p $HGPORT -d --pid-file hg.pid
  $ cat hg.pid > $DAEMON_PIDS

  $ hg --cwd ../test2 push -B bm http://localhost:$HGPORT/
  pushing to http://localhost:$HGPORT/
  searching for changes
  no changes found
  exporting bookmark bm
  [1]

  $ hg book -d bm

  $ hg --cwd ../test2 push http://localhost:$HGPORT/
  pushing to http://localhost:$HGPORT/
  searching for changes
  remote: adding changesets
  remote: adding manifests
  remote: adding file changes
  remote: added 1 changesets with 1 changes to 1 files

  $ hg strip -r 1:
  saved backup bundle to $TESTTMP/test/.hg/strip-backup/ba677d0156c1-eea704d7-backup.hg

  $ killdaemons.py

web.allow-push=<user> denies push to user not in list

  $ cat > .hg/hgrc <<EOF
  > [web]
  > push_ssl = false
  > allow-push = gooduser
  > EOF

  $ REMOTE_USER=baduser REQUEST_METHOD=POST hg serve -p $HGPORT -d --pid-file hg.pid
  $ cat hg.pid > $DAEMON_PIDS

  $ get-with-headers.py $LOCALIP:$HGPORT '?cmd=pushkey' --requestheader 'x-hgarg-1=namespace=bookmarks&key=bm&old=&new=cb9a9f314b8b07ba71012fcdbc544b5a4d82ff5b'
  401 push not authorized
  
  0
  push not authorized
  [1]

  $ get-with-headers.py $LOCALIP:$HGPORT '?cmd=batch' --requestheader 'x-hgarg-1=cmds=pushkey+namespace%3Dbookmarks%2Ckey%3Dbm%2Cold%3D%2Cnew%3Dcb9a9f314b8b07ba71012fcdbc544b5a4d82ff5b'
  401 push not authorized
  
  0
  push not authorized
  [1]

  $ hg bookmarks
  no bookmarks set

TODO custom commands don't check permissions

  $ get-with-headers.py $LOCALIP:$HGPORT '?cmd=customwritenoperm'
  200 Script output follows
  
  write command no defined permissions

  $ get-with-headers.py $LOCALIP:$HGPORT '?cmd=customwritewithperm'
  401 push not authorized
  
  0
  push not authorized
  [1]

Reset server to remove REQUEST_METHOD hack to test hg client

  $ killdaemons.py
  $ REMOTE_USER=baduser hg serve -p $HGPORT -d --pid-file hg.pid
  $ cat hg.pid > $DAEMON_PIDS

  $ hg --cwd ../test2 push -B bm http://localhost:$HGPORT/
  pushing to http://localhost:$HGPORT/
  searching for changes
  no changes found
  abort: authorization failed
  [255]

  $ hg --cwd ../test2 push http://localhost:$HGPORT/
  pushing to http://localhost:$HGPORT/
  searching for changes
  abort: authorization failed
  [255]

  $ killdaemons.py

web.allow-push=<user> allows push from user in list

  $ REMOTE_USER=gooduser REQUEST_METHOD=POST hg serve -p $HGPORT -d --pid-file hg.pid
  $ cat hg.pid > $DAEMON_PIDS

  $ get-with-headers.py $LOCALIP:$HGPORT '?cmd=pushkey' --requestheader 'x-hgarg-1=namespace=bookmarks&key=bm&old=&new=cb9a9f314b8b07ba71012fcdbc544b5a4d82ff5b'
  200 Script output follows
  
  1

  $ hg bookmarks
     bm                        0:cb9a9f314b8b
  $ hg book -d bm

  $ get-with-headers.py $LOCALIP:$HGPORT '?cmd=batch' --requestheader 'x-hgarg-1=cmds=pushkey+namespace%3Dbookmarks%2Ckey%3Dbm%2Cold%3D%2Cnew%3Dcb9a9f314b8b07ba71012fcdbc544b5a4d82ff5b'
  200 Script output follows
  
  1

  $ hg bookmarks
     bm                        0:cb9a9f314b8b
  $ hg book -d bm

  $ get-with-headers.py $LOCALIP:$HGPORT '?cmd=customwritenoperm'
  200 Script output follows
  
  write command no defined permissions

  $ get-with-headers.py $LOCALIP:$HGPORT '?cmd=customwritewithperm'
  200 Script output follows
  
  write command w/ defined permissions

Reset server to remove REQUEST_METHOD hack to test hg client

  $ killdaemons.py
  $ REMOTE_USER=gooduser hg serve -p $HGPORT -d --pid-file hg.pid
  $ cat hg.pid > $DAEMON_PIDS

  $ hg --cwd ../test2 push -B bm http://localhost:$HGPORT/
  pushing to http://localhost:$HGPORT/
  searching for changes
  no changes found
  exporting bookmark bm
  [1]

  $ hg book -d bm

  $ hg --cwd ../test2 push http://localhost:$HGPORT/
  pushing to http://localhost:$HGPORT/
  searching for changes
  remote: adding changesets
  remote: adding manifests
  remote: adding file changes
  remote: added 1 changesets with 1 changes to 1 files

  $ hg strip -r 1:
  saved backup bundle to $TESTTMP/test/.hg/strip-backup/ba677d0156c1-eea704d7-backup.hg

  $ killdaemons.py

web.deny_push takes precedence over web.allow_push

  $ cat > .hg/hgrc <<EOF
  > [web]
  > push_ssl = false
  > allow-push = someuser
  > deny_push = someuser
  > EOF

  $ REMOTE_USER=someuser REQUEST_METHOD=POST hg serve -p $HGPORT -d --pid-file hg.pid
  $ cat hg.pid > $DAEMON_PIDS

  $ get-with-headers.py $LOCALIP:$HGPORT '?cmd=pushkey' --requestheader 'x-hgarg-1=namespace=bookmarks&key=bm&old=&new=cb9a9f314b8b07ba71012fcdbc544b5a4d82ff5b'
  401 push not authorized
  
  0
  push not authorized
  [1]

  $ get-with-headers.py $LOCALIP:$HGPORT '?cmd=batch' --requestheader 'x-hgarg-1=cmds=pushkey+namespace%3Dbookmarks%2Ckey%3Dbm%2Cold%3D%2Cnew%3Dcb9a9f314b8b07ba71012fcdbc544b5a4d82ff5b'
  401 push not authorized
  
  0
  push not authorized
  [1]

  $ hg bookmarks
  no bookmarks set

TODO custom commands don't check permissions

  $ get-with-headers.py $LOCALIP:$HGPORT '?cmd=customwritenoperm'
  200 Script output follows
  
  write command no defined permissions

  $ get-with-headers.py $LOCALIP:$HGPORT '?cmd=customwritewithperm'
  401 push not authorized
  
  0
  push not authorized
  [1]

Reset server to remove REQUEST_METHOD hack to test hg client

  $ killdaemons.py
  $ REMOTE_USER=someuser hg serve -p $HGPORT -d --pid-file hg.pid
  $ cat hg.pid > $DAEMON_PIDS

  $ hg --cwd ../test2 push -B bm http://localhost:$HGPORT/
  pushing to http://localhost:$HGPORT/
  searching for changes
  no changes found
  abort: authorization failed
  [255]

  $ hg --cwd ../test2 push http://localhost:$HGPORT/
  pushing to http://localhost:$HGPORT/
  searching for changes
  abort: authorization failed
  [255]

  $ killdaemons.py

web.allow-push has no effect if web.deny_read is set

  $ cat > .hg/hgrc <<EOF
  > [web]
  > push_ssl = false
  > allow-push = *
  > deny_read = *
  > EOF

  $ REQUEST_METHOD=POST REMOTE_USER=someuser hg serve -p $HGPORT -d --pid-file hg.pid
  $ cat hg.pid > $DAEMON_PIDS

  $ get-with-headers.py $LOCALIP:$HGPORT '?cmd=pushkey' --requestheader 'x-hgarg-1=namespace=bookmarks&key=bm&old=&new=cb9a9f314b8b07ba71012fcdbc544b5a4d82ff5b'
  401 read not authorized
  
  0
  read not authorized
  [1]

  $ get-with-headers.py $LOCALIP:$HGPORT '?cmd=batch' --requestheader 'x-hgarg-1=cmds=pushkey+namespace%3Dbookmarks%2Ckey%3Dbm%2Cold%3D%2Cnew%3Dcb9a9f314b8b07ba71012fcdbc544b5a4d82ff5b'
  401 read not authorized
  
  0
  read not authorized
  [1]

  $ hg bookmarks
  no bookmarks set

TODO custom commands don't check permissions

  $ get-with-headers.py $LOCALIP:$HGPORT '?cmd=customreadnoperm'
  200 Script output follows
  
  read-only command no defined permissions

  $ get-with-headers.py $LOCALIP:$HGPORT '?cmd=customreadwithperm'
  401 read not authorized
  
  0
  read not authorized
  [1]

  $ get-with-headers.py $LOCALIP:$HGPORT '?cmd=customwritenoperm'
  200 Script output follows
  
  write command no defined permissions

  $ get-with-headers.py $LOCALIP:$HGPORT '?cmd=customwritewithperm'
  401 read not authorized
  
  0
  read not authorized
  [1]

Reset server to remove REQUEST_METHOD hack to test hg client

  $ killdaemons.py
  $ REMOTE_USER=someuser hg serve -p $HGPORT -d --pid-file hg.pid
  $ cat hg.pid > $DAEMON_PIDS

  $ hg --cwd ../test2 push -B bm http://localhost:$HGPORT/
  pushing to http://localhost:$HGPORT/
  abort: authorization failed
  [255]

  $ hg --cwd ../test2 push http://localhost:$HGPORT/
  pushing to http://localhost:$HGPORT/
  abort: authorization failed
  [255]

  $ killdaemons.py
