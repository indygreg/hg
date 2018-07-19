Dummy extension simulating unsafe long running command
  $ cat > sleepext.py <<EOF
  > import itertools
  > import time
  > 
  > from mercurial.i18n import _
  > from mercurial import registrar
  > 
  > cmdtable = {}
  > command = registrar.command(cmdtable)
  > 
  > @command(b'sleep', [], _(b'TIME'), norepo=True)
  > def sleep(ui, sleeptime=b"1", **opts):
  >     with ui.uninterruptable():
  >         for _i in itertools.repeat(None, int(sleeptime)):
  >             time.sleep(1)
  >         ui.warn(b"end of unsafe operation\n")
  >     ui.warn(b"%s second(s) passed\n" % sleeptime)
  > EOF

Kludge to emulate timeout(1) which is not generally available.
  $ cat > timeout.py <<EOF
  > from __future__ import print_function
  > import argparse
  > import signal
  > import subprocess
  > import sys
  > import time
  > 
  > ap = argparse.ArgumentParser()
  > ap.add_argument('-s', nargs=1, default='SIGTERM')
  > ap.add_argument('duration', nargs=1, type=int)
  > ap.add_argument('argv', nargs='*')
  > opts = ap.parse_args()
  > try:
  >     sig = int(opts.s[0])
  > except ValueError:
  >     sname = opts.s[0]
  >     if not sname.startswith('SIG'):
  >         sname = 'SIG' + sname
  >     sig = getattr(signal, sname)
  > proc = subprocess.Popen(opts.argv)
  > time.sleep(opts.duration[0])
  > proc.poll()
  > if proc.returncode is None:
  >     proc.send_signal(sig)
  >     proc.wait()
  >     sys.exit(124)
  > EOF

Set up repository
  $ hg init repo
  $ cd repo
  $ cat >> $HGRCPATH << EOF
  > [extensions]
  > sleepext = ../sleepext.py
  > EOF

Test ctrl-c
  $ python $TESTTMP/timeout.py -s INT 1 hg sleep 2
  interrupted!
  [124]

  $ cat >> $HGRCPATH << EOF
  > [experimental]
  > nointerrupt = yes
  > EOF

  $ python $TESTTMP/timeout.py -s INT 1 hg sleep 2
  interrupted!
  [124]

  $ cat >> $HGRCPATH << EOF
  > [experimental]
  > nointerrupt-interactiveonly = False
  > EOF

  $ python $TESTTMP/timeout.py -s INT 1 hg sleep 2
  shutting down cleanly
  press ^C again to terminate immediately (dangerous)
  end of unsafe operation
  interrupted!
  [124]
