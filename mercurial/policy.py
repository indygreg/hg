# policy.py - module policy logic for Mercurial.
#
# Copyright 2015 Gregory Szorc <gregory.szorc@gmail.com>
#
# This software may be used and distributed according to the terms of the
# GNU General Public License version 2 or any later version.

from __future__ import absolute_import

import os
import sys

# Rules for how modules can be loaded. Values are:
#
#    c - require C extensions
#    allow - allow pure Python implementation when C loading fails
#    cffi - required cffi versions (implemented within pure module)
#    cffi-allow - allow pure Python implementation if cffi version is missing
#    py - only load pure Python modules
#
# By default, fall back to the pure modules so the in-place build can
# run without recompiling the C extensions. This will be overridden by
# __modulepolicy__ generated by setup.py.
policy = b'allow'
policynoc = (b'cffi', b'cffi-allow', b'py')
policynocffi = (b'c', b'py')
_packageprefs = {
    # policy: (versioned package, pure package)
    b'c': (r'cext', None),
    b'allow': (r'cext', r'pure'),
    b'cffi': (None, r'pure'),  # TODO: (r'cffi', None)
    b'cffi-allow': (None, r'pure'),  # TODO: (r'cffi', r'pure')
    b'py': (None, r'pure'),
}

try:
    from . import __modulepolicy__
    policy = __modulepolicy__.modulepolicy
except ImportError:
    pass

# PyPy doesn't load C extensions.
#
# The canonical way to do this is to test platform.python_implementation().
# But we don't import platform and don't bloat for it here.
if r'__pypy__' in sys.builtin_module_names:
    policy = b'cffi'

# Our C extensions aren't yet compatible with Python 3. So use pure Python
# on Python 3 for now.
if sys.version_info[0] >= 3:
    policy = b'py'

# Environment variable can always force settings.
if sys.version_info[0] >= 3:
    if r'HGMODULEPOLICY' in os.environ:
        policy = os.environ[r'HGMODULEPOLICY'].encode(r'utf-8')
else:
    policy = os.environ.get(r'HGMODULEPOLICY', policy)

def _importfrom(pkgname, modname):
    # from .<pkgname> import <modname> (where . is looked through this module)
    fakelocals = {}
    pkg = __import__(pkgname, globals(), fakelocals, [modname], level=1)
    try:
        fakelocals[modname] = mod = getattr(pkg, modname)
    except AttributeError:
        raise ImportError(r'cannot import name %s' % modname)
    # force import; fakelocals[modname] may be replaced with the real module
    getattr(mod, r'__doc__', None)
    return fakelocals[modname]

def _checkmod(pkgname, modname, mod):
    expected = 1  # TODO: maybe defined in table?
    actual = getattr(mod, r'version', None)
    if actual != expected:
        raise ImportError(r'cannot import module %s.%s '
                          r'(expected version: %d, actual: %r)'
                          % (pkgname, modname, expected, actual))

def importmod(modname):
    """Import module according to policy and check API version"""
    try:
        verpkg, purepkg = _packageprefs[policy]
    except KeyError:
        raise ImportError(r'invalid HGMODULEPOLICY %r' % policy)
    assert verpkg or purepkg
    if verpkg:
        try:
            mod = _importfrom(verpkg, modname)
            _checkmod(verpkg, modname, mod)
            return mod
        except ImportError:
            if not purepkg:
                raise
    return _importfrom(purepkg, modname)
