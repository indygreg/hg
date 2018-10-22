#!/usr/bin/env python
#
# generate-branchy-bundle - generate a branch for a "large" branchy repository
#
# Copyright 2018 Octobus, contact@octobus.net
#
# This software may be used and distributed according to the terms of the
# GNU General Public License version 2 or any later version.
#
# This script generates a repository suitable for testing delta computation
# strategies.
#
# The repository update a single "large" file with many updates. One fixed part
# of the files always get updated while the rest of the lines get updated over
# time. This update happens over many topological branches, some getting merged
# back.
#
# Running with `chg` in your path and `CHGHG` set is recommended for speed.

from __future__ import absolute_import, print_function

import hashlib
import os
import shutil
import subprocess
import sys
import tempfile

BUNDLE_NAME = 'big-file-churn.hg'

# constants for generating the repository
NB_CHANGESET = 5000
PERIOD_MERGING = 8
PERIOD_BRANCHING = 7
MOVE_BACK_MIN = 3
MOVE_BACK_RANGE = 5

# constants for generating the large file we keep updating
#
# At each revision, the beginning on the file change,
# and set of other lines changes too.
FILENAME='SPARSE-REVLOG-TEST-FILE'
NB_LINES = 10500
ALWAYS_CHANGE_LINES = 500
FILENAME = 'SPARSE-REVLOG-TEST-FILE'
OTHER_CHANGES = 300

def nextcontent(previous_content):
    """utility to produce a new file content from the previous one"""
    return hashlib.md5(previous_content).hexdigest()

def filecontent(iteridx, oldcontent):
    """generate a new file content

    The content is generated according the iteration index and previous
    content"""

    # initial call
    if iteridx is None:
        current = ''
    else:
        current = str(iteridx)

    for idx in xrange(NB_LINES):
        do_change_line = True
        if oldcontent is not None and ALWAYS_CHANGE_LINES < idx:
            do_change_line = not ((idx - iteridx) % OTHER_CHANGES)

        if do_change_line:
            to_write = current + '\n'
            current = nextcontent(current)
        else:
            to_write = oldcontent[idx]
        yield to_write

def updatefile(filename, idx):
    """update <filename> to be at appropriate content for iteration <idx>"""
    existing = None
    if idx is not None:
        with open(filename, 'rb') as old:
            existing = old.readlines()
    with open(filename, 'wb') as target:
        for line in filecontent(idx, existing):
            target.write(line)

def hg(command, *args):
    """call a mercurial command with appropriate config and argument"""
    env = os.environ.copy()
    if 'CHGHG' in env:
        full_cmd = ['chg']
    else:
        full_cmd = ['hg']
    full_cmd.append('--quiet')
    full_cmd.append(command)
    if command == 'commit':
        # reproducible commit metadata
        full_cmd.extend(['--date', '0 0', '--user', 'test'])
    elif command == 'merge':
        # avoid conflicts by picking the local variant
        full_cmd.extend(['--tool', ':merge-local'])
    full_cmd.extend(args)
    env['HGRCPATH'] = ''
    return subprocess.check_call(full_cmd, env=env)

def run(target):
    tmpdir = tempfile.mkdtemp(prefix='tmp-hg-test-big-file-bundle-')
    try:
        os.chdir(tmpdir)
        hg('init')
        updatefile(FILENAME, None)
        hg('commit', '--addremove', '--message', 'initial commit')
        for idx in xrange(1, NB_CHANGESET + 1):
            if sys.stdout.isatty():
                print("generating commit #%d/%d" % (idx, NB_CHANGESET))
            if (idx % PERIOD_BRANCHING) == 0:
                move_back = MOVE_BACK_MIN + (idx % MOVE_BACK_RANGE)
                hg('update', ".~%d" % move_back)
            if (idx % PERIOD_MERGING) == 0:
                hg('merge', 'min(head())')
            updatefile(FILENAME, idx)
            hg('commit', '--message', 'commit #%d' % idx)
        hg('bundle', '--all', target)
        with open(target, 'rb') as bundle:
            data = bundle.read()
            digest = hashlib.md5(data).hexdigest()
        with open(target + '.md5', 'wb') as md5file:
            md5file.write(digest + '\n')
        if sys.stdout.isatty():
            print('bundle generated at "%s" md5: %s' % (target, digest))

    finally:
        shutil.rmtree(tmpdir)
    return 0

if __name__ == '__main__':
    orig = os.path.realpath(os.path.dirname(sys.argv[0]))
    target = os.path.join(orig, os.pardir, 'cache', BUNDLE_NAME)
    sys.exit(run(target))

