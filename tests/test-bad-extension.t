ensure that failing ui.atexit handlers report sensibly

  $ cat > $TESTTMP/bailatexit.py <<EOF
  > from mercurial import util
  > def bail():
  >     raise RuntimeError('ui.atexit handler exception')
  > 
  > def extsetup(ui):
  >     ui.atexit(bail)
  > EOF
  $ hg -q --config extensions.bailatexit=$TESTTMP/bailatexit.py \
  >  help help
  hg help [-eck] [-s PLATFORM] [TOPIC]
  
  show help for a given topic or a help overview
  error in exit handlers:
  Traceback (most recent call last):
    File "*/mercurial/dispatch.py", line *, in _runexithandlers (glob)
      func(*args, **kwargs)
    File "$TESTTMP/bailatexit.py", line *, in bail (glob)
      raise RuntimeError('ui.atexit handler exception')
  RuntimeError: ui.atexit handler exception
  [255]

  $ rm $TESTTMP/bailatexit.py

another bad extension

  $ echo 'raise Exception("bit bucket overflow")' > badext.py
  $ abspathexc=`pwd`/badext.py

  $ cat >baddocext.py <<EOF
  > """
  > baddocext is bad
  > """
  > EOF
  $ abspathdoc=`pwd`/baddocext.py

  $ cat <<EOF >> $HGRCPATH
  > [extensions]
  > gpg =
  > hgext.gpg =
  > badext = $abspathexc
  > baddocext = $abspathdoc
  > badext2 =
  > EOF

  $ hg -q help help 2>&1 |grep extension
  *** failed to import extension badext from $TESTTMP/badext.py: bit bucket overflow
  *** failed to import extension badext2: No module named *badext2* (glob)

show traceback

  $ hg -q help help --traceback 2>&1 | egrep ' extension|^Exception|Traceback|ImportError|ModuleNotFound'
  *** failed to import extension badext from $TESTTMP/badext.py: bit bucket overflow
  Traceback (most recent call last):
  Exception: bit bucket overflow
  *** failed to import extension badext2: No module named *badext2* (glob)
  Traceback (most recent call last):
  ImportError: No module named badext2 (no-py3 !)
  ModuleNotFoundError: No module named 'hgext.badext2' (py3 !)
  Traceback (most recent call last): (py3 !)
  ModuleNotFoundError: No module named 'hgext3rd.badext2' (py3 !)
  Traceback (most recent call last): (py3 !)
  ModuleNotFoundError: No module named 'badext2' (py3 !)

names of extensions failed to load can be accessed via extensions.notloaded()

  $ cat <<EOF > showbadexts.py
  > from mercurial import commands, extensions, registrar
  > cmdtable = {}
  > command = registrar.command(cmdtable)
  > @command(b'showbadexts', norepo=True)
  > def showbadexts(ui, *pats, **opts):
  >     ui.write(b'BADEXTS: %s\n' % b' '.join(sorted(extensions.notloaded())))
  > EOF
  $ hg --config extensions.badexts=showbadexts.py showbadexts 2>&1 | grep '^BADEXTS'
  BADEXTS: badext badext2

#if no-extraextensions
show traceback for ImportError of hgext.name if devel.debug.extensions is set

  $ (hg help help --traceback --debug --config devel.debug.extensions=yes 2>&1) \
  > | grep -v '^ ' \
  > | egrep 'extension..[^p]|^Exception|Traceback|ImportError|not import|ModuleNotFound'
  debug.extensions: loading extensions
  debug.extensions: - processing 5 entries
  debug.extensions:   - loading extension: 'gpg'
  debug.extensions:   > 'gpg' extension loaded in * (glob)
  debug.extensions:     - validating extension tables: 'gpg'
  debug.extensions:     - invoking registered callbacks: 'gpg'
  debug.extensions:     > callbacks completed in * (glob)
  debug.extensions:   - loading extension: 'badext'
  *** failed to import extension badext from $TESTTMP/badext.py: bit bucket overflow
  Traceback (most recent call last):
  Exception: bit bucket overflow
  debug.extensions:   - loading extension: 'baddocext'
  debug.extensions:   > 'baddocext' extension loaded in * (glob)
  debug.extensions:     - validating extension tables: 'baddocext'
  debug.extensions:     - invoking registered callbacks: 'baddocext'
  debug.extensions:     > callbacks completed in * (glob)
  debug.extensions:   - loading extension: 'badext2'
  debug.extensions:     - could not import hgext.badext2 (No module named *badext2*): trying hgext3rd.badext2 (glob)
  Traceback (most recent call last):
  ImportError: No module named badext2 (no-py3 !)
  ModuleNotFoundError: No module named 'hgext.badext2' (py3 !)
  debug.extensions:     - could not import hgext3rd.badext2 (No module named *badext2*): trying badext2 (glob)
  Traceback (most recent call last):
  ImportError: No module named badext2 (no-py3 !)
  ModuleNotFoundError: No module named 'hgext.badext2' (py3 !)
  Traceback (most recent call last): (py3 !)
  ModuleNotFoundError: No module named 'hgext3rd.badext2' (py3 !)
  *** failed to import extension badext2: No module named *badext2* (glob)
  Traceback (most recent call last):
  ModuleNotFoundError: No module named 'hgext.badext2' (py3 !)
  Traceback (most recent call last): (py3 !)
  ModuleNotFoundError: No module named 'hgext3rd.badext2' (py3 !)
  Traceback (most recent call last): (py3 !)
  ModuleNotFoundError: No module named 'badext2' (py3 !)
  ImportError: No module named badext2 (no-py3 !)
  debug.extensions: > loaded 2 extensions, total time * (glob)
  debug.extensions: - loading configtable attributes
  debug.extensions: - executing uisetup hooks
  debug.extensions:   - running uisetup for 'gpg'
  debug.extensions:   > uisetup for 'gpg' took * (glob)
  debug.extensions:   - running uisetup for 'baddocext'
  debug.extensions:   > uisetup for 'baddocext' took * (glob)
  debug.extensions: > all uisetup took * (glob)
  debug.extensions: - executing extsetup hooks
  debug.extensions:   - running extsetup for 'gpg'
  debug.extensions:   > extsetup for 'gpg' took * (glob)
  debug.extensions:   - running extsetup for 'baddocext'
  debug.extensions:   > extsetup for 'baddocext' took * (glob)
  debug.extensions: > all extsetup took * (glob)
  debug.extensions: - executing remaining aftercallbacks
  debug.extensions: > remaining aftercallbacks completed in * (glob)
  debug.extensions: - loading extension registration objects
  debug.extensions: > extension registration object loading took * (glob)
  debug.extensions: > extension baddocext take a total of * to load (glob)
  debug.extensions: > extension gpg take a total of * to load (glob)
  debug.extensions: extension loading complete
#endif

confirm that there's no crash when an extension's documentation is bad

  $ hg help --keyword baddocext
  *** failed to import extension badext from $TESTTMP/badext.py: bit bucket overflow
  *** failed to import extension badext2: No module named *badext2* (glob)
  Topics:
  
   extensions Using Additional Features
