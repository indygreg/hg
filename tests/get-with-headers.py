#!/usr/bin/env python

"""This does HTTP GET requests given a host:port and path and returns
a subset of the headers plus the body of the result."""

from __future__ import absolute_import, print_function

import argparse
import json
import os
import sys

from mercurial import (
    util,
)

httplib = util.httplib

try:
    import msvcrt
    msvcrt.setmode(sys.stdout.fileno(), os.O_BINARY)
    msvcrt.setmode(sys.stderr.fileno(), os.O_BINARY)
except ImportError:
    pass

parser = argparse.ArgumentParser()
parser.add_argument('--twice', action='store_true')
parser.add_argument('--headeronly', action='store_true')
parser.add_argument('--json', action='store_true')
parser.add_argument('--hgproto')
parser.add_argument('--requestheader', nargs='*', default=[],
                    help='Send an additional HTTP request header. Argument '
                         'value is <header>=<value>')
parser.add_argument('--bodyfile',
                    help='Write HTTP response body to a file')
parser.add_argument('host')
parser.add_argument('path')
parser.add_argument('show', nargs='*')

args = parser.parse_args()

twice = args.twice
headeronly = args.headeronly
formatjson = args.json
hgproto = args.hgproto
requestheaders = args.requestheader

tag = None
def request(host, path, show):
    assert not path.startswith('/'), path
    global tag
    headers = {}
    if tag:
        headers['If-None-Match'] = tag
    if hgproto:
        headers['X-HgProto-1'] = hgproto

    for header in requestheaders:
        key, value = header.split('=', 1)
        headers[key] = value

    conn = httplib.HTTPConnection(host)
    conn.request("GET", '/' + path, None, headers)
    response = conn.getresponse()
    print(response.status, response.reason)
    if show[:1] == ['-']:
        show = sorted(h for h, v in response.getheaders()
                      if h.lower() not in show)
    for h in [h.lower() for h in show]:
        if response.getheader(h, None) is not None:
            print("%s: %s" % (h, response.getheader(h)))
    if not headeronly:
        print()
        data = response.read()

        if args.bodyfile:
            bodyfh = open(args.bodyfile, 'wb')
        else:
            bodyfh = sys.stdout

        # Pretty print JSON. This also has the beneficial side-effect
        # of verifying emitted JSON is well-formed.
        if formatjson:
            # json.dumps() will print trailing newlines. Eliminate them
            # to make tests easier to write.
            data = json.loads(data)
            lines = json.dumps(data, sort_keys=True, indent=2).splitlines()
            for line in lines:
                bodyfh.write(line.rstrip())
                bodyfh.write(b'\n')
        else:
            bodyfh.write(data)

        if args.bodyfile:
            bodyfh.close()

    if twice and response.getheader('ETag', None):
        tag = response.getheader('ETag')

    return response.status

status = request(args.host, args.path, args.show)
if twice:
    status = request(args.host, args.path, args.show)

if 200 <= status <= 305:
    sys.exit(0)
sys.exit(1)
