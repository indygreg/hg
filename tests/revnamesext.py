# Dummy extension to define a namespace containing revision names

from __future__ import absolute_import

from mercurial import (
    namespaces,
)

def reposetup(ui, repo):
    names = {b'r%d' % rev: repo[rev].node() for rev in repo}
    namemap = lambda r, name: names.get(name)
    nodemap = lambda r, node: [b'r%d' % repo[node].rev()]

    ns = namespaces.namespace(b'revnames', templatename=b'revname',
                              logname=b'revname',
                              listnames=lambda r: names.keys(),
                              namemap=namemap, nodemap=nodemap)
    repo.names.addnamespace(ns)
