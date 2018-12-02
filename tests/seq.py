#!/usr/bin/env python
#
# A portable replacement for 'seq'
#
# Usage:
#   seq STOP              [1, STOP] stepping by 1
#   seq START STOP        [START, STOP] stepping by 1
#   seq START STEP STOP   [START, STOP] stepping by STEP

from __future__ import absolute_import, print_function
import os
import sys

try:
    import msvcrt
    msvcrt.setmode(sys.stdin.fileno(), os.O_BINARY)
    msvcrt.setmode(sys.stdout.fileno(), os.O_BINARY)
    msvcrt.setmode(sys.stderr.fileno(), os.O_BINARY)
except ImportError:
    pass

if sys.version_info[0] >= 3:
    xrange = range

start = 1
if len(sys.argv) > 2:
    start = int(sys.argv[1])

step = 1
if len(sys.argv) > 3:
    step = int(sys.argv[2])

stop = int(sys.argv[-1]) + 1

for i in xrange(start, stop, step):
    print(i)
