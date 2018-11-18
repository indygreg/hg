# loggingutil.py - utility for logging events
#
# Copyright 2010 Nicolas Dumazet
# Copyright 2013 Facebook, Inc.
#
# This software may be used and distributed according to the terms of the
# GNU General Public License version 2 or any later version.

from __future__ import absolute_import

import errno

from . import (
    pycompat,
)

def openlogfile(ui, vfs, name, maxfiles=0, maxsize=0):
    """Open log file in append mode, with optional rotation

    If maxsize > 0, the log file will be rotated up to maxfiles.
    """
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
