#require unix-permissions

test that new files created in .hg inherit the permissions from .hg/store

  $ mkdir dir

just in case somebody has a strange $TMPDIR

  $ chmod g-s dir
  $ cd dir

  $ cat >printmodes.py <<EOF
  > from __future__ import absolute_import, print_function
  > import os
  > import sys
  > 
  > allnames = []
  > isdir = {}
  > for root, dirs, files in os.walk(sys.argv[1]):
  >     for d in dirs:
  >         name = os.path.join(root, d)
  >         isdir[name] = 1
  >         allnames.append(name)
  >     for f in files:
  >         name = os.path.join(root, f)
  >         allnames.append(name)
  > allnames.sort()
  > for name in allnames:
  >     suffix = name in isdir and '/' or ''
  >     print('%05o %s%s' % (os.lstat(name).st_mode & 0o7777, name, suffix))
  > EOF

  $ cat >mode.py <<EOF
  > from __future__ import absolute_import, print_function
  > import os
  > import sys
  > print('%05o' % os.lstat(sys.argv[1]).st_mode)
  > EOF

  $ umask 077

  $ hg init repo
  $ cd repo

  $ chmod 0770 .hg/store .hg/cache .hg/wcache

before commit
store can be written by the group, other files cannot
store is setgid

  $ "$PYTHON" ../printmodes.py .
  00700 ./.hg/
  00600 ./.hg/00changelog.i
  00770 ./.hg/cache/
  00600 ./.hg/requires
  00770 ./.hg/store/
  00770 ./.hg/wcache/

  $ mkdir dir
  $ touch foo dir/bar
  $ hg ci -qAm 'add files'

after commit
working dir files can only be written by the owner
files created in .hg can be written by the group
(in particular, store/**, dirstate, branch cache file, undo files)
new directories are setgid

  $ "$PYTHON" ../printmodes.py .
  00700 ./.hg/
  00600 ./.hg/00changelog.i
  00770 ./.hg/cache/
  00660 ./.hg/cache/branch2-served
  00660 ./.hg/cache/manifestfulltextcache (reporevlogstore !)
  00660 ./.hg/cache/rbc-names-v1
  00660 ./.hg/cache/rbc-revs-v1
  00660 ./.hg/dirstate
  00660 ./.hg/fsmonitor.state (fsmonitor !)
  00660 ./.hg/last-message.txt
  00600 ./.hg/requires
  00770 ./.hg/store/
  00660 ./.hg/store/00changelog.i
  00660 ./.hg/store/00manifest.i
  00770 ./.hg/store/data/
  00770 ./.hg/store/data/dir/
  00660 ./.hg/store/data/dir/bar.i (reporevlogstore !)
  00660 ./.hg/store/data/foo.i (reporevlogstore !)
  00770 ./.hg/store/data/dir/bar/ (reposimplestore !)
  00660 ./.hg/store/data/dir/bar/b80de5d138758541c5f05265ad144ab9fa86d1db (reposimplestore !)
  00660 ./.hg/store/data/dir/bar/index (reposimplestore !)
  00770 ./.hg/store/data/foo/ (reposimplestore !)
  00660 ./.hg/store/data/foo/b80de5d138758541c5f05265ad144ab9fa86d1db (reposimplestore !)
  00660 ./.hg/store/data/foo/index (reposimplestore !)
  00660 ./.hg/store/fncache (repofncache !)
  00660 ./.hg/store/phaseroots
  00660 ./.hg/store/undo
  00660 ./.hg/store/undo.backupfiles
  00660 ./.hg/store/undo.phaseroots
  00660 ./.hg/undo.backup.dirstate
  00660 ./.hg/undo.bookmarks
  00660 ./.hg/undo.branch
  00660 ./.hg/undo.desc
  00660 ./.hg/undo.dirstate
  00770 ./.hg/wcache/
  00711 ./.hg/wcache/checkisexec
  007.. ./.hg/wcache/checklink (re)
  00600 ./.hg/wcache/checklink-target
  00700 ./dir/
  00600 ./dir/bar
  00600 ./foo

  $ umask 007
  $ hg init ../push

before push
group can write everything

  $ "$PYTHON" ../printmodes.py ../push
  00770 ../push/.hg/
  00660 ../push/.hg/00changelog.i
  00770 ../push/.hg/cache/
  00660 ../push/.hg/requires
  00770 ../push/.hg/store/
  00770 ../push/.hg/wcache/

  $ umask 077
  $ hg -q push ../push

after push
group can still write everything

  $ "$PYTHON" ../printmodes.py ../push
  00770 ../push/.hg/
  00660 ../push/.hg/00changelog.i
  00770 ../push/.hg/cache/
  00660 ../push/.hg/cache/branch2-base
  00660 ../push/.hg/dirstate
  00660 ../push/.hg/requires
  00770 ../push/.hg/store/
  00660 ../push/.hg/store/00changelog.i
  00660 ../push/.hg/store/00manifest.i
  00770 ../push/.hg/store/data/
  00770 ../push/.hg/store/data/dir/
  00660 ../push/.hg/store/data/dir/bar.i (reporevlogstore !)
  00660 ../push/.hg/store/data/foo.i (reporevlogstore !)
  00770 ../push/.hg/store/data/dir/bar/ (reposimplestore !)
  00660 ../push/.hg/store/data/dir/bar/b80de5d138758541c5f05265ad144ab9fa86d1db (reposimplestore !)
  00660 ../push/.hg/store/data/dir/bar/index (reposimplestore !)
  00770 ../push/.hg/store/data/foo/ (reposimplestore !)
  00660 ../push/.hg/store/data/foo/b80de5d138758541c5f05265ad144ab9fa86d1db (reposimplestore !)
  00660 ../push/.hg/store/data/foo/index (reposimplestore !)
  00660 ../push/.hg/store/fncache (repofncache !)
  00660 ../push/.hg/store/undo
  00660 ../push/.hg/store/undo.backupfiles
  00660 ../push/.hg/store/undo.phaseroots
  00660 ../push/.hg/undo.bookmarks
  00660 ../push/.hg/undo.branch
  00660 ../push/.hg/undo.desc
  00660 ../push/.hg/undo.dirstate
  00770 ../push/.hg/wcache/


Test that we don't lose the setgid bit when we call chmod.
Not all systems support setgid directories (e.g. HFS+), so
just check that directories have the same mode.

  $ cd ..
  $ hg init setgid
  $ cd setgid
  $ chmod g+rwx .hg/store
  $ chmod g+s .hg/store 2> /dev/null || true
  $ mkdir dir
  $ touch dir/file
  $ hg ci -qAm 'add dir/file'
  $ storemode=`"$PYTHON" ../mode.py .hg/store`
  $ dirmode=`"$PYTHON" ../mode.py .hg/store/data/dir`
  $ if [ "$storemode" != "$dirmode" ]; then
  >  echo "$storemode != $dirmode"
  > fi
  $ cd ..

  $ cd .. # g-s dir
