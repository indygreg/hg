# Test that certain objects conform to well-defined interfaces.

from __future__ import absolute_import, print_function

import os

from mercurial.thirdparty.zope import (
    interface as zi,
)
from mercurial.thirdparty.zope.interface import (
    verify as ziverify,
)
from mercurial import (
    bundlerepo,
    filelog,
    httppeer,
    localrepo,
    repository,
    sshpeer,
    statichttprepo,
    ui as uimod,
    unionrepo,
    vfs as vfsmod,
    wireprotoserver,
    wireprototypes,
    wireprotov2server,
)

rootdir = os.path.normpath(os.path.join(os.path.dirname(__file__), '..'))

def checkzobject(o, allowextra=False):
    """Verify an object with a zope interface."""
    ifaces = zi.providedBy(o)
    if not ifaces:
        print('%r does not provide any zope interfaces' % o)
        return

    # Run zope.interface's built-in verification routine. This verifies that
    # everything that is supposed to be present is present.
    for iface in ifaces:
        ziverify.verifyObject(iface, o)

    if allowextra:
        return

    # Now verify that the object provides no extra public attributes that
    # aren't declared as part of interfaces.
    allowed = set()
    for iface in ifaces:
        allowed |= set(iface.names(all=True))

    public = {a for a in dir(o) if not a.startswith('_')}

    for attr in sorted(public - allowed):
        print('public attribute not declared in interfaces: %s.%s' % (
            o.__class__.__name__, attr))

# Facilitates testing localpeer.
class dummyrepo(object):
    def __init__(self):
        self.ui = uimod.ui()
    def filtered(self, name):
        pass
    def _restrictcapabilities(self, caps):
        pass

class dummyopener(object):
    handlers = []

# Facilitates testing sshpeer without requiring an SSH server.
class badpeer(httppeer.httppeer):
    def __init__(self):
        super(badpeer, self).__init__(None, None, None, dummyopener(), None)
        self.badattribute = True

    def badmethod(self):
        pass

class dummypipe(object):
    def close(self):
        pass

def main():
    ui = uimod.ui()
    # Needed so we can open a local repo with obsstore without a warning.
    ui.setconfig('experimental', 'evolution.createmarkers', True)

    checkzobject(badpeer())

    ziverify.verifyClass(repository.ipeerbaselegacycommands,
                         httppeer.httppeer)
    checkzobject(httppeer.httppeer(None, None, None, dummyopener(), None))

    ziverify.verifyClass(repository.ipeerbase,
                         localrepo.localpeer)
    checkzobject(localrepo.localpeer(dummyrepo()))

    ziverify.verifyClass(repository.ipeerbaselegacycommands,
                         sshpeer.sshv1peer)
    checkzobject(sshpeer.sshv1peer(ui, 'ssh://localhost/foo', None, dummypipe(),
                                   dummypipe(), None, None))

    ziverify.verifyClass(repository.ipeerbaselegacycommands,
                         sshpeer.sshv2peer)
    checkzobject(sshpeer.sshv2peer(ui, 'ssh://localhost/foo', None, dummypipe(),
                                   dummypipe(), None, None))

    ziverify.verifyClass(repository.ipeerbase, bundlerepo.bundlepeer)
    checkzobject(bundlerepo.bundlepeer(dummyrepo()))

    ziverify.verifyClass(repository.ipeerbase, statichttprepo.statichttppeer)
    checkzobject(statichttprepo.statichttppeer(dummyrepo()))

    ziverify.verifyClass(repository.ipeerbase, unionrepo.unionpeer)
    checkzobject(unionrepo.unionpeer(dummyrepo()))

    ziverify.verifyClass(repository.completelocalrepository,
                         localrepo.localrepository)
    repo = localrepo.localrepository(ui, rootdir)
    checkzobject(repo)

    ziverify.verifyClass(wireprototypes.baseprotocolhandler,
                         wireprotoserver.sshv1protocolhandler)
    ziverify.verifyClass(wireprototypes.baseprotocolhandler,
                         wireprotoserver.sshv2protocolhandler)
    ziverify.verifyClass(wireprototypes.baseprotocolhandler,
                         wireprotoserver.httpv1protocolhandler)
    ziverify.verifyClass(wireprototypes.baseprotocolhandler,
                         wireprotov2server.httpv2protocolhandler)

    sshv1 = wireprotoserver.sshv1protocolhandler(None, None, None)
    checkzobject(sshv1)
    sshv2 = wireprotoserver.sshv2protocolhandler(None, None, None)
    checkzobject(sshv2)

    httpv1 = wireprotoserver.httpv1protocolhandler(None, None, None)
    checkzobject(httpv1)
    httpv2 = wireprotov2server.httpv2protocolhandler(None, None)
    checkzobject(httpv2)

    ziverify.verifyClass(repository.ifilestorage, filelog.filelog)

    vfs = vfsmod.vfs('.')
    fl = filelog.filelog(vfs, 'dummy.i')
    checkzobject(fl, allowextra=True)

main()
