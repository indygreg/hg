# blackbox.py - log repository events to a file for post-mortem debugging
#
# Copyright 2010 Nicolas Dumazet
# Copyright 2013 Facebook, Inc.
#
# This software may be used and distributed according to the terms of the
# GNU General Public License version 2 or any later version.

"""log repository events to a blackbox for debugging

Logs event information to .hg/blackbox.log to help debug and diagnose problems.
The events that get logged can be configured via the blackbox.track config key.

Examples::

  [blackbox]
  track = *
  # dirty is *EXPENSIVE* (slow);
  # each log entry indicates `+` if the repository is dirty, like :hg:`id`.
  dirty = True
  # record the source of log messages
  logsource = True

  [blackbox]
  track = command, commandfinish, commandexception, exthook, pythonhook

  [blackbox]
  track = incoming

  [blackbox]
  # limit the size of a log file
  maxsize = 1.5 MB
  # rotate up to N log files when the current one gets too big
  maxfiles = 3

  [blackbox]
  # Include nanoseconds in log entries with %f (see Python function
  # datetime.datetime.strftime)
  date-format = '%Y-%m-%d @ %H:%M:%S.%f'

"""

from __future__ import absolute_import

import errno
import re

from mercurial.i18n import _
from mercurial.node import hex

from mercurial import (
    encoding,
    pycompat,
    registrar,
)
from mercurial.utils import (
    dateutil,
    procutil,
)

# Note for extension authors: ONLY specify testedwith = 'ships-with-hg-core' for
# extensions which SHIP WITH MERCURIAL. Non-mainline extensions should
# be specifying the version(s) of Mercurial they are tested with, or
# leave the attribute unspecified.
testedwith = 'ships-with-hg-core'

cmdtable = {}
command = registrar.command(cmdtable)

configtable = {}
configitem = registrar.configitem(configtable)

configitem('blackbox', 'dirty',
    default=False,
)
configitem('blackbox', 'maxsize',
    default='1 MB',
)
configitem('blackbox', 'logsource',
    default=False,
)
configitem('blackbox', 'maxfiles',
    default=7,
)
configitem('blackbox', 'track',
    default=lambda: ['*'],
)
configitem('blackbox', 'date-format',
    default='%Y/%m/%d %H:%M:%S',
)

def _openlogfile(ui, vfs, name, maxfiles=0, maxsize=0):
    def rotate(oldpath, newpath):
        try:
            vfs.unlink(newpath)
        except OSError as err:
            if err.errno != errno.ENOENT:
                ui.debug("warning: cannot remove '%s': %s\n" %
                         (newpath, err.strerror))
        try:
            if newpath:
                vfs.rename(oldpath, newpath)
        except OSError as err:
            if err.errno != errno.ENOENT:
                ui.debug("warning: cannot rename '%s' to '%s': %s\n" %
                         (newpath, oldpath, err.strerror))

    if maxsize > 0:
        try:
            st = vfs.stat(name)
        except OSError:
            pass
        else:
            if st.st_size >= maxsize:
                path = vfs.join(name)
                for i in pycompat.xrange(maxfiles - 1, 1, -1):
                    rotate(oldpath='%s.%d' % (path, i - 1),
                           newpath='%s.%d' % (path, i))
                rotate(oldpath=path,
                       newpath=maxfiles > 0 and path + '.1')
    return vfs(name, 'a', makeparentdirs=False)

class proxylogger(object):
    """Forward log events to another logger to be set later"""

    def __init__(self):
        self.logger = None

    def tracked(self, event):
        return self.logger is not None and self.logger.tracked(event)

    def log(self, ui, event, msg, opts):
        assert self.logger is not None
        self.logger.log(ui, event, msg, opts)

_lastlogger = proxylogger()

class blackboxlogger(object):
    def __init__(self, ui, repo):
        self._repo = repo
        self._trackedevents = set(ui.configlist('blackbox', 'track'))
        self._maxfiles = ui.configint('blackbox', 'maxfiles')
        self._maxsize = ui.configbytes('blackbox', 'maxsize')

    def tracked(self, event):
        return b'*' in self._trackedevents or event in self._trackedevents

    def log(self, ui, event, msg, opts):
        default = ui.configdate('devel', 'default-date')
        date = dateutil.datestr(default, ui.config('blackbox', 'date-format'))
        user = procutil.getuser()
        pid = '%d' % procutil.getpid()
        rev = '(unknown)'
        changed = ''
        ctx = self._repo[None]
        parents = ctx.parents()
        rev = ('+'.join([hex(p.node()) for p in parents]))
        if (ui.configbool('blackbox', 'dirty') and
            ctx.dirty(missing=True, merge=False, branch=False)):
            changed = '+'
        if ui.configbool('blackbox', 'logsource'):
            src = ' [%s]' % event
        else:
            src = ''
        try:
            fmt = '%s %s @%s%s (%s)%s> %s'
            args = (date, user, rev, changed, pid, src, msg)
            with _openlogfile(ui, self._repo.vfs, name='blackbox.log',
                              maxfiles=self._maxfiles,
                              maxsize=self._maxsize) as fp:
                fp.write(fmt % args)
        except (IOError, OSError) as err:
            # deactivate this to avoid failed logging again
            self._trackedevents.clear()
            ui.debug('warning: cannot write to blackbox.log: %s\n' %
                     encoding.strtolocal(err.strerror))
            return
        _lastlogger.logger = self

def uipopulate(ui):
    ui.setlogger(b'blackbox', _lastlogger)

def reposetup(ui, repo):
    # During 'hg pull' a httppeer repo is created to represent the remote repo.
    # It doesn't have a .hg directory to put a blackbox in, so we don't do
    # the blackbox setup for it.
    if not repo.local():
        return

    # Since blackbox.log is stored in the repo directory, the logger should be
    # instantiated per repository.
    logger = blackboxlogger(ui, repo)
    ui.setlogger(b'blackbox', logger)

    # Set _lastlogger even if ui.log is not called. This gives blackbox a
    # fallback place to log
    if _lastlogger.logger is None:
        _lastlogger.logger = logger

    repo._wlockfreeprefix.add('blackbox.log')

@command('blackbox',
    [('l', 'limit', 10, _('the number of events to show')),
    ],
    _('hg blackbox [OPTION]...'),
    helpcategory=command.CATEGORY_MAINTENANCE,
    helpbasic=True)
def blackbox(ui, repo, *revs, **opts):
    '''view the recent repository events
    '''

    if not repo.vfs.exists('blackbox.log'):
        return

    limit = opts.get(r'limit')
    fp = repo.vfs('blackbox.log', 'r')
    lines = fp.read().split('\n')

    count = 0
    output = []
    for line in reversed(lines):
        if count >= limit:
            break

        # count the commands by matching lines like: 2013/01/23 19:13:36 root>
        if re.match('^\d{4}/\d{2}/\d{2} \d{2}:\d{2}:\d{2} .*> .*', line):
            count += 1
        output.append(line)

    ui.status('\n'.join(reversed(output)))
