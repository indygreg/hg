# extutil.py - useful utility methods for extensions
#
# Copyright 2016 Facebook
#
# This software may be used and distributed according to the terms of the
# GNU General Public License version 2 or any later version.

from __future__ import absolute_import

import contextlib
import errno
import os
import time

from mercurial import (
    error,
    lock as lockmod,
    util,
    vfs as vfsmod,
)

@contextlib.contextmanager
def flock(lockpath, description, timeout=-1):
    """A flock based lock object. Currently it is always non-blocking.

    Note that since it is flock based, you can accidentally take it multiple
    times within one process and the first one to be released will release all
    of them. So the caller needs to be careful to not create more than one
    instance per lock.
    """

    # best effort lightweight lock
    try:
        import fcntl
        fcntl.flock
    except ImportError:
        # fallback to Mercurial lock
        vfs = vfsmod.vfs(os.path.dirname(lockpath))
        with lockmod.lock(vfs, os.path.basename(lockpath), timeout=timeout):
            yield
        return
    # make sure lock file exists
    util.makedirs(os.path.dirname(lockpath))
    with open(lockpath, 'a'):
        pass
    lockfd = os.open(lockpath, os.O_RDONLY, 0o664)
    start = time.time()
    while True:
        try:
            fcntl.flock(lockfd, fcntl.LOCK_EX | fcntl.LOCK_NB)
            break
        except IOError as ex:
            if ex.errno == errno.EAGAIN:
                if timeout != -1 and time.time() - start > timeout:
                    raise error.LockHeld(errno.EAGAIN, lockpath, description,
                                         '')
                else:
                    time.sleep(0.05)
                    continue
            raise

    try:
        yield
    finally:
        fcntl.flock(lockfd, fcntl.LOCK_UN)
        os.close(lockfd)
