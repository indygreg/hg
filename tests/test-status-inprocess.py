#!/usr/bin/env python
from __future__ import absolute_import, print_function

from mercurial import (
    commands,
    localrepo,
    ui as uimod,
)

u = uimod.ui.load()

print('% creating repo')
repo = localrepo.localrepository(u, b'.', create=True)

f = open('test.py', 'w')
try:
    f.write('foo\n')
finally:
    f.close

print('% add and commit')
commands.add(u, repo, b'test.py')
commands.commit(u, repo, message=b'*')
commands.status(u, repo, clean=True)


print('% change')
f = open('test.py', 'w')
try:
    f.write('bar\n')
finally:
    f.close()

# this would return clean instead of changed before the fix
commands.status(u, repo, clean=True, modified=True)
