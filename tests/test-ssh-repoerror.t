#require unix-permissions no-root

initial setup

  $ cat << EOF >> $HGRCPATH
  > [ui]
  > ssh="$PYTHON" "$TESTDIR/dummyssh"
  > EOF

repository itself is non-readable
---------------------------------

  $ hg init no-read
  $ hg id ssh://user@dummy/no-read
  000000000000
  $ chmod a-rx no-read

  $ hg id ssh://user@dummy/no-read
  remote: abort: Permission denied: *$TESTTMP/no-read/.hg* (glob)
  abort: no suitable response from remote hg!
  [255]

special case files are visible, but unreadable
----------------------------------------------

This is "similar" to the test above, but the directory is "traversable". This
seems an unexpected case in real life, but we test it anyway.

  $ hg init other
  $ hg id ssh://user@dummy/other
  000000000000
  $ for item in `find other | sort -r` ; do
  >     chmod a-r $item
  > done

  $ hg id ssh://user@dummy/other
  remote: abort: Permission denied: $TESTTMP/other/.hg/requires
  abort: no suitable response from remote hg!
  [255]

directory toward the repository is read only
--------------------------------------------

  $ mkdir deep
  $ hg init deep/nested

  $ hg id ssh://user@dummy/deep/nested
  000000000000

  $ chmod a-rx deep

  $ hg id ssh://user@dummy/deep/nested
  remote: abort: Permission denied: *$TESTTMP/deep/nested/.hg* (glob)
  abort: no suitable response from remote hg!
  [255]

repository has wrong requirement
--------------------------------

  $ hg init repo-future
  $ hg id ssh://user@dummy/repo-future
  000000000000
  $ echo flying-car >> repo-future/.hg/requires
  $ hg id ssh://user@dummy/repo-future
  remote: abort: repository requires features unknown to this Mercurial: flying-car!
  remote: (see https://mercurial-scm.org/wiki/MissingRequirement for more information)
  abort: no suitable response from remote hg!
  [255]
