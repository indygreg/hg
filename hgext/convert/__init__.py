# convert.py Foreign SCM converter
#
# Copyright 2005-2007 Matt Mackall <mpm@selenic.com>
#
# This software may be used and distributed according to the terms of the
# GNU General Public License version 2 or any later version.

'''import revisions from foreign VCS repositories into Mercurial'''

from __future__ import absolute_import

from mercurial.i18n import _
from mercurial import (
    registrar,
)

from . import (
    convcmd,
    cvsps,
    subversion,
)

cmdtable = {}
command = registrar.command(cmdtable)
# Note for extension authors: ONLY specify testedwith = 'ships-with-hg-core' for
# extensions which SHIP WITH MERCURIAL. Non-mainline extensions should
# be specifying the version(s) of Mercurial they are tested with, or
# leave the attribute unspecified.
testedwith = 'ships-with-hg-core'

configtable = {}
configitem = registrar.configitem(configtable)

configitem('convert', 'cvsps.cache',
    default=True,
)
configitem('convert', 'cvsps.fuzz',
    default=60,
)
configitem('convert', 'cvsps.mergefrom',
    default=None,
)
configitem('convert', 'cvsps.mergeto',
    default=None,
)
configitem('convert', 'git.committeractions',
    default=lambda: ['messagedifferent'],
)
configitem('convert', 'git.extrakeys',
    default=list,
)
configitem('convert', 'git.findcopiesharder',
    default=False,
)
configitem('convert', 'git.remoteprefix',
    default='remote',
)
configitem('convert', 'git.renamelimit',
    default=400,
)
configitem('convert', 'git.saverev',
    default=True,
)
configitem('convert', 'git.similarity',
    default=50,
)
configitem('convert', 'git.skipsubmodules',
    default=False,
)
configitem('convert', 'hg.clonebranches',
    default=False,
)
configitem('convert', 'hg.ignoreerrors',
    default=False,
)
configitem('convert', 'hg.revs',
    default=None,
)
configitem('convert', 'hg.saverev',
    default=False,
)
configitem('convert', 'hg.sourcename',
    default=None,
)
configitem('convert', 'hg.startrev',
    default=None,
)
configitem('convert', 'hg.tagsbranch',
    default='default',
)
configitem('convert', 'hg.usebranchnames',
    default=True,
)
configitem('convert', 'ignoreancestorcheck',
    default=False,
)
configitem('convert', 'localtimezone',
    default=False,
)
configitem('convert', 'p4.startrev',
    default=0,
)
configitem('convert', 'skiptags',
    default=False,
)
configitem('convert', 'svn.debugsvnlog',
    default=True,
)

# Commands definition was moved elsewhere to ease demandload job.

@command('convert',
    [('', 'authors', '',
      _('username mapping filename (DEPRECATED) (use --authormap instead)'),
      _('FILE')),
    ('s', 'source-type', '', _('source repository type'), _('TYPE')),
    ('d', 'dest-type', '', _('destination repository type'), _('TYPE')),
    ('r', 'rev', [], _('import up to source revision REV'), _('REV')),
    ('A', 'authormap', '', _('remap usernames using this file'), _('FILE')),
    ('', 'filemap', '', _('remap file names using contents of file'),
     _('FILE')),
    ('', 'full', None,
     _('apply filemap changes by converting all files again')),
    ('', 'splicemap', '', _('splice synthesized history into place'),
     _('FILE')),
    ('', 'branchmap', '', _('change branch names while converting'),
     _('FILE')),
    ('', 'branchsort', None, _('try to sort changesets by branches')),
    ('', 'datesort', None, _('try to sort changesets by date')),
    ('', 'sourcesort', None, _('preserve source changesets order')),
    ('', 'closesort', None, _('try to reorder closed revisions'))],
   _('hg convert [OPTION]... SOURCE [DEST [REVMAP]]'),
   norepo=True)
def convert(ui, src, dest=None, revmapfile=None, **opts):
    """convert a foreign SCM repository to a Mercurial one.

    Accepted source formats [identifiers]:

    - Mercurial [hg]
    - CVS [cvs]
    - Darcs [darcs]
    - git [git]
    - Subversion [svn]
    - Monotone [mtn]
    - GNU Arch [gnuarch]
    - Bazaar [bzr]
    - Perforce [p4]

    Accepted destination formats [identifiers]:

    - Mercurial [hg]
    - Subversion [svn] (history on branches is not preserved)

    If no revision is given, all revisions will be converted.
    Otherwise, convert will only import up to the named revision
    (given in a format understood by the source).

    If no destination directory name is specified, it defaults to the
    basename of the source with ``-hg`` appended. If the destination
    repository doesn't exist, it will be created.

    By default, all sources except Mercurial will use --branchsort.
    Mercurial uses --sourcesort to preserve original revision numbers
    order. Sort modes have the following effects:

    --branchsort  convert from parent to child revision when possible,
                  which means branches are usually converted one after
                  the other. It generates more compact repositories.

    --datesort    sort revisions by date. Converted repositories have
                  good-looking changelogs but are often an order of
                  magnitude larger than the same ones generated by
                  --branchsort.

    --sourcesort  try to preserve source revisions order, only
                  supported by Mercurial sources.

    --closesort   try to move closed revisions as close as possible
                  to parent branches, only supported by Mercurial
                  sources.

    If ``REVMAP`` isn't given, it will be put in a default location
    (``<dest>/.hg/shamap`` by default). The ``REVMAP`` is a simple
    text file that maps each source commit ID to the destination ID
    for that revision, like so::

      <source ID> <destination ID>

    If the file doesn't exist, it's automatically created. It's
    updated on each commit copied, so :hg:`convert` can be interrupted
    and can be run repeatedly to copy new commits.

    The authormap is a simple text file that maps each source commit
    author to a destination commit author. It is handy for source SCMs
    that use unix logins to identify authors (e.g.: CVS). One line per
    author mapping and the line format is::

      source author = destination author

    Empty lines and lines starting with a ``#`` are ignored.

    The filemap is a file that allows filtering and remapping of files
    and directories. Each line can contain one of the following
    directives::

      include path/to/file-or-dir

      exclude path/to/file-or-dir

      rename path/to/source path/to/destination

    Comment lines start with ``#``. A specified path matches if it
    equals the full relative name of a file or one of its parent
    directories. The ``include`` or ``exclude`` directive with the
    longest matching path applies, so line order does not matter.

    The ``include`` directive causes a file, or all files under a
    directory, to be included in the destination repository. The default
    if there are no ``include`` statements is to include everything.
    If there are any ``include`` statements, nothing else is included.
    The ``exclude`` directive causes files or directories to
    be omitted. The ``rename`` directive renames a file or directory if
    it is converted. To rename from a subdirectory into the root of
    the repository, use ``.`` as the path to rename to.

    ``--full`` will make sure the converted changesets contain exactly
    the right files with the right content. It will make a full
    conversion of all files, not just the ones that have
    changed. Files that already are correct will not be changed. This
    can be used to apply filemap changes when converting
    incrementally. This is currently only supported for Mercurial and
    Subversion.

    The splicemap is a file that allows insertion of synthetic
    history, letting you specify the parents of a revision. This is
    useful if you want to e.g. give a Subversion merge two parents, or
    graft two disconnected series of history together. Each entry
    contains a key, followed by a space, followed by one or two
    comma-separated values::

      key parent1, parent2

    The key is the revision ID in the source
    revision control system whose parents should be modified (same
    format as a key in .hg/shamap). The values are the revision IDs
    (in either the source or destination revision control system) that
    should be used as the new parents for that node. For example, if
    you have merged "release-1.0" into "trunk", then you should
    specify the revision on "trunk" as the first parent and the one on
    the "release-1.0" branch as the second.

    The branchmap is a file that allows you to rename a branch when it is
    being brought in from whatever external repository. When used in
    conjunction with a splicemap, it allows for a powerful combination
    to help fix even the most badly mismanaged repositories and turn them
    into nicely structured Mercurial repositories. The branchmap contains
    lines of the form::

      original_branch_name new_branch_name

    where "original_branch_name" is the name of the branch in the
    source repository, and "new_branch_name" is the name of the branch
    is the destination repository. No whitespace is allowed in the new
    branch name. This can be used to (for instance) move code in one
    repository from "default" to a named branch.

    Mercurial Source
    ################

    The Mercurial source recognizes the following configuration
    options, which you can set on the command line with ``--config``:

    :convert.hg.ignoreerrors: ignore integrity errors when reading.
        Use it to fix Mercurial repositories with missing revlogs, by
        converting from and to Mercurial. Default is False.

    :convert.hg.saverev: store original revision ID in changeset
        (forces target IDs to change). It takes a boolean argument and
        defaults to False.

    :convert.hg.startrev: specify the initial Mercurial revision.
        The default is 0.

    :convert.hg.revs: revset specifying the source revisions to convert.

    CVS Source
    ##########

    CVS source will use a sandbox (i.e. a checked-out copy) from CVS
    to indicate the starting point of what will be converted. Direct
    access to the repository files is not needed, unless of course the
    repository is ``:local:``. The conversion uses the top level
    directory in the sandbox to find the CVS repository, and then uses
    CVS rlog commands to find files to convert. This means that unless
    a filemap is given, all files under the starting directory will be
    converted, and that any directory reorganization in the CVS
    sandbox is ignored.

    The following options can be used with ``--config``:

    :convert.cvsps.cache: Set to False to disable remote log caching,
        for testing and debugging purposes. Default is True.

    :convert.cvsps.fuzz: Specify the maximum time (in seconds) that is
        allowed between commits with identical user and log message in
        a single changeset. When very large files were checked in as
        part of a changeset then the default may not be long enough.
        The default is 60.

    :convert.cvsps.logencoding: Specify encoding name to be used for
        transcoding CVS log messages. Multiple encoding names can be
        specified as a list (see :hg:`help config.Syntax`), but only
        the first acceptable encoding in the list is used per CVS log
        entries. This transcoding is executed before cvslog hook below.

    :convert.cvsps.mergeto: Specify a regular expression to which
        commit log messages are matched. If a match occurs, then the
        conversion process will insert a dummy revision merging the
        branch on which this log message occurs to the branch
        indicated in the regex. Default is ``{{mergetobranch
        ([-\\w]+)}}``

    :convert.cvsps.mergefrom: Specify a regular expression to which
        commit log messages are matched. If a match occurs, then the
        conversion process will add the most recent revision on the
        branch indicated in the regex as the second parent of the
        changeset. Default is ``{{mergefrombranch ([-\\w]+)}}``

    :convert.localtimezone: use local time (as determined by the TZ
        environment variable) for changeset date/times. The default
        is False (use UTC).

    :hooks.cvslog: Specify a Python function to be called at the end of
        gathering the CVS log. The function is passed a list with the
        log entries, and can modify the entries in-place, or add or
        delete them.

    :hooks.cvschangesets: Specify a Python function to be called after
        the changesets are calculated from the CVS log. The
        function is passed a list with the changeset entries, and can
        modify the changesets in-place, or add or delete them.

    An additional "debugcvsps" Mercurial command allows the builtin
    changeset merging code to be run without doing a conversion. Its
    parameters and output are similar to that of cvsps 2.1. Please see
    the command help for more details.

    Subversion Source
    #################

    Subversion source detects classical trunk/branches/tags layouts.
    By default, the supplied ``svn://repo/path/`` source URL is
    converted as a single branch. If ``svn://repo/path/trunk`` exists
    it replaces the default branch. If ``svn://repo/path/branches``
    exists, its subdirectories are listed as possible branches. If
    ``svn://repo/path/tags`` exists, it is looked for tags referencing
    converted branches. Default ``trunk``, ``branches`` and ``tags``
    values can be overridden with following options. Set them to paths
    relative to the source URL, or leave them blank to disable auto
    detection.

    The following options can be set with ``--config``:

    :convert.svn.branches: specify the directory containing branches.
        The default is ``branches``.

    :convert.svn.tags: specify the directory containing tags. The
        default is ``tags``.

    :convert.svn.trunk: specify the name of the trunk branch. The
        default is ``trunk``.

    :convert.localtimezone: use local time (as determined by the TZ
        environment variable) for changeset date/times. The default
        is False (use UTC).

    Source history can be retrieved starting at a specific revision,
    instead of being integrally converted. Only single branch
    conversions are supported.

    :convert.svn.startrev: specify start Subversion revision number.
        The default is 0.

    Git Source
    ##########

    The Git importer converts commits from all reachable branches (refs
    in refs/heads) and remotes (refs in refs/remotes) to Mercurial.
    Branches are converted to bookmarks with the same name, with the
    leading 'refs/heads' stripped. Git submodules are converted to Git
    subrepos in Mercurial.

    The following options can be set with ``--config``:

    :convert.git.similarity: specify how similar files modified in a
        commit must be to be imported as renames or copies, as a
        percentage between ``0`` (disabled) and ``100`` (files must be
        identical). For example, ``90`` means that a delete/add pair will
        be imported as a rename if more than 90% of the file hasn't
        changed. The default is ``50``.

    :convert.git.findcopiesharder: while detecting copies, look at all
        files in the working copy instead of just changed ones. This
        is very expensive for large projects, and is only effective when
        ``convert.git.similarity`` is greater than 0. The default is False.

    :convert.git.renamelimit: perform rename and copy detection up to this
        many changed files in a commit. Increasing this will make rename
        and copy detection more accurate but will significantly slow down
        computation on large projects. The option is only relevant if
        ``convert.git.similarity`` is greater than 0. The default is
        ``400``.

    :convert.git.committeractions: list of actions to take when processing
        author and committer values.

        Git commits have separate author (who wrote the commit) and committer
        (who applied the commit) fields. Not all destinations support separate
        author and committer fields (including Mercurial). This config option
        controls what to do with these author and committer fields during
        conversion.

        A value of ``messagedifferent`` will append a ``committer: ...``
        line to the commit message if the Git committer is different from the
        author. The prefix of that line can be specified using the syntax
        ``messagedifferent=<prefix>``. e.g. ``messagedifferent=git-committer:``.
        When a prefix is specified, a space will always be inserted between the
        prefix and the value.

        ``messagealways`` behaves like ``messagedifferent`` except it will
        always result in a ``committer: ...`` line being appended to the commit
        message. This value is mutually exclusive with ``messagedifferent``.

        ``dropcommitter`` will remove references to the committer. Only
        references to the author will remain. Actions that add references
        to the committer will have no effect when this is set.

        ``replaceauthor`` will replace the value of the author field with
        the committer. Other actions that add references to the committer
        will still take effect when this is set.

        The default is ``messagedifferent``.

    :convert.git.extrakeys: list of extra keys from commit metadata to copy to
        the destination. Some Git repositories store extra metadata in commits.
        By default, this non-default metadata will be lost during conversion.
        Setting this config option can retain that metadata. Some built-in
        keys such as ``parent`` and ``branch`` are not allowed to be copied.

    :convert.git.remoteprefix: remote refs are converted as bookmarks with
        ``convert.git.remoteprefix`` as a prefix followed by a /. The default
        is 'remote'.

    :convert.git.saverev: whether to store the original Git commit ID in the
        metadata of the destination commit. The default is True.

    :convert.git.skipsubmodules: does not convert root level .gitmodules files
        or files with 160000 mode indicating a submodule. Default is False.

    Perforce Source
    ###############

    The Perforce (P4) importer can be given a p4 depot path or a
    client specification as source. It will convert all files in the
    source to a flat Mercurial repository, ignoring labels, branches
    and integrations. Note that when a depot path is given you then
    usually should specify a target directory, because otherwise the
    target may be named ``...-hg``.

    The following options can be set with ``--config``:

    :convert.p4.encoding: specify the encoding to use when decoding standard
        output of the Perforce command line tool. The default is default system
        encoding.

    :convert.p4.startrev: specify initial Perforce revision (a
        Perforce changelist number).

    Mercurial Destination
    #####################

    The Mercurial destination will recognize Mercurial subrepositories in the
    destination directory, and update the .hgsubstate file automatically if the
    destination subrepositories contain the <dest>/<sub>/.hg/shamap file.
    Converting a repository with subrepositories requires converting a single
    repository at a time, from the bottom up.

    .. container:: verbose

       An example showing how to convert a repository with subrepositories::

         # so convert knows the type when it sees a non empty destination
         $ hg init converted

         $ hg convert orig/sub1 converted/sub1
         $ hg convert orig/sub2 converted/sub2
         $ hg convert orig converted

    The following options are supported:

    :convert.hg.clonebranches: dispatch source branches in separate
        clones. The default is False.

    :convert.hg.tagsbranch: branch name for tag revisions, defaults to
        ``default``.

    :convert.hg.usebranchnames: preserve branch names. The default is
        True.

    :convert.hg.sourcename: records the given string as a 'convert_source' extra
        value on each commit made in the target repository. The default is None.

    All Destinations
    ################

    All destination types accept the following options:

    :convert.skiptags: does not convert tags from the source repo to the target
        repo. The default is False.
    """
    return convcmd.convert(ui, src, dest, revmapfile, **opts)

@command('debugsvnlog', [], 'hg debugsvnlog', norepo=True)
def debugsvnlog(ui, **opts):
    return subversion.debugsvnlog(ui, **opts)

@command('debugcvsps',
    [
    # Main options shared with cvsps-2.1
    ('b', 'branches', [], _('only return changes on specified branches')),
    ('p', 'prefix', '', _('prefix to remove from file names')),
    ('r', 'revisions', [],
     _('only return changes after or between specified tags')),
    ('u', 'update-cache', None, _("update cvs log cache")),
    ('x', 'new-cache', None, _("create new cvs log cache")),
    ('z', 'fuzz', 60, _('set commit time fuzz in seconds')),
    ('', 'root', '', _('specify cvsroot')),
    # Options specific to builtin cvsps
    ('', 'parents', '', _('show parent changesets')),
    ('', 'ancestors', '', _('show current changeset in ancestor branches')),
    # Options that are ignored for compatibility with cvsps-2.1
    ('A', 'cvs-direct', None, _('ignored for compatibility')),
    ],
    _('hg debugcvsps [OPTION]... [PATH]...'),
    norepo=True)
def debugcvsps(ui, *args, **opts):
    '''create changeset information from CVS

    This command is intended as a debugging tool for the CVS to
    Mercurial converter, and can be used as a direct replacement for
    cvsps.

    Hg debugcvsps reads the CVS rlog for current directory (or any
    named directory) in the CVS repository, and converts the log to a
    series of changesets based on matching commit log entries and
    dates.'''
    return cvsps.debugcvsps(ui, *args, **opts)

def kwconverted(ctx, name):
    rev = ctx.extra().get('convert_revision', '')
    if rev.startswith('svn:'):
        if name == 'svnrev':
            return str(subversion.revsplit(rev)[2])
        elif name == 'svnpath':
            return subversion.revsplit(rev)[1]
        elif name == 'svnuuid':
            return subversion.revsplit(rev)[0]
    return rev

templatekeyword = registrar.templatekeyword()

@templatekeyword('svnrev')
def kwsvnrev(repo, ctx, **args):
    """String. Converted subversion revision number."""
    return kwconverted(ctx, 'svnrev')

@templatekeyword('svnpath')
def kwsvnpath(repo, ctx, **args):
    """String. Converted subversion revision project path."""
    return kwconverted(ctx, 'svnpath')

@templatekeyword('svnuuid')
def kwsvnuuid(repo, ctx, **args):
    """String. Converted subversion revision repository identifier."""
    return kwconverted(ctx, 'svnuuid')

# tell hggettext to extract docstrings from these functions:
i18nfunctions = [kwsvnrev, kwsvnpath, kwsvnuuid]
