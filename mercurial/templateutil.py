# templateutil.py - utility for template evaluation
#
# Copyright 2005, 2006 Matt Mackall <mpm@selenic.com>
#
# This software may be used and distributed according to the terms of the
# GNU General Public License version 2 or any later version.

from __future__ import absolute_import

import types

from .i18n import _
from . import (
    error,
    pycompat,
    templatefilters,
    templatekw,
    util,
)

class ResourceUnavailable(error.Abort):
    pass

class TemplateNotFound(error.Abort):
    pass

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

def evalrawexp(context, mapping, arg):
    """Evaluate given argument as a bare template object which may require
    further processing (such as folding generator of strings)"""
    func, data = arg
    return func(context, mapping, data)

def evalfuncarg(context, mapping, arg):
    """Evaluate given argument as value type"""
    thing = evalrawexp(context, mapping, arg)
    thing = templatekw.unwrapvalue(thing)
    # evalrawexp() may return string, generator of strings or arbitrary object
    # such as date tuple, but filter does not want generator.
    if isinstance(thing, types.GeneratorType):
        thing = stringify(thing)
    return thing

def evalboolean(context, mapping, arg):
    """Evaluate given argument as boolean, but also takes boolean literals"""
    func, data = arg
    if func is runsymbol:
        thing = func(context, mapping, data, default=None)
        if thing is None:
            # not a template keyword, takes as a boolean literal
            thing = util.parsebool(data)
    else:
        thing = func(context, mapping, data)
    thing = templatekw.unwrapvalue(thing)
    if isinstance(thing, bool):
        return thing
    # other objects are evaluated as strings, which means 0 is True, but
    # empty dict/list should be False as they are expected to be ''
    return bool(stringify(thing))

def evalinteger(context, mapping, arg, err=None):
    v = evalfuncarg(context, mapping, arg)
    try:
        return int(v)
    except (TypeError, ValueError):
        raise error.ParseError(err or _('not an integer'))

def evalstring(context, mapping, arg):
    return stringify(evalrawexp(context, mapping, arg))

def evalstringliteral(context, mapping, arg):
    """Evaluate given argument as string template, but returns symbol name
    if it is unknown"""
    func, data = arg
    if func is runsymbol:
        thing = func(context, mapping, data, default=data)
    else:
        thing = func(context, mapping, data)
    return stringify(thing)

_evalfuncbytype = {
    bool: evalboolean,
    bytes: evalstring,
    int: evalinteger,
}

def evalastype(context, mapping, arg, typ):
    """Evaluate given argument and coerce its type"""
    try:
        f = _evalfuncbytype[typ]
    except KeyError:
        raise error.ProgrammingError('invalid type specified: %r' % typ)
    return f(context, mapping, arg)

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
        props = context._resources.copy()
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
    thing = evalfuncarg(context, mapping, arg)
    try:
        return filt(thing)
    except (ValueError, AttributeError, TypeError):
        sym = findsymbolicname(arg)
        if sym:
            msg = (_("template filter '%s' is not compatible with keyword '%s'")
                   % (pycompat.sysbytes(filt.__name__), sym))
        else:
            msg = (_("incompatible use of template filter '%s'")
                   % pycompat.sysbytes(filt.__name__))
        raise error.Abort(msg)

def runmap(context, mapping, data):
    darg, targ = data
    d = evalrawexp(context, mapping, darg)
    if util.safehasattr(d, 'itermaps'):
        diter = d.itermaps()
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
        lm = mapping.copy()
        lm['index'] = i
        if isinstance(v, dict):
            lm.update(v)
            lm['originalnode'] = mapping.get('node')
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
        lm = mapping.copy()
        lm.update(d.tomap())
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
    return templatekw.wraphybridvalue(dictarg, key, val)

stringify = templatefilters.stringify
