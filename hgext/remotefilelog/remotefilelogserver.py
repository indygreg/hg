# remotefilelogserver.py - server logic for a remotefilelog server
#
# Copyright 2013 Facebook, Inc.
#
# This software may be used and distributed according to the terms of the
# GNU General Public License version 2 or any later version.
from __future__ import absolute_import

import errno
import os
import stat
import time
import zlib

from mercurial.i18n import _
from mercurial.node import bin, hex, nullid
from mercurial import (
    changegroup,
    changelog,
    context,
    error,
    extensions,
    match,
    store,
    streamclone,
    util,
    wireprotoserver,
    wireprototypes,
    wireprotov1server,
)
from .  import (
    constants,
    shallowutil,
)

_sshv1server = wireprotoserver.sshv1protocolhandler

def setupserver(ui, repo):
    """Sets up a normal Mercurial repo so it can serve files to shallow repos.
    """
    onetimesetup(ui)

    # don't send files to shallow clients during pulls
    def generatefiles(orig, self, changedfiles, linknodes, commonrevs, source,
                      *args, **kwargs):
        caps = self._bundlecaps or []
        if constants.BUNDLE2_CAPABLITY in caps:
            # only send files that don't match the specified patterns
            includepattern = None
            excludepattern = None
            for cap in (self._bundlecaps or []):
                if cap.startswith("includepattern="):
                    includepattern = cap[len("includepattern="):].split('\0')
                elif cap.startswith("excludepattern="):
                    excludepattern = cap[len("excludepattern="):].split('\0')

            m = match.always(repo.root, '')
            if includepattern or excludepattern:
                m = match.match(repo.root, '', None,
                    includepattern, excludepattern)

            changedfiles = list([f for f in changedfiles if not m(f)])
        return orig(self, changedfiles, linknodes, commonrevs, source,
                    *args, **kwargs)

    extensions.wrapfunction(
        changegroup.cgpacker, 'generatefiles', generatefiles)

onetime = False
def onetimesetup(ui):
    """Configures the wireprotocol for both clients and servers.
    """
    global onetime
    if onetime:
        return
    onetime = True

    # support file content requests
    wireprotov1server.wireprotocommand(
        'x_rfl_getflogheads', 'path', permission='pull')(getflogheads)
    wireprotov1server.wireprotocommand(
        'x_rfl_getfiles', '', permission='pull')(getfiles)
    wireprotov1server.wireprotocommand(
        'x_rfl_getfile', 'file node', permission='pull')(getfile)

    class streamstate(object):
        match = None
        shallowremote = False
        noflatmf = False
    state = streamstate()

    def stream_out_shallow(repo, proto, other):
        includepattern = None
        excludepattern = None
        raw = other.get('includepattern')
        if raw:
            includepattern = raw.split('\0')
        raw = other.get('excludepattern')
        if raw:
            excludepattern = raw.split('\0')

        oldshallow = state.shallowremote
        oldmatch = state.match
        oldnoflatmf = state.noflatmf
        try:
            state.shallowremote = True
            state.match = match.always(repo.root, '')
            state.noflatmf = other.get('noflatmanifest') == 'True'
            if includepattern or excludepattern:
                state.match = match.match(repo.root, '', None,
                    includepattern, excludepattern)
            streamres = wireprotov1server.stream(repo, proto)

            # Force the first value to execute, so the file list is computed
            # within the try/finally scope
            first = next(streamres.gen)
            second = next(streamres.gen)
            def gen():
                yield first
                yield second
                for value in streamres.gen:
                    yield value
            return wireprototypes.streamres(gen())
        finally:
            state.shallowremote = oldshallow
            state.match = oldmatch
            state.noflatmf = oldnoflatmf

    wireprotov1server.commands['stream_out_shallow'] = (stream_out_shallow, '*')

    # don't clone filelogs to shallow clients
    def _walkstreamfiles(orig, repo, matcher=None):
        if state.shallowremote:
            # if we are shallow ourselves, stream our local commits
            if shallowutil.isenabled(repo):
                striplen = len(repo.store.path) + 1
                readdir = repo.store.rawvfs.readdir
                visit = [os.path.join(repo.store.path, 'data')]
                while visit:
                    p = visit.pop()
                    for f, kind, st in readdir(p, stat=True):
                        fp = p + '/' + f
                        if kind == stat.S_IFREG:
                            if not fp.endswith('.i') and not fp.endswith('.d'):
                                n = util.pconvert(fp[striplen:])
                                yield (store.decodedir(n), n, st.st_size)
                        if kind == stat.S_IFDIR:
                            visit.append(fp)

            if 'treemanifest' in repo.requirements:
                for (u, e, s) in repo.store.datafiles():
                    if (u.startswith('meta/') and
                        (u.endswith('.i') or u.endswith('.d'))):
                        yield (u, e, s)

            # Return .d and .i files that do not match the shallow pattern
            match = state.match
            if match and not match.always():
                for (u, e, s) in repo.store.datafiles():
                    f = u[5:-2]  # trim data/...  and .i/.d
                    if not state.match(f):
                        yield (u, e, s)

            for x in repo.store.topfiles():
                if state.noflatmf and x[0][:11] == '00manifest.':
                    continue
                yield x

        elif shallowutil.isenabled(repo):
            # don't allow cloning from a shallow repo to a full repo
            # since it would require fetching every version of every
            # file in order to create the revlogs.
            raise error.Abort(_("Cannot clone from a shallow repo "
                                "to a full repo."))
        else:
            for x in orig(repo, matcher):
                yield x

    extensions.wrapfunction(streamclone, '_walkstreamfiles', _walkstreamfiles)

    # expose remotefilelog capabilities
    def _capabilities(orig, repo, proto):
        caps = orig(repo, proto)
        if (shallowutil.isenabled(repo) or ui.configbool('remotefilelog',
                                                         'server')):
            if isinstance(proto, _sshv1server):
                # legacy getfiles method which only works over ssh
                caps.append(constants.NETWORK_CAP_LEGACY_SSH_GETFILES)
            caps.append('x_rfl_getflogheads')
            caps.append('x_rfl_getfile')
        return caps
    extensions.wrapfunction(wireprotov1server, '_capabilities', _capabilities)

    def _adjustlinkrev(orig, self, *args, **kwargs):
        # When generating file blobs, taking the real path is too slow on large
        # repos, so force it to just return the linkrev directly.
        repo = self._repo
        if util.safehasattr(repo, 'forcelinkrev') and repo.forcelinkrev:
            return self._filelog.linkrev(self._filelog.rev(self._filenode))
        return orig(self, *args, **kwargs)

    extensions.wrapfunction(
        context.basefilectx, '_adjustlinkrev', _adjustlinkrev)

    def _iscmd(orig, cmd):
        if cmd == 'x_rfl_getfiles':
            return False
        return orig(cmd)

    extensions.wrapfunction(wireprotoserver, 'iscmd', _iscmd)

def _loadfileblob(repo, cachepath, path, node):
    filecachepath = os.path.join(cachepath, path, hex(node))
    if not os.path.exists(filecachepath) or os.path.getsize(filecachepath) == 0:
        filectx = repo.filectx(path, fileid=node)
        if filectx.node() == nullid:
            repo.changelog = changelog.changelog(repo.svfs)
            filectx = repo.filectx(path, fileid=node)

        text = createfileblob(filectx)
        # TODO configurable compression engines
        text = zlib.compress(text)

        # everything should be user & group read/writable
        oldumask = os.umask(0o002)
        try:
            dirname = os.path.dirname(filecachepath)
            if not os.path.exists(dirname):
                try:
                    os.makedirs(dirname)
                except OSError as ex:
                    if ex.errno != errno.EEXIST:
                        raise

            f = None
            try:
                f = util.atomictempfile(filecachepath, "wb")
                f.write(text)
            except (IOError, OSError):
                # Don't abort if the user only has permission to read,
                # and not write.
                pass
            finally:
                if f:
                    f.close()
        finally:
            os.umask(oldumask)
    else:
        with open(filecachepath, "rb") as f:
            text = f.read()
    return text

def getflogheads(repo, proto, path):
    """A server api for requesting a filelog's heads
    """
    flog = repo.file(path)
    heads = flog.heads()
    return '\n'.join((hex(head) for head in heads if head != nullid))

def getfile(repo, proto, file, node):
    """A server api for requesting a particular version of a file. Can be used
    in batches to request many files at once. The return protocol is:
    <errorcode>\0<data/errormsg> where <errorcode> is 0 for success or
    non-zero for an error.

    data is a compressed blob with revlog flag and ancestors information. See
    createfileblob for its content.
    """
    if shallowutil.isenabled(repo):
        return '1\0' + _('cannot fetch remote files from shallow repo')
    cachepath = repo.ui.config("remotefilelog", "servercachepath")
    if not cachepath:
        cachepath = os.path.join(repo.path, "remotefilelogcache")
    node = bin(node.strip())
    if node == nullid:
        return '0\0'
    return '0\0' + _loadfileblob(repo, cachepath, file, node)

def getfiles(repo, proto):
    """A server api for requesting particular versions of particular files.
    """
    if shallowutil.isenabled(repo):
        raise error.Abort(_('cannot fetch remote files from shallow repo'))
    if not isinstance(proto, _sshv1server):
        raise error.Abort(_('cannot fetch remote files over non-ssh protocol'))

    def streamer():
        fin = proto._fin

        cachepath = repo.ui.config("remotefilelog", "servercachepath")
        if not cachepath:
            cachepath = os.path.join(repo.path, "remotefilelogcache")

        while True:
            request = fin.readline()[:-1]
            if not request:
                break

            node = bin(request[:40])
            if node == nullid:
                yield '0\n'
                continue

            path = request[40:]

            text = _loadfileblob(repo, cachepath, path, node)

            yield '%d\n%s' % (len(text), text)

            # it would be better to only flush after processing a whole batch
            # but currently we don't know if there are more requests coming
            proto._fout.flush()
    return wireprototypes.streamres(streamer())

def createfileblob(filectx):
    """
    format:
        v0:
            str(len(rawtext)) + '\0' + rawtext + ancestortext
        v1:
            'v1' + '\n' + metalist + '\0' + rawtext + ancestortext
            metalist := metalist + '\n' + meta | meta
            meta := sizemeta | flagmeta
            sizemeta := METAKEYSIZE + str(len(rawtext))
            flagmeta := METAKEYFLAG + str(flag)

            note: sizemeta must exist. METAKEYFLAG and METAKEYSIZE must have a
            length of 1.
    """
    flog = filectx.filelog()
    frev = filectx.filerev()
    revlogflags = flog._revlog.flags(frev)
    if revlogflags == 0:
        # normal files
        text = filectx.data()
    else:
        # lfs, read raw revision data
        text = flog.revision(frev, raw=True)

    repo = filectx._repo

    ancestors = [filectx]

    try:
        repo.forcelinkrev = True
        ancestors.extend([f for f in filectx.ancestors()])

        ancestortext = ""
        for ancestorctx in ancestors:
            parents = ancestorctx.parents()
            p1 = nullid
            p2 = nullid
            if len(parents) > 0:
                p1 = parents[0].filenode()
            if len(parents) > 1:
                p2 = parents[1].filenode()

            copyname = ""
            rename = ancestorctx.renamed()
            if rename:
                copyname = rename[0]
            linknode = ancestorctx.node()
            ancestortext += "%s%s%s%s%s\0" % (
                ancestorctx.filenode(), p1, p2, linknode,
                copyname)
    finally:
        repo.forcelinkrev = False

    header = shallowutil.buildfileblobheader(len(text), revlogflags)

    return "%s\0%s%s" % (header, text, ancestortext)

def gcserver(ui, repo):
    if not repo.ui.configbool("remotefilelog", "server"):
        return

    neededfiles = set()
    heads = repo.revs("heads(tip~25000:) - null")

    cachepath = repo.vfs.join("remotefilelogcache")
    for head in heads:
        mf = repo[head].manifest()
        for filename, filenode in mf.iteritems():
            filecachepath = os.path.join(cachepath, filename, hex(filenode))
            neededfiles.add(filecachepath)

    # delete unneeded older files
    days = repo.ui.configint("remotefilelog", "serverexpiration")
    expiration = time.time() - (days * 24 * 60 * 60)

    progress = ui.makeprogress(_("removing old server cache"), unit="files")
    progress.update(0)
    for root, dirs, files in os.walk(cachepath):
        for file in files:
            filepath = os.path.join(root, file)
            progress.increment()
            if filepath in neededfiles:
                continue

            stat = os.stat(filepath)
            if stat.st_mtime < expiration:
                os.remove(filepath)

    progress.complete()
