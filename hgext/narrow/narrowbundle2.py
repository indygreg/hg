# narrowbundle2.py - bundle2 extensions for narrow repository support
#
# Copyright 2017 Google, Inc.
#
# This software may be used and distributed according to the terms of the
# GNU General Public License version 2 or any later version.

from __future__ import absolute_import

import collections
import errno
import struct

from mercurial.i18n import _
from mercurial.node import (
    bin,
    nullid,
    nullrev,
)
from mercurial import (
    bundle2,
    changegroup,
    dagutil,
    error,
    exchange,
    extensions,
    narrowspec,
    repair,
    util,
    wireproto,
)
from mercurial.utils import (
    stringutil,
)

NARROWCAP = 'narrow'
_NARROWACL_SECTION = 'narrowhgacl'
_CHANGESPECPART = NARROWCAP + ':changespec'
_SPECPART = NARROWCAP + ':spec'
_SPECPART_INCLUDE = 'include'
_SPECPART_EXCLUDE = 'exclude'
_KILLNODESIGNAL = 'KILL'
_DONESIGNAL = 'DONE'
_ELIDEDCSHEADER = '>20s20s20sl' # cset id, p1, p2, len(text)
_ELIDEDMFHEADER = '>20s20s20s20sl' # manifest id, p1, p2, link id, len(text)
_CSHEADERSIZE = struct.calcsize(_ELIDEDCSHEADER)
_MFHEADERSIZE = struct.calcsize(_ELIDEDMFHEADER)

# When advertising capabilities, always include narrow clone support.
def getrepocaps_narrow(orig, repo, **kwargs):
    caps = orig(repo, **kwargs)
    caps[NARROWCAP] = ['v0']
    return caps

def _computeellipsis(repo, common, heads, known, match, depth=None):
    """Compute the shape of a narrowed DAG.

    Args:
      repo: The repository we're transferring.
      common: The roots of the DAG range we're transferring.
              May be just [nullid], which means all ancestors of heads.
      heads: The heads of the DAG range we're transferring.
      match: The narrowmatcher that allows us to identify relevant changes.
      depth: If not None, only consider nodes to be full nodes if they are at
             most depth changesets away from one of heads.

    Returns:
      A tuple of (visitnodes, relevant_nodes, ellipsisroots) where:

        visitnodes: The list of nodes (either full or ellipsis) which
                    need to be sent to the client.
        relevant_nodes: The set of changelog nodes which change a file inside
                 the narrowspec. The client needs these as non-ellipsis nodes.
        ellipsisroots: A dict of {rev: parents} that is used in
                       narrowchangegroup to produce ellipsis nodes with the
                       correct parents.
    """
    cl = repo.changelog
    mfl = repo.manifestlog

    cldag = dagutil.revlogdag(cl)
    # dagutil does not like nullid/nullrev
    commonrevs = cldag.internalizeall(common - set([nullid])) | set([nullrev])
    headsrevs = cldag.internalizeall(heads)
    if depth:
        revdepth = {h: 0 for h in headsrevs}

    ellipsisheads = collections.defaultdict(set)
    ellipsisroots = collections.defaultdict(set)

    def addroot(head, curchange):
        """Add a root to an ellipsis head, splitting heads with 3 roots."""
        ellipsisroots[head].add(curchange)
        # Recursively split ellipsis heads with 3 roots by finding the
        # roots' youngest common descendant which is an elided merge commit.
        # That descendant takes 2 of the 3 roots as its own, and becomes a
        # root of the head.
        while len(ellipsisroots[head]) > 2:
            child, roots = splithead(head)
            splitroots(head, child, roots)
            head = child  # Recurse in case we just added a 3rd root

    def splitroots(head, child, roots):
        ellipsisroots[head].difference_update(roots)
        ellipsisroots[head].add(child)
        ellipsisroots[child].update(roots)
        ellipsisroots[child].discard(child)

    def splithead(head):
        r1, r2, r3 = sorted(ellipsisroots[head])
        for nr1, nr2 in ((r2, r3), (r1, r3), (r1, r2)):
            mid = repo.revs('sort(merge() & %d::%d & %d::%d, -rev)',
                            nr1, head, nr2, head)
            for j in mid:
                if j == nr2:
                    return nr2, (nr1, nr2)
                if j not in ellipsisroots or len(ellipsisroots[j]) < 2:
                    return j, (nr1, nr2)
        raise error.Abort('Failed to split up ellipsis node! head: %d, '
                          'roots: %d %d %d' % (head, r1, r2, r3))

    missing = list(cl.findmissingrevs(common=commonrevs, heads=headsrevs))
    visit = reversed(missing)
    relevant_nodes = set()
    visitnodes = [cl.node(m) for m in missing]
    required = set(headsrevs) | known
    for rev in visit:
        clrev = cl.changelogrevision(rev)
        ps = cldag.parents(rev)
        if depth is not None:
            curdepth = revdepth[rev]
            for p in ps:
                revdepth[p] = min(curdepth + 1, revdepth.get(p, depth + 1))
        needed = False
        shallow_enough = depth is None or revdepth[rev] <= depth
        if shallow_enough:
            curmf = mfl[clrev.manifest].read()
            if ps:
                # We choose to not trust the changed files list in
                # changesets because it's not always correct. TODO: could
                # we trust it for the non-merge case?
                p1mf = mfl[cl.changelogrevision(ps[0]).manifest].read()
                needed = bool(curmf.diff(p1mf, match))
                if not needed and len(ps) > 1:
                    # For merge changes, the list of changed files is not
                    # helpful, since we need to emit the merge if a file
                    # in the narrow spec has changed on either side of the
                    # merge. As a result, we do a manifest diff to check.
                    p2mf = mfl[cl.changelogrevision(ps[1]).manifest].read()
                    needed = bool(curmf.diff(p2mf, match))
            else:
                # For a root node, we need to include the node if any
                # files in the node match the narrowspec.
                needed = any(curmf.walk(match))

        if needed:
            for head in ellipsisheads[rev]:
                addroot(head, rev)
            for p in ps:
                required.add(p)
            relevant_nodes.add(cl.node(rev))
        else:
            if not ps:
                ps = [nullrev]
            if rev in required:
                for head in ellipsisheads[rev]:
                    addroot(head, rev)
                for p in ps:
                    ellipsisheads[p].add(rev)
            else:
                for p in ps:
                    ellipsisheads[p] |= ellipsisheads[rev]

    # add common changesets as roots of their reachable ellipsis heads
    for c in commonrevs:
        for head in ellipsisheads[c]:
            addroot(head, c)
    return visitnodes, relevant_nodes, ellipsisroots

def _packellipsischangegroup(repo, common, match, relevant_nodes,
                             ellipsisroots, visitnodes, depth, source, version):
    if version in ('01', '02'):
        raise error.Abort(
            'ellipsis nodes require at least cg3 on client and server, '
            'but negotiated version %s' % version)
    # We wrap cg1packer.revchunk, using a side channel to pass
    # relevant_nodes into that area. Then if linknode isn't in the
    # set, we know we have an ellipsis node and we should defer
    # sending that node's data. We override close() to detect
    # pending ellipsis nodes and flush them.
    packer = changegroup.getbundler(version, repo)
    # Let the packer have access to the narrow matcher so it can
    # omit filelogs and dirlogs as needed
    packer._narrow_matcher = lambda : match
    # Give the packer the list of nodes which should not be
    # ellipsis nodes. We store this rather than the set of nodes
    # that should be an ellipsis because for very large histories
    # we expect this to be significantly smaller.
    packer.full_nodes = relevant_nodes
    # Maps ellipsis revs to their roots at the changelog level.
    packer.precomputed_ellipsis = ellipsisroots
    # Maps CL revs to per-revlog revisions. Cleared in close() at
    # the end of each group.
    packer.clrev_to_localrev = {}
    packer.next_clrev_to_localrev = {}
    # Maps changelog nodes to changelog revs. Filled in once
    # during changelog stage and then left unmodified.
    packer.clnode_to_rev = {}
    packer.changelog_done = False
    # If true, informs the packer that it is serving shallow content and might
    # need to pack file contents not introduced by the changes being packed.
    packer.is_shallow = depth is not None

    return packer.generate(common, visitnodes, False, source)

# Serve a changegroup for a client with a narrow clone.
def getbundlechangegrouppart_narrow(bundler, repo, source,
                                    bundlecaps=None, b2caps=None, heads=None,
                                    common=None, **kwargs):
    cgversions = b2caps.get('changegroup')
    if cgversions:  # 3.1 and 3.2 ship with an empty value
        cgversions = [v for v in cgversions
                      if v in changegroup.supportedoutgoingversions(repo)]
        if not cgversions:
            raise ValueError(_('no common changegroup version'))
        version = max(cgversions)
    else:
        raise ValueError(_("server does not advertise changegroup version,"
                           " can't negotiate support for ellipsis nodes"))

    include = sorted(filter(bool, kwargs.get(r'includepats', [])))
    exclude = sorted(filter(bool, kwargs.get(r'excludepats', [])))
    newmatch = narrowspec.match(repo.root, include=include, exclude=exclude)
    if not repo.ui.configbool("experimental", "narrowservebrokenellipses"):
        outgoing = exchange._computeoutgoing(repo, heads, common)
        if not outgoing.missing:
            return
        def wrappedgetbundler(orig, *args, **kwargs):
            bundler = orig(*args, **kwargs)
            bundler._narrow_matcher = lambda : newmatch
            return bundler
        with extensions.wrappedfunction(changegroup, 'getbundler',
                                        wrappedgetbundler):
            cg = changegroup.makestream(repo, outgoing, version, source)
        part = bundler.newpart('changegroup', data=cg)
        part.addparam('version', version)
        if 'treemanifest' in repo.requirements:
            part.addparam('treemanifest', '1')

        if include or exclude:
            narrowspecpart = bundler.newpart(_SPECPART)
            if include:
                narrowspecpart.addparam(
                    _SPECPART_INCLUDE, '\n'.join(include), mandatory=True)
            if exclude:
                narrowspecpart.addparam(
                    _SPECPART_EXCLUDE, '\n'.join(exclude), mandatory=True)

        return

    depth = kwargs.get(r'depth', None)
    if depth is not None:
        depth = int(depth)
        if depth < 1:
            raise error.Abort(_('depth must be positive, got %d') % depth)

    heads = set(heads or repo.heads())
    common = set(common or [nullid])
    oldinclude = sorted(filter(bool, kwargs.get(r'oldincludepats', [])))
    oldexclude = sorted(filter(bool, kwargs.get(r'oldexcludepats', [])))
    known = {bin(n) for n in kwargs.get(r'known', [])}
    if known and (oldinclude != include or oldexclude != exclude):
        # Steps:
        # 1. Send kill for "$known & ::common"
        #
        # 2. Send changegroup for ::common
        #
        # 3. Proceed.
        #
        # In the future, we can send kills for only the specific
        # nodes we know should go away or change shape, and then
        # send a data stream that tells the client something like this:
        #
        # a) apply this changegroup
        # b) apply nodes XXX, YYY, ZZZ that you already have
        # c) goto a
        #
        # until they've built up the full new state.
        # Convert to revnums and intersect with "common". The client should
        # have made it a subset of "common" already, but let's be safe.
        known = set(repo.revs("%ln & ::%ln", known, common))
        # TODO: we could send only roots() of this set, and the
        # list of nodes in common, and the client could work out
        # what to strip, instead of us explicitly sending every
        # single node.
        deadrevs = known
        def genkills():
            for r in deadrevs:
                yield _KILLNODESIGNAL
                yield repo.changelog.node(r)
            yield _DONESIGNAL
        bundler.newpart(_CHANGESPECPART, data=genkills())
        newvisit, newfull, newellipsis = _computeellipsis(
            repo, set(), common, known, newmatch)
        if newvisit:
            cg = _packellipsischangegroup(
                repo, common, newmatch, newfull, newellipsis,
                newvisit, depth, source, version)
            part = bundler.newpart('changegroup', data=cg)
            part.addparam('version', version)
            if 'treemanifest' in repo.requirements:
                part.addparam('treemanifest', '1')

    visitnodes, relevant_nodes, ellipsisroots = _computeellipsis(
        repo, common, heads, set(), newmatch, depth=depth)

    repo.ui.debug('Found %d relevant revs\n' % len(relevant_nodes))
    if visitnodes:
        cg = _packellipsischangegroup(
            repo, common, newmatch, relevant_nodes, ellipsisroots,
            visitnodes, depth, source, version)
        part = bundler.newpart('changegroup', data=cg)
        part.addparam('version', version)
        if 'treemanifest' in repo.requirements:
            part.addparam('treemanifest', '1')

def applyacl_narrow(repo, kwargs):
    ui = repo.ui
    username = ui.shortuser(ui.environ.get('REMOTE_USER') or ui.username())
    user_includes = ui.configlist(
        _NARROWACL_SECTION, username + '.includes',
        ui.configlist(_NARROWACL_SECTION, 'default.includes'))
    user_excludes = ui.configlist(
        _NARROWACL_SECTION, username + '.excludes',
        ui.configlist(_NARROWACL_SECTION, 'default.excludes'))
    if not user_includes:
        raise error.Abort(_("{} configuration for user {} is empty")
                          .format(_NARROWACL_SECTION, username))

    user_includes = [
        'path:.' if p == '*' else 'path:' + p for p in user_includes]
    user_excludes = [
        'path:.' if p == '*' else 'path:' + p for p in user_excludes]

    req_includes = set(kwargs.get(r'includepats', []))
    req_excludes = set(kwargs.get(r'excludepats', []))

    req_includes, req_excludes, invalid_includes = narrowspec.restrictpatterns(
        req_includes, req_excludes, user_includes, user_excludes)

    if invalid_includes:
        raise error.Abort(
            _("The following includes are not accessible for {}: {}")
            .format(username, invalid_includes))

    new_args = {}
    new_args.update(kwargs)
    new_args['includepats'] = req_includes
    if req_excludes:
        new_args['excludepats'] = req_excludes
    return new_args

@bundle2.parthandler(_SPECPART, (_SPECPART_INCLUDE, _SPECPART_EXCLUDE))
def _handlechangespec_2(op, inpart):
    includepats = set(inpart.params.get(_SPECPART_INCLUDE, '').splitlines())
    excludepats = set(inpart.params.get(_SPECPART_EXCLUDE, '').splitlines())
    if not changegroup.NARROW_REQUIREMENT in op.repo.requirements:
        op.repo.requirements.add(changegroup.NARROW_REQUIREMENT)
        op.repo._writerequirements()
    op.repo.setnarrowpats(includepats, excludepats)

@bundle2.parthandler(_CHANGESPECPART)
def _handlechangespec(op, inpart):
    repo = op.repo
    cl = repo.changelog

    # changesets which need to be stripped entirely. either they're no longer
    # needed in the new narrow spec, or the server is sending a replacement
    # in the changegroup part.
    clkills = set()

    # A changespec part contains all the updates to ellipsis nodes
    # that will happen as a result of widening or narrowing a
    # repo. All the changes that this block encounters are ellipsis
    # nodes or flags to kill an existing ellipsis.
    chunksignal = changegroup.readexactly(inpart, 4)
    while chunksignal != _DONESIGNAL:
        if chunksignal == _KILLNODESIGNAL:
            # a node used to be an ellipsis but isn't anymore
            ck = changegroup.readexactly(inpart, 20)
            if cl.hasnode(ck):
                clkills.add(ck)
        else:
            raise error.Abort(
                _('unexpected changespec node chunk type: %s') % chunksignal)
        chunksignal = changegroup.readexactly(inpart, 4)

    if clkills:
        # preserve bookmarks that repair.strip() would otherwise strip
        bmstore = repo._bookmarks
        class dummybmstore(dict):
            def applychanges(self, repo, tr, changes):
                pass
            def recordchange(self, tr): # legacy version
                pass
        repo._bookmarks = dummybmstore()
        chgrpfile = repair.strip(op.ui, repo, list(clkills), backup=True,
                                 topic='widen')
        repo._bookmarks = bmstore
        if chgrpfile:
            # presence of _widen_bundle attribute activates widen handler later
            op._widen_bundle = chgrpfile
    # Set the new narrowspec if we're widening. The setnewnarrowpats() method
    # will currently always be there when using the core+narrowhg server, but
    # other servers may include a changespec part even when not widening (e.g.
    # because we're deepening a shallow repo).
    if util.safehasattr(repo, 'setnewnarrowpats'):
        repo.setnewnarrowpats()

def handlechangegroup_widen(op, inpart):
    """Changegroup exchange handler which restores temporarily-stripped nodes"""
    # We saved a bundle with stripped node data we must now restore.
    # This approach is based on mercurial/repair.py@6ee26a53c111.
    repo = op.repo
    ui = op.ui

    chgrpfile = op._widen_bundle
    del op._widen_bundle
    vfs = repo.vfs

    ui.note(_("adding branch\n"))
    f = vfs.open(chgrpfile, "rb")
    try:
        gen = exchange.readbundle(ui, f, chgrpfile, vfs)
        if not ui.verbose:
            # silence internal shuffling chatter
            ui.pushbuffer()
        if isinstance(gen, bundle2.unbundle20):
            with repo.transaction('strip') as tr:
                bundle2.processbundle(repo, gen, lambda: tr)
        else:
            gen.apply(repo, 'strip', 'bundle:' + vfs.join(chgrpfile), True)
        if not ui.verbose:
            ui.popbuffer()
    finally:
        f.close()

    # remove undo files
    for undovfs, undofile in repo.undofiles():
        try:
            undovfs.unlink(undofile)
        except OSError as e:
            if e.errno != errno.ENOENT:
                ui.warn(_('error removing %s: %s\n') %
                        (undovfs.join(undofile), stringutil.forcebytestr(e)))

    # Remove partial backup only if there were no exceptions
    vfs.unlink(chgrpfile)

def setup():
    """Enable narrow repo support in bundle2-related extension points."""
    extensions.wrapfunction(bundle2, 'getrepocaps', getrepocaps_narrow)

    wireproto.gboptsmap['narrow'] = 'boolean'
    wireproto.gboptsmap['depth'] = 'plain'
    wireproto.gboptsmap['oldincludepats'] = 'csv'
    wireproto.gboptsmap['oldexcludepats'] = 'csv'
    wireproto.gboptsmap['includepats'] = 'csv'
    wireproto.gboptsmap['excludepats'] = 'csv'
    wireproto.gboptsmap['known'] = 'csv'

    # Extend changegroup serving to handle requests from narrow clients.
    origcgfn = exchange.getbundle2partsmapping['changegroup']
    def wrappedcgfn(*args, **kwargs):
        repo = args[1]
        if repo.ui.has_section(_NARROWACL_SECTION):
            getbundlechangegrouppart_narrow(
                *args, **applyacl_narrow(repo, kwargs))
        elif kwargs.get(r'narrow', False):
            getbundlechangegrouppart_narrow(*args, **kwargs)
        else:
            origcgfn(*args, **kwargs)
    exchange.getbundle2partsmapping['changegroup'] = wrappedcgfn

    # disable rev branch cache exchange when serving a narrow bundle
    # (currently incompatible with that part)
    origrbcfn = exchange.getbundle2partsmapping['cache:rev-branch-cache']
    def wrappedcgfn(*args, **kwargs):
        repo = args[1]
        if repo.ui.has_section(_NARROWACL_SECTION):
            return
        elif kwargs.get(r'narrow', False):
            return
        else:
            origrbcfn(*args, **kwargs)
    exchange.getbundle2partsmapping['cache:rev-branch-cache'] = wrappedcgfn

    # Extend changegroup receiver so client can fixup after widen requests.
    origcghandler = bundle2.parthandlermapping['changegroup']
    def wrappedcghandler(op, inpart):
        origcghandler(op, inpart)
        if util.safehasattr(op, '_widen_bundle'):
            handlechangegroup_widen(op, inpart)
    wrappedcghandler.params = origcghandler.params
    bundle2.parthandlermapping['changegroup'] = wrappedcghandler
