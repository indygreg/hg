  $ . $TESTDIR/wireprotohelpers.sh
  $ cat >> $HGRCPATH << EOF
  > [extensions]
  > blackbox =
  > [blackbox]
  > track = simplecache
  > EOF
  $ hg init server
  $ enablehttpv2 server
  $ cd server
  $ cat >> .hg/hgrc << EOF
  > [extensions]
  > simplecache = $TESTDIR/wireprotosimplecache.py
  > EOF

  $ echo a0 > a
  $ echo b0 > b
  $ hg -q commit -A -m 'commit 0'
  $ echo a1 > a
  $ hg commit -m 'commit 1'
  $ echo b1 > b
  $ hg commit -m 'commit 2'
  $ echo a2 > a
  $ echo b2 > b
  $ hg commit -m 'commit 3'

  $ hg log -G -T '{rev}:{node} {desc}'
  @  3:50590a86f3ff5d1e9a1624a7a6957884565cc8e8 commit 3
  |
  o  2:4d01eda50c6ac5f7e89cbe1880143a32f559c302 commit 2
  |
  o  1:4432d83626e8a98655f062ec1f2a43b07f7fbbb0 commit 1
  |
  o  0:3390ef850073fbc2f0dfff2244342c8e9229013a commit 0
  

  $ hg --debug debugindex -m
     rev linkrev nodeid                                   p1                                       p2
       0       0 992f4779029a3df8d0666d00bb924f69634e2641 0000000000000000000000000000000000000000 0000000000000000000000000000000000000000
       1       1 a988fb43583e871d1ed5750ee074c6d840bbbfc8 992f4779029a3df8d0666d00bb924f69634e2641 0000000000000000000000000000000000000000
       2       2 a8853dafacfca6fc807055a660d8b835141a3bb4 a988fb43583e871d1ed5750ee074c6d840bbbfc8 0000000000000000000000000000000000000000
       3       3 3fe11dfbb13645782b0addafbe75a87c210ffddc a8853dafacfca6fc807055a660d8b835141a3bb4 0000000000000000000000000000000000000000

  $ hg serve -p $HGPORT -d --pid-file hg.pid -E error.log
  $ cat hg.pid > $DAEMON_PIDS

Performing the same request should result in same result, with 2nd response
coming from cache.

  $ sendhttpv2peer << EOF
  > command manifestdata
  >     nodes eval:[b'\x99\x2f\x47\x79\x02\x9a\x3d\xf8\xd0\x66\x6d\x00\xbb\x92\x4f\x69\x63\x4e\x26\x41']
  >     tree eval:b''
  >     fields eval:[b'parents']
  > EOF
  creating http peer for wire protocol version 2
  sending manifestdata command
  response: gen[
    {
      b'totalitems': 1
    },
    {
      b'node': b'\x99/Gy\x02\x9a=\xf8\xd0fm\x00\xbb\x92OicN&A',
      b'parents': [
        b'\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00',
        b'\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00'
      ]
    }
  ]

  $ sendhttpv2peer << EOF
  > command manifestdata
  >     nodes eval:[b'\x99\x2f\x47\x79\x02\x9a\x3d\xf8\xd0\x66\x6d\x00\xbb\x92\x4f\x69\x63\x4e\x26\x41']
  >     tree eval:b''
  >     fields eval:[b'parents']
  > EOF
  creating http peer for wire protocol version 2
  sending manifestdata command
  response: gen[
    {
      b'totalitems': 1
    },
    {
      b'node': b'\x99/Gy\x02\x9a=\xf8\xd0fm\x00\xbb\x92OicN&A',
      b'parents': [
        b'\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00',
        b'\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00'
      ]
    }
  ]

Sending different request doesn't yield cache hit.

  $ sendhttpv2peer << EOF
  > command manifestdata
  >     nodes eval:[b'\x99\x2f\x47\x79\x02\x9a\x3d\xf8\xd0\x66\x6d\x00\xbb\x92\x4f\x69\x63\x4e\x26\x41', b'\xa9\x88\xfb\x43\x58\x3e\x87\x1d\x1e\xd5\x75\x0e\xe0\x74\xc6\xd8\x40\xbb\xbf\xc8']
  >     tree eval:b''
  >     fields eval:[b'parents']
  > EOF
  creating http peer for wire protocol version 2
  sending manifestdata command
  response: gen[
    {
      b'totalitems': 2
    },
    {
      b'node': b'\x99/Gy\x02\x9a=\xf8\xd0fm\x00\xbb\x92OicN&A',
      b'parents': [
        b'\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00',
        b'\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00'
      ]
    },
    {
      b'node': b'\xa9\x88\xfbCX>\x87\x1d\x1e\xd5u\x0e\xe0t\xc6\xd8@\xbb\xbf\xc8',
      b'parents': [
        b'\x99/Gy\x02\x9a=\xf8\xd0fm\x00\xbb\x92OicN&A',
        b'\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00'
      ]
    }
  ]

  $ cat .hg/blackbox.log
  *> cacher constructed for manifestdata (glob)
  *> cache miss for 47abb8efa5f01b8964d74917793ad2464db0fa2c (glob)
  *> storing cache entry for 47abb8efa5f01b8964d74917793ad2464db0fa2c (glob)
  *> cacher constructed for manifestdata (glob)
  *> cache hit for 47abb8efa5f01b8964d74917793ad2464db0fa2c (glob)
  *> cacher constructed for manifestdata (glob)
  *> cache miss for 37326a83e9843f15161fce9d1e92d06b795d5e8e (glob)
  *> storing cache entry for 37326a83e9843f15161fce9d1e92d06b795d5e8e (glob)

  $ cat error.log

  $ killdaemons.py
  $ rm .hg/blackbox.log

Try with object caching mode

  $ cat >> .hg/hgrc << EOF
  > [simplecache]
  > cacheobjects = true
  > EOF

  $ hg serve -p $HGPORT -d --pid-file hg.pid -E error.log
  $ cat hg.pid > $DAEMON_PIDS

  $ sendhttpv2peer << EOF
  > command manifestdata
  >     nodes eval:[b'\x99\x2f\x47\x79\x02\x9a\x3d\xf8\xd0\x66\x6d\x00\xbb\x92\x4f\x69\x63\x4e\x26\x41']
  >     tree eval:b''
  >     fields eval:[b'parents']
  > EOF
  creating http peer for wire protocol version 2
  sending manifestdata command
  response: gen[
    {
      b'totalitems': 1
    },
    {
      b'node': b'\x99/Gy\x02\x9a=\xf8\xd0fm\x00\xbb\x92OicN&A',
      b'parents': [
        b'\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00',
        b'\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00'
      ]
    }
  ]

  $ sendhttpv2peer << EOF
  > command manifestdata
  >     nodes eval:[b'\x99\x2f\x47\x79\x02\x9a\x3d\xf8\xd0\x66\x6d\x00\xbb\x92\x4f\x69\x63\x4e\x26\x41']
  >     tree eval:b''
  >     fields eval:[b'parents']
  > EOF
  creating http peer for wire protocol version 2
  sending manifestdata command
  response: gen[
    {
      b'totalitems': 1
    },
    {
      b'node': b'\x99/Gy\x02\x9a=\xf8\xd0fm\x00\xbb\x92OicN&A',
      b'parents': [
        b'\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00',
        b'\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00'
      ]
    }
  ]

  $ cat .hg/blackbox.log
  *> cacher constructed for manifestdata (glob)
  *> cache miss for 47abb8efa5f01b8964d74917793ad2464db0fa2c (glob)
  *> storing cache entry for 47abb8efa5f01b8964d74917793ad2464db0fa2c (glob)
  *> cacher constructed for manifestdata (glob)
  *> cache hit for 47abb8efa5f01b8964d74917793ad2464db0fa2c (glob)

  $ cat error.log

  $ killdaemons.py
  $ rm .hg/blackbox.log

A non-cacheable command does not instantiate cacher

  $ hg serve -p $HGPORT -d --pid-file hg.pid -E error.log
  $ cat hg.pid > $DAEMON_PIDS
  $ sendhttpv2peer << EOF
  > command capabilities
  > EOF
  creating http peer for wire protocol version 2
  sending capabilities command
  response: gen[
    {
      b'commands': {
        b'branchmap': {
          b'args': {},
          b'permissions': [
            b'pull'
          ]
        },
        b'capabilities': {
          b'args': {},
          b'permissions': [
            b'pull'
          ]
        },
        b'changesetdata': {
          b'args': {
            b'fields': {
              b'default': set([]),
              b'required': False,
              b'type': b'set',
              b'validvalues': set([
                b'bookmarks',
                b'parents',
                b'phase',
                b'revision'
              ])
            },
            b'revisions': {
              b'required': True,
              b'type': b'list'
            }
          },
          b'permissions': [
            b'pull'
          ]
        },
        b'filedata': {
          b'args': {
            b'fields': {
              b'default': set([]),
              b'required': False,
              b'type': b'set',
              b'validvalues': set([
                b'linknode',
                b'parents',
                b'revision'
              ])
            },
            b'haveparents': {
              b'default': False,
              b'required': False,
              b'type': b'bool'
            },
            b'nodes': {
              b'required': True,
              b'type': b'list'
            },
            b'path': {
              b'required': True,
              b'type': b'bytes'
            }
          },
          b'permissions': [
            b'pull'
          ]
        },
        b'filesdata': {
          b'args': {
            b'fields': {
              b'default': set([]),
              b'required': False,
              b'type': b'set',
              b'validvalues': set([
                b'firstchangeset',
                b'linknode',
                b'parents',
                b'revision'
              ])
            },
            b'haveparents': {
              b'default': False,
              b'required': False,
              b'type': b'bool'
            },
            b'pathfilter': {
              b'default': None,
              b'required': False,
              b'type': b'dict'
            },
            b'revisions': {
              b'required': True,
              b'type': b'list'
            }
          },
          b'permissions': [
            b'pull'
          ],
          b'recommendedbatchsize': 50000
        },
        b'heads': {
          b'args': {
            b'publiconly': {
              b'default': False,
              b'required': False,
              b'type': b'bool'
            }
          },
          b'permissions': [
            b'pull'
          ]
        },
        b'known': {
          b'args': {
            b'nodes': {
              b'default': [],
              b'required': False,
              b'type': b'list'
            }
          },
          b'permissions': [
            b'pull'
          ]
        },
        b'listkeys': {
          b'args': {
            b'namespace': {
              b'required': True,
              b'type': b'bytes'
            }
          },
          b'permissions': [
            b'pull'
          ]
        },
        b'lookup': {
          b'args': {
            b'key': {
              b'required': True,
              b'type': b'bytes'
            }
          },
          b'permissions': [
            b'pull'
          ]
        },
        b'manifestdata': {
          b'args': {
            b'fields': {
              b'default': set([]),
              b'required': False,
              b'type': b'set',
              b'validvalues': set([
                b'parents',
                b'revision'
              ])
            },
            b'haveparents': {
              b'default': False,
              b'required': False,
              b'type': b'bool'
            },
            b'nodes': {
              b'required': True,
              b'type': b'list'
            },
            b'tree': {
              b'required': True,
              b'type': b'bytes'
            }
          },
          b'permissions': [
            b'pull'
          ],
          b'recommendedbatchsize': 100000
        },
        b'pushkey': {
          b'args': {
            b'key': {
              b'required': True,
              b'type': b'bytes'
            },
            b'namespace': {
              b'required': True,
              b'type': b'bytes'
            },
            b'new': {
              b'required': True,
              b'type': b'bytes'
            },
            b'old': {
              b'required': True,
              b'type': b'bytes'
            }
          },
          b'permissions': [
            b'push'
          ]
        },
        b'rawstorefiledata': {
          b'args': {
            b'files': {
              b'required': True,
              b'type': b'list'
            },
            b'pathfilter': {
              b'default': None,
              b'required': False,
              b'type': b'list'
            }
          },
          b'permissions': [
            b'pull'
          ]
        }
      },
      b'framingmediatypes': [
        b'application/mercurial-exp-framing-0006'
      ],
      b'pathfilterprefixes': set([
        b'path:',
        b'rootfilesin:'
      ]),
      b'rawrepoformats': [
        b'generaldelta',
        b'revlogv1',
        b'sparserevlog'
      ]
    }
  ]

  $ test -f .hg/blackbox.log
  [1]

An error is not cached

  $ sendhttpv2peer << EOF
  > command manifestdata
  >     nodes eval:[b'\xaa\xaa\xaa\xaa\xaa\xaa\xaa\xaa\xaa\xaa\xaa\xaa\xaa\xaa\xaa\xaa\xaa\xaa\xaa\xaa']
  >     tree eval:b''
  >     fields eval:[b'parents']
  > EOF
  creating http peer for wire protocol version 2
  sending manifestdata command
  abort: unknown node: \xaa\xaa\xaa\xaa\xaa\xaa\xaa\xaa\xaa\xaa\xaa\xaa\xaa\xaa\xaa\xaa\xaa\xaa\xaa\xaa! (esc)
  [255]

  $ cat .hg/blackbox.log
  *> cacher constructed for manifestdata (glob)
  *> cache miss for 2cba2a7d0d1575fea2fe68f597e97a7c2ac2f705 (glob)
  *> cacher exiting due to error (glob)

  $ killdaemons.py
  $ rm .hg/blackbox.log
