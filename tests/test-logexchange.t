Testing the functionality to pull remotenames
=============================================

  $ cat >> $HGRCPATH << EOF
  > [ui]
  > ssh = $PYTHON "$TESTDIR/dummyssh"
  > [alias]
  > glog = log -G -T '{rev}:{node|short}  {desc}'
  > [extensions]
  > remotenames =
  > show =
  > EOF

Making a server repo
--------------------

  $ hg init server
  $ cd server
  $ for ch in a b c d e f g h; do
  >   echo "foo" >> $ch
  >   hg ci -Aqm "Added "$ch
  > done
  $ hg glog
  @  7:ec2426147f0e  Added h
  |
  o  6:87d6d6676308  Added g
  |
  o  5:825660c69f0c  Added f
  |
  o  4:aa98ab95a928  Added e
  |
  o  3:62615734edd5  Added d
  |
  o  2:28ad74487de9  Added c
  |
  o  1:29becc82797a  Added b
  |
  o  0:18d04c59bb5d  Added a
  
  $ hg bookmark -r 3 foo
  $ hg bookmark -r 6 bar
  $ hg up 4
  0 files updated, 0 files merged, 3 files removed, 0 files unresolved
  $ hg branch wat
  marked working directory as branch wat
  (branches are permanent and global, did you want a bookmark?)
  $ echo foo >> bar
  $ hg ci -Aqm "added bar"

Making a client repo
--------------------

  $ cd ..

  $ hg clone ssh://user@dummy/server client
  requesting all changes
  adding changesets
  adding manifests
  adding file changes
  added 9 changesets with 9 changes to 9 files (+1 heads)
  new changesets 18d04c59bb5d:3e1487808078
  updating to branch default
  8 files updated, 0 files merged, 0 files removed, 0 files unresolved

  $ cd client
  $ cat .hg/logexchange/bookmarks
  0
  
  87d6d66763085b629e6d7ed56778c79827273022\x00default\x00bar (esc)
  62615734edd52f06b6fb9c2beb429e4fe30d57b8\x00default\x00foo (esc)

  $ cat .hg/logexchange/branches
  0
  
  ec2426147f0e39dbc9cef599b066be6035ce691d\x00default\x00default (esc)
  3e1487808078543b0af6d10dadf5d46943578db0\x00default\x00wat (esc)

  $ hg show work
  o  3e14 (wat) (default/wat) added bar
  |
  ~
  @  ec24 (default/default) Added h
  |
  ~

  $ hg update "default/wat"
  1 files updated, 0 files merged, 3 files removed, 0 files unresolved
  $ hg identify
  3e1487808078 (wat) tip

Making a new server
-------------------

  $ cd ..
  $ hg init server2
  $ cd server2
  $ hg pull ../server/
  pulling from ../server/
  requesting all changes
  adding changesets
  adding manifests
  adding file changes
  added 9 changesets with 9 changes to 9 files (+1 heads)
  adding remote bookmark bar
  adding remote bookmark foo
  new changesets 18d04c59bb5d:3e1487808078
  (run 'hg heads' to see heads)

Pulling form the new server
---------------------------
  $ cd ../client/
  $ hg pull ../server2/
  pulling from ../server2/
  searching for changes
  no changes found
  $ cat .hg/logexchange/bookmarks
  0
  
  62615734edd52f06b6fb9c2beb429e4fe30d57b8\x00default\x00foo (esc)
  87d6d66763085b629e6d7ed56778c79827273022\x00default\x00bar (esc)
  87d6d66763085b629e6d7ed56778c79827273022\x00$TESTTMP/server2\x00bar (esc)
  62615734edd52f06b6fb9c2beb429e4fe30d57b8\x00$TESTTMP/server2\x00foo (esc)

  $ cat .hg/logexchange/branches
  0
  
  3e1487808078543b0af6d10dadf5d46943578db0\x00default\x00wat (esc)
  ec2426147f0e39dbc9cef599b066be6035ce691d\x00default\x00default (esc)
  ec2426147f0e39dbc9cef599b066be6035ce691d\x00$TESTTMP/server2\x00default (esc)
  3e1487808078543b0af6d10dadf5d46943578db0\x00$TESTTMP/server2\x00wat (esc)

  $ hg log -G
  @  changeset:   8:3e1487808078
  |  branch:      wat
  |  tag:         tip
  |  remote branch:  $TESTTMP/server2/wat
  |  remote branch:  default/wat
  |  parent:      4:aa98ab95a928
  |  user:        test
  |  date:        Thu Jan 01 00:00:00 1970 +0000
  |  summary:     added bar
  |
  | o  changeset:   7:ec2426147f0e
  | |  remote branch:  $TESTTMP/server2/default
  | |  remote branch:  default/default
  | |  user:        test
  | |  date:        Thu Jan 01 00:00:00 1970 +0000
  | |  summary:     Added h
  | |
  | o  changeset:   6:87d6d6676308
  | |  bookmark:    bar
  | |  remote bookmark:  $TESTTMP/server2/bar
  | |  remote bookmark:  default/bar
  | |  hoisted name:  bar
  | |  user:        test
  | |  date:        Thu Jan 01 00:00:00 1970 +0000
  | |  summary:     Added g
  | |
  | o  changeset:   5:825660c69f0c
  |/   user:        test
  |    date:        Thu Jan 01 00:00:00 1970 +0000
  |    summary:     Added f
  |
  o  changeset:   4:aa98ab95a928
  |  user:        test
  |  date:        Thu Jan 01 00:00:00 1970 +0000
  |  summary:     Added e
  |
  o  changeset:   3:62615734edd5
  |  bookmark:    foo
  |  remote bookmark:  $TESTTMP/server2/foo
  |  remote bookmark:  default/foo
  |  hoisted name:  foo
  |  user:        test
  |  date:        Thu Jan 01 00:00:00 1970 +0000
  |  summary:     Added d
  |
  o  changeset:   2:28ad74487de9
  |  user:        test
  |  date:        Thu Jan 01 00:00:00 1970 +0000
  |  summary:     Added c
  |
  o  changeset:   1:29becc82797a
  |  user:        test
  |  date:        Thu Jan 01 00:00:00 1970 +0000
  |  summary:     Added b
  |
  o  changeset:   0:18d04c59bb5d
     user:        test
     date:        Thu Jan 01 00:00:00 1970 +0000
     summary:     Added a
  
Testing the templates provided by remotenames extension

`remotenames` keyword

  $ hg log -G -T "{rev}:{node|short} {remotenames}\n"
  @  8:3e1487808078 $TESTTMP/server2/wat default/wat
  |
  | o  7:ec2426147f0e $TESTTMP/server2/default default/default
  | |
  | o  6:87d6d6676308 $TESTTMP/server2/bar default/bar
  | |
  | o  5:825660c69f0c
  |/
  o  4:aa98ab95a928
  |
  o  3:62615734edd5 $TESTTMP/server2/foo default/foo
  |
  o  2:28ad74487de9
  |
  o  1:29becc82797a
  |
  o  0:18d04c59bb5d
  
`remotebookmarks` and `remotebranches` keywords

  $ hg log -G -T "{rev}:{node|short} [{remotebookmarks}] ({remotebranches})"
  @  8:3e1487808078 [] ($TESTTMP/server2/wat default/wat)
  |
  | o  7:ec2426147f0e [] ($TESTTMP/server2/default default/default)
  | |
  | o  6:87d6d6676308 [$TESTTMP/server2/bar default/bar] ()
  | |
  | o  5:825660c69f0c [] ()
  |/
  o  4:aa98ab95a928 [] ()
  |
  o  3:62615734edd5 [$TESTTMP/server2/foo default/foo] ()
  |
  o  2:28ad74487de9 [] ()
  |
  o  1:29becc82797a [] ()
  |
  o  0:18d04c59bb5d [] ()
  
The `hoistednames` template keyword

  $ hg log -GT "{rev}:{node|short} ({hoistednames})"
  @  8:3e1487808078 ()
  |
  | o  7:ec2426147f0e ()
  | |
  | o  6:87d6d6676308 (bar)
  | |
  | o  5:825660c69f0c ()
  |/
  o  4:aa98ab95a928 ()
  |
  o  3:62615734edd5 (foo)
  |
  o  2:28ad74487de9 ()
  |
  o  1:29becc82797a ()
  |
  o  0:18d04c59bb5d ()
  

Testing the revsets provided by remotenames extension

`remotenames` revset

  $ hg log -r "remotenames()" -GT "{rev}:{node|short} {remotenames}\n"
  @  8:3e1487808078 $TESTTMP/server2/wat default/wat
  :
  : o  7:ec2426147f0e $TESTTMP/server2/default default/default
  : |
  : o  6:87d6d6676308 $TESTTMP/server2/bar default/bar
  :/
  o  3:62615734edd5 $TESTTMP/server2/foo default/foo
  |
  ~

`remotebranches` revset

  $ hg log -r "remotebranches()" -GT "{rev}:{node|short} {remotenames}\n"
  @  8:3e1487808078 $TESTTMP/server2/wat default/wat
  |
  ~
  o  7:ec2426147f0e $TESTTMP/server2/default default/default
  |
  ~

`remotebookmarks` revset

  $ hg log -r "remotebookmarks()" -GT "{rev}:{node|short} {remotenames}\n"
  o  6:87d6d6676308 $TESTTMP/server2/bar default/bar
  :
  o  3:62615734edd5 $TESTTMP/server2/foo default/foo
  |
  ~

Updating to revision using hoisted name

Deleting local bookmark to make sure we update to hoisted name only

  $ hg bookmark -d bar

  $ hg up bar
  2 files updated, 0 files merged, 1 files removed, 0 files unresolved

  $ hg log -r .
  changeset:   6:87d6d6676308
  remote bookmark:  $TESTTMP/server2/bar
  remote bookmark:  default/bar
  hoisted name:  bar
  user:        test
  date:        Thu Jan 01 00:00:00 1970 +0000
  summary:     Added g
  
When both local bookmark and hoisted name exists but on different revs

  $ hg up 8
  1 files updated, 0 files merged, 2 files removed, 0 files unresolved

  $ hg bookmark foo
  moving bookmark 'foo' forward from 62615734edd5

Local bookmark should take precedence over hoisted name

  $ hg up foo
  0 files updated, 0 files merged, 0 files removed, 0 files unresolved

  $ hg log -r .
  changeset:   8:3e1487808078
  branch:      wat
  bookmark:    foo
  tag:         tip
  remote branch:  $TESTTMP/server2/wat
  remote branch:  default/wat
  parent:      4:aa98ab95a928
  user:        test
  date:        Thu Jan 01 00:00:00 1970 +0000
  summary:     added bar
  
  $ hg bookmarks
     $TESTTMP/server2/bar 6:87d6d6676308
     $TESTTMP/server2/foo 3:62615734edd5
     default/bar               6:87d6d6676308
     default/foo               3:62615734edd5
   * foo                       8:3e1487808078

Testing the remotenames sychronization during `hg push`
-------------------------------------------------------

  $ cd ../server/
  $ hg bookmark foo
  moving bookmark 'foo' forward from 62615734edd5

After the push, default/foo should move to rev 8
  $ cd ../client/
  $ hg push
  pushing to ssh://user@dummy/server
  searching for changes
  no changes found
  [1]
  $ hg log -Gr 'remotenames()'
  @  changeset:   8:3e1487808078
  :  branch:      wat
  :  bookmark:    foo
  :  tag:         tip
  :  remote bookmark:  default/foo
  :  hoisted name:  foo
  :  remote branch:  $TESTTMP/server2/wat
  :  remote branch:  default/wat
  :  parent:      4:aa98ab95a928
  :  user:        test
  :  date:        Thu Jan 01 00:00:00 1970 +0000
  :  summary:     added bar
  :
  : o  changeset:   7:ec2426147f0e
  : |  remote branch:  $TESTTMP/server2/default
  : |  remote branch:  default/default
  : |  user:        test
  : |  date:        Thu Jan 01 00:00:00 1970 +0000
  : |  summary:     Added h
  : |
  : o  changeset:   6:87d6d6676308
  :/   remote bookmark:  $TESTTMP/server2/bar
  :    remote bookmark:  default/bar
  :    hoisted name:  bar
  :    user:        test
  :    date:        Thu Jan 01 00:00:00 1970 +0000
  :    summary:     Added g
  :
  o  changeset:   3:62615734edd5
  |  remote bookmark:  $TESTTMP/server2/foo
  ~  user:        test
     date:        Thu Jan 01 00:00:00 1970 +0000
     summary:     Added d
  
  $ hg bookmarks
     $TESTTMP/server2/bar 6:87d6d6676308
     $TESTTMP/server2/foo 3:62615734edd5
     default/bar               6:87d6d6676308
     default/foo               8:3e1487808078
   * foo                       8:3e1487808078
