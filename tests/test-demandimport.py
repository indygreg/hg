from __future__ import absolute_import, print_function

from mercurial import demandimport
demandimport.enable()

import os
import subprocess
import sys

# Only run if demandimport is allowed
if subprocess.call(['python', '%s/hghave' % os.environ['TESTDIR'],
                    'demandimport']):
    sys.exit(80)

if os.name != 'nt':
    try:
        import distutils.msvc9compiler
        print('distutils.msvc9compiler needs to be an immediate '
              'importerror on non-windows platforms')
        distutils.msvc9compiler
    except ImportError:
        pass

import re

rsub = re.sub
def f(obj):
    l = repr(obj)
    l = rsub("0x[0-9a-fA-F]+", "0x?", l)
    l = rsub("from '.*'", "from '?'", l)
    l = rsub("'<[a-z]*>'", "'<whatever>'", l)
    return l

demandimport.disable()
os.environ['HGDEMANDIMPORT'] = 'disable'
# this enable call should not actually enable demandimport!
demandimport.enable()
from mercurial import node
print("node =", f(node))
# now enable it for real
del os.environ['HGDEMANDIMPORT']
demandimport.enable()

# Test access to special attributes through demandmod proxy
from mercurial import error as errorproxy
print("errorproxy =", f(errorproxy))
print("errorproxy.__doc__ = %r"
      % (' '.join(errorproxy.__doc__.split()[:3]) + ' ...'))
print("errorproxy.__name__ = %r" % errorproxy.__name__)
# __name__ must be accessible via __dict__ so the relative imports can be
# resolved
print("errorproxy.__dict__['__name__'] = %r" % errorproxy.__dict__['__name__'])
print("errorproxy =", f(errorproxy))

import os

print("os =", f(os))
print("os.system =", f(os.system))
print("os =", f(os))

from mercurial.utils import procutil

print("procutil =", f(procutil))
print("procutil.system =", f(procutil.system))
print("procutil =", f(procutil))
print("procutil.system =", f(procutil.system))

from mercurial import hgweb
print("hgweb =", f(hgweb))
print("hgweb_mod =", f(hgweb.hgweb_mod))
print("hgweb =", f(hgweb))

import re as fred
print("fred =", f(fred))

import re as remod
print("remod =", f(remod))

import sys as re
print("re =", f(re))

print("fred =", f(fred))
print("fred.sub =", f(fred.sub))
print("fred =", f(fred))

remod.escape  # use remod
print("remod =", f(remod))

print("re =", f(re))
print("re.stderr =", f(re.stderr))
print("re =", f(re))

import contextlib
print("contextlib =", f(contextlib))
try:
    from contextlib import unknownattr
    print('no demandmod should be created for attribute of non-package '
          'module:\ncontextlib.unknownattr =', f(unknownattr))
except ImportError as inst:
    print('contextlib.unknownattr = ImportError: %s'
          % rsub(r"'", '', str(inst)))

from mercurial import util

# Unlike the import statement, __import__() function should not raise
# ImportError even if fromlist has an unknown item
# (see Python/import.c:import_module_level() and ensure_fromlist())
contextlibimp = __import__('contextlib', globals(), locals(), ['unknownattr'])
print("__import__('contextlib', ..., ['unknownattr']) =", f(contextlibimp))
print("hasattr(contextlibimp, 'unknownattr') =",
      util.safehasattr(contextlibimp, 'unknownattr'))
