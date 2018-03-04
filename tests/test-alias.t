  $ HGFOO=BAR; export HGFOO
  $ cat >> $HGRCPATH <<EOF
  > [alias]
  > # should clobber ci but not commit (issue2993)
  > ci = version
  > myinit = init
  > myinit:doc = This is my documented alias for init.
  > myinit:help = [OPTIONS] [BLA] [BLE]
  > mycommit = commit
  > mycommit:doc = This is my alias with only doc.
  > optionalrepo = showconfig alias.myinit
  > cleanstatus = status -c
  > cleanstatus:help = [ONLYHELPHERE]
  > unknown = bargle
  > ambiguous = s
  > recursive = recursive
  > disabled = email
  > nodefinition =
  > noclosingquotation = '
  > no--cwd = status --cwd elsewhere
  > no-R = status -R elsewhere
  > no--repo = status --repo elsewhere
  > no--repository = status --repository elsewhere
  > no--config = status --config a.config=1
  > mylog = log
  > lognull = log -r null
  > lognull:doc = Logs the null rev
  > lognull:help = foo bar baz
  > shortlog = log --template '{rev} {node|short} | {date|isodate}\n'
  > positional = log --template '{\$2} {\$1} | {date|isodate}\n'
  > dln = lognull --debug
  > recursivedoc = dln
  > recursivedoc:doc = Logs the null rev in debug mode
  > nousage = rollback
  > put = export -r 0 -o "\$FOO/%R.diff"
  > blank = !printf '\n'
  > self = !printf '\$0\n'
  > echoall = !printf '\$@\n'
  > echo1 = !printf '\$1\n'
  > echo2 = !printf '\$2\n'
  > echo13 = !printf '\$1 \$3\n'
  > echotokens = !printf "%s\n" "\$@"
  > count = !hg log -r "\$@" --template=. | wc -c | sed -e 's/ //g'
  > mcount = !hg log \$@ --template=. | wc -c | sed -e 's/ //g'
  > rt = root
  > tglog = log -G --template "{rev}:{node|short}: '{desc}' {branches}\n"
  > idalias = id
  > idaliaslong = id
  > idaliasshell = !echo test
  > parentsshell1 = !echo one
  > parentsshell2 = !echo two
  > escaped1 = !printf 'test\$\$test\n'
  > escaped2 = !sh -c 'echo "HGFOO is \$\$HGFOO"'
  > escaped3 = !sh -c 'echo "\$1 is \$\$\$1"'
  > escaped4 = !printf '\$\$0 \$\$@\n'
  > exit1 = !sh -c 'exit 1'
  > 
  > [defaults]
  > mylog = -q
  > lognull = -q
  > log = -v
  > EOF

basic

  $ hg myinit alias

help

  $ hg help -c | grep myinit
   myinit             This is my documented alias for init.
  $ hg help -c | grep mycommit
   mycommit           This is my alias with only doc.
  $ hg help -c | grep cleanstatus
   cleanstatus        show changed files in the working directory
  $ hg help -c | grep lognull
   lognull            Logs the null rev
  $ hg help -c | grep dln
   dln                Logs the null rev
  $ hg help -c | grep recursivedoc
   recursivedoc       Logs the null rev in debug mode
  $ hg help myinit
  hg myinit [OPTIONS] [BLA] [BLE]
  
  alias for: hg init
  
  This is my documented alias for init.
  
  defined by: * (glob)
  */* (glob) (?)
  */* (glob) (?)
  */* (glob) (?)
  
  options:
  
   -e --ssh CMD       specify ssh command to use
      --remotecmd CMD specify hg command to run on the remote side
      --insecure      do not verify server certificate (ignoring web.cacerts
                      config)
  
  (some details hidden, use --verbose to show complete help)

  $ hg help mycommit
  hg mycommit [OPTION]... [FILE]...
  
  alias for: hg commit
  
  This is my alias with only doc.
  
  defined by: * (glob)
  */* (glob) (?)
  */* (glob) (?)
  */* (glob) (?)
  
  options ([+] can be repeated):
  
   -A --addremove           mark new/missing files as added/removed before
                            committing
      --close-branch        mark a branch head as closed
      --amend               amend the parent of the working directory
   -s --secret              use the secret phase for committing
   -e --edit                invoke editor on commit messages
   -i --interactive         use interactive mode
   -I --include PATTERN [+] include names matching the given patterns
   -X --exclude PATTERN [+] exclude names matching the given patterns
   -m --message TEXT        use text as commit message
   -l --logfile FILE        read commit message from file
   -d --date DATE           record the specified date as commit date
   -u --user USER           record the specified user as committer
   -S --subrepos            recurse into subrepositories
  
  (some details hidden, use --verbose to show complete help)

  $ hg help cleanstatus
  hg cleanstatus [ONLYHELPHERE]
  
  alias for: hg status -c
  
  show changed files in the working directory
  
      Show status of files in the repository. If names are given, only files
      that match are shown. Files that are clean or ignored or the source of a
      copy/move operation, are not listed unless -c/--clean, -i/--ignored,
      -C/--copies or -A/--all are given. Unless options described with "show
      only ..." are given, the options -mardu are used.
  
      Option -q/--quiet hides untracked (unknown and ignored) files unless
      explicitly requested with -u/--unknown or -i/--ignored.
  
      Note:
         'hg status' may appear to disagree with diff if permissions have
         changed or a merge has occurred. The standard diff format does not
         report permission changes and diff only reports changes relative to one
         merge parent.
  
      If one revision is given, it is used as the base revision. If two
      revisions are given, the differences between them are shown. The --change
      option can also be used as a shortcut to list the changed files of a
      revision from its first parent.
  
      The codes used to show the status of files are:
  
        M = modified
        A = added
        R = removed
        C = clean
        ! = missing (deleted by non-hg command, but still tracked)
        ? = not tracked
        I = ignored
          = origin of the previous file (with --copies)
  
      Returns 0 on success.
  
  defined by: * (glob)
  */* (glob) (?)
  */* (glob) (?)
  */* (glob) (?)
  
  options ([+] can be repeated):
  
   -A --all                 show status of all files
   -m --modified            show only modified files
   -a --added               show only added files
   -r --removed             show only removed files
   -d --deleted             show only deleted (but tracked) files
   -c --clean               show only files without changes
   -u --unknown             show only unknown (not tracked) files
   -i --ignored             show only ignored files
   -n --no-status           hide status prefix
   -C --copies              show source of copied files
   -0 --print0              end filenames with NUL, for use with xargs
      --rev REV [+]         show difference from revision
      --change REV          list the changed files of a revision
   -I --include PATTERN [+] include names matching the given patterns
   -X --exclude PATTERN [+] exclude names matching the given patterns
   -S --subrepos            recurse into subrepositories
  
  (some details hidden, use --verbose to show complete help)

  $ hg help recursivedoc | head -n 5
  hg recursivedoc foo bar baz
  
  alias for: hg dln
  
  Logs the null rev in debug mode

unknown

  $ hg unknown
  abort: alias 'unknown' resolves to unknown command 'bargle'
  [255]
  $ hg help unknown
  alias 'unknown' resolves to unknown command 'bargle'


ambiguous

  $ hg ambiguous
  abort: alias 'ambiguous' resolves to ambiguous command 's'
  [255]
  $ hg help ambiguous
  alias 'ambiguous' resolves to ambiguous command 's'


recursive

  $ hg recursive
  abort: alias 'recursive' resolves to unknown command 'recursive'
  [255]
  $ hg help recursive
  alias 'recursive' resolves to unknown command 'recursive'


disabled

  $ hg disabled
  abort: alias 'disabled' resolves to unknown command 'email'
  ('email' is provided by 'patchbomb' extension)
  [255]
  $ hg help disabled
  alias 'disabled' resolves to unknown command 'email'
  
  'email' is provided by the following extension:
  
      patchbomb     command to send changesets as (a series of) patch emails
  
  (use 'hg help extensions' for information on enabling extensions)


no definition

  $ hg nodef
  abort: no definition for alias 'nodefinition'
  [255]
  $ hg help nodef
  no definition for alias 'nodefinition'


no closing quotation

  $ hg noclosing
  abort: error in definition for alias 'noclosingquotation': No closing quotation
  [255]
  $ hg help noclosing
  error in definition for alias 'noclosingquotation': No closing quotation

"--" in alias definition should be preserved

  $ hg --config alias.dash='cat --' -R alias dash -r0
  abort: -r0 not under root '$TESTTMP/alias'
  (consider using '--cwd alias')
  [255]

invalid options

  $ hg no--cwd
  abort: error in definition for alias 'no--cwd': --cwd may only be given on the command line
  [255]
  $ hg help no--cwd
  error in definition for alias 'no--cwd': --cwd may only be given on the
  command line
  $ hg no-R
  abort: error in definition for alias 'no-R': -R may only be given on the command line
  [255]
  $ hg help no-R
  error in definition for alias 'no-R': -R may only be given on the command line
  $ hg no--repo
  abort: error in definition for alias 'no--repo': --repo may only be given on the command line
  [255]
  $ hg help no--repo
  error in definition for alias 'no--repo': --repo may only be given on the
  command line
  $ hg no--repository
  abort: error in definition for alias 'no--repository': --repository may only be given on the command line
  [255]
  $ hg help no--repository
  error in definition for alias 'no--repository': --repository may only be given
  on the command line
  $ hg no--config
  abort: error in definition for alias 'no--config': --config may only be given on the command line
  [255]
  $ hg no --config alias.no='--repo elsewhere --cwd elsewhere status'
  abort: error in definition for alias 'no': --repo/--cwd may only be given on the command line
  [255]
  $ hg no --config alias.no='--repo elsewhere'
  abort: error in definition for alias 'no': --repo may only be given on the command line
  [255]

optional repository

#if no-outer-repo
  $ hg optionalrepo
  init
#endif
  $ cd alias
  $ cat > .hg/hgrc <<EOF
  > [alias]
  > myinit = init -q
  > EOF
  $ hg optionalrepo
  init -q

no usage

  $ hg nousage
  no rollback information available
  [1]

  $ echo foo > foo
  $ hg commit -Amfoo
  adding foo

infer repository

  $ cd ..

#if no-outer-repo
  $ hg shortlog alias/foo
  0 e63c23eaa88a | 1970-01-01 00:00 +0000
#endif

  $ cd alias

with opts

  $ hg cleanst
  C foo


with opts and whitespace

  $ hg shortlog
  0 e63c23eaa88a | 1970-01-01 00:00 +0000

positional arguments

  $ hg positional
  abort: too few arguments for command alias
  [255]
  $ hg positional a
  abort: too few arguments for command alias
  [255]
  $ hg positional 'node|short' rev
  0 e63c23eaa88a | 1970-01-01 00:00 +0000

interaction with defaults

  $ hg mylog
  0:e63c23eaa88a
  $ hg lognull
  -1:000000000000


properly recursive

  $ hg dln
  changeset:   -1:0000000000000000000000000000000000000000
  phase:       public
  parent:      -1:0000000000000000000000000000000000000000
  parent:      -1:0000000000000000000000000000000000000000
  manifest:    -1:0000000000000000000000000000000000000000
  user:        
  date:        Thu Jan 01 00:00:00 1970 +0000
  extra:       branch=default
  


path expanding

  $ FOO=`pwd` hg put
  $ cat 0.diff
  # HG changeset patch
  # User test
  # Date 0 0
  #      Thu Jan 01 00:00:00 1970 +0000
  # Node ID e63c23eaa88ae77967edcf4ea194d31167c478b0
  # Parent  0000000000000000000000000000000000000000
  foo
  
  diff -r 000000000000 -r e63c23eaa88a foo
  --- /dev/null	Thu Jan 01 00:00:00 1970 +0000
  +++ b/foo	Thu Jan 01 00:00:00 1970 +0000
  @@ -0,0 +1,1 @@
  +foo


simple shell aliases

  $ hg blank
  
  $ hg blank foo
  
  $ hg self
  self
  $ hg echoall
  
  $ hg echoall foo
  foo
  $ hg echoall 'test $2' foo
  test $2 foo
  $ hg echoall 'test $@' foo '$@'
  test $@ foo $@
  $ hg echoall 'test "$@"' foo '"$@"'
  test "$@" foo "$@"
  $ hg echo1 foo bar baz
  foo
  $ hg echo2 foo bar baz
  bar
  $ hg echo13 foo bar baz test
  foo baz
  $ hg echo2 foo
  
  $ hg echotokens
  
  $ hg echotokens foo 'bar $1 baz'
  foo
  bar $1 baz
  $ hg echotokens 'test $2' foo
  test $2
  foo
  $ hg echotokens 'test $@' foo '$@'
  test $@
  foo
  $@
  $ hg echotokens 'test "$@"' foo '"$@"'
  test "$@"
  foo
  "$@"
  $ echo bar > bar
  $ hg commit -qA -m bar
  $ hg count .
  1
  $ hg count 'branch(default)'
  2
  $ hg mcount -r '"branch(default)"'
  2

  $ hg tglog
  @  1:042423737847: 'bar'
  |
  o  0:e63c23eaa88a: 'foo'
  


shadowing

  $ hg i
  hg: command 'i' is ambiguous:
      idalias idaliaslong idaliasshell identify import incoming init
  [255]
  $ hg id
  042423737847 tip
  $ hg ida
  hg: command 'ida' is ambiguous:
      idalias idaliaslong idaliasshell
  [255]
  $ hg idalias
  042423737847 tip
  $ hg idaliasl
  042423737847 tip
  $ hg idaliass
  test
  $ hg parentsshell
  hg: command 'parentsshell' is ambiguous:
      parentsshell1 parentsshell2
  [255]
  $ hg parentsshell1
  one
  $ hg parentsshell2
  two


shell aliases with global options

  $ hg init sub
  $ cd sub
  $ hg count 'branch(default)'
  abort: unknown revision 'default'!
  0
  $ hg -v count 'branch(default)'
  abort: unknown revision 'default'!
  0
  $ hg -R .. count 'branch(default)'
  abort: unknown revision 'default'!
  0
  $ hg --cwd .. count 'branch(default)'
  2
  $ hg echoall --cwd ..
  

"--" passed to shell alias should be preserved

  $ hg --config alias.printf='!printf "$@"' printf '%s %s %s\n' -- --cwd ..
  -- --cwd ..

repo specific shell aliases

  $ cat >> .hg/hgrc <<EOF
  > [alias]
  > subalias = !echo sub
  > EOF
  $ cat >> ../.hg/hgrc <<EOF
  > [alias]
  > mainalias = !echo main
  > EOF


shell alias defined in current repo

  $ hg subalias
  sub
  $ hg --cwd .. subalias > /dev/null
  hg: unknown command 'subalias'
  (did you mean idalias?)
  [255]
  $ hg -R .. subalias > /dev/null
  hg: unknown command 'subalias'
  (did you mean idalias?)
  [255]


shell alias defined in other repo

  $ hg mainalias > /dev/null
  hg: unknown command 'mainalias'
  (did you mean idalias?)
  [255]
  $ hg -R .. mainalias
  main
  $ hg --cwd .. mainalias
  main

typos get useful suggestions
  $ hg --cwd .. manalias
  hg: unknown command 'manalias'
  (did you mean one of idalias, mainalias, manifest?)
  [255]

shell aliases with escaped $ chars

  $ hg escaped1
  test$test
  $ hg escaped2
  HGFOO is BAR
  $ hg escaped3 HGFOO
  HGFOO is BAR
  $ hg escaped4 test
  $0 $@

abbreviated name, which matches against both shell alias and the
command provided extension, should be aborted.

  $ cat >> .hg/hgrc <<EOF
  > [extensions]
  > hgext.rebase =
  > EOF
#if windows
  $ cat >> .hg/hgrc <<EOF
  > [alias]
  > rebate = !echo this is %HG_ARGS%
  > EOF
#else
  $ cat >> .hg/hgrc <<EOF
  > [alias]
  > rebate = !echo this is \$HG_ARGS
  > EOF
#endif
  $ cat >> .hg/hgrc <<EOF
  > rebate:doc = This is my alias which just prints something.
  > rebate:help = [MYARGS]
  > EOF
  $ hg reba
  hg: command 'reba' is ambiguous:
      rebase rebate
  [255]
  $ hg rebat
  this is rebate
  $ hg rebat --foo-bar
  this is rebate --foo-bar

help for a shell alias

  $ hg help -c | grep rebate
   rebate             This is my alias which just prints something.
  $ hg help rebate
  hg rebate [MYARGS]
  
  shell alias for: echo this is $HG_ARGS
  
  This is my alias which just prints something.
  
  defined by:* (glob)
  */* (glob) (?)
  */* (glob) (?)
  */* (glob) (?)
  
  (some details hidden, use --verbose to show complete help)

invalid arguments

  $ hg rt foo
  hg rt: invalid arguments
  hg rt
  
  alias for: hg root
  
  (use 'hg rt -h' to show more help)
  [255]

invalid global arguments for normal commands, aliases, and shell aliases

  $ hg --invalid root
  hg: option --invalid not recognized
  Mercurial Distributed SCM
  
  basic commands:
  
   add           add the specified files on the next commit
   annotate      show changeset information by line for each file
   clone         make a copy of an existing repository
   commit        commit the specified files or all outstanding changes
   diff          diff repository (or selected files)
   export        dump the header and diffs for one or more changesets
   forget        forget the specified files on the next commit
   init          create a new repository in the given directory
   log           show revision history of entire repository or files
   merge         merge another revision into working directory
   pull          pull changes from the specified source
   push          push changes to the specified destination
   remove        remove the specified files on the next commit
   serve         start stand-alone webserver
   status        show changed files in the working directory
   summary       summarize working directory state
   update        update working directory (or switch revisions)
  
  (use 'hg help' for the full list of commands or 'hg -v' for details)
  [255]
  $ hg --invalid mylog
  hg: option --invalid not recognized
  Mercurial Distributed SCM
  
  basic commands:
  
   add           add the specified files on the next commit
   annotate      show changeset information by line for each file
   clone         make a copy of an existing repository
   commit        commit the specified files or all outstanding changes
   diff          diff repository (or selected files)
   export        dump the header and diffs for one or more changesets
   forget        forget the specified files on the next commit
   init          create a new repository in the given directory
   log           show revision history of entire repository or files
   merge         merge another revision into working directory
   pull          pull changes from the specified source
   push          push changes to the specified destination
   remove        remove the specified files on the next commit
   serve         start stand-alone webserver
   status        show changed files in the working directory
   summary       summarize working directory state
   update        update working directory (or switch revisions)
  
  (use 'hg help' for the full list of commands or 'hg -v' for details)
  [255]
  $ hg --invalid blank
  hg: option --invalid not recognized
  Mercurial Distributed SCM
  
  basic commands:
  
   add           add the specified files on the next commit
   annotate      show changeset information by line for each file
   clone         make a copy of an existing repository
   commit        commit the specified files or all outstanding changes
   diff          diff repository (or selected files)
   export        dump the header and diffs for one or more changesets
   forget        forget the specified files on the next commit
   init          create a new repository in the given directory
   log           show revision history of entire repository or files
   merge         merge another revision into working directory
   pull          pull changes from the specified source
   push          push changes to the specified destination
   remove        remove the specified files on the next commit
   serve         start stand-alone webserver
   status        show changed files in the working directory
   summary       summarize working directory state
   update        update working directory (or switch revisions)
  
  (use 'hg help' for the full list of commands or 'hg -v' for details)
  [255]

environment variable changes in alias commands

  $ cat > $TESTTMP/expandalias.py <<EOF
  > import os
  > from mercurial import cmdutil, commands, registrar
  > cmdtable = {}
  > command = registrar.command(cmdtable)
  > @command(b'expandalias')
  > def expandalias(ui, repo, name):
  >     alias = cmdutil.findcmd(name, commands.table)[1][0]
  >     ui.write(b'%s args: %s\n' % (name, b' '.join(alias.args)))
  >     os.environ['COUNT'] = '2'
  >     ui.write(b'%s args: %s (with COUNT=2)\n' % (name, b' '.join(alias.args)))
  > EOF

  $ cat >> $HGRCPATH <<'EOF'
  > [extensions]
  > expandalias = $TESTTMP/expandalias.py
  > [alias]
  > showcount = log -T "$COUNT" -r .
  > EOF

  $ COUNT=1 hg expandalias showcount
  showcount args: -T 1 -r .
  showcount args: -T 2 -r . (with COUNT=2)

This should show id:

  $ hg --config alias.log='id' log
  000000000000 tip

This shouldn't:

  $ hg --config alias.log='id' history

  $ cd ../..

return code of command and shell aliases:

  $ hg mycommit -R alias
  nothing changed
  [1]
  $ hg exit1
  [1]

#if no-outer-repo
  $ hg root
  abort: no repository found in '$TESTTMP' (.hg not found)!
  [255]
  $ hg --config alias.hgroot='!hg root' hgroot
  abort: no repository found in '$TESTTMP' (.hg not found)!
  [255]
#endif
