from __future__ import absolute_import, print_function

import unittest

from mercurial.hgweb import (
    request as requestmod,
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

def parse(env, bodyfh=None, extra=None):
    env = dict(env)
    env.update(extra or {})

    return requestmod.parserequestfromenv(env, bodyfh)

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
        self.assertEqual(r.dispatchpath, b'')
        self.assertFalse(r.havepathinfo)
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
        self.assertEqual(r.dispatchpath, b'')
        self.assertFalse(r.havepathinfo)

        r = parse(DEFAULT_ENV, extra={
            r'SCRIPT_NAME': r'/script',
        })

        self.assertEqual(r.url, b'http://testserver/script')
        self.assertEqual(r.baseurl, b'http://testserver')
        self.assertEqual(r.advertisedurl, b'http://testserver/script')
        self.assertEqual(r.advertisedbaseurl, b'http://testserver')
        self.assertEqual(r.apppath, b'/script')
        self.assertEqual(r.dispatchparts, [])
        self.assertEqual(r.dispatchpath, b'')
        self.assertFalse(r.havepathinfo)

        r = parse(DEFAULT_ENV, extra={
            r'SCRIPT_NAME': r'/multiple words',
        })

        self.assertEqual(r.url, b'http://testserver/multiple%20words')
        self.assertEqual(r.baseurl, b'http://testserver')
        self.assertEqual(r.advertisedurl, b'http://testserver/multiple%20words')
        self.assertEqual(r.advertisedbaseurl, b'http://testserver')
        self.assertEqual(r.apppath, b'/multiple words')
        self.assertEqual(r.dispatchparts, [])
        self.assertEqual(r.dispatchpath, b'')
        self.assertFalse(r.havepathinfo)

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
        self.assertTrue(r.havepathinfo)

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
        self.assertTrue(r.havepathinfo)

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
        self.assertTrue(r.havepathinfo)

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
        self.assertTrue(r.havepathinfo)

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
        self.assertTrue(r.havepathinfo)

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
        self.assertTrue(r.havepathinfo)

    def testreponame(self):
        """REPO_NAME path components get stripped from URL."""
        r = parse(DEFAULT_ENV, extra={
            r'REPO_NAME': r'repo',
            r'PATH_INFO': r'/path1/path2'
        })

        self.assertEqual(r.url, b'http://testserver/path1/path2')
        self.assertEqual(r.baseurl, b'http://testserver')
        self.assertEqual(r.advertisedurl, b'http://testserver/path1/path2')
        self.assertEqual(r.advertisedbaseurl, b'http://testserver')
        self.assertEqual(r.apppath, b'/repo')
        self.assertEqual(r.dispatchparts, [b'path1', b'path2'])
        self.assertEqual(r.dispatchpath, b'path1/path2')
        self.assertTrue(r.havepathinfo)
        self.assertEqual(r.reponame, b'repo')

        r = parse(DEFAULT_ENV, extra={
            r'REPO_NAME': r'repo',
            r'PATH_INFO': r'/repo/path1/path2',
        })

        self.assertEqual(r.url, b'http://testserver/repo/path1/path2')
        self.assertEqual(r.baseurl, b'http://testserver')
        self.assertEqual(r.advertisedurl, b'http://testserver/repo/path1/path2')
        self.assertEqual(r.advertisedbaseurl, b'http://testserver')
        self.assertEqual(r.apppath, b'/repo')
        self.assertEqual(r.dispatchparts, [b'path1', b'path2'])
        self.assertEqual(r.dispatchpath, b'path1/path2')
        self.assertTrue(r.havepathinfo)
        self.assertEqual(r.reponame, b'repo')

        r = parse(DEFAULT_ENV, extra={
            r'REPO_NAME': r'prefix/repo',
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
        self.assertTrue(r.havepathinfo)
        self.assertEqual(r.reponame, b'prefix/repo')

if __name__ == '__main__':
    import silenttestrunner
    silenttestrunner.main(__name__)
