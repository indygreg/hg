# __init__.py - narrowhg extension
#
# Copyright 2017 Google, Inc.
#
# This software may be used and distributed according to the terms of the
# GNU General Public License version 2 or any later version.
'''create clones which fetch history data for subset of files (EXPERIMENTAL)'''

from __future__ import absolute_import

# Note for extension authors: ONLY specify testedwith = 'ships-with-hg-core' for
# extensions which SHIP WITH MERCURIAL. Non-mainline extensions should
# be specifying the version(s) of Mercurial they are tested with, or
# leave the attribute unspecified.
testedwith = 'ships-with-hg-core'

from mercurial import (
    changegroup,
    extensions,
    hg,
    localrepo,
    registrar,
    verify as verifymod,
)

from . import (
    narrowbundle2,
    narrowchangegroup,
    narrowcommands,
    narrowcopies,
    narrowdirstate,
    narrowmerge,
    narrowpatch,
    narrowrepo,
    narrowrevlog,
    narrowtemplates,
    narrowwirepeer,
)

configtable = {}
configitem = registrar.configitem(configtable)
# Narrowhg *has* support for serving ellipsis nodes (which are used at
# least by Google's internal server), but that support is pretty
# fragile and has a lot of problems on real-world repositories that
# have complex graph topologies. This could probably be corrected, but
# absent someone needing the full support for ellipsis nodes in
# repositories with merges, it's unlikely this work will get done. As
# of this writining in late 2017, all repositories large enough for
# ellipsis nodes to be a hard requirement also enforce strictly linear
# history for other scaling reasons.
configitem('experimental', 'narrowservebrokenellipses',
           default=False,
           alias=[('narrow', 'serveellipses')],
)

# Export the commands table for Mercurial to see.
cmdtable = narrowcommands.table

def featuresetup(ui, features):
    features.add(changegroup.NARROW_REQUIREMENT)

def uisetup(ui):
    """Wraps user-facing mercurial commands with narrow-aware versions."""
    localrepo.featuresetupfuncs.add(featuresetup)
    narrowrevlog.setup()
    narrowbundle2.setup()
    narrowmerge.setup()
    narrowcommands.setup()
    narrowchangegroup.setup()
    narrowwirepeer.uisetup()

def reposetup(ui, repo):
    """Wraps local repositories with narrow repo support."""
    if not isinstance(repo, localrepo.localrepository):
        return

    narrowrepo.wraprepo(repo)
    if changegroup.NARROW_REQUIREMENT in repo.requirements:
        narrowcopies.setup(repo)
        narrowdirstate.setup(repo)
        narrowpatch.setup(repo)
        narrowwirepeer.reposetup(repo)

def _verifierinit(orig, self, repo, matcher=None):
    # The verifier's matcher argument was desgined for narrowhg, so it should
    # be None from core. If another extension passes a matcher (unlikely),
    # we'll have to fail until matchers can be composed more easily.
    assert matcher is None
    orig(self, repo, repo.narrowmatch())

def extsetup(ui):
    extensions.wrapfunction(verifymod.verifier, '__init__', _verifierinit)
    extensions.wrapfunction(hg, 'postshare', narrowrepo.wrappostshare)
    extensions.wrapfunction(hg, 'copystore', narrowrepo.unsharenarrowspec)

templatekeyword = narrowtemplates.templatekeyword
revsetpredicate = narrowtemplates.revsetpredicate
