from __future__ import absolute_import, print_function

from mercurial import demandimport; demandimport.enable()
from mercurial import (
    error,
    pycompat,
    ui as uimod,
    url,
    util,
)
from mercurial.utils import (
    stringutil,
)

urlerr = util.urlerr
urlreq = util.urlreq

class myui(uimod.ui):
    def interactive(self):
        return False

origui = myui.load()

def writeauth(items):
    ui = origui.copy()
    for name, value in items.items():
        ui.setconfig('auth', name, value)
    return ui

def test(auth, urls=None):
    print('CFG:', pycompat.sysstr(stringutil.pprint(auth, bprefix=True)))
    prefixes = set()
    for k in auth:
        prefixes.add(k.split('.', 1)[0])
    for p in prefixes:
        for name in ('.username', '.password'):
            if (p + name) not in auth:
                auth[p + name] = p
    auth = dict((k, v) for k, v in auth.items() if v is not None)

    ui = writeauth(auth)

    def _test(uri):
        print('URI:', uri)
        try:
            pm = url.passwordmgr(ui, urlreq.httppasswordmgrwithdefaultrealm())
            u, authinfo = util.url(uri).authinfo()
            if authinfo is not None:
                pm.add_password(*authinfo)
            print('    ', pm.find_user_password('test', u))
        except error.Abort:
            print('    ','abort')

    if not urls:
        urls = [
            'http://example.org/foo',
            'http://example.org/foo/bar',
            'http://example.org/bar',
            'https://example.org/foo',
            'https://example.org/foo/bar',
            'https://example.org/bar',
            'https://x@example.org/bar',
            'https://y@example.org/bar',
            ]
    for u in urls:
        _test(u)


print('\n*** Test in-uri schemes\n')
test({'x.prefix': 'http://example.org'})
test({'x.prefix': 'https://example.org'})
test({'x.prefix': 'http://example.org', 'x.schemes': 'https'})
test({'x.prefix': 'https://example.org', 'x.schemes': 'http'})

print('\n*** Test separately configured schemes\n')
test({'x.prefix': 'example.org', 'x.schemes': 'http'})
test({'x.prefix': 'example.org', 'x.schemes': 'https'})
test({'x.prefix': 'example.org', 'x.schemes': 'http https'})

print('\n*** Test prefix matching\n')
test({'x.prefix': 'http://example.org/foo',
      'y.prefix': 'http://example.org/bar'})
test({'x.prefix': 'http://example.org/foo',
      'y.prefix': 'http://example.org/foo/bar'})
test({'x.prefix': '*', 'y.prefix': 'https://example.org/bar'})

print('\n*** Test user matching\n')
test({'x.prefix': 'http://example.org/foo',
      'x.username': None,
      'x.password': 'xpassword'},
     urls=['http://y@example.org/foo'])
test({'x.prefix': 'http://example.org/foo',
      'x.username': None,
      'x.password': 'xpassword',
      'y.prefix': 'http://example.org/foo',
      'y.username': 'y',
      'y.password': 'ypassword'},
     urls=['http://y@example.org/foo'])
test({'x.prefix': 'http://example.org/foo/bar',
      'x.username': None,
      'x.password': 'xpassword',
      'y.prefix': 'http://example.org/foo',
      'y.username': 'y',
      'y.password': 'ypassword'},
     urls=['http://y@example.org/foo/bar'])

print('\n*** Test user matching with name in prefix\n')

# prefix, username and URL have the same user
test({'x.prefix': 'https://example.org/foo',
      'x.username': None,
      'x.password': 'xpassword',
      'y.prefix': 'http://y@example.org/foo',
      'y.username': 'y',
      'y.password': 'ypassword'},
     urls=['http://y@example.org/foo'])
# Prefix has a different user from username and URL
test({'y.prefix': 'http://z@example.org/foo',
      'y.username': 'y',
      'y.password': 'ypassword'},
     urls=['http://y@example.org/foo'])
# Prefix has a different user from URL; no username
test({'y.prefix': 'http://z@example.org/foo',
      'y.password': 'ypassword'},
     urls=['http://y@example.org/foo'])
# Prefix and URL have same user, but doesn't match username
test({'y.prefix': 'http://y@example.org/foo',
      'y.username': 'z',
      'y.password': 'ypassword'},
     urls=['http://y@example.org/foo'])
# Prefix and URL have the same user; no username
test({'y.prefix': 'http://y@example.org/foo',
      'y.password': 'ypassword'},
     urls=['http://y@example.org/foo'])
# Prefix user, but no URL user or username
test({'y.prefix': 'http://y@example.org/foo',
      'y.password': 'ypassword'},
     urls=['http://example.org/foo'])

def testauthinfo(fullurl, authurl):
    print('URIs:', fullurl, authurl)
    pm = urlreq.httppasswordmgrwithdefaultrealm()
    pm.add_password(*util.url(fullurl).authinfo()[1])
    print(pm.find_user_password('test', authurl))

print('\n*** Test urllib2 and util.url\n')
testauthinfo('http://user@example.com:8080/foo', 'http://example.com:8080/foo')
