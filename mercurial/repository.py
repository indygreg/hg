# repository.py - Interfaces and base classes for repositories and peers.
#
# Copyright 2017 Gregory Szorc <gregory.szorc@gmail.com>
#
# This software may be used and distributed according to the terms of the
# GNU General Public License version 2 or any later version.

from __future__ import absolute_import

import abc

from .i18n import _
from .thirdparty.zope import (
    interface as zi,
)
from . import (
    error,
)

class _basepeer(object):
    """Represents a "connection" to a repository.

    This is the base interface for representing a connection to a repository.
    It holds basic properties and methods applicable to all peer types.

    This is not a complete interface definition and should not be used
    outside of this module.
    """
    __metaclass__ = abc.ABCMeta

    @abc.abstractproperty
    def ui(self):
        """ui.ui instance."""

    @abc.abstractmethod
    def url(self):
        """Returns a URL string representing this peer.

        Currently, implementations expose the raw URL used to construct the
        instance. It may contain credentials as part of the URL. The
        expectations of the value aren't well-defined and this could lead to
        data leakage.

        TODO audit/clean consumers and more clearly define the contents of this
        value.
        """

    @abc.abstractmethod
    def local(self):
        """Returns a local repository instance.

        If the peer represents a local repository, returns an object that
        can be used to interface with it. Otherwise returns ``None``.
        """

    @abc.abstractmethod
    def peer(self):
        """Returns an object conforming to this interface.

        Most implementations will ``return self``.
        """

    @abc.abstractmethod
    def canpush(self):
        """Returns a boolean indicating if this peer can be pushed to."""

    @abc.abstractmethod
    def close(self):
        """Close the connection to this peer.

        This is called when the peer will no longer be used. Resources
        associated with the peer should be cleaned up.
        """

class _basewirecommands(object):
    """Client-side interface for communicating over the wire protocol.

    This interface is used as a gateway to the Mercurial wire protocol.
    methods commonly call wire protocol commands of the same name.
    """
    __metaclass__ = abc.ABCMeta

    @abc.abstractmethod
    def branchmap(self):
        """Obtain heads in named branches.

        Returns a dict mapping branch name to an iterable of nodes that are
        heads on that branch.
        """

    @abc.abstractmethod
    def capabilities(self):
        """Obtain capabilities of the peer.

        Returns a set of string capabilities.
        """

    @abc.abstractmethod
    def debugwireargs(self, one, two, three=None, four=None, five=None):
        """Used to facilitate debugging of arguments passed over the wire."""

    @abc.abstractmethod
    def getbundle(self, source, **kwargs):
        """Obtain remote repository data as a bundle.

        This command is how the bulk of repository data is transferred from
        the peer to the local repository

        Returns a generator of bundle data.
        """

    @abc.abstractmethod
    def heads(self):
        """Determine all known head revisions in the peer.

        Returns an iterable of binary nodes.
        """

    @abc.abstractmethod
    def known(self, nodes):
        """Determine whether multiple nodes are known.

        Accepts an iterable of nodes whose presence to check for.

        Returns an iterable of booleans indicating of the corresponding node
        at that index is known to the peer.
        """

    @abc.abstractmethod
    def listkeys(self, namespace):
        """Obtain all keys in a pushkey namespace.

        Returns an iterable of key names.
        """

    @abc.abstractmethod
    def lookup(self, key):
        """Resolve a value to a known revision.

        Returns a binary node of the resolved revision on success.
        """

    @abc.abstractmethod
    def pushkey(self, namespace, key, old, new):
        """Set a value using the ``pushkey`` protocol.

        Arguments correspond to the pushkey namespace and key to operate on and
        the old and new values for that key.

        Returns a string with the peer result. The value inside varies by the
        namespace.
        """

    @abc.abstractmethod
    def stream_out(self):
        """Obtain streaming clone data.

        Successful result should be a generator of data chunks.
        """

    @abc.abstractmethod
    def unbundle(self, bundle, heads, url):
        """Transfer repository data to the peer.

        This is how the bulk of data during a push is transferred.

        Returns the integer number of heads added to the peer.
        """

class _baselegacywirecommands(object):
    """Interface for implementing support for legacy wire protocol commands.

    Wire protocol commands transition to legacy status when they are no longer
    used by modern clients. To facilitate identifying which commands are
    legacy, the interfaces are split.
    """
    __metaclass__ = abc.ABCMeta

    @abc.abstractmethod
    def between(self, pairs):
        """Obtain nodes between pairs of nodes.

        ``pairs`` is an iterable of node pairs.

        Returns an iterable of iterables of nodes corresponding to each
        requested pair.
        """

    @abc.abstractmethod
    def branches(self, nodes):
        """Obtain ancestor changesets of specific nodes back to a branch point.

        For each requested node, the peer finds the first ancestor node that is
        a DAG root or is a merge.

        Returns an iterable of iterables with the resolved values for each node.
        """

    @abc.abstractmethod
    def changegroup(self, nodes, kind):
        """Obtain a changegroup with data for descendants of specified nodes."""

    @abc.abstractmethod
    def changegroupsubset(self, bases, heads, kind):
        pass

class peer(_basepeer, _basewirecommands):
    """Unified interface and base class for peer repositories.

    All peer instances must inherit from this class and conform to its
    interface.
    """

    @abc.abstractmethod
    def iterbatch(self):
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

    def capable(self, name):
        """Determine support for a named capability.

        Returns ``False`` if capability not supported.

        Returns ``True`` if boolean capability is supported. Returns a string
        if capability support is non-boolean.
        """
        caps = self.capabilities()
        if name in caps:
            return True

        name = '%s=' % name
        for cap in caps:
            if cap.startswith(name):
                return cap[len(name):]

        return False

    def requirecap(self, name, purpose):
        """Require a capability to be present.

        Raises a ``CapabilityError`` if the capability isn't present.
        """
        if self.capable(name):
            return

        raise error.CapabilityError(
            _('cannot %s; remote repository does not support the %r '
              'capability') % (purpose, name))

class legacypeer(peer, _baselegacywirecommands):
    """peer but with support for legacy wire protocol commands."""

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

    def lookupbranch(key, remote=None):
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

    def changectx(changeid):
        """Obtains a changectx for a revision.

        Identical to __getitem__.
        """

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
