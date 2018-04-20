  $ hg debugtemplate '{""|splitlines|commonprefix}\n'
  
  $ hg debugtemplate '{"foo/bar\nfoo/baz\nfoo/foobar\n"|splitlines|commonprefix}\n'
  foo
  $ hg debugtemplate '{"foo/bar\nfoo/bar\n"|splitlines|commonprefix}\n'
  foo
  $ hg debugtemplate '{"/foo/bar\n/foo/bar\n"|splitlines|commonprefix}\n'
  foo
  $ hg debugtemplate '{"/foo\n/foo\n"|splitlines|commonprefix}\n'
  
  $ hg debugtemplate '{"foo/bar\nbar/baz"|splitlines|commonprefix}\n'
  
  $ hg debugtemplate '{"foo/bar\nbar/baz\nbar/foo\n"|splitlines|commonprefix}\n'
  
  $ hg debugtemplate '{"foo/../bar\nfoo/bar"|splitlines|commonprefix}\n'
  foo
  $ hg debugtemplate '{"foo\n/foo"|splitlines|commonprefix}\n'
  
  $ hg init
  $ hg log -r null -T '{rev|commonprefix}'
  hg: parse error: argument is not a list of text
  (template filter 'commonprefix' is not compatible with keyword 'rev')
  [255]
