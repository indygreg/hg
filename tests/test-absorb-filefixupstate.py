from __future__ import absolute_import, print_function

import itertools
from mercurial import pycompat
from hgext import absorb

class simplefctx(object):
    def __init__(self, content):
        self.content = content

    def data(self):
        return self.content

def insertreturns(x):
    # insert "\n"s after each single char
    if isinstance(x, bytes):
        return b''.join(ch + b'\n' for ch in pycompat.bytestr(x))
    else:
        return pycompat.maplist(insertreturns, x)

def removereturns(x):
    # the revert of "insertreturns"
    if isinstance(x, bytes):
        return x.replace(b'\n', b'')
    else:
        return pycompat.maplist(removereturns, x)

def assertlistequal(lhs, rhs, decorator=lambda x: x):
    if lhs != rhs:
        raise RuntimeError('mismatch:\n actual:   %r\n expected: %r'
                           % tuple(map(decorator, [lhs, rhs])))

def testfilefixup(oldcontents, workingcopy, expectedcontents, fixups=None):
    """([str], str, [str], [(rev, a1, a2, b1, b2)]?) -> None

    workingcopy is a string, of which every character denotes a single line.

    oldcontents, expectedcontents are lists of strings, every character of
    every string denots a single line.

    if fixups is not None, it's the expected fixups list and will be checked.
    """
    expectedcontents = insertreturns(expectedcontents)
    oldcontents = insertreturns(oldcontents)
    workingcopy = insertreturns(workingcopy)
    state = absorb.filefixupstate(pycompat.maplist(simplefctx, oldcontents),
                                  'path')
    state.diffwith(simplefctx(workingcopy))
    if fixups is not None:
        assertlistequal(state.fixups, fixups)
    state.apply()
    assertlistequal(state.finalcontents, expectedcontents, removereturns)

def buildcontents(linesrevs):
    # linesrevs: [(linecontent : str, revs : [int])]
    revs = set(itertools.chain(*[revs for line, revs in linesrevs]))
    return [b''] + [
        b''.join([l for l, rs in linesrevs if r in rs])
        for r in sorted(revs)
    ]

# input case 0: one single commit
case0 = [b'', b'11']

# replace a single chunk
testfilefixup(case0, b'', [b'', b''])
testfilefixup(case0, b'2', [b'', b'2'])
testfilefixup(case0, b'22', [b'', b'22'])
testfilefixup(case0, b'222', [b'', b'222'])

# input case 1: 3 lines, each commit adds one line
case1 = buildcontents([
    (b'1', [1, 2, 3]),
    (b'2', [   2, 3]),
    (b'3', [      3]),
])

# 1:1 line mapping
testfilefixup(case1, b'123', case1)
testfilefixup(case1, b'12c', [b'', b'1', b'12', b'12c'])
testfilefixup(case1, b'1b3', [b'', b'1', b'1b', b'1b3'])
testfilefixup(case1, b'1bc', [b'', b'1', b'1b', b'1bc'])
testfilefixup(case1, b'a23', [b'', b'a', b'a2', b'a23'])
testfilefixup(case1, b'a2c', [b'', b'a', b'a2', b'a2c'])
testfilefixup(case1, b'ab3', [b'', b'a', b'ab', b'ab3'])
testfilefixup(case1, b'abc', [b'', b'a', b'ab', b'abc'])

# non 1:1 edits
testfilefixup(case1, b'abcd', case1)
testfilefixup(case1, b'ab', case1)

# deletion
testfilefixup(case1, b'',   [b'', b'', b'', b''])
testfilefixup(case1, b'1',  [b'', b'1', b'1', b'1'])
testfilefixup(case1, b'2',  [b'', b'', b'2', b'2'])
testfilefixup(case1, b'3',  [b'', b'', b'', b'3'])
testfilefixup(case1, b'13', [b'', b'1', b'1', b'13'])

# replaces
testfilefixup(case1, b'1bb3', [b'', b'1', b'1bb', b'1bb3'])

# (confusing) replaces
testfilefixup(case1, b'1bbb', case1)
testfilefixup(case1, b'bbbb', case1)
testfilefixup(case1, b'bbb3', case1)
testfilefixup(case1, b'1b', case1)
testfilefixup(case1, b'bb', case1)
testfilefixup(case1, b'b3', case1)

# insertions at the beginning and the end
testfilefixup(case1, b'123c', [b'', b'1', b'12', b'123c'])
testfilefixup(case1, b'a123', [b'', b'a1', b'a12', b'a123'])

# (confusing) insertions
testfilefixup(case1, b'1a23', case1)
testfilefixup(case1, b'12b3', case1)

# input case 2: delete in the middle
case2 = buildcontents([
    (b'11', [1, 2]),
    (b'22', [1   ]),
    (b'33', [1, 2]),
])

# deletion (optimize code should make it 2 chunks)
testfilefixup(case2, b'', [b'', b'22', b''],
              fixups=[(4, 0, 2, 0, 0), (4, 2, 4, 0, 0)])

# 1:1 line mapping
testfilefixup(case2, b'aaaa', [b'', b'aa22aa', b'aaaa'])

# non 1:1 edits
# note: unlike case0, the chunk is not "continuous" and no edit allowed
testfilefixup(case2, b'aaa', case2)

# input case 3: rev 3 reverts rev 2
case3 = buildcontents([
    (b'1', [1, 2, 3]),
    (b'2', [   2   ]),
    (b'3', [1, 2, 3]),
])

# 1:1 line mapping
testfilefixup(case3, b'13', case3)
testfilefixup(case3, b'1b', [b'', b'1b', b'12b', b'1b'])
testfilefixup(case3, b'a3', [b'', b'a3', b'a23', b'a3'])
testfilefixup(case3, b'ab', [b'', b'ab', b'a2b', b'ab'])

# non 1:1 edits
testfilefixup(case3, b'a', case3)
testfilefixup(case3, b'abc', case3)

# deletion
testfilefixup(case3, b'', [b'', b'', b'2', b''])

# insertion
testfilefixup(case3, b'a13c', [b'', b'a13c', b'a123c', b'a13c'])

# input case 4: a slightly complex case
case4 = buildcontents([
    (b'1', [1, 2, 3]),
    (b'2', [   2, 3]),
    (b'3', [1, 2,  ]),
    (b'4', [1,    3]),
    (b'5', [      3]),
    (b'6', [   2, 3]),
    (b'7', [   2   ]),
    (b'8', [   2, 3]),
    (b'9', [      3]),
])

testfilefixup(case4, b'1245689', case4)
testfilefixup(case4, b'1a2456bbb', case4)
testfilefixup(case4, b'1abc5689', case4)
testfilefixup(case4, b'1ab5689', [b'', b'134', b'1a3678', b'1ab5689'])
testfilefixup(case4, b'aa2bcd8ee', [b'', b'aa34', b'aa23d78', b'aa2bcd8ee'])
testfilefixup(case4, b'aa2bcdd8ee',[b'', b'aa34', b'aa23678', b'aa24568ee'])
testfilefixup(case4, b'aaaaaa', case4)
testfilefixup(case4, b'aa258b', [b'', b'aa34', b'aa2378', b'aa258b'])
testfilefixup(case4, b'25bb', [b'', b'34', b'23678', b'25689'])
testfilefixup(case4, b'27', [b'', b'34', b'23678', b'245689'])
testfilefixup(case4, b'28', [b'', b'34', b'2378', b'28'])
testfilefixup(case4, b'', [b'', b'34', b'37', b''])

# input case 5: replace a small chunk which is near a deleted line
case5 = buildcontents([
    (b'12', [1, 2]),
    (b'3',  [1]),
    (b'4',  [1, 2]),
])

testfilefixup(case5, b'1cd4', [b'', b'1cd34', b'1cd4'])

# input case 6: base "changeset" is immutable
case6 = [b'1357', b'0125678']

testfilefixup(case6, b'0125678', case6)
testfilefixup(case6, b'0a25678', case6)
testfilefixup(case6, b'0a256b8', case6)
testfilefixup(case6, b'abcdefg', [b'1357', b'a1c5e7g'])
testfilefixup(case6, b'abcdef', case6)
testfilefixup(case6, b'', [b'1357', b'157'])
testfilefixup(case6, b'0123456789', [b'1357', b'0123456789'])

# input case 7: change an empty file
case7 = [b'']

testfilefixup(case7, b'1', case7)
