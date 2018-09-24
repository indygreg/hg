# storageutil.py - Storage functionality agnostic of backend implementation.
#
# Copyright 2018 Gregory Szorc <gregory.szorc@gmail.com>
#
# This software may be used and distributed according to the terms of the
# GNU General Public License version 2 or any later version.

from __future__ import absolute_import

import hashlib

from ..node import (
    nullid,
)

_nullhash = hashlib.sha1(nullid)

def hashrevisionsha1(text, p1, p2):
    """Compute the SHA-1 for revision data and its parents.

    This hash combines both the current file contents and its history
    in a manner that makes it easy to distinguish nodes with the same
    content in the revision graph.
    """
    # As of now, if one of the parent node is null, p2 is null
    if p2 == nullid:
        # deep copy of a hash is faster than creating one
        s = _nullhash.copy()
        s.update(p1)
    else:
        # none of the parent nodes are nullid
        if p1 < p2:
            a = p1
            b = p2
        else:
            a = p2
            b = p1
        s = hashlib.sha1(a)
        s.update(b)
    s.update(text)
    return s.digest()
