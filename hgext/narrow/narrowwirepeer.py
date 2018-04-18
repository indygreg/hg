# narrowwirepeer.py - passes narrow spec with unbundle command
#
# Copyright 2017 Google, Inc.
#
# This software may be used and distributed according to the terms of the
# GNU General Public License version 2 or any later version.

from __future__ import absolute_import

from mercurial.i18n import _
from mercurial import (
    error,
    extensions,
    hg,
    narrowspec,
    node,
)

def uisetup():
    def peersetup(ui, peer):
        # We must set up the expansion before reposetup below, since it's used
        # at clone time before we have a repo.
        class expandingpeer(peer.__class__):
            def expandnarrow(self, narrow_include, narrow_exclude, nodes):
                ui.status(_("expanding narrowspec\n"))
                if not self.capable('exp-expandnarrow'):
                    raise error.Abort(
                        'peer does not support expanding narrowspecs')

                hex_nodes = (node.hex(n) for n in nodes)
                new_narrowspec = self._call(
                    'expandnarrow',
                    includepats=','.join(narrow_include),
                    excludepats=','.join(narrow_exclude),
                    nodes=','.join(hex_nodes))

                return narrowspec.parseserverpatterns(new_narrowspec)
        peer.__class__ = expandingpeer
    hg.wirepeersetupfuncs.append(peersetup)

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
