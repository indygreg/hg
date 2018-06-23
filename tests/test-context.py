from __future__ import absolute_import, print_function
import os
import stat
import sys
from mercurial.node import hex
from mercurial import (
    context,
    encoding,
    hg,
    scmutil,
    ui as uimod,
)
from mercurial.utils import diffutil

print_ = print
def print(*args, **kwargs):
    """print() wrapper that flushes stdout buffers to avoid py3 buffer issues

    We could also just write directly to sys.stdout.buffer the way the
    ui object will, but this was easier for porting the test.
    """
    print_(*args, **kwargs)
    sys.stdout.flush()

def printb(data, end=b'\n'):
    out = getattr(sys.stdout, 'buffer', sys.stdout)
    out.write(data + end)
    out.flush()

u = uimod.ui.load()

repo = hg.repository(u, b'test1', create=1)
os.chdir('test1')

# create 'foo' with fixed time stamp
f = open('foo', 'wb')
f.write(b'foo\n')
f.close()
os.utime('foo', (1000, 1000))

# add+commit 'foo'
repo[None].add([b'foo'])
repo.commit(text=b'commit1', date=b"0 0")

d = repo[None][b'foo'].date()
if os.name == 'nt':
    d = d[:2]
print("workingfilectx.date = (%d, %d)" % d)

# test memctx with non-ASCII commit message

def filectxfn(repo, memctx, path):
    return context.memfilectx(repo, memctx, b"foo", b"")

ctx = context.memctx(repo, [b'tip', None],
                     encoding.tolocal(b"Gr\xc3\xbcezi!"),
                     [b"foo"], filectxfn)
ctx.commit()
for enc in "ASCII", "Latin-1", "UTF-8":
    encoding.encoding = enc
    printb(b"%-8s: %s" % (enc.encode('ascii'), repo[b"tip"].description()))

# test performing a status

def getfilectx(repo, memctx, f):
    fctx = memctx.parents()[0][f]
    data, flags = fctx.data(), fctx.flags()
    if f == b'foo':
        data += b'bar\n'
    return context.memfilectx(
        repo, memctx, f, data, b'l' in flags, b'x' in flags)

ctxa = repo[0]
ctxb = context.memctx(repo, [ctxa.node(), None], b"test diff", [b"foo"],
                      getfilectx, ctxa.user(), ctxa.date())

print(ctxb.status(ctxa))

# test performing a diff on a memctx
diffopts = diffutil.diffopts(repo.ui, {'git': True})
for d in ctxb.diff(ctxa, opts=diffopts):
    printb(d, end=b'')

# test safeness and correctness of "ctx.status()"
print('= checking context.status():')

# ancestor "wcctx ~ 2"
actx2 = repo[b'.']

repo.wwrite(b'bar-m', b'bar-m\n', b'')
repo.wwrite(b'bar-r', b'bar-r\n', b'')
repo[None].add([b'bar-m', b'bar-r'])
repo.commit(text=b'add bar-m, bar-r', date=b"0 0")

# ancestor "wcctx ~ 1"
actx1 = repo[b'.']

repo.wwrite(b'bar-m', b'bar-m bar-m\n', b'')
repo.wwrite(b'bar-a', b'bar-a\n', b'')
repo[None].add([b'bar-a'])
repo[None].forget([b'bar-r'])

# status at this point:
#   M bar-m
#   A bar-a
#   R bar-r
#   C foo

from mercurial import scmutil

print('== checking workingctx.status:')

wctx = repo[None]
print('wctx._status=%s' % (str(wctx._status)))

print('=== with "pattern match":')
print(actx1.status(other=wctx,
                   match=scmutil.matchfiles(repo, [b'bar-m', b'foo'])))
print('wctx._status=%s' % (str(wctx._status)))
print(actx2.status(other=wctx,
                   match=scmutil.matchfiles(repo, [b'bar-m', b'foo'])))
print('wctx._status=%s' % (str(wctx._status)))

print('=== with "always match" and "listclean=True":')
print(actx1.status(other=wctx, listclean=True))
print('wctx._status=%s' % (str(wctx._status)))
print(actx2.status(other=wctx, listclean=True))
print('wctx._status=%s' % (str(wctx._status)))

print("== checking workingcommitctx.status:")

wcctx = context.workingcommitctx(repo,
                                 scmutil.status([b'bar-m'],
                                                [b'bar-a'],
                                                [],
                                                [], [], [], []),
                                 text=b'', date=b'0 0')
print('wcctx._status=%s' % (str(wcctx._status)))

print('=== with "always match":')
print(actx1.status(other=wcctx))
print('wcctx._status=%s' % (str(wcctx._status)))
print(actx2.status(other=wcctx))
print('wcctx._status=%s' % (str(wcctx._status)))

print('=== with "always match" and "listclean=True":')
print(actx1.status(other=wcctx, listclean=True))
print('wcctx._status=%s' % (str(wcctx._status)))
print(actx2.status(other=wcctx, listclean=True))
print('wcctx._status=%s' % (str(wcctx._status)))

print('=== with "pattern match":')
print(actx1.status(other=wcctx,
                   match=scmutil.matchfiles(repo, [b'bar-m', b'foo'])))
print('wcctx._status=%s' % (str(wcctx._status)))
print(actx2.status(other=wcctx,
                   match=scmutil.matchfiles(repo, [b'bar-m', b'foo'])))
print('wcctx._status=%s' % (str(wcctx._status)))

print('=== with "pattern match" and "listclean=True":')
print(actx1.status(other=wcctx,
                   match=scmutil.matchfiles(repo, [b'bar-r', b'foo']),
                   listclean=True))
print('wcctx._status=%s' % (str(wcctx._status)))
print(actx2.status(other=wcctx,
                   match=scmutil.matchfiles(repo, [b'bar-r', b'foo']),
                   listclean=True))
print('wcctx._status=%s' % (str(wcctx._status)))

os.chdir('..')

# test manifestlog being changed
print('== commit with manifestlog invalidated')

repo = hg.repository(u, b'test2', create=1)
os.chdir('test2')

# make some commits
for i in [b'1', b'2', b'3']:
    with open(i, 'wb') as f:
        f.write(i)
    status = scmutil.status([], [i], [], [], [], [], [])
    ctx = context.workingcommitctx(repo, status, text=i, user=b'test@test.com',
                                   date=(0, 0))
    ctx.p1().manifest() # side effect: cache manifestctx
    n = repo.commitctx(ctx)
    printb(b'commit %s: %s' % (i, hex(n)))

    # touch 00manifest.i mtime so storecache could expire.
    # repo.__dict__['manifestlog'] is deleted by transaction releasefn.
    st = repo.svfs.stat(b'00manifest.i')
    repo.svfs.utime(b'00manifest.i',
                    (st[stat.ST_MTIME] + 1, st[stat.ST_MTIME] + 1))

    # read the file just committed
    try:
        if repo[n][i].data() != i:
            print('data mismatch')
    except Exception as ex:
        print('cannot read data: %r' % ex)

with repo.wlock(), repo.lock(), repo.transaction(b'test'):
    with open(b'4', 'wb') as f:
        f.write(b'4')
    repo.dirstate.normal(b'4')
    repo.commit(b'4')
    revsbefore = len(repo.changelog)
    repo.invalidate(clearfilecache=True)
    revsafter = len(repo.changelog)
    if revsbefore != revsafter:
        print('changeset lost by repo.invalidate()')
