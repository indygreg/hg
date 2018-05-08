Tests for access level on hidden commits by various commands on based of their
type.

Setting the required config to start this

  $ cat >> $HGRCPATH <<EOF
  > [experimental]
  > evolution=createmarkers, allowunstable
  > directaccess=True
  > directaccess.revnums=True
  > [extensions]
  > amend =
  > EOF

  $ hg init repo
  $ cd repo
  $ for ch in a b c; do touch $ch; echo "foo" >> $ch; hg ci -Aqm "Added "$ch; done

  $ hg log -G -T '{rev}:{node} {desc}' --hidden
  @  2:28ad74487de9599d00d81085be739c61fc340652 Added c
  |
  o  1:29becc82797a4bc11ec8880b58eaecd2ab3e7760 Added b
  |
  o  0:18d04c59bb5d2d4090ad9a5b59bd6274adb63add Added a
  
  $ echo "bar" >> c
  $ hg amend

  $ hg log -G -T '{rev}:{node} {desc}' --hidden
  @  3:2443a0e664694756d8b435d06b6ad84f941b6fc0 Added c
  |
  | x  2:28ad74487de9599d00d81085be739c61fc340652 Added c
  |/
  o  1:29becc82797a4bc11ec8880b58eaecd2ab3e7760 Added b
  |
  o  0:18d04c59bb5d2d4090ad9a5b59bd6274adb63add Added a
  
Testing read only commands on the hidden revision

Testing with rev number

  $ hg exp 2 --config experimental.directaccess.revnums=False
  abort: hidden revision '2' was rewritten as: 2443a0e66469!
  (use --hidden to access hidden revisions)
  [255]

  $ hg exp 2
  # HG changeset patch
  # User test
  # Date 0 0
  #      Thu Jan 01 00:00:00 1970 +0000
  # Node ID 28ad74487de9599d00d81085be739c61fc340652
  # Parent  29becc82797a4bc11ec8880b58eaecd2ab3e7760
  Added c
  
  diff -r 29becc82797a -r 28ad74487de9 c
  --- /dev/null	Thu Jan 01 00:00:00 1970 +0000
  +++ b/c	Thu Jan 01 00:00:00 1970 +0000
  @@ -0,0 +1,1 @@
  +foo

  $ hg log -r 2
  changeset:   2:28ad74487de9
  user:        test
  date:        Thu Jan 01 00:00:00 1970 +0000
  obsolete:    rewritten using amend as 3:2443a0e66469
  summary:     Added c
  
  $ hg identify -r 2
  28ad74487de9

  $ hg status --change 2
  A c

  $ hg status --change 2 --config experimental.directaccess.revnums=False
  abort: hidden revision '2' was rewritten as: 2443a0e66469!
  (use --hidden to access hidden revisions)
  [255]

  $ hg diff -c 2
  diff -r 29becc82797a -r 28ad74487de9 c
  --- /dev/null	Thu Jan 01 00:00:00 1970 +0000
  +++ b/c	Thu Jan 01 00:00:00 1970 +0000
  @@ -0,0 +1,1 @@
  +foo

Testing with hash

`hg export`

  $ hg exp 28ad74
  # HG changeset patch
  # User test
  # Date 0 0
  #      Thu Jan 01 00:00:00 1970 +0000
  # Node ID 28ad74487de9599d00d81085be739c61fc340652
  # Parent  29becc82797a4bc11ec8880b58eaecd2ab3e7760
  Added c
  
  diff -r 29becc82797a -r 28ad74487de9 c
  --- /dev/null	Thu Jan 01 00:00:00 1970 +0000
  +++ b/c	Thu Jan 01 00:00:00 1970 +0000
  @@ -0,0 +1,1 @@
  +foo

`hg log`

  $ hg log -r 28ad74
  changeset:   2:28ad74487de9
  user:        test
  date:        Thu Jan 01 00:00:00 1970 +0000
  obsolete:    rewritten using amend as 3:2443a0e66469
  summary:     Added c
  
`hg cat`

  $ hg cat -r 28ad74 c
  foo

`hg diff`

  $ hg diff -c 28ad74
  diff -r 29becc82797a -r 28ad74487de9 c
  --- /dev/null	Thu Jan 01 00:00:00 1970 +0000
  +++ b/c	Thu Jan 01 00:00:00 1970 +0000
  @@ -0,0 +1,1 @@
  +foo

`hg files`

  $ hg files -r 28ad74
  a
  b
  c

`hg identify`

  $ hg identify -r 28ad74
  28ad74487de9

`hg annotate`

  $ hg annotate -r 28ad74 a
  0: foo

`hg status`

  $ hg status --change 28ad74
  A c

`hg archive`

This should not throw error
  $ hg archive -r 28ad74 foo

`hg update`

  $ hg up 28ad74
  1 files updated, 0 files merged, 0 files removed, 0 files unresolved
  updated to hidden changeset 28ad74487de9
  (hidden revision '28ad74487de9' was rewritten as: 2443a0e66469)

  $ hg up 3
  1 files updated, 0 files merged, 0 files removed, 0 files unresolved

  $ hg up
  0 files updated, 0 files merged, 0 files removed, 0 files unresolved

`hg revert`

  $ hg revert -r 28ad74 --all
  reverting c

  $ hg diff
  diff -r 2443a0e66469 c
  --- a/c	Thu Jan 01 00:00:00 1970 +0000
  +++ b/c	Thu Jan 01 00:00:00 1970 +0000
  @@ -1,2 +1,1 @@
   foo
  -bar

Test special hash/rev

  $ hg log -qr 'null:wdir() & 000000000000'
  -1:000000000000
  $ hg log -qr 'null:wdir() & ffffffffffff'
  2147483647:ffffffffffff
  $ hg log -qr 'null:wdir() & rev(-1)'
  -1:000000000000
  $ hg log -qr 'null:wdir() & rev(2147483647)'
  2147483647:ffffffffffff
  $ hg log -qr 'null:wdir() & 2147483647'
  2147483647:ffffffffffff

Commands with undefined intent should not work right now

  $ hg phase -r 28ad74
  abort: hidden revision '28ad74' was rewritten as: 2443a0e66469!
  (use --hidden to access hidden revisions)
  [255]

  $ hg phase -r 2
  abort: hidden revision '2' was rewritten as: 2443a0e66469!
  (use --hidden to access hidden revisions)
  [255]

Setting a bookmark will make that changeset unhidden, so this should come in end

  $ hg bookmarks -r 28ad74 book
  bookmarking hidden changeset 28ad74487de9
  (hidden revision '28ad74487de9' was rewritten as: 2443a0e66469)

  $ hg bookmarks
     book                      2:28ad74487de9
