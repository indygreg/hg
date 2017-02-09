from __future__ import absolute_import, print_function
import os
from mercurial import (
    hg,
    merge,
    ui as uimod,
)

u = uimod.ui.load()

repo = hg.repository(u, b'test1', create=1)
os.chdir('test1')

def commit(text, time):
    repo.commit(text=text, date=b"%d 0" % time)

def addcommit(name, time):
    f = open(name, 'wb')
    f.write(b'%s\n' % name)
    f.close()
    repo[None].add([name])
    commit(name, time)

def update(rev):
    merge.update(repo, rev, branchmerge=False, force=True)

def merge_(rev):
    merge.update(repo, rev, branchmerge=True, force=False)

if __name__ == '__main__':
    addcommit(b"A", 0)
    addcommit(b"B", 1)

    update(0)
    addcommit(b"C", 2)

    merge_(1)
    commit(b"D", 3)

    update(2)
    addcommit(b"E", 4)
    addcommit(b"F", 5)

    update(3)
    addcommit(b"G", 6)

    merge_(5)
    commit(b"H", 7)

    update(5)
    addcommit(b"I", 8)

    # Ancestors
    print('Ancestors of 5')
    for r in repo.changelog.ancestors([5]):
        print(r, end=' ')

    print('\nAncestors of 6 and 5')
    for r in repo.changelog.ancestors([6, 5]):
        print(r, end=' ')

    print('\nAncestors of 5 and 4')
    for r in repo.changelog.ancestors([5, 4]):
        print(r, end=' ')

    print('\nAncestors of 7, stop at 6')
    for r in repo.changelog.ancestors([7], 6):
        print(r, end=' ')

    print('\nAncestors of 7, including revs')
    for r in repo.changelog.ancestors([7], inclusive=True):
        print(r, end=' ')

    print('\nAncestors of 7, 5 and 3, including revs')
    for r in repo.changelog.ancestors([7, 5, 3], inclusive=True):
        print(r, end=' ')

    # Descendants
    print('\n\nDescendants of 5')
    for r in repo.changelog.descendants([5]):
        print(r, end=' ')

    print('\nDescendants of 5 and 3')
    for r in repo.changelog.descendants([5, 3]):
        print(r, end=' ')

    print('\nDescendants of 5 and 4')
    print(*repo.changelog.descendants([5, 4]), sep=' ')
