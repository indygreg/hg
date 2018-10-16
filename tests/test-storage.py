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

if __name__ == '__main__':
    silenttestrunner.main(__name__)
