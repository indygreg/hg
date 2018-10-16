# A minimal client for Mercurial's command server

from __future__ import absolute_import, print_function
import os
import signal
import socket
import struct
import subprocess
import sys
import time

try:
    import cStringIO as io
    stringio = io.StringIO
except ImportError:
    import io
    stringio = io.StringIO

def connectpipe(path=None):
    cmdline = [b'hg', b'serve', b'--cmdserver', b'pipe']
    if path:
        cmdline += [b'-R', path]

    server = subprocess.Popen(cmdline, stdin=subprocess.PIPE,
                              stdout=subprocess.PIPE)

    return server

class unixconnection(object):
    def __init__(self, sockpath):
        self.sock = sock = socket.socket(socket.AF_UNIX)
        sock.connect(sockpath)
        self.stdin = sock.makefile('wb')
        self.stdout = sock.makefile('rb')

    def wait(self):
        self.stdin.close()
        self.stdout.close()
        self.sock.close()

class unixserver(object):
    def __init__(self, sockpath, logpath=None, repopath=None):
        self.sockpath = sockpath
        cmdline = [b'hg', b'serve', b'--cmdserver', b'unix', b'-a', sockpath]
        if repopath:
            cmdline += [b'-R', repopath]
        if logpath:
            stdout = open(logpath, 'a')
            stderr = subprocess.STDOUT
        else:
            stdout = stderr = None
        self.server = subprocess.Popen(cmdline, stdout=stdout, stderr=stderr)
        # wait for listen()
        while self.server.poll() is None:
            if os.path.exists(sockpath):
                break
            time.sleep(0.1)

    def connect(self):
        return unixconnection(self.sockpath)

    def shutdown(self):
        os.kill(self.server.pid, signal.SIGTERM)
        self.server.wait()

def writeblock(server, data):
    server.stdin.write(struct.pack(b'>I', len(data)))
    server.stdin.write(data)
    server.stdin.flush()

def readchannel(server):
    data = server.stdout.read(5)
    if not data:
        raise EOFError
    channel, length = struct.unpack('>cI', data)
    if channel in b'IL':
        return channel, length
    else:
        return channel, server.stdout.read(length)

def sep(text):
    return text.replace(b'\\', b'/')

def runcommand(server, args, output=sys.stdout, error=sys.stderr, input=None,
               outfilter=lambda x: x):
    print(b'*** runcommand', b' '.join(args))
    sys.stdout.flush()
    server.stdin.write(b'runcommand\n')
    writeblock(server, b'\0'.join(args))

    if not input:
        input = stringio()

    while True:
        ch, data = readchannel(server)
        if ch == b'o':
            output.write(outfilter(data))
            output.flush()
        elif ch == b'e':
            error.write(data)
            error.flush()
        elif ch == b'I':
            writeblock(server, input.read(data))
        elif ch == b'L':
            writeblock(server, input.readline(data))
        elif ch == b'r':
            ret, = struct.unpack('>i', data)
            if ret != 0:
                print(b' [%d]' % ret)
            return ret
        else:
            print(b"unexpected channel %c: %r" % (ch, data))
            if ch.isupper():
                return

def check(func, connect=connectpipe):
    sys.stdout.flush()
    server = connect()
    try:
        return func(server)
    finally:
        server.stdin.close()
        server.wait()
