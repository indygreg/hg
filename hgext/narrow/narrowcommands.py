# narrowcommands.py - command modifications for narrowhg extension
#
# Copyright 2017 Google, Inc.
#
# This software may be used and distributed according to the terms of the
# GNU General Public License version 2 or any later version.
from __future__ import absolute_import

import itertools

from mercurial.i18n import _
from mercurial import (
    changegroup,
    cmdutil,
    commands,
    discovery,
    error,
    exchange,
    extensions,
    hg,
    merge,
    narrowspec,
    node,
    pycompat,
    registrar,
    repair,
    repoview,
    util,
)

from . import (
    narrowbundle2,
)

table = {}
command = registrar.command(table)

def setup():
    """Wraps user-facing mercurial commands with narrow-aware versions."""

    entry = extensions.wrapcommand(commands.table, 'clone', clonenarrowcmd)
    entry[1].append(('', 'narrow', None,
                     _("create a narrow clone of select files")))
    entry[1].append(('', 'depth', '',
                     _("limit the history fetched by distance from heads")))
    # TODO(durin42): unify sparse/narrow --include/--exclude logic a bit
    if 'sparse' not in extensions.enabled():
        entry[1].append(('', 'include', [],
                         _("specifically fetch this file/directory")))
        entry[1].append(
            ('', 'exclude', [],
             _("do not fetch this file/directory, even if included")))

    entry = extensions.wrapcommand(commands.table, 'pull', pullnarrowcmd)
    entry[1].append(('', 'depth', '',
                     _("limit the history fetched by distance from heads")))

    extensions.wrapcommand(commands.table, 'archive', archivenarrowcmd)

def expandpull(pullop, includepats, excludepats):
    if not narrowspec.needsexpansion(includepats):
        return includepats, excludepats

    heads = pullop.heads or pullop.rheads
    includepats, excludepats = pullop.remote.expandnarrow(
        includepats, excludepats, heads)
    pullop.repo.ui.debug('Expanded narrowspec to inc=%s, exc=%s\n' % (
        includepats, excludepats))
    return set(includepats), set(excludepats)

def clonenarrowcmd(orig, ui, repo, *args, **opts):
    """Wraps clone command, so 'hg clone' first wraps localrepo.clone()."""
    opts = pycompat.byteskwargs(opts)
    wrappedextraprepare = util.nullcontextmanager()
    opts_narrow = opts['narrow']
    if opts_narrow:
        def pullbundle2extraprepare_widen(orig, pullop, kwargs):
            # Create narrow spec patterns from clone flags
            includepats = narrowspec.parsepatterns(opts['include'])
            excludepats = narrowspec.parsepatterns(opts['exclude'])

            # If necessary, ask the server to expand the narrowspec.
            includepats, excludepats = expandpull(
                pullop, includepats, excludepats)

            if not includepats and excludepats:
                # If nothing was included, we assume the user meant to include
                # everything, except what they asked to exclude.
                includepats = {'path:.'}

            pullop.repo.setnarrowpats(includepats, excludepats)

            # This will populate 'includepats' etc with the values from the
            # narrowspec we just saved.
            orig(pullop, kwargs)

            if opts.get('depth'):
                kwargs['depth'] = opts['depth']
        wrappedextraprepare = extensions.wrappedfunction(exchange,
            '_pullbundle2extraprepare', pullbundle2extraprepare_widen)

    def pullnarrow(orig, repo, *args, **kwargs):
        if opts_narrow:
            repo.requirements.add(changegroup.NARROW_REQUIREMENT)
            repo._writerequirements()

        return orig(repo, *args, **kwargs)

    wrappedpull = extensions.wrappedfunction(exchange, 'pull', pullnarrow)

    with wrappedextraprepare, wrappedpull:
        return orig(ui, repo, *args, **pycompat.strkwargs(opts))

def pullnarrowcmd(orig, ui, repo, *args, **opts):
    """Wraps pull command to allow modifying narrow spec."""
    wrappedextraprepare = util.nullcontextmanager()
    if changegroup.NARROW_REQUIREMENT in repo.requirements:

        def pullbundle2extraprepare_widen(orig, pullop, kwargs):
            orig(pullop, kwargs)
            if opts.get(r'depth'):
                kwargs['depth'] = opts[r'depth']
        wrappedextraprepare = extensions.wrappedfunction(exchange,
            '_pullbundle2extraprepare', pullbundle2extraprepare_widen)

    with wrappedextraprepare:
        return orig(ui, repo, *args, **opts)

def archivenarrowcmd(orig, ui, repo, *args, **opts):
    """Wraps archive command to narrow the default includes."""
    if changegroup.NARROW_REQUIREMENT in repo.requirements:
        repo_includes, repo_excludes = repo.narrowpats
        includes = set(opts.get(r'include', []))
        excludes = set(opts.get(r'exclude', []))
        includes, excludes, unused_invalid = narrowspec.restrictpatterns(
            includes, excludes, repo_includes, repo_excludes)
        if includes:
            opts[r'include'] = includes
        if excludes:
            opts[r'exclude'] = excludes
    return orig(ui, repo, *args, **opts)

def pullbundle2extraprepare(orig, pullop, kwargs):
    repo = pullop.repo
    if changegroup.NARROW_REQUIREMENT not in repo.requirements:
        return orig(pullop, kwargs)

    if narrowbundle2.NARROWCAP not in pullop.remotebundle2caps:
        raise error.Abort(_("server doesn't support narrow clones"))
    orig(pullop, kwargs)
    kwargs['narrow'] = True
    include, exclude = repo.narrowpats
    kwargs['oldincludepats'] = include
    kwargs['oldexcludepats'] = exclude
    kwargs['includepats'] = include
    kwargs['excludepats'] = exclude
    kwargs['known'] = [node.hex(ctx.node()) for ctx in
                       repo.set('::%ln', pullop.common)
                       if ctx.node() != node.nullid]
    if not kwargs['known']:
        # Mercurial serialized an empty list as '' and deserializes it as
        # [''], so delete it instead to avoid handling the empty string on the
        # server.
        del kwargs['known']

extensions.wrapfunction(exchange,'_pullbundle2extraprepare',
                        pullbundle2extraprepare)

def _narrow(ui, repo, remote, commoninc, oldincludes, oldexcludes,
            newincludes, newexcludes, force):
    oldmatch = narrowspec.match(repo.root, oldincludes, oldexcludes)
    newmatch = narrowspec.match(repo.root, newincludes, newexcludes)

    # This is essentially doing "hg outgoing" to find all local-only
    # commits. We will then check that the local-only commits don't
    # have any changes to files that will be untracked.
    unfi = repo.unfiltered()
    outgoing = discovery.findcommonoutgoing(unfi, remote,
                                            commoninc=commoninc)
    ui.status(_('looking for local changes to affected paths\n'))
    localnodes = []
    for n in itertools.chain(outgoing.missing, outgoing.excluded):
        if any(oldmatch(f) and not newmatch(f) for f in unfi[n].files()):
            localnodes.append(n)
    revstostrip = unfi.revs('descendants(%ln)', localnodes)
    hiddenrevs = repoview.filterrevs(repo, 'visible')
    visibletostrip = list(repo.changelog.node(r)
                          for r in (revstostrip - hiddenrevs))
    if visibletostrip:
        ui.status(_('The following changeset(s) or their ancestors have '
                    'local changes not on the remote:\n'))
        maxnodes = 10
        if ui.verbose or len(visibletostrip) <= maxnodes:
            for n in visibletostrip:
                ui.status('%s\n' % node.short(n))
        else:
            for n in visibletostrip[:maxnodes]:
                ui.status('%s\n' % node.short(n))
            ui.status(_('...and %d more, use --verbose to list all\n') %
                      (len(visibletostrip) - maxnodes))
        if not force:
            raise error.Abort(_('local changes found'),
                              hint=_('use --force-delete-local-changes to '
                                     'ignore'))

    with ui.uninterruptable():
        if revstostrip:
            tostrip = [unfi.changelog.node(r) for r in revstostrip]
            if repo['.'].node() in tostrip:
                # stripping working copy, so move to a different commit first
                urev = max(repo.revs('(::%n) - %ln + null',
                                     repo['.'].node(), visibletostrip))
                hg.clean(repo, urev)
            repair.strip(ui, unfi, tostrip, topic='narrow')

        todelete = []
        for f, f2, size in repo.store.datafiles():
            if f.startswith('data/'):
                file = f[5:-2]
                if not newmatch(file):
                    todelete.append(f)
            elif f.startswith('meta/'):
                dir = f[5:-13]
                dirs = ['.'] + sorted(util.dirs({dir})) + [dir]
                include = True
                for d in dirs:
                    visit = newmatch.visitdir(d)
                    if not visit:
                        include = False
                        break
                    if visit == 'all':
                        break
                if not include:
                    todelete.append(f)

        repo.destroying()

        with repo.transaction("narrowing"):
            for f in todelete:
                ui.status(_('deleting %s\n') % f)
                util.unlinkpath(repo.svfs.join(f))
                repo.store.markremoved(f)

            for f in repo.dirstate:
                if not newmatch(f):
                    repo.dirstate.drop(f)
                    repo.wvfs.unlinkpath(f)
            repo.setnarrowpats(newincludes, newexcludes)

        repo.destroyed()

def _widen(ui, repo, remote, commoninc, newincludes, newexcludes):
    newmatch = narrowspec.match(repo.root, newincludes, newexcludes)

    # TODO(martinvonz): Get expansion working with widening/narrowing.
    if narrowspec.needsexpansion(newincludes):
        raise error.Abort('Expansion not yet supported on pull')

    def pullbundle2extraprepare_widen(orig, pullop, kwargs):
        orig(pullop, kwargs)
        # The old{in,ex}cludepats have already been set by orig()
        kwargs['includepats'] = newincludes
        kwargs['excludepats'] = newexcludes
    wrappedextraprepare = extensions.wrappedfunction(exchange,
        '_pullbundle2extraprepare', pullbundle2extraprepare_widen)

    # define a function that narrowbundle2 can call after creating the
    # backup bundle, but before applying the bundle from the server
    def setnewnarrowpats():
        repo.setnarrowpats(newincludes, newexcludes)
    repo.setnewnarrowpats = setnewnarrowpats

    with ui.uninterruptable():
        ds = repo.dirstate
        p1, p2 = ds.p1(), ds.p2()
        with ds.parentchange():
            ds.setparents(node.nullid, node.nullid)
        common = commoninc[0]
        with wrappedextraprepare:
            exchange.pull(repo, remote, heads=common)
        with ds.parentchange():
            ds.setparents(p1, p2)

        actions = {k: [] for k in 'a am f g cd dc r dm dg m e k p pr'.split()}
        addgaction = actions['g'].append

        mf = repo['.'].manifest().matches(newmatch)
        for f, fn in mf.iteritems():
            if f not in repo.dirstate:
                addgaction((f, (mf.flags(f), False),
                            "add from widened narrow clone"))

        merge.applyupdates(repo, actions, wctx=repo[None],
                           mctx=repo['.'], overwrite=False)
        merge.recordupdates(repo, actions, branchmerge=False)

# TODO(rdamazio): Make new matcher format and update description
@command('tracked',
    [('', 'addinclude', [], _('new paths to include')),
     ('', 'removeinclude', [], _('old paths to no longer include')),
     ('', 'addexclude', [], _('new paths to exclude')),
     ('', 'removeexclude', [], _('old paths to no longer exclude')),
     ('', 'clear', False, _('whether to replace the existing narrowspec')),
     ('', 'force-delete-local-changes', False,
       _('forces deletion of local changes when narrowing')),
    ] + commands.remoteopts,
    _('[OPTIONS]... [REMOTE]'),
    inferrepo=True)
def trackedcmd(ui, repo, remotepath=None, *pats, **opts):
    """show or change the current narrowspec

    With no argument, shows the current narrowspec entries, one per line. Each
    line will be prefixed with 'I' or 'X' for included or excluded patterns,
    respectively.

    The narrowspec is comprised of expressions to match remote files and/or
    directories that should be pulled into your client.
    The narrowspec has *include* and *exclude* expressions, with excludes always
    trumping includes: that is, if a file matches an exclude expression, it will
    be excluded even if it also matches an include expression.
    Excluding files that were never included has no effect.

    Each included or excluded entry is in the format described by
    'hg help patterns'.

    The options allow you to add or remove included and excluded expressions.

    If --clear is specified, then all previous includes and excludes are DROPPED
    and replaced by the new ones specified to --addinclude and --addexclude.
    If --clear is specified without any further options, the narrowspec will be
    empty and will not match any files.
    """
    opts = pycompat.byteskwargs(opts)
    if changegroup.NARROW_REQUIREMENT not in repo.requirements:
        ui.warn(_('The narrow command is only supported on respositories cloned'
                  ' with --narrow.\n'))
        return 1

    # Before supporting, decide whether it "hg tracked --clear" should mean
    # tracking no paths or all paths.
    if opts['clear']:
        ui.warn(_('The --clear option is not yet supported.\n'))
        return 1

    if narrowspec.needsexpansion(opts['addinclude'] + opts['addexclude']):
        raise error.Abort('Expansion not yet supported on widen/narrow')

    addedincludes = narrowspec.parsepatterns(opts['addinclude'])
    removedincludes = narrowspec.parsepatterns(opts['removeinclude'])
    addedexcludes = narrowspec.parsepatterns(opts['addexclude'])
    removedexcludes = narrowspec.parsepatterns(opts['removeexclude'])
    widening = addedincludes or removedexcludes
    narrowing = removedincludes or addedexcludes
    only_show = not widening and not narrowing

    # Only print the current narrowspec.
    if only_show:
        include, exclude = repo.narrowpats

        ui.pager('tracked')
        fm = ui.formatter('narrow', opts)
        for i in sorted(include):
            fm.startitem()
            fm.write('status', '%s ', 'I', label='narrow.included')
            fm.write('pat', '%s\n', i, label='narrow.included')
        for i in sorted(exclude):
            fm.startitem()
            fm.write('status', '%s ', 'X', label='narrow.excluded')
            fm.write('pat', '%s\n', i, label='narrow.excluded')
        fm.end()
        return 0

    with repo.wlock(), repo.lock():
        cmdutil.bailifchanged(repo)

        # Find the revisions we have in common with the remote. These will
        # be used for finding local-only changes for narrowing. They will
        # also define the set of revisions to update for widening.
        remotepath = ui.expandpath(remotepath or 'default')
        url, branches = hg.parseurl(remotepath)
        ui.status(_('comparing with %s\n') % util.hidepassword(url))
        remote = hg.peer(repo, opts, url)
        commoninc = discovery.findcommonincoming(repo, remote)

        oldincludes, oldexcludes = repo.narrowpats
        if narrowing:
            newincludes = oldincludes - removedincludes
            newexcludes = oldexcludes | addedexcludes
            _narrow(ui, repo, remote, commoninc, oldincludes, oldexcludes,
                    newincludes, newexcludes,
                    opts['force_delete_local_changes'])
            # _narrow() updated the narrowspec and _widen() below needs to
            # use the updated values as its base (otherwise removed includes
            # and addedexcludes will be lost in the resulting narrowspec)
            oldincludes = newincludes
            oldexcludes = newexcludes

        if widening:
            newincludes = oldincludes | addedincludes
            newexcludes = oldexcludes - removedexcludes
            _widen(ui, repo, remote, commoninc, newincludes, newexcludes)

    return 0
