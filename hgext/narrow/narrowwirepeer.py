# narrowwirepeer.py - passes narrow spec with unbundle command
#
# Copyright 2017 Google, Inc.
#
# This software may be used and distributed according to the terms of the
# GNU General Public License version 2 or any later version.

from __future__ import absolute_import

from mercurial import (
    bundle2,
    error,
    extensions,
    hg,
    match as matchmod,
    narrowspec,
    pycompat,
    wireprotoserver,
    wireprototypes,
    wireprotov1peer,
    wireprotov1server,
)

from . import narrowbundle2

def uisetup():
    extensions.wrapfunction(wireprotov1server, '_capabilities', addnarrowcap)
    wireprotov1peer.wirepeer.narrow_widen = peernarrowwiden

def addnarrowcap(orig, repo, proto):
    """add the narrow capability to the server"""
    caps = orig(repo, proto)
    caps.append(wireprotoserver.NARROWCAP)
    if repo.ui.configbool('experimental', 'narrowservebrokenellipses'):
        caps.append(wireprotoserver.ELLIPSESCAP)
    return caps

def reposetup(repo):
    def wirereposetup(ui, peer):
        def wrapped(orig, cmd, *args, **kwargs):
            if cmd == 'unbundle':
                # TODO: don't blindly add include/exclude wireproto
                # arguments to unbundle.
                include, exclude = repo.narrowpats
                kwargs[r"includepats"] = ','.join(include)
                kwargs[r"excludepats"] = ','.join(exclude)
            return orig(cmd, *args, **kwargs)
        extensions.wrapfunction(peer, '_calltwowaystream', wrapped)
    hg.wirepeersetupfuncs.append(wirereposetup)

@wireprotov1server.wireprotocommand('narrow_widen', 'oldincludes oldexcludes'
                                                    ' newincludes newexcludes'
                                                    ' commonheads cgversion'
                                                    ' known ellipses',
                                    permission='pull')
def narrow_widen(repo, proto, oldincludes, oldexcludes, newincludes,
                 newexcludes, commonheads, cgversion, known, ellipses):
    """wireprotocol command to send data when a narrow clone is widen. We will
    be sending a changegroup here.

    The current set of arguments which are required:
    oldincludes: the old includes of the narrow copy
    oldexcludes: the old excludes of the narrow copy
    newincludes: the new includes of the narrow copy
    newexcludes: the new excludes of the narrow copy
    commonheads: list of heads which are common between the server and client
    cgversion(maybe): the changegroup version to produce
    known: list of nodes which are known on the client (used in ellipses cases)
    ellipses: whether to send ellipses data or not
    """

    try:
        oldincludes = wireprototypes.decodelist(oldincludes)
        newincludes = wireprototypes.decodelist(newincludes)
        oldexcludes = wireprototypes.decodelist(oldexcludes)
        newexcludes = wireprototypes.decodelist(newexcludes)
        # validate the patterns
        narrowspec.validatepatterns(set(oldincludes))
        narrowspec.validatepatterns(set(newincludes))
        narrowspec.validatepatterns(set(oldexcludes))
        narrowspec.validatepatterns(set(newexcludes))

        common = wireprototypes.decodelist(commonheads)
        known = None
        if known:
            known = wireprototypes.decodelist(known)
        if ellipses == '0':
            ellipses = False
        else:
            ellipses = bool(ellipses)
        cgversion = cgversion
        newmatch = narrowspec.match(repo.root, include=newincludes,
                                    exclude=newexcludes)
        oldmatch = narrowspec.match(repo.root, include=oldincludes,
                                    exclude=oldexcludes)
        diffmatch = matchmod.differencematcher(newmatch, oldmatch)

        bundler = narrowbundle2.widen_bundle(repo, diffmatch, common, known,
                                             cgversion, ellipses)
    except error.Abort as exc:
        bundler = bundle2.bundle20(repo.ui)
        manargs = [('message', pycompat.bytestr(exc))]
        advargs = []
        if exc.hint is not None:
            advargs.append(('hint', exc.hint))
        bundler.addpart(bundle2.bundlepart('error:abort', manargs, advargs))

    chunks = bundler.getchunks()
    return wireprototypes.streamres(gen=chunks)

def peernarrowwiden(remote, **kwargs):
    for ch in ('oldincludes', 'newincludes', 'oldexcludes', 'newexcludes',
               'commonheads', 'known'):
        kwargs[ch] = wireprototypes.encodelist(kwargs[ch])

    kwargs['ellipses'] = '%i' % bool(kwargs['ellipses'])
    f = remote._callcompressable('narrow_widen', **kwargs)
    return bundle2.getunbundler(remote.ui, f)
