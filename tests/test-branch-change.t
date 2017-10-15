Testing changing branch on commits
==================================

Setup

  $ cat >> $HGRCPATH << EOF
  > [alias]
  > glog = log -G -T "{rev}:{node|short} {desc}\n{branch} ({bookmarks})"
  > [experimental]
  > evolution = createmarkers
  > [extensions]
  > rebase=
  > EOF

  $ hg init repo
  $ cd repo
  $ for ch in a b c d e; do echo foo >> $ch; hg ci -Aqm "Added "$ch; done
  $ hg glog
  @  4:aa98ab95a928 Added e
  |  default ()
  o  3:62615734edd5 Added d
  |  default ()
  o  2:28ad74487de9 Added c
  |  default ()
  o  1:29becc82797a Added b
  |  default ()
  o  0:18d04c59bb5d Added a
     default ()

  $ hg branches
  default                        4:aa98ab95a928

Try without passing a new branch name

  $ hg branch -r .
  abort: no branch name specified for the revisions
  [255]

Setting an invalid branch name

  $ hg branch -r . a:b
  abort: ':' cannot be used in a name
  [255]
  $ hg branch -r . tip
  abort: the name 'tip' is reserved
  [255]
  $ hg branch -r . 1234
  abort: cannot use an integer as a name
  [255]

Change on non-linear set of commits

  $ hg branch -r 2 -r 4 foo
  abort: cannot change branch of non-linear revisions
  [255]

Change in middle of the stack (linear commits)

  $ hg branch -r 1::3 foo
  abort: cannot change branch of changeset with children
  [255]

Change with dirty working directory

  $ echo bar > a
  $ hg branch -r . foo
  abort: uncommitted changes
  [255]

  $ hg revert --all
  reverting a

Change on empty revision set

  $ hg branch -r 'draft() - all()' foo
  abort: empty revision set
  [255]

Changing branch on linear set of commits from head

Without obsmarkers

  $ hg branch -r 3:4 foo --config experimental.evolution=!
  changed branch on 2 changesets
  saved backup bundle to $TESTTMP/repo/.hg/strip-backup/62615734edd5-e86bd13a-branch-change.hg (glob)
  $ hg glog
  @  4:3938acfb5c0f Added e
  |  foo ()
  o  3:9435da006bdc Added d
  |  foo ()
  o  2:28ad74487de9 Added c
  |  default ()
  o  1:29becc82797a Added b
  |  default ()
  o  0:18d04c59bb5d Added a
     default ()

  $ hg branches
  foo                            4:3938acfb5c0f
  default                        2:28ad74487de9 (inactive)

With obsmarkers

  $ hg branch -r 3::4 bar
  changed branch on 2 changesets
  $ hg glog
  @  6:7c1991464886 Added e
  |  bar ()
  o  5:1ea05e93925f Added d
  |  bar ()
  o  2:28ad74487de9 Added c
  |  default ()
  o  1:29becc82797a Added b
  |  default ()
  o  0:18d04c59bb5d Added a
     default ()

  $ hg branches
  bar                            6:7c1991464886
  default                        2:28ad74487de9 (inactive)

Change branch name to an existing branch

  $ hg branch -r . default
  abort: a branch of the same name already exists
  [255]

Changing on a branch head which is not topological head

  $ hg branch -r 2 stable
  abort: cannot change branch of changeset with children
  [255]

Enabling the allowunstable config and trying to change branch on a branch head
which is not a topological head

  $ echo "[experimental]" >> .hg/hgrc
  $ echo "evolution.allowunstable=yes" >> .hg/hgrc
  $ hg branch -r 2 foo
  changed branch on 1 changesets
  2 new orphan changesets

Changing branch of an obsoleted changeset

  $ hg branch -r 4 foobar
  abort: hidden revision '4' was rewritten as: 7c1991464886!
  (use --hidden to access hidden revisions)
  [255]

  $ hg branch -r 4 --hidden foobar
  abort: cannot change branch of a obsolete changeset
  [255]

Make sure bookmark movement is correct

  $ hg bookmark b1
  $ hg glog -r '.^::'
  @  6:7c1991464886 Added e
  |  bar (b1)
  *  5:1ea05e93925f Added d
  |  bar ()
  ~

  $ hg branch -r '(.^)::' wat --debug
  changing branch of '1ea05e93925f806d875a2163f9b76764be644636' from 'bar' to 'wat'
  committing files:
  d
  committing manifest
  committing changelog
  new node id is 343660ccab7400da637bd6a211d07f413536d718
  changing branch of '7c19914648869f5b02fc7fed31ddee9783fdd680' from 'bar' to 'wat'
  committing files:
  e
  committing manifest
  committing changelog
  new node id is de1404b45a69f8cc6437d7679033ee33e9efb4ba
  moving bookmarks ['b1'] from 7c19914648869f5b02fc7fed31ddee9783fdd680 to de1404b45a69f8cc6437d7679033ee33e9efb4ba
  resolving manifests
   branchmerge: False, force: False, partial: False
   ancestor: 7c1991464886, local: 7c1991464886+, remote: de1404b45a69
  changed branch on 2 changesets
  updating the branch cache
  invalid branchheads cache (served): tip differs

  $ hg glog -r '(.^)::'
  @  9:de1404b45a69 Added e
  |  wat (b1)
  *  8:343660ccab74 Added d
  |  wat ()
  ~

Make sure phase handling is correct

  $ echo foo >> bar
  $ hg ci -Aqm "added bar" --secret
  1 new orphan changesets
  $ hg glog -r .
  @  10:8ad1294c1660 added bar
  |  wat (b1)
  ~
  $ hg branch -r . secret
  changed branch on 1 changesets
  $ hg phase -r .
  11: secret

  $ hg branches
  secret                        11:38a9b2d53f98
  foo                            7:8a4729a5e2b8
  wat                            9:de1404b45a69 (inactive)
  default                        2:28ad74487de9 (inactive)
  $ hg branch
  secret

Changing branch of another head, different from one on which we are

  $ hg glog
  @  11:38a9b2d53f98 added bar
  |  secret (b1)
  *  9:de1404b45a69 Added e
  |  wat ()
  *  8:343660ccab74 Added d
  |  wat ()
  | o  7:8a4729a5e2b8 Added c
  | |  foo ()
  x |  2:28ad74487de9 Added c
  |/   default ()
  o  1:29becc82797a Added b
  |  default ()
  o  0:18d04c59bb5d Added a
     default ()

  $ hg branch
  secret

  $ hg branch -r 7 foobar
  changed branch on 1 changesets

The current branch must be preserved
  $ hg branch
  secret

Changing branch on multiple heads at once

  $ hg rebase -s 8 -d 12 --keepbranches -q

  $ hg rebase -s 14 -d 1 --keepbranches -q

  $ hg branch -r 0: stable
  changed branch on 6 changesets
  $ hg glog
  @  23:6a5ddbcfb870 added bar
  |  stable (b1)
  o  22:baedc6e98a67 Added e
  |  stable ()
  | o  21:99ac7bf8aad1 Added d
  | |  stable ()
  | o  20:0ecb4d39c4bd Added c
  |/   stable ()
  o  19:fd45b986b109 Added b
  |  stable ()
  o  18:204d2769eca2 Added a
     stable ()

  $ hg branches
  stable                        23:6a5ddbcfb870

  $ hg branch
  stable

Changing to same branch name does not work

  $ hg branch -r 19::21 stable
  abort: a branch of the same name already exists
  [255]

Testing on merge

  $ hg merge -r 20
  1 files updated, 0 files merged, 0 files removed, 0 files unresolved
  (branch merge, don't forget to commit)

  $ hg branch -r . abcd
  abort: outstanding uncommitted merge
  [255]
  $ hg ci -m "Merge commit"
  $ hg branch -r '(.^)::' def
  abort: cannot change branch of a merge commit
  [255]

Changing branch on public changeset

  $ hg phase -r 21 -p
  $ hg branch -r 21 def
  abort: cannot change branch of public changesets
  (see 'hg help phases' for details)
  [255]
