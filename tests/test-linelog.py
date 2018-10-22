from __future__ import absolute_import, print_function

import difflib
import random
import unittest

from mercurial import linelog

vecratio = 3 # number of replacelines / number of replacelines_vec
maxlinenum = 0xffffff
maxb1 = 0xffffff
maxdeltaa = 10
maxdeltab = 10

def _genedits(seed, endrev):
    lines = []
    random.seed(seed)
    rev = 0
    for rev in range(0, endrev):
        n = len(lines)
        a1 = random.randint(0, n)
        a2 = random.randint(a1, min(n, a1 + maxdeltaa))
        b1 = random.randint(0, maxb1)
        b2 = random.randint(b1, b1 + maxdeltab)
        usevec = not bool(random.randint(0, vecratio))
        if usevec:
            blines = [(random.randint(0, rev), random.randint(0, maxlinenum))
                      for _ in range(b1, b2)]
        else:
            blines = [(rev, bidx) for bidx in range(b1, b2)]
        lines[a1:a2] = blines
        yield lines, rev, a1, a2, b1, b2, blines, usevec

class linelogtests(unittest.TestCase):
    def testlinelogencodedecode(self):
        program = [linelog._eof(0, 0),
                   linelog._jge(41, 42),
                   linelog._jump(0, 43),
                   linelog._eof(0, 0),
                   linelog._jl(44, 45),
                   linelog._line(46, 47),
                   ]
        ll = linelog.linelog(program, maxrev=100)
        enc = ll.encode()
        # round-trips okay
        self.assertEqual(linelog.linelog.fromdata(enc)._program, ll._program)
        self.assertEqual(linelog.linelog.fromdata(enc), ll)
        # This encoding matches the encoding used by hg-experimental's
        # linelog file, or is supposed to if it doesn't.
        self.assertEqual(enc, (b'\x00\x00\x01\x90\x00\x00\x00\x06'
                               b'\x00\x00\x00\xa4\x00\x00\x00*'
                               b'\x00\x00\x00\x00\x00\x00\x00+'
                               b'\x00\x00\x00\x00\x00\x00\x00\x00'
                               b'\x00\x00\x00\xb1\x00\x00\x00-'
                               b'\x00\x00\x00\xba\x00\x00\x00/'))

    def testsimpleedits(self):
        ll = linelog.linelog()
        # Initial revision: add lines 0, 1, and 2
        ll.replacelines(1, 0, 0, 0, 3)
        self.assertEqual([(l.rev, l.linenum) for l in ll.annotate(1)],
                         [(1, 0),
                          (1, 1),
                          (1, 2),
                         ])
        # Replace line 1 with a new line
        ll.replacelines(2, 1, 2, 1, 2)
        self.assertEqual([(l.rev, l.linenum) for l in ll.annotate(2)],
                         [(1, 0),
                          (2, 1),
                          (1, 2),
                         ])
        # delete a line out of 2
        ll.replacelines(3, 1, 2, 0, 0)
        self.assertEqual([(l.rev, l.linenum) for l in ll.annotate(3)],
                         [(1, 0),
                          (1, 2),
                         ])
        # annotation of 1 is unchanged
        self.assertEqual([(l.rev, l.linenum) for l in ll.annotate(1)],
                         [(1, 0),
                          (1, 1),
                          (1, 2),
                         ])
        ll.annotate(3) # set internal state to revision 3
        start = ll.getoffset(0)
        end = ll.getoffset(1)
        self.assertEqual(ll.getalllines(start, end), [
            (1, 0),
            (2, 1),
            (1, 1),
        ])
        self.assertEqual(ll.getalllines(), [
            (1, 0),
            (2, 1),
            (1, 1),
            (1, 2),
        ])

    def testparseclinelogfile(self):
        # This data is what the replacements in testsimpleedits
        # produce when fed to the original linelog.c implementation.
        data = (b'\x00\x00\x00\x0c\x00\x00\x00\x0f'
                b'\x00\x00\x00\x00\x00\x00\x00\x02'
                b'\x00\x00\x00\x05\x00\x00\x00\x06'
                b'\x00\x00\x00\x06\x00\x00\x00\x00'
                b'\x00\x00\x00\x00\x00\x00\x00\x07'
                b'\x00\x00\x00\x06\x00\x00\x00\x02'
                b'\x00\x00\x00\x00\x00\x00\x00\x00'
                b'\x00\x00\x00\t\x00\x00\x00\t'
                b'\x00\x00\x00\x00\x00\x00\x00\x0c'
                b'\x00\x00\x00\x08\x00\x00\x00\x05'
                b'\x00\x00\x00\x06\x00\x00\x00\x01'
                b'\x00\x00\x00\x00\x00\x00\x00\x05'
                b'\x00\x00\x00\x0c\x00\x00\x00\x05'
                b'\x00\x00\x00\n\x00\x00\x00\x01'
                b'\x00\x00\x00\x00\x00\x00\x00\t')
        llc = linelog.linelog.fromdata(data)
        self.assertEqual([(l.rev, l.linenum) for l in llc.annotate(1)],
                         [(1, 0),
                          (1, 1),
                          (1, 2),
                         ])
        self.assertEqual([(l.rev, l.linenum) for l in llc.annotate(2)],
                         [(1, 0),
                          (2, 1),
                          (1, 2),
                         ])
        self.assertEqual([(l.rev, l.linenum) for l in llc.annotate(3)],
                         [(1, 0),
                          (1, 2),
                         ])
        # Check we emit the same bytecode.
        ll = linelog.linelog()
        # Initial revision: add lines 0, 1, and 2
        ll.replacelines(1, 0, 0, 0, 3)
        # Replace line 1 with a new line
        ll.replacelines(2, 1, 2, 1, 2)
        # delete a line out of 2
        ll.replacelines(3, 1, 2, 0, 0)
        diff = '\n   ' + '\n   '.join(difflib.unified_diff(
            ll.debugstr().splitlines(), llc.debugstr().splitlines(),
            'python', 'c', lineterm=''))
        self.assertEqual(ll._program, llc._program, 'Program mismatch: ' + diff)
        # Done as a secondary step so we get a better result if the
        # program is where the mismatch is.
        self.assertEqual(ll, llc)
        self.assertEqual(ll.encode(), data)

    def testanothersimplecase(self):
        ll = linelog.linelog()
        ll.replacelines(3, 0, 0, 0, 2)
        ll.replacelines(4, 0, 2, 0, 0)
        self.assertEqual([(l.rev, l.linenum) for l in ll.annotate(4)],
                         [])
        self.assertEqual([(l.rev, l.linenum) for l in ll.annotate(3)],
                         [(3, 0), (3, 1)])
        # rev 2 is empty because contents were only ever introduced in rev 3
        self.assertEqual([(l.rev, l.linenum) for l in ll.annotate(2)],
                         [])

    def testrandomedits(self):
        # Inspired by original linelog tests.
        seed = random.random()
        numrevs = 2000
        ll = linelog.linelog()
        # Populate linelog
        for lines, rev, a1, a2, b1, b2, blines, usevec in _genedits(
                seed, numrevs):
            if usevec:
                ll.replacelines_vec(rev, a1, a2, blines)
            else:
                ll.replacelines(rev, a1, a2, b1, b2)
            ar = ll.annotate(rev)
            self.assertEqual(ll.annotateresult, lines)
        # Verify we can get back these states by annotating each rev
        for lines, rev, a1, a2, b1, b2, blines, usevec in _genedits(
                seed, numrevs):
            ar = ll.annotate(rev)
            self.assertEqual([(l.rev, l.linenum) for l in ar], lines)

    def testinfinitebadprogram(self):
        ll = linelog.linelog.fromdata(
            b'\x00\x00\x00\x00\x00\x00\x00\x02'  # header
            b'\x00\x00\x00\x00\x00\x00\x00\x01'  # JUMP to self
        )
        with self.assertRaises(linelog.LineLogError):
            # should not be an infinite loop and raise
            ll.annotate(1)

if __name__ == '__main__':
    import silenttestrunner
    silenttestrunner.main(__name__)
