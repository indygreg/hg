# Copyright 21 May 2005 - (c) 2005 Jake Edge <jake@edge2.net>
# Copyright 2005-2007 Matt Mackall <mpm@selenic.com>
#
# This software may be used and distributed according to the terms of the
# GNU General Public License version 2 or any later version.

from __future__ import absolute_import

import abc
import cgi
import struct
import sys

from .i18n import _
from . import (
    encoding,
    error,
    hook,
    pycompat,
    util,
    wireproto,
)

stringio = util.stringio

urlerr = util.urlerr
urlreq = util.urlreq

HTTP_OK = 200

HGTYPE = 'application/mercurial-0.1'
HGTYPE2 = 'application/mercurial-0.2'
HGERRTYPE = 'application/hg-error'

class abstractserverproto(object):
    """abstract class that summarizes the protocol API

    Used as reference and documentation.
    """

    __metaclass__ = abc.ABCMeta

    @abc.abstractproperty
    def name(self):
        """The name of the protocol implementation.

        Used for uniquely identifying the transport type.
        """

    @abc.abstractmethod
    def getargs(self, args):
        """return the value for arguments in <args>

        returns a list of values (same order as <args>)"""

    @abc.abstractmethod
    def getfile(self, fp):
        """write the whole content of a file into a file like object

        The file is in the form::

            (<chunk-size>\n<chunk>)+0\n

        chunk size is the ascii version of the int.
        """

    @abc.abstractmethod
    def redirect(self):
        """may setup interception for stdout and stderr

        See also the `restore` method."""

    # If the `redirect` function does install interception, the `restore`
    # function MUST be defined. If interception is not used, this function
    # MUST NOT be defined.
    #
    # left commented here on purpose
    #
    #def restore(self):
    #    """reinstall previous stdout and stderr and return intercepted stdout
    #    """
    #    raise NotImplementedError()

def decodevaluefromheaders(req, headerprefix):
    """Decode a long value from multiple HTTP request headers.

    Returns the value as a bytes, not a str.
    """
    chunks = []
    i = 1
    prefix = headerprefix.upper().replace(r'-', r'_')
    while True:
        v = req.env.get(r'HTTP_%s_%d' % (prefix, i))
        if v is None:
            break
        chunks.append(pycompat.bytesurl(v))
        i += 1

    return ''.join(chunks)

class webproto(abstractserverproto):
    def __init__(self, req, ui):
        self._req = req
        self._ui = ui

    @property
    def name(self):
        return 'http'

    def getargs(self, args):
        knownargs = self._args()
        data = {}
        keys = args.split()
        for k in keys:
            if k == '*':
                star = {}
                for key in knownargs.keys():
                    if key != 'cmd' and key not in keys:
                        star[key] = knownargs[key][0]
                data['*'] = star
            else:
                data[k] = knownargs[k][0]
        return [data[k] for k in keys]

    def _args(self):
        args = self._req.form.copy()
        if pycompat.ispy3:
            args = {k.encode('ascii'): [v.encode('ascii') for v in vs]
                    for k, vs in args.items()}
        postlen = int(self._req.env.get(r'HTTP_X_HGARGS_POST', 0))
        if postlen:
            args.update(cgi.parse_qs(
                self._req.read(postlen), keep_blank_values=True))
            return args

        argvalue = decodevaluefromheaders(self._req, r'X-HgArg')
        args.update(cgi.parse_qs(argvalue, keep_blank_values=True))
        return args

    def getfile(self, fp):
        length = int(self._req.env[r'CONTENT_LENGTH'])
        # If httppostargs is used, we need to read Content-Length
        # minus the amount that was consumed by args.
        length -= int(self._req.env.get(r'HTTP_X_HGARGS_POST', 0))
        for s in util.filechunkiter(self._req, limit=length):
            fp.write(s)

    def redirect(self):
        self._oldio = self._ui.fout, self._ui.ferr
        self._ui.ferr = self._ui.fout = stringio()

    def restore(self):
        val = self._ui.fout.getvalue()
        self._ui.ferr, self._ui.fout = self._oldio
        return val

    def _client(self):
        return 'remote:%s:%s:%s' % (
            self._req.env.get('wsgi.url_scheme') or 'http',
            urlreq.quote(self._req.env.get('REMOTE_HOST', '')),
            urlreq.quote(self._req.env.get('REMOTE_USER', '')))

    def responsetype(self, prefer_uncompressed):
        """Determine the appropriate response type and compression settings.

        Returns a tuple of (mediatype, compengine, engineopts).
        """
        # Determine the response media type and compression engine based
        # on the request parameters.
        protocaps = decodevaluefromheaders(self._req, r'X-HgProto').split(' ')

        if '0.2' in protocaps:
            # All clients are expected to support uncompressed data.
            if prefer_uncompressed:
                return HGTYPE2, util._noopengine(), {}

            # Default as defined by wire protocol spec.
            compformats = ['zlib', 'none']
            for cap in protocaps:
                if cap.startswith('comp='):
                    compformats = cap[5:].split(',')
                    break

            # Now find an agreed upon compression format.
            for engine in wireproto.supportedcompengines(self._ui, self,
                                                         util.SERVERROLE):
                if engine.wireprotosupport().name in compformats:
                    opts = {}
                    level = self._ui.configint('server',
                                              '%slevel' % engine.name())
                    if level is not None:
                        opts['level'] = level

                    return HGTYPE2, engine, opts

            # No mutually supported compression format. Fall back to the
            # legacy protocol.

        # Don't allow untrusted settings because disabling compression or
        # setting a very high compression level could lead to flooding
        # the server's network or CPU.
        opts = {'level': self._ui.configint('server', 'zliblevel')}
        return HGTYPE, util.compengines['zlib'], opts

def iscmd(cmd):
    return cmd in wireproto.commands

def callhttp(repo, req, cmd):
    proto = webproto(req, repo.ui)

    def genversion2(gen, engine, engineopts):
        # application/mercurial-0.2 always sends a payload header
        # identifying the compression engine.
        name = engine.wireprotosupport().name
        assert 0 < len(name) < 256
        yield struct.pack('B', len(name))
        yield name

        for chunk in gen:
            yield chunk

    rsp = wireproto.dispatch(repo, proto, cmd)
    if isinstance(rsp, bytes):
        req.respond(HTTP_OK, HGTYPE, body=rsp)
        return []
    elif isinstance(rsp, wireproto.streamres_legacy):
        gen = rsp.gen
        req.respond(HTTP_OK, HGTYPE)
        return gen
    elif isinstance(rsp, wireproto.streamres):
        gen = rsp.gen

        # This code for compression should not be streamres specific. It
        # is here because we only compress streamres at the moment.
        mediatype, engine, engineopts = proto.responsetype(
            rsp.prefer_uncompressed)
        gen = engine.compressstream(gen, engineopts)

        if mediatype == HGTYPE2:
            gen = genversion2(gen, engine, engineopts)

        req.respond(HTTP_OK, mediatype)
        return gen
    elif isinstance(rsp, wireproto.pushres):
        val = proto.restore()
        rsp = '%d\n%s' % (rsp.res, val)
        req.respond(HTTP_OK, HGTYPE, body=rsp)
        return []
    elif isinstance(rsp, wireproto.pusherr):
        # drain the incoming bundle
        req.drain()
        proto.restore()
        rsp = '0\n%s\n' % rsp.res
        req.respond(HTTP_OK, HGTYPE, body=rsp)
        return []
    elif isinstance(rsp, wireproto.ooberror):
        rsp = rsp.message
        req.respond(HTTP_OK, HGERRTYPE, body=rsp)
        return []
    raise error.ProgrammingError('hgweb.protocol internal failure', rsp)

class sshserver(abstractserverproto):
    def __init__(self, ui, repo):
        self._ui = ui
        self._repo = repo
        self._fin = ui.fin
        self._fout = ui.fout

        hook.redirect(True)
        ui.fout = repo.ui.fout = ui.ferr

        # Prevent insertion/deletion of CRs
        util.setbinary(self._fin)
        util.setbinary(self._fout)

    @property
    def name(self):
        return 'ssh'

    def getargs(self, args):
        data = {}
        keys = args.split()
        for n in xrange(len(keys)):
            argline = self._fin.readline()[:-1]
            arg, l = argline.split()
            if arg not in keys:
                raise error.Abort(_("unexpected parameter %r") % arg)
            if arg == '*':
                star = {}
                for k in xrange(int(l)):
                    argline = self._fin.readline()[:-1]
                    arg, l = argline.split()
                    val = self._fin.read(int(l))
                    star[arg] = val
                data['*'] = star
            else:
                val = self._fin.read(int(l))
                data[arg] = val
        return [data[k] for k in keys]

    def getfile(self, fpout):
        self._sendresponse('')
        count = int(self._fin.readline())
        while count:
            fpout.write(self._fin.read(count))
            count = int(self._fin.readline())

    def redirect(self):
        pass

    def _sendresponse(self, v):
        self._fout.write("%d\n" % len(v))
        self._fout.write(v)
        self._fout.flush()

    def _sendstream(self, source):
        write = self._fout.write
        for chunk in source.gen:
            write(chunk)
        self._fout.flush()

    def _sendpushresponse(self, rsp):
        self._sendresponse('')
        self._sendresponse(str(rsp.res))

    def _sendpusherror(self, rsp):
        self._sendresponse(rsp.res)

    def _sendooberror(self, rsp):
        self._ui.ferr.write('%s\n-\n' % rsp.message)
        self._ui.ferr.flush()
        self._fout.write('\n')
        self._fout.flush()

    def serve_forever(self):
        while self.serve_one():
            pass
        sys.exit(0)

    _handlers = {
        str: _sendresponse,
        wireproto.streamres: _sendstream,
        wireproto.streamres_legacy: _sendstream,
        wireproto.pushres: _sendpushresponse,
        wireproto.pusherr: _sendpusherror,
        wireproto.ooberror: _sendooberror,
    }

    def serve_one(self):
        cmd = self._fin.readline()[:-1]
        if cmd and cmd in wireproto.commands:
            rsp = wireproto.dispatch(self._repo, self, cmd)
            self._handlers[rsp.__class__](self, rsp)
        elif cmd:
            self._sendresponse("")
        return cmd != ''

    def _client(self):
        client = encoding.environ.get('SSH_CLIENT', '').split(' ', 1)[0]
        return 'remote:ssh:' + client