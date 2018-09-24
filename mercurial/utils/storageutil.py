# storageutil.py - Storage functionality agnostic of backend implementation.
#
# Copyright 2018 Gregory Szorc <gregory.szorc@gmail.com>
#
# This software may be used and distributed according to the terms of the
# GNU General Public License version 2 or any later version.

from __future__ import absolute_import

import hashlib
import re

from ..node import (
    nullid,
)
from .. import (
    pycompat,
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

METADATA_RE = re.compile(b'\x01\n')

def parsemeta(text):
    """Parse metadata header from revision data.

    Returns a 2-tuple of (metadata, offset), where both can be None if there
    is no metadata.
    """
    # text can be buffer, so we can't use .startswith or .index
    if text[:2] != b'\x01\n':
        return None, None
    s = METADATA_RE.search(text, 2).start()
    mtext = text[2:s]
    meta = {}
    for l in mtext.splitlines():
        k, v = l.split(b': ', 1)
        meta[k] = v
    return meta, s + 2

def packmeta(meta, text):
    """Add metadata to fulltext to produce revision text."""
    keys = sorted(meta)
    metatext = b''.join(b'%s: %s\n' % (k, meta[k]) for k in keys)
    return b'\x01\n%s\x01\n%s' % (metatext, text)

def iscensoredtext(text):
    meta = parsemeta(text)[0]
    return meta and b'censored' in meta

def filtermetadata(text):
    """Extract just the revision data from source text.

    Returns ``text`` unless it has a metadata header, in which case we return
    a new buffer without hte metadata.
    """
    if not text.startswith(b'\x01\n'):
        return text

    offset = text.index(b'\x01\n', 2)
    return text[offset + 2:]

def iterrevs(storelen, start=0, stop=None):
    """Iterate over revision numbers in a store."""
    step = 1

    if stop is not None:
        if start > stop:
            step = -1
        stop += step
        if stop > storelen:
            stop = storelen
    else:
        stop = storelen

    return pycompat.xrange(start, stop, step)
