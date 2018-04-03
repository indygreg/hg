# narrowchangegroup.py - narrow clone changegroup creation and consumption
#
# Copyright 2017 Google, Inc.
#
# This software may be used and distributed according to the terms of the
# GNU General Public License version 2 or any later version.

from __future__ import absolute_import

from mercurial.i18n import _
from mercurial import (
    changegroup,
    error,
    extensions,
    manifest,
    match as matchmod,
    mdiff,
    node,
    revlog,
    util,
)

def setup():

    def _cgmatcher(cgpacker):
        localmatcher = cgpacker._repo.narrowmatch()
        remotematcher = getattr(cgpacker, '_narrow_matcher', lambda: None)()
        if remotematcher:
            return matchmod.intersectmatchers(localmatcher, remotematcher)
        else:
            return localmatcher

    def prune(orig, self, revlog, missing, commonrevs):
        if isinstance(revlog, manifest.manifestrevlog):
            matcher = _cgmatcher(self)
            if (matcher and
                not matcher.visitdir(revlog._dir[:-1] or '.')):
                return []
        return orig(self, revlog, missing, commonrevs)

    extensions.wrapfunction(changegroup.cg1packer, 'prune', prune)

    def generatefiles(orig, self, changedfiles, linknodes, commonrevs,
                      source):
        matcher = _cgmatcher(self)
        if matcher:
            changedfiles = list(filter(matcher, changedfiles))
        if getattr(self, 'is_shallow', False):
            # See comment in generate() for why this sadness is a thing.
            mfdicts = self._mfdicts
            del self._mfdicts
            # In a shallow clone, the linknodes callback needs to also include
            # those file nodes that are in the manifests we sent but weren't
            # introduced by those manifests.
            commonctxs = [self._repo[c] for c in commonrevs]
            oldlinknodes = linknodes
            clrev = self._repo.changelog.rev
            def linknodes(flog, fname):
                for c in commonctxs:
                    try:
                        fnode = c.filenode(fname)
                        self.clrev_to_localrev[c.rev()] = flog.rev(fnode)
                    except error.ManifestLookupError:
                        pass
                links = oldlinknodes(flog, fname)
                if len(links) != len(mfdicts):
                    for mf, lr in mfdicts:
                        fnode = mf.get(fname, None)
                        if fnode in links:
                            links[fnode] = min(links[fnode], lr, key=clrev)
                        elif fnode:
                            links[fnode] = lr
                return links
        return orig(self, changedfiles, linknodes, commonrevs, source)
    extensions.wrapfunction(
        changegroup.cg1packer, 'generatefiles', generatefiles)

    def ellipsisdata(packer, rev, revlog_, p1, p2, data, linknode):
        n = revlog_.node(rev)
        p1n, p2n = revlog_.node(p1), revlog_.node(p2)
        flags = revlog_.flags(rev)
        flags |= revlog.REVIDX_ELLIPSIS
        meta = packer.builddeltaheader(
            n, p1n, p2n, node.nullid, linknode, flags)
        # TODO: try and actually send deltas for ellipsis data blocks
        diffheader = mdiff.trivialdiffheader(len(data))
        l = len(meta) + len(diffheader) + len(data)
        return ''.join((changegroup.chunkheader(l),
                        meta,
                        diffheader,
                        data))

    def close(orig, self):
        getattr(self, 'clrev_to_localrev', {}).clear()
        if getattr(self, 'next_clrev_to_localrev', {}):
            self.clrev_to_localrev = self.next_clrev_to_localrev
            del self.next_clrev_to_localrev
        self.changelog_done = True
        return orig(self)
    extensions.wrapfunction(changegroup.cg1packer, 'close', close)

    # In a perfect world, we'd generate better ellipsis-ified graphs
    # for non-changelog revlogs. In practice, we haven't started doing
    # that yet, so the resulting DAGs for the manifestlog and filelogs
    # are actually full of bogus parentage on all the ellipsis
    # nodes. This has the side effect that, while the contents are
    # correct, the individual DAGs might be completely out of whack in
    # a case like 882681bc3166 and its ancestors (back about 10
    # revisions or so) in the main hg repo.
    #
    # The one invariant we *know* holds is that the new (potentially
    # bogus) DAG shape will be valid if we order the nodes in the
    # order that they're introduced in dramatis personae by the
    # changelog, so what we do is we sort the non-changelog histories
    # by the order in which they are used by the changelog.
    def _sortgroup(orig, self, revlog, nodelist, lookup):
        if not util.safehasattr(self, 'full_nodes') or not self.clnode_to_rev:
            return orig(self, revlog, nodelist, lookup)
        key = lambda n: self.clnode_to_rev[lookup(n)]
        return [revlog.rev(n) for n in sorted(nodelist, key=key)]

    extensions.wrapfunction(changegroup.cg1packer, '_sortgroup', _sortgroup)

    def generate(orig, self, commonrevs, clnodes, fastpathlinkrev, source):
        '''yield a sequence of changegroup chunks (strings)'''
        # Note: other than delegating to orig, the only deviation in
        # logic from normal hg's generate is marked with BEGIN/END
        # NARROW HACK.
        if not util.safehasattr(self, 'full_nodes'):
            # not sending a narrow bundle
            for x in orig(self, commonrevs, clnodes, fastpathlinkrev, source):
                yield x
            return

        repo = self._repo
        cl = repo.changelog
        mfl = repo.manifestlog
        mfrevlog = mfl._revlog

        clrevorder = {}
        mfs = {} # needed manifests
        fnodes = {} # needed file nodes
        changedfiles = set()

        # Callback for the changelog, used to collect changed files and manifest
        # nodes.
        # Returns the linkrev node (identity in the changelog case).
        def lookupcl(x):
            c = cl.read(x)
            clrevorder[x] = len(clrevorder)
            # BEGIN NARROW HACK
            #
            # Only update mfs if x is going to be sent. Otherwise we
            # end up with bogus linkrevs specified for manifests and
            # we skip some manifest nodes that we should otherwise
            # have sent.
            if x in self.full_nodes or cl.rev(x) in self.precomputed_ellipsis:
                n = c[0]
                # record the first changeset introducing this manifest version
                mfs.setdefault(n, x)
                # Set this narrow-specific dict so we have the lowest manifest
                # revnum to look up for this cl revnum. (Part of mapping
                # changelog ellipsis parents to manifest ellipsis parents)
                self.next_clrev_to_localrev.setdefault(cl.rev(x),
                                                       mfrevlog.rev(n))
            # We can't trust the changed files list in the changeset if the
            # client requested a shallow clone.
            if self.is_shallow:
                changedfiles.update(mfl[c[0]].read().keys())
            else:
                changedfiles.update(c[3])
            # END NARROW HACK
            # Record a complete list of potentially-changed files in
            # this manifest.
            return x

        self._verbosenote(_('uncompressed size of bundle content:\n'))
        size = 0
        for chunk in self.group(clnodes, cl, lookupcl, units=_('changesets')):
            size += len(chunk)
            yield chunk
        self._verbosenote(_('%8.i (changelog)\n') % size)

        # We need to make sure that the linkrev in the changegroup refers to
        # the first changeset that introduced the manifest or file revision.
        # The fastpath is usually safer than the slowpath, because the filelogs
        # are walked in revlog order.
        #
        # When taking the slowpath with reorder=None and the manifest revlog
        # uses generaldelta, the manifest may be walked in the "wrong" order.
        # Without 'clrevorder', we would get an incorrect linkrev (see fix in
        # cc0ff93d0c0c).
        #
        # When taking the fastpath, we are only vulnerable to reordering
        # of the changelog itself. The changelog never uses generaldelta, so
        # it is only reordered when reorder=True. To handle this case, we
        # simply take the slowpath, which already has the 'clrevorder' logic.
        # This was also fixed in cc0ff93d0c0c.
        fastpathlinkrev = fastpathlinkrev and not self._reorder
        # Treemanifests don't work correctly with fastpathlinkrev
        # either, because we don't discover which directory nodes to
        # send along with files. This could probably be fixed.
        fastpathlinkrev = fastpathlinkrev and (
            'treemanifest' not in repo.requirements)
        # Shallow clones also don't work correctly with fastpathlinkrev
        # because file nodes may need to be sent for a manifest even if they
        # weren't introduced by that manifest.
        fastpathlinkrev = fastpathlinkrev and not self.is_shallow

        for chunk in self.generatemanifests(commonrevs, clrevorder,
                fastpathlinkrev, mfs, fnodes, source):
            yield chunk
        # BEGIN NARROW HACK
        mfdicts = None
        if self.is_shallow:
            mfdicts = [(self._repo.manifestlog[n].read(), lr)
                       for (n, lr) in mfs.iteritems()]
        # END NARROW HACK
        mfs.clear()
        clrevs = set(cl.rev(x) for x in clnodes)

        if not fastpathlinkrev:
            def linknodes(unused, fname):
                return fnodes.get(fname, {})
        else:
            cln = cl.node
            def linknodes(filerevlog, fname):
                llr = filerevlog.linkrev
                fln = filerevlog.node
                revs = ((r, llr(r)) for r in filerevlog)
                return dict((fln(r), cln(lr)) for r, lr in revs if lr in clrevs)

        # BEGIN NARROW HACK
        #
        # We need to pass the mfdicts variable down into
        # generatefiles(), but more than one command might have
        # wrapped generatefiles so we can't modify the function
        # signature. Instead, we pass the data to ourselves using an
        # instance attribute. I'm sorry.
        self._mfdicts = mfdicts
        # END NARROW HACK
        for chunk in self.generatefiles(changedfiles, linknodes, commonrevs,
                                        source):
            yield chunk

        yield self.close()

        if clnodes:
            repo.hook('outgoing', node=node.hex(clnodes[0]), source=source)
    extensions.wrapfunction(changegroup.cg1packer, 'generate', generate)

    def revchunk(orig, self, revlog, rev, prev, linknode):
        if not util.safehasattr(self, 'full_nodes'):
            # not sending a narrow changegroup
            for x in orig(self, revlog, rev, prev, linknode):
                yield x
            return
        # build up some mapping information that's useful later. See
        # the local() nested function below.
        if not self.changelog_done:
            self.clnode_to_rev[linknode] = rev
            linkrev = rev
            self.clrev_to_localrev[linkrev] = rev
        else:
            linkrev = self.clnode_to_rev[linknode]
            self.clrev_to_localrev[linkrev] = rev
        # This is a node to send in full, because the changeset it
        # corresponds to was a full changeset.
        if linknode in self.full_nodes:
            for x in orig(self, revlog, rev, prev, linknode):
                yield x
            return
        # At this point, a node can either be one we should skip or an
        # ellipsis. If it's not an ellipsis, bail immediately.
        if linkrev not in self.precomputed_ellipsis:
            return
        linkparents = self.precomputed_ellipsis[linkrev]
        def local(clrev):
            """Turn a changelog revnum into a local revnum.

            The ellipsis dag is stored as revnums on the changelog,
            but when we're producing ellipsis entries for
            non-changelog revlogs, we need to turn those numbers into
            something local. This does that for us, and during the
            changelog sending phase will also expand the stored
            mappings as needed.
            """
            if clrev == node.nullrev:
                return node.nullrev
            if not self.changelog_done:
                # If we're doing the changelog, it's possible that we
                # have a parent that is already on the client, and we
                # need to store some extra mapping information so that
                # our contained ellipsis nodes will be able to resolve
                # their parents.
                if clrev not in self.clrev_to_localrev:
                    clnode = revlog.node(clrev)
                    self.clnode_to_rev[clnode] = clrev
                return clrev
            # Walk the ellipsis-ized changelog breadth-first looking for a
            # change that has been linked from the current revlog.
            #
            # For a flat manifest revlog only a single step should be necessary
            # as all relevant changelog entries are relevant to the flat
            # manifest.
            #
            # For a filelog or tree manifest dirlog however not every changelog
            # entry will have been relevant, so we need to skip some changelog
            # nodes even after ellipsis-izing.
            walk = [clrev]
            while walk:
                p = walk[0]
                walk = walk[1:]
                if p in self.clrev_to_localrev:
                    return self.clrev_to_localrev[p]
                elif p in self.full_nodes:
                    walk.extend([pp for pp in self._repo.changelog.parentrevs(p)
                                    if pp != node.nullrev])
                elif p in self.precomputed_ellipsis:
                    walk.extend([pp for pp in self.precomputed_ellipsis[p]
                                    if pp != node.nullrev])
                else:
                    # In this case, we've got an ellipsis with parents
                    # outside the current bundle (likely an
                    # incremental pull). We "know" that we can use the
                    # value of this same revlog at whatever revision
                    # is pointed to by linknode. "Know" is in scare
                    # quotes because I haven't done enough examination
                    # of edge cases to convince myself this is really
                    # a fact - it works for all the (admittedly
                    # thorough) cases in our testsuite, but I would be
                    # somewhat unsurprised to find a case in the wild
                    # where this breaks down a bit. That said, I don't
                    # know if it would hurt anything.
                    for i in xrange(rev, 0, -1):
                        if revlog.linkrev(i) == clrev:
                            return i
                    # We failed to resolve a parent for this node, so
                    # we crash the changegroup construction.
                    raise error.Abort(
                        'unable to resolve parent while packing %r %r'
                        ' for changeset %r' % (revlog.indexfile, rev, clrev))
            return node.nullrev

        if not linkparents or (
            revlog.parentrevs(rev) == (node.nullrev, node.nullrev)):
            p1, p2 = node.nullrev, node.nullrev
        elif len(linkparents) == 1:
            p1, = sorted(local(p) for p in linkparents)
            p2 = node.nullrev
        else:
            p1, p2 = sorted(local(p) for p in linkparents)
        n = revlog.node(rev)
        yield ellipsisdata(
            self, rev, revlog, p1, p2, revlog.revision(n), linknode)
    extensions.wrapfunction(changegroup.cg1packer, 'revchunk', revchunk)

    def deltaparent(orig, self, revlog, rev, p1, p2, prev):
        if util.safehasattr(self, 'full_nodes'):
            # TODO: send better deltas when in narrow mode.
            #
            # changegroup.group() loops over revisions to send,
            # including revisions we'll skip. What this means is that
            # `prev` will be a potentially useless delta base for all
            # ellipsis nodes, as the client likely won't have it. In
            # the future we should do bookkeeping about which nodes
            # have been sent to the client, and try to be
            # significantly smarter about delta bases. This is
            # slightly tricky because this same code has to work for
            # all revlogs, and we don't have the linkrev/linknode here.
            return p1
        return orig(self, revlog, rev, p1, p2, prev)
    extensions.wrapfunction(changegroup.cg2packer, 'deltaparent', deltaparent)
