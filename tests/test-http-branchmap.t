  $ hgserve() {
  >     hg serve -a localhost -p $HGPORT1 -d --pid-file=hg.pid \
  >       -E errors.log -v $@ > startup.log
  >     # Grepping hg serve stdout would hang on Windows
  >     grep -v 'listening at' startup.log
  >     cat hg.pid >> "$DAEMON_PIDS"
  > }
  $ hg init a
  $ hg --encoding utf-8 -R a branch æ
  marked working directory as branch \xc3\xa6 (esc)
  (branches are permanent and global, did you want a bookmark?)
  $ echo foo > a/foo
  $ hg -R a ci -Am foo
  adding foo
  $ hgserve -R a --config web.push_ssl=False --config web.allow_push=* --encoding latin1
  $ hg --encoding utf-8 clone http://localhost:$HGPORT1 b
  requesting all changes
  adding changesets
  adding manifests
  adding file changes
  added 1 changesets with 1 changes to 1 files
  new changesets 867c11ce77b8
  updating to branch \xc3\xa6 (esc)
  1 files updated, 0 files merged, 0 files removed, 0 files unresolved
  $ hg --encoding utf-8 -R b log
  changeset:   0:867c11ce77b8
  branch:      \xc3\xa6 (esc)
  tag:         tip
  user:        test
  date:        Thu Jan 01 00:00:00 1970 +0000
  summary:     foo
  
  $ echo bar >> b/foo
  $ hg -R b ci -m bar
  $ hg --encoding utf-8 -R b push
  pushing to http://localhost:$HGPORT1/
  searching for changes
  remote: adding changesets
  remote: adding manifests
  remote: adding file changes
  remote: added 1 changesets with 1 changes to 1 files
  $ hg -R a --encoding utf-8 log
  changeset:   1:58e7c90d67cb
  branch:      \xc3\xa6 (esc)
  tag:         tip
  user:        test
  date:        Thu Jan 01 00:00:00 1970 +0000
  summary:     bar
  
  changeset:   0:867c11ce77b8
  branch:      \xc3\xa6 (esc)
  user:        test
  date:        Thu Jan 01 00:00:00 1970 +0000
  summary:     foo
  
  $ killdaemons.py hg.pid

verify 7e7d56fe4833 (encoding fallback in branchmap to maintain compatibility with 1.3.x)

  $ cat <<EOF > oldhg
  > import threading
  > from mercurial import dispatch, hg, ui, wireprotoserver
  > 
  > class StdoutWrapper(object):
  >     def __init__(self, stdout):
  >         self._file = stdout
  > 
  >     def write(self, data):
  >         if data == b'47\n':
  >             # latin1 encoding is one %xx (3 bytes) shorter
  >             data = b'44\n'
  >         elif data.startswith(b'%C3%A6 '):
  >             # translate to latin1 encoding
  >             data = b'%%E6 %s' % data[7:]
  >         self._file.write(data)
  > 
  >     def __getattr__(self, name):
  >         return getattr(self._file, name)
  > 
  > dispatch.initstdio()
  > myui = ui.ui.load()
  > fout = StdoutWrapper(myui.fout)
  > myui.fout = myui.ferr
  > repo = hg.repository(myui, b'a')
  > wireprotoserver._runsshserver(myui, repo, myui.fin, fout, threading.Event())
  > EOF
  $ echo baz >> b/foo
  $ hg -R b ci -m baz
  $ hg push -R b -e "\"$PYTHON\" oldhg" ssh://dummy/ --encoding latin1
  pushing to ssh://dummy/
  searching for changes
  remote: adding changesets
  remote: adding manifests
  remote: adding file changes
  remote: added 1 changesets with 1 changes to 1 files
