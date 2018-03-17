# templateutil.py - utility for template evaluation
#
# Copyright 2005, 2006 Matt Mackall <mpm@selenic.com>
#
# This software may be used and distributed according to the terms of the
# GNU General Public License version 2 or any later version.

from __future__ import absolute_import

import abc
import types

from .i18n import _
from . import (
    error,
    pycompat,
    util,
)
from .utils import (
    dateutil,
    stringutil,
)

class ResourceUnavailable(error.Abort):
    pass

class TemplateNotFound(error.Abort):
    pass

class wrapped(object):
    """Object requiring extra conversion prior to displaying or processing
    as value

    Use unwrapvalue(), unwrapastype(), or unwraphybrid() to obtain the inner
    object.
    """

    __metaclass__ = abc.ABCMeta

    @abc.abstractmethod
    def itermaps(self, context):
        """Yield each template mapping"""

    @abc.abstractmethod
    def show(self, context, mapping):
        """Return a bytes or (possibly nested) generator of bytes representing
        the underlying object

        A pre-configured template may be rendered if the underlying object is
        not printable.
        """

    @abc.abstractmethod
    def tovalue(self, context, mapping):
        """Move the inner value object out or create a value representation

        A returned value must be serializable by templaterfilters.json().
        """

# stub for representing a date type; may be a real date type that can
# provide a readable string value
class date(object):
    pass

class hybrid(wrapped):
    """Wrapper for list or dict to support legacy template

    This class allows us to handle both:
    - "{files}" (legacy command-line-specific list hack) and
    - "{files % '{file}\n'}" (hgweb-style with inlining and function support)
    and to access raw values:
    - "{ifcontains(file, files, ...)}", "{ifcontains(key, extras, ...)}"
    - "{get(extras, key)}"
    - "{files|json}"
    """

    def __init__(self, gen, values, makemap, joinfmt, keytype=None):
        self._gen = gen  # generator or function returning generator
        self._values = values
        self._makemap = makemap
        self.joinfmt = joinfmt
        self.keytype = keytype  # hint for 'x in y' where type(x) is unresolved

    def itermaps(self, context):
        makemap = self._makemap
        for x in self._values:
            yield makemap(x)

    def show(self, context, mapping):
        # TODO: switch gen to (context, mapping) API?
        gen = self._gen
        if gen is None:
            return joinitems((self.joinfmt(x) for x in self._values), ' ')
        if callable(gen):
            return gen()
        return gen

    def tovalue(self, context, mapping):
        # TODO: return self._values and get rid of proxy methods
        return self

    def __contains__(self, x):
        return x in self._values
    def __getitem__(self, key):
        return self._values[key]
    def __len__(self):
        return len(self._values)
    def __iter__(self):
        return iter(self._values)
    def __getattr__(self, name):
        if name not in (r'get', r'items', r'iteritems', r'iterkeys',
                        r'itervalues', r'keys', r'values'):
            raise AttributeError(name)
        return getattr(self._values, name)

class mappable(wrapped):
    """Wrapper for non-list/dict object to support map operation

    This class allows us to handle both:
    - "{manifest}"
    - "{manifest % '{rev}:{node}'}"
    - "{manifest.rev}"

    Unlike a hybrid, this does not simulate the behavior of the underling
    value.
    """

    def __init__(self, gen, key, value, makemap):
        self._gen = gen  # generator or function returning generator
        self._key = key
        self._value = value  # may be generator of strings
        self._makemap = makemap

    def tomap(self):
        return self._makemap(self._key)

    def itermaps(self, context):
        yield self.tomap()

    def show(self, context, mapping):
        # TODO: switch gen to (context, mapping) API?
        gen = self._gen
        if gen is None:
            return pycompat.bytestr(self._value)
        if callable(gen):
            return gen()
        return gen

    def tovalue(self, context, mapping):
        return _unthunk(context, mapping, self._value)

def hybriddict(data, key='key', value='value', fmt=None, gen=None):
    """Wrap data to support both dict-like and string-like operations"""
    prefmt = pycompat.identity
    if fmt is None:
        fmt = '%s=%s'
        prefmt = pycompat.bytestr
    return hybrid(gen, data, lambda k: {key: k, value: data[k]},
                  lambda k: fmt % (prefmt(k), prefmt(data[k])))

def hybridlist(data, name, fmt=None, gen=None):
    """Wrap data to support both list-like and string-like operations"""
    prefmt = pycompat.identity
    if fmt is None:
        fmt = '%s'
        prefmt = pycompat.bytestr
    return hybrid(gen, data, lambda x: {name: x}, lambda x: fmt % prefmt(x))

def unwraphybrid(context, mapping, thing):
    """Return an object which can be stringified possibly by using a legacy
    template"""
    if not isinstance(thing, wrapped):
        return thing
    return thing.show(context, mapping)

def unwrapvalue(context, mapping, thing):
    """Move the inner value object out of the wrapper"""
    if not isinstance(thing, wrapped):
        return thing
    return thing.tovalue(context, mapping)

def wraphybridvalue(container, key, value):
    """Wrap an element of hybrid container to be mappable

    The key is passed to the makemap function of the given container, which
    should be an item generated by iter(container).
    """
    makemap = getattr(container, '_makemap', None)
    if makemap is None:
        return value
    if util.safehasattr(value, '_makemap'):
        # a nested hybrid list/dict, which has its own way of map operation
        return value
    return mappable(None, key, value, makemap)

def compatdict(context, mapping, name, data, key='key', value='value',
               fmt=None, plural=None, separator=' '):
    """Wrap data like hybriddict(), but also supports old-style list template

    This exists for backward compatibility with the old-style template. Use
    hybriddict() for new template keywords.
    """
    c = [{key: k, value: v} for k, v in data.iteritems()]
    f = _showcompatlist(context, mapping, name, c, plural, separator)
    return hybriddict(data, key=key, value=value, fmt=fmt, gen=f)

def compatlist(context, mapping, name, data, element=None, fmt=None,
               plural=None, separator=' '):
    """Wrap data like hybridlist(), but also supports old-style list template

    This exists for backward compatibility with the old-style template. Use
    hybridlist() for new template keywords.
    """
    f = _showcompatlist(context, mapping, name, data, plural, separator)
    return hybridlist(data, name=element or name, fmt=fmt, gen=f)

def _showcompatlist(context, mapping, name, values, plural=None, separator=' '):
    """Return a generator that renders old-style list template

    name is name of key in template map.
    values is list of strings or dicts.
    plural is plural of name, if not simply name + 's'.
    separator is used to join values as a string

    expansion works like this, given name 'foo'.

    if values is empty, expand 'no_foos'.

    if 'foo' not in template map, return values as a string,
    joined by 'separator'.

    expand 'start_foos'.

    for each value, expand 'foo'. if 'last_foo' in template
    map, expand it instead of 'foo' for last key.

    expand 'end_foos'.
    """
    if not plural:
        plural = name + 's'
    if not values:
        noname = 'no_' + plural
        if context.preload(noname):
            yield context.process(noname, mapping)
        return
    if not context.preload(name):
        if isinstance(values[0], bytes):
            yield separator.join(values)
        else:
            for v in values:
                r = dict(v)
                r.update(mapping)
                yield r
        return
    startname = 'start_' + plural
    if context.preload(startname):
        yield context.process(startname, mapping)
    def one(v, tag=name):
        vmapping = {}
        try:
            vmapping.update(v)
        # Python 2 raises ValueError if the type of v is wrong. Python
        # 3 raises TypeError.
        except (AttributeError, TypeError, ValueError):
            try:
                # Python 2 raises ValueError trying to destructure an e.g.
                # bytes. Python 3 raises TypeError.
                for a, b in v:
                    vmapping[a] = b
            except (TypeError, ValueError):
                vmapping[name] = v
        vmapping = context.overlaymap(mapping, vmapping)
        return context.process(tag, vmapping)
    lastname = 'last_' + name
    if context.preload(lastname):
        last = values.pop()
    else:
        last = None
    for v in values:
        yield one(v)
    if last is not None:
        yield one(last, tag=lastname)
    endname = 'end_' + plural
    if context.preload(endname):
        yield context.process(endname, mapping)

def flatten(context, mapping, thing):
    """Yield a single stream from a possibly nested set of iterators"""
    thing = unwraphybrid(context, mapping, thing)
    if isinstance(thing, bytes):
        yield thing
    elif isinstance(thing, str):
        # We can only hit this on Python 3, and it's here to guard
        # against infinite recursion.
        raise error.ProgrammingError('Mercurial IO including templates is done'
                                     ' with bytes, not strings, got %r' % thing)
    elif thing is None:
        pass
    elif not util.safehasattr(thing, '__iter__'):
        yield pycompat.bytestr(thing)
    else:
        for i in thing:
            i = unwraphybrid(context, mapping, i)
            if isinstance(i, bytes):
                yield i
            elif i is None:
                pass
            elif not util.safehasattr(i, '__iter__'):
                yield pycompat.bytestr(i)
            else:
                for j in flatten(context, mapping, i):
                    yield j

def stringify(context, mapping, thing):
    """Turn values into bytes by converting into text and concatenating them"""
    if isinstance(thing, bytes):
        return thing  # retain localstr to be round-tripped
    return b''.join(flatten(context, mapping, thing))

def findsymbolicname(arg):
    """Find symbolic name for the given compiled expression; returns None
    if nothing found reliably"""
    while True:
        func, data = arg
        if func is runsymbol:
            return data
        elif func is runfilter:
            arg = data[0]
        else:
            return None

def _unthunk(context, mapping, thing):
    """Evaluate a lazy byte string into value"""
    if not isinstance(thing, types.GeneratorType):
        return thing
    return stringify(context, mapping, thing)

def evalrawexp(context, mapping, arg):
    """Evaluate given argument as a bare template object which may require
    further processing (such as folding generator of strings)"""
    func, data = arg
    return func(context, mapping, data)

def evalfuncarg(context, mapping, arg):
    """Evaluate given argument as value type"""
    return _unwrapvalue(context, mapping, evalrawexp(context, mapping, arg))

# TODO: unify this with unwrapvalue() once the bug of templatefunc.join()
# is fixed. we can't do that right now because join() has to take a generator
# of byte strings as it is, not a lazy byte string.
def _unwrapvalue(context, mapping, thing):
    thing = unwrapvalue(context, mapping, thing)
    # evalrawexp() may return string, generator of strings or arbitrary object
    # such as date tuple, but filter does not want generator.
    return _unthunk(context, mapping, thing)

def evalboolean(context, mapping, arg):
    """Evaluate given argument as boolean, but also takes boolean literals"""
    func, data = arg
    if func is runsymbol:
        thing = func(context, mapping, data, default=None)
        if thing is None:
            # not a template keyword, takes as a boolean literal
            thing = stringutil.parsebool(data)
    else:
        thing = func(context, mapping, data)
    thing = unwrapvalue(context, mapping, thing)
    if isinstance(thing, bool):
        return thing
    # other objects are evaluated as strings, which means 0 is True, but
    # empty dict/list should be False as they are expected to be ''
    return bool(stringify(context, mapping, thing))

def evaldate(context, mapping, arg, err=None):
    """Evaluate given argument as a date tuple or a date string; returns
    a (unixtime, offset) tuple"""
    thing = evalrawexp(context, mapping, arg)
    return unwrapdate(context, mapping, thing, err)

def unwrapdate(context, mapping, thing, err=None):
    thing = _unwrapvalue(context, mapping, thing)
    try:
        return dateutil.parsedate(thing)
    except AttributeError:
        raise error.ParseError(err or _('not a date tuple nor a string'))
    except error.ParseError:
        if not err:
            raise
        raise error.ParseError(err)

def evalinteger(context, mapping, arg, err=None):
    thing = evalrawexp(context, mapping, arg)
    return unwrapinteger(context, mapping, thing, err)

def unwrapinteger(context, mapping, thing, err=None):
    thing = _unwrapvalue(context, mapping, thing)
    try:
        return int(thing)
    except (TypeError, ValueError):
        raise error.ParseError(err or _('not an integer'))

def evalstring(context, mapping, arg):
    return stringify(context, mapping, evalrawexp(context, mapping, arg))

def evalstringliteral(context, mapping, arg):
    """Evaluate given argument as string template, but returns symbol name
    if it is unknown"""
    func, data = arg
    if func is runsymbol:
        thing = func(context, mapping, data, default=data)
    else:
        thing = func(context, mapping, data)
    return stringify(context, mapping, thing)

_unwrapfuncbytype = {
    None: _unwrapvalue,
    bytes: stringify,
    date: unwrapdate,
    int: unwrapinteger,
}

def unwrapastype(context, mapping, thing, typ):
    """Move the inner value object out of the wrapper and coerce its type"""
    try:
        f = _unwrapfuncbytype[typ]
    except KeyError:
        raise error.ProgrammingError('invalid type specified: %r' % typ)
    return f(context, mapping, thing)

def runinteger(context, mapping, data):
    return int(data)

def runstring(context, mapping, data):
    return data

def _recursivesymbolblocker(key):
    def showrecursion(**args):
        raise error.Abort(_("recursive reference '%s' in template") % key)
    return showrecursion

def runsymbol(context, mapping, key, default=''):
    v = context.symbol(mapping, key)
    if v is None:
        # put poison to cut recursion. we can't move this to parsing phase
        # because "x = {x}" is allowed if "x" is a keyword. (issue4758)
        safemapping = mapping.copy()
        safemapping[key] = _recursivesymbolblocker(key)
        try:
            v = context.process(key, safemapping)
        except TemplateNotFound:
            v = default
    if callable(v) and getattr(v, '_requires', None) is None:
        # old templatekw: expand all keywords and resources
        # (TODO: deprecate this after porting web template keywords to new API)
        props = {k: context._resources.lookup(context, mapping, k)
                 for k in context._resources.knownkeys()}
        # pass context to _showcompatlist() through templatekw._showlist()
        props['templ'] = context
        props.update(mapping)
        return v(**pycompat.strkwargs(props))
    if callable(v):
        # new templatekw
        try:
            return v(context, mapping)
        except ResourceUnavailable:
            # unsupported keyword is mapped to empty just like unknown keyword
            return None
    return v

def runtemplate(context, mapping, template):
    for arg in template:
        yield evalrawexp(context, mapping, arg)

def runfilter(context, mapping, data):
    arg, filt = data
    thing = evalrawexp(context, mapping, arg)
    intype = getattr(filt, '_intype', None)
    try:
        thing = unwrapastype(context, mapping, thing, intype)
        return filt(thing)
    except error.ParseError as e:
        raise error.ParseError(bytes(e), hint=_formatfiltererror(arg, filt))

def _formatfiltererror(arg, filt):
    fn = pycompat.sysbytes(filt.__name__)
    sym = findsymbolicname(arg)
    if not sym:
        return _("incompatible use of template filter '%s'") % fn
    return (_("template filter '%s' is not compatible with keyword '%s'")
            % (fn, sym))

def runmap(context, mapping, data):
    darg, targ = data
    d = evalrawexp(context, mapping, darg)
    if isinstance(d, wrapped):
        diter = d.itermaps(context)
    else:
        try:
            diter = iter(d)
        except TypeError:
            sym = findsymbolicname(darg)
            if sym:
                raise error.ParseError(_("keyword '%s' is not iterable") % sym)
            else:
                raise error.ParseError(_("%r is not iterable") % d)

    for i, v in enumerate(diter):
        if isinstance(v, dict):
            lm = context.overlaymap(mapping, v)
            lm['index'] = i
            yield evalrawexp(context, lm, targ)
        else:
            # v is not an iterable of dicts, this happen when 'key'
            # has been fully expanded already and format is useless.
            # If so, return the expanded value.
            yield v

def runmember(context, mapping, data):
    darg, memb = data
    d = evalrawexp(context, mapping, darg)
    if util.safehasattr(d, 'tomap'):
        lm = context.overlaymap(mapping, d.tomap())
        return runsymbol(context, lm, memb)
    if util.safehasattr(d, 'get'):
        return getdictitem(d, memb)

    sym = findsymbolicname(darg)
    if sym:
        raise error.ParseError(_("keyword '%s' has no member") % sym)
    else:
        raise error.ParseError(_("%r has no member") % pycompat.bytestr(d))

def runnegate(context, mapping, data):
    data = evalinteger(context, mapping, data,
                       _('negation needs an integer argument'))
    return -data

def runarithmetic(context, mapping, data):
    func, left, right = data
    left = evalinteger(context, mapping, left,
                       _('arithmetic only defined on integers'))
    right = evalinteger(context, mapping, right,
                        _('arithmetic only defined on integers'))
    try:
        return func(left, right)
    except ZeroDivisionError:
        raise error.Abort(_('division by zero is not defined'))

def getdictitem(dictarg, key):
    val = dictarg.get(key)
    if val is None:
        return
    return wraphybridvalue(dictarg, key, val)

def joinitems(itemiter, sep):
    """Join items with the separator; Returns generator of bytes"""
    first = True
    for x in itemiter:
        if first:
            first = False
        else:
            yield sep
        yield x
