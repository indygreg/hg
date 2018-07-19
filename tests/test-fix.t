A script that implements uppercasing of specific lines in a file. This
approximates the behavior of code formatters well enough for our tests.

  $ UPPERCASEPY="$TESTTMP/uppercase.py"
  $ cat > $UPPERCASEPY <<EOF
  > import sys
  > from mercurial.utils.procutil import setbinary
  > setbinary(sys.stdin)
  > setbinary(sys.stdout)
  > lines = set()
  > for arg in sys.argv[1:]:
  >   if arg == 'all':
  >     sys.stdout.write(sys.stdin.read().upper())
  >     sys.exit(0)
  >   else:
  >     first, last = arg.split('-')
  >     lines.update(range(int(first), int(last) + 1))
  > for i, line in enumerate(sys.stdin.readlines()):
  >   if i + 1 in lines:
  >     sys.stdout.write(line.upper())
  >   else:
  >     sys.stdout.write(line)
  > EOF
  $ TESTLINES="foo\nbar\nbaz\nqux\n"
  $ printf $TESTLINES | $PYTHON $UPPERCASEPY
  foo
  bar
  baz
  qux
  $ printf $TESTLINES | $PYTHON $UPPERCASEPY all
  FOO
  BAR
  BAZ
  QUX
  $ printf $TESTLINES | $PYTHON $UPPERCASEPY 1-1
  FOO
  bar
  baz
  qux
  $ printf $TESTLINES | $PYTHON $UPPERCASEPY 1-2
  FOO
  BAR
  baz
  qux
  $ printf $TESTLINES | $PYTHON $UPPERCASEPY 2-3
  foo
  BAR
  BAZ
  qux
  $ printf $TESTLINES | $PYTHON $UPPERCASEPY 2-2 4-4
  foo
  BAR
  baz
  QUX

Set up the config with two simple fixers: one that fixes specific line ranges,
and one that always fixes the whole file. They both "fix" files by converting
letters to uppercase. They use different file extensions, so each test case can
choose which behavior to use by naming files.

  $ cat >> $HGRCPATH <<EOF
  > [extensions]
  > fix =
  > [experimental]
  > evolution.createmarkers=True
  > evolution.allowunstable=True
  > [fix]
  > uppercase-whole-file:command=$PYTHON $UPPERCASEPY all
  > uppercase-whole-file:fileset=set:**.whole
  > uppercase-changed-lines:command=$PYTHON $UPPERCASEPY
  > uppercase-changed-lines:linerange={first}-{last}
  > uppercase-changed-lines:fileset=set:**.changed
  > EOF

Help text for fix.

  $ hg help fix
  hg fix [OPTION]... [FILE]...
  
  rewrite file content in changesets or working directory
  
      Runs any configured tools to fix the content of files. Only affects files
      with changes, unless file arguments are provided. Only affects changed
      lines of files, unless the --whole flag is used. Some tools may always
      affect the whole file regardless of --whole.
  
      If revisions are specified with --rev, those revisions will be checked,
      and they may be replaced with new revisions that have fixed file content.
      It is desirable to specify all descendants of each specified revision, so
      that the fixes propagate to the descendants. If all descendants are fixed
      at the same time, no merging, rebasing, or evolution will be required.
  
      If --working-dir is used, files with uncommitted changes in the working
      copy will be fixed. If the checked-out revision is also fixed, the working
      directory will update to the replacement revision.
  
      When determining what lines of each file to fix at each revision, the
      whole set of revisions being fixed is considered, so that fixes to earlier
      revisions are not forgotten in later ones. The --base flag can be used to
      override this default behavior, though it is not usually desirable to do
      so.
  
  (use 'hg help -e fix' to show help for the fix extension)
  
  options ([+] can be repeated):
  
      --all          fix all non-public non-obsolete revisions
      --base REV [+] revisions to diff against (overrides automatic selection,
                     and applies to every revision being fixed)
   -r --rev REV [+]  revisions to fix
   -w --working-dir  fix the working directory
      --whole        always fix every line of a file
  
  (some details hidden, use --verbose to show complete help)

  $ hg help -e fix
  fix extension - rewrite file content in changesets or working copy
  (EXPERIMENTAL)
  
  Provides a command that runs configured tools on the contents of modified
  files, writing back any fixes to the working copy or replacing changesets.
  
  Here is an example configuration that causes 'hg fix' to apply automatic
  formatting fixes to modified lines in C++ code:
  
    [fix]
    clang-format:command=clang-format --assume-filename={rootpath}
    clang-format:linerange=--lines={first}:{last}
    clang-format:fileset=set:**.cpp or **.hpp
  
  The :command suboption forms the first part of the shell command that will be
  used to fix a file. The content of the file is passed on standard input, and
  the fixed file content is expected on standard output. If there is any output
  on standard error, the file will not be affected. Some values may be
  substituted into the command:
  
    {rootpath}  The path of the file being fixed, relative to the repo root
    {basename}  The name of the file being fixed, without the directory path
  
  If the :linerange suboption is set, the tool will only be run if there are
  changed lines in a file. The value of this suboption is appended to the shell
  command once for every range of changed lines in the file. Some values may be
  substituted into the command:
  
    {first}   The 1-based line number of the first line in the modified range
    {last}    The 1-based line number of the last line in the modified range
  
  The :fileset suboption determines which files will be passed through each
  configured tool. See 'hg help fileset' for possible values. If there are file
  arguments to 'hg fix', the intersection of these filesets is used.
  
  There is also a configurable limit for the maximum size of file that will be
  processed by 'hg fix':
  
    [fix]
    maxfilesize=2MB
  
  list of commands:
  
   fix           rewrite file content in changesets or working directory
  
  (use 'hg help -v -e fix' to show built-in aliases and global options)

There is no default behavior in the absence of --rev and --working-dir.

  $ hg init badusage
  $ cd badusage

  $ hg fix
  abort: no changesets specified
  (use --rev or --working-dir)
  [255]
  $ hg fix --whole
  abort: no changesets specified
  (use --rev or --working-dir)
  [255]
  $ hg fix --base 0
  abort: no changesets specified
  (use --rev or --working-dir)
  [255]

Fixing a public revision isn't allowed. It should abort early enough that
nothing happens, even to the working directory.

  $ printf "hello\n" > hello.whole
  $ hg commit -Aqm "hello"
  $ hg phase -r 0 --public
  $ hg fix -r 0
  abort: can't fix immutable changeset 0:6470986d2e7b
  [255]
  $ hg fix -r 0 --working-dir
  abort: can't fix immutable changeset 0:6470986d2e7b
  [255]
  $ hg cat -r tip hello.whole
  hello
  $ cat hello.whole
  hello

  $ cd ..

Fixing a clean working directory should do nothing. Even the --whole flag
shouldn't cause any clean files to be fixed. Specifying a clean file explicitly
should only fix it if the fixer always fixes the whole file. The combination of
an explicit filename and --whole should format the entire file regardless.

  $ hg init fixcleanwdir
  $ cd fixcleanwdir

  $ printf "hello\n" > hello.changed
  $ printf "world\n" > hello.whole
  $ hg commit -Aqm "foo"
  $ hg fix --working-dir
  $ hg diff
  $ hg fix --working-dir --whole
  $ hg diff
  $ hg fix --working-dir *
  $ cat *
  hello
  WORLD
  $ hg revert --all --no-backup
  reverting hello.whole
  $ hg fix --working-dir * --whole
  $ cat *
  HELLO
  WORLD

The same ideas apply to fixing a revision, so we create a revision that doesn't
modify either of the files in question and try fixing it. This also tests that
we ignore a file that doesn't match any configured fixer.

  $ hg revert --all --no-backup
  reverting hello.changed
  reverting hello.whole
  $ printf "unimportant\n" > some.file
  $ hg commit -Aqm "some other file"

  $ hg fix -r .
  $ hg cat -r tip *
  hello
  world
  unimportant
  $ hg fix -r . --whole
  $ hg cat -r tip *
  hello
  world
  unimportant
  $ hg fix -r . *
  $ hg cat -r tip *
  hello
  WORLD
  unimportant
  $ hg fix -r . * --whole --config experimental.evolution.allowdivergence=true
  2 new content-divergent changesets
  $ hg cat -r tip *
  HELLO
  WORLD
  unimportant

  $ cd ..

Fixing the working directory should still work if there are no revisions.

  $ hg init norevisions
  $ cd norevisions

  $ printf "something\n" > something.whole
  $ hg add
  adding something.whole
  $ hg fix --working-dir
  $ cat something.whole
  SOMETHING

  $ cd ..

Test the effect of fixing the working directory for each possible status, with
and without providing explicit file arguments.

  $ hg init implicitlyfixstatus
  $ cd implicitlyfixstatus

  $ printf "modified\n" > modified.whole
  $ printf "removed\n" > removed.whole
  $ printf "deleted\n" > deleted.whole
  $ printf "clean\n" > clean.whole
  $ printf "ignored.whole" > .hgignore
  $ hg commit -Aqm "stuff"

  $ printf "modified!!!\n" > modified.whole
  $ printf "unknown\n" > unknown.whole
  $ printf "ignored\n" > ignored.whole
  $ printf "added\n" > added.whole
  $ hg add added.whole
  $ hg remove removed.whole
  $ rm deleted.whole

  $ hg status --all
  M modified.whole
  A added.whole
  R removed.whole
  ! deleted.whole
  ? unknown.whole
  I ignored.whole
  C .hgignore
  C clean.whole

  $ hg fix --working-dir

  $ hg status --all
  M modified.whole
  A added.whole
  R removed.whole
  ! deleted.whole
  ? unknown.whole
  I ignored.whole
  C .hgignore
  C clean.whole

  $ cat *.whole
  ADDED
  clean
  ignored
  MODIFIED!!!
  unknown

  $ printf "modified!!!\n" > modified.whole
  $ printf "added\n" > added.whole
  $ hg fix --working-dir *.whole

  $ hg status --all
  M clean.whole
  M modified.whole
  A added.whole
  R removed.whole
  ! deleted.whole
  ? unknown.whole
  I ignored.whole
  C .hgignore

It would be better if this also fixed the unknown file.
  $ cat *.whole
  ADDED
  CLEAN
  ignored
  MODIFIED!!!
  unknown

  $ cd ..

Test that incremental fixing works on files with additions, deletions, and
changes in multiple line ranges. Note that deletions do not generally cause
neighboring lines to be fixed, so we don't return a line range for purely
deleted sections. In the future we should support a :deletion config that
allows fixers to know where deletions are located.

  $ hg init incrementalfixedlines
  $ cd incrementalfixedlines

  $ printf "a\nb\nc\nd\ne\nf\ng\n" > foo.txt
  $ hg commit -Aqm "foo"
  $ printf "zz\na\nc\ndd\nee\nff\nf\ngg\n" > foo.txt

  $ hg --config "fix.fail:command=echo" \
  >    --config "fix.fail:linerange={first}:{last}" \
  >    --config "fix.fail:fileset=foo.txt" \
  >    fix --working-dir
  $ cat foo.txt
  1:1 4:6 8:8

  $ cd ..

Test that --whole fixes all lines regardless of the diffs present.

  $ hg init wholeignoresdiffs
  $ cd wholeignoresdiffs

  $ printf "a\nb\nc\nd\ne\nf\ng\n" > foo.changed
  $ hg commit -Aqm "foo"
  $ printf "zz\na\nc\ndd\nee\nff\nf\ngg\n" > foo.changed
  $ hg fix --working-dir --whole
  $ cat foo.changed
  ZZ
  A
  C
  DD
  EE
  FF
  F
  GG

  $ cd ..

We should do nothing with symlinks, and their targets should be unaffected. Any
other behavior would be more complicated to implement and harder to document.

#if symlink
  $ hg init dontmesswithsymlinks
  $ cd dontmesswithsymlinks

  $ printf "hello\n" > hello.whole
  $ ln -s hello.whole hellolink
  $ hg add
  adding hello.whole
  adding hellolink
  $ hg fix --working-dir hellolink
  $ hg status
  A hello.whole
  A hellolink

  $ cd ..
#endif

We should allow fixers to run on binary files, even though this doesn't sound
like a common use case. There's not much benefit to disallowing it, and users
can add "and not binary()" to their filesets if needed. The Mercurial
philosophy is generally to not handle binary files specially anyway.

  $ hg init cantouchbinaryfiles
  $ cd cantouchbinaryfiles

  $ printf "hello\0\n" > hello.whole
  $ hg add
  adding hello.whole
  $ hg fix --working-dir 'set:binary()'
  $ cat hello.whole
  HELLO\x00 (esc)

  $ cd ..

We have a config for the maximum size of file we will attempt to fix. This can
be helpful to avoid running unsuspecting fixer tools on huge inputs, which
could happen by accident without a well considered configuration. A more
precise configuration could use the size() fileset function if one global limit
is undesired.

  $ hg init maxfilesize
  $ cd maxfilesize

  $ printf "this file is huge\n" > hello.whole
  $ hg add
  adding hello.whole
  $ hg --config fix.maxfilesize=10 fix --working-dir
  ignoring file larger than 10 bytes: hello.whole
  $ cat hello.whole
  this file is huge

  $ cd ..

If we specify a file to fix, other files should be left alone, even if they
have changes.

  $ hg init fixonlywhatitellyouto
  $ cd fixonlywhatitellyouto

  $ printf "fix me!\n" > fixme.whole
  $ printf "not me.\n" > notme.whole
  $ hg add
  adding fixme.whole
  adding notme.whole
  $ hg fix --working-dir fixme.whole
  $ cat *.whole
  FIX ME!
  not me.

  $ cd ..

Specifying a directory name should fix all its files and subdirectories.

  $ hg init fixdirectory
  $ cd fixdirectory

  $ mkdir -p dir1/dir2
  $ printf "foo\n" > foo.whole
  $ printf "bar\n" > dir1/bar.whole
  $ printf "baz\n" > dir1/dir2/baz.whole
  $ hg add
  adding dir1/bar.whole
  adding dir1/dir2/baz.whole
  adding foo.whole
  $ hg fix --working-dir dir1
  $ cat foo.whole dir1/bar.whole dir1/dir2/baz.whole
  foo
  BAR
  BAZ

  $ cd ..

Fixing a file in the working directory that needs no fixes should not actually
write back to the file, so for example the mtime shouldn't change.

  $ hg init donttouchunfixedfiles
  $ cd donttouchunfixedfiles

  $ printf "NO FIX NEEDED\n" > foo.whole
  $ hg add
  adding foo.whole
  $ cp -p foo.whole foo.whole.orig
  $ cp -p foo.whole.orig foo.whole
  $ sleep 2 # mtime has a resolution of one or two seconds.
  $ hg fix --working-dir
  $ f foo.whole.orig --newer foo.whole
  foo.whole.orig: newer than foo.whole

  $ cd ..

When a fixer prints to stderr, we assume that it has failed. We should show the
error messages to the user, and we should not let the failing fixer affect the
file it was fixing (many code formatters might emit error messages on stderr
and nothing on stdout, which would cause us the clear the file). We show the
user which fixer failed and which revision, but we assume that the fixer will
print the filename if it is relevant.

  $ hg init showstderr
  $ cd showstderr

  $ printf "hello\n" > hello.txt
  $ hg add
  adding hello.txt
  $ cat >> $TESTTMP/cmd.sh <<'EOF'
  > printf 'HELLO\n'
  > printf "$@: some\nerror" >&2
  > EOF
  $ hg --config "fix.fail:command=sh $TESTTMP/cmd.sh {rootpath}" \
  >    --config "fix.fail:fileset=hello.txt" \
  >    fix --working-dir
  [wdir] fail: hello.txt: some
  [wdir] fail: error
  $ cat hello.txt
  hello

  $ cd ..

Fixing the working directory and its parent revision at the same time should
check out the replacement revision for the parent. This prevents any new
uncommitted changes from appearing. We test this for a clean working directory
and a dirty one. In both cases, all lines/files changed since the grandparent
will be fixed. The grandparent is the "baserev" for both the parent and the
working copy.

  $ hg init fixdotandcleanwdir
  $ cd fixdotandcleanwdir

  $ printf "hello\n" > hello.whole
  $ printf "world\n" > world.whole
  $ hg commit -Aqm "the parent commit"

  $ hg parents --template '{rev} {desc}\n'
  0 the parent commit
  $ hg fix --working-dir -r .
  $ hg parents --template '{rev} {desc}\n'
  1 the parent commit
  $ hg cat -r . *.whole
  HELLO
  WORLD
  $ cat *.whole
  HELLO
  WORLD
  $ hg status

  $ cd ..

Same test with a dirty working copy.

  $ hg init fixdotanddirtywdir
  $ cd fixdotanddirtywdir

  $ printf "hello\n" > hello.whole
  $ printf "world\n" > world.whole
  $ hg commit -Aqm "the parent commit"

  $ printf "hello,\n" > hello.whole
  $ printf "world!\n" > world.whole

  $ hg parents --template '{rev} {desc}\n'
  0 the parent commit
  $ hg fix --working-dir -r .
  $ hg parents --template '{rev} {desc}\n'
  1 the parent commit
  $ hg cat -r . *.whole
  HELLO
  WORLD
  $ cat *.whole
  HELLO,
  WORLD!
  $ hg status
  M hello.whole
  M world.whole

  $ cd ..

When we have a chain of commits that change mutually exclusive lines of code,
we should be able to do incremental fixing that causes each commit in the chain
to include fixes made to the previous commits. This prevents children from
backing out the fixes made in their parents. A dirty working directory is
conceptually similar to another commit in the chain.

  $ hg init incrementallyfixchain
  $ cd incrementallyfixchain

  $ cat > file.changed <<EOF
  > first
  > second
  > third
  > fourth
  > fifth
  > EOF
  $ hg commit -Aqm "the common ancestor (the baserev)"
  $ cat > file.changed <<EOF
  > first (changed)
  > second
  > third
  > fourth
  > fifth
  > EOF
  $ hg commit -Aqm "the first commit to fix"
  $ cat > file.changed <<EOF
  > first (changed)
  > second
  > third (changed)
  > fourth
  > fifth
  > EOF
  $ hg commit -Aqm "the second commit to fix"
  $ cat > file.changed <<EOF
  > first (changed)
  > second
  > third (changed)
  > fourth
  > fifth (changed)
  > EOF

  $ hg fix -r . -r '.^' --working-dir

  $ hg parents --template '{rev}\n'
  4
  $ hg cat -r '.^^' file.changed
  first
  second
  third
  fourth
  fifth
  $ hg cat -r '.^' file.changed
  FIRST (CHANGED)
  second
  third
  fourth
  fifth
  $ hg cat -r . file.changed
  FIRST (CHANGED)
  second
  THIRD (CHANGED)
  fourth
  fifth
  $ cat file.changed
  FIRST (CHANGED)
  second
  THIRD (CHANGED)
  fourth
  FIFTH (CHANGED)

  $ cd ..

If we incrementally fix a merge commit, we should fix any lines that changed
versus either parent. You could imagine only fixing the intersection or some
other subset, but this is necessary if either parent is being fixed. It
prevents us from forgetting fixes made in either parent.

  $ hg init incrementallyfixmergecommit
  $ cd incrementallyfixmergecommit

  $ printf "a\nb\nc\n" > file.changed
  $ hg commit -Aqm "ancestor"

  $ printf "aa\nb\nc\n" > file.changed
  $ hg commit -m "change a"

  $ hg checkout '.^'
  1 files updated, 0 files merged, 0 files removed, 0 files unresolved
  $ printf "a\nb\ncc\n" > file.changed
  $ hg commit -m "change c"
  created new head

  $ hg merge
  merging file.changed
  0 files updated, 1 files merged, 0 files removed, 0 files unresolved
  (branch merge, don't forget to commit)
  $ hg commit -m "merge"
  $ hg cat -r . file.changed
  aa
  b
  cc

  $ hg fix -r . --working-dir
  $ hg cat -r . file.changed
  AA
  b
  CC

  $ cd ..

Abort fixing revisions if there is an unfinished operation. We don't want to
make things worse by editing files or stripping/obsoleting things. Also abort
fixing the working directory if there are unresolved merge conflicts.

  $ hg init abortunresolved
  $ cd abortunresolved

  $ echo "foo1" > foo.whole
  $ hg commit -Aqm "foo 1"

  $ hg update null
  0 files updated, 0 files merged, 1 files removed, 0 files unresolved
  $ echo "foo2" > foo.whole
  $ hg commit -Aqm "foo 2"

  $ hg --config extensions.rebase= rebase -r 1 -d 0
  rebasing 1:c3b6dc0e177a "foo 2" (tip)
  merging foo.whole
  warning: conflicts while merging foo.whole! (edit, then use 'hg resolve --mark')
  unresolved conflicts (see hg resolve, then hg rebase --continue)
  [1]

  $ hg --config extensions.rebase= fix --working-dir
  abort: unresolved conflicts
  (use 'hg resolve')
  [255]

  $ hg --config extensions.rebase= fix -r .
  abort: rebase in progress
  (use 'hg rebase --continue' or 'hg rebase --abort')
  [255]

When fixing a file that was renamed, we should diff against the source of the
rename for incremental fixing and we should correctly reproduce the rename in
the replacement revision.

  $ hg init fixrenamecommit
  $ cd fixrenamecommit

  $ printf "a\nb\nc\n" > source.changed
  $ hg commit -Aqm "source revision"
  $ hg move source.changed dest.changed
  $ printf "a\nb\ncc\n" > dest.changed
  $ hg commit -m "dest revision"

  $ hg fix -r .
  $ hg log -r tip --copies --template "{file_copies}\n"
  dest.changed (source.changed)
  $ hg cat -r tip dest.changed
  a
  b
  CC

  $ cd ..

When fixing revisions that remove files we must ensure that the replacement
actually removes the file, whereas it could accidentally leave it unchanged or
write an empty string to it.

  $ hg init fixremovedfile
  $ cd fixremovedfile

  $ printf "foo\n" > foo.whole
  $ printf "bar\n" > bar.whole
  $ hg commit -Aqm "add files"
  $ hg remove bar.whole
  $ hg commit -m "remove file"
  $ hg status --change .
  R bar.whole
  $ hg fix -r . foo.whole
  $ hg status --change tip
  M foo.whole
  R bar.whole

  $ cd ..

If fixing a revision finds no fixes to make, no replacement revision should be
created.

  $ hg init nofixesneeded
  $ cd nofixesneeded

  $ printf "FOO\n" > foo.whole
  $ hg commit -Aqm "add file"
  $ hg log --template '{rev}\n'
  0
  $ hg fix -r .
  $ hg log --template '{rev}\n'
  0

  $ cd ..

If fixing a commit reverts all the changes in the commit, we replace it with a
commit that changes no files.

  $ hg init nochangesleft
  $ cd nochangesleft

  $ printf "FOO\n" > foo.whole
  $ hg commit -Aqm "add file"
  $ printf "foo\n" > foo.whole
  $ hg commit -m "edit file"
  $ hg status --change .
  M foo.whole
  $ hg fix -r .
  $ hg status --change tip

  $ cd ..

If we fix a parent and child revision together, the child revision must be
replaced if the parent is replaced, even if the diffs of the child needed no
fixes. However, we're free to not replace revisions that need no fixes and have
no ancestors that are replaced.

  $ hg init mustreplacechild
  $ cd mustreplacechild

  $ printf "FOO\n" > foo.whole
  $ hg commit -Aqm "add foo"
  $ printf "foo\n" > foo.whole
  $ hg commit -m "edit foo"
  $ printf "BAR\n" > bar.whole
  $ hg commit -Aqm "add bar"

  $ hg log --graph --template '{node|shortest} {files}'
  @  bc05 bar.whole
  |
  o  4fd2 foo.whole
  |
  o  f9ac foo.whole
  
  $ hg fix -r 0:2
  $ hg log --graph --template '{node|shortest} {files}'
  o  3801 bar.whole
  |
  o  38cc
  |
  | @  bc05 bar.whole
  | |
  | x  4fd2 foo.whole
  |/
  o  f9ac foo.whole
  

  $ cd ..

It's also possible that the child needs absolutely no changes, but we still
need to replace it to update its parent. If we skipped replacing the child
because it had no file content changes, it would become an orphan for no good
reason.

  $ hg init mustreplacechildevenifnop
  $ cd mustreplacechildevenifnop

  $ printf "Foo\n" > foo.whole
  $ hg commit -Aqm "add a bad foo"
  $ printf "FOO\n" > foo.whole
  $ hg commit -m "add a good foo"
  $ hg fix -r . -r '.^'
  $ hg log --graph --template '{rev} {desc}'
  o  3 add a good foo
  |
  o  2 add a bad foo
  
  @  1 add a good foo
  |
  x  0 add a bad foo
  

  $ cd ..

Similar to the case above, the child revision may become empty as a result of
fixing its parent. We should still create an empty replacement child.
TODO: determine how this should interact with ui.allowemptycommit given that
the empty replacement could have children.

  $ hg init mustreplacechildevenifempty
  $ cd mustreplacechildevenifempty

  $ printf "foo\n" > foo.whole
  $ hg commit -Aqm "add foo"
  $ printf "Foo\n" > foo.whole
  $ hg commit -m "edit foo"
  $ hg fix -r . -r '.^'
  $ hg log --graph --template '{rev} {desc}\n' --stat
  o  3 edit foo
  |
  o  2 add foo
      foo.whole |  1 +
      1 files changed, 1 insertions(+), 0 deletions(-)
  
  @  1 edit foo
  |   foo.whole |  2 +-
  |   1 files changed, 1 insertions(+), 1 deletions(-)
  |
  x  0 add foo
      foo.whole |  1 +
      1 files changed, 1 insertions(+), 0 deletions(-)
  

  $ cd ..

Fixing a secret commit should replace it with another secret commit.

  $ hg init fixsecretcommit
  $ cd fixsecretcommit

  $ printf "foo\n" > foo.whole
  $ hg commit -Aqm "add foo" --secret
  $ hg fix -r .
  $ hg log --template '{rev} {phase}\n'
  1 secret
  0 secret

  $ cd ..

We should also preserve phase when fixing a draft commit while the user has
their default set to secret.

  $ hg init respectphasesnewcommit
  $ cd respectphasesnewcommit

  $ printf "foo\n" > foo.whole
  $ hg commit -Aqm "add foo"
  $ hg --config phases.newcommit=secret fix -r .
  $ hg log --template '{rev} {phase}\n'
  1 draft
  0 draft

  $ cd ..

Debug output should show what fixer commands are being subprocessed, which is
useful for anyone trying to set up a new config.

  $ hg init debugoutput
  $ cd debugoutput

  $ printf "foo\nbar\nbaz\n" > foo.changed
  $ hg commit -Aqm "foo"
  $ printf "Foo\nbar\nBaz\n" > foo.changed
  $ hg --debug fix --working-dir
  subprocess: * $TESTTMP/uppercase.py 1-1 3-3 (glob)

  $ cd ..

Fixing an obsolete revision can cause divergence, so we abort unless the user
configures to allow it. This is not yet smart enough to know whether there is a
successor, but even then it is not likely intentional or idiomatic to fix an
obsolete revision.

  $ hg init abortobsoleterev
  $ cd abortobsoleterev

  $ printf "foo\n" > foo.changed
  $ hg commit -Aqm "foo"
  $ hg debugobsolete `hg parents --template '{node}'`
  obsoleted 1 changesets
  $ hg --hidden fix -r 0
  abort: fixing obsolete revision could cause divergence
  [255]

  $ hg --hidden fix -r 0 --config experimental.evolution.allowdivergence=true
  $ hg cat -r tip foo.changed
  FOO

  $ cd ..

Test all of the available substitution values for fixer commands.

  $ hg init substitution
  $ cd substitution

  $ mkdir foo
  $ printf "hello\ngoodbye\n" > foo/bar
  $ hg add
  adding foo/bar
  $ hg --config "fix.fail:command=printf '%s\n' '{rootpath}' '{basename}'" \
  >    --config "fix.fail:linerange='{first}' '{last}'" \
  >    --config "fix.fail:fileset=foo/bar" \
  >    fix --working-dir
  $ cat foo/bar
  foo/bar
  bar
  1
  2

  $ cd ..

The --base flag should allow picking the revisions to diff against for changed
files and incremental line formatting.

  $ hg init baseflag
  $ cd baseflag

  $ printf "one\ntwo\n" > foo.changed
  $ printf "bar\n" > bar.changed
  $ hg commit -Aqm "first"
  $ printf "one\nTwo\n" > foo.changed
  $ hg commit -m "second"
  $ hg fix -w --base .
  $ hg status
  $ hg fix -w --base null
  $ cat foo.changed
  ONE
  TWO
  $ cat bar.changed
  BAR

  $ cd ..

If the user asks to fix the parent of another commit, they are asking to create
an orphan. We must respect experimental.evolution.allowunstable.

  $ hg init allowunstable
  $ cd allowunstable

  $ printf "one\n" > foo.whole
  $ hg commit -Aqm "first"
  $ printf "two\n" > foo.whole
  $ hg commit -m "second"
  $ hg --config experimental.evolution.allowunstable=False fix -r '.^'
  abort: can only fix a changeset together with all its descendants
  [255]
  $ hg fix -r '.^'
  1 new orphan changesets
  $ hg cat -r 2 foo.whole
  ONE

  $ cd ..

The --base flag affects the set of files being fixed. So while the --whole flag
makes the base irrelevant for changed line ranges, it still changes the
meaning and effect of the command. In this example, no files or lines are fixed
until we specify the base, but then we do fix unchanged lines.

  $ hg init basewhole
  $ cd basewhole
  $ printf "foo1\n" > foo.changed
  $ hg commit -Aqm "first"
  $ printf "foo2\n" >> foo.changed
  $ printf "bar\n" > bar.changed
  $ hg commit -Aqm "second"

  $ hg fix --working-dir --whole
  $ cat *.changed
  bar
  foo1
  foo2

  $ hg fix --working-dir --base 0 --whole
  $ cat *.changed
  BAR
  FOO1
  FOO2

  $ cd ..
