from __future__ import absolute_import, print_function

import os
import sys

# make it runnable using python directly without run-tests.py
sys.path[0:0] = [os.path.join(os.path.dirname(__file__), '..')]

# Import something from Mercurial, so the module loader gets initialized.
from mercurial import pycompat
del pycompat  # unused for now

from hgext.lfs import pointer

def tryparse(text):
    r = {}
    try:
        r = pointer.deserialize(text)
        print('ok')
    except Exception as ex:
        print((b'%s' % ex).decode('ascii'))
    if r:
        text2 = r.serialize()
        if text2 != text:
            print('reconstructed text differs')
    return r

t = (b'version https://git-lfs.github.com/spec/v1\n'
     b'oid sha256:4d7a214614ab2935c943f9e0ff69d22eadbb8f32b1'
     b'258daaa5e2ca24d17e2393\n'
     b'size 12345\n'
     b'x-foo extra-information\n')

tryparse(b'')
tryparse(t)
tryparse(t.replace(b'git-lfs', b'unknown'))
tryparse(t.replace(b'v1\n', b'v1\n\n'))
tryparse(t.replace(b'sha256', b'ahs256'))
tryparse(t.replace(b'sha256:', b''))
tryparse(t.replace(b'12345', b'0x12345'))
tryparse(t.replace(b'extra-information', b'extra\0information'))
tryparse(t.replace(b'extra-information', b'extra\ninformation'))
tryparse(t.replace(b'x-foo', b'x_foo'))
tryparse(t.replace(b'oid', b'blobid'))
tryparse(t.replace(b'size', b'size-bytes').replace(b'oid', b'object-id'))
