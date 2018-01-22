#require serve

  $ hg init server
  $ hg serve -R server -p $HGPORT -d --pid-file=hg1.pid -E ../error.log
  $ cat hg1.pid >> $DAEMON_PIDS

Check basic fetching

  $ hg debugdownload "http://localhost:$HGPORT/?cmd=lookup&key=tip"
  1 0000000000000000000000000000000000000000
  $ hg debugdownload  -o null.txt "http://localhost:$HGPORT/?cmd=lookup&key=null"
  $ cat null.txt
  1 0000000000000000000000000000000000000000

Check the request is made from the usual Mercurial logic
(rev details, give different content if the request has a Mercurial user agent)

  $ get-with-headers.py --headeronly "localhost:$HGPORT" "rev/tip" content-type
  200 Script output follows
  content-type: text/html; charset=ascii
  $ hg debugdownload "http://localhost:$HGPORT/rev/tip"
  
  # HG changeset patch
  # User 
  # Date 0 0
  # Node ID 0000000000000000000000000000000000000000
  
  
  
  

Check other kind of compatible url

  $ hg debugdownload ./null.txt
  1 0000000000000000000000000000000000000000

Test largefile URL
------------------

  $ cat << EOF >> $HGRCPATH
  > [extensions]
  > largefiles=
  > EOF

  $ killdaemons.py
  $ rm -f error.log hg1.pid
  $ hg serve -R server -p $HGPORT -d --pid-file=hg1.pid -E error.log
  $ cat hg1.pid >> $DAEMON_PIDS

  $ hg -R server debuglfput null.txt
  a57b57b39ee4dc3da1e03526596007f480ecdbe8

  $ hg --traceback debugdownload "largefile://a57b57b39ee4dc3da1e03526596007f480ecdbe8" --config paths.default=http://localhost:$HGPORT/
  1 0000000000000000000000000000000000000000

from within a repository

  $ hg clone http://localhost:$HGPORT/ client
  no changes found
  updating to branch default
  0 files updated, 0 files merged, 0 files removed, 0 files unresolved

  $ cd client
  $ hg path
  default = http://localhost:$HGPORT/
  $ hg debugdownload "largefile://a57b57b39ee4dc3da1e03526596007f480ecdbe8"
  1 0000000000000000000000000000000000000000
  $ cd ..
