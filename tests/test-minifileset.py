from __future__ import absolute_import
from __future__ import print_function

from mercurial import minifileset

def check(text, truecases, falsecases):
    f = minifileset.compile(text)
    for args in truecases:
        if not f(*args):
            print('unexpected: %r should include %r' % (text, args))
    for args in falsecases:
        if f(*args):
            print('unexpected: %r should exclude %r' % (text, args))

check(b'all()', [(b'a.php', 123), (b'b.txt', 0)], [])
check(b'none()', [], [(b'a.php', 123), (b'b.txt', 0)])
check(b'!!!!((!(!!all())))', [], [(b'a.php', 123), (b'b.txt', 0)])

check(b'"path:a" & (**.b | **.c)',
      [(b'a/b.b', 0), (b'a/c.c', 0)], [(b'b/c.c', 0)])
check(b'(path:a & **.b) | **.c',
      [(b'a/b.b', 0), (b'a/c.c', 0), (b'b/c.c', 0)], [])

check(b'**.bin - size("<20B")',
      [(b'b.bin', 21)], [(b'a.bin', 11), (b'b.txt', 21)])

check(b'!!**.bin or size(">20B") + "path:bin" or !size(">10")',
      [(b'a.bin', 11), (b'b.txt', 21), (b'bin/abc', 11)],
      [(b'a.notbin', 11), (b'b.txt', 11), (b'bin2/abc', 11)])

check(
    b'(**.php and size(">10KB")) | **.zip | ("path:bin" & !"path:bin/README") '
    b' | size(">1M")',
    [(b'a.php', 15000), (b'a.zip', 0), (b'bin/a', 0), (b'bin/README', 1e7)],
    [(b'a.php', 5000), (b'b.zip2', 0), (b't/bin/a', 0), (b'bin/README', 1)])
