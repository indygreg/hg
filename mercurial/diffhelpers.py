# diffhelpers.py - helper routines for patch
#
# Copyright 2009 Matt Mackall <mpm@selenic.com> and others
#
# This software may be used and distributed according to the terms of the
# GNU General Public License version 2 or any later version.

from __future__ import absolute_import

def addlines(fp, hunk, lena, lenb, a, b):
    """Read lines from fp into the hunk

    The hunk is parsed into two arrays, a and b. a gets the old state of
    the text, b gets the new state. The control char from the hunk is saved
    when inserting into a, but not b (for performance while deleting files.)
    """
    while True:
        todoa = lena - len(a)
        todob = lenb - len(b)
        num = max(todoa, todob)
        if num == 0:
            break
        for i in xrange(num):
            s = fp.readline()
            if s == "\\ No newline at end of file\n":
                fixnewline(hunk, a, b)
                continue
            if s == "\n":
                # Some patches may be missing the control char
                # on empty lines. Supply a leading space.
                s = " \n"
            hunk.append(s)
            if s.startswith('+'):
                b.append(s[1:])
            elif s.startswith('-'):
                a.append(s)
            else:
                b.append(s[1:])
                a.append(s)
    return 0

def fixnewline(hunk, a, b):
    """Fix up the last lines of a and b when the patch has no newline at EOF"""
    l = hunk[-1]
    # tolerate CRLF in last line
    if l.endswith('\r\n'):
        hline = l[:-2]
    else:
        hline = l[:-1]

    if hline.startswith((' ', '+')):
        b[-1] = hline[1:]
    if hline.startswith((' ', '-')):
        a[-1] = hline
    hunk[-1] = hline
    return 0

def testhunk(a, b, bstart):
    """Compare the lines in a with the lines in b

    a is assumed to have a control char at the start of each line, this char
    is ignored in the compare.
    """
    alen = len(a)
    blen = len(b)
    if alen > blen - bstart:
        return -1
    for i in xrange(alen):
        if a[i][1:] != b[i + bstart]:
            return -1
    return 0
