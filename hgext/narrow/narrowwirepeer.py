# narrowwirepeer.py - passes narrow spec with unbundle command
#
# Copyright 2017 Google, Inc.
#
# This software may be used and distributed according to the terms of the
# GNU General Public License version 2 or any later version.

from __future__ import absolute_import

from mercurial import (
    extensions,
    hg,
    wireprotov1server,
)

NARROWCAP = 'exp-narrow-1'
ELLIPSESCAP = 'exp-ellipses-1'

def uisetup():
    extensions.wrapfunction(wireprotov1server, '_capabilities', addnarrowcap)

def addnarrowcap(orig, repo, proto):
    """add the narrow capability to the server"""
    caps = orig(repo, proto)
    caps.append(NARROWCAP)
    if repo.ui.configbool('experimental', 'narrowservebrokenellipses'):
        caps.append(ELLIPSESCAP)
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
