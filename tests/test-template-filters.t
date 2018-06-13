  $ hg debugtemplate '{""|splitlines|commondir}\n'
  
  $ hg debugtemplate '{"foo/bar\nfoo/baz\nfoo/foobar\n"|splitlines|commondir}\n'
  foo
  $ hg debugtemplate '{"foo/bar\nfoo/bar\n"|splitlines|commondir}\n'
  foo
  $ hg debugtemplate '{"/foo/bar\n/foo/bar\n"|splitlines|commondir}\n'
  foo
  $ hg debugtemplate '{"/foo\n/foo\n"|splitlines|commondir}\n'
  
  $ hg debugtemplate '{"foo/bar\nbar/baz"|splitlines|commondir}\n'
  
  $ hg debugtemplate '{"foo/bar\nbar/baz\nbar/foo\n"|splitlines|commondir}\n'
  
  $ hg debugtemplate '{"foo/../bar\nfoo/bar"|splitlines|commondir}\n'
  foo
  $ hg debugtemplate '{"foo\n/foo"|splitlines|commondir}\n'
  
  $ hg init
  $ hg log -r null -T '{rev|commondir}'
  hg: parse error: argument is not a list of text
  (template filter 'commondir' is not compatible with keyword 'rev')
  [255]
