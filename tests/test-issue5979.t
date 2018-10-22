  $ hg init r1
  $ cd r1
  $ hg ci --config ui.allowemptycommit=true -m c0
  $ hg ci --config ui.allowemptycommit=true -m c1
  $ hg ci --config ui.allowemptycommit=true -m c2
  $ hg co -q 0
  $ hg ci --config ui.allowemptycommit=true -m c3
  created new head
  $ hg co -q 3
  $ hg merge --quiet
  $ hg ci --config ui.allowemptycommit=true -m c4

  $ hg log -G -T'{desc}'
  @    c4
  |\
  | o  c3
  | |
  o |  c2
  | |
  o |  c1
  |/
  o  c0
  

  >>> from mercurial import hg
  >>> from mercurial import ui as uimod
  >>> repo = hg.repository(uimod.ui())
  >>> for anc in repo.changelog.ancestors([4], inclusive=True):
  ...   print(anc)
  4
  3
  2
  1
  0
