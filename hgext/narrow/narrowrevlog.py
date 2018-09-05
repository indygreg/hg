# narrowrevlog.py - revlog storing irrelevant nodes as "ellipsis" nodes
#
# Copyright 2017 Google, Inc.
#
# This software may be used and distributed according to the terms of the
# GNU General Public License version 2 or any later version.

from __future__ import absolute_import

from mercurial import (
   revlog,
)

revlog.addflagprocessor(revlog.REVIDX_ELLIPSIS, revlog.ellipsisprocessor)

def setup():
    # We just wanted to add the flag processor, which is done at module
    # load time.
    pass
