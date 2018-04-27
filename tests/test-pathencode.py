# This is a randomized test that generates different pathnames every
# time it is invoked, and tests the encoding of those pathnames.
#
# It uses a simple probabilistic model to generate valid pathnames
# that have proven likely to expose bugs and divergent behavior in
# different encoding implementations.

from __future__ import absolute_import, print_function

import binascii
import collections
import itertools
import math
import os
import random
import sys
import time
from mercurial import (
    pycompat,
    store,
)

try:
    xrange
except NameError:
    xrange = range

validchars = set(map(pycompat.bytechr, range(0, 256)))
alphanum = range(ord('A'), ord('Z'))

for c in (b'\0', b'/'):
    validchars.remove(c)

winreserved = (b'aux con prn nul'.split() +
               [b'com%d' % i for i in xrange(1, 10)] +
               [b'lpt%d' % i for i in xrange(1, 10)])

def casecombinations(names):
    '''Build all case-diddled combinations of names.'''

    combos = set()

    for r in names:
        for i in xrange(len(r) + 1):
            for c in itertools.combinations(xrange(len(r)), i):
                d = r
                for j in c:
                    d = b''.join((d[:j], d[j:j + 1].upper(), d[j + 1:]))
                combos.add(d)
    return sorted(combos)

def buildprobtable(fp, cmd='hg manifest tip'):
    '''Construct and print a table of probabilities for path name
    components.  The numbers are percentages.'''

    counts = collections.defaultdict(lambda: 0)
    for line in os.popen(cmd).read().splitlines():
        if line[-2:] in ('.i', '.d'):
            line = line[:-2]
        if line.startswith('data/'):
            line = line[5:]
        for c in line:
            counts[c] += 1
    for c in '\r/\n':
        counts.pop(c, None)
    t = sum(counts.itervalues()) / 100.0
    fp.write('probtable = (')
    for i, (k, v) in enumerate(sorted(counts.items(), key=lambda x: x[1],
                                      reverse=True)):
        if (i % 5) == 0:
            fp.write('\n    ')
        vt = v / t
        if vt < 0.0005:
            break
        fp.write('(%r, %.03f), ' % (k, vt))
    fp.write('\n    )\n')

# A table of character frequencies (as percentages), gleaned by
# looking at filelog names from a real-world, very large repo.

probtable = (
    (b't', 9.828), (b'e', 9.042), (b's', 8.011), (b'a', 6.801), (b'i', 6.618),
    (b'g', 5.053), (b'r', 5.030), (b'o', 4.887), (b'p', 4.363), (b'n', 4.258),
    (b'l', 3.830), (b'h', 3.693), (b'_', 3.659), (b'.', 3.377), (b'm', 3.194),
    (b'u', 2.364), (b'd', 2.296), (b'c', 2.163), (b'b', 1.739), (b'f', 1.625),
    (b'6', 0.666), (b'j', 0.610), (b'y', 0.554), (b'x', 0.487), (b'w', 0.477),
    (b'k', 0.476), (b'v', 0.473), (b'3', 0.336), (b'1', 0.335), (b'2', 0.326),
    (b'4', 0.310), (b'5', 0.305), (b'9', 0.302), (b'8', 0.300), (b'7', 0.299),
    (b'q', 0.298), (b'0', 0.250), (b'z', 0.223), (b'-', 0.118), (b'C', 0.095),
    (b'T', 0.087), (b'F', 0.085), (b'B', 0.077), (b'S', 0.076), (b'P', 0.076),
    (b'L', 0.059), (b'A', 0.058), (b'N', 0.051), (b'D', 0.049), (b'M', 0.046),
    (b'E', 0.039), (b'I', 0.035), (b'R', 0.035), (b'G', 0.028), (b'U', 0.026),
    (b'W', 0.025), (b'O', 0.017), (b'V', 0.015), (b'H', 0.013), (b'Q', 0.011),
    (b'J', 0.007), (b'K', 0.005), (b'+', 0.004), (b'X', 0.003), (b'Y', 0.001),
    )

for c, _ in probtable:
    validchars.remove(c)
validchars = list(validchars)

def pickfrom(rng, table):
    c = 0
    r = rng.random() * sum(i[1] for i in table)
    for i, p in table:
        c += p
        if c >= r:
            return i

reservedcombos = casecombinations(winreserved)

# The first component of a name following a slash.

firsttable = (
    (lambda rng: pickfrom(rng, probtable), 90),
    (lambda rng: rng.choice(validchars), 5),
    (lambda rng: rng.choice(reservedcombos), 5),
    )

# Components of a name following the first.

resttable = firsttable[:-1]

# Special suffixes.

internalsuffixcombos = casecombinations(b'.hg .i .d'.split())

# The last component of a path, before a slash or at the end of a name.

lasttable = resttable + (
    (lambda rng: b'', 95),
    (lambda rng: rng.choice(internalsuffixcombos), 5),
    )

def makepart(rng, k):
    '''Construct a part of a pathname, without slashes.'''

    p = pickfrom(rng, firsttable)(rng)
    l = len(p)
    ps = [p]
    maxl = rng.randint(1, k)
    while l < maxl:
        p = pickfrom(rng, resttable)(rng)
        l += len(p)
        ps.append(p)
    ps.append(pickfrom(rng, lasttable)(rng))
    return b''.join(ps)

def makepath(rng, j, k):
    '''Construct a complete pathname.'''

    return (b'data/' + b'/'.join(makepart(rng, k) for _ in xrange(j)) +
            rng.choice([b'.d', b'.i']))

def genpath(rng, count):
    '''Generate random pathnames with gradually increasing lengths.'''

    mink, maxk = 1, 4096
    def steps():
        for i in xrange(count):
            yield mink + int(round(math.sqrt((maxk - mink) * float(i) / count)))
    for k in steps():
        x = rng.randint(1, k)
        y = rng.randint(1, k)
        yield makepath(rng, x, y)

def runtests(rng, seed, count):
    nerrs = 0
    for p in genpath(rng, count):
        h = store._pathencode(p)    # uses C implementation, if available
        r = store._hybridencode(p, True) # reference implementation in Python
        if h != r:
            if nerrs == 0:
                print('seed:', hex(seed)[:-1], file=sys.stderr)
            print("\np: '%s'" % p.encode("string_escape"), file=sys.stderr)
            print("h: '%s'" % h.encode("string_escape"), file=sys.stderr)
            print("r: '%s'" % r.encode("string_escape"), file=sys.stderr)
            nerrs += 1
    return nerrs

def main():
    import getopt

    # Empirically observed to take about a second to run
    count = 100
    seed = None
    opts, args = getopt.getopt(sys.argv[1:], 'c:s:',
                               ['build', 'count=', 'seed='])
    for o, a in opts:
        if o in ('-c', '--count'):
            count = int(a)
        elif o in ('-s', '--seed'):
            seed = int(a, base=0) # accepts base 10 or 16 strings
        elif o == '--build':
            buildprobtable(sys.stdout,
                           'find .hg/store/data -type f && '
                           'cat .hg/store/fncache 2>/dev/null')
            sys.exit(0)

    if seed is None:
        try:
            seed = int(binascii.hexlify(os.urandom(16)), 16)
        except AttributeError:
            seed = int(time.time() * 1000)

    rng = random.Random(seed)
    if runtests(rng, seed, count):
        sys.exit(1)

if __name__ == '__main__':
    main()
