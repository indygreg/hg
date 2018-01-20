# blobstore.py - local and remote (speaking Git-LFS protocol) blob storages
#
# Copyright 2017 Facebook, Inc.
#
# This software may be used and distributed according to the terms of the
# GNU General Public License version 2 or any later version.

from __future__ import absolute_import

import hashlib
import json
import os
import re
import socket

from mercurial.i18n import _

from mercurial import (
    error,
    pathutil,
    url as urlmod,
    util,
    vfs as vfsmod,
    worker,
)

from ..largefiles import lfutil

# 64 bytes for SHA256
_lfsre = re.compile(r'\A[a-f0-9]{64}\Z')

class lfsvfs(vfsmod.vfs):
    def join(self, path):
        """split the path at first two characters, like: XX/XXXXX..."""
        if not _lfsre.match(path):
            raise error.ProgrammingError('unexpected lfs path: %s' % path)
        return super(lfsvfs, self).join(path[0:2], path[2:])

    def walk(self, path=None, onerror=None):
        """Yield (dirpath, [], oids) tuple for blobs under path

        Oids only exist in the root of this vfs, so dirpath is always ''.
        """
        root = os.path.normpath(self.base)
        # when dirpath == root, dirpath[prefixlen:] becomes empty
        # because len(dirpath) < prefixlen.
        prefixlen = len(pathutil.normasprefix(root))
        oids = []

        for dirpath, dirs, files in os.walk(self.reljoin(self.base, path or ''),
                                            onerror=onerror):
            dirpath = dirpath[prefixlen:]

            # Silently skip unexpected files and directories
            if len(dirpath) == 2:
                oids.extend([dirpath + f for f in files
                             if _lfsre.match(dirpath + f)])

        yield ('', [], oids)

class filewithprogress(object):
    """a file-like object that supports __len__ and read.

    Useful to provide progress information for how many bytes are read.
    """

    def __init__(self, fp, callback):
        self._fp = fp
        self._callback = callback # func(readsize)
        fp.seek(0, os.SEEK_END)
        self._len = fp.tell()
        fp.seek(0)

    def __len__(self):
        return self._len

    def read(self, size):
        if self._fp is None:
            return b''
        data = self._fp.read(size)
        if data:
            if self._callback:
                self._callback(len(data))
        else:
            self._fp.close()
            self._fp = None
        return data

class local(object):
    """Local blobstore for large file contents.

    This blobstore is used both as a cache and as a staging area for large blobs
    to be uploaded to the remote blobstore.
    """

    def __init__(self, repo):
        fullpath = repo.svfs.join('lfs/objects')
        self.vfs = lfsvfs(fullpath)
        usercache = lfutil._usercachedir(repo.ui, 'lfs')
        self.cachevfs = lfsvfs(usercache)
        self.ui = repo.ui

    def open(self, oid):
        """Open a read-only file descriptor to the named blob, in either the
        usercache or the local store."""
        # The usercache is the most likely place to hold the file.  Commit will
        # write to both it and the local store, as will anything that downloads
        # the blobs.  However, things like clone without an update won't
        # populate the local store.  For an init + push of a local clone,
        # the usercache is the only place it _could_ be.  If not present, the
        # missing file msg here will indicate the local repo, not the usercache.
        if self.cachevfs.exists(oid):
            return self.cachevfs(oid, 'rb')

        return self.vfs(oid, 'rb')

    def download(self, oid, src):
        """Read the blob from the remote source in chunks, verify the content,
        and write to this local blobstore."""
        sha256 = hashlib.sha256()

        with self.vfs(oid, 'wb', atomictemp=True) as fp:
            for chunk in util.filechunkiter(src, size=1048576):
                fp.write(chunk)
                sha256.update(chunk)

            realoid = sha256.hexdigest()
            if realoid != oid:
                raise error.Abort(_('corrupt remote lfs object: %s') % oid)

        # XXX: should we verify the content of the cache, and hardlink back to
        # the local store on success, but truncate, write and link on failure?
        if not self.cachevfs.exists(oid):
            self.ui.note(_('lfs: adding %s to the usercache\n') % oid)
            lfutil.link(self.vfs.join(oid), self.cachevfs.join(oid))

    def write(self, oid, data):
        """Write blob to local blobstore.

        This should only be called from the filelog during a commit or similar.
        As such, there is no need to verify the data.  Imports from a remote
        store must use ``download()`` instead."""
        with self.vfs(oid, 'wb', atomictemp=True) as fp:
            fp.write(data)

        # XXX: should we verify the content of the cache, and hardlink back to
        # the local store on success, but truncate, write and link on failure?
        if not self.cachevfs.exists(oid):
            self.ui.note(_('lfs: adding %s to the usercache\n') % oid)
            lfutil.link(self.vfs.join(oid), self.cachevfs.join(oid))

    def read(self, oid, verify=True):
        """Read blob from local blobstore."""
        if not self.vfs.exists(oid):
            blob = self._read(self.cachevfs, oid, verify)

            # Even if revlog will verify the content, it needs to be verified
            # now before making the hardlink to avoid propagating corrupt blobs.
            # Don't abort if corruption is detected, because `hg verify` will
            # give more useful info about the corruption- simply don't add the
            # hardlink.
            if verify or hashlib.sha256(blob).hexdigest() == oid:
                self.ui.note(_('lfs: found %s in the usercache\n') % oid)
                lfutil.link(self.cachevfs.join(oid), self.vfs.join(oid))
        else:
            self.ui.note(_('lfs: found %s in the local lfs store\n') % oid)
            blob = self._read(self.vfs, oid, verify)
        return blob

    def _read(self, vfs, oid, verify):
        """Read blob (after verifying) from the given store"""
        blob = vfs.read(oid)
        if verify:
            _verify(oid, blob)
        return blob

    def has(self, oid):
        """Returns True if the local blobstore contains the requested blob,
        False otherwise."""
        return self.cachevfs.exists(oid) or self.vfs.exists(oid)

class _gitlfsremote(object):

    def __init__(self, repo, url):
        ui = repo.ui
        self.ui = ui
        baseurl, authinfo = url.authinfo()
        self.baseurl = baseurl.rstrip('/')
        useragent = repo.ui.config('experimental', 'lfs.user-agent')
        if not useragent:
            useragent = 'git-lfs/2.3.4 (Mercurial %s)' % util.version()
        self.urlopener = urlmod.opener(ui, authinfo, useragent)
        self.retry = ui.configint('lfs', 'retry')

    def writebatch(self, pointers, fromstore):
        """Batch upload from local to remote blobstore."""
        self._batch(pointers, fromstore, 'upload')

    def readbatch(self, pointers, tostore):
        """Batch download from remote to local blostore."""
        self._batch(pointers, tostore, 'download')

    def _batchrequest(self, pointers, action):
        """Get metadata about objects pointed by pointers for given action

        Return decoded JSON object like {'objects': [{'oid': '', 'size': 1}]}
        See https://github.com/git-lfs/git-lfs/blob/master/docs/api/batch.md
        """
        objects = [{'oid': p.oid(), 'size': p.size()} for p in pointers]
        requestdata = json.dumps({
            'objects': objects,
            'operation': action,
        })
        batchreq = util.urlreq.request('%s/objects/batch' % self.baseurl,
                                       data=requestdata)
        batchreq.add_header('Accept', 'application/vnd.git-lfs+json')
        batchreq.add_header('Content-Type', 'application/vnd.git-lfs+json')
        try:
            rawjson = self.urlopener.open(batchreq).read()
        except util.urlerr.httperror as ex:
            raise LfsRemoteError(_('LFS HTTP error: %s (action=%s)')
                                 % (ex, action))
        try:
            response = json.loads(rawjson)
        except ValueError:
            raise LfsRemoteError(_('LFS server returns invalid JSON: %s')
                                 % rawjson)
        return response

    def _checkforservererror(self, pointers, responses, action):
        """Scans errors from objects

        Raises LfsRemoteError if any objects have an error"""
        for response in responses:
            # The server should return 404 when objects cannot be found. Some
            # server implementation (ex. lfs-test-server)  does not set "error"
            # but just removes "download" from "actions". Treat that case
            # as the same as 404 error.
            notfound = (response.get('error', {}).get('code') == 404
                        or (action == 'download'
                            and action not in response.get('actions', [])))
            if notfound:
                ptrmap = {p.oid(): p for p in pointers}
                p = ptrmap.get(response['oid'], None)
                if p:
                    filename = getattr(p, 'filename', 'unknown')
                    raise LfsRemoteError(
                        _(('LFS server error. Remote object '
                          'for "%s" not found: %r')) % (filename, response))
                else:
                    raise LfsRemoteError(
                        _('LFS server error. Unsolicited response for oid %s')
                        % response['oid'])
            if 'error' in response:
                raise LfsRemoteError(_('LFS server error: %r') % response)

    def _extractobjects(self, response, pointers, action):
        """extract objects from response of the batch API

        response: parsed JSON object returned by batch API
        return response['objects'] filtered by action
        raise if any object has an error
        """
        # Scan errors from objects - fail early
        objects = response.get('objects', [])
        self._checkforservererror(pointers, objects, action)

        # Filter objects with given action. Practically, this skips uploading
        # objects which exist in the server.
        filteredobjects = [o for o in objects if action in o.get('actions', [])]

        return filteredobjects

    def _basictransfer(self, obj, action, localstore):
        """Download or upload a single object using basic transfer protocol

        obj: dict, an object description returned by batch API
        action: string, one of ['upload', 'download']
        localstore: blobstore.local

        See https://github.com/git-lfs/git-lfs/blob/master/docs/api/\
        basic-transfers.md
        """
        oid = str(obj['oid'])

        href = str(obj['actions'][action].get('href'))
        headers = obj['actions'][action].get('header', {}).items()

        request = util.urlreq.request(href)
        if action == 'upload':
            # If uploading blobs, read data from local blobstore.
            with localstore.open(oid) as fp:
                _verifyfile(oid, fp)
            request.data = filewithprogress(localstore.open(oid), None)
            request.get_method = lambda: 'PUT'

        for k, v in headers:
            request.add_header(k, v)

        response = b''
        try:
            req = self.urlopener.open(request)
            if action == 'download':
                # If downloading blobs, store downloaded data to local blobstore
                localstore.download(oid, req)
            else:
                while True:
                    data = req.read(1048576)
                    if not data:
                        break
                    response += data
                if response:
                    self.ui.debug('lfs %s response: %s' % (action, response))
        except util.urlerr.httperror as ex:
            if self.ui.debugflag:
                self.ui.debug('%s: %s\n' % (oid, ex.read()))
            raise LfsRemoteError(_('HTTP error: %s (oid=%s, action=%s)')
                                 % (ex, oid, action))

    def _batch(self, pointers, localstore, action):
        if action not in ['upload', 'download']:
            raise error.ProgrammingError('invalid Git-LFS action: %s' % action)

        response = self._batchrequest(pointers, action)
        objects = self._extractobjects(response, pointers, action)
        total = sum(x.get('size', 0) for x in objects)
        sizes = {}
        for obj in objects:
            sizes[obj.get('oid')] = obj.get('size', 0)
        topic = {'upload': _('lfs uploading'),
                 'download': _('lfs downloading')}[action]
        if len(objects) > 1:
            self.ui.note(_('lfs: need to transfer %d objects (%s)\n')
                         % (len(objects), util.bytecount(total)))
        self.ui.progress(topic, 0, total=total)
        def transfer(chunk):
            for obj in chunk:
                objsize = obj.get('size', 0)
                if self.ui.verbose:
                    if action == 'download':
                        msg = _('lfs: downloading %s (%s)\n')
                    elif action == 'upload':
                        msg = _('lfs: uploading %s (%s)\n')
                    self.ui.note(msg % (obj.get('oid'),
                                 util.bytecount(objsize)))
                retry = self.retry
                while True:
                    try:
                        self._basictransfer(obj, action, localstore)
                        yield 1, obj.get('oid')
                        break
                    except socket.error as ex:
                        if retry > 0:
                            self.ui.note(
                                _('lfs: failed: %r (remaining retry %d)\n')
                                % (ex, retry))
                            retry -= 1
                            continue
                        raise

        # Until https multiplexing gets sorted out
        if self.ui.configbool('experimental', 'lfs.worker-enable'):
            oids = worker.worker(self.ui, 0.1, transfer, (),
                                 sorted(objects, key=lambda o: o.get('oid')))
        else:
            oids = transfer(sorted(objects, key=lambda o: o.get('oid')))

        processed = 0
        for _one, oid in oids:
            processed += sizes[oid]
            self.ui.progress(topic, processed, total=total)
            self.ui.note(_('lfs: processed: %s\n') % oid)
        self.ui.progress(topic, pos=None, total=total)

    def __del__(self):
        # copied from mercurial/httppeer.py
        urlopener = getattr(self, 'urlopener', None)
        if urlopener:
            for h in urlopener.handlers:
                h.close()
                getattr(h, "close_all", lambda : None)()

class _dummyremote(object):
    """Dummy store storing blobs to temp directory."""

    def __init__(self, repo, url):
        fullpath = repo.vfs.join('lfs', url.path)
        self.vfs = lfsvfs(fullpath)

    def writebatch(self, pointers, fromstore):
        for p in pointers:
            content = fromstore.read(p.oid(), verify=True)
            with self.vfs(p.oid(), 'wb', atomictemp=True) as fp:
                fp.write(content)

    def readbatch(self, pointers, tostore):
        for p in pointers:
            with self.vfs(p.oid(), 'rb') as fp:
                tostore.download(p.oid(), fp)

class _nullremote(object):
    """Null store storing blobs to /dev/null."""

    def __init__(self, repo, url):
        pass

    def writebatch(self, pointers, fromstore):
        pass

    def readbatch(self, pointers, tostore):
        pass

class _promptremote(object):
    """Prompt user to set lfs.url when accessed."""

    def __init__(self, repo, url):
        pass

    def writebatch(self, pointers, fromstore, ui=None):
        self._prompt()

    def readbatch(self, pointers, tostore, ui=None):
        self._prompt()

    def _prompt(self):
        raise error.Abort(_('lfs.url needs to be configured'))

_storemap = {
    'https': _gitlfsremote,
    'http': _gitlfsremote,
    'file': _dummyremote,
    'null': _nullremote,
    None: _promptremote,
}

def _verify(oid, content):
    realoid = hashlib.sha256(content).hexdigest()
    if realoid != oid:
        raise error.Abort(_('detected corrupt lfs object: %s') % oid,
                          hint=_('run hg verify'))

def _verifyfile(oid, fp):
    sha256 = hashlib.sha256()
    while True:
        data = fp.read(1024 * 1024)
        if not data:
            break
        sha256.update(data)
    realoid = sha256.hexdigest()
    if realoid != oid:
        raise error.Abort(_('detected corrupt lfs object: %s') % oid,
                          hint=_('run hg verify'))

def remote(repo):
    """remotestore factory. return a store in _storemap depending on config"""
    url = util.url(repo.ui.config('lfs', 'url') or '')
    scheme = url.scheme
    if scheme not in _storemap:
        raise error.Abort(_('lfs: unknown url scheme: %s') % scheme)
    return _storemap[scheme](repo, url)

class LfsRemoteError(error.RevlogError):
    pass
