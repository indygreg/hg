from __future__ import absolute_import, print_function
import os
import sys
from mercurial import (
    dispatch,
)

def printb(data, end=b'\n'):
    out = getattr(sys.stdout, 'buffer', sys.stdout)
    out.write(data + end)
    out.flush()

def testdispatch(cmd):
    """Simple wrapper around dispatch.dispatch()

    Prints command and result value, but does not handle quoting.
    """
    printb(b"running: %s" % (cmd,))
    req = dispatch.request(cmd.split())
    result = dispatch.dispatch(req)
    printb(b"result: %r" % (result,))

testdispatch(b"init test1")
os.chdir('test1')

# create file 'foo', add and commit
f = open('foo', 'wb')
f.write(b'foo\n')
f.close()
testdispatch(b"add foo")
testdispatch(b"commit -m commit1 -d 2000-01-01 foo")

# append to file 'foo' and commit
f = open('foo', 'ab')
f.write(b'bar\n')
f.close()
testdispatch(b"commit -m commit2 -d 2000-01-02 foo")

# check 88803a69b24 (fancyopts modified command table)
testdispatch(b"log -r 0")
testdispatch(b"log -r tip")
