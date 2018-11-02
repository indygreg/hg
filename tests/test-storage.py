# This test verifies the conformance of various classes to various
# storage interfaces.
from __future__ import absolute_import

import silenttestrunner

from mercurial import (
    error,
    filelog,
    revlog,
    transaction,
    ui as uimod,
    vfs as vfsmod,
)

from mercurial.testing import (
    storage as storagetesting,
)

try:
    from hgext import (
        sqlitestore,
    )
except ImportError:
    sqlitestore = None

try:
    import sqlite3
    if sqlite3.sqlite_version_info < (3, 8, 3):
        # WITH clause not supported
        sqlitestore = None
except ImportError:
    pass

try:
    from mercurial import zstd
    zstd.__version__
except ImportError:
    zstd = None

STATE = {
    'lastindex': 0,
    'ui': uimod.ui(),
    'vfs': vfsmod.vfs(b'.', realpath=True),
}

def makefilefn(self):
    """Factory for filelog instances."""
    fl = filelog.filelog(STATE['vfs'], b'filelog-%d' % STATE['lastindex'])
    STATE['lastindex'] += 1
    return fl

def maketransaction(self):
    vfsmap = {b'plain': STATE['vfs'], b'store': STATE['vfs']}

    return transaction.transaction(STATE['ui'].warn, STATE['vfs'], vfsmap,
                                   b'journal', b'undo')

def addrawrevision(self, fl, tr, node, p1, p2, linkrev, rawtext=None,
                   delta=None, censored=False, ellipsis=False, extstored=False):
    flags = 0

    if censored:
        flags |= revlog.REVIDX_ISCENSORED
    if ellipsis:
        flags |= revlog.REVIDX_ELLIPSIS
    if extstored:
        flags |= revlog.REVIDX_EXTSTORED

    if rawtext is not None:
        fl._revlog.addrawrevision(rawtext, tr, linkrev, p1, p2, node, flags)
    elif delta is not None:
        fl._revlog.addrawrevision(rawtext, tr, linkrev, p1, p2, node, flags,
                                  cachedelta=delta)
    else:
        raise error.Abort('must supply rawtext or delta arguments')

    # We may insert bad data. Clear caches to prevent e.g. cache hits to
    # bypass hash verification.
    fl._revlog.clearcaches()

# Assigning module-level attributes that inherit from unittest.TestCase
# is all that is needed to register tests.
filelogindextests = storagetesting.makeifileindextests(makefilefn,
                                                       maketransaction,
                                                       addrawrevision)
filelogdatatests = storagetesting.makeifiledatatests(makefilefn,
                                                     maketransaction,
                                                     addrawrevision)
filelogmutationtests = storagetesting.makeifilemutationtests(makefilefn,
                                                             maketransaction,
                                                             addrawrevision)

def makesqlitefile(self):
    path = STATE['vfs'].join(b'db-%d.db' % STATE['lastindex'])
    STATE['lastindex'] += 1

    db = sqlitestore.makedb(path)

    compression = b'zstd' if zstd else b'zlib'

    return sqlitestore.sqlitefilestore(db, b'dummy-path', compression)

def addrawrevisionsqlite(self, fl, tr, node, p1, p2, linkrev, rawtext=None,
                         delta=None, censored=False, ellipsis=False,
                         extstored=False):
    flags = 0

    if censored:
        flags |= sqlitestore.FLAG_CENSORED

    if ellipsis | extstored:
        raise error.Abort(b'support for ellipsis and extstored flags not '
                          b'supported')

    if rawtext is not None:
        fl._addrawrevision(node, rawtext, tr, linkrev, p1, p2, flags=flags)
    elif delta is not None:
        fl._addrawrevision(node, rawtext, tr, linkrev, p1, p2,
                           storedelta=delta, flags=flags)
    else:
        raise error.Abort(b'must supply rawtext or delta arguments')

if sqlitestore is not None:
    sqlitefileindextests = storagetesting.makeifileindextests(
        makesqlitefile, maketransaction, addrawrevisionsqlite)
    sqlitefiledatatests = storagetesting.makeifiledatatests(
        makesqlitefile, maketransaction, addrawrevisionsqlite)
    sqlitefilemutationtests = storagetesting.makeifilemutationtests(
        makesqlitefile, maketransaction, addrawrevisionsqlite)

if __name__ == '__main__':
    silenttestrunner.main(__name__)
