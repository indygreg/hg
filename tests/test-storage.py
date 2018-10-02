# This test verifies the conformance of various classes to various
# storage interfaces.
from __future__ import absolute_import

import silenttestrunner

from mercurial import (
    filelog,
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
    vfsmap = {'plain': STATE['vfs']}

    return transaction.transaction(STATE['ui'].warn, STATE['vfs'], vfsmap,
                                   b'journal', b'undo')

# Assigning module-level attributes that inherit from unittest.TestCase
# is all that is needed to register tests.
filelogindextests = storagetesting.makeifileindextests(makefilefn,
                                                       maketransaction)
filelogdatatests = storagetesting.makeifiledatatests(makefilefn,
                                                     maketransaction)
filelogmutationtests = storagetesting.makeifilemutationtests(makefilefn,
                                                             maketransaction)

if __name__ == '__main__':
    silenttestrunner.main(__name__)
