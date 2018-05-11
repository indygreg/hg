# coding=utf-8
from __future__ import absolute_import, print_function

import doctest
import os

def check(a, b):
    if a != b:
        print((a, b))

def cert(cn):
    return {'subject': ((('commonName', cn),),)}

from mercurial import (
    sslutil,
)

_verifycert = sslutil._verifycert
# Test non-wildcard certificates
check(_verifycert(cert('example.com'), 'example.com'),
      None)
check(_verifycert(cert('example.com'), 'www.example.com'),
      b'certificate is for example.com')
check(_verifycert(cert('www.example.com'), 'example.com'),
      b'certificate is for www.example.com')

# Test wildcard certificates
check(_verifycert(cert('*.example.com'), 'www.example.com'),
      None)
check(_verifycert(cert('*.example.com'), 'example.com'),
      b'certificate is for *.example.com')
check(_verifycert(cert('*.example.com'), 'w.w.example.com'),
      b'certificate is for *.example.com')

# Test subjectAltName
san_cert = {'subject': ((('commonName', 'example.com'),),),
            'subjectAltName': (('DNS', '*.example.net'),
                               ('DNS', 'example.net'))}
check(_verifycert(san_cert, 'example.net'),
      None)
check(_verifycert(san_cert, 'foo.example.net'),
      None)
# no fallback to subject commonName when subjectAltName has DNS
check(_verifycert(san_cert, 'example.com'),
      b'certificate is for *.example.net, example.net')
# fallback to subject commonName when no DNS in subjectAltName
san_cert = {'subject': ((('commonName', 'example.com'),),),
            'subjectAltName': (('IP Address', '8.8.8.8'),)}
check(_verifycert(san_cert, 'example.com'), None)

# Avoid some pitfalls
check(_verifycert(cert('*.foo'), 'foo'),
      b'certificate is for *.foo')
check(_verifycert(cert('*o'), 'foo'), None)

check(_verifycert({'subject': ()},
                  'example.com'),
      b'no commonName or subjectAltName found in certificate')
check(_verifycert(None, 'example.com'),
      b'no certificate received')

# Unicode (IDN) certname isn't supported
check(_verifycert(cert(u'\u4f8b.jp'), 'example.jp'),
      b'IDN in certificate not supported')

# The following tests are from CPython's test_ssl.py.
check(_verifycert(cert('example.com'), 'example.com'), None)
check(_verifycert(cert('example.com'), 'ExAmple.cOm'), None)
check(_verifycert(cert('example.com'), 'www.example.com'),
      b'certificate is for example.com')
check(_verifycert(cert('example.com'), '.example.com'),
      b'certificate is for example.com')
check(_verifycert(cert('example.com'), 'example.org'),
      b'certificate is for example.com')
check(_verifycert(cert('example.com'), 'exampleXcom'),
      b'certificate is for example.com')
check(_verifycert(cert('*.a.com'), 'foo.a.com'), None)
check(_verifycert(cert('*.a.com'), 'bar.foo.a.com'),
      b'certificate is for *.a.com')
check(_verifycert(cert('*.a.com'), 'a.com'),
      b'certificate is for *.a.com')
check(_verifycert(cert('*.a.com'), 'Xa.com'),
      b'certificate is for *.a.com')
check(_verifycert(cert('*.a.com'), '.a.com'),
      b'certificate is for *.a.com')

# only match one left-most wildcard
check(_verifycert(cert('f*.com'), 'foo.com'), None)
check(_verifycert(cert('f*.com'), 'f.com'), None)
check(_verifycert(cert('f*.com'), 'bar.com'),
      b'certificate is for f*.com')
check(_verifycert(cert('f*.com'), 'foo.a.com'),
      b'certificate is for f*.com')
check(_verifycert(cert('f*.com'), 'bar.foo.com'),
      b'certificate is for f*.com')

# NULL bytes are bad, CVE-2013-4073
check(_verifycert(cert('null.python.org\x00example.org'),
                  'null.python.org\x00example.org'), None)
check(_verifycert(cert('null.python.org\x00example.org'),
                  'example.org'),
      b'certificate is for null.python.org\x00example.org')
check(_verifycert(cert('null.python.org\x00example.org'),
                  'null.python.org'),
      b'certificate is for null.python.org\x00example.org')

# error cases with wildcards
check(_verifycert(cert('*.*.a.com'), 'bar.foo.a.com'),
      b'certificate is for *.*.a.com')
check(_verifycert(cert('*.*.a.com'), 'a.com'),
      b'certificate is for *.*.a.com')
check(_verifycert(cert('*.*.a.com'), 'Xa.com'),
      b'certificate is for *.*.a.com')
check(_verifycert(cert('*.*.a.com'), '.a.com'),
      b'certificate is for *.*.a.com')

check(_verifycert(cert('a.*.com'), 'a.foo.com'),
      b'certificate is for a.*.com')
check(_verifycert(cert('a.*.com'), 'a..com'),
      b'certificate is for a.*.com')
check(_verifycert(cert('a.*.com'), 'a.com'),
      b'certificate is for a.*.com')

# wildcard doesn't match IDNA prefix 'xn--'
idna = u'püthon.python.org'.encode('idna').decode('ascii')
check(_verifycert(cert(idna), idna), None)
check(_verifycert(cert('x*.python.org'), idna),
      b'certificate is for x*.python.org')
check(_verifycert(cert('xn--p*.python.org'), idna),
      b'certificate is for xn--p*.python.org')

# wildcard in first fragment and  IDNA A-labels in sequent fragments
# are supported.
idna = u'www*.pythön.org'.encode('idna').decode('ascii')
check(_verifycert(cert(idna),
                  u'www.pythön.org'.encode('idna').decode('ascii')),
      None)
check(_verifycert(cert(idna),
                  u'www1.pythön.org'.encode('idna').decode('ascii')),
      None)
check(_verifycert(cert(idna),
                  u'ftp.pythön.org'.encode('idna').decode('ascii')),
      b'certificate is for www*.xn--pythn-mua.org')
check(_verifycert(cert(idna),
                  u'pythön.org'.encode('idna').decode('ascii')),
      b'certificate is for www*.xn--pythn-mua.org')

c = {
    'notAfter': 'Jun 26 21:41:46 2011 GMT',
    'subject': (((u'commonName', u'linuxfrz.org'),),),
    'subjectAltName': (
        ('DNS', 'linuxfr.org'),
        ('DNS', 'linuxfr.com'),
        ('othername', '<unsupported>'),
    )
}
check(_verifycert(c, 'linuxfr.org'), None)
check(_verifycert(c, 'linuxfr.com'), None)
# Not a "DNS" entry
check(_verifycert(c, '<unsupported>'),
      b'certificate is for linuxfr.org, linuxfr.com')
# When there is a subjectAltName, commonName isn't used
check(_verifycert(c, 'linuxfrz.org'),
      b'certificate is for linuxfr.org, linuxfr.com')

# A pristine real-world example
c = {
    'notAfter': 'Dec 18 23:59:59 2011 GMT',
    'subject': (
        ((u'countryName', u'US'),),
        ((u'stateOrProvinceName', u'California'),),
        ((u'localityName', u'Mountain View'),),
        ((u'organizationName', u'Google Inc'),),
        ((u'commonName', u'mail.google.com'),),
    ),
}
check(_verifycert(c, 'mail.google.com'), None)
check(_verifycert(c, 'gmail.com'), b'certificate is for mail.google.com')

# Only commonName is considered
check(_verifycert(c, 'California'), b'certificate is for mail.google.com')

# Neither commonName nor subjectAltName
c = {
    'notAfter': 'Dec 18 23:59:59 2011 GMT',
    'subject': (
        ((u'countryName', u'US'),),
        ((u'stateOrProvinceName', u'California'),),
        ((u'localityName', u'Mountain View'),),
        ((u'organizationName', u'Google Inc'),),
    ),
}
check(_verifycert(c, 'mail.google.com'),
      b'no commonName or subjectAltName found in certificate')

# No DNS entry in subjectAltName but a commonName
c = {
    'notAfter': 'Dec 18 23:59:59 2099 GMT',
    'subject': (
        ((u'countryName', u'US'),),
        ((u'stateOrProvinceName', u'California'),),
        ((u'localityName', u'Mountain View'),),
        ((u'commonName', u'mail.google.com'),),
    ),
    'subjectAltName': (('othername', 'blabla'),),
}
check(_verifycert(c, 'mail.google.com'), None)

# No DNS entry subjectAltName and no commonName
c = {
    'notAfter': 'Dec 18 23:59:59 2099 GMT',
    'subject': (
        ((u'countryName', u'US'),),
        ((u'stateOrProvinceName', u'California'),),
        ((u'localityName', u'Mountain View'),),
        ((u'organizationName', u'Google Inc'),),
    ),
    'subjectAltName': (('othername', 'blabla'),),
}
check(_verifycert(c, 'google.com'),
      b'no commonName or subjectAltName found in certificate')

# Empty cert / no cert
check(_verifycert(None, 'example.com'), b'no certificate received')
check(_verifycert({}, 'example.com'), b'no certificate received')

# avoid denials of service by refusing more than one
# wildcard per fragment.
check(_verifycert({'subject': (((u'commonName', u'a*b.com'),),)},
                  'axxb.com'), None)
check(_verifycert({'subject': (((u'commonName', u'a*b.co*'),),)},
                  'axxb.com'), b'certificate is for a*b.co*')
check(_verifycert({'subject': (((u'commonName', u'a*b*.com'),),)},
                  'axxbxxc.com'),
      b'too many wildcards in certificate DNS name: a*b*.com')

def test_url():
    """
    >>> from mercurial import error, pycompat
    >>> from mercurial.util import url
    >>> from mercurial.utils.stringutil import forcebytestr

    This tests for edge cases in url.URL's parsing algorithm. Most of
    these aren't useful for documentation purposes, so they aren't
    part of the class's doc tests.

    Query strings and fragments:

    >>> url(b'http://host/a?b#c')
    <url scheme: 'http', host: 'host', path: 'a', query: 'b', fragment: 'c'>
    >>> url(b'http://host/a?')
    <url scheme: 'http', host: 'host', path: 'a'>
    >>> url(b'http://host/a#b#c')
    <url scheme: 'http', host: 'host', path: 'a', fragment: 'b#c'>
    >>> url(b'http://host/a#b?c')
    <url scheme: 'http', host: 'host', path: 'a', fragment: 'b?c'>
    >>> url(b'http://host/?a#b')
    <url scheme: 'http', host: 'host', path: '', query: 'a', fragment: 'b'>
    >>> url(b'http://host/?a#b', parsequery=False)
    <url scheme: 'http', host: 'host', path: '?a', fragment: 'b'>
    >>> url(b'http://host/?a#b', parsefragment=False)
    <url scheme: 'http', host: 'host', path: '', query: 'a#b'>
    >>> url(b'http://host/?a#b', parsequery=False, parsefragment=False)
    <url scheme: 'http', host: 'host', path: '?a#b'>

    IPv6 addresses:

    >>> url(b'ldap://[2001:db8::7]/c=GB?objectClass?one')
    <url scheme: 'ldap', host: '[2001:db8::7]', path: 'c=GB',
         query: 'objectClass?one'>
    >>> url(b'ldap://joe:xxx@[2001:db8::7]:80/c=GB?objectClass?one')
    <url scheme: 'ldap', user: 'joe', passwd: 'xxx', host: '[2001:db8::7]',
         port: '80', path: 'c=GB', query: 'objectClass?one'>

    Missing scheme, host, etc.:

    >>> url(b'://192.0.2.16:80/')
    <url path: '://192.0.2.16:80/'>
    >>> url(b'https://mercurial-scm.org')
    <url scheme: 'https', host: 'mercurial-scm.org'>
    >>> url(b'/foo')
    <url path: '/foo'>
    >>> url(b'bundle:/foo')
    <url scheme: 'bundle', path: '/foo'>
    >>> url(b'a?b#c')
    <url path: 'a?b', fragment: 'c'>
    >>> url(b'http://x.com?arg=/foo')
    <url scheme: 'http', host: 'x.com', query: 'arg=/foo'>
    >>> url(b'http://joe:xxx@/foo')
    <url scheme: 'http', user: 'joe', passwd: 'xxx', path: 'foo'>

    Just a scheme and a path:

    >>> url(b'mailto:John.Doe@example.com')
    <url scheme: 'mailto', path: 'John.Doe@example.com'>
    >>> url(b'a:b:c:d')
    <url path: 'a:b:c:d'>
    >>> url(b'aa:bb:cc:dd')
    <url scheme: 'aa', path: 'bb:cc:dd'>

    SSH examples:

    >>> url(b'ssh://joe@host//home/joe')
    <url scheme: 'ssh', user: 'joe', host: 'host', path: '/home/joe'>
    >>> url(b'ssh://joe:xxx@host/src')
    <url scheme: 'ssh', user: 'joe', passwd: 'xxx', host: 'host', path: 'src'>
    >>> url(b'ssh://joe:xxx@host')
    <url scheme: 'ssh', user: 'joe', passwd: 'xxx', host: 'host'>
    >>> url(b'ssh://joe@host')
    <url scheme: 'ssh', user: 'joe', host: 'host'>
    >>> url(b'ssh://host')
    <url scheme: 'ssh', host: 'host'>
    >>> url(b'ssh://')
    <url scheme: 'ssh'>
    >>> url(b'ssh:')
    <url scheme: 'ssh'>

    Non-numeric port:

    >>> url(b'http://example.com:dd')
    <url scheme: 'http', host: 'example.com', port: 'dd'>
    >>> url(b'ssh://joe:xxx@host:ssh/foo')
    <url scheme: 'ssh', user: 'joe', passwd: 'xxx', host: 'host', port: 'ssh',
         path: 'foo'>

    Bad authentication credentials:

    >>> url(b'http://joe@joeville:123@4:@host/a?b#c')
    <url scheme: 'http', user: 'joe@joeville', passwd: '123@4:',
         host: 'host', path: 'a', query: 'b', fragment: 'c'>
    >>> url(b'http://!*#?/@!*#?/:@host/a?b#c')
    <url scheme: 'http', host: '!*', fragment: '?/@!*#?/:@host/a?b#c'>
    >>> url(b'http://!*#?@!*#?:@host/a?b#c')
    <url scheme: 'http', host: '!*', fragment: '?@!*#?:@host/a?b#c'>
    >>> url(b'http://!*@:!*@@host/a?b#c')
    <url scheme: 'http', user: '!*@', passwd: '!*@', host: 'host',
         path: 'a', query: 'b', fragment: 'c'>

    File paths:

    >>> url(b'a/b/c/d.g.f')
    <url path: 'a/b/c/d.g.f'>
    >>> url(b'/x///z/y/')
    <url path: '/x///z/y/'>
    >>> url(b'/foo:bar')
    <url path: '/foo:bar'>
    >>> url(b'\\\\foo:bar')
    <url path: '\\\\foo:bar'>
    >>> url(b'./foo:bar')
    <url path: './foo:bar'>

    Non-localhost file URL:

    >>> try:
    ...   u = url(b'file://mercurial-scm.org/foo')
    ... except error.Abort as e:
    ...   forcebytestr(e)
    'file:// URLs can only refer to localhost'

    Empty URL:

    >>> u = url(b'')
    >>> u
    <url path: ''>
    >>> str(u)
    ''

    Empty path with query string:

    >>> str(url(b'http://foo/?bar'))
    'http://foo/?bar'

    Invalid path:

    >>> u = url(b'http://foo/bar')
    >>> u.path = b'bar'
    >>> str(u)
    'http://foo/bar'

    >>> u = url(b'file:/foo/bar/baz')
    >>> u
    <url scheme: 'file', path: '/foo/bar/baz'>
    >>> str(u)
    'file:///foo/bar/baz'
    >>> pycompat.bytestr(u.localpath())
    '/foo/bar/baz'

    >>> u = url(b'file:///foo/bar/baz')
    >>> u
    <url scheme: 'file', path: '/foo/bar/baz'>
    >>> str(u)
    'file:///foo/bar/baz'
    >>> pycompat.bytestr(u.localpath())
    '/foo/bar/baz'

    >>> u = url(b'file:///f:oo/bar/baz')
    >>> u
    <url scheme: 'file', path: 'f:oo/bar/baz'>
    >>> str(u)
    'file:///f:oo/bar/baz'
    >>> pycompat.bytestr(u.localpath())
    'f:oo/bar/baz'

    >>> u = url(b'file://localhost/f:oo/bar/baz')
    >>> u
    <url scheme: 'file', host: 'localhost', path: 'f:oo/bar/baz'>
    >>> str(u)
    'file://localhost/f:oo/bar/baz'
    >>> pycompat.bytestr(u.localpath())
    'f:oo/bar/baz'

    >>> u = url(b'file:foo/bar/baz')
    >>> u
    <url scheme: 'file', path: 'foo/bar/baz'>
    >>> str(u)
    'file:foo/bar/baz'
    >>> pycompat.bytestr(u.localpath())
    'foo/bar/baz'
    """

if 'TERM' in os.environ:
    del os.environ['TERM']

doctest.testmod(optionflags=doctest.NORMALIZE_WHITESPACE)
