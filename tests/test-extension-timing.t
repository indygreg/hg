Test basic extension support

  $ cat > foobar.py <<EOF
  > import os
  > from mercurial import commands, registrar
  > cmdtable = {}
  > command = registrar.command(cmdtable)
  > configtable = {}
  > configitem = registrar.configitem(configtable)
  > configitem(b'tests', b'foo', default=b"Foo")
  > def uisetup(ui):
  >     ui.debug(b"uisetup called [debug]\\n")
  >     ui.write(b"uisetup called\\n")
  >     ui.status(b"uisetup called [status]\\n")
  >     ui.flush()
  > def reposetup(ui, repo):
  >     ui.write(b"reposetup called for %s\\n" % os.path.basename(repo.root))
  >     ui.write(b"ui %s= repo.ui\\n" % (ui == repo.ui and b"=" or b"!"))
  >     ui.flush()
  > @command(b'foo', [], b'hg foo')
  > def foo(ui, *args, **kwargs):
  >     foo = ui.config(b'tests', b'foo')
  >     ui.write(foo)
  >     ui.write(b"\\n")
  > @command(b'bar', [], b'hg bar', norepo=True)
  > def bar(ui, *args, **kwargs):
  >     ui.write(b"Bar\\n")
  > EOF
  $ abspath=`pwd`/foobar.py

  $ mkdir barfoo
  $ cp foobar.py barfoo/__init__.py
  $ barfoopath=`pwd`/barfoo

  $ hg init a
  $ cd a
  $ echo foo > file
  $ hg add file
  $ hg commit -m 'add file'

  $ echo '[extensions]' >> $HGRCPATH
  $ echo "foobar = $abspath" >> $HGRCPATH

Test extension setup timings

  $ hg foo --traceback --config devel.debug.extensions=yes --debug 2>&1
  debug.extensions: loading extensions
  debug.extensions: - processing 1 entries
  debug.extensions:   - loading extension: 'foobar'
  debug.extensions:   > 'foobar' extension loaded in * (glob)
  debug.extensions:     - validating extension tables: 'foobar'
  debug.extensions:     - invoking registered callbacks: 'foobar'
  debug.extensions:     > callbacks completed in * (glob)
  debug.extensions: > loaded 1 extensions, total time * (glob)
  debug.extensions: - loading configtable attributes
  debug.extensions: - executing uisetup hooks
  debug.extensions:   - running uisetup for 'foobar'
  uisetup called [debug]
  uisetup called
  uisetup called [status]
  debug.extensions:   > uisetup for 'foobar' took * (glob)
  debug.extensions: > all uisetup took * (glob)
  debug.extensions: - executing extsetup hooks
  debug.extensions:   - running extsetup for 'foobar'
  debug.extensions:   > extsetup for 'foobar' took * (glob)
  debug.extensions: > all extsetup took * (glob)
  debug.extensions: - executing remaining aftercallbacks
  debug.extensions: > remaining aftercallbacks completed in * (glob)
  debug.extensions: - loading extension registration objects
  debug.extensions: > extension registration object loading took * (glob)
  debug.extensions: > extension foobar take a total of * to load (glob)
  debug.extensions: extension loading complete
  debug.extensions: loading additional extensions
  debug.extensions: - processing 1 entries
  debug.extensions: > loaded 0 extensions, total time * (glob)
  debug.extensions: - loading configtable attributes
  debug.extensions: - executing uisetup hooks
  debug.extensions: > all uisetup took * (glob)
  debug.extensions: - executing extsetup hooks
  debug.extensions: > all extsetup took * (glob)
  debug.extensions: - executing remaining aftercallbacks
  debug.extensions: > remaining aftercallbacks completed in * (glob)
  debug.extensions: - loading extension registration objects
  debug.extensions: > extension registration object loading took * (glob)
  debug.extensions: extension loading complete
  debug.extensions: - executing reposetup hooks
  debug.extensions:   - running reposetup for foobar
  reposetup called for a
  ui == repo.ui
  debug.extensions:   > reposetup for 'foobar' took * (glob)
  debug.extensions: > all reposetup took * (glob)
  Foo

  $ cd ..

  $ echo 'foobar = !' >> $HGRCPATH
