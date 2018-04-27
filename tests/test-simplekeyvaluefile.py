from __future__ import absolute_import

import unittest
import silenttestrunner

from mercurial import (
    error,
    scmutil,
)

class mockfile(object):
    def __init__(self, name, fs):
        self.name = name
        self.fs = fs

    def __enter__(self):
        return self

    def __exit__(self, *args, **kwargs):
        pass

    def write(self, text):
        self.fs.contents[self.name] = text

    def read(self):
        return self.fs.contents[self.name]

class mockvfs(object):
    def __init__(self):
        self.contents = {}

    def read(self, path):
        return mockfile(path, self).read()

    def readlines(self, path):
        # lines need to contain the trailing '\n' to mock the real readlines
        return [l for l in mockfile(path, self).read().splitlines(True)]

    def __call__(self, path, mode, atomictemp):
        return mockfile(path, self)

class testsimplekeyvaluefile(unittest.TestCase):
    def setUp(self):
        self.vfs = mockvfs()

    def testbasicwritingiandreading(self):
        dw = {b'key1': b'value1', b'Key2': b'value2'}
        scmutil.simplekeyvaluefile(self.vfs, b'kvfile').write(dw)
        self.assertEqual(sorted(self.vfs.read(b'kvfile').split(b'\n')),
                         [b'', b'Key2=value2', b'key1=value1'])
        dr = scmutil.simplekeyvaluefile(self.vfs, b'kvfile').read()
        self.assertEqual(dr, dw)

    if not getattr(unittest.TestCase, 'assertRaisesRegex', False):
        # Python 3.7 deprecates the regex*p* version, but 2.7 lacks
        # the regex version.
        assertRaisesRegex = (# camelcase-required
            unittest.TestCase.assertRaisesRegexp)

    def testinvalidkeys(self):
        d = {b'0key1': b'value1', b'Key2': b'value2'}
        with self.assertRaisesRegex(error.ProgrammingError,
                                     'keys must start with a letter.*'):
            scmutil.simplekeyvaluefile(self.vfs, b'kvfile').write(d)

        d = {b'key1@': b'value1', b'Key2': b'value2'}
        with self.assertRaisesRegex(error.ProgrammingError, 'invalid key.*'):
            scmutil.simplekeyvaluefile(self.vfs, b'kvfile').write(d)

    def testinvalidvalues(self):
        d = {b'key1': b'value1', b'Key2': b'value2\n'}
        with self.assertRaisesRegex(error.ProgrammingError,  'invalid val.*'):
            scmutil.simplekeyvaluefile(self.vfs, b'kvfile').write(d)

    def testcorruptedfile(self):
        self.vfs.contents[b'badfile'] = b'ababagalamaga\n'
        with self.assertRaisesRegex(error.CorruptedState,
                                     'dictionary.*element.*'):
            scmutil.simplekeyvaluefile(self.vfs, b'badfile').read()

    def testfirstline(self):
        dw = {b'key1': b'value1'}
        scmutil.simplekeyvaluefile(self.vfs, b'fl').write(dw, firstline=b'1.0')
        self.assertEqual(self.vfs.read(b'fl'), b'1.0\nkey1=value1\n')
        dr = scmutil.simplekeyvaluefile(self.vfs, b'fl')\
                    .read(firstlinenonkeyval=True)
        self.assertEqual(dr, {b'__firstline': b'1.0', b'key1': b'value1'})

if __name__ == "__main__":
    silenttestrunner.main(__name__)
