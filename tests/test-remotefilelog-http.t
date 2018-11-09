  $ PYTHONPATH=$TESTDIR/..:$PYTHONPATH
  $ export PYTHONPATH

  $ . "$TESTDIR/remotefilelog-library.sh"

  $ hg init master
  $ cd master
  $ cat >> .hg/hgrc <<EOF
  > [remotefilelog]
  > server=True
  > EOF
  $ echo x > x
  $ echo y > y
  $ hg commit -qAm x
  $ hg serve -p $HGPORT -d --pid-file=../hg1.pid -E ../error.log -A ../access.log

Build a query string for later use:
  $ GET=`hg debugdata -m 0 | $PYTHON -c \
  > 'import sys ; print [("?cmd=x_rfl_getfile&file=%s&node=%s" % tuple(s.split("\0"))) for s in sys.stdin.read().splitlines()][0]'`

  $ cd ..
  $ cat hg1.pid >> $DAEMON_PIDS

  $ hgcloneshallow http://localhost:$HGPORT/ shallow -q
  2 files fetched over 1 fetches - (2 misses, 0.00% hit ratio) over *s (glob)

  $ grep getfile access.log
  * "GET /?cmd=batch HTTP/1.1" 200 - x-hgarg-1:cmds=x_rfl_getfile+*node%3D1406e74118627694268417491f018a4a883152f0* (glob)

Clear filenode cache so we can test fetching with a modified batch size
  $ rm -r $TESTTMP/hgcache
Now do a fetch with a large batch size so we're sure it works
  $ hgcloneshallow http://localhost:$HGPORT/ shallow-large-batch \
  >    --config remotefilelog.batchsize=1000 -q
  2 files fetched over 1 fetches - (2 misses, 0.00% hit ratio) over *s (glob)

The 'remotefilelog' capability should *not* be exported over http(s),
as the getfile method it offers doesn't work with http.
  $ get-with-headers.py localhost:$HGPORT '?cmd=capabilities' | grep lookup | identifyrflcaps
  x_rfl_getfile
  x_rfl_getflogheads

  $ get-with-headers.py localhost:$HGPORT '?cmd=hello' | grep lookup | identifyrflcaps
  x_rfl_getfile
  x_rfl_getflogheads

  $ get-with-headers.py localhost:$HGPORT '?cmd=this-command-does-not-exist' | head -n 1
  400 no such method: this-command-does-not-exist
  $ get-with-headers.py localhost:$HGPORT '?cmd=x_rfl_getfiles' | head -n 1
  400 no such method: x_rfl_getfiles

Verify serving from a shallow clone doesn't allow for remotefile
fetches. This also serves to test the error handling for our batchable
getfile RPC.

  $ cd shallow
  $ hg serve -p $HGPORT1 -d --pid-file=../hg2.pid -E ../error2.log
  $ cd ..
  $ cat hg2.pid >> $DAEMON_PIDS

This GET should work, because this server is serving master, which is
a full clone.

  $ get-with-headers.py localhost:$HGPORT "$GET"
  200 Script output follows
  
  0\x00x\x9c3b\xa8\xe0\x12a{\xee(\x91T6E\xadE\xdcS\x9e\xb1\xcb\xab\xc30\xe8\x03\x03\x91 \xe4\xc6\xfb\x99J,\x17\x0c\x9f-\xcb\xfcR7c\xf3c\x97r\xbb\x10\x06\x00\x96m\x121 (no-eol) (esc)

This GET should fail using the in-band signalling mechanism, because
it's not a full clone. Note that it's also plausible for servers to
refuse to serve file contents for other reasons, like the file
contents not being visible to the current user.

  $ get-with-headers.py localhost:$HGPORT1 "$GET"
  200 Script output follows
  
  1\x00cannot fetch remote files from shallow repo (no-eol) (esc)

Clones should work with httppostargs turned on

  $ cd master
  $ hg --config experimental.httppostargs=1 serve -p $HGPORT2 -d --pid-file=../hg3.pid -E ../error3.log

  $ cd ..
  $ cat hg3.pid >> $DAEMON_PIDS

Clear filenode cache so we can test fetching with a modified batch size
  $ rm -r $TESTTMP/hgcache

  $ hgcloneshallow http://localhost:$HGPORT2/ shallow-postargs -q
  2 files fetched over 1 fetches - (2 misses, 0.00% hit ratio) over *s (glob)

All error logs should be empty:
  $ cat error.log
  $ cat error2.log
  $ cat error3.log
