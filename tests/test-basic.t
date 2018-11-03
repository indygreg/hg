Create a repository:

#if no-extraextensions
  $ hg config
  devel.all-warnings=true
  devel.default-date=0 0
  extensions.fsmonitor= (fsmonitor !)
  largefiles.usercache=$TESTTMP/.cache/largefiles
  lfs.usercache=$TESTTMP/.cache/lfs
  ui.slash=True
  ui.interactive=False
  ui.merge=internal:merge
  ui.mergemarkers=detailed
  ui.promptecho=True
  web.address=localhost
  web\.ipv6=(?:True|False) (re)
  web.server-header=testing stub value
#endif

  $ hg init t
  $ cd t

Prepare a changeset:

  $ echo a > a
  $ hg add a

  $ hg status
  A a

Writes to stdio succeed and fail appropriately

#if devfull
  $ hg status 2>/dev/full
  A a

  $ hg status >/dev/full
  abort: No space left on device
  [255]
#endif

#if devfull
  $ hg status >/dev/full 2>&1
  [255]

  $ hg status ENOENT 2>/dev/full
  [255]
#endif

  $ hg commit -m test

This command is ancient:

  $ hg history
  changeset:   0:acb14030fe0a
  tag:         tip
  user:        test
  date:        Thu Jan 01 00:00:00 1970 +0000
  summary:     test
  

Verify that updating to revision 0 via commands.update() works properly

  $ cat <<EOF > update_to_rev0.py
  > from mercurial import commands, hg, ui as uimod
  > myui = uimod.ui.load()
  > repo = hg.repository(myui, path=b'.')
  > commands.update(myui, repo, rev=b"0")
  > EOF
  $ hg up null
  0 files updated, 0 files merged, 1 files removed, 0 files unresolved
  $ "$PYTHON" ./update_to_rev0.py
  1 files updated, 0 files merged, 0 files removed, 0 files unresolved
  $ hg identify -n
  0


Poke around at hashes:

  $ hg manifest --debug
  b789fdd96dc2f3bd229c1dd8eedf0fc60e2b68e3 644   a

  $ hg cat a
  a

Verify should succeed:

  $ hg verify
  checking changesets
  checking manifests
  crosschecking files in changesets and manifests
  checking files
  checked 1 changesets with 1 changes to 1 files

Repository root:

  $ hg root
  $TESTTMP/t
  $ hg log -l1 -T '{reporoot}\n'
  $TESTTMP/t

At the end...

  $ cd ..

Status message redirection:

  $ hg init empty

 status messages are sent to stdout by default:

  $ hg outgoing -R t empty -Tjson 2>/dev/null
  comparing with empty
  searching for changes
  [
   {
    "bookmarks": [],
    "branch": "default",
    "date": [0, 0],
    "desc": "test",
    "node": "acb14030fe0a21b60322c440ad2d20cf7685a376",
    "parents": ["0000000000000000000000000000000000000000"],
    "phase": "draft",
    "rev": 0,
    "tags": ["tip"],
    "user": "test"
   }
  ]

 which can be configured to send to stderr, so the output wouldn't be
 interleaved:

  $ cat <<'EOF' >> "$HGRCPATH"
  > [ui]
  > message-output = stderr
  > EOF
  $ hg outgoing -R t empty -Tjson 2>/dev/null
  [
   {
    "bookmarks": [],
    "branch": "default",
    "date": [0, 0],
    "desc": "test",
    "node": "acb14030fe0a21b60322c440ad2d20cf7685a376",
    "parents": ["0000000000000000000000000000000000000000"],
    "phase": "draft",
    "rev": 0,
    "tags": ["tip"],
    "user": "test"
   }
  ]
  $ hg outgoing -R t empty -Tjson >/dev/null
  comparing with empty
  searching for changes

 this option should be turned off by HGPLAIN= since it may break scripting use:

  $ HGPLAIN= hg outgoing -R t empty -Tjson 2>/dev/null
  comparing with empty
  searching for changes
  [
   {
    "bookmarks": [],
    "branch": "default",
    "date": [0, 0],
    "desc": "test",
    "node": "acb14030fe0a21b60322c440ad2d20cf7685a376",
    "parents": ["0000000000000000000000000000000000000000"],
    "phase": "draft",
    "rev": 0,
    "tags": ["tip"],
    "user": "test"
   }
  ]

 but still overridden by --config:

  $ HGPLAIN= hg outgoing -R t empty -Tjson --config ui.message-output=stderr \
  > 2>/dev/null
  [
   {
    "bookmarks": [],
    "branch": "default",
    "date": [0, 0],
    "desc": "test",
    "node": "acb14030fe0a21b60322c440ad2d20cf7685a376",
    "parents": ["0000000000000000000000000000000000000000"],
    "phase": "draft",
    "rev": 0,
    "tags": ["tip"],
    "user": "test"
   }
  ]

Invalid ui.message-output option:

  $ hg log -R t --config ui.message-output=bad
  abort: invalid ui.message-output destination: bad
  [255]

Underlying message streams should be updated when ui.fout/ferr are set:

  $ cat <<'EOF' > capui.py
  > from mercurial import pycompat, registrar
  > cmdtable = {}
  > command = registrar.command(cmdtable)
  > @command(b'capui', norepo=True)
  > def capui(ui):
  >     out = ui.fout
  >     ui.fout = pycompat.bytesio()
  >     ui.status(b'status\n')
  >     ui.ferr = pycompat.bytesio()
  >     ui.warn(b'warn\n')
  >     out.write(b'stdout: %s' % ui.fout.getvalue())
  >     out.write(b'stderr: %s' % ui.ferr.getvalue())
  > EOF
  $ hg --config extensions.capui=capui.py --config ui.message-output=stdio capui
  stdout: status
  stderr: warn
