# hgweb/request.py - An http request from either CGI or the standalone server.
#
# Copyright 21 May 2005 - (c) 2005 Jake Edge <jake@edge2.net>
# Copyright 2005, 2006 Matt Mackall <mpm@selenic.com>
#
# This software may be used and distributed according to the terms of the
# GNU General Public License version 2 or any later version.

from __future__ import absolute_import

import cgi
import errno
import socket
import wsgiref.headers as wsgiheaders
#import wsgiref.validate

from .common import (
    ErrorResponse,
    HTTP_NOT_MODIFIED,
    statusmessage,
)

from ..thirdparty import (
    attr,
)
from .. import (
    pycompat,
    util,
)

shortcuts = {
    'cl': [('cmd', ['changelog']), ('rev', None)],
    'sl': [('cmd', ['shortlog']), ('rev', None)],
    'cs': [('cmd', ['changeset']), ('node', None)],
    'f': [('cmd', ['file']), ('filenode', None)],
    'fl': [('cmd', ['filelog']), ('filenode', None)],
    'fd': [('cmd', ['filediff']), ('node', None)],
    'fa': [('cmd', ['annotate']), ('filenode', None)],
    'mf': [('cmd', ['manifest']), ('manifest', None)],
    'ca': [('cmd', ['archive']), ('node', None)],
    'tags': [('cmd', ['tags'])],
    'tip': [('cmd', ['changeset']), ('node', ['tip'])],
    'static': [('cmd', ['static']), ('file', None)]
}

def normalize(form):
    # first expand the shortcuts
    for k in shortcuts:
        if k in form:
            for name, value in shortcuts[k]:
                if value is None:
                    value = form[k]
                form[name] = value
            del form[k]
    # And strip the values
    bytesform = {}
    for k, v in form.iteritems():
        bytesform[pycompat.bytesurl(k)] = [
            pycompat.bytesurl(i.strip()) for i in v]
    return bytesform

@attr.s(frozen=True)
class parsedrequest(object):
    """Represents a parsed WSGI request / static HTTP request parameters."""

    # Request method.
    method = attr.ib()
    # Full URL for this request.
    url = attr.ib()
    # URL without any path components. Just <proto>://<host><port>.
    baseurl = attr.ib()
    # Advertised URL. Like ``url`` and ``baseurl`` but uses SERVER_NAME instead
    # of HTTP: Host header for hostname. This is likely what clients used.
    advertisedurl = attr.ib()
    advertisedbaseurl = attr.ib()
    # WSGI application path.
    apppath = attr.ib()
    # List of path parts to be used for dispatch.
    dispatchparts = attr.ib()
    # URL path component (no query string) used for dispatch.
    dispatchpath = attr.ib()
    # Whether there is a path component to this request. This can be true
    # when ``dispatchpath`` is empty due to REPO_NAME muckery.
    havepathinfo = attr.ib()
    # Raw query string (part after "?" in URL).
    querystring = attr.ib()
    # List of 2-tuples of query string arguments.
    querystringlist = attr.ib()
    # Dict of query string arguments. Values are lists with at least 1 item.
    querystringdict = attr.ib()
    # wsgiref.headers.Headers instance. Operates like a dict with case
    # insensitive keys.
    headers = attr.ib()

def parserequestfromenv(env):
    """Parse URL components from environment variables.

    WSGI defines request attributes via environment variables. This function
    parses the environment variables into a data structure.
    """
    # PEP-0333 defines the WSGI spec and is a useful reference for this code.

    # We first validate that the incoming object conforms with the WSGI spec.
    # We only want to be dealing with spec-conforming WSGI implementations.
    # TODO enable this once we fix internal violations.
    #wsgiref.validate.check_environ(env)

    # PEP-0333 states that environment keys and values are native strings
    # (bytes on Python 2 and str on Python 3). The code points for the Unicode
    # strings on Python 3 must be between \00000-\000FF. We deal with bytes
    # in Mercurial, so mass convert string keys and values to bytes.
    if pycompat.ispy3:
        env = {k.encode('latin-1'): v for k, v in env.iteritems()}
        env = {k: v.encode('latin-1') if isinstance(v, str) else v
               for k, v in env.iteritems()}

    # https://www.python.org/dev/peps/pep-0333/#environ-variables defines
    # the environment variables.
    # https://www.python.org/dev/peps/pep-0333/#url-reconstruction defines
    # how URLs are reconstructed.
    fullurl = env['wsgi.url_scheme'] + '://'
    advertisedfullurl = fullurl

    def addport(s):
        if env['wsgi.url_scheme'] == 'https':
            if env['SERVER_PORT'] != '443':
                s += ':' + env['SERVER_PORT']
        else:
            if env['SERVER_PORT'] != '80':
                s += ':' + env['SERVER_PORT']

        return s

    if env.get('HTTP_HOST'):
        fullurl += env['HTTP_HOST']
    else:
        fullurl += env['SERVER_NAME']
        fullurl = addport(fullurl)

    advertisedfullurl += env['SERVER_NAME']
    advertisedfullurl = addport(advertisedfullurl)

    baseurl = fullurl
    advertisedbaseurl = advertisedfullurl

    fullurl += util.urlreq.quote(env.get('SCRIPT_NAME', ''))
    advertisedfullurl += util.urlreq.quote(env.get('SCRIPT_NAME', ''))
    fullurl += util.urlreq.quote(env.get('PATH_INFO', ''))
    advertisedfullurl += util.urlreq.quote(env.get('PATH_INFO', ''))

    if env.get('QUERY_STRING'):
        fullurl += '?' + env['QUERY_STRING']
        advertisedfullurl += '?' + env['QUERY_STRING']

    # When dispatching requests, we look at the URL components (PATH_INFO
    # and QUERY_STRING) after the application root (SCRIPT_NAME). But hgwebdir
    # has the concept of "virtual" repositories. This is defined via REPO_NAME.
    # If REPO_NAME is defined, we append it to SCRIPT_NAME to form a new app
    # root. We also exclude its path components from PATH_INFO when resolving
    # the dispatch path.

    apppath = env['SCRIPT_NAME']

    if env.get('REPO_NAME'):
        if not apppath.endswith('/'):
            apppath += '/'

        apppath += env.get('REPO_NAME')

    if 'PATH_INFO' in env:
        dispatchparts = env['PATH_INFO'].strip('/').split('/')

        # Strip out repo parts.
        repoparts = env.get('REPO_NAME', '').split('/')
        if dispatchparts[:len(repoparts)] == repoparts:
            dispatchparts = dispatchparts[len(repoparts):]
    else:
        dispatchparts = []

    dispatchpath = '/'.join(dispatchparts)

    querystring = env.get('QUERY_STRING', '')

    # We store as a list so we have ordering information. We also store as
    # a dict to facilitate fast lookup.
    querystringlist = util.urlreq.parseqsl(querystring, keep_blank_values=True)

    querystringdict = {}
    for k, v in querystringlist:
        if k in querystringdict:
            querystringdict[k].append(v)
        else:
            querystringdict[k] = [v]

    # HTTP_* keys contain HTTP request headers. The Headers structure should
    # perform case normalization for us. We just rewrite underscore to dash
    # so keys match what likely went over the wire.
    headers = []
    for k, v in env.iteritems():
        if k.startswith('HTTP_'):
            headers.append((k[len('HTTP_'):].replace('_', '-'), v))

    headers = wsgiheaders.Headers(headers)

    # This is kind of a lie because the HTTP header wasn't explicitly
    # sent. But for all intents and purposes it should be OK to lie about
    # this, since a consumer will either either value to determine how many
    # bytes are available to read.
    if 'CONTENT_LENGTH' in env and 'HTTP_CONTENT_LENGTH' not in env:
        headers['Content-Length'] = env['CONTENT_LENGTH']

    return parsedrequest(method=env['REQUEST_METHOD'],
                         url=fullurl, baseurl=baseurl,
                         advertisedurl=advertisedfullurl,
                         advertisedbaseurl=advertisedbaseurl,
                         apppath=apppath,
                         dispatchparts=dispatchparts, dispatchpath=dispatchpath,
                         havepathinfo='PATH_INFO' in env,
                         querystring=querystring,
                         querystringlist=querystringlist,
                         querystringdict=querystringdict,
                         headers=headers)

class wsgirequest(object):
    """Higher-level API for a WSGI request.

    WSGI applications are invoked with 2 arguments. They are used to
    instantiate instances of this class, which provides higher-level APIs
    for obtaining request parameters, writing HTTP output, etc.
    """
    def __init__(self, wsgienv, start_response):
        version = wsgienv[r'wsgi.version']
        if (version < (1, 0)) or (version >= (2, 0)):
            raise RuntimeError("Unknown and unsupported WSGI version %d.%d"
                               % version)
        self.inp = wsgienv[r'wsgi.input']
        self.err = wsgienv[r'wsgi.errors']
        self.threaded = wsgienv[r'wsgi.multithread']
        self.multiprocess = wsgienv[r'wsgi.multiprocess']
        self.run_once = wsgienv[r'wsgi.run_once']
        self.env = wsgienv
        self.form = normalize(cgi.parse(self.inp,
                                        self.env,
                                        keep_blank_values=1))
        self._start_response = start_response
        self.server_write = None
        self.headers = []

    def __iter__(self):
        return iter([])

    def read(self, count=-1):
        return self.inp.read(count)

    def drain(self):
        '''need to read all data from request, httplib is half-duplex'''
        length = int(self.env.get('CONTENT_LENGTH') or 0)
        for s in util.filechunkiter(self.inp, limit=length):
            pass

    def respond(self, status, type, filename=None, body=None):
        if not isinstance(type, str):
            type = pycompat.sysstr(type)
        if self._start_response is not None:
            self.headers.append((r'Content-Type', type))
            if filename:
                filename = (filename.rpartition('/')[-1]
                            .replace('\\', '\\\\').replace('"', '\\"'))
                self.headers.append(('Content-Disposition',
                                     'inline; filename="%s"' % filename))
            if body is not None:
                self.headers.append((r'Content-Length', str(len(body))))

            for k, v in self.headers:
                if not isinstance(v, str):
                    raise TypeError('header value must be string: %r' % (v,))

            if isinstance(status, ErrorResponse):
                self.headers.extend(status.headers)
                if status.code == HTTP_NOT_MODIFIED:
                    # RFC 2616 Section 10.3.5: 304 Not Modified has cases where
                    # it MUST NOT include any headers other than these and no
                    # body
                    self.headers = [(k, v) for (k, v) in self.headers if
                                    k in ('Date', 'ETag', 'Expires',
                                          'Cache-Control', 'Vary')]
                status = statusmessage(status.code, pycompat.bytestr(status))
            elif status == 200:
                status = '200 Script output follows'
            elif isinstance(status, int):
                status = statusmessage(status)

            self.server_write = self._start_response(
                pycompat.sysstr(status), self.headers)
            self._start_response = None
            self.headers = []
        if body is not None:
            self.write(body)
            self.server_write = None

    def write(self, thing):
        if thing:
            try:
                self.server_write(thing)
            except socket.error as inst:
                if inst[0] != errno.ECONNRESET:
                    raise

    def flush(self):
        return None

def wsgiapplication(app_maker):
    '''For compatibility with old CGI scripts. A plain hgweb() or hgwebdir()
    can and should now be used as a WSGI application.'''
    application = app_maker()
    def run_wsgi(env, respond):
        return application(env, respond)
    return run_wsgi
