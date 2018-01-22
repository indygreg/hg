from __future__ import absolute_import
from __future__ import print_function

import os
import sys

# make it runnable directly without run-tests.py
sys.path[0:0] = [os.path.join(os.path.dirname(__file__), '..')]

from mercurial import minifileset

def check(text, truecases, falsecases):
    f = minifileset.compile(text)
    for args in truecases:
        if not f(*args):
            print('unexpected: %r should include %r' % (text, args))
    for args in falsecases:
        if f(*args):
            print('unexpected: %r should exclude %r' % (text, args))

check('all()', [('a.php', 123), ('b.txt', 0)], [])
check('none()', [], [('a.php', 123), ('b.txt', 0)])
check('!!!!((!(!!all())))', [], [('a.php', 123), ('b.txt', 0)])

check('"path:a" & (**.b | **.c)', [('a/b.b', 0), ('a/c.c', 0)], [('b/c.c', 0)])
check('(path:a & **.b) | **.c',
      [('a/b.b', 0), ('a/c.c', 0), ('b/c.c', 0)], [])

check('**.bin - size("<20B")', [('b.bin', 21)], [('a.bin', 11), ('b.txt', 21)])

check('!!**.bin or size(">20B") + "path:bin" or !size(">10")',
      [('a.bin', 11), ('b.txt', 21), ('bin/abc', 11)],
      [('a.notbin', 11), ('b.txt', 11), ('bin2/abc', 11)])

check('(**.php and size(">10KB")) | **.zip | ("path:bin" & !"path:bin/README") '
      ' | size(">1M")',
      [('a.php', 15000), ('a.zip', 0), ('bin/a', 0), ('bin/README', 1e7)],
      [('a.php', 5000), ('b.zip2', 0), ('t/bin/a', 0), ('bin/README', 1)])
