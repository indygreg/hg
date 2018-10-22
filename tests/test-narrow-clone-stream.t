Tests narrow stream clones

  $ . "$TESTDIR/narrow-library.sh"

Server setup

  $ hg init master
  $ cd master
  $ mkdir dir
  $ mkdir dir/src
  $ cd dir/src
  $ for x in `$TESTDIR/seq.py 20`; do echo $x > "f$x"; hg add "f$x"; hg commit -m "Commit src $x"; done

  $ cd ..
  $ mkdir tests
  $ cd tests
  $ for x in `$TESTDIR/seq.py 20`; do echo $x > "f$x"; hg add "f$x"; hg commit -m "Commit src $x"; done
  $ cd ../../..

Trying to stream clone when the server does not support it

  $ hg clone --narrow ssh://user@dummy/master narrow --noupdate --include "dir/src/f10" --stream
  streaming all changes
  remote: abort: server does not support narrow stream clones
  abort: pull failed on remote
  [255]

Enable stream clone on the server

  $ echo "[server]" >> master/.hg/hgrc
  $ echo "stream-narrow-clones=True" >> master/.hg/hgrc

Cloning a specific file when stream clone is supported

  $ hg clone --narrow ssh://user@dummy/master narrow --noupdate --include "dir/src/f10" --stream
  streaming all changes
  remote: abort: server does not support narrow stream clones
  abort: pull failed on remote
  [255]
