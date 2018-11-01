#!/usr/bin/env python3
#
# Copyright 2018 Google LLC.
#
# This software may be used and distributed according to the terms of the
# GNU General Public License version 2 or any later version.
"""Tool read primitive events from a pipe to produce a catapult trace.

Usage:
    Terminal 1: $ catapipe.py /tmp/mypipe /tmp/trace.json
    Terminal 2: $ HGCATAPULTSERVERPIPE=/tmp/mypipe hg root
    <ctrl-c catapipe.py in Terminal 1>
    $ catapult/tracing/bin/trace2html /tmp/trace.json  # produce /tmp/trace.html
    <open trace.html in your browser of choice; the WASD keys are very useful>
    (catapult is located at https://github.com/catapult-project/catapult)

For now the event stream supports

  START $SESSIONID ...

and

  END $SESSIONID ...

events. Everything after the SESSIONID (which must not contain spaces)
is used as a label for the event. Events are timestamped as of when
they arrive in this process and are then used to produce catapult
traces that can be loaded in Chrome's about:tracing utility. It's
important that the event stream *into* this process stay simple,
because we have to emit it from the shell scripts produced by
run-tests.py.

Typically you'll want to place the path to the named pipe in the
HGCATAPULTSERVERPIPE environment variable, which both run-tests and hg
understand. To trace *only* run-tests, use HGTESTCATAPULTSERVERPIPE instead.
"""
from __future__ import absolute_import, print_function

import argparse
import json
import os
import timeit

_TYPEMAP = {
    'START': 'B',
    'END': 'E',
}

_threadmap = {}

# Timeit already contains the whole logic about which timer to use based on
# Python version and OS
timer = timeit.default_timer

def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('pipe', type=str, nargs=1,
                        help='Path of named pipe to create and listen on.')
    parser.add_argument('output', default='trace.json', type=str, nargs='?',
                        help='Path of json file to create where the traces '
                             'will be stored.')
    parser.add_argument('--debug', default=False, action='store_true',
                        help='Print useful debug messages')
    args = parser.parse_args()
    fn = args.pipe[0]
    os.mkfifo(fn)
    try:
        with open(fn) as f, open(args.output, 'w') as out:
            out.write('[\n')
            start = timer()
            while True:
                ev = f.readline().strip()
                if not ev:
                    continue
                now = timer()
                if args.debug:
                    print(ev)
                verb, session, label = ev.split(' ', 2)
                if session not in _threadmap:
                    _threadmap[session] = len(_threadmap)
                pid = _threadmap[session]
                ts_micros = (now - start) * 1000000
                out.write(json.dumps(
                    {
                        "name": label,
                        "cat": "misc",
                        "ph": _TYPEMAP[verb],
                        "ts": ts_micros,
                        "pid": pid,
                        "tid": 1,
                        "args": {}
                    }))
                out.write(',\n')
    finally:
        os.unlink(fn)

if __name__ == '__main__':
    main()
