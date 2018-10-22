# testparseutil.py - utilities to parse test script for check tools
#
#  Copyright 2018 FUJIWARA Katsunori <foozy@lares.dti.ne.jp> and others
#
# This software may be used and distributed according to the terms of the
# GNU General Public License version 2 or any later version.

from __future__ import absolute_import, print_function

import abc
import re
import sys

####################
# for Python3 compatibility (almost comes from mercurial/pycompat.py)

ispy3 = (sys.version_info[0] >= 3)

def identity(a):
    return a

def _rapply(f, xs):
    if xs is None:
        # assume None means non-value of optional data
        return xs
    if isinstance(xs, (list, set, tuple)):
        return type(xs)(_rapply(f, x) for x in xs)
    if isinstance(xs, dict):
        return type(xs)((_rapply(f, k), _rapply(f, v)) for k, v in xs.items())
    return f(xs)

def rapply(f, xs):
    if f is identity:
        # fast path mainly for py2
        return xs
    return _rapply(f, xs)

if ispy3:
    import builtins

    # TODO: .buffer might not exist if std streams were replaced; we'll need
    # a silly wrapper to make a bytes stream backed by a unicode one.
    stdin = sys.stdin.buffer
    stdout = sys.stdout.buffer
    stderr = sys.stderr.buffer

    def bytestr(s):
        # tiny version of pycompat.bytestr
        return s.encode('latin1')

    def sysstr(s):
        if isinstance(s, builtins.str):
            return s
        return s.decode(u'latin-1')

    def opentext(f):
        return open(f, 'rb')
else:
    stdin = sys.stdin
    stdout = sys.stdout
    stderr = sys.stderr

    bytestr = str
    sysstr = identity

    opentext = open

def b2s(x):
    # convert BYTES elements in "x" to SYSSTR recursively
    return rapply(sysstr, x)

def writeout(data):
    # write "data" in BYTES into stdout
    stdout.write(data)

def writeerr(data):
    # write "data" in BYTES into stderr
    stderr.write(data)

####################

class embeddedmatcher(object):
    """Base class to detect embedded code fragments in *.t test script
    """
    __metaclass__ = abc.ABCMeta

    def __init__(self, desc):
        self.desc = desc

    @abc.abstractmethod
    def startsat(self, line):
        """Examine whether embedded code starts at line

        This can return arbitrary object, and it is used as 'ctx' for
        subsequent method invocations.
        """

    @abc.abstractmethod
    def endsat(self, ctx, line):
        """Examine whether embedded code ends at line"""

    @abc.abstractmethod
    def isinside(self, ctx, line):
        """Examine whether line is inside embedded code, if not yet endsat
        """

    @abc.abstractmethod
    def ignores(self, ctx):
        """Examine whether detected embedded code should be ignored"""

    @abc.abstractmethod
    def filename(self, ctx):
        """Return filename of embedded code

        If filename isn't specified for embedded code explicitly, this
        returns None.
        """

    @abc.abstractmethod
    def codeatstart(self, ctx, line):
        """Return actual code at the start line of embedded code

        This might return None, if the start line doesn't contain
        actual code.
        """

    @abc.abstractmethod
    def codeatend(self, ctx, line):
        """Return actual code at the end line of embedded code

        This might return None, if the end line doesn't contain actual
        code.
        """

    @abc.abstractmethod
    def codeinside(self, ctx, line):
        """Return actual code at line inside embedded code"""

def embedded(basefile, lines, errors, matchers):
    """pick embedded code fragments up from given lines

    This is common parsing logic, which examines specified matchers on
    given lines.

    :basefile: a name of a file, from which lines to be parsed come.
    :lines: to be parsed (might be a value returned by "open(basefile)")
    :errors: an array, into which messages for detected error are stored
    :matchers: an array of embeddedmatcher objects

    This function yields '(filename, starts, ends, code)' tuple.

    :filename: a name of embedded code, if it is explicitly specified
               (e.g.  "foobar" of "cat >> foobar <<EOF").
               Otherwise, this is None
    :starts: line number (1-origin), at which embedded code starts (inclusive)
    :ends: line number (1-origin), at which embedded code ends (exclusive)
    :code: extracted embedded code, which is single-stringified

    >>> class ambigmatcher(object):
    ...     # mock matcher class to examine implementation of
    ...     # "ambiguous matching" corner case
    ...     def __init__(self, desc, matchfunc):
    ...         self.desc = desc
    ...         self.matchfunc = matchfunc
    ...     def startsat(self, line):
    ...         return self.matchfunc(line)
    >>> ambig1 = ambigmatcher(b'ambiguous #1',
    ...                       lambda l: l.startswith(b'  $ cat '))
    >>> ambig2 = ambigmatcher(b'ambiguous #2',
    ...                       lambda l: l.endswith(b'<< EOF\\n'))
    >>> lines = [b'  $ cat > foo.py << EOF\\n']
    >>> errors = []
    >>> matchers = [ambig1, ambig2]
    >>> list(t for t in embedded(b'<dummy>', lines, errors, matchers))
    []
    >>> b2s(errors)
    ['<dummy>:1: ambiguous line for "ambiguous #1", "ambiguous #2"']

    """
    matcher = None
    ctx = filename = code = startline = None # for pyflakes

    for lineno, line in enumerate(lines, 1):
        if not line.endswith(b'\n'):
            line += b'\n' # to normalize EOF line
        if matcher: # now, inside embedded code
            if matcher.endsat(ctx, line):
                codeatend = matcher.codeatend(ctx, line)
                if codeatend is not None:
                    code.append(codeatend)
                if not matcher.ignores(ctx):
                    yield (filename, startline, lineno, b''.join(code))
                matcher = None
                # DO NOT "continue", because line might start next fragment
            elif not matcher.isinside(ctx, line):
                # this is an error of basefile
                # (if matchers are implemented correctly)
                errors.append(b'%s:%d: unexpected line for "%s"'
                              % (basefile, lineno, matcher.desc))
                # stop extracting embedded code by current 'matcher',
                # because appearance of unexpected line might mean
                # that expected end-of-embedded-code line might never
                # appear
                matcher = None
                # DO NOT "continue", because line might start next fragment
            else:
                code.append(matcher.codeinside(ctx, line))
                continue

        # examine whether current line starts embedded code or not
        assert not matcher

        matched = []
        for m in matchers:
            ctx = m.startsat(line)
            if ctx:
                matched.append((m, ctx))
        if matched:
            if len(matched) > 1:
                # this is an error of matchers, maybe
                errors.append(b'%s:%d: ambiguous line for %s' %
                              (basefile, lineno,
                               b', '.join([b'"%s"' % m.desc
                                           for m, c in matched])))
                # omit extracting embedded code, because choosing
                # arbitrary matcher from matched ones might fail to
                # detect the end of embedded code as expected.
                continue
            matcher, ctx = matched[0]
            filename = matcher.filename(ctx)
            code = []
            codeatstart = matcher.codeatstart(ctx, line)
            if codeatstart is not None:
                code.append(codeatstart)
                startline = lineno
            else:
                startline = lineno + 1

    if matcher:
        # examine whether EOF ends embedded code, because embedded
        # code isn't yet ended explicitly
        if matcher.endsat(ctx, b'\n'):
            codeatend = matcher.codeatend(ctx, b'\n')
            if codeatend is not None:
                code.append(codeatend)
            if not matcher.ignores(ctx):
                yield (filename, startline, lineno + 1, b''.join(code))
        else:
            # this is an error of basefile
            # (if matchers are implemented correctly)
            errors.append(b'%s:%d: unexpected end of file for "%s"'
                          % (basefile, lineno, matcher.desc))

# heredoc limit mark to ignore embedded code at check-code.py or so
heredocignorelimit = b'NO_CHECK_EOF'

# the pattern to match against cases below, and to return a limit mark
# string as 'lname' group
#
# - << LIMITMARK
# - << "LIMITMARK"
# - << 'LIMITMARK'
heredoclimitpat = br'\s*<<\s*(?P<lquote>["\']?)(?P<limit>\w+)(?P=lquote)'

class fileheredocmatcher(embeddedmatcher):
    """Detect "cat > FILE << LIMIT" style embedded code

    >>> matcher = fileheredocmatcher(b'heredoc .py file', br'[^<]+\.py')
    >>> b2s(matcher.startsat(b'  $ cat > file.py << EOF\\n'))
    ('file.py', '  > EOF\\n')
    >>> b2s(matcher.startsat(b'  $ cat   >>file.py   <<EOF\\n'))
    ('file.py', '  > EOF\\n')
    >>> b2s(matcher.startsat(b'  $ cat>  \\x27any file.py\\x27<<  "EOF"\\n'))
    ('any file.py', '  > EOF\\n')
    >>> b2s(matcher.startsat(b"  $ cat > file.py << 'ANYLIMIT'\\n"))
    ('file.py', '  > ANYLIMIT\\n')
    >>> b2s(matcher.startsat(b'  $ cat<<ANYLIMIT>"file.py"\\n'))
    ('file.py', '  > ANYLIMIT\\n')
    >>> start = b'  $ cat > file.py << EOF\\n'
    >>> ctx = matcher.startsat(start)
    >>> matcher.codeatstart(ctx, start)
    >>> b2s(matcher.filename(ctx))
    'file.py'
    >>> matcher.ignores(ctx)
    False
    >>> inside = b'  > foo = 1\\n'
    >>> matcher.endsat(ctx, inside)
    False
    >>> matcher.isinside(ctx, inside)
    True
    >>> b2s(matcher.codeinside(ctx, inside))
    'foo = 1\\n'
    >>> end = b'  > EOF\\n'
    >>> matcher.endsat(ctx, end)
    True
    >>> matcher.codeatend(ctx, end)
    >>> matcher.endsat(ctx, b'  > EOFEOF\\n')
    False
    >>> ctx = matcher.startsat(b'  $ cat > file.py << NO_CHECK_EOF\\n')
    >>> matcher.ignores(ctx)
    True
    """
    _prefix = b'  > '

    def __init__(self, desc, namepat):
        super(fileheredocmatcher, self).__init__(desc)

        # build the pattern to match against cases below (and ">>"
        # variants), and to return a target filename string as 'name'
        # group
        #
        # - > NAMEPAT
        # - > "NAMEPAT"
        # - > 'NAMEPAT'
        namepat = (br'\s*>>?\s*(?P<nquote>["\']?)(?P<name>%s)(?P=nquote)'
                   % namepat)
        self._fileres = [
            # "cat > NAME << LIMIT" case
            re.compile(br'  \$ \s*cat' + namepat + heredoclimitpat),
            # "cat << LIMIT > NAME" case
            re.compile(br'  \$ \s*cat' + heredoclimitpat + namepat),
        ]

    def startsat(self, line):
        # ctx is (filename, END-LINE-OF-EMBEDDED-CODE) tuple
        for filere in self._fileres:
            matched = filere.match(line)
            if matched:
                return (matched.group('name'),
                        b'  > %s\n' % matched.group('limit'))

    def endsat(self, ctx, line):
        return ctx[1] == line

    def isinside(self, ctx, line):
        return line.startswith(self._prefix)

    def ignores(self, ctx):
        return b'  > %s\n' % heredocignorelimit == ctx[1]

    def filename(self, ctx):
        return ctx[0]

    def codeatstart(self, ctx, line):
        return None # no embedded code at start line

    def codeatend(self, ctx, line):
        return None # no embedded code at end line

    def codeinside(self, ctx, line):
        return line[len(self._prefix):] # strip prefix

####
# for embedded python script

class pydoctestmatcher(embeddedmatcher):
    """Detect ">>> code" style embedded python code

    >>> matcher = pydoctestmatcher()
    >>> startline = b'  >>> foo = 1\\n'
    >>> matcher.startsat(startline)
    True
    >>> matcher.startsat(b'  ... foo = 1\\n')
    False
    >>> ctx = matcher.startsat(startline)
    >>> matcher.filename(ctx)
    >>> matcher.ignores(ctx)
    False
    >>> b2s(matcher.codeatstart(ctx, startline))
    'foo = 1\\n'
    >>> inside = b'  >>> foo = 1\\n'
    >>> matcher.endsat(ctx, inside)
    False
    >>> matcher.isinside(ctx, inside)
    True
    >>> b2s(matcher.codeinside(ctx, inside))
    'foo = 1\\n'
    >>> inside = b'  ... foo = 1\\n'
    >>> matcher.endsat(ctx, inside)
    False
    >>> matcher.isinside(ctx, inside)
    True
    >>> b2s(matcher.codeinside(ctx, inside))
    'foo = 1\\n'
    >>> inside = b'  expected output\\n'
    >>> matcher.endsat(ctx, inside)
    False
    >>> matcher.isinside(ctx, inside)
    True
    >>> b2s(matcher.codeinside(ctx, inside))
    '\\n'
    >>> inside = b'  \\n'
    >>> matcher.endsat(ctx, inside)
    False
    >>> matcher.isinside(ctx, inside)
    True
    >>> b2s(matcher.codeinside(ctx, inside))
    '\\n'
    >>> end = b'  $ foo bar\\n'
    >>> matcher.endsat(ctx, end)
    True
    >>> matcher.codeatend(ctx, end)
    >>> end = b'\\n'
    >>> matcher.endsat(ctx, end)
    True
    >>> matcher.codeatend(ctx, end)
    """
    _prefix = b'  >>> '
    _prefixre = re.compile(br'  (>>>|\.\.\.) ')

    # If a line matches against not _prefixre but _outputre, that line
    # is "an expected output line" (= not a part of code fragment).
    #
    # Strictly speaking, a line matching against "(#if|#else|#endif)"
    # is also treated similarly in "inline python code" semantics by
    # run-tests.py. But "directive line inside inline python code"
    # should be rejected by Mercurial reviewers. Therefore, this
    # regexp does not matche against such directive lines.
    _outputre = re.compile(br'  $|  [^$]')

    def __init__(self):
        super(pydoctestmatcher, self).__init__(b"doctest style python code")

    def startsat(self, line):
        # ctx is "True"
        return line.startswith(self._prefix)

    def endsat(self, ctx, line):
        return not (self._prefixre.match(line) or self._outputre.match(line))

    def isinside(self, ctx, line):
        return True # always true, if not yet ended

    def ignores(self, ctx):
        return False # should be checked always

    def filename(self, ctx):
        return None # no filename

    def codeatstart(self, ctx, line):
        return line[len(self._prefix):] # strip prefix '  >>> '/'  ... '

    def codeatend(self, ctx, line):
        return None # no embedded code at end line

    def codeinside(self, ctx, line):
        if self._prefixre.match(line):
            return line[len(self._prefix):] # strip prefix '  >>> '/'  ... '
        return b'\n' # an expected output line is treated as an empty line

class pyheredocmatcher(embeddedmatcher):
    """Detect "python << LIMIT" style embedded python code

    >>> matcher = pyheredocmatcher()
    >>> b2s(matcher.startsat(b'  $ python << EOF\\n'))
    '  > EOF\\n'
    >>> b2s(matcher.startsat(b'  $ $PYTHON   <<EOF\\n'))
    '  > EOF\\n'
    >>> b2s(matcher.startsat(b'  $ "$PYTHON"<<  "EOF"\\n'))
    '  > EOF\\n'
    >>> b2s(matcher.startsat(b"  $ $PYTHON << 'ANYLIMIT'\\n"))
    '  > ANYLIMIT\\n'
    >>> matcher.startsat(b'  $ "$PYTHON" < EOF\\n')
    >>> start = b'  $ python << EOF\\n'
    >>> ctx = matcher.startsat(start)
    >>> matcher.codeatstart(ctx, start)
    >>> matcher.filename(ctx)
    >>> matcher.ignores(ctx)
    False
    >>> inside = b'  > foo = 1\\n'
    >>> matcher.endsat(ctx, inside)
    False
    >>> matcher.isinside(ctx, inside)
    True
    >>> b2s(matcher.codeinside(ctx, inside))
    'foo = 1\\n'
    >>> end = b'  > EOF\\n'
    >>> matcher.endsat(ctx, end)
    True
    >>> matcher.codeatend(ctx, end)
    >>> matcher.endsat(ctx, b'  > EOFEOF\\n')
    False
    >>> ctx = matcher.startsat(b'  $ python << NO_CHECK_EOF\\n')
    >>> matcher.ignores(ctx)
    True
    """
    _prefix = b'  > '

    _startre = re.compile(br'  \$ (\$PYTHON|"\$PYTHON"|python).*' +
                          heredoclimitpat)

    def __init__(self):
        super(pyheredocmatcher, self).__init__(b"heredoc python invocation")

    def startsat(self, line):
        # ctx is END-LINE-OF-EMBEDDED-CODE
        matched = self._startre.match(line)
        if matched:
            return b'  > %s\n' % matched.group('limit')

    def endsat(self, ctx, line):
        return ctx == line

    def isinside(self, ctx, line):
        return line.startswith(self._prefix)

    def ignores(self, ctx):
        return b'  > %s\n' % heredocignorelimit == ctx

    def filename(self, ctx):
        return None # no filename

    def codeatstart(self, ctx, line):
        return None # no embedded code at start line

    def codeatend(self, ctx, line):
        return None # no embedded code at end line

    def codeinside(self, ctx, line):
        return line[len(self._prefix):] # strip prefix

_pymatchers = [
    pydoctestmatcher(),
    pyheredocmatcher(),
    # use '[^<]+' instead of '\S+', in order to match against
    # paths including whitespaces
    fileheredocmatcher(b'heredoc .py file', br'[^<]+\.py'),
]

def pyembedded(basefile, lines, errors):
    return embedded(basefile, lines, errors, _pymatchers)

####
# for embedded shell script

_shmatchers = [
    # use '[^<]+' instead of '\S+', in order to match against
    # paths including whitespaces
    fileheredocmatcher(b'heredoc .sh file', br'[^<]+\.sh'),
]

def shembedded(basefile, lines, errors):
    return embedded(basefile, lines, errors, _shmatchers)

####
# for embedded hgrc configuration

_hgrcmatchers = [
    # use '[^<]+' instead of '\S+', in order to match against
    # paths including whitespaces
    fileheredocmatcher(b'heredoc hgrc file',
                       br'(([^/<]+/)+hgrc|\$HGRCPATH|\${HGRCPATH})'),
]

def hgrcembedded(basefile, lines, errors):
    return embedded(basefile, lines, errors, _hgrcmatchers)

####

if __name__ == "__main__":
    import optparse
    import sys

    def showembedded(basefile, lines, embeddedfunc, opts):
        errors = []
        for name, starts, ends, code in embeddedfunc(basefile, lines, errors):
            if not name:
                name = b'<anonymous>'
            writeout(b"%s:%d: %s starts\n" % (basefile, starts, name))
            if opts.verbose and code:
                writeout(b"  |%s\n" %
                         b"\n  |".join(l for l in code.splitlines()))
            writeout(b"%s:%d: %s ends\n" % (basefile, ends, name))
        for e in errors:
            writeerr(b"%s\n" % e)
        return len(errors)

    def applyembedded(args, embeddedfunc, opts):
        ret = 0
        if args:
            for f in args:
                with opentext(f) as fp:
                    if showembedded(bytestr(f), fp, embeddedfunc, opts):
                        ret = 1
        else:
            lines = [l for l in stdin.readlines()]
            if showembedded(b'<stdin>', lines, embeddedfunc, opts):
                ret = 1
        return ret

    commands = {}
    def command(name, desc):
        def wrap(func):
            commands[name] = (desc, func)
        return wrap

    @command("pyembedded", "detect embedded python script")
    def pyembeddedcmd(args, opts):
        return applyembedded(args, pyembedded, opts)

    @command("shembedded", "detect embedded shell script")
    def shembeddedcmd(args, opts):
        return applyembedded(args, shembedded, opts)

    @command("hgrcembedded", "detect embedded hgrc configuration")
    def hgrcembeddedcmd(args, opts):
        return applyembedded(args, hgrcembedded, opts)

    availablecommands = "\n".join(["  - %s: %s" % (key, value[0])
                                   for key, value in commands.items()])

    parser = optparse.OptionParser("""%prog COMMAND [file ...]

Pick up embedded code fragments from given file(s) or stdin, and list
up start/end lines of them in standard compiler format
("FILENAME:LINENO:").

Available commands are:
""" + availablecommands + """
""")
    parser.add_option("-v", "--verbose",
                      help="enable additional output (e.g. actual code)",
                      action="store_true")
    (opts, args) = parser.parse_args()

    if not args or args[0] not in commands:
        parser.print_help()
        sys.exit(255)

    sys.exit(commands[args[0]][1](args[1:], opts))
