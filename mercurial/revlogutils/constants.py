# revlogdeltas.py - constant used for revlog logic
#
# Copyright 2005-2007 Matt Mackall <mpm@selenic.com>
# Copyright 2018 Octobus <contact@octobus.net>
#
# This software may be used and distributed according to the terms of the
# GNU General Public License version 2 or any later version.
"""Helper class to compute deltas stored inside revlogs"""

from __future__ import absolute_import

from .. import (
    util,
)

# revlog header flags
REVLOGV0 = 0
REVLOGV1 = 1
# Dummy value until file format is finalized.
# Reminder: change the bounds check in revlog.__init__ when this is changed.
REVLOGV2 = 0xDEAD
FLAG_INLINE_DATA = (1 << 16)
FLAG_GENERALDELTA = (1 << 17)
REVLOG_DEFAULT_FLAGS = FLAG_INLINE_DATA
REVLOG_DEFAULT_FORMAT = REVLOGV1
REVLOG_DEFAULT_VERSION = REVLOG_DEFAULT_FORMAT | REVLOG_DEFAULT_FLAGS
REVLOGV1_FLAGS = FLAG_INLINE_DATA | FLAG_GENERALDELTA
REVLOGV2_FLAGS = REVLOGV1_FLAGS

# revlog index flags
REVIDX_ISCENSORED = (1 << 15) # revision has censor metadata, must be verified
REVIDX_ELLIPSIS = (1 << 14) # revision hash does not match data (narrowhg)
REVIDX_EXTSTORED = (1 << 13) # revision data is stored externally
REVIDX_DEFAULT_FLAGS = 0
# stable order in which flags need to be processed and their processors applied
REVIDX_FLAGS_ORDER = [
    REVIDX_ISCENSORED,
    REVIDX_ELLIPSIS,
    REVIDX_EXTSTORED,
]
REVIDX_KNOWN_FLAGS = util.bitsfrom(REVIDX_FLAGS_ORDER)
# bitmark for flags that could cause rawdata content change
REVIDX_RAWTEXT_CHANGING_FLAGS = REVIDX_ISCENSORED | REVIDX_EXTSTORED
