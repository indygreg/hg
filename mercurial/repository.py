# repository.py - Interfaces and base classes for repositories and peers.
#
# Copyright 2017 Gregory Szorc <gregory.szorc@gmail.com>
#
# This software may be used and distributed according to the terms of the
# GNU General Public License version 2 or any later version.

from __future__ import absolute_import

from .i18n import _
from .thirdparty.zope import (
    interface as zi,
)
from . import (
    error,
)

class ipeerconnection(zi.Interface):
    """Represents a "connection" to a repository.

    This is the base interface for representing a connection to a repository.
    It holds basic properties and methods applicable to all peer types.

    This is not a complete interface definition and should not be used
    outside of this module.
    """
    ui = zi.Attribute("""ui.ui instance""")

    def url():
        """Returns a URL string representing this peer.

        Currently, implementations expose the raw URL used to construct the
        instance. It may contain credentials as part of the URL. The
        expectations of the value aren't well-defined and this could lead to
        data leakage.

        TODO audit/clean consumers and more clearly define the contents of this
        value.
        """

    def local():
        """Returns a local repository instance.

        If the peer represents a local repository, returns an object that
        can be used to interface with it. Otherwise returns ``None``.
        """

    def peer():
        """Returns an object conforming to this interface.

        Most implementations will ``return self``.
        """

    def canpush():
        """Returns a boolean indicating if this peer can be pushed to."""

    def close():
        """Close the connection to this peer.

        This is called when the peer will no longer be used. Resources
        associated with the peer should be cleaned up.
        """

class ipeercommands(zi.Interface):
    """Client-side interface for communicating over the wire protocol.

    This interface is used as a gateway to the Mercurial wire protocol.
    methods commonly call wire protocol commands of the same name.
    """

    def branchmap():
        """Obtain heads in named branches.

        Returns a dict mapping branch name to an iterable of nodes that are
        heads on that branch.
        """

    def capabilities():
        """Obtain capabilities of the peer.

        Returns a set of string capabilities.
        """

    def debugwireargs(one, two, three=None, four=None, five=None):
        """Used to facilitate debugging of arguments passed over the wire."""

    def getbundle(source, **kwargs):
        """Obtain remote repository data as a bundle.

        This command is how the bulk of repository data is transferred from
        the peer to the local repository

        Returns a generator of bundle data.
        """

    def heads():
        """Determine all known head revisions in the peer.

        Returns an iterable of binary nodes.
        """

    def known(nodes):
        """Determine whether multiple nodes are known.

        Accepts an iterable of nodes whose presence to check for.

        Returns an iterable of booleans indicating of the corresponding node
        at that index is known to the peer.
        """

    def listkeys(namespace):
        """Obtain all keys in a pushkey namespace.

        Returns an iterable of key names.
        """

    def lookup(key):
        """Resolve a value to a known revision.

        Returns a binary node of the resolved revision on success.
        """

    def pushkey(namespace, key, old, new):
        """Set a value using the ``pushkey`` protocol.

        Arguments correspond to the pushkey namespace and key to operate on and
        the old and new values for that key.

        Returns a string with the peer result. The value inside varies by the
        namespace.
        """

    def stream_out():
        """Obtain streaming clone data.

        Successful result should be a generator of data chunks.
        """

    def unbundle(bundle, heads, url):
        """Transfer repository data to the peer.

        This is how the bulk of data during a push is transferred.

        Returns the integer number of heads added to the peer.
        """

class ipeerlegacycommands(zi.Interface):
    """Interface for implementing support for legacy wire protocol commands.

    Wire protocol commands transition to legacy status when they are no longer
    used by modern clients. To facilitate identifying which commands are
    legacy, the interfaces are split.
    """

    def between(pairs):
        """Obtain nodes between pairs of nodes.

        ``pairs`` is an iterable of node pairs.

        Returns an iterable of iterables of nodes corresponding to each
        requested pair.
        """

    def branches(nodes):
        """Obtain ancestor changesets of specific nodes back to a branch point.

        For each requested node, the peer finds the first ancestor node that is
        a DAG root or is a merge.

        Returns an iterable of iterables with the resolved values for each node.
        """

    def changegroup(nodes, kind):
        """Obtain a changegroup with data for descendants of specified nodes."""

    def changegroupsubset(bases, heads, kind):
        pass

class ipeerbase(ipeerconnection, ipeercommands):
    """Unified interface for peer repositories.

    All peer instances must conform to this interface.
    """
    def iterbatch():
        """Obtain an object to be used for multiple method calls.

        Various operations call several methods on peer instances. If each
        method call were performed immediately and serially, this would
        require round trips to remote peers and/or would slow down execution.

        Some peers have the ability to "batch" method calls to avoid costly
        round trips or to facilitate concurrent execution.

        This method returns an object that can be used to indicate intent to
        perform batched method calls.

        The returned object is a proxy of this peer. It intercepts calls to
        batchable methods and queues them instead of performing them
        immediately. This proxy object has a ``submit`` method that will
        perform all queued batchable method calls. A ``results()`` method
        exposes the results of queued/batched method calls. It is a generator
        of results in the order they were called.

        Not all peers or wire protocol implementations may actually batch method
        calls. However, they must all support this API.
        """

    def capable(name):
        """Determine support for a named capability.

        Returns ``False`` if capability not supported.

        Returns ``True`` if boolean capability is supported. Returns a string
        if capability support is non-boolean.
        """

    def requirecap(name, purpose):
        """Require a capability to be present.

        Raises a ``CapabilityError`` if the capability isn't present.
        """

class ipeerbaselegacycommands(ipeerbase, ipeerlegacycommands):
    """Unified peer interface that supports legacy commands."""

@zi.implementer(ipeerbase)
class peer(object):
    """Base class for peer repositories."""

    def capable(self, name):
        caps = self.capabilities()
        if name in caps:
            return True

        name = '%s=' % name
        for cap in caps:
            if cap.startswith(name):
                return cap[len(name):]

        return False

    def requirecap(self, name, purpose):
        if self.capable(name):
            return

        raise error.CapabilityError(
            _('cannot %s; remote repository does not support the %r '
              'capability') % (purpose, name))

@zi.implementer(ipeerbaselegacycommands)
class legacypeer(peer):
    """peer but with support for legacy wire protocol commands."""

class ifilerevisionssequence(zi.Interface):
    """Contains index data for all revisions of a file.

    Types implementing this behave like lists of tuples. The index
    in the list corresponds to the revision number. The values contain
    index metadata.

    The *null* revision (revision number -1) is always the last item
    in the index.
    """

    def __len__():
        """The total number of revisions."""

    def __getitem__(rev):
        """Returns the object having a specific revision number.

        Returns an 8-tuple with the following fields:

        offset+flags
           Contains the offset and flags for the revision. 64-bit unsigned
           integer where first 6 bytes are the offset and the next 2 bytes
           are flags. The offset can be 0 if it is not used by the store.
        compressed size
            Size of the revision data in the store. It can be 0 if it isn't
            needed by the store.
        uncompressed size
            Fulltext size. It can be 0 if it isn't needed by the store.
        base revision
            Revision number of revision the delta for storage is encoded
            against. -1 indicates not encoded against a base revision.
        link revision
            Revision number of changelog revision this entry is related to.
        p1 revision
            Revision number of 1st parent. -1 if no 1st parent.
        p2 revision
            Revision number of 2nd parent. -1 if no 1st parent.
        node
            Binary node value for this revision number.

        Negative values should index off the end of the sequence. ``-1``
        should return the null revision. ``-2`` should return the most
        recent revision.
        """

    def __contains__(rev):
        """Whether a revision number exists."""

    def insert(self, i, entry):
        """Add an item to the index at specific revision."""

class ifileindex(zi.Interface):
    """Storage interface for index data of a single file.

    File storage data is divided into index metadata and data storage.
    This interface defines the index portion of the interface.

    The index logically consists of:

    * A mapping between revision numbers and nodes.
    * DAG data (storing and querying the relationship between nodes).
    * Metadata to facilitate storage.
    """
    index = zi.Attribute(
        """An ``ifilerevisionssequence`` instance.""")

    def __len__():
        """Obtain the number of revisions stored for this file."""

    def __iter__():
        """Iterate over revision numbers for this file."""

    def revs(start=0, stop=None):
        """Iterate over revision numbers for this file, with control."""

    def parents(node):
        """Returns a 2-tuple of parent nodes for a revision.

        Values will be ``nullid`` if the parent is empty.
        """

    def parentrevs(rev):
        """Like parents() but operates on revision numbers."""

    def rev(node):
        """Obtain the revision number given a node.

        Raises ``error.LookupError`` if the node is not known.
        """

    def node(rev):
        """Obtain the node value given a revision number.

        Raises ``IndexError`` if the node is not known.
        """

    def lookup(node):
        """Attempt to resolve a value to a node.

        Value can be a binary node, hex node, revision number, or a string
        that can be converted to an integer.

        Raises ``error.LookupError`` if a node could not be resolved.
        """

    def linkrev(rev):
        """Obtain the changeset revision number a revision is linked to."""

    def flags(rev):
        """Obtain flags used to affect storage of a revision."""

    def iscensored(rev):
        """Return whether a revision's content has been censored."""

    def commonancestorsheads(node1, node2):
        """Obtain an iterable of nodes containing heads of common ancestors.

        See ``ancestor.commonancestorsheads()``.
        """

    def descendants(revs):
        """Obtain descendant revision numbers for a set of revision numbers.

        If ``nullrev`` is in the set, this is equivalent to ``revs()``.
        """

    def headrevs():
        """Obtain a list of revision numbers that are DAG heads.

        The list is sorted oldest to newest.

        TODO determine if sorting is required.
        """

    def heads(start=None, stop=None):
        """Obtain a list of nodes that are DAG heads, with control.

        The set of revisions examined can be limited by specifying
        ``start`` and ``stop``. ``start`` is a node. ``stop`` is an
        iterable of nodes. DAG traversal starts at earlier revision
        ``start`` and iterates forward until any node in ``stop`` is
        encountered.
        """

    def children(node):
        """Obtain nodes that are children of a node.

        Returns a list of nodes.
        """

    def deltaparent(rev):
        """"Return the revision that is a suitable parent to delta against."""

    def candelta(baserev, rev):
        """"Whether a delta can be generated between two revisions."""

class ifiledata(zi.Interface):
    """Storage interface for data storage of a specific file.

    This complements ``ifileindex`` and provides an interface for accessing
    data for a tracked file.
    """
    def rawsize(rev):
        """The size of the fulltext data for a revision as stored."""

    def size(rev):
        """Obtain the fulltext size of file data.

        Any metadata is excluded from size measurements. Use ``rawsize()`` if
        metadata size is important.
        """

    def checkhash(fulltext, node, p1=None, p2=None, rev=None):
        """Validate the stored hash of a given fulltext and node.

        Raises ``error.RevlogError`` is hash validation fails.
        """

    def revision(node, raw=False):
        """"Obtain fulltext data for a node.

        By default, any storage transformations are applied before the data
        is returned. If ``raw`` is True, non-raw storage transformations
        are not applied.

        The fulltext data may contain a header containing metadata. Most
        consumers should use ``read()`` to obtain the actual file data.
        """

    def read(node):
        """Resolve file fulltext data.

        This is similar to ``revision()`` except any metadata in the data
        headers is stripped.
        """

    def renamed(node):
        """Obtain copy metadata for a node.

        Returns ``False`` if no copy metadata is stored or a 2-tuple of
        (path, node) from which this revision was copied.
        """

    def cmp(node, fulltext):
        """Compare fulltext to another revision.

        Returns True if the fulltext is different from what is stored.

        This takes copy metadata into account.

        TODO better document the copy metadata and censoring logic.
        """

    def revdiff(rev1, rev2):
        """Obtain a delta between two revision numbers.

        Operates on raw data in the store (``revision(node, raw=True)``).

        The returned data is the result of ``bdiff.bdiff`` on the raw
        revision data.
        """

class ifilemutation(zi.Interface):
    """Storage interface for mutation events of a tracked file."""

    def add(filedata, meta, transaction, linkrev, p1, p2):
        """Add a new revision to the store.

        Takes file data, dictionary of metadata, a transaction, linkrev,
        and parent nodes.

        Returns the node that was added.

        May no-op if a revision matching the supplied data is already stored.
        """

    def addrevision(revisiondata, transaction, linkrev, p1, p2, node=None,
                    flags=0, cachedelta=None):
        """Add a new revision to the store.

        This is similar to ``add()`` except it operates at a lower level.

        The data passed in already contains a metadata header, if any.

        ``node`` and ``flags`` can be used to define the expected node and
        the flags to use with storage.

        ``add()`` is usually called when adding files from e.g. the working
        directory. ``addrevision()`` is often called by ``add()`` and for
        scenarios where revision data has already been computed, such as when
        applying raw data from a peer repo.
        """

    def addgroup(deltas, linkmapper, transaction, addrevisioncb=None):
        """Process a series of deltas for storage.

        ``deltas`` is an iterable of 7-tuples of
        (node, p1, p2, linknode, deltabase, delta, flags) defining revisions
        to add.

        The ``delta`` field contains ``mpatch`` data to apply to a base
        revision, identified by ``deltabase``. The base node can be
        ``nullid``, in which case the header from the delta can be ignored
        and the delta used as the fulltext.

        ``addrevisioncb`` should be called for each node as it is committed.

        Returns a list of nodes that were processed. A node will be in the list
        even if it existed in the store previously.
        """

    def getstrippoint(minlink):
        """Find the minimum revision that must be stripped to strip a linkrev.

        Returns a 2-tuple containing the minimum revision number and a set
        of all revisions numbers that would be broken by this strip.

        TODO this is highly revlog centric and should be abstracted into
        a higher-level deletion API. ``repair.strip()`` relies on this.
        """

    def strip(minlink, transaction):
        """Remove storage of items starting at a linkrev.

        This uses ``getstrippoint()`` to determine the first node to remove.
        Then it effectively truncates storage for all revisions after that.

        TODO this is highly revlog centric and should be abstracted into a
        higher-level deletion API.
        """

class ifilestorage(ifileindex, ifiledata, ifilemutation):
    """Complete storage interface for a single tracked file."""

    version = zi.Attribute(
        """Version number of storage.

        TODO this feels revlog centric and could likely be removed.
        """)

    storedeltachains = zi.Attribute(
        """Whether the store stores deltas.

        TODO deltachains are revlog centric. This can probably removed
        once there are better abstractions for obtaining/writing
        data.
        """)

    _generaldelta = zi.Attribute(
        """Whether deltas can be against any parent revision.

        TODO this is used by changegroup code and it could probably be
        folded into another API.
        """)

    def files():
        """Obtain paths that are backing storage for this file.

        TODO this is used heavily by verify code and there should probably
        be a better API for that.
        """

    def checksize():
        """Obtain the expected sizes of backing files.

        TODO this is used by verify and it should not be part of the interface.
        """

class completelocalrepository(zi.Interface):
    """Monolithic interface for local repositories.

    This currently captures the reality of things - not how things should be.
    """

    supportedformats = zi.Attribute(
        """Set of requirements that apply to stream clone.

        This is actually a class attribute and is shared among all instances.
        """)

    openerreqs = zi.Attribute(
        """Set of requirements that are passed to the opener.

        This is actually a class attribute and is shared among all instances.
        """)

    supported = zi.Attribute(
        """Set of requirements that this repo is capable of opening.""")

    requirements = zi.Attribute(
        """Set of requirements this repo uses.""")

    filtername = zi.Attribute(
        """Name of the repoview that is active on this repo.""")

    wvfs = zi.Attribute(
        """VFS used to access the working directory.""")

    vfs = zi.Attribute(
        """VFS rooted at the .hg directory.

        Used to access repository data not in the store.
        """)

    svfs = zi.Attribute(
        """VFS rooted at the store.

        Used to access repository data in the store. Typically .hg/store.
        But can point elsewhere if the store is shared.
        """)

    root = zi.Attribute(
        """Path to the root of the working directory.""")

    path = zi.Attribute(
        """Path to the .hg directory.""")

    origroot = zi.Attribute(
        """The filesystem path that was used to construct the repo.""")

    auditor = zi.Attribute(
        """A pathauditor for the working directory.

        This checks if a path refers to a nested repository.

        Operates on the filesystem.
        """)

    nofsauditor = zi.Attribute(
        """A pathauditor for the working directory.

        This is like ``auditor`` except it doesn't do filesystem checks.
        """)

    baseui = zi.Attribute(
        """Original ui instance passed into constructor.""")

    ui = zi.Attribute(
        """Main ui instance for this instance.""")

    sharedpath = zi.Attribute(
        """Path to the .hg directory of the repo this repo was shared from.""")

    store = zi.Attribute(
        """A store instance.""")

    spath = zi.Attribute(
        """Path to the store.""")

    sjoin = zi.Attribute(
        """Alias to self.store.join.""")

    cachevfs = zi.Attribute(
        """A VFS used to access the cache directory.

        Typically .hg/cache.
        """)

    filteredrevcache = zi.Attribute(
        """Holds sets of revisions to be filtered.""")

    names = zi.Attribute(
        """A ``namespaces`` instance.""")

    def close():
        """Close the handle on this repository."""

    def peer():
        """Obtain an object conforming to the ``peer`` interface."""

    def unfiltered():
        """Obtain an unfiltered/raw view of this repo."""

    def filtered(name, visibilityexceptions=None):
        """Obtain a named view of this repository."""

    obsstore = zi.Attribute(
        """A store of obsolescence data.""")

    changelog = zi.Attribute(
        """A handle on the changelog revlog.""")

    manifestlog = zi.Attribute(
        """A handle on the root manifest revlog.""")

    dirstate = zi.Attribute(
        """Working directory state.""")

    narrowpats = zi.Attribute(
        """Matcher patterns for this repository's narrowspec.""")

    def narrowmatch():
        """Obtain a matcher for the narrowspec."""

    def setnarrowpats(newincludes, newexcludes):
        """Define the narrowspec for this repository."""

    def __getitem__(changeid):
        """Try to resolve a changectx."""

    def __contains__(changeid):
        """Whether a changeset exists."""

    def __nonzero__():
        """Always returns True."""
        return True

    __bool__ = __nonzero__

    def __len__():
        """Returns the number of changesets in the repo."""

    def __iter__():
        """Iterate over revisions in the changelog."""

    def revs(expr, *args):
        """Evaluate a revset.

        Emits revisions.
        """

    def set(expr, *args):
        """Evaluate a revset.

        Emits changectx instances.
        """

    def anyrevs(specs, user=False, localalias=None):
        """Find revisions matching one of the given revsets."""

    def url():
        """Returns a string representing the location of this repo."""

    def hook(name, throw=False, **args):
        """Call a hook."""

    def tags():
        """Return a mapping of tag to node."""

    def tagtype(tagname):
        """Return the type of a given tag."""

    def tagslist():
        """Return a list of tags ordered by revision."""

    def nodetags(node):
        """Return the tags associated with a node."""

    def nodebookmarks(node):
        """Return the list of bookmarks pointing to the specified node."""

    def branchmap():
        """Return a mapping of branch to heads in that branch."""

    def revbranchcache():
        pass

    def branchtip(branchtip, ignoremissing=False):
        """Return the tip node for a given branch."""

    def lookup(key):
        """Resolve the node for a revision."""

    def lookupbranch(key):
        """Look up the branch name of the given revision or branch name."""

    def known(nodes):
        """Determine whether a series of nodes is known.

        Returns a list of bools.
        """

    def local():
        """Whether the repository is local."""
        return True

    def publishing():
        """Whether the repository is a publishing repository."""

    def cancopy():
        pass

    def shared():
        """The type of shared repository or None."""

    def wjoin(f, *insidef):
        """Calls self.vfs.reljoin(self.root, f, *insidef)"""

    def file(f):
        """Obtain a filelog for a tracked path."""

    def setparents(p1, p2):
        """Set the parent nodes of the working directory."""

    def filectx(path, changeid=None, fileid=None):
        """Obtain a filectx for the given file revision."""

    def getcwd():
        """Obtain the current working directory from the dirstate."""

    def pathto(f, cwd=None):
        """Obtain the relative path to a file."""

    def adddatafilter(name, fltr):
        pass

    def wread(filename):
        """Read a file from wvfs, using data filters."""

    def wwrite(filename, data, flags, backgroundclose=False, **kwargs):
        """Write data to a file in the wvfs, using data filters."""

    def wwritedata(filename, data):
        """Resolve data for writing to the wvfs, using data filters."""

    def currenttransaction():
        """Obtain the current transaction instance or None."""

    def transaction(desc, report=None):
        """Open a new transaction to write to the repository."""

    def undofiles():
        """Returns a list of (vfs, path) for files to undo transactions."""

    def recover():
        """Roll back an interrupted transaction."""

    def rollback(dryrun=False, force=False):
        """Undo the last transaction.

        DANGEROUS.
        """

    def updatecaches(tr=None, full=False):
        """Warm repo caches."""

    def invalidatecaches():
        """Invalidate cached data due to the repository mutating."""

    def invalidatevolatilesets():
        pass

    def invalidatedirstate():
        """Invalidate the dirstate."""

    def invalidate(clearfilecache=False):
        pass

    def invalidateall():
        pass

    def lock(wait=True):
        """Lock the repository store and return a lock instance."""

    def wlock(wait=True):
        """Lock the non-store parts of the repository."""

    def currentwlock():
        """Return the wlock if it's held or None."""

    def checkcommitpatterns(wctx, vdirs, match, status, fail):
        pass

    def commit(text='', user=None, date=None, match=None, force=False,
               editor=False, extra=None):
        """Add a new revision to the repository."""

    def commitctx(ctx, error=False):
        """Commit a commitctx instance to the repository."""

    def destroying():
        """Inform the repository that nodes are about to be destroyed."""

    def destroyed():
        """Inform the repository that nodes have been destroyed."""

    def status(node1='.', node2=None, match=None, ignored=False,
               clean=False, unknown=False, listsubrepos=False):
        """Convenience method to call repo[x].status()."""

    def addpostdsstatus(ps):
        pass

    def postdsstatus():
        pass

    def clearpostdsstatus():
        pass

    def heads(start=None):
        """Obtain list of nodes that are DAG heads."""

    def branchheads(branch=None, start=None, closed=False):
        pass

    def branches(nodes):
        pass

    def between(pairs):
        pass

    def checkpush(pushop):
        pass

    prepushoutgoinghooks = zi.Attribute(
        """util.hooks instance.""")

    def pushkey(namespace, key, old, new):
        pass

    def listkeys(namespace):
        pass

    def debugwireargs(one, two, three=None, four=None, five=None):
        pass

    def savecommitmessage(text):
        pass
