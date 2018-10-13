#!/usr/bin/env python
#
# check-config - a config flag documentation checker for Mercurial
#
# Copyright 2015 Matt Mackall <mpm@selenic.com>
#
# This software may be used and distributed according to the terms of the
# GNU General Public License version 2 or any later version.

from __future__ import absolute_import, print_function
import re
import sys

foundopts = {}
documented = {}
allowinconsistent = set()

configre = re.compile(br'''
    # Function call
    ui\.config(?P<ctype>|int|bool|list)\(
        # First argument.
        ['"](?P<section>\S+)['"],\s*
        # Second argument
        ['"](?P<option>\S+)['"](,\s+
        (?:default=)?(?P<default>\S+?))?
    \)''', re.VERBOSE | re.MULTILINE)

configwithre = re.compile(b'''
    ui\.config(?P<ctype>with)\(
        # First argument is callback function. This doesn't parse robustly
        # if it is e.g. a function call.
        [^,]+,\s*
        ['"](?P<section>\S+)['"],\s*
        ['"](?P<option>\S+)['"](,\s+
        (?:default=)?(?P<default>\S+?))?
    \)''', re.VERBOSE | re.MULTILINE)

configpartialre = (br"""ui\.config""")

ignorere = re.compile(br'''
    \#\s(?P<reason>internal|experimental|deprecated|developer|inconsistent)\s
    config:\s(?P<config>\S+\.\S+)$
    ''', re.VERBOSE | re.MULTILINE)

if sys.version_info[0] > 2:
    def mkstr(b):
        if isinstance(b, str):
            return b
        return b.decode('utf8')
else:
    mkstr = lambda x: x

def main(args):
    for f in args:
        sect = b''
        prevname = b''
        confsect = b''
        carryover = b''
        linenum = 0
        for l in open(f, 'rb'):
            linenum += 1

            # check topic-like bits
            m = re.match(b'\s*``(\S+)``', l)
            if m:
                prevname = m.group(1)
            if re.match(b'^\s*-+$', l):
                sect = prevname
                prevname = b''

            if sect and prevname:
                name = sect + b'.' + prevname
                documented[name] = 1

            # check docstring bits
            m = re.match(br'^\s+\[(\S+)\]', l)
            if m:
                confsect = m.group(1)
                continue
            m = re.match(br'^\s+(?:#\s*)?(\S+) = ', l)
            if m:
                name = confsect + b'.' + m.group(1)
                documented[name] = 1

            # like the bugzilla extension
            m = re.match(br'^\s*(\S+\.\S+)$', l)
            if m:
                documented[m.group(1)] = 1

            # like convert
            m = re.match(br'^\s*:(\S+\.\S+):\s+', l)
            if m:
                documented[m.group(1)] = 1

            # quoted in help or docstrings
            m = re.match(br'.*?``(\S+\.\S+)``', l)
            if m:
                documented[m.group(1)] = 1

            # look for ignore markers
            m = ignorere.search(l)
            if m:
                if m.group('reason') == b'inconsistent':
                    allowinconsistent.add(m.group('config'))
                else:
                    documented[m.group('config')] = 1

            # look for code-like bits
            line = carryover + l
            m = configre.search(line) or configwithre.search(line)
            if m:
                ctype = m.group('ctype')
                if not ctype:
                    ctype = 'str'
                name = m.group('section') + b"." + m.group('option')
                default = m.group('default')
                if default in (
                        None, b'False', b'None', b'0', b'[]', b'""', b"''"):
                    default = b''
                if re.match(b'[a-z.]+$', default):
                    default = b'<variable>'
                if (name in foundopts and (ctype, default) != foundopts[name]
                    and name not in allowinconsistent):
                    print(mkstr(l.rstrip()))
                    fctype, fdefault = foundopts[name]
                    print("conflict on %s: %r != %r" % (
                        mkstr(name),
                        (mkstr(ctype), mkstr(default)),
                        (mkstr(fctype), mkstr(fdefault))))
                    print("at %s:%d:" % (mkstr(f), linenum))
                foundopts[name] = (ctype, default)
                carryover = b''
            else:
                m = re.search(configpartialre, line)
                if m:
                    carryover = line
                else:
                    carryover = b''

    for name in sorted(foundopts):
        if name not in documented:
            if not (name.startswith(b"devel.") or
                    name.startswith(b"experimental.") or
                    name.startswith(b"debug.")):
                ctype, default = foundopts[name]
                if default:
                    if isinstance(default, bytes):
                        default = mkstr(default)
                    default = ' [%s]' % default
                elif isinstance(default, bytes):
                    default = mkstr(default)
                print("undocumented: %s (%s)%s" % (
                    mkstr(name), mkstr(ctype), default))

if __name__ == "__main__":
    if len(sys.argv) > 1:
        sys.exit(main(sys.argv[1:]))
    else:
        sys.exit(main([l.rstrip() for l in sys.stdin]))
