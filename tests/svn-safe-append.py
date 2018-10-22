#!/usr/bin/env python

from __future__ import absolute_import

__doc__ = """Same as `echo a >> b`, but ensures a changed mtime of b.
Without this svn will not detect workspace changes."""

import os
import stat
import sys

if sys.version_info[0] >= 3:
    text = os.fsencode(sys.argv[1])
    fname = os.fsencode(sys.argv[2])
else:
    text = sys.argv[1]
    fname = sys.argv[2]

f = open(fname, "ab")
try:
    before = os.fstat(f.fileno())[stat.ST_MTIME]
    f.write(text)
    f.write(b"\n")
finally:
    f.close()
inc = 1
now = os.stat(fname)[stat.ST_MTIME]
while now == before:
    t = now + inc
    inc += 1
    os.utime(fname, (t, t))
    now = os.stat(fname)[stat.ST_MTIME]
