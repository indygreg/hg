from __future__ import absolute_import

import struct

from mercurial.i18n import _

NETWORK_CAP_LEGACY_SSH_GETFILES = 'exp-remotefilelog-ssh-getfiles-1'

SHALLOWREPO_REQUIREMENT = "exp-remotefilelog-repo-req-1"

BUNDLE2_CAPABLITY = "exp-remotefilelog-b2cap-1"

FILENAMESTRUCT = '!H'
FILENAMESIZE = struct.calcsize(FILENAMESTRUCT)

NODESIZE = 20
PACKREQUESTCOUNTSTRUCT = '!I'

NODECOUNTSTRUCT = '!I'
NODECOUNTSIZE = struct.calcsize(NODECOUNTSTRUCT)

PATHCOUNTSTRUCT = '!I'
PATHCOUNTSIZE = struct.calcsize(PATHCOUNTSTRUCT)

FILEPACK_CATEGORY=""
TREEPACK_CATEGORY="manifests"

ALL_CATEGORIES = [FILEPACK_CATEGORY, TREEPACK_CATEGORY]

# revision metadata keys. must be a single character.
METAKEYFLAG = 'f'  # revlog flag
METAKEYSIZE = 's'  # full rawtext size

def getunits(category):
    if category == FILEPACK_CATEGORY:
        return _("files")
    if category == TREEPACK_CATEGORY:
        return _("trees")

# Repack options passed to ``markledger``.
OPTION_PACKSONLY = 'packsonly'
