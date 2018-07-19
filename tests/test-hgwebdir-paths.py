from __future__ import absolute_import

import os
from mercurial import (
    hg,
    ui as uimod,
)
from mercurial.hgweb import (
    hgwebdir_mod,
)
hgwebdir = hgwebdir_mod.hgwebdir

os.mkdir(b'webdir')
os.chdir(b'webdir')

webdir = os.path.realpath(b'.')

u = uimod.ui.load()
hg.repository(u, b'a', create=1)
hg.repository(u, b'b', create=1)
os.chdir(b'b')
hg.repository(u, b'd', create=1)
os.chdir(b'..')
hg.repository(u, b'c', create=1)
os.chdir(b'..')

paths = {b't/a/': b'%s/a' % webdir,
         b'b': b'%s/b' % webdir,
         b'coll': b'%s/*' % webdir,
         b'rcoll': b'%s/**' % webdir}

config = os.path.join(webdir, b'hgwebdir.conf')
configfile = open(config, 'wb')
configfile.write(b'[paths]\n')
for k, v in paths.items():
    configfile.write(b'%s = %s\n' % (k, v))
configfile.close()

confwd = hgwebdir(config)
dictwd = hgwebdir(paths)

assert len(confwd.repos) == len(dictwd.repos), 'different numbers'
assert len(confwd.repos) == 9, 'expected 9 repos, found %d' % len(confwd.repos)

found = dict(confwd.repos)
for key, path in dictwd.repos:
    assert key in found, 'repository %s was not found' % key
    assert found[key] == path, 'different paths for repo %s' % key
