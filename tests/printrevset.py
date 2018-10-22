from __future__ import absolute_import
from mercurial import (
  cmdutil,
  commands,
  extensions,
  logcmdutil,
  revsetlang,
  smartset,
)

from mercurial.utils import (
  stringutil,
)

def logrevset(repo, pats, opts):
    revs = logcmdutil._initialrevs(repo, opts)
    if not revs:
        return None
    match, pats, slowpath = logcmdutil._makematcher(repo, revs, pats, opts)
    return logcmdutil._makerevset(repo, match, pats, slowpath, opts)

def uisetup(ui):
    def printrevset(orig, repo, pats, opts):
        revs, filematcher = orig(repo, pats, opts)
        if opts.get(b'print_revset'):
            expr = logrevset(repo, pats, opts)
            if expr:
                tree = revsetlang.parse(expr)
                tree = revsetlang.analyze(tree)
            else:
                tree = []
            ui = repo.ui
            ui.write(b'%s\n' % stringutil.pprint(opts.get(b'rev', [])))
            ui.write(revsetlang.prettyformat(tree) + b'\n')
            ui.write(stringutil.prettyrepr(revs) + b'\n')
            revs = smartset.baseset()  # display no revisions
        return revs, filematcher
    extensions.wrapfunction(logcmdutil, 'getrevs', printrevset)
    aliases, entry = cmdutil.findcmd(b'log', commands.table)
    entry[1].append((b'', b'print-revset', False,
                     b'print generated revset and exit (DEPRECATED)'))
