# Extension dedicated to test patch.diff() upgrade modes

from __future__ import absolute_import

from mercurial import (
    error,
    patch,
    registrar,
    scmutil,
)

cmdtable = {}
command = registrar.command(cmdtable)

@command(b'autodiff',
    [(b'', b'git', b'', b'git upgrade mode (yes/no/auto/warn/abort)')],
    b'[OPTION]... [FILE]...')
def autodiff(ui, repo, *pats, **opts):
    diffopts = patch.difffeatureopts(ui, opts)
    git = opts.get(b'git', b'no')
    brokenfiles = set()
    losedatafn = None
    if git in (b'yes', b'no'):
        diffopts.git = git == b'yes'
        diffopts.upgrade = False
    elif git == b'auto':
        diffopts.git = False
        diffopts.upgrade = True
    elif git == b'warn':
        diffopts.git = False
        diffopts.upgrade = True
        def losedatafn(fn=None, **kwargs):
            brokenfiles.add(fn)
            return True
    elif git == b'abort':
        diffopts.git = False
        diffopts.upgrade = True
        def losedatafn(fn=None, **kwargs):
            raise error.Abort(b'losing data for %s' % fn)
    else:
        raise error.Abort(b'--git must be yes, no or auto')

    node1, node2 = scmutil.revpair(repo, [])
    m = scmutil.match(repo[node2], pats, opts)
    it = patch.diff(repo, node1, node2, match=m, opts=diffopts,
                    losedatafn=losedatafn)
    for chunk in it:
        ui.write(chunk)
    for fn in sorted(brokenfiles):
        ui.write((b'data lost for: %s\n' % fn))
