from __future__ import absolute_import, print_function

import io
import unittest

import silenttestrunner

from mercurial import (
    wireproto,
    wireprotoserver,
)

from mercurial.utils import (
    procutil,
)

class SSHServerGetArgsTests(unittest.TestCase):
    def testparseknown(self):
        tests = [
            (b'* 0\nnodes 0\n', [b'', {}]),
            (b'* 0\nnodes 40\n1111111111111111111111111111111111111111\n',
             [b'1111111111111111111111111111111111111111', {}]),
        ]
        for input, expected in tests:
            self.assertparse(b'known', input, expected)

    def assertparse(self, cmd, input, expected):
        server = mockserver(input)
        proto = wireprotoserver.sshv1protocolhandler(server._ui,
                                                     server._fin,
                                                     server._fout)
        _func, spec = wireproto.commands[cmd]
        self.assertEqual(proto.getargs(spec), expected)

def mockserver(inbytes):
    ui = mockui(inbytes)
    repo = mockrepo(ui)
    return wireprotoserver.sshserver(ui, repo)

class mockrepo(object):
    def __init__(self, ui):
        self.ui = ui

class mockui(object):
    def __init__(self, inbytes):
        self.fin = io.BytesIO(inbytes)
        self.fout = io.BytesIO()
        self.ferr = io.BytesIO()

if __name__ == '__main__':
    # Don't call into msvcrt to set BytesIO to binary mode
    procutil.setbinary = lambda fp: True
    silenttestrunner.main(__name__)
