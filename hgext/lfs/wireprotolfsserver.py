# wireprotolfsserver.py - lfs protocol server side implementation
#
# Copyright 2018 Matt Harbison <matt_harbison@yahoo.com>
#
# This software may be used and distributed according to the terms of the
# GNU General Public License version 2 or any later version.

from __future__ import absolute_import

from mercurial.hgweb import (
    common as hgwebcommon,
)

from mercurial import (
    pycompat,
)

def handlewsgirequest(orig, rctx, req, res, checkperm):
    """Wrap wireprotoserver.handlewsgirequest() to possibly process an LFS
    request if it is left unprocessed by the wrapped method.
    """
    if orig(rctx, req, res, checkperm):
        return True

    if not req.dispatchpath:
        return False

    try:
        if req.dispatchpath == b'.git/info/lfs/objects/batch':
            checkperm(rctx, req, 'pull')
            return _processbatchrequest(rctx.repo, req, res)
        # TODO: reserve and use a path in the proposed http wireprotocol /api/
        #       namespace?
        elif req.dispatchpath.startswith(b'.hg/lfs/objects'):
            return _processbasictransfer(rctx.repo, req, res,
                                         lambda perm:
                                                checkperm(rctx, req, perm))
        return False
    except hgwebcommon.ErrorResponse as e:
        # XXX: copied from the handler surrounding wireprotoserver._callhttp()
        #      in the wrapped function.  Should this be moved back to hgweb to
        #      be a common handler?
        for k, v in e.headers:
            res.headers[k] = v
        res.status = hgwebcommon.statusmessage(e.code, pycompat.bytestr(e))
        res.setbodybytes(b'0\n%s\n' % pycompat.bytestr(e))
        return True

def _processbatchrequest(repo, req, res):
    """Handle a request for the Batch API, which is the gateway to granting file
    access.

    https://github.com/git-lfs/git-lfs/blob/master/docs/api/batch.md
    """
    return False

def _processbasictransfer(repo, req, res, checkperm):
    """Handle a single file upload (PUT) or download (GET) action for the Basic
    Transfer Adapter.

    After determining if the request is for an upload or download, the access
    must be checked by calling ``checkperm()`` with either 'pull' or 'upload'
    before accessing the files.

    https://github.com/git-lfs/git-lfs/blob/master/docs/api/basic-transfers.md
    """

    method = req.method

    if method == b'PUT':
        checkperm('upload')
    elif method == b'GET':
        checkperm('pull')

    return False
