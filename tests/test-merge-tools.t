test merge-tools configuration - mostly exercising filemerge.py

  $ unset HGMERGE # make sure HGMERGE doesn't interfere with the test
  $ hg init repo
  $ cd repo

revision 0

  $ echo "revision 0" > f
  $ echo "space" >> f
  $ hg commit -Am "revision 0"
  adding f

revision 1

  $ echo "revision 1" > f
  $ echo "space" >> f
  $ hg commit -Am "revision 1"
  $ hg update 0 > /dev/null

revision 2

  $ echo "revision 2" > f
  $ echo "space" >> f
  $ hg commit -Am "revision 2"
  created new head
  $ hg update 0 > /dev/null

revision 3 - simple to merge

  $ echo "revision 3" >> f
  $ hg commit -Am "revision 3"
  created new head

revision 4 - hard to merge

  $ hg update 0 > /dev/null
  $ echo "revision 4" > f
  $ hg commit -Am "revision 4"
  created new head

  $ echo "[merge-tools]" > .hg/hgrc

  $ beforemerge() {
  >   cat .hg/hgrc
  >   echo "# hg update -C 1"
  >   hg update -C 1 > /dev/null
  > }
  $ aftermerge() {
  >   echo "# cat f"
  >   cat f
  >   echo "# hg stat"
  >   hg stat
  >   echo "# hg resolve --list"
  >   hg resolve --list
  >   rm -f f.orig
  > }

Tool selection

default is internal merge:

  $ beforemerge
  [merge-tools]
  # hg update -C 1

hg merge -r 2
override $PATH to ensure hgmerge not visible; use $PYTHON in case we're
running from a devel copy, not a temp installation

  $ PATH="$BINDIR:/usr/sbin" "$PYTHON" "$BINDIR"/hg merge -r 2
  merging f
  warning: conflicts while merging f! (edit, then use 'hg resolve --mark')
  0 files updated, 0 files merged, 0 files removed, 1 files unresolved
  use 'hg resolve' to retry unresolved file merges or 'hg merge --abort' to abandon
  [1]
  $ aftermerge
  # cat f
  <<<<<<< working copy: ef83787e2614 - test: revision 1
  revision 1
  =======
  revision 2
  >>>>>>> merge rev:    0185f4e0cf02 - test: revision 2
  space
  # hg stat
  M f
  ? f.orig
  # hg resolve --list
  U f

simplest hgrc using false for merge:

  $ echo "false.whatever=" >> .hg/hgrc
  $ beforemerge
  [merge-tools]
  false.whatever=
  # hg update -C 1
  $ hg merge -r 2
  merging f
  merging f failed!
  0 files updated, 0 files merged, 0 files removed, 1 files unresolved
  use 'hg resolve' to retry unresolved file merges or 'hg merge --abort' to abandon
  [1]
  $ aftermerge
  # cat f
  revision 1
  space
  # hg stat
  M f
  ? f.orig
  # hg resolve --list
  U f

#if unix-permissions

unexecutable file in $PATH shouldn't be found:

  $ echo "echo fail" > false
  $ hg up -qC 1
  $ PATH="`pwd`:$BINDIR:/usr/sbin" "$PYTHON" "$BINDIR"/hg merge -r 2
  merging f
  warning: conflicts while merging f! (edit, then use 'hg resolve --mark')
  0 files updated, 0 files merged, 0 files removed, 1 files unresolved
  use 'hg resolve' to retry unresolved file merges or 'hg merge --abort' to abandon
  [1]
  $ rm false

#endif

executable directory in $PATH shouldn't be found:

  $ mkdir false
  $ hg up -qC 1
  $ PATH="`pwd`:$BINDIR:/usr/sbin" "$PYTHON" "$BINDIR"/hg merge -r 2
  merging f
  warning: conflicts while merging f! (edit, then use 'hg resolve --mark')
  0 files updated, 0 files merged, 0 files removed, 1 files unresolved
  use 'hg resolve' to retry unresolved file merges or 'hg merge --abort' to abandon
  [1]
  $ rmdir false

true with higher .priority gets precedence:

  $ echo "true.priority=1" >> .hg/hgrc
  $ beforemerge
  [merge-tools]
  false.whatever=
  true.priority=1
  # hg update -C 1
  $ hg merge -r 2
  merging f
  0 files updated, 1 files merged, 0 files removed, 0 files unresolved
  (branch merge, don't forget to commit)
  $ aftermerge
  # cat f
  revision 1
  space
  # hg stat
  M f
  # hg resolve --list
  R f

unless lowered on command line:

  $ beforemerge
  [merge-tools]
  false.whatever=
  true.priority=1
  # hg update -C 1
  $ hg merge -r 2 --config merge-tools.true.priority=-7
  merging f
  merging f failed!
  0 files updated, 0 files merged, 0 files removed, 1 files unresolved
  use 'hg resolve' to retry unresolved file merges or 'hg merge --abort' to abandon
  [1]
  $ aftermerge
  # cat f
  revision 1
  space
  # hg stat
  M f
  ? f.orig
  # hg resolve --list
  U f

or false set higher on command line:

  $ beforemerge
  [merge-tools]
  false.whatever=
  true.priority=1
  # hg update -C 1
  $ hg merge -r 2 --config merge-tools.false.priority=117
  merging f
  merging f failed!
  0 files updated, 0 files merged, 0 files removed, 1 files unresolved
  use 'hg resolve' to retry unresolved file merges or 'hg merge --abort' to abandon
  [1]
  $ aftermerge
  # cat f
  revision 1
  space
  # hg stat
  M f
  ? f.orig
  # hg resolve --list
  U f

or true set to disabled:
  $ beforemerge
  [merge-tools]
  false.whatever=
  true.priority=1
  # hg update -C 1
  $ hg merge -r 2 --config merge-tools.true.disabled=yes
  merging f
  merging f failed!
  0 files updated, 0 files merged, 0 files removed, 1 files unresolved
  use 'hg resolve' to retry unresolved file merges or 'hg merge --abort' to abandon
  [1]
  $ aftermerge
  # cat f
  revision 1
  space
  # hg stat
  M f
  ? f.orig
  # hg resolve --list
  U f

or true.executable not found in PATH:

  $ beforemerge
  [merge-tools]
  false.whatever=
  true.priority=1
  # hg update -C 1
  $ hg merge -r 2 --config merge-tools.true.executable=nonexistentmergetool
  merging f
  merging f failed!
  0 files updated, 0 files merged, 0 files removed, 1 files unresolved
  use 'hg resolve' to retry unresolved file merges or 'hg merge --abort' to abandon
  [1]
  $ aftermerge
  # cat f
  revision 1
  space
  # hg stat
  M f
  ? f.orig
  # hg resolve --list
  U f

or true.executable with bogus path:

  $ beforemerge
  [merge-tools]
  false.whatever=
  true.priority=1
  # hg update -C 1
  $ hg merge -r 2 --config merge-tools.true.executable=/nonexistent/mergetool
  merging f
  merging f failed!
  0 files updated, 0 files merged, 0 files removed, 1 files unresolved
  use 'hg resolve' to retry unresolved file merges or 'hg merge --abort' to abandon
  [1]
  $ aftermerge
  # cat f
  revision 1
  space
  # hg stat
  M f
  ? f.orig
  # hg resolve --list
  U f

but true.executable set to cat found in PATH works:

  $ echo "true.executable=cat" >> .hg/hgrc
  $ beforemerge
  [merge-tools]
  false.whatever=
  true.priority=1
  true.executable=cat
  # hg update -C 1
  $ hg merge -r 2
  merging f
  revision 1
  space
  revision 0
  space
  revision 2
  space
  0 files updated, 1 files merged, 0 files removed, 0 files unresolved
  (branch merge, don't forget to commit)
  $ aftermerge
  # cat f
  revision 1
  space
  # hg stat
  M f
  # hg resolve --list
  R f

and true.executable set to cat with path works:

  $ beforemerge
  [merge-tools]
  false.whatever=
  true.priority=1
  true.executable=cat
  # hg update -C 1
  $ hg merge -r 2 --config merge-tools.true.executable=cat
  merging f
  revision 1
  space
  revision 0
  space
  revision 2
  space
  0 files updated, 1 files merged, 0 files removed, 0 files unresolved
  (branch merge, don't forget to commit)
  $ aftermerge
  # cat f
  revision 1
  space
  # hg stat
  M f
  # hg resolve --list
  R f

executable set to python script that succeeds:

  $ cat > "$TESTTMP/myworkingmerge.py" <<EOF
  > def myworkingmergefn(ui, repo, args, **kwargs):
  >     return False
  > EOF
  $ beforemerge
  [merge-tools]
  false.whatever=
  true.priority=1
  true.executable=cat
  # hg update -C 1
  $ hg merge -r 2 --config merge-tools.true.executable="python:$TESTTMP/myworkingmerge.py:myworkingmergefn"
  merging f
  0 files updated, 1 files merged, 0 files removed, 0 files unresolved
  (branch merge, don't forget to commit)
  $ aftermerge
  # cat f
  revision 1
  space
  # hg stat
  M f
  # hg resolve --list
  R f

executable set to python script that fails:

  $ cat > "$TESTTMP/mybrokenmerge.py" <<EOF
  > def mybrokenmergefn(ui, repo, args, **kwargs):
  >     ui.write(b"some fail message\n")
  >     return True
  > EOF
  $ beforemerge
  [merge-tools]
  false.whatever=
  true.priority=1
  true.executable=cat
  # hg update -C 1
  $ hg merge -r 2 --config merge-tools.true.executable="python:$TESTTMP/mybrokenmerge.py:mybrokenmergefn"
  merging f
  some fail message
  abort: $TESTTMP/mybrokenmerge.py hook failed
  [255]
  $ aftermerge
  # cat f
  revision 1
  space
  # hg stat
  ? f.orig
  # hg resolve --list
  U f

executable set to python script that is missing function:

  $ beforemerge
  [merge-tools]
  false.whatever=
  true.priority=1
  true.executable=cat
  # hg update -C 1
  $ hg merge -r 2 --config merge-tools.true.executable="python:$TESTTMP/myworkingmerge.py:missingFunction"
  merging f
  abort: $TESTTMP/myworkingmerge.py does not have function: missingFunction
  [255]
  $ aftermerge
  # cat f
  revision 1
  space
  # hg stat
  ? f.orig
  # hg resolve --list
  U f

executable set to missing python script:

  $ beforemerge
  [merge-tools]
  false.whatever=
  true.priority=1
  true.executable=cat
  # hg update -C 1
  $ hg merge -r 2 --config merge-tools.true.executable="python:$TESTTMP/missingpythonscript.py:mergefn"
  merging f
  abort: loading python merge script failed: $TESTTMP/missingpythonscript.py
  [255]
  $ aftermerge
  # cat f
  revision 1
  space
  # hg stat
  ? f.orig
  # hg resolve --list
  U f

executable set to python script but callable function is missing:

  $ beforemerge
  [merge-tools]
  false.whatever=
  true.priority=1
  true.executable=cat
  # hg update -C 1
  $ hg merge -r 2 --config merge-tools.true.executable="python:$TESTTMP/myworkingmerge.py"
  abort: invalid 'python:' syntax: python:$TESTTMP/myworkingmerge.py
  [255]
  $ aftermerge
  # cat f
  revision 1
  space
  # hg stat
  # hg resolve --list
  U f

executable set to python script but callable function is empty string:

  $ beforemerge
  [merge-tools]
  false.whatever=
  true.priority=1
  true.executable=cat
  # hg update -C 1
  $ hg merge -r 2 --config merge-tools.true.executable="python:$TESTTMP/myworkingmerge.py:"
  abort: invalid 'python:' syntax: python:$TESTTMP/myworkingmerge.py:
  [255]
  $ aftermerge
  # cat f
  revision 1
  space
  # hg stat
  # hg resolve --list
  U f

executable set to python script but callable function is missing and path contains colon:

  $ beforemerge
  [merge-tools]
  false.whatever=
  true.priority=1
  true.executable=cat
  # hg update -C 1
  $ hg merge -r 2 --config merge-tools.true.executable="python:$TESTTMP/some:dir/myworkingmerge.py"
  abort: invalid 'python:' syntax: python:$TESTTMP/some:dir/myworkingmerge.py
  [255]
  $ aftermerge
  # cat f
  revision 1
  space
  # hg stat
  # hg resolve --list
  U f

executable set to python script filename that contains spaces:

  $ mkdir -p "$TESTTMP/my path"
  $ cat > "$TESTTMP/my path/my working merge with spaces in filename.py" <<EOF
  > def myworkingmergefn(ui, repo, args, **kwargs):
  >     return False
  > EOF
  $ beforemerge
  [merge-tools]
  false.whatever=
  true.priority=1
  true.executable=cat
  # hg update -C 1
  $ hg merge -r 2 --config "merge-tools.true.executable=python:$TESTTMP/my path/my working merge with spaces in filename.py:myworkingmergefn"
  merging f
  0 files updated, 1 files merged, 0 files removed, 0 files unresolved
  (branch merge, don't forget to commit)
  $ aftermerge
  # cat f
  revision 1
  space
  # hg stat
  M f
  # hg resolve --list
  R f

#if unix-permissions

environment variables in true.executable are handled:

  $ echo 'echo "custom merge tool"' > .hg/merge.sh
  $ beforemerge
  [merge-tools]
  false.whatever=
  true.priority=1
  true.executable=cat
  # hg update -C 1
  $ hg --config merge-tools.true.executable='sh' \
  >    --config merge-tools.true.args=.hg/merge.sh \
  >    merge -r 2
  merging f
  custom merge tool
  0 files updated, 1 files merged, 0 files removed, 0 files unresolved
  (branch merge, don't forget to commit)
  $ aftermerge
  # cat f
  revision 1
  space
  # hg stat
  M f
  # hg resolve --list
  R f

#endif

Tool selection and merge-patterns

merge-patterns specifies new tool false:

  $ beforemerge
  [merge-tools]
  false.whatever=
  true.priority=1
  true.executable=cat
  # hg update -C 1
  $ hg merge -r 2 --config merge-patterns.f=false
  merging f
  merging f failed!
  0 files updated, 0 files merged, 0 files removed, 1 files unresolved
  use 'hg resolve' to retry unresolved file merges or 'hg merge --abort' to abandon
  [1]
  $ aftermerge
  # cat f
  revision 1
  space
  # hg stat
  M f
  ? f.orig
  # hg resolve --list
  U f

merge-patterns specifies executable not found in PATH and gets warning:

  $ beforemerge
  [merge-tools]
  false.whatever=
  true.priority=1
  true.executable=cat
  # hg update -C 1
  $ hg merge -r 2 --config merge-patterns.f=true --config merge-tools.true.executable=nonexistentmergetool
  couldn't find merge tool true (for pattern f)
  merging f
  couldn't find merge tool true (for pattern f)
  merging f failed!
  0 files updated, 0 files merged, 0 files removed, 1 files unresolved
  use 'hg resolve' to retry unresolved file merges or 'hg merge --abort' to abandon
  [1]
  $ aftermerge
  # cat f
  revision 1
  space
  # hg stat
  M f
  ? f.orig
  # hg resolve --list
  U f

merge-patterns specifies executable with bogus path and gets warning:

  $ beforemerge
  [merge-tools]
  false.whatever=
  true.priority=1
  true.executable=cat
  # hg update -C 1
  $ hg merge -r 2 --config merge-patterns.f=true --config merge-tools.true.executable=/nonexistent/mergetool
  couldn't find merge tool true (for pattern f)
  merging f
  couldn't find merge tool true (for pattern f)
  merging f failed!
  0 files updated, 0 files merged, 0 files removed, 1 files unresolved
  use 'hg resolve' to retry unresolved file merges or 'hg merge --abort' to abandon
  [1]
  $ aftermerge
  # cat f
  revision 1
  space
  # hg stat
  M f
  ? f.orig
  # hg resolve --list
  U f

ui.merge overrules priority

ui.merge specifies false:

  $ beforemerge
  [merge-tools]
  false.whatever=
  true.priority=1
  true.executable=cat
  # hg update -C 1
  $ hg merge -r 2 --config ui.merge=false
  merging f
  merging f failed!
  0 files updated, 0 files merged, 0 files removed, 1 files unresolved
  use 'hg resolve' to retry unresolved file merges or 'hg merge --abort' to abandon
  [1]
  $ aftermerge
  # cat f
  revision 1
  space
  # hg stat
  M f
  ? f.orig
  # hg resolve --list
  U f

ui.merge specifies internal:fail:

  $ beforemerge
  [merge-tools]
  false.whatever=
  true.priority=1
  true.executable=cat
  # hg update -C 1
  $ hg merge -r 2 --config ui.merge=internal:fail
  0 files updated, 0 files merged, 0 files removed, 1 files unresolved
  use 'hg resolve' to retry unresolved file merges or 'hg merge --abort' to abandon
  [1]
  $ aftermerge
  # cat f
  revision 1
  space
  # hg stat
  M f
  # hg resolve --list
  U f

ui.merge specifies :local (without internal prefix):

  $ beforemerge
  [merge-tools]
  false.whatever=
  true.priority=1
  true.executable=cat
  # hg update -C 1
  $ hg merge -r 2 --config ui.merge=:local
  0 files updated, 1 files merged, 0 files removed, 0 files unresolved
  (branch merge, don't forget to commit)
  $ aftermerge
  # cat f
  revision 1
  space
  # hg stat
  M f
  # hg resolve --list
  R f

ui.merge specifies internal:other:

  $ beforemerge
  [merge-tools]
  false.whatever=
  true.priority=1
  true.executable=cat
  # hg update -C 1
  $ hg merge -r 2 --config ui.merge=internal:other
  0 files updated, 1 files merged, 0 files removed, 0 files unresolved
  (branch merge, don't forget to commit)
  $ aftermerge
  # cat f
  revision 2
  space
  # hg stat
  M f
  # hg resolve --list
  R f

ui.merge specifies internal:prompt:

  $ beforemerge
  [merge-tools]
  false.whatever=
  true.priority=1
  true.executable=cat
  # hg update -C 1
  $ hg merge -r 2 --config ui.merge=internal:prompt
  keep (l)ocal [working copy], take (o)ther [merge rev], or leave (u)nresolved for f? u
  0 files updated, 0 files merged, 0 files removed, 1 files unresolved
  use 'hg resolve' to retry unresolved file merges or 'hg merge --abort' to abandon
  [1]
  $ aftermerge
  # cat f
  revision 1
  space
  # hg stat
  M f
  # hg resolve --list
  U f

ui.merge specifies :prompt, with 'leave unresolved' chosen

  $ beforemerge
  [merge-tools]
  false.whatever=
  true.priority=1
  true.executable=cat
  # hg update -C 1
  $ hg merge -r 2 --config ui.merge=:prompt --config ui.interactive=True << EOF
  > u
  > EOF
  keep (l)ocal [working copy], take (o)ther [merge rev], or leave (u)nresolved for f? u
  0 files updated, 0 files merged, 0 files removed, 1 files unresolved
  use 'hg resolve' to retry unresolved file merges or 'hg merge --abort' to abandon
  [1]
  $ aftermerge
  # cat f
  revision 1
  space
  # hg stat
  M f
  # hg resolve --list
  U f

prompt with EOF

  $ beforemerge
  [merge-tools]
  false.whatever=
  true.priority=1
  true.executable=cat
  # hg update -C 1
  $ hg merge -r 2 --config ui.merge=internal:prompt --config ui.interactive=true
  keep (l)ocal [working copy], take (o)ther [merge rev], or leave (u)nresolved for f? 
  0 files updated, 0 files merged, 0 files removed, 1 files unresolved
  use 'hg resolve' to retry unresolved file merges or 'hg merge --abort' to abandon
  [1]
  $ aftermerge
  # cat f
  revision 1
  space
  # hg stat
  M f
  # hg resolve --list
  U f
  $ hg resolve --all --config ui.merge=internal:prompt --config ui.interactive=true
  keep (l)ocal [working copy], take (o)ther [merge rev], or leave (u)nresolved for f? 
  [1]
  $ aftermerge
  # cat f
  revision 1
  space
  # hg stat
  M f
  ? f.orig
  # hg resolve --list
  U f
  $ rm f
  $ hg resolve --all --config ui.merge=internal:prompt --config ui.interactive=true
  keep (l)ocal [working copy], take (o)ther [merge rev], or leave (u)nresolved for f? 
  [1]
  $ aftermerge
  # cat f
  revision 1
  space
  # hg stat
  M f
  # hg resolve --list
  U f
  $ hg resolve --all --config ui.merge=internal:prompt
  keep (l)ocal [working copy], take (o)ther [merge rev], or leave (u)nresolved for f? u
  [1]
  $ aftermerge
  # cat f
  revision 1
  space
  # hg stat
  M f
  ? f.orig
  # hg resolve --list
  U f

ui.merge specifies internal:dump:

  $ beforemerge
  [merge-tools]
  false.whatever=
  true.priority=1
  true.executable=cat
  # hg update -C 1
  $ hg merge -r 2 --config ui.merge=internal:dump
  merging f
  0 files updated, 0 files merged, 0 files removed, 1 files unresolved
  use 'hg resolve' to retry unresolved file merges or 'hg merge --abort' to abandon
  [1]
  $ aftermerge
  # cat f
  revision 1
  space
  # hg stat
  M f
  ? f.base
  ? f.local
  ? f.orig
  ? f.other
  # hg resolve --list
  U f

f.base:

  $ cat f.base
  revision 0
  space

f.local:

  $ cat f.local
  revision 1
  space

f.other:

  $ cat f.other
  revision 2
  space
  $ rm f.base f.local f.other

check that internal:dump doesn't dump files if premerge runs
successfully

  $ beforemerge
  [merge-tools]
  false.whatever=
  true.priority=1
  true.executable=cat
  # hg update -C 1
  $ hg merge -r 3 --config ui.merge=internal:dump
  merging f
  0 files updated, 1 files merged, 0 files removed, 0 files unresolved
  (branch merge, don't forget to commit)

  $ aftermerge
  # cat f
  revision 1
  space
  revision 3
  # hg stat
  M f
  # hg resolve --list
  R f

check that internal:forcedump dumps files, even if local and other can
be merged easily

  $ beforemerge
  [merge-tools]
  false.whatever=
  true.priority=1
  true.executable=cat
  # hg update -C 1
  $ hg merge -r 3 --config ui.merge=internal:forcedump
  merging f
  0 files updated, 0 files merged, 0 files removed, 1 files unresolved
  use 'hg resolve' to retry unresolved file merges or 'hg merge --abort' to abandon
  [1]
  $ aftermerge
  # cat f
  revision 1
  space
  # hg stat
  M f
  ? f.base
  ? f.local
  ? f.orig
  ? f.other
  # hg resolve --list
  U f

  $ cat f.base
  revision 0
  space

  $ cat f.local
  revision 1
  space

  $ cat f.other
  revision 0
  space
  revision 3

  $ rm -f f.base f.local f.other

ui.merge specifies internal:other but is overruled by pattern for false:

  $ beforemerge
  [merge-tools]
  false.whatever=
  true.priority=1
  true.executable=cat
  # hg update -C 1
  $ hg merge -r 2 --config ui.merge=internal:other --config merge-patterns.f=false
  merging f
  merging f failed!
  0 files updated, 0 files merged, 0 files removed, 1 files unresolved
  use 'hg resolve' to retry unresolved file merges or 'hg merge --abort' to abandon
  [1]
  $ aftermerge
  # cat f
  revision 1
  space
  # hg stat
  M f
  ? f.orig
  # hg resolve --list
  U f

Premerge

ui.merge specifies internal:other but is overruled by --tool=false

  $ beforemerge
  [merge-tools]
  false.whatever=
  true.priority=1
  true.executable=cat
  # hg update -C 1
  $ hg merge -r 2 --config ui.merge=internal:other --tool=false
  merging f
  merging f failed!
  0 files updated, 0 files merged, 0 files removed, 1 files unresolved
  use 'hg resolve' to retry unresolved file merges or 'hg merge --abort' to abandon
  [1]
  $ aftermerge
  # cat f
  revision 1
  space
  # hg stat
  M f
  ? f.orig
  # hg resolve --list
  U f

HGMERGE specifies internal:other but is overruled by --tool=false

  $ HGMERGE=internal:other ; export HGMERGE
  $ beforemerge
  [merge-tools]
  false.whatever=
  true.priority=1
  true.executable=cat
  # hg update -C 1
  $ hg merge -r 2 --tool=false
  merging f
  merging f failed!
  0 files updated, 0 files merged, 0 files removed, 1 files unresolved
  use 'hg resolve' to retry unresolved file merges or 'hg merge --abort' to abandon
  [1]
  $ aftermerge
  # cat f
  revision 1
  space
  # hg stat
  M f
  ? f.orig
  # hg resolve --list
  U f

  $ unset HGMERGE # make sure HGMERGE doesn't interfere with remaining tests

update is a merge ...

(this also tests that files reverted with '--rev REV' are treated as
"modified", even if none of mode, size and timestamp of them isn't
changed on the filesystem (see also issue4583))

  $ cat >> $HGRCPATH <<EOF
  > [fakedirstatewritetime]
  > # emulate invoking dirstate.write() via repo.status()
  > # at 2000-01-01 00:00
  > fakenow = 200001010000
  > EOF

  $ beforemerge
  [merge-tools]
  false.whatever=
  true.priority=1
  true.executable=cat
  # hg update -C 1
  $ hg update -q 0
  $ f -s f
  f: size=17
  $ touch -t 200001010000 f
  $ hg debugrebuildstate
  $ cat >> $HGRCPATH <<EOF
  > [extensions]
  > fakedirstatewritetime = $TESTDIR/fakedirstatewritetime.py
  > EOF
  $ hg revert -q -r 1 .
  $ cat >> $HGRCPATH <<EOF
  > [extensions]
  > fakedirstatewritetime = !
  > EOF
  $ f -s f
  f: size=17
  $ touch -t 200001010000 f
  $ hg status f
  M f
  $ hg update -r 2
  merging f
  revision 1
  space
  revision 0
  space
  revision 2
  space
  0 files updated, 1 files merged, 0 files removed, 0 files unresolved
  $ aftermerge
  # cat f
  revision 1
  space
  # hg stat
  M f
  # hg resolve --list
  R f

update should also have --tool

  $ beforemerge
  [merge-tools]
  false.whatever=
  true.priority=1
  true.executable=cat
  # hg update -C 1
  $ hg update -q 0
  $ f -s f
  f: size=17
  $ touch -t 200001010000 f
  $ hg debugrebuildstate
  $ cat >> $HGRCPATH <<EOF
  > [extensions]
  > fakedirstatewritetime = $TESTDIR/fakedirstatewritetime.py
  > EOF
  $ hg revert -q -r 1 .
  $ cat >> $HGRCPATH <<EOF
  > [extensions]
  > fakedirstatewritetime = !
  > EOF
  $ f -s f
  f: size=17
  $ touch -t 200001010000 f
  $ hg status f
  M f
  $ hg update -r 2 --tool false
  merging f
  merging f failed!
  0 files updated, 0 files merged, 0 files removed, 1 files unresolved
  use 'hg resolve' to retry unresolved file merges
  [1]
  $ aftermerge
  # cat f
  revision 1
  space
  # hg stat
  M f
  ? f.orig
  # hg resolve --list
  U f

Default is silent simplemerge:

  $ beforemerge
  [merge-tools]
  false.whatever=
  true.priority=1
  true.executable=cat
  # hg update -C 1
  $ hg merge -r 3
  merging f
  0 files updated, 1 files merged, 0 files removed, 0 files unresolved
  (branch merge, don't forget to commit)
  $ aftermerge
  # cat f
  revision 1
  space
  revision 3
  # hg stat
  M f
  # hg resolve --list
  R f

.premerge=True is same:

  $ beforemerge
  [merge-tools]
  false.whatever=
  true.priority=1
  true.executable=cat
  # hg update -C 1
  $ hg merge -r 3 --config merge-tools.true.premerge=True
  merging f
  0 files updated, 1 files merged, 0 files removed, 0 files unresolved
  (branch merge, don't forget to commit)
  $ aftermerge
  # cat f
  revision 1
  space
  revision 3
  # hg stat
  M f
  # hg resolve --list
  R f

.premerge=False executes merge-tool:

  $ beforemerge
  [merge-tools]
  false.whatever=
  true.priority=1
  true.executable=cat
  # hg update -C 1
  $ hg merge -r 3 --config merge-tools.true.premerge=False
  merging f
  revision 1
  space
  revision 0
  space
  revision 0
  space
  revision 3
  0 files updated, 1 files merged, 0 files removed, 0 files unresolved
  (branch merge, don't forget to commit)
  $ aftermerge
  # cat f
  revision 1
  space
  # hg stat
  M f
  # hg resolve --list
  R f

premerge=keep keeps conflict markers in:

  $ beforemerge
  [merge-tools]
  false.whatever=
  true.priority=1
  true.executable=cat
  # hg update -C 1
  $ hg merge -r 4 --config merge-tools.true.premerge=keep
  merging f
  <<<<<<< working copy: ef83787e2614 - test: revision 1
  revision 1
  space
  =======
  revision 4
  >>>>>>> merge rev:    81448d39c9a0 - test: revision 4
  revision 0
  space
  revision 4
  0 files updated, 1 files merged, 0 files removed, 0 files unresolved
  (branch merge, don't forget to commit)
  $ aftermerge
  # cat f
  <<<<<<< working copy: ef83787e2614 - test: revision 1
  revision 1
  space
  =======
  revision 4
  >>>>>>> merge rev:    81448d39c9a0 - test: revision 4
  # hg stat
  M f
  # hg resolve --list
  R f

premerge=keep-merge3 keeps conflict markers with base content:

  $ beforemerge
  [merge-tools]
  false.whatever=
  true.priority=1
  true.executable=cat
  # hg update -C 1
  $ hg merge -r 4 --config merge-tools.true.premerge=keep-merge3
  merging f
  <<<<<<< working copy: ef83787e2614 - test: revision 1
  revision 1
  space
  ||||||| base
  revision 0
  space
  =======
  revision 4
  >>>>>>> merge rev:    81448d39c9a0 - test: revision 4
  revision 0
  space
  revision 4
  0 files updated, 1 files merged, 0 files removed, 0 files unresolved
  (branch merge, don't forget to commit)
  $ aftermerge
  # cat f
  <<<<<<< working copy: ef83787e2614 - test: revision 1
  revision 1
  space
  ||||||| base
  revision 0
  space
  =======
  revision 4
  >>>>>>> merge rev:    81448d39c9a0 - test: revision 4
  # hg stat
  M f
  # hg resolve --list
  R f

premerge=keep respects ui.mergemarkers=basic:

  $ beforemerge
  [merge-tools]
  false.whatever=
  true.priority=1
  true.executable=cat
  # hg update -C 1
  $ hg merge -r 4 --config merge-tools.true.premerge=keep --config ui.mergemarkers=basic
  merging f
  <<<<<<< working copy
  revision 1
  space
  =======
  revision 4
  >>>>>>> merge rev
  revision 0
  space
  revision 4
  0 files updated, 1 files merged, 0 files removed, 0 files unresolved
  (branch merge, don't forget to commit)
  $ aftermerge
  # cat f
  <<<<<<< working copy
  revision 1
  space
  =======
  revision 4
  >>>>>>> merge rev
  # hg stat
  M f
  # hg resolve --list
  R f

premerge=keep ignores ui.mergemarkers=basic if true.mergemarkers=detailed:

  $ beforemerge
  [merge-tools]
  false.whatever=
  true.priority=1
  true.executable=cat
  # hg update -C 1
  $ hg merge -r 4 --config merge-tools.true.premerge=keep \
  >     --config ui.mergemarkers=basic \
  >     --config merge-tools.true.mergemarkers=detailed
  merging f
  <<<<<<< working copy: ef83787e2614 - test: revision 1
  revision 1
  space
  =======
  revision 4
  >>>>>>> merge rev:    81448d39c9a0 - test: revision 4
  revision 0
  space
  revision 4
  0 files updated, 1 files merged, 0 files removed, 0 files unresolved
  (branch merge, don't forget to commit)
  $ aftermerge
  # cat f
  <<<<<<< working copy: ef83787e2614 - test: revision 1
  revision 1
  space
  =======
  revision 4
  >>>>>>> merge rev:    81448d39c9a0 - test: revision 4
  # hg stat
  M f
  # hg resolve --list
  R f

premerge=keep respects ui.mergemarkertemplate instead of
true.mergemarkertemplate if true.mergemarkers=basic:

  $ beforemerge
  [merge-tools]
  false.whatever=
  true.priority=1
  true.executable=cat
  # hg update -C 1
  $ hg merge -r 4 --config merge-tools.true.premerge=keep \
  >    --config ui.mergemarkertemplate='uitmpl {rev}' \
  >    --config merge-tools.true.mergemarkertemplate='tooltmpl {short(node)}'
  merging f
  <<<<<<< working copy: uitmpl 1
  revision 1
  space
  =======
  revision 4
  >>>>>>> merge rev:    uitmpl 4
  revision 0
  space
  revision 4
  0 files updated, 1 files merged, 0 files removed, 0 files unresolved
  (branch merge, don't forget to commit)
  $ aftermerge
  # cat f
  <<<<<<< working copy: uitmpl 1
  revision 1
  space
  =======
  revision 4
  >>>>>>> merge rev:    uitmpl 4
  # hg stat
  M f
  # hg resolve --list
  R f

premerge=keep respects true.mergemarkertemplate instead of
true.mergemarkertemplate if true.mergemarkers=detailed:

  $ beforemerge
  [merge-tools]
  false.whatever=
  true.priority=1
  true.executable=cat
  # hg update -C 1
  $ hg merge -r 4 --config merge-tools.true.premerge=keep \
  >    --config ui.mergemarkertemplate='uitmpl {rev}' \
  >    --config merge-tools.true.mergemarkertemplate='tooltmpl {short(node)}' \
  >    --config merge-tools.true.mergemarkers=detailed
  merging f
  <<<<<<< working copy: tooltmpl ef83787e2614
  revision 1
  space
  =======
  revision 4
  >>>>>>> merge rev:    tooltmpl 81448d39c9a0
  revision 0
  space
  revision 4
  0 files updated, 1 files merged, 0 files removed, 0 files unresolved
  (branch merge, don't forget to commit)
  $ aftermerge
  # cat f
  <<<<<<< working copy: tooltmpl ef83787e2614
  revision 1
  space
  =======
  revision 4
  >>>>>>> merge rev:    tooltmpl 81448d39c9a0
  # hg stat
  M f
  # hg resolve --list
  R f

Tool execution

set tools.args explicit to include $base $local $other $output:

  $ beforemerge
  [merge-tools]
  false.whatever=
  true.priority=1
  true.executable=cat
  # hg update -C 1
  $ hg merge -r 2 --config merge-tools.true.executable=head --config merge-tools.true.args='$base $local $other $output' \
  >   | sed 's,==> .* <==,==> ... <==,g'
  merging f
  ==> ... <==
  revision 0
  space
  
  ==> ... <==
  revision 1
  space
  
  ==> ... <==
  revision 2
  space
  
  ==> ... <==
  revision 1
  space
  0 files updated, 1 files merged, 0 files removed, 0 files unresolved
  (branch merge, don't forget to commit)
  $ aftermerge
  # cat f
  revision 1
  space
  # hg stat
  M f
  # hg resolve --list
  R f

Merge with "echo mergeresult > $local":

  $ beforemerge
  [merge-tools]
  false.whatever=
  true.priority=1
  true.executable=cat
  # hg update -C 1
  $ hg merge -r 2 --config merge-tools.true.executable=echo --config merge-tools.true.args='mergeresult > $local'
  merging f
  0 files updated, 1 files merged, 0 files removed, 0 files unresolved
  (branch merge, don't forget to commit)
  $ aftermerge
  # cat f
  mergeresult
  # hg stat
  M f
  # hg resolve --list
  R f

- and $local is the file f:

  $ beforemerge
  [merge-tools]
  false.whatever=
  true.priority=1
  true.executable=cat
  # hg update -C 1
  $ hg merge -r 2 --config merge-tools.true.executable=echo --config merge-tools.true.args='mergeresult > f'
  merging f
  0 files updated, 1 files merged, 0 files removed, 0 files unresolved
  (branch merge, don't forget to commit)
  $ aftermerge
  # cat f
  mergeresult
  # hg stat
  M f
  # hg resolve --list
  R f

Merge with "echo mergeresult > $output" - the variable is a bit magic:

  $ beforemerge
  [merge-tools]
  false.whatever=
  true.priority=1
  true.executable=cat
  # hg update -C 1
  $ hg merge -r 2 --config merge-tools.true.executable=echo --config merge-tools.true.args='mergeresult > $output'
  merging f
  0 files updated, 1 files merged, 0 files removed, 0 files unresolved
  (branch merge, don't forget to commit)
  $ aftermerge
  # cat f
  mergeresult
  # hg stat
  M f
  # hg resolve --list
  R f

Merge using tool with a path that must be quoted:

  $ beforemerge
  [merge-tools]
  false.whatever=
  true.priority=1
  true.executable=cat
  # hg update -C 1
  $ cat <<EOF > 'my merge tool'
  > cat "\$1" "\$2" "\$3" > "\$4"
  > EOF
  $ hg --config merge-tools.true.executable='sh' \
  >    --config merge-tools.true.args='"./my merge tool" $base $local $other $output' \
  >    merge -r 2
  merging f
  0 files updated, 1 files merged, 0 files removed, 0 files unresolved
  (branch merge, don't forget to commit)
  $ rm -f 'my merge tool'
  $ aftermerge
  # cat f
  revision 0
  space
  revision 1
  space
  revision 2
  space
  # hg stat
  M f
  # hg resolve --list
  R f

Merge using a tool that supports labellocal, labelother, and labelbase, checking
that they're quoted properly as well. This is using the default 'basic'
mergemarkers even though ui.mergemarkers is 'detailed', so it's ignoring both
mergemarkertemplate settings:

  $ beforemerge
  [merge-tools]
  false.whatever=
  true.priority=1
  true.executable=cat
  # hg update -C 1
  $ cat <<EOF > printargs_merge_tool
  > while test \$# -gt 0; do echo arg: \"\$1\"; shift; done
  > EOF
  $ hg --config merge-tools.true.executable='sh' \
  >    --config merge-tools.true.args='./printargs_merge_tool ll:$labellocal lo: $labelother lb:$labelbase": "$base' \
  >    --config merge-tools.true.mergemarkertemplate='tooltmpl {short(node)}' \
  >    --config ui.mergemarkertemplate='uitmpl {rev}' \
  >    --config ui.mergemarkers=detailed \
  >    merge -r 2
  merging f
  arg: "ll:working copy"
  arg: "lo:"
  arg: "merge rev"
  arg: "lb:base: */f~base.*" (glob)
  0 files updated, 1 files merged, 0 files removed, 0 files unresolved
  (branch merge, don't forget to commit)
  $ rm -f 'printargs_merge_tool'

Same test with experimental.mergetempdirprefix set:

  $ beforemerge
  [merge-tools]
  false.whatever=
  true.priority=1
  true.executable=cat
  # hg update -C 1
  $ cat <<EOF > printargs_merge_tool
  > while test \$# -gt 0; do echo arg: \"\$1\"; shift; done
  > EOF
  $ hg --config experimental.mergetempdirprefix=$TESTTMP/hgmerge. \
  >    --config merge-tools.true.executable='sh' \
  >    --config merge-tools.true.args='./printargs_merge_tool ll:$labellocal lo: $labelother lb:$labelbase": "$base' \
  >    --config merge-tools.true.mergemarkertemplate='tooltmpl {short(node)}' \
  >    --config ui.mergemarkertemplate='uitmpl {rev}' \
  >    --config ui.mergemarkers=detailed \
  >    merge -r 2
  merging f
  arg: "ll:working copy"
  arg: "lo:"
  arg: "merge rev"
  arg: "lb:base: */hgmerge.*/f~base" (glob)
  0 files updated, 1 files merged, 0 files removed, 0 files unresolved
  (branch merge, don't forget to commit)
  $ rm -f 'printargs_merge_tool'

Merge using a tool that supports labellocal, labelother, and labelbase, checking
that they're quoted properly as well. This is using 'detailed' mergemarkers,
even though ui.mergemarkers is 'basic', and using the tool's
mergemarkertemplate:

  $ beforemerge
  [merge-tools]
  false.whatever=
  true.priority=1
  true.executable=cat
  # hg update -C 1
  $ cat <<EOF > printargs_merge_tool
  > while test \$# -gt 0; do echo arg: \"\$1\"; shift; done
  > EOF
  $ hg --config merge-tools.true.executable='sh' \
  >    --config merge-tools.true.args='./printargs_merge_tool ll:$labellocal lo: $labelother lb:$labelbase": "$base' \
  >    --config merge-tools.true.mergemarkers=detailed \
  >    --config merge-tools.true.mergemarkertemplate='tooltmpl {short(node)}' \
  >    --config ui.mergemarkertemplate='uitmpl {rev}' \
  >    --config ui.mergemarkers=basic \
  >    merge -r 2
  merging f
  arg: "ll:working copy: tooltmpl ef83787e2614"
  arg: "lo:"
  arg: "merge rev: tooltmpl 0185f4e0cf02"
  arg: "lb:base: */f~base.*" (glob)
  0 files updated, 1 files merged, 0 files removed, 0 files unresolved
  (branch merge, don't forget to commit)
  $ rm -f 'printargs_merge_tool'

The merge tool still gets labellocal and labelother as 'basic' even when
premerge=keep is used and has 'detailed' markers:

  $ beforemerge
  [merge-tools]
  false.whatever=
  true.priority=1
  true.executable=cat
  # hg update -C 1
  $ cat <<EOF > mytool
  > echo labellocal: \"\$1\"
  > echo labelother: \"\$2\"
  > echo "output (arg)": \"\$3\"
  > echo "output (contents)":
  > cat "\$3"
  > EOF
  $ hg --config merge-tools.true.executable='sh' \
  >    --config merge-tools.true.args='mytool $labellocal $labelother $output' \
  >    --config merge-tools.true.premerge=keep \
  >    --config merge-tools.true.mergemarkertemplate='tooltmpl {short(node)}' \
  >    --config ui.mergemarkertemplate='uitmpl {rev}' \
  >    --config ui.mergemarkers=detailed \
  >    merge -r 2
  merging f
  labellocal: "working copy"
  labelother: "merge rev"
  output (arg): "$TESTTMP/repo/f"
  output (contents):
  <<<<<<< working copy: uitmpl 1
  revision 1
  =======
  revision 2
  >>>>>>> merge rev:    uitmpl 2
  space
  0 files updated, 1 files merged, 0 files removed, 0 files unresolved
  (branch merge, don't forget to commit)
  $ rm -f 'mytool'

premerge=keep uses the *tool's* mergemarkertemplate if tool's
mergemarkers=detailed; labellocal and labelother also use the tool's template

  $ beforemerge
  [merge-tools]
  false.whatever=
  true.priority=1
  true.executable=cat
  # hg update -C 1
  $ cat <<EOF > mytool
  > echo labellocal: \"\$1\"
  > echo labelother: \"\$2\"
  > echo "output (arg)": \"\$3\"
  > echo "output (contents)":
  > cat "\$3"
  > EOF
  $ hg --config merge-tools.true.executable='sh' \
  >    --config merge-tools.true.args='mytool $labellocal $labelother $output' \
  >    --config merge-tools.true.premerge=keep \
  >    --config merge-tools.true.mergemarkers=detailed \
  >    --config merge-tools.true.mergemarkertemplate='tooltmpl {short(node)}' \
  >    --config ui.mergemarkertemplate='uitmpl {rev}' \
  >    --config ui.mergemarkers=detailed \
  >    merge -r 2
  merging f
  labellocal: "working copy: tooltmpl ef83787e2614"
  labelother: "merge rev: tooltmpl 0185f4e0cf02"
  output (arg): "$TESTTMP/repo/f"
  output (contents):
  <<<<<<< working copy: tooltmpl ef83787e2614
  revision 1
  =======
  revision 2
  >>>>>>> merge rev:    tooltmpl 0185f4e0cf02
  space
  0 files updated, 1 files merged, 0 files removed, 0 files unresolved
  (branch merge, don't forget to commit)
  $ rm -f 'mytool'

Issue3581: Merging a filename that needs to be quoted
(This test doesn't work on Windows filesystems even on Linux, so check
for Unix-like permission)

#if unix-permissions
  $ beforemerge
  [merge-tools]
  false.whatever=
  true.priority=1
  true.executable=cat
  # hg update -C 1
  $ echo "revision 5" > '"; exit 1; echo "'
  $ hg commit -Am "revision 5"
  adding "; exit 1; echo "
  warning: filename contains '"', which is reserved on Windows: '"; exit 1; echo "'
  $ hg update -C 1 > /dev/null
  $ echo "revision 6" > '"; exit 1; echo "'
  $ hg commit -Am "revision 6"
  adding "; exit 1; echo "
  warning: filename contains '"', which is reserved on Windows: '"; exit 1; echo "'
  created new head
  $ hg merge --config merge-tools.true.executable="true" -r 5
  merging "; exit 1; echo "
  0 files updated, 1 files merged, 0 files removed, 0 files unresolved
  (branch merge, don't forget to commit)
  $ hg update -C 1 > /dev/null

#else

Match the non-portable filename commits above for test stability

  $ hg import --bypass -q - << EOF
  > # HG changeset patch
  > revision 5
  > 
  > diff --git a/"; exit 1; echo " b/"; exit 1; echo "
  > new file mode 100644
  > --- /dev/null
  > +++ b/"; exit 1; echo "
  > @@ -0,0 +1,1 @@
  > +revision 5
  > EOF

  $ hg import --bypass -q - << EOF
  > # HG changeset patch
  > revision 6
  > 
  > diff --git a/"; exit 1; echo " b/"; exit 1; echo "
  > new file mode 100644
  > --- /dev/null
  > +++ b/"; exit 1; echo "
  > @@ -0,0 +1,1 @@
  > +revision 6
  > EOF

#endif

Merge post-processing

cat is a bad merge-tool and doesn't change:

  $ beforemerge
  [merge-tools]
  false.whatever=
  true.priority=1
  true.executable=cat
  # hg update -C 1
  $ hg merge -y -r 2 --config merge-tools.true.checkchanged=1
  merging f
  revision 1
  space
  revision 0
  space
  revision 2
  space
   output file f appears unchanged
  was merge successful (yn)? n
  merging f failed!
  0 files updated, 0 files merged, 0 files removed, 1 files unresolved
  use 'hg resolve' to retry unresolved file merges or 'hg merge --abort' to abandon
  [1]
  $ aftermerge
  # cat f
  revision 1
  space
  # hg stat
  M f
  ? f.orig
  # hg resolve --list
  U f

missingbinary is a merge-tool that doesn't exist:

  $ echo "missingbinary.executable=doesnotexist" >> .hg/hgrc
  $ beforemerge
  [merge-tools]
  false.whatever=
  true.priority=1
  true.executable=cat
  missingbinary.executable=doesnotexist
  # hg update -C 1
  $ hg merge -y -r 2 --config ui.merge=missingbinary
  couldn't find merge tool missingbinary (for pattern f)
  merging f
  couldn't find merge tool missingbinary (for pattern f)
  revision 1
  space
  revision 0
  space
  revision 2
  space
  0 files updated, 1 files merged, 0 files removed, 0 files unresolved
  (branch merge, don't forget to commit)

  $ hg update -q -C 1
  $ rm f

internal merge cannot handle symlinks and shouldn't try:

#if symlink

  $ ln -s symlink f
  $ hg commit -qm 'f is symlink'

#else

  $ hg import --bypass -q - << EOF
  > # HG changeset patch
  > f is symlink
  > 
  > diff --git a/f b/f
  > old mode 100644
  > new mode 120000
  > --- a/f
  > +++ b/f
  > @@ -1,2 +1,1 @@
  > -revision 1
  > -space
  > +symlink
  > \ No newline at end of file
  > EOF

Resolve 'other [destination] changed f which local [working copy] deleted' prompt
  $ hg up -q -C --config ui.interactive=True << EOF
  > c
  > EOF

#endif

  $ hg merge -r 2 --tool internal:merge
  merging f
  warning: internal :merge cannot merge symlinks for f
  warning: conflicts while merging f! (edit, then use 'hg resolve --mark')
  0 files updated, 0 files merged, 0 files removed, 1 files unresolved
  use 'hg resolve' to retry unresolved file merges or 'hg merge --abort' to abandon
  [1]

Verify naming of temporary files and that extension is preserved:

  $ hg update -q -C 1
  $ hg mv f f.txt
  $ hg ci -qm "f.txt"
  $ hg update -q -C 2
  $ hg merge -y -r tip --tool echo --config merge-tools.echo.args='$base $local $other $output'
  merging f and f.txt to f.txt
  */f~base.* */f~local.*.txt */f~other.*.txt $TESTTMP/repo/f.txt (glob)
  0 files updated, 1 files merged, 0 files removed, 0 files unresolved
  (branch merge, don't forget to commit)

Verify naming of temporary files and that extension is preserved
(experimental.mergetempdirprefix version):

  $ hg update -q -C 1
  $ hg mv f f.txt
  $ hg ci -qm "f.txt"
  $ hg update -q -C 2
  $ hg merge -y -r tip --tool echo \
  >    --config merge-tools.echo.args='$base $local $other $output' \
  >    --config experimental.mergetempdirprefix=$TESTTMP/hgmerge.
  merging f and f.txt to f.txt
  $TESTTMP/hgmerge.*/f~base $TESTTMP/hgmerge.*/f~local.txt $TESTTMP/hgmerge.*/f~other.txt $TESTTMP/repo/f.txt (glob)
  0 files updated, 1 files merged, 0 files removed, 0 files unresolved
  (branch merge, don't forget to commit)

Binary files capability checking

  $ hg update -q -C 0
  $ python <<EOF
  > with open('b', 'wb') as fp:
  >     fp.write(b'\x00\x01\x02\x03')
  > EOF
  $ hg add b
  $ hg commit -qm "add binary file (#1)"

  $ hg update -q -C 0
  $ python <<EOF
  > with open('b', 'wb') as fp:
  >     fp.write(b'\x03\x02\x01\x00')
  > EOF
  $ hg add b
  $ hg commit -qm "add binary file (#2)"

By default, binary files capability of internal merge tools is not
checked strictly.

(for merge-patterns, chosen unintentionally)

  $ hg merge 9 \
  > --config merge-patterns.b=:merge-other \
  > --config merge-patterns.re:[a-z]=:other
  warning: check merge-patterns configurations, if ':merge-other' for binary file 'b' is unintentional
  (see 'hg help merge-tools' for binary files capability)
  merging b
  warning: b looks like a binary file.
  0 files updated, 0 files merged, 0 files removed, 1 files unresolved
  use 'hg resolve' to retry unresolved file merges or 'hg merge --abort' to abandon
  [1]
  $ hg merge --abort -q

(for ui.merge, ignored unintentionally)

  $ hg merge 9 \
  > --config merge-tools.:other.binary=true \
  > --config ui.merge=:other
  tool :other (for pattern b) can't handle binary
  tool true can't handle binary
  tool :other can't handle binary
  tool false can't handle binary
  no tool found to merge b
  keep (l)ocal [working copy], take (o)ther [merge rev], or leave (u)nresolved for b? u
  0 files updated, 0 files merged, 0 files removed, 1 files unresolved
  use 'hg resolve' to retry unresolved file merges or 'hg merge --abort' to abandon
  [1]
  $ hg merge --abort -q

With merge.strict-capability-check=true, binary files capability of
internal merge tools is checked strictly.

  $ f --hexdump b
  b:
  0000: 03 02 01 00                                     |....|

(for merge-patterns)

  $ hg merge 9 --config merge.strict-capability-check=true \
  > --config merge-tools.:merge-other.binary=true \
  > --config merge-patterns.b=:merge-other \
  > --config merge-patterns.re:[a-z]=:other
  tool :merge-other (for pattern b) can't handle binary
  0 files updated, 1 files merged, 0 files removed, 0 files unresolved
  (branch merge, don't forget to commit)
  $ f --hexdump b
  b:
  0000: 00 01 02 03                                     |....|
  $ hg merge --abort -q

(for ui.merge)

  $ hg merge 9 --config merge.strict-capability-check=true \
  > --config ui.merge=:other
  0 files updated, 1 files merged, 0 files removed, 0 files unresolved
  (branch merge, don't forget to commit)
  $ f --hexdump b
  b:
  0000: 00 01 02 03                                     |....|
  $ hg merge --abort -q

Check that debugpicktool examines which merge tool is chosen for
specified file as expected

  $ beforemerge
  [merge-tools]
  false.whatever=
  true.priority=1
  true.executable=cat
  missingbinary.executable=doesnotexist
  # hg update -C 1

(default behavior: checking files in the working parent context)

  $ hg manifest
  f
  $ hg debugpickmergetool
  f = true

(-X/-I and file patterns limmit examination targets)

  $ hg debugpickmergetool -X f
  $ hg debugpickmergetool unknown
  unknown: no such file in rev ef83787e2614

(--changedelete emulates merging change and delete)

  $ hg debugpickmergetool --changedelete
  f = :prompt

(-r REV causes checking files in specified revision)

  $ hg manifest -r 8
  f.txt
  $ hg debugpickmergetool -r 8
  f.txt = true

#if symlink

(symlink causes chosing :prompt)

  $ hg debugpickmergetool -r 6d00b3726f6e
  f = :prompt

(by default, it is assumed that no internal merge tools has symlinks
capability)

  $ hg debugpickmergetool \
  > -r 6d00b3726f6e \
  > --config merge-tools.:merge-other.symlink=true \
  > --config merge-patterns.f=:merge-other \
  > --config merge-patterns.re:[f]=:merge-local \
  > --config merge-patterns.re:[a-z]=:other
  f = :prompt

  $ hg debugpickmergetool \
  > -r 6d00b3726f6e \
  > --config merge-tools.:other.symlink=true \
  > --config ui.merge=:other
  f = :prompt

(with strict-capability-check=true, actual symlink capabilities are
checked striclty)

  $ hg debugpickmergetool --config merge.strict-capability-check=true \
  > -r 6d00b3726f6e \
  > --config merge-tools.:merge-other.symlink=true \
  > --config merge-patterns.f=:merge-other \
  > --config merge-patterns.re:[f]=:merge-local \
  > --config merge-patterns.re:[a-z]=:other
  f = :other

  $ hg debugpickmergetool --config merge.strict-capability-check=true \
  > -r 6d00b3726f6e \
  > --config ui.merge=:other
  f = :other

  $ hg debugpickmergetool --config merge.strict-capability-check=true \
  > -r 6d00b3726f6e \
  > --config merge-tools.:merge-other.symlink=true \
  > --config ui.merge=:merge-other
  f = :prompt

#endif

(--verbose shows some configurations)

  $ hg debugpickmergetool --tool foobar -v
  with --tool 'foobar'
  f = foobar

  $ HGMERGE=false hg debugpickmergetool -v
  with HGMERGE='false'
  f = false

  $ hg debugpickmergetool --config ui.merge=false -v
  with ui.merge='false'
  f = false

(--debug shows errors detected intermediately)

  $ hg debugpickmergetool --config merge-patterns.f=true --config merge-tools.true.executable=nonexistentmergetool --debug f
  couldn't find merge tool true (for pattern f)
  couldn't find merge tool true
  f = false

  $ cd ..
