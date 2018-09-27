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

configitem('simplecache', 'cacheobjects',
           default=False)
configitem('simplecache', 'redirectsfile',
           default=None)

@interfaceutil.implementer(repository.iwireprotocolcommandcacher)
class memorycacher(object):
    def __init__(self, ui, command, encodefn):
        self.ui = ui
        self.encodefn = encodefn
        self.key = None
        self.cacheobjects = ui.configbool('simplecache', 'cacheobjects')
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

def makeresponsecacher(orig, repo, proto, command, args, objencoderfn):
    return memorycacher(repo.ui, command, objencoderfn)

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
