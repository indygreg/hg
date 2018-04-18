# narrowspec.py - methods for working with a narrow view of a repository
#
# Copyright 2017 Google, Inc.
#
# This software may be used and distributed according to the terms of the
# GNU General Public License version 2 or any later version.

from __future__ import absolute_import

import errno

from .i18n import _
from . import (
    error,
    match as matchmod,
    util,
)

FILENAME = 'narrowspec'

def _parsestoredpatterns(text):
    """Parses the narrowspec format that's stored on disk."""
    patlist = None
    includepats = []
    excludepats = []
    for l in text.splitlines():
        if l == '[includes]':
            if patlist is None:
                patlist = includepats
            else:
                raise error.Abort(_('narrowspec includes section must appear '
                                    'at most once, before excludes'))
        elif l == '[excludes]':
            if patlist is not excludepats:
                patlist = excludepats
            else:
                raise error.Abort(_('narrowspec excludes section must appear '
                                    'at most once'))
        else:
            patlist.append(l)

    return set(includepats), set(excludepats)

def parseserverpatterns(text):
    """Parses the narrowspec format that's returned by the server."""
    includepats = set()
    excludepats = set()

    # We get one entry per line, in the format "<key> <value>".
    # It's OK for value to contain other spaces.
    for kp in (l.split(' ', 1) for l in text.splitlines()):
        if len(kp) != 2:
            raise error.Abort(_('Invalid narrowspec pattern line: "%s"') % kp)
        key = kp[0]
        pat = kp[1]
        if key == 'include':
            includepats.add(pat)
        elif key == 'exclude':
            excludepats.add(pat)
        else:
            raise error.Abort(_('Invalid key "%s" in server response') % key)

    return includepats, excludepats

def normalizesplitpattern(kind, pat):
    """Returns the normalized version of a pattern and kind.

    Returns a tuple with the normalized kind and normalized pattern.
    """
    pat = pat.rstrip('/')
    _validatepattern(pat)
    return kind, pat

def _numlines(s):
    """Returns the number of lines in s, including ending empty lines."""
    # We use splitlines because it is Unicode-friendly and thus Python 3
    # compatible. However, it does not count empty lines at the end, so trick
    # it by adding a character at the end.
    return len((s + 'x').splitlines())

def _validatepattern(pat):
    """Validates the pattern and aborts if it is invalid.

    Patterns are stored in the narrowspec as newline-separated
    POSIX-style bytestring paths. There's no escaping.
    """

    # We use newlines as separators in the narrowspec file, so don't allow them
    # in patterns.
    if _numlines(pat) > 1:
        raise error.Abort(_('newlines are not allowed in narrowspec paths'))

    components = pat.split('/')
    if '.' in components or '..' in components:
        raise error.Abort(_('"." and ".." are not allowed in narrowspec paths'))

def normalizepattern(pattern, defaultkind='path'):
    """Returns the normalized version of a text-format pattern.

    If the pattern has no kind, the default will be added.
    """
    kind, pat = matchmod._patsplit(pattern, defaultkind)
    return '%s:%s' % normalizesplitpattern(kind, pat)

def parsepatterns(pats):
    """Parses a list of patterns into a typed pattern set."""
    return set(normalizepattern(p) for p in pats)

def format(includes, excludes):
    output = '[includes]\n'
    for i in sorted(includes - excludes):
        output += i + '\n'
    output += '[excludes]\n'
    for e in sorted(excludes):
        output += e + '\n'
    return output

def match(root, include=None, exclude=None):
    if not include:
        # Passing empty include and empty exclude to matchmod.match()
        # gives a matcher that matches everything, so explicitly use
        # the nevermatcher.
        return matchmod.never(root, '')
    return matchmod.match(root, '', [], include=include or [],
                          exclude=exclude or [])

def needsexpansion(includes):
    return [i for i in includes if i.startswith('include:')]

def load(repo):
    try:
        spec = repo.vfs.read(FILENAME)
    except IOError as e:
        # Treat "narrowspec does not exist" the same as "narrowspec file exists
        # and is empty".
        if e.errno == errno.ENOENT:
            # Without this the next call to load will use the cached
            # non-existence of the file, which can cause some odd issues.
            repo.invalidate(clearfilecache=True)
            return set(), set()
        raise
    return _parsestoredpatterns(spec)

def save(repo, includepats, excludepats):
    spec = format(includepats, excludepats)
    repo.vfs.write(FILENAME, spec)

def restrictpatterns(req_includes, req_excludes, repo_includes, repo_excludes):
    r""" Restricts the patterns according to repo settings,
    results in a logical AND operation

    :param req_includes: requested includes
    :param req_excludes: requested excludes
    :param repo_includes: repo includes
    :param repo_excludes: repo excludes
    :return: include patterns, exclude patterns, and invalid include patterns.

    >>> restrictpatterns({'f1','f2'}, {}, ['f1'], [])
    (set(['f1']), {}, [])
    >>> restrictpatterns({'f1'}, {}, ['f1','f2'], [])
    (set(['f1']), {}, [])
    >>> restrictpatterns({'f1/fc1', 'f3/fc3'}, {}, ['f1','f2'], [])
    (set(['f1/fc1']), {}, [])
    >>> restrictpatterns({'f1_fc1'}, {}, ['f1','f2'], [])
    ([], set(['path:.']), [])
    >>> restrictpatterns({'f1/../f2/fc2'}, {}, ['f1','f2'], [])
    (set(['f2/fc2']), {}, [])
    >>> restrictpatterns({'f1/../f3/fc3'}, {}, ['f1','f2'], [])
    ([], set(['path:.']), [])
    >>> restrictpatterns({'f1/$non_exitent_var'}, {}, ['f1','f2'], [])
    (set(['f1/$non_exitent_var']), {}, [])
    """
    res_excludes = set(req_excludes)
    res_excludes.update(repo_excludes)
    invalid_includes = []
    if not req_includes:
        res_includes = set(repo_includes)
    elif 'path:.' not in repo_includes:
        res_includes = []
        for req_include in req_includes:
            req_include = util.expandpath(util.normpath(req_include))
            if req_include in repo_includes:
                res_includes.append(req_include)
                continue
            valid = False
            for repo_include in repo_includes:
                if req_include.startswith(repo_include + '/'):
                    valid = True
                    res_includes.append(req_include)
                    break
            if not valid:
                invalid_includes.append(req_include)
        if len(res_includes) == 0:
            res_excludes = {'path:.'}
        else:
            res_includes = set(res_includes)
    else:
        res_includes = set(req_includes)
    return res_includes, res_excludes, invalid_includes
