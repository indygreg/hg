# wireprotosimplecache.py - Extension providing in-memory wire protocol cache
#
# Copyright 2018 Gregory Szorc <gregory.szorc@gmail.com>
#
# This software may be used and distributed according to the terms of the
# GNU General Public License version 2 or any later version.

from __future__ import absolute_import

from mercurial import (
    extensions,
    registrar,
    repository,
    util,
    wireprotoserver,
    wireprototypes,
    wireprotov2server,
)
from mercurial.utils import (
    interfaceutil,
    stringutil,
)

CACHE = None

configtable = {}
configitem = registrar.configitem(configtable)

configitem('simplecache', 'cacheapi',
           default=False)
configitem('simplecache', 'cacheobjects',
           default=False)
configitem('simplecache', 'redirectsfile',
           default=None)

# API handler that makes cached keys available.
def handlecacherequest(rctx, req, res, checkperm, urlparts):
    if rctx.repo.ui.configbool('simplecache', 'cacheobjects'):
        res.status = b'500 Internal Server Error'
        res.setbodybytes(b'cacheobjects not supported for api server')
        return

    if not urlparts:
        res.status = b'200 OK'
        res.headers[b'Content-Type'] = b'text/plain'
        res.setbodybytes(b'simple cache server')
        return

    key = b'/'.join(urlparts)

    if key not in CACHE:
        res.status = b'404 Not Found'
        res.headers[b'Content-Type'] = b'text/plain'
        res.setbodybytes(b'key not found in cache')
        return

    res.status = b'200 OK'
    res.headers[b'Content-Type'] = b'application/mercurial-cbor'
    res.setbodybytes(CACHE[key])

def cachedescriptor(req, repo):
    return {}

wireprotoserver.API_HANDLERS[b'simplecache'] = {
    'config': (b'simplecache', b'cacheapi'),
    'handler': handlecacherequest,
    'apidescriptor': cachedescriptor,
}

@interfaceutil.implementer(repository.iwireprotocolcommandcacher)
class memorycacher(object):
    def __init__(self, ui, command, encodefn, redirecttargets, redirecthashes,
                 req):
        self.ui = ui
        self.encodefn = encodefn
        self.redirecttargets = redirecttargets
        self.redirecthashes = redirecthashes
        self.req = req
        self.key = None
        self.cacheobjects = ui.configbool('simplecache', 'cacheobjects')
        self.cacheapi = ui.configbool('simplecache', 'cacheapi')
        self.buffered = []

        ui.log('simplecache', 'cacher constructed for %s\n', command)

    def __enter__(self):
        return self

    def __exit__(self, exctype, excvalue, exctb):
        if exctype:
            self.ui.log('simplecache', 'cacher exiting due to error\n')

    def adjustcachekeystate(self, state):
        # Needed in order to make tests deterministic. Don't copy this
        # pattern for production caches!
        del state[b'repo']

    def setcachekey(self, key):
        self.key = key
        return True

    def lookup(self):
        if self.key not in CACHE:
            self.ui.log('simplecache', 'cache miss for %s\n', self.key)
            return None

        entry = CACHE[self.key]
        self.ui.log('simplecache', 'cache hit for %s\n', self.key)

        redirectable = True

        if not self.cacheapi:
            redirectable = False
        elif not self.redirecttargets:
            redirectable = False
        else:
            clienttargets = set(self.redirecttargets)
            ourtargets = set(t[b'name'] for t in loadredirecttargets(self.ui))

            # We only ever redirect to a single target (for now). So we don't
            # need to store which target matched.
            if not clienttargets & ourtargets:
                redirectable = False

        if redirectable:
            paths = self.req.dispatchparts[:-3]
            paths.append(b'simplecache')
            paths.append(self.key)

            url = b'%s/%s' % (self.req.advertisedbaseurl, b'/'.join(paths))

            #url = b'http://example.com/%s' % self.key
            self.ui.log('simplecache', 'sending content redirect for %s to '
                                       '%s\n', self.key, url)
            response = wireprototypes.alternatelocationresponse(
                url=url,
                mediatype=b'application/mercurial-cbor')

            return {'objs': [response]}

        if self.cacheobjects:
            return {
                'objs': entry,
            }
        else:
            return {
                'objs': [wireprototypes.encodedresponse(entry)],
            }

    def onobject(self, obj):
        if self.cacheobjects:
            self.buffered.append(obj)
        else:
            self.buffered.extend(self.encodefn(obj))

        yield obj

    def onfinished(self):
        self.ui.log('simplecache', 'storing cache entry for %s\n', self.key)
        if self.cacheobjects:
            CACHE[self.key] = self.buffered
        else:
            CACHE[self.key] = b''.join(self.buffered)

        return []

def makeresponsecacher(orig, repo, proto, command, args, objencoderfn,
                       redirecttargets, redirecthashes):
    return memorycacher(repo.ui, command, objencoderfn, redirecttargets,
                        redirecthashes, proto._req)

def loadredirecttargets(ui):
    path = ui.config('simplecache', 'redirectsfile')
    if not path:
        return []

    with open(path, 'rb') as fh:
        s = fh.read()

    return stringutil.evalpythonliteral(s)

def getadvertisedredirecttargets(orig, repo, proto):
    return loadredirecttargets(repo.ui)

def extsetup(ui):
    global CACHE

    CACHE = util.lrucachedict(10000)

    extensions.wrapfunction(wireprotov2server, 'makeresponsecacher',
                            makeresponsecacher)
    extensions.wrapfunction(wireprotov2server, 'getadvertisedredirecttargets',
                            getadvertisedredirecttargets)
