# fix - rewrite file content in changesets and working copy
#
# Copyright 2018 Google LLC.
#
# This software may be used and distributed according to the terms of the
# GNU General Public License version 2 or any later version.
"""rewrite file content in changesets or working copy (EXPERIMENTAL)

Provides a command that runs configured tools on the contents of modified files,
writing back any fixes to the working copy or replacing changesets.

Here is an example configuration that causes :hg:`fix` to apply automatic
formatting fixes to modified lines in C++ code::

  [fix]
  clang-format:command=clang-format --assume-filename={rootpath}
  clang-format:linerange=--lines={first}:{last}
  clang-format:fileset=set:**.cpp or **.hpp

The :command suboption forms the first part of the shell command that will be
used to fix a file. The content of the file is passed on standard input, and the
fixed file content is expected on standard output. If there is any output on
standard error, the file will not be affected. Some values may be substituted
into the command::

  {rootpath}  The path of the file being fixed, relative to the repo root
  {basename}  The name of the file being fixed, without the directory path

If the :linerange suboption is set, the tool will only be run if there are
changed lines in a file. The value of this suboption is appended to the shell
command once for every range of changed lines in the file. Some values may be
substituted into the command::

  {first}   The 1-based line number of the first line in the modified range
  {last}    The 1-based line number of the last line in the modified range

The :fileset suboption determines which files will be passed through each
configured tool. See :hg:`help fileset` for possible values. If there are file
arguments to :hg:`fix`, the intersection of these filesets is used.

There is also a configurable limit for the maximum size of file that will be
processed by :hg:`fix`::

  [fix]
  maxfilesize=2MB

"""

from __future__ import absolute_import

import collections
import itertools
import os
import re
import subprocess
import sys

from mercurial.i18n import _
from mercurial.node import nullrev
from mercurial.node import wdirrev

from mercurial import (
    cmdutil,
    context,
    copies,
    error,
    match,
    mdiff,
    merge,
    obsolete,
    posix,
    registrar,
    scmutil,
    util,
)

# Note for extension authors: ONLY specify testedwith = 'ships-with-hg-core' for
# extensions which SHIP WITH MERCURIAL. Non-mainline extensions should
# be specifying the version(s) of Mercurial they are tested with, or
# leave the attribute unspecified.
testedwith = 'ships-with-hg-core'

cmdtable = {}
command = registrar.command(cmdtable)

configtable = {}
configitem = registrar.configitem(configtable)

# Register the suboptions allowed for each configured fixer.
FIXER_ATTRS = ('command', 'linerange', 'fileset')

for key in FIXER_ATTRS:
    configitem('fix', '.*(:%s)?' % key, default=None, generic=True)

# A good default size allows most source code files to be fixed, but avoids
# letting fixer tools choke on huge inputs, which could be surprising to the
# user.
configitem('fix', 'maxfilesize', default='2MB')

@command('fix',
    [('', 'base', [], _('revisions to diff against (overrides automatic '
                        'selection, and applies to every revision being '
                        'fixed)'), _('REV')),
     ('r', 'rev', [], _('revisions to fix'), _('REV')),
     ('w', 'working-dir', False, _('fix the working directory')),
     ('', 'whole', False, _('always fix every line of a file'))],
    _('[OPTION]... [FILE]...'))
def fix(ui, repo, *pats, **opts):
    """rewrite file content in changesets or working directory

    Runs any configured tools to fix the content of files. Only affects files
    with changes, unless file arguments are provided. Only affects changed lines
    of files, unless the --whole flag is used. Some tools may always affect the
    whole file regardless of --whole.

    If revisions are specified with --rev, those revisions will be checked, and
    they may be replaced with new revisions that have fixed file content.  It is
    desirable to specify all descendants of each specified revision, so that the
    fixes propagate to the descendants. If all descendants are fixed at the same
    time, no merging, rebasing, or evolution will be required.

    If --working-dir is used, files with uncommitted changes in the working copy
    will be fixed. If the checked-out revision is also fixed, the working
    directory will update to the replacement revision.

    When determining what lines of each file to fix at each revision, the whole
    set of revisions being fixed is considered, so that fixes to earlier
    revisions are not forgotten in later ones. The --base flag can be used to
    override this default behavior, though it is not usually desirable to do so.
    """
    with repo.wlock(), repo.lock():
        revstofix = getrevstofix(ui, repo, opts)
        basectxs = getbasectxs(repo, opts, revstofix)
        workqueue, numitems = getworkqueue(ui, repo, pats, opts, revstofix,
                                           basectxs)
        filedata = collections.defaultdict(dict)
        replacements = {}
        fixers = getfixers(ui)
        # Some day this loop can become a worker pool, but for now it's easier
        # to fix everything serially in topological order.
        for rev, path in sorted(workqueue):
            ctx = repo[rev]
            olddata = ctx[path].data()
            newdata = fixfile(ui, opts, fixers, ctx, path, basectxs[rev])
            if newdata != olddata:
                filedata[rev][path] = newdata
            numitems[rev] -= 1
            if not numitems[rev]:
                if rev == wdirrev:
                    writeworkingdir(repo, ctx, filedata[rev], replacements)
                else:
                    replacerev(ui, repo, ctx, filedata[rev], replacements)
                del filedata[rev]

        replacements = {prec: [succ] for prec, succ in replacements.iteritems()}
        scmutil.cleanupnodes(repo, replacements, 'fix')

def getworkqueue(ui, repo, pats, opts, revstofix, basectxs):
    """"Constructs the list of files to be fixed at specific revisions

    It is up to the caller how to consume the work items, and the only
    dependence between them is that replacement revisions must be committed in
    topological order. Each work item represents a file in the working copy or
    in some revision that should be fixed and written back to the working copy
    or into a replacement revision.
    """
    workqueue = []
    numitems = collections.defaultdict(int)
    maxfilesize = ui.configbytes('fix', 'maxfilesize')
    for rev in revstofix:
        fixctx = repo[rev]
        match = scmutil.match(fixctx, pats, opts)
        for path in pathstofix(ui, repo, pats, opts, match, basectxs[rev],
                               fixctx):
            if path not in fixctx:
                continue
            fctx = fixctx[path]
            if fctx.islink():
                continue
            if fctx.size() > maxfilesize:
                ui.warn(_('ignoring file larger than %s: %s\n') %
                        (util.bytecount(maxfilesize), path))
                continue
            workqueue.append((rev, path))
            numitems[rev] += 1
    return workqueue, numitems

def getrevstofix(ui, repo, opts):
    """Returns the set of revision numbers that should be fixed"""
    revs = set(scmutil.revrange(repo, opts['rev']))
    for rev in revs:
        checkfixablectx(ui, repo, repo[rev])
    if revs:
        cmdutil.checkunfinished(repo)
        checknodescendants(repo, revs)
    if opts.get('working_dir'):
        revs.add(wdirrev)
        if list(merge.mergestate.read(repo).unresolved()):
            raise error.Abort('unresolved conflicts', hint="use 'hg resolve'")
    if not revs:
        raise error.Abort(
            'no changesets specified', hint='use --rev or --working-dir')
    return revs

def checknodescendants(repo, revs):
    if (not obsolete.isenabled(repo, obsolete.allowunstableopt) and
        repo.revs('(%ld::) - (%ld)', revs, revs)):
        raise error.Abort(_('can only fix a changeset together '
                            'with all its descendants'))

def checkfixablectx(ui, repo, ctx):
    """Aborts if the revision shouldn't be replaced with a fixed one."""
    if not ctx.mutable():
        raise error.Abort('can\'t fix immutable changeset %s' %
                          (scmutil.formatchangeid(ctx),))
    if ctx.obsolete():
        # It would be better to actually check if the revision has a successor.
        allowdivergence = ui.configbool('experimental',
                                        'evolution.allowdivergence')
        if not allowdivergence:
            raise error.Abort('fixing obsolete revision could cause divergence')

def pathstofix(ui, repo, pats, opts, match, basectxs, fixctx):
    """Returns the set of files that should be fixed in a context

    The result depends on the base contexts; we include any file that has
    changed relative to any of the base contexts. Base contexts should be
    ancestors of the context being fixed.
    """
    files = set()
    for basectx in basectxs:
        stat = repo.status(
            basectx, fixctx, match=match, clean=bool(pats), unknown=bool(pats))
        files.update(
            set(itertools.chain(stat.added, stat.modified, stat.clean,
                                stat.unknown)))
    return files

def lineranges(opts, path, basectxs, fixctx, content2):
    """Returns the set of line ranges that should be fixed in a file

    Of the form [(10, 20), (30, 40)].

    This depends on the given base contexts; we must consider lines that have
    changed versus any of the base contexts, and whether the file has been
    renamed versus any of them.

    Another way to understand this is that we exclude line ranges that are
    common to the file in all base contexts.
    """
    if opts.get('whole'):
        # Return a range containing all lines. Rely on the diff implementation's
        # idea of how many lines are in the file, instead of reimplementing it.
        return difflineranges('', content2)

    rangeslist = []
    for basectx in basectxs:
        basepath = copies.pathcopies(basectx, fixctx).get(path, path)
        if basepath in basectx:
            content1 = basectx[basepath].data()
        else:
            content1 = ''
        rangeslist.extend(difflineranges(content1, content2))
    return unionranges(rangeslist)

def unionranges(rangeslist):
    """Return the union of some closed intervals

    >>> unionranges([])
    []
    >>> unionranges([(1, 100)])
    [(1, 100)]
    >>> unionranges([(1, 100), (1, 100)])
    [(1, 100)]
    >>> unionranges([(1, 100), (2, 100)])
    [(1, 100)]
    >>> unionranges([(1, 99), (1, 100)])
    [(1, 100)]
    >>> unionranges([(1, 100), (40, 60)])
    [(1, 100)]
    >>> unionranges([(1, 49), (50, 100)])
    [(1, 100)]
    >>> unionranges([(1, 48), (50, 100)])
    [(1, 48), (50, 100)]
    >>> unionranges([(1, 2), (3, 4), (5, 6)])
    [(1, 6)]
    """
    rangeslist = sorted(set(rangeslist))
    unioned = []
    if rangeslist:
        unioned, rangeslist = [rangeslist[0]], rangeslist[1:]
    for a, b in rangeslist:
        c, d = unioned[-1]
        if a > d + 1:
            unioned.append((a, b))
        else:
            unioned[-1] = (c, max(b, d))
    return unioned

def difflineranges(content1, content2):
    """Return list of line number ranges in content2 that differ from content1.

    Line numbers are 1-based. The numbers are the first and last line contained
    in the range. Single-line ranges have the same line number for the first and
    last line. Excludes any empty ranges that result from lines that are only
    present in content1. Relies on mdiff's idea of where the line endings are in
    the string.

    >>> lines = lambda s: '\\n'.join([c for c in s])
    >>> difflineranges2 = lambda a, b: difflineranges(lines(a), lines(b))
    >>> difflineranges2('', '')
    []
    >>> difflineranges2('a', '')
    []
    >>> difflineranges2('', 'A')
    [(1, 1)]
    >>> difflineranges2('a', 'a')
    []
    >>> difflineranges2('a', 'A')
    [(1, 1)]
    >>> difflineranges2('ab', '')
    []
    >>> difflineranges2('', 'AB')
    [(1, 2)]
    >>> difflineranges2('abc', 'ac')
    []
    >>> difflineranges2('ab', 'aCb')
    [(2, 2)]
    >>> difflineranges2('abc', 'aBc')
    [(2, 2)]
    >>> difflineranges2('ab', 'AB')
    [(1, 2)]
    >>> difflineranges2('abcde', 'aBcDe')
    [(2, 2), (4, 4)]
    >>> difflineranges2('abcde', 'aBCDe')
    [(2, 4)]
    """
    ranges = []
    for lines, kind in mdiff.allblocks(content1, content2):
        firstline, lastline = lines[2:4]
        if kind == '!' and firstline != lastline:
            ranges.append((firstline + 1, lastline))
    return ranges

def getbasectxs(repo, opts, revstofix):
    """Returns a map of the base contexts for each revision

    The base contexts determine which lines are considered modified when we
    attempt to fix just the modified lines in a file.
    """
    # The --base flag overrides the usual logic, and we give every revision
    # exactly the set of baserevs that the user specified.
    if opts.get('base'):
        baserevs = set(scmutil.revrange(repo, opts.get('base')))
        if not baserevs:
            baserevs = {nullrev}
        basectxs = {repo[rev] for rev in baserevs}
        return {rev: basectxs for rev in revstofix}

    # Proceed in topological order so that we can easily determine each
    # revision's baserevs by looking at its parents and their baserevs.
    basectxs = collections.defaultdict(set)
    for rev in sorted(revstofix):
        ctx = repo[rev]
        for pctx in ctx.parents():
            if pctx.rev() in basectxs:
                basectxs[rev].update(basectxs[pctx.rev()])
            else:
                basectxs[rev].add(pctx)
    return basectxs

def fixfile(ui, opts, fixers, fixctx, path, basectxs):
    """Run any configured fixers that should affect the file in this context

    Returns the file content that results from applying the fixers in some order
    starting with the file's content in the fixctx. Fixers that support line
    ranges will affect lines that have changed relative to any of the basectxs
    (i.e. they will only avoid lines that are common to all basectxs).
    """
    newdata = fixctx[path].data()
    for fixername, fixer in fixers.iteritems():
        if fixer.affects(opts, fixctx, path):
            ranges = lineranges(opts, path, basectxs, fixctx, newdata)
            command = fixer.command(path, ranges)
            if command is None:
                continue
            ui.debug('subprocess: %s\n' % (command,))
            proc = subprocess.Popen(
                command,
                shell=True,
                cwd='/',
                stdin=subprocess.PIPE,
                stdout=subprocess.PIPE,
                stderr=subprocess.PIPE)
            newerdata, stderr = proc.communicate(newdata)
            if stderr:
                showstderr(ui, fixctx.rev(), fixername, stderr)
            else:
                newdata = newerdata
    return newdata

def showstderr(ui, rev, fixername, stderr):
    """Writes the lines of the stderr string as warnings on the ui

    Uses the revision number and fixername to give more context to each line of
    the error message. Doesn't include file names, since those take up a lot of
    space and would tend to be included in the error message if they were
    relevant.
    """
    for line in re.split('[\r\n]+', stderr):
        if line:
            ui.warn(('['))
            if rev is None:
                ui.warn(_('wdir'), label='evolve.rev')
            else:
                ui.warn((str(rev)), label='evolve.rev')
            ui.warn(('] %s: %s\n') % (fixername, line))

def writeworkingdir(repo, ctx, filedata, replacements):
    """Write new content to the working copy and check out the new p1 if any

    We check out a new revision if and only if we fixed something in both the
    working directory and its parent revision. This avoids the need for a full
    update/merge, and means that the working directory simply isn't affected
    unless the --working-dir flag is given.

    Directly updates the dirstate for the affected files.
    """
    for path, data in filedata.iteritems():
        fctx = ctx[path]
        fctx.write(data, fctx.flags())
        if repo.dirstate[path] == 'n':
            repo.dirstate.normallookup(path)

    oldparentnodes = repo.dirstate.parents()
    newparentnodes = [replacements.get(n, n) for n in oldparentnodes]
    if newparentnodes != oldparentnodes:
        repo.setparents(*newparentnodes)

def replacerev(ui, repo, ctx, filedata, replacements):
    """Commit a new revision like the given one, but with file content changes

    "ctx" is the original revision to be replaced by a modified one.

    "filedata" is a dict that maps paths to their new file content. All other
    paths will be recreated from the original revision without changes.
    "filedata" may contain paths that didn't exist in the original revision;
    they will be added.

    "replacements" is a dict that maps a single node to a single node, and it is
    updated to indicate the original revision is replaced by the newly created
    one. No entry is added if the replacement's node already exists.

    The new revision has the same parents as the old one, unless those parents
    have already been replaced, in which case those replacements are the parents
    of this new revision. Thus, if revisions are replaced in topological order,
    there is no need to rebase them into the original topology later.
    """

    p1rev, p2rev = repo.changelog.parentrevs(ctx.rev())
    p1ctx, p2ctx = repo[p1rev], repo[p2rev]
    newp1node = replacements.get(p1ctx.node(), p1ctx.node())
    newp2node = replacements.get(p2ctx.node(), p2ctx.node())

    def filectxfn(repo, memctx, path):
        if path not in ctx:
            return None
        fctx = ctx[path]
        copied = fctx.renamed()
        if copied:
            copied = copied[0]
        return context.memfilectx(
            repo,
            memctx,
            path=fctx.path(),
            data=filedata.get(path, fctx.data()),
            islink=fctx.islink(),
            isexec=fctx.isexec(),
            copied=copied)

    overrides = {('phases', 'new-commit'): ctx.phase()}
    with ui.configoverride(overrides, source='fix'):
        memctx = context.memctx(
            repo,
            parents=(newp1node, newp2node),
            text=ctx.description(),
            files=set(ctx.files()) | set(filedata.keys()),
            filectxfn=filectxfn,
            user=ctx.user(),
            date=ctx.date(),
            extra=ctx.extra(),
            branch=ctx.branch(),
            editor=None)
        sucnode = memctx.commit()
        prenode = ctx.node()
        if prenode == sucnode:
            ui.debug('node %s already existed\n' % (ctx.hex()))
        else:
            replacements[ctx.node()] = sucnode

def getfixers(ui):
    """Returns a map of configured fixer tools indexed by their names

    Each value is a Fixer object with methods that implement the behavior of the
    fixer's config suboptions. Does not validate the config values.
    """
    result = {}
    for name in fixernames(ui):
        result[name] = Fixer()
        attrs = ui.configsuboptions('fix', name)[1]
        for key in FIXER_ATTRS:
            setattr(result[name], '_' + key, attrs.get(key, ''))
    return result

def fixernames(ui):
    """Returns the names of [fix] config options that have suboptions"""
    names = set()
    for k, v in ui.configitems('fix'):
        if ':' in k:
            names.add(k.split(':', 1)[0])
    return names

class Fixer(object):
    """Wraps the raw config values for a fixer with methods"""

    def affects(self, opts, fixctx, path):
        """Should this fixer run on the file at the given path and context?"""
        return scmutil.match(fixctx, [self._fileset], opts)(path)

    def command(self, path, ranges):
        """A shell command to use to invoke this fixer on the given file/lines

        May return None if there is no appropriate command to run for the given
        parameters.
        """
        parts = [self._command.format(rootpath=path,
                                      basename=os.path.basename(path))]
        if self._linerange:
            if not ranges:
                # No line ranges to fix, so don't run the fixer.
                return None
            for first, last in ranges:
                parts.append(self._linerange.format(first=first, last=last))
        return ' '.join(parts)
