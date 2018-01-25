# minifileset.py - a simple language to select files
#
# Copyright 2017 Facebook, Inc.
#
# This software may be used and distributed according to the terms of the
# GNU General Public License version 2 or any later version.

from __future__ import absolute_import

from .i18n import _
from . import (
    error,
    fileset,
)

def _compile(tree):
    if not tree:
        raise error.ParseError(_("missing argument"))
    op = tree[0]
    if op in {'symbol', 'string', 'kindpat'}:
        name = fileset.getpattern(tree, {'path'}, _('invalid file pattern'))
        if name.startswith('**'): # file extension test, ex. "**.tar.gz"
            ext = name[2:]
            for c in ext:
                if c in '*{}[]?/\\':
                    raise error.ParseError(_('reserved character: %s') % c)
            return lambda n, s: n.endswith(ext)
        elif name.startswith('path:'): # directory or full path test
            p = name[5:] # prefix
            pl = len(p)
            f = lambda n, s: n.startswith(p) and (len(n) == pl or n[pl] == '/')
            return f
        raise error.ParseError(_("unsupported file pattern: %s") % name,
                               hint=_('paths must be prefixed with "path:"'))
    elif op == 'or':
        func1 = _compile(tree[1])
        func2 = _compile(tree[2])
        return lambda n, s: func1(n, s) or func2(n, s)
    elif op == 'and':
        func1 = _compile(tree[1])
        func2 = _compile(tree[2])
        return lambda n, s: func1(n, s) and func2(n, s)
    elif op == 'not':
        return lambda n, s: not _compile(tree[1])(n, s)
    elif op == 'group':
        return _compile(tree[1])
    elif op == 'func':
        symbols = {
            'all': lambda n, s: True,
            'none': lambda n, s: False,
            'size': lambda n, s: fileset.sizematcher(tree[2])(s),
        }

        name = fileset.getsymbol(tree[1])
        if name in symbols:
            return symbols[name]

        raise error.UnknownIdentifier(name, symbols.keys())
    elif op == 'minus':     # equivalent to 'x and not y'
        func1 = _compile(tree[1])
        func2 = _compile(tree[2])
        return lambda n, s: func1(n, s) and not func2(n, s)
    elif op == 'negate':
        raise error.ParseError(_("can't use negate operator in this context"))
    elif op == 'list':
        raise error.ParseError(_("can't use a list in this context"),
                               hint=_('see hg help "filesets.x or y"'))
    raise error.ProgrammingError('illegal tree: %r' % (tree,))

def compile(text):
    """generate a function (path, size) -> bool from filter specification.

    "text" could contain the operators defined by the fileset language for
    common logic operations, and parenthesis for grouping.  The supported path
    tests are '**.extname' for file extension test, and '"path:dir/subdir"'
    for prefix test.  The ``size()`` predicate is borrowed from filesets to test
    file size.  The predicates ``all()`` and ``none()`` are also supported.

    '(**.php & size(">10MB")) | **.zip | (path:bin & !path:bin/README)' for
    example, will catch all php files whose size is greater than 10 MB, all
    files whose name ends with ".zip", and all files under "bin" in the repo
    root except for "bin/README".
    """
    tree = fileset.parse(text)
    return _compile(tree)
