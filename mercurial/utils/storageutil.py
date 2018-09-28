# storageutil.py - Storage functionality agnostic of backend implementation.
#
# Copyright 2018 Gregory Szorc <gregory.szorc@gmail.com>
#
# This software may be used and distributed according to the terms of the
# GNU General Public License version 2 or any later version.

from __future__ import absolute_import

import hashlib
import re

from ..i18n import _
from ..node import (
    bin,
    nullid,
    nullrev,
)
from .. import (
    error,
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

def filerevisioncopied(store, node):
    """Resolve file revision copy metadata.

    Returns ``False`` if the file has no copy metadata. Otherwise a
    2-tuple of the source filename and node.
    """
    if store.parents(node)[0] != nullid:
        return False

    meta = parsemeta(store.revision(node))[0]

    # copy and copyrev occur in pairs. In rare cases due to old bugs,
    # one can occur without the other. So ensure both are present to flag
    # as a copy.
    if meta and b'copy' in meta and b'copyrev' in meta:
        return meta[b'copy'], bin(meta[b'copyrev'])

    return False

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

def fileidlookup(store, fileid, identifier):
    """Resolve the file node for a value.

    ``store`` is an object implementing the ``ifileindex`` interface.

    ``fileid`` can be:

    * A 20 byte binary node.
    * An integer revision number
    * A 40 byte hex node.
    * A bytes that can be parsed as an integer representing a revision number.

    ``identifier`` is used to populate ``error.LookupError`` with an identifier
    for the store.

    Raises ``error.LookupError`` on failure.
    """
    if isinstance(fileid, int):
        try:
            return store.node(fileid)
        except IndexError:
            raise error.LookupError(fileid, identifier, _('no match found'))

    if len(fileid) == 20:
        try:
            store.rev(fileid)
            return fileid
        except error.LookupError:
            pass

    if len(fileid) == 40:
        try:
            rawnode = bin(fileid)
            store.rev(rawnode)
            return rawnode
        except TypeError:
            pass

    try:
        rev = int(fileid)

        if b'%d' % rev != fileid:
            raise ValueError

        try:
            return store.node(rev)
        except (IndexError, TypeError):
            pass
    except (ValueError, OverflowError):
        pass

    raise error.LookupError(fileid, identifier, _('no match found'))

def resolvestripinfo(minlinkrev, tiprev, headrevs, linkrevfn, parentrevsfn):
    """Resolve information needed to strip revisions.

    Finds the minimum revision number that must be stripped in order to
    strip ``minlinkrev``.

    Returns a 2-tuple of the minimum revision number to do that and a set
    of all revision numbers that have linkrevs that would be broken
    by that strip.

    ``tiprev`` is the current tip-most revision. It is ``len(store) - 1``.
    ``headrevs`` is an iterable of head revisions.
    ``linkrevfn`` is a callable that receives a revision and returns a linked
    revision.
    ``parentrevsfn`` is a callable that receives a revision number and returns
    an iterable of its parent revision numbers.
    """
    brokenrevs = set()
    strippoint = tiprev + 1

    heads = {}
    futurelargelinkrevs = set()
    for head in headrevs:
        headlinkrev = linkrevfn(head)
        heads[head] = headlinkrev
        if headlinkrev >= minlinkrev:
            futurelargelinkrevs.add(headlinkrev)

    # This algorithm involves walking down the rev graph, starting at the
    # heads. Since the revs are topologically sorted according to linkrev,
    # once all head linkrevs are below the minlink, we know there are
    # no more revs that could have a linkrev greater than minlink.
    # So we can stop walking.
    while futurelargelinkrevs:
        strippoint -= 1
        linkrev = heads.pop(strippoint)

        if linkrev < minlinkrev:
            brokenrevs.add(strippoint)
        else:
            futurelargelinkrevs.remove(linkrev)

        for p in parentrevsfn(strippoint):
            if p != nullrev:
                plinkrev = linkrevfn(p)
                heads[p] = plinkrev
                if plinkrev >= minlinkrev:
                    futurelargelinkrevs.add(plinkrev)

    return strippoint, brokenrevs
