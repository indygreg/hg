from __future__ import absolute_import, print_function

import unittest

from mercurial.hgweb import (
    request as requestmod,
)
from mercurial import (
    error,
)

DEFAULT_ENV = {
    r'REQUEST_METHOD': r'GET',
    r'SERVER_NAME': r'testserver',
    r'SERVER_PORT': r'80',
    r'SERVER_PROTOCOL': r'http',
    r'wsgi.version': (1, 0),
    r'wsgi.url_scheme': r'http',
    r'wsgi.input': None,
    r'wsgi.errors': None,
    r'wsgi.multithread': False,
    r'wsgi.multiprocess': True,
    r'wsgi.run_once': False,
}

def parse(env, reponame=None, altbaseurl=None, extra=None):
    env = dict(env)
    env.update(extra or {})

    return requestmod.parserequestfromenv(env, reponame=reponame,
                                          altbaseurl=altbaseurl)

class ParseRequestTests(unittest.TestCase):
    def testdefault(self):
        r = parse(DEFAULT_ENV)
        self.assertEqual(r.url, b'http://testserver')
        self.assertEqual(r.baseurl, b'http://testserver')
        self.assertEqual(r.advertisedurl, b'http://testserver')
        self.assertEqual(r.advertisedbaseurl, b'http://testserver')
        self.assertEqual(r.urlscheme, b'http')
        self.assertEqual(r.method, b'GET')
        self.assertIsNone(r.remoteuser)
        self.assertIsNone(r.remotehost)
        self.assertEqual(r.apppath, b'')
        self.assertEqual(r.dispatchparts, [])
        self.assertIsNone(r.dispatchpath)
        self.assertIsNone(r.reponame)
        self.assertEqual(r.querystring, b'')
        self.assertEqual(len(r.qsparams), 0)
        self.assertEqual(len(r.headers), 0)

    def testcustomport(self):
        r = parse(DEFAULT_ENV, extra={
            r'SERVER_PORT': r'8000',
        })

        self.assertEqual(r.url, b'http://testserver:8000')
        self.assertEqual(r.baseurl, b'http://testserver:8000')
        self.assertEqual(r.advertisedurl, b'http://testserver:8000')
        self.assertEqual(r.advertisedbaseurl, b'http://testserver:8000')

        r = parse(DEFAULT_ENV, extra={
            r'SERVER_PORT': r'4000',
            r'wsgi.url_scheme': r'https',
        })

        self.assertEqual(r.url, b'https://testserver:4000')
        self.assertEqual(r.baseurl, b'https://testserver:4000')
        self.assertEqual(r.advertisedurl, b'https://testserver:4000')
        self.assertEqual(r.advertisedbaseurl, b'https://testserver:4000')

    def testhttphost(self):
        r = parse(DEFAULT_ENV, extra={
            r'HTTP_HOST': r'altserver',
        })

        self.assertEqual(r.url, b'http://altserver')
        self.assertEqual(r.baseurl, b'http://altserver')
        self.assertEqual(r.advertisedurl, b'http://testserver')
        self.assertEqual(r.advertisedbaseurl, b'http://testserver')

    def testscriptname(self):
        r = parse(DEFAULT_ENV, extra={
            r'SCRIPT_NAME': r'',
        })

        self.assertEqual(r.url, b'http://testserver')
        self.assertEqual(r.baseurl, b'http://testserver')
        self.assertEqual(r.advertisedurl, b'http://testserver')
        self.assertEqual(r.advertisedbaseurl, b'http://testserver')
        self.assertEqual(r.apppath, b'')
        self.assertEqual(r.dispatchparts, [])
        self.assertIsNone(r.dispatchpath)

        r = parse(DEFAULT_ENV, extra={
            r'SCRIPT_NAME': r'/script',
        })

        self.assertEqual(r.url, b'http://testserver/script')
        self.assertEqual(r.baseurl, b'http://testserver')
        self.assertEqual(r.advertisedurl, b'http://testserver/script')
        self.assertEqual(r.advertisedbaseurl, b'http://testserver')
        self.assertEqual(r.apppath, b'/script')
        self.assertEqual(r.dispatchparts, [])
        self.assertIsNone(r.dispatchpath)

        r = parse(DEFAULT_ENV, extra={
            r'SCRIPT_NAME': r'/multiple words',
        })

        self.assertEqual(r.url, b'http://testserver/multiple%20words')
        self.assertEqual(r.baseurl, b'http://testserver')
        self.assertEqual(r.advertisedurl, b'http://testserver/multiple%20words')
        self.assertEqual(r.advertisedbaseurl, b'http://testserver')
        self.assertEqual(r.apppath, b'/multiple words')
        self.assertEqual(r.dispatchparts, [])
        self.assertIsNone(r.dispatchpath)

    def testpathinfo(self):
        r = parse(DEFAULT_ENV, extra={
            r'PATH_INFO': r'',
        })

        self.assertEqual(r.url, b'http://testserver')
        self.assertEqual(r.baseurl, b'http://testserver')
        self.assertEqual(r.advertisedurl, b'http://testserver')
        self.assertEqual(r.advertisedbaseurl, b'http://testserver')
        self.assertEqual(r.apppath, b'')
        self.assertEqual(r.dispatchparts, [])
        self.assertEqual(r.dispatchpath, b'')

        r = parse(DEFAULT_ENV, extra={
            r'PATH_INFO': r'/pathinfo',
        })

        self.assertEqual(r.url, b'http://testserver/pathinfo')
        self.assertEqual(r.baseurl, b'http://testserver')
        self.assertEqual(r.advertisedurl, b'http://testserver/pathinfo')
        self.assertEqual(r.advertisedbaseurl, b'http://testserver')
        self.assertEqual(r.apppath, b'')
        self.assertEqual(r.dispatchparts, [b'pathinfo'])
        self.assertEqual(r.dispatchpath, b'pathinfo')

        r = parse(DEFAULT_ENV, extra={
            r'PATH_INFO': r'/one/two/',
        })

        self.assertEqual(r.url, b'http://testserver/one/two/')
        self.assertEqual(r.baseurl, b'http://testserver')
        self.assertEqual(r.advertisedurl, b'http://testserver/one/two/')
        self.assertEqual(r.advertisedbaseurl, b'http://testserver')
        self.assertEqual(r.apppath, b'')
        self.assertEqual(r.dispatchparts, [b'one', b'two'])
        self.assertEqual(r.dispatchpath, b'one/two')

    def testscriptandpathinfo(self):
        r = parse(DEFAULT_ENV, extra={
            r'SCRIPT_NAME': r'/script',
            r'PATH_INFO': r'/pathinfo',
        })

        self.assertEqual(r.url, b'http://testserver/script/pathinfo')
        self.assertEqual(r.baseurl, b'http://testserver')
        self.assertEqual(r.advertisedurl, b'http://testserver/script/pathinfo')
        self.assertEqual(r.advertisedbaseurl, b'http://testserver')
        self.assertEqual(r.apppath, b'/script')
        self.assertEqual(r.dispatchparts, [b'pathinfo'])
        self.assertEqual(r.dispatchpath, b'pathinfo')

        r = parse(DEFAULT_ENV, extra={
            r'SCRIPT_NAME': r'/script1/script2',
            r'PATH_INFO': r'/path1/path2',
        })

        self.assertEqual(r.url,
                         b'http://testserver/script1/script2/path1/path2')
        self.assertEqual(r.baseurl, b'http://testserver')
        self.assertEqual(r.advertisedurl,
                         b'http://testserver/script1/script2/path1/path2')
        self.assertEqual(r.advertisedbaseurl, b'http://testserver')
        self.assertEqual(r.apppath, b'/script1/script2')
        self.assertEqual(r.dispatchparts, [b'path1', b'path2'])
        self.assertEqual(r.dispatchpath, b'path1/path2')

        r = parse(DEFAULT_ENV, extra={
            r'HTTP_HOST': r'hostserver',
            r'SCRIPT_NAME': r'/script',
            r'PATH_INFO': r'/pathinfo',
        })

        self.assertEqual(r.url, b'http://hostserver/script/pathinfo')
        self.assertEqual(r.baseurl, b'http://hostserver')
        self.assertEqual(r.advertisedurl, b'http://testserver/script/pathinfo')
        self.assertEqual(r.advertisedbaseurl, b'http://testserver')
        self.assertEqual(r.apppath, b'/script')
        self.assertEqual(r.dispatchparts, [b'pathinfo'])
        self.assertEqual(r.dispatchpath, b'pathinfo')

    if not getattr(unittest.TestCase, 'assertRaisesRegex', False):
        # Python 3.7 deprecates the regex*p* version, but 2.7 lacks
        # the regex version.
        assertRaisesRegex = (# camelcase-required
            unittest.TestCase.assertRaisesRegexp)

    def testreponame(self):
        """repository path components get stripped from URL."""

        with self.assertRaisesRegex(error.ProgrammingError,
                                     b'reponame requires PATH_INFO'):
            parse(DEFAULT_ENV, reponame=b'repo')

        with self.assertRaisesRegex(error.ProgrammingError,
                                     b'PATH_INFO does not begin with repo '
                                     b'name'):
            parse(DEFAULT_ENV, reponame=b'repo', extra={
                r'PATH_INFO': r'/pathinfo',
            })

        with self.assertRaisesRegex(error.ProgrammingError,
                                     b'reponame prefix of PATH_INFO'):
            parse(DEFAULT_ENV, reponame=b'repo', extra={
                r'PATH_INFO': r'/repoextra/path',
            })

        r = parse(DEFAULT_ENV, reponame=b'repo', extra={
            r'PATH_INFO': r'/repo/path1/path2',
        })

        self.assertEqual(r.url, b'http://testserver/repo/path1/path2')
        self.assertEqual(r.baseurl, b'http://testserver')
        self.assertEqual(r.advertisedurl, b'http://testserver/repo/path1/path2')
        self.assertEqual(r.advertisedbaseurl, b'http://testserver')
        self.assertEqual(r.apppath, b'/repo')
        self.assertEqual(r.dispatchparts, [b'path1', b'path2'])
        self.assertEqual(r.dispatchpath, b'path1/path2')
        self.assertEqual(r.reponame, b'repo')

        r = parse(DEFAULT_ENV, reponame=b'prefix/repo', extra={
            r'PATH_INFO': r'/prefix/repo/path1/path2',
        })

        self.assertEqual(r.url, b'http://testserver/prefix/repo/path1/path2')
        self.assertEqual(r.baseurl, b'http://testserver')
        self.assertEqual(r.advertisedurl,
                         b'http://testserver/prefix/repo/path1/path2')
        self.assertEqual(r.advertisedbaseurl, b'http://testserver')
        self.assertEqual(r.apppath, b'/prefix/repo')
        self.assertEqual(r.dispatchparts, [b'path1', b'path2'])
        self.assertEqual(r.dispatchpath, b'path1/path2')
        self.assertEqual(r.reponame, b'prefix/repo')

    def testaltbaseurl(self):
        # Simple hostname remap.
        r = parse(DEFAULT_ENV, altbaseurl='http://altserver')

        self.assertEqual(r.url, b'http://testserver')
        self.assertEqual(r.baseurl, b'http://testserver')
        self.assertEqual(r.advertisedurl, b'http://altserver')
        self.assertEqual(r.advertisedbaseurl, b'http://altserver')
        self.assertEqual(r.urlscheme, b'http')
        self.assertEqual(r.apppath, b'')
        self.assertEqual(r.dispatchparts, [])
        self.assertIsNone(r.dispatchpath)
        self.assertIsNone(r.reponame)

        # With a custom port.
        r = parse(DEFAULT_ENV, altbaseurl='http://altserver:8000')
        self.assertEqual(r.url, b'http://testserver')
        self.assertEqual(r.baseurl, b'http://testserver')
        self.assertEqual(r.advertisedurl, b'http://altserver:8000')
        self.assertEqual(r.advertisedbaseurl, b'http://altserver:8000')
        self.assertEqual(r.urlscheme, b'http')
        self.assertEqual(r.apppath, b'')
        self.assertEqual(r.dispatchparts, [])
        self.assertIsNone(r.dispatchpath)
        self.assertIsNone(r.reponame)

        # With a changed protocol.
        r = parse(DEFAULT_ENV, altbaseurl='https://altserver')
        self.assertEqual(r.url, b'http://testserver')
        self.assertEqual(r.baseurl, b'http://testserver')
        self.assertEqual(r.advertisedurl, b'https://altserver')
        self.assertEqual(r.advertisedbaseurl, b'https://altserver')
        # URL scheme is defined as the actual scheme, not advertised.
        self.assertEqual(r.urlscheme, b'http')
        self.assertEqual(r.apppath, b'')
        self.assertEqual(r.dispatchparts, [])
        self.assertIsNone(r.dispatchpath)
        self.assertIsNone(r.reponame)

        # Need to specify explicit port number for proper https:// alt URLs.
        r = parse(DEFAULT_ENV, altbaseurl='https://altserver:443')
        self.assertEqual(r.url, b'http://testserver')
        self.assertEqual(r.baseurl, b'http://testserver')
        self.assertEqual(r.advertisedurl, b'https://altserver')
        self.assertEqual(r.advertisedbaseurl, b'https://altserver')
        self.assertEqual(r.urlscheme, b'http')
        self.assertEqual(r.apppath, b'')
        self.assertEqual(r.dispatchparts, [])
        self.assertIsNone(r.dispatchpath)
        self.assertIsNone(r.reponame)

        # With only PATH_INFO defined.
        r = parse(DEFAULT_ENV, altbaseurl='http://altserver', extra={
            r'PATH_INFO': r'/path1/path2',
        })
        self.assertEqual(r.url, b'http://testserver/path1/path2')
        self.assertEqual(r.baseurl, b'http://testserver')
        self.assertEqual(r.advertisedurl, b'http://altserver/path1/path2')
        self.assertEqual(r.advertisedbaseurl, b'http://altserver')
        self.assertEqual(r.urlscheme, b'http')
        self.assertEqual(r.apppath, b'')
        self.assertEqual(r.dispatchparts, [b'path1', b'path2'])
        self.assertEqual(r.dispatchpath, b'path1/path2')
        self.assertIsNone(r.reponame)

        # Path on alt URL.
        r = parse(DEFAULT_ENV, altbaseurl='http://altserver/altpath')
        self.assertEqual(r.url, b'http://testserver')
        self.assertEqual(r.baseurl, b'http://testserver')
        self.assertEqual(r.advertisedurl, b'http://altserver/altpath')
        self.assertEqual(r.advertisedbaseurl, b'http://altserver')
        self.assertEqual(r.urlscheme, b'http')
        self.assertEqual(r.apppath, b'/altpath')
        self.assertEqual(r.dispatchparts, [])
        self.assertIsNone(r.dispatchpath)
        self.assertIsNone(r.reponame)

        # With a trailing slash.
        r = parse(DEFAULT_ENV, altbaseurl='http://altserver/altpath/')
        self.assertEqual(r.url, b'http://testserver')
        self.assertEqual(r.baseurl, b'http://testserver')
        self.assertEqual(r.advertisedurl, b'http://altserver/altpath/')
        self.assertEqual(r.advertisedbaseurl, b'http://altserver')
        self.assertEqual(r.urlscheme, b'http')
        self.assertEqual(r.apppath, b'/altpath/')
        self.assertEqual(r.dispatchparts, [])
        self.assertIsNone(r.dispatchpath)
        self.assertIsNone(r.reponame)

        # PATH_INFO + path on alt URL.
        r = parse(DEFAULT_ENV, altbaseurl='http://altserver/altpath', extra={
            r'PATH_INFO': r'/path1/path2',
        })
        self.assertEqual(r.url, b'http://testserver/path1/path2')
        self.assertEqual(r.baseurl, b'http://testserver')
        self.assertEqual(r.advertisedurl,
                         b'http://altserver/altpath/path1/path2')
        self.assertEqual(r.advertisedbaseurl, b'http://altserver')
        self.assertEqual(r.urlscheme, b'http')
        self.assertEqual(r.apppath, b'/altpath')
        self.assertEqual(r.dispatchparts, [b'path1', b'path2'])
        self.assertEqual(r.dispatchpath, b'path1/path2')
        self.assertIsNone(r.reponame)

        # PATH_INFO + path on alt URL with trailing slash.
        r = parse(DEFAULT_ENV, altbaseurl='http://altserver/altpath/', extra={
            r'PATH_INFO': r'/path1/path2',
        })
        self.assertEqual(r.url, b'http://testserver/path1/path2')
        self.assertEqual(r.baseurl, b'http://testserver')
        self.assertEqual(r.advertisedurl,
                         b'http://altserver/altpath//path1/path2')
        self.assertEqual(r.advertisedbaseurl, b'http://altserver')
        self.assertEqual(r.urlscheme, b'http')
        self.assertEqual(r.apppath, b'/altpath/')
        self.assertEqual(r.dispatchparts, [b'path1', b'path2'])
        self.assertEqual(r.dispatchpath, b'path1/path2')
        self.assertIsNone(r.reponame)

        # Local SCRIPT_NAME is ignored.
        r = parse(DEFAULT_ENV, altbaseurl='http://altserver', extra={
            r'SCRIPT_NAME': r'/script',
            r'PATH_INFO': r'/path1/path2',
        })
        self.assertEqual(r.url, b'http://testserver/script/path1/path2')
        self.assertEqual(r.baseurl, b'http://testserver')
        self.assertEqual(r.advertisedurl, b'http://altserver/path1/path2')
        self.assertEqual(r.advertisedbaseurl, b'http://altserver')
        self.assertEqual(r.urlscheme, b'http')
        self.assertEqual(r.apppath, b'')
        self.assertEqual(r.dispatchparts, [b'path1', b'path2'])
        self.assertEqual(r.dispatchpath, b'path1/path2')
        self.assertIsNone(r.reponame)

        # Use remote's path for script name, app path
        r = parse(DEFAULT_ENV, altbaseurl='http://altserver/altroot', extra={
            r'SCRIPT_NAME': r'/script',
            r'PATH_INFO': r'/path1/path2',
        })
        self.assertEqual(r.url, b'http://testserver/script/path1/path2')
        self.assertEqual(r.baseurl, b'http://testserver')
        self.assertEqual(r.advertisedurl,
                         b'http://altserver/altroot/path1/path2')
        self.assertEqual(r.advertisedbaseurl, b'http://altserver')
        self.assertEqual(r.urlscheme, b'http')
        self.assertEqual(r.apppath, b'/altroot')
        self.assertEqual(r.dispatchparts, [b'path1', b'path2'])
        self.assertEqual(r.dispatchpath, b'path1/path2')
        self.assertIsNone(r.reponame)

        # reponame is factored in properly.
        r = parse(DEFAULT_ENV, reponame=b'repo',
                  altbaseurl='http://altserver/altroot',
                  extra={
                r'SCRIPT_NAME': r'/script',
                r'PATH_INFO': r'/repo/path1/path2',
            })

        self.assertEqual(r.url, b'http://testserver/script/repo/path1/path2')
        self.assertEqual(r.baseurl, b'http://testserver')
        self.assertEqual(r.advertisedurl,
                         b'http://altserver/altroot/repo/path1/path2')
        self.assertEqual(r.advertisedbaseurl, b'http://altserver')
        self.assertEqual(r.apppath, b'/altroot/repo')
        self.assertEqual(r.dispatchparts, [b'path1', b'path2'])
        self.assertEqual(r.dispatchpath, b'path1/path2')
        self.assertEqual(r.reponame, b'repo')

if __name__ == '__main__':
    import silenttestrunner
    silenttestrunner.main(__name__)
