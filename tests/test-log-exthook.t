Test hg log changeset printer external hook
-------------------------------------------

  $ cat > $TESTTMP/logexthook.py <<EOF
  > from __future__ import absolute_import
  > import codecs
  > from mercurial import (
  >   commands,
  >   logcmdutil,
  >   repair,
  > )
  > def brot13(b):
  >     return codecs.encode(b.decode('utf8'), 'rot-13').encode('utf8')
  > def rot13description(self, ctx):
  >     description = ctx.description().strip().splitlines()[0]
  >     self.ui.write(b"%s:     %s\n" % (brot13(b"summary"),
  >                                      brot13(description)))
  > def reposetup(ui, repo):
  >     logcmdutil.changesetprinter._exthook = rot13description
  > EOF

Prepare the repository

  $ hg init empty
  $ cd empty
  $ touch ROOT
  $ hg commit -A -m "Root" ROOT

  $ touch a b c
  $ hg commit -A -m "Add A, B, C" a b c

Check the log

  $ hg log --config extensions.t=$TESTTMP/logexthook.py
  changeset:   1:70fc82b23320
  tag:         tip
  user:        test
  date:        Thu Jan 01 00:00:00 1970 +0000
  fhzznel:     Nqq N, O, P
  summary:     Add A, B, C
  
  changeset:   0:b00443a54871
  user:        test
  date:        Thu Jan 01 00:00:00 1970 +0000
  fhzznel:     Ebbg
  summary:     Root
  
Check that exthook is working with graph log too

  $ hg log -G --config extensions.t=$TESTTMP/logexthook.py
  @  changeset:   1:70fc82b23320
  |  tag:         tip
  |  user:        test
  |  date:        Thu Jan 01 00:00:00 1970 +0000
  |  fhzznel:     Nqq N, O, P
  |  summary:     Add A, B, C
  |
  o  changeset:   0:b00443a54871
     user:        test
     date:        Thu Jan 01 00:00:00 1970 +0000
     fhzznel:     Ebbg
     summary:     Root
  
