#require no-windows

ATTENTION: logtoprocess runs commands asynchronously. Be sure to append "| cat"
to hg commands, to wait for the output, if you want to test its output.
Otherwise the test will be flaky.

Test if logtoprocess correctly captures command-related log calls.

  $ hg init
  $ cat > $TESTTMP/foocommand.py << EOF
  > from __future__ import absolute_import
  > from mercurial import registrar
  > cmdtable = {}
  > command = registrar.command(cmdtable)
  > configtable = {}
  > configitem = registrar.configitem(configtable)
  > configitem('logtoprocess', 'foo',
  >     default=None,
  > )
  > @command(b'foo', [])
  > def foo(ui, repo):
  >     ui.log('foo', 'a message: %s\n', 'spam')
  > EOF
  $ cp $HGRCPATH $HGRCPATH.bak
  $ cat >> $HGRCPATH << EOF
  > [extensions]
  > logtoprocess=
  > foocommand=$TESTTMP/foocommand.py
  > [logtoprocess]
  > command=(echo 'logtoprocess command output:';
  >     echo "\$EVENT";
  >     echo "\$MSG1";
  >     echo "\$MSG2") > $TESTTMP/command.log
  > commandfinish=(echo 'logtoprocess commandfinish output:';
  >     echo "\$EVENT";
  >     echo "\$MSG1";
  >     echo "\$MSG2";
  >     echo "\$MSG3") > $TESTTMP/commandfinish.log
  > foo=(echo 'logtoprocess foo output:';
  >     echo "\$EVENT";
  >     echo "\$MSG1";
  >     echo "\$MSG2") > $TESTTMP/foo.log
  > EOF

Running a command triggers both a ui.log('command') and a
ui.log('commandfinish') call. The foo command also uses ui.log.

Use sort to avoid ordering issues between the various processes we spawn:
  $ hg foo
  $ sleep 1
  $ cat $TESTTMP/command.log | sort
  
  command
  foo
  foo
  logtoprocess command output:

#if no-chg
  $ cat $TESTTMP/commandfinish.log | sort
  
  0
  commandfinish
  foo
  foo exited 0 after * seconds (glob)
  logtoprocess commandfinish output:
  $ cat $TESTTMP/foo.log | sort
  
  a message: spam
  foo
  logtoprocess foo output:
  spam
#endif

Confirm that logging blocked time catches stdio properly:
  $ cp $HGRCPATH.bak $HGRCPATH
  $ cat >> $HGRCPATH << EOF
  > [extensions]
  > logtoprocess=
  > pager=
  > [logtoprocess]
  > uiblocked=echo "\$EVENT stdio \$OPT_STDIO_BLOCKED ms command \$OPT_COMMAND_DURATION ms" > $TESTTMP/uiblocked.log
  > [ui]
  > logblockedtimes=True
  > EOF

  $ hg log
  $ sleep 1
  $ cat $TESTTMP/uiblocked.log
  uiblocked stdio [0-9]+.[0-9]* ms command [0-9]+.[0-9]* ms (re)

Try to confirm that pager wait on logtoprocess:

Add a script that wait on a file to appears for 5 seconds, if it sees it touch
another file or die after 5 seconds. If the scripts is awaited by hg, the
script will die after the timeout before we could touch the file and the
resulting file will not exists. If not, we will touch the file and see it.

  $ cat > $TESTTMP/wait-output.sh << EOF
  > #!/bin/sh
  > for i in \`$TESTDIR/seq.py 50\`; do
  >   if [ -f "$TESTTMP/wait-for-touched" ];
  >   then
  >     touch "$TESTTMP/touched";
  >     break;
  >   else
  >     sleep 0.1;
  >   fi
  > done
  > EOF
  $ chmod +x $TESTTMP/wait-output.sh

  $ cat >> $HGRCPATH << EOF
  > [extensions]
  > logtoprocess=
  > pager=
  > [logtoprocess]
  > commandfinish=$TESTTMP/wait-output.sh
  > EOF
  $ hg version -q --pager=always
  Mercurial Distributed SCM (version *) (glob)
  $ touch $TESTTMP/wait-for-touched
  $ sleep 0.2
  $ test -f $TESTTMP/touched && echo "SUCCESS Pager is not waiting on ltp" || echo "FAIL Pager is waiting on ltp"
  SUCCESS Pager is not waiting on ltp
