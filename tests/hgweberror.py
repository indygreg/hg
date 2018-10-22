# A dummy extension that installs an hgweb command that throws an Exception.

from __future__ import absolute_import

from mercurial.hgweb import (
    webcommands,
)

def raiseerror(web):
    '''Dummy web command that raises an uncaught Exception.'''

    # Simulate an error after partial response.
    if b'partialresponse' in web.req.qsparams:
        web.res.status = b'200 Script output follows'
        web.res.headers[b'Content-Type'] = b'text/plain'
        web.res.setbodywillwrite()
        list(web.res.sendresponse())
        web.res.getbodyfile().write(b'partial content\n')

    raise AttributeError('I am an uncaught error!')

def extsetup(ui):
    setattr(webcommands, 'raiseerror', raiseerror)
    webcommands.__all__.append(b'raiseerror')
