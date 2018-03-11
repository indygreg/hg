# hgweb/hgweb_mod.py - Web interface for a repository.
#
# Copyright 21 May 2005 - (c) 2005 Jake Edge <jake@edge2.net>
# Copyright 2005-2007 Matt Mackall <mpm@selenic.com>
#
# This software may be used and distributed according to the terms of the
# GNU General Public License version 2 or any later version.

from __future__ import absolute_import

import contextlib
import os

from .common import (
    ErrorResponse,
    HTTP_BAD_REQUEST,
    HTTP_NOT_FOUND,
    HTTP_NOT_MODIFIED,
    HTTP_OK,
    HTTP_SERVER_ERROR,
    cspvalues,
    permhooks,
)

from .. import (
    encoding,
    error,
    formatter,
    hg,
    hook,
    profiling,
    pycompat,
    repoview,
    templatefilters,
    templater,
    ui as uimod,
    util,
    wireprotoserver,
)

from . import (
    request as requestmod,
    webcommands,
    webutil,
    wsgicgi,
)

archivespecs = util.sortdict((
    ('zip', ('application/zip', 'zip', '.zip', None)),
    ('gz', ('application/x-gzip', 'tgz', '.tar.gz', None)),
    ('bz2', ('application/x-bzip2', 'tbz2', '.tar.bz2', None)),
))

def getstyle(req, configfn, templatepath):
    styles = (
        req.qsparams.get('style', None),
        configfn('web', 'style'),
        'paper',
    )
    return styles, templater.stylemap(styles, templatepath)

def makebreadcrumb(url, prefix=''):
    '''Return a 'URL breadcrumb' list

    A 'URL breadcrumb' is a list of URL-name pairs,
    corresponding to each of the path items on a URL.
    This can be used to create path navigation entries.
    '''
    if url.endswith('/'):
        url = url[:-1]
    if prefix:
        url = '/' + prefix + url
    relpath = url
    if relpath.startswith('/'):
        relpath = relpath[1:]

    breadcrumb = []
    urlel = url
    pathitems = [''] + relpath.split('/')
    for pathel in reversed(pathitems):
        if not pathel or not urlel:
            break
        breadcrumb.append({'url': urlel, 'name': pathel})
        urlel = os.path.dirname(urlel)
    return reversed(breadcrumb)

class requestcontext(object):
    """Holds state/context for an individual request.

    Servers can be multi-threaded. Holding state on the WSGI application
    is prone to race conditions. Instances of this class exist to hold
    mutable and race-free state for requests.
    """
    def __init__(self, app, repo, req, res):
        self.repo = repo
        self.reponame = app.reponame
        self.req = req
        self.res = res

        self.archivespecs = archivespecs

        self.maxchanges = self.configint('web', 'maxchanges')
        self.stripecount = self.configint('web', 'stripes')
        self.maxshortchanges = self.configint('web', 'maxshortchanges')
        self.maxfiles = self.configint('web', 'maxfiles')
        self.allowpull = self.configbool('web', 'allow-pull')

        # we use untrusted=False to prevent a repo owner from using
        # web.templates in .hg/hgrc to get access to any file readable
        # by the user running the CGI script
        self.templatepath = self.config('web', 'templates', untrusted=False)

        # This object is more expensive to build than simple config values.
        # It is shared across requests. The app will replace the object
        # if it is updated. Since this is a reference and nothing should
        # modify the underlying object, it should be constant for the lifetime
        # of the request.
        self.websubtable = app.websubtable

        self.csp, self.nonce = cspvalues(self.repo.ui)

    # Trust the settings from the .hg/hgrc files by default.
    def config(self, section, name, default=uimod._unset, untrusted=True):
        return self.repo.ui.config(section, name, default,
                                   untrusted=untrusted)

    def configbool(self, section, name, default=uimod._unset, untrusted=True):
        return self.repo.ui.configbool(section, name, default,
                                       untrusted=untrusted)

    def configint(self, section, name, default=uimod._unset, untrusted=True):
        return self.repo.ui.configint(section, name, default,
                                      untrusted=untrusted)

    def configlist(self, section, name, default=uimod._unset, untrusted=True):
        return self.repo.ui.configlist(section, name, default,
                                       untrusted=untrusted)

    def archivelist(self, nodeid):
        allowed = self.configlist('web', 'allow_archive')
        for typ, spec in self.archivespecs.iteritems():
            if typ in allowed or self.configbool('web', 'allow%s' % typ):
                yield {'type': typ, 'extension': spec[2], 'node': nodeid}

    def templater(self, req):
        # determine scheme, port and server name
        # this is needed to create absolute urls
        logourl = self.config('web', 'logourl')
        logoimg = self.config('web', 'logoimg')
        staticurl = (self.config('web', 'staticurl')
                     or req.apppath + '/static/')
        if not staticurl.endswith('/'):
            staticurl += '/'

        # some functions for the templater

        def motd(**map):
            yield self.config('web', 'motd')

        # figure out which style to use

        vars = {}
        styles, (style, mapfile) = getstyle(req, self.config,
                                            self.templatepath)
        if style == styles[0]:
            vars['style'] = style

        sessionvars = webutil.sessionvars(vars, '?')

        if not self.reponame:
            self.reponame = (self.config('web', 'name', '')
                             or req.reponame
                             or req.apppath
                             or self.repo.root)

        def websubfilter(text):
            return templatefilters.websub(text, self.websubtable)

        # create the templater
        # TODO: export all keywords: defaults = templatekw.keywords.copy()
        defaults = {
            'url': req.apppath + '/',
            'logourl': logourl,
            'logoimg': logoimg,
            'staticurl': staticurl,
            'urlbase': req.advertisedbaseurl,
            'repo': self.reponame,
            'encoding': encoding.encoding,
            'motd': motd,
            'sessionvars': sessionvars,
            'pathdef': makebreadcrumb(req.apppath),
            'style': style,
            'nonce': self.nonce,
        }
        tres = formatter.templateresources(self.repo.ui, self.repo)
        tmpl = templater.templater.frommapfile(mapfile,
                                               filters={'websub': websubfilter},
                                               defaults=defaults,
                                               resources=tres)
        return tmpl


class hgweb(object):
    """HTTP server for individual repositories.

    Instances of this class serve HTTP responses for a particular
    repository.

    Instances are typically used as WSGI applications.

    Some servers are multi-threaded. On these servers, there may
    be multiple active threads inside __call__.
    """
    def __init__(self, repo, name=None, baseui=None):
        if isinstance(repo, str):
            if baseui:
                u = baseui.copy()
            else:
                u = uimod.ui.load()
            r = hg.repository(u, repo)
        else:
            # we trust caller to give us a private copy
            r = repo

        r.ui.setconfig('ui', 'report_untrusted', 'off', 'hgweb')
        r.baseui.setconfig('ui', 'report_untrusted', 'off', 'hgweb')
        r.ui.setconfig('ui', 'nontty', 'true', 'hgweb')
        r.baseui.setconfig('ui', 'nontty', 'true', 'hgweb')
        # resolve file patterns relative to repo root
        r.ui.setconfig('ui', 'forcecwd', r.root, 'hgweb')
        r.baseui.setconfig('ui', 'forcecwd', r.root, 'hgweb')
        # displaying bundling progress bar while serving feel wrong and may
        # break some wsgi implementation.
        r.ui.setconfig('progress', 'disable', 'true', 'hgweb')
        r.baseui.setconfig('progress', 'disable', 'true', 'hgweb')
        self._repos = [hg.cachedlocalrepo(self._webifyrepo(r))]
        self._lastrepo = self._repos[0]
        hook.redirect(True)
        self.reponame = name

    def _webifyrepo(self, repo):
        repo = getwebview(repo)
        self.websubtable = webutil.getwebsubs(repo)
        return repo

    @contextlib.contextmanager
    def _obtainrepo(self):
        """Obtain a repo unique to the caller.

        Internally we maintain a stack of cachedlocalrepo instances
        to be handed out. If one is available, we pop it and return it,
        ensuring it is up to date in the process. If one is not available,
        we clone the most recently used repo instance and return it.

        It is currently possible for the stack to grow without bounds
        if the server allows infinite threads. However, servers should
        have a thread limit, thus establishing our limit.
        """
        if self._repos:
            cached = self._repos.pop()
            r, created = cached.fetch()
        else:
            cached = self._lastrepo.copy()
            r, created = cached.fetch()
        if created:
            r = self._webifyrepo(r)

        self._lastrepo = cached
        self.mtime = cached.mtime
        try:
            yield r
        finally:
            self._repos.append(cached)

    def run(self):
        """Start a server from CGI environment.

        Modern servers should be using WSGI and should avoid this
        method, if possible.
        """
        if not encoding.environ.get('GATEWAY_INTERFACE',
                                    '').startswith("CGI/1."):
            raise RuntimeError("This function is only intended to be "
                               "called while running as a CGI script.")
        wsgicgi.launch(self)

    def __call__(self, env, respond):
        """Run the WSGI application.

        This may be called by multiple threads.
        """
        req = requestmod.wsgirequest(env, respond)
        return self.run_wsgi(req)

    def run_wsgi(self, wsgireq):
        """Internal method to run the WSGI application.

        This is typically only called by Mercurial. External consumers
        should be using instances of this class as the WSGI application.
        """
        with self._obtainrepo() as repo:
            profile = repo.ui.configbool('profiling', 'enabled')
            with profiling.profile(repo.ui, enabled=profile):
                for r in self._runwsgi(wsgireq, repo):
                    yield r

    def _runwsgi(self, wsgireq, repo):
        req = wsgireq.req
        res = wsgireq.res
        rctx = requestcontext(self, repo, req, res)

        # This state is global across all threads.
        encoding.encoding = rctx.config('web', 'encoding')
        rctx.repo.ui.environ = wsgireq.env

        if rctx.csp:
            # hgwebdir may have added CSP header. Since we generate our own,
            # replace it.
            wsgireq.headers = [h for h in wsgireq.headers
                               if h[0] != 'Content-Security-Policy']
            wsgireq.headers.append(('Content-Security-Policy', rctx.csp))
            res.headers['Content-Security-Policy'] = rctx.csp

        handled = wireprotoserver.handlewsgirequest(
            rctx, wsgireq, req, res, self.check_perm)
        if handled:
            return res.sendresponse()

        if req.havepathinfo:
            query = req.dispatchpath
        else:
            query = req.querystring.partition('&')[0].partition(';')[0]

        # translate user-visible url structure to internal structure

        args = query.split('/', 2)
        if 'cmd' not in req.qsparams and args and args[0]:
            cmd = args.pop(0)
            style = cmd.rfind('-')
            if style != -1:
                req.qsparams['style'] = cmd[:style]
                cmd = cmd[style + 1:]

            # avoid accepting e.g. style parameter as command
            if util.safehasattr(webcommands, cmd):
                req.qsparams['cmd'] = cmd

            if cmd == 'static':
                req.qsparams['file'] = '/'.join(args)
            else:
                if args and args[0]:
                    node = args.pop(0).replace('%2F', '/')
                    req.qsparams['node'] = node
                if args:
                    if 'file' in req.qsparams:
                        del req.qsparams['file']
                    for a in args:
                        req.qsparams.add('file', a)

            ua = req.headers.get('User-Agent', '')
            if cmd == 'rev' and 'mercurial' in ua:
                req.qsparams['style'] = 'raw'

            if cmd == 'archive':
                fn = req.qsparams['node']
                for type_, spec in rctx.archivespecs.iteritems():
                    ext = spec[2]
                    if fn.endswith(ext):
                        req.qsparams['node'] = fn[:-len(ext)]
                        req.qsparams['type'] = type_
        else:
            cmd = req.qsparams.get('cmd', '')

        # process the web interface request

        try:
            tmpl = rctx.templater(req)
            ctype = tmpl('mimetype', encoding=encoding.encoding)
            ctype = templater.stringify(ctype)

            # check read permissions non-static content
            if cmd != 'static':
                self.check_perm(rctx, wsgireq, None)

            if cmd == '':
                req.qsparams['cmd'] = tmpl.cache['default']
                cmd = req.qsparams['cmd']

            # Don't enable caching if using a CSP nonce because then it wouldn't
            # be a nonce.
            if rctx.configbool('web', 'cache') and not rctx.nonce:
                tag = 'W/"%d"' % self.mtime
                if req.headers.get('If-None-Match') == tag:
                    raise ErrorResponse(HTTP_NOT_MODIFIED)

                wsgireq.headers.append((r'ETag', pycompat.sysstr(tag)))
                res.headers['ETag'] = tag

            if cmd not in webcommands.__all__:
                msg = 'no such method: %s' % cmd
                raise ErrorResponse(HTTP_BAD_REQUEST, msg)
            elif cmd == 'file' and req.qsparams.get('style') == 'raw':
                res.status = '200 Script output follows'
                res.headers['Content-Type'] = ctype
                content = webcommands.rawfile(rctx, wsgireq, tmpl)
                assert content is res
                return res.sendresponse()
            else:
                # Set some globals appropriate for web handlers. Commands can
                # override easily enough.
                res.status = '200 Script output follows'
                res.headers['Content-Type'] = ctype
                content = getattr(webcommands, cmd)(rctx, wsgireq, tmpl)

                if content is res:
                    return res.sendresponse()

                wsgireq.respond(HTTP_OK, ctype)

            return content

        except (error.LookupError, error.RepoLookupError) as err:
            wsgireq.respond(HTTP_NOT_FOUND, ctype)
            msg = pycompat.bytestr(err)
            if (util.safehasattr(err, 'name') and
                not isinstance(err,  error.ManifestLookupError)):
                msg = 'revision not found: %s' % err.name
            return tmpl('error', error=msg)
        except (error.RepoError, error.RevlogError) as inst:
            wsgireq.respond(HTTP_SERVER_ERROR, ctype)
            return tmpl('error', error=pycompat.bytestr(inst))
        except ErrorResponse as inst:
            wsgireq.respond(inst, ctype)
            if inst.code == HTTP_NOT_MODIFIED:
                # Not allowed to return a body on a 304
                return ['']
            return tmpl('error', error=pycompat.bytestr(inst))

    def check_perm(self, rctx, req, op):
        for permhook in permhooks:
            permhook(rctx, req, op)

def getwebview(repo):
    """The 'web.view' config controls changeset filter to hgweb. Possible
    values are ``served``, ``visible`` and ``all``. Default is ``served``.
    The ``served`` filter only shows changesets that can be pulled from the
    hgweb instance.  The``visible`` filter includes secret changesets but
    still excludes "hidden" one.

    See the repoview module for details.

    The option has been around undocumented since Mercurial 2.5, but no
    user ever asked about it. So we better keep it undocumented for now."""
    # experimental config: web.view
    viewconfig = repo.ui.config('web', 'view', untrusted=True)
    if viewconfig == 'all':
        return repo.unfiltered()
    elif viewconfig in repoview.filtertable:
        return repo.filtered(viewconfig)
    else:
        return repo.filtered('served')
