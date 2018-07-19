@  (34) head
|
| o  (33) head
| |
o |    (32) expand
|\ \
| o \    (31) expand
| |\ \
| | o \    (30) expand
| | |\ \
| | | o |  (29) regular commit
| | | | |
| | o | |    (28) merge zero known
| | |\ \ \
o | | | | |  (27) collapse
|/ / / / /
| | o---+  (26) merge one known; far right
| | | | |
+---o | |  (25) merge one known; far left
| | | | |
| | o | |  (24) merge one known; immediate right
| | |\| |
| | o | |  (23) merge one known; immediate left
| |/| | |
+---o---+  (22) merge two known; one far left, one far right
| |  / /
o | | |    (21) expand
|\ \ \ \
| o---+-+  (20) merge two known; two far right
|  / / /
o | | |    (19) expand
|\ \ \ \
+---+---o  (18) merge two known; two far left
| | | |
| o | |    (17) expand
| |\ \ \
| | o---+  (16) merge two known; one immediate right, one near right
| | |/ /
o | | |    (15) expand
|\ \ \ \
| o-----+  (14) merge two known; one immediate right, one far right
| |/ / /
o | | |    (13) expand
|\ \ \ \
+---o | |  (12) merge two known; one immediate right, one far left
| | |/ /
| o | |    (11) expand
| |\ \ \
| | o---+  (10) merge two known; one immediate left, one near right
| |/ / /
o | | |    (9) expand
|\ \ \ \
| o-----+  (8) merge two known; one immediate left, one far right
|/ / / /
o | | |    (7) expand
|\ \ \ \
+---o | |  (6) merge two known; one immediate left, one far left
| |/ / /
| o | |    (5) expand
| |\ \ \
| | o | |  (4) merge two known; one immediate left, one immediate right
| |/|/ /
| o / /  (3) collapse
|/ / /
o / /  (2) collapse
|/ /
o /  (1) collapse
|/
o  (0) root

  $ commit()
  > {
  >   rev=$1
  >   msg=$2
  >   shift 2
  >   if [ "$#" -gt 0 ]; then
  >       hg debugsetparents "$@"
  >   fi
  >   echo $rev > a
  >   hg commit -Aqd "$rev 0" -m "($rev) $msg"
  > }

  $ cat > printrevset.py <<EOF
  > from __future__ import absolute_import
  > from mercurial import (
  >   cmdutil,
  >   commands,
  >   extensions,
  >   logcmdutil,
  >   revsetlang,
  >   smartset,
  > )
  > 
  > from mercurial.utils import (
  >   stringutil,
  > )
  > 
  > def logrevset(repo, pats, opts):
  >     revs = logcmdutil._initialrevs(repo, opts)
  >     if not revs:
  >         return None
  >     match, pats, slowpath = logcmdutil._makematcher(repo, revs, pats, opts)
  >     return logcmdutil._makerevset(repo, match, pats, slowpath, opts)
  > 
  > def uisetup(ui):
  >     def printrevset(orig, repo, pats, opts):
  >         revs, filematcher = orig(repo, pats, opts)
  >         if opts.get(b'print_revset'):
  >             expr = logrevset(repo, pats, opts)
  >             if expr:
  >                 tree = revsetlang.parse(expr)
  >                 tree = revsetlang.analyze(tree)
  >             else:
  >                 tree = []
  >             ui = repo.ui
  >             ui.write(b'%r\n' % (opts.get(b'rev', []),))
  >             ui.write(revsetlang.prettyformat(tree) + b'\n')
  >             ui.write(stringutil.prettyrepr(revs) + b'\n')
  >             revs = smartset.baseset()  # display no revisions
  >         return revs, filematcher
  >     extensions.wrapfunction(logcmdutil, 'getrevs', printrevset)
  >     aliases, entry = cmdutil.findcmd(b'log', commands.table)
  >     entry[1].append((b'', b'print-revset', False,
  >                      b'print generated revset and exit (DEPRECATED)'))
  > EOF

  $ echo "[extensions]" >> $HGRCPATH
  $ echo "printrevset=`pwd`/printrevset.py" >> $HGRCPATH
  $ echo "beautifygraph=" >> $HGRCPATH

Set a default of narrow-text UTF-8.

  $ HGENCODING=UTF-8; export HGENCODING
  $ HGENCODINGAMBIGUOUS=narrow; export HGENCODINGAMBIGUOUS

Empty repo:

  $ hg init repo
  $ cd repo
  $ hg log -G

Building DAG:

  $ commit 0 "root"
  $ commit 1 "collapse" 0
  $ commit 2 "collapse" 1
  $ commit 3 "collapse" 2
  $ commit 4 "merge two known; one immediate left, one immediate right" 1 3
  $ commit 5 "expand" 3 4
  $ commit 6 "merge two known; one immediate left, one far left" 2 5
  $ commit 7 "expand" 2 5
  $ commit 8 "merge two known; one immediate left, one far right" 0 7
  $ commit 9 "expand" 7 8
  $ commit 10 "merge two known; one immediate left, one near right" 0 6
  $ commit 11 "expand" 6 10
  $ commit 12 "merge two known; one immediate right, one far left" 1 9
  $ commit 13 "expand" 9 11
  $ commit 14 "merge two known; one immediate right, one far right" 0 12
  $ commit 15 "expand" 13 14
  $ commit 16 "merge two known; one immediate right, one near right" 0 1
  $ commit 17 "expand" 12 16
  $ commit 18 "merge two known; two far left" 1 15
  $ commit 19 "expand" 15 17
  $ commit 20 "merge two known; two far right" 0 18
  $ commit 21 "expand" 19 20
  $ commit 22 "merge two known; one far left, one far right" 18 21
  $ commit 23 "merge one known; immediate left" 1 22
  $ commit 24 "merge one known; immediate right" 0 23
  $ commit 25 "merge one known; far left" 21 24
  $ commit 26 "merge one known; far right" 18 25
  $ commit 27 "collapse" 21
  $ commit 28 "merge zero known" 1 26
  $ commit 29 "regular commit" 0
  $ commit 30 "expand" 28 29
  $ commit 31 "expand" 21 30
  $ commit 32 "expand" 27 31
  $ commit 33 "head" 18
  $ commit 34 "head" 32

The extension should not turn on unless we're in UTF-8.

  $ HGENCODING=latin1 hg log -G -q
  beautifygraph: unsupported encoding, UTF-8 required
  @  34:fea3ac5810e0
  |
  | o  33:68608f5145f9
  | |
  o |    32:d06dffa21a31
  |\ \
  | o \    31:621d83e11f67
  | |\ \
  | | o \    30:6e11cd4b648f
  | | |\ \
  | | | o |  29:cd9bb2be7593
  | | | | |
  | | o | |    28:44ecd0b9ae99
  | | |\ \ \
  o | | | | |  27:886ed638191b
  |/ / / / /
  | | o---+  26:7f25b6c2f0b9
  | | | | |
  +---o | |  25:91da8ed57247
  | | | | |
  | | o | |  24:a9c19a3d96b7
  | | |\| |
  | | o | |  23:a01cddf0766d
  | |/| | |
  +---o---+  22:e0d9cccacb5d
  | |  / /
  o | | |    21:d42a756af44d
  |\ \ \ \
  | o---+-+  20:d30ed6450e32
  |  / / /
  o | | |    19:31ddc2c1573b
  |\ \ \ \
  +---+---o  18:1aa84d96232a
  | | | |
  | o | |    17:44765d7c06e0
  | |\ \ \
  | | o---+  16:3677d192927d
  | | |/ /
  o | | |    15:1dda3f72782d
  |\ \ \ \
  | o-----+  14:8eac370358ef
  | |/ / /
  o | | |    13:22d8966a97e3
  |\ \ \ \
  +---o | |  12:86b91144a6e9
  | | |/ /
  | o | |    11:832d76e6bdf2
  | |\ \ \
  | | o---+  10:74c64d036d72
  | |/ / /
  o | | |    9:7010c0af0a35
  |\ \ \ \
  | o-----+  8:7a0b11f71937
  |/ / / /
  o | | |    7:b632bb1b1224
  |\ \ \ \
  +---o | |  6:b105a072e251
  | |/ / /
  | o | |    5:4409d547b708
  | |\ \ \
  | | o | |  4:26a8bac39d9f
  | |/|/ /
  | o / /  3:27eef8ed80b4
  |/ / /
  o / /  2:3d9a33b8d1e1
  |/ /
  o /  1:6db2ef61d156
  |/
  o  0:e6eb3150255d
  

The extension should not turn on if we're using wide text.

  $ HGENCODINGAMBIGUOUS=wide hg log -G -q
  beautifygraph: unsupported terminal settings, monospace narrow text required
  @  34:fea3ac5810e0
  |
  | o  33:68608f5145f9
  | |
  o |    32:d06dffa21a31
  |\ \
  | o \    31:621d83e11f67
  | |\ \
  | | o \    30:6e11cd4b648f
  | | |\ \
  | | | o |  29:cd9bb2be7593
  | | | | |
  | | o | |    28:44ecd0b9ae99
  | | |\ \ \
  o | | | | |  27:886ed638191b
  |/ / / / /
  | | o---+  26:7f25b6c2f0b9
  | | | | |
  +---o | |  25:91da8ed57247
  | | | | |
  | | o | |  24:a9c19a3d96b7
  | | |\| |
  | | o | |  23:a01cddf0766d
  | |/| | |
  +---o---+  22:e0d9cccacb5d
  | |  / /
  o | | |    21:d42a756af44d
  |\ \ \ \
  | o---+-+  20:d30ed6450e32
  |  / / /
  o | | |    19:31ddc2c1573b
  |\ \ \ \
  +---+---o  18:1aa84d96232a
  | | | |
  | o | |    17:44765d7c06e0
  | |\ \ \
  | | o---+  16:3677d192927d
  | | |/ /
  o | | |    15:1dda3f72782d
  |\ \ \ \
  | o-----+  14:8eac370358ef
  | |/ / /
  o | | |    13:22d8966a97e3
  |\ \ \ \
  +---o | |  12:86b91144a6e9
  | | |/ /
  | o | |    11:832d76e6bdf2
  | |\ \ \
  | | o---+  10:74c64d036d72
  | |/ / /
  o | | |    9:7010c0af0a35
  |\ \ \ \
  | o-----+  8:7a0b11f71937
  |/ / / /
  o | | |    7:b632bb1b1224
  |\ \ \ \
  +---o | |  6:b105a072e251
  | |/ / /
  | o | |    5:4409d547b708
  | |\ \ \
  | | o | |  4:26a8bac39d9f
  | |/|/ /
  | o / /  3:27eef8ed80b4
  |/ / /
  o / /  2:3d9a33b8d1e1
  |/ /
  o /  1:6db2ef61d156
  |/
  o  0:e6eb3150255d
  

The rest of our tests will use the default narrow text UTF-8.

  $ hg log -G -q
  \xe2\x97\x8d  34:fea3ac5810e0 (esc)
  \xe2\x94\x82 (esc)
  \xe2\x94\x82 \xe2\x97\x8b  33:68608f5145f9 (esc)
  \xe2\x94\x82 \xe2\x94\x82 (esc)
  \xe2\x97\x8b \xe2\x94\x82  32:d06dffa21a31 (esc)
  \xe2\x94\x82\xe2\x95\xb2 \xe2\x95\xb2 (esc)
  \xe2\x94\x82 \xe2\x97\x8b \xe2\x95\xb2  31:621d83e11f67 (esc)
  \xe2\x94\x82 \xe2\x94\x82\xe2\x95\xb2 \xe2\x95\xb2 (esc)
  \xe2\x94\x82 \xe2\x94\x82 \xe2\x97\x8b \xe2\x95\xb2  30:6e11cd4b648f (esc)
  \xe2\x94\x82 \xe2\x94\x82 \xe2\x94\x82\xe2\x95\xb2 \xe2\x95\xb2 (esc)
  \xe2\x94\x82 \xe2\x94\x82 \xe2\x94\x82 \xe2\x97\x8b \xe2\x94\x82  29:cd9bb2be7593 (esc)
  \xe2\x94\x82 \xe2\x94\x82 \xe2\x94\x82 \xe2\x94\x82 \xe2\x94\x82 (esc)
  \xe2\x94\x82 \xe2\x94\x82 \xe2\x97\x8b \xe2\x94\x82 \xe2\x94\x82  28:44ecd0b9ae99 (esc)
  \xe2\x94\x82 \xe2\x94\x82 \xe2\x94\x82\xe2\x95\xb2 \xe2\x95\xb2 \xe2\x95\xb2 (esc)
  \xe2\x97\x8b \xe2\x94\x82 \xe2\x94\x82 \xe2\x94\x82 \xe2\x94\x82 \xe2\x94\x82  27:886ed638191b (esc)
  \xe2\x94\x82\xe2\x95\xb1 \xe2\x95\xb1 \xe2\x95\xb1 \xe2\x95\xb1 \xe2\x95\xb1 (esc)
  \xe2\x94\x82 \xe2\x94\x82 \xe2\x97\x8b\xe2\x94\x80\xe2\x94\x80\xe2\x94\x80\xe2\x94\xa4  26:7f25b6c2f0b9 (esc)
  \xe2\x94\x82 \xe2\x94\x82 \xe2\x94\x82 \xe2\x94\x82 \xe2\x94\x82 (esc)
  \xe2\x94\x9c\xe2\x94\x80\xe2\x94\x80\xe2\x94\x80\xe2\x97\x8b \xe2\x94\x82 \xe2\x94\x82  25:91da8ed57247 (esc)
  \xe2\x94\x82 \xe2\x94\x82 \xe2\x94\x82 \xe2\x94\x82 \xe2\x94\x82 (esc)
  \xe2\x94\x82 \xe2\x94\x82 \xe2\x97\x8b \xe2\x94\x82 \xe2\x94\x82  24:a9c19a3d96b7 (esc)
  \xe2\x94\x82 \xe2\x94\x82 \xe2\x94\x82\xe2\x95\xb2\xe2\x94\x82 \xe2\x94\x82 (esc)
  \xe2\x94\x82 \xe2\x94\x82 \xe2\x97\x8b \xe2\x94\x82 \xe2\x94\x82  23:a01cddf0766d (esc)
  \xe2\x94\x82 \xe2\x94\x82\xe2\x95\xb1\xe2\x94\x82 \xe2\x94\x82 \xe2\x94\x82 (esc)
  \xe2\x94\x9c\xe2\x94\x80\xe2\x94\x80\xe2\x94\x80\xe2\x97\x8b\xe2\x94\x80\xe2\x94\x80\xe2\x94\x80\xe2\x94\xa4  22:e0d9cccacb5d (esc)
  \xe2\x94\x82 \xe2\x94\x82  \xe2\x95\xb1 \xe2\x95\xb1 (esc)
  \xe2\x97\x8b \xe2\x94\x82 \xe2\x94\x82 \xe2\x94\x82  21:d42a756af44d (esc)
  \xe2\x94\x82\xe2\x95\xb2 \xe2\x95\xb2 \xe2\x95\xb2 \xe2\x95\xb2 (esc)
  \xe2\x94\x82 \xe2\x97\x8b\xe2\x94\x80\xe2\x94\x80\xe2\x94\x80\xe2\x94\xbc\xe2\x94\x80\xe2\x94\xa4  20:d30ed6450e32 (esc)
  \xe2\x94\x82  \xe2\x95\xb1 \xe2\x95\xb1 \xe2\x95\xb1 (esc)
  \xe2\x97\x8b \xe2\x94\x82 \xe2\x94\x82 \xe2\x94\x82  19:31ddc2c1573b (esc)
  \xe2\x94\x82\xe2\x95\xb2 \xe2\x95\xb2 \xe2\x95\xb2 \xe2\x95\xb2 (esc)
  \xe2\x94\x9c\xe2\x94\x80\xe2\x94\x80\xe2\x94\x80\xe2\x94\xbc\xe2\x94\x80\xe2\x94\x80\xe2\x94\x80\xe2\x97\x8b  18:1aa84d96232a (esc)
  \xe2\x94\x82 \xe2\x94\x82 \xe2\x94\x82 \xe2\x94\x82 (esc)
  \xe2\x94\x82 \xe2\x97\x8b \xe2\x94\x82 \xe2\x94\x82  17:44765d7c06e0 (esc)
  \xe2\x94\x82 \xe2\x94\x82\xe2\x95\xb2 \xe2\x95\xb2 \xe2\x95\xb2 (esc)
  \xe2\x94\x82 \xe2\x94\x82 \xe2\x97\x8b\xe2\x94\x80\xe2\x94\x80\xe2\x94\x80\xe2\x94\xa4  16:3677d192927d (esc)
  \xe2\x94\x82 \xe2\x94\x82 \xe2\x94\x82\xe2\x95\xb1 \xe2\x95\xb1 (esc)
  \xe2\x97\x8b \xe2\x94\x82 \xe2\x94\x82 \xe2\x94\x82  15:1dda3f72782d (esc)
  \xe2\x94\x82\xe2\x95\xb2 \xe2\x95\xb2 \xe2\x95\xb2 \xe2\x95\xb2 (esc)
  \xe2\x94\x82 \xe2\x97\x8b\xe2\x94\x80\xe2\x94\x80\xe2\x94\x80\xe2\x94\x80\xe2\x94\x80\xe2\x94\xa4  14:8eac370358ef (esc)
  \xe2\x94\x82 \xe2\x94\x82\xe2\x95\xb1 \xe2\x95\xb1 \xe2\x95\xb1 (esc)
  \xe2\x97\x8b \xe2\x94\x82 \xe2\x94\x82 \xe2\x94\x82  13:22d8966a97e3 (esc)
  \xe2\x94\x82\xe2\x95\xb2 \xe2\x95\xb2 \xe2\x95\xb2 \xe2\x95\xb2 (esc)
  \xe2\x94\x9c\xe2\x94\x80\xe2\x94\x80\xe2\x94\x80\xe2\x97\x8b \xe2\x94\x82 \xe2\x94\x82  12:86b91144a6e9 (esc)
  \xe2\x94\x82 \xe2\x94\x82 \xe2\x94\x82\xe2\x95\xb1 \xe2\x95\xb1 (esc)
  \xe2\x94\x82 \xe2\x97\x8b \xe2\x94\x82 \xe2\x94\x82  11:832d76e6bdf2 (esc)
  \xe2\x94\x82 \xe2\x94\x82\xe2\x95\xb2 \xe2\x95\xb2 \xe2\x95\xb2 (esc)
  \xe2\x94\x82 \xe2\x94\x82 \xe2\x97\x8b\xe2\x94\x80\xe2\x94\x80\xe2\x94\x80\xe2\x94\xa4  10:74c64d036d72 (esc)
  \xe2\x94\x82 \xe2\x94\x82\xe2\x95\xb1 \xe2\x95\xb1 \xe2\x95\xb1 (esc)
  \xe2\x97\x8b \xe2\x94\x82 \xe2\x94\x82 \xe2\x94\x82  9:7010c0af0a35 (esc)
  \xe2\x94\x82\xe2\x95\xb2 \xe2\x95\xb2 \xe2\x95\xb2 \xe2\x95\xb2 (esc)
  \xe2\x94\x82 \xe2\x97\x8b\xe2\x94\x80\xe2\x94\x80\xe2\x94\x80\xe2\x94\x80\xe2\x94\x80\xe2\x94\xa4  8:7a0b11f71937 (esc)
  \xe2\x94\x82\xe2\x95\xb1 \xe2\x95\xb1 \xe2\x95\xb1 \xe2\x95\xb1 (esc)
  \xe2\x97\x8b \xe2\x94\x82 \xe2\x94\x82 \xe2\x94\x82  7:b632bb1b1224 (esc)
  \xe2\x94\x82\xe2\x95\xb2 \xe2\x95\xb2 \xe2\x95\xb2 \xe2\x95\xb2 (esc)
  \xe2\x94\x9c\xe2\x94\x80\xe2\x94\x80\xe2\x94\x80\xe2\x97\x8b \xe2\x94\x82 \xe2\x94\x82  6:b105a072e251 (esc)
  \xe2\x94\x82 \xe2\x94\x82\xe2\x95\xb1 \xe2\x95\xb1 \xe2\x95\xb1 (esc)
  \xe2\x94\x82 \xe2\x97\x8b \xe2\x94\x82 \xe2\x94\x82  5:4409d547b708 (esc)
  \xe2\x94\x82 \xe2\x94\x82\xe2\x95\xb2 \xe2\x95\xb2 \xe2\x95\xb2 (esc)
  \xe2\x94\x82 \xe2\x94\x82 \xe2\x97\x8b \xe2\x94\x82 \xe2\x94\x82  4:26a8bac39d9f (esc)
  \xe2\x94\x82 \xe2\x94\x82\xe2\x95\xb1\xe2\x94\x82\xe2\x95\xb1 \xe2\x95\xb1 (esc)
  \xe2\x94\x82 \xe2\x97\x8b \xe2\x95\xb1 \xe2\x95\xb1  3:27eef8ed80b4 (esc)
  \xe2\x94\x82\xe2\x95\xb1 \xe2\x95\xb1 \xe2\x95\xb1 (esc)
  \xe2\x97\x8b \xe2\x95\xb1 \xe2\x95\xb1  2:3d9a33b8d1e1 (esc)
  \xe2\x94\x82\xe2\x95\xb1 \xe2\x95\xb1 (esc)
  \xe2\x97\x8b \xe2\x95\xb1  1:6db2ef61d156 (esc)
  \xe2\x94\x82\xe2\x95\xb1 (esc)
  \xe2\x97\x8b  0:e6eb3150255d (esc)
  

  $ hg log -G
  \xe2\x97\x8d  changeset:   34:fea3ac5810e0 (esc)
  \xe2\x94\x82  tag:         tip (esc)
  \xe2\x94\x82  parent:      32:d06dffa21a31 (esc)
  \xe2\x94\x82  user:        test (esc)
  \xe2\x94\x82  date:        Thu Jan 01 00:00:34 1970 +0000 (esc)
  \xe2\x94\x82  summary:     (34) head (esc)
  \xe2\x94\x82 (esc)
  \xe2\x94\x82 \xe2\x97\x8b  changeset:   33:68608f5145f9 (esc)
  \xe2\x94\x82 \xe2\x94\x82  parent:      18:1aa84d96232a (esc)
  \xe2\x94\x82 \xe2\x94\x82  user:        test (esc)
  \xe2\x94\x82 \xe2\x94\x82  date:        Thu Jan 01 00:00:33 1970 +0000 (esc)
  \xe2\x94\x82 \xe2\x94\x82  summary:     (33) head (esc)
  \xe2\x94\x82 \xe2\x94\x82 (esc)
  \xe2\x97\x8b \xe2\x94\x82  changeset:   32:d06dffa21a31 (esc)
  \xe2\x94\x82\xe2\x95\xb2 \xe2\x95\xb2   parent:      27:886ed638191b (esc)
  \xe2\x94\x82 \xe2\x94\x82 \xe2\x94\x82  parent:      31:621d83e11f67 (esc)
  \xe2\x94\x82 \xe2\x94\x82 \xe2\x94\x82  user:        test (esc)
  \xe2\x94\x82 \xe2\x94\x82 \xe2\x94\x82  date:        Thu Jan 01 00:00:32 1970 +0000 (esc)
  \xe2\x94\x82 \xe2\x94\x82 \xe2\x94\x82  summary:     (32) expand (esc)
  \xe2\x94\x82 \xe2\x94\x82 \xe2\x94\x82 (esc)
  \xe2\x94\x82 \xe2\x97\x8b \xe2\x94\x82  changeset:   31:621d83e11f67 (esc)
  \xe2\x94\x82 \xe2\x94\x82\xe2\x95\xb2 \xe2\x95\xb2   parent:      21:d42a756af44d (esc)
  \xe2\x94\x82 \xe2\x94\x82 \xe2\x94\x82 \xe2\x94\x82  parent:      30:6e11cd4b648f (esc)
  \xe2\x94\x82 \xe2\x94\x82 \xe2\x94\x82 \xe2\x94\x82  user:        test (esc)
  \xe2\x94\x82 \xe2\x94\x82 \xe2\x94\x82 \xe2\x94\x82  date:        Thu Jan 01 00:00:31 1970 +0000 (esc)
  \xe2\x94\x82 \xe2\x94\x82 \xe2\x94\x82 \xe2\x94\x82  summary:     (31) expand (esc)
  \xe2\x94\x82 \xe2\x94\x82 \xe2\x94\x82 \xe2\x94\x82 (esc)
  \xe2\x94\x82 \xe2\x94\x82 \xe2\x97\x8b \xe2\x94\x82  changeset:   30:6e11cd4b648f (esc)
  \xe2\x94\x82 \xe2\x94\x82 \xe2\x94\x82\xe2\x95\xb2 \xe2\x95\xb2   parent:      28:44ecd0b9ae99 (esc)
  \xe2\x94\x82 \xe2\x94\x82 \xe2\x94\x82 \xe2\x94\x82 \xe2\x94\x82  parent:      29:cd9bb2be7593 (esc)
  \xe2\x94\x82 \xe2\x94\x82 \xe2\x94\x82 \xe2\x94\x82 \xe2\x94\x82  user:        test (esc)
  \xe2\x94\x82 \xe2\x94\x82 \xe2\x94\x82 \xe2\x94\x82 \xe2\x94\x82  date:        Thu Jan 01 00:00:30 1970 +0000 (esc)
  \xe2\x94\x82 \xe2\x94\x82 \xe2\x94\x82 \xe2\x94\x82 \xe2\x94\x82  summary:     (30) expand (esc)
  \xe2\x94\x82 \xe2\x94\x82 \xe2\x94\x82 \xe2\x94\x82 \xe2\x94\x82 (esc)
  \xe2\x94\x82 \xe2\x94\x82 \xe2\x94\x82 \xe2\x97\x8b \xe2\x94\x82  changeset:   29:cd9bb2be7593 (esc)
  \xe2\x94\x82 \xe2\x94\x82 \xe2\x94\x82 \xe2\x94\x82 \xe2\x94\x82  parent:      0:e6eb3150255d (esc)
  \xe2\x94\x82 \xe2\x94\x82 \xe2\x94\x82 \xe2\x94\x82 \xe2\x94\x82  user:        test (esc)
  \xe2\x94\x82 \xe2\x94\x82 \xe2\x94\x82 \xe2\x94\x82 \xe2\x94\x82  date:        Thu Jan 01 00:00:29 1970 +0000 (esc)
  \xe2\x94\x82 \xe2\x94\x82 \xe2\x94\x82 \xe2\x94\x82 \xe2\x94\x82  summary:     (29) regular commit (esc)
  \xe2\x94\x82 \xe2\x94\x82 \xe2\x94\x82 \xe2\x94\x82 \xe2\x94\x82 (esc)
  \xe2\x94\x82 \xe2\x94\x82 \xe2\x97\x8b \xe2\x94\x82 \xe2\x94\x82  changeset:   28:44ecd0b9ae99 (esc)
  \xe2\x94\x82 \xe2\x94\x82 \xe2\x94\x82\xe2\x95\xb2 \xe2\x95\xb2 \xe2\x95\xb2   parent:      1:6db2ef61d156 (esc)
  \xe2\x94\x82 \xe2\x94\x82 \xe2\x94\x82 \xe2\x94\x82 \xe2\x94\x82 \xe2\x94\x82  parent:      26:7f25b6c2f0b9 (esc)
  \xe2\x94\x82 \xe2\x94\x82 \xe2\x94\x82 \xe2\x94\x82 \xe2\x94\x82 \xe2\x94\x82  user:        test (esc)
  \xe2\x94\x82 \xe2\x94\x82 \xe2\x94\x82 \xe2\x94\x82 \xe2\x94\x82 \xe2\x94\x82  date:        Thu Jan 01 00:00:28 1970 +0000 (esc)
  \xe2\x94\x82 \xe2\x94\x82 \xe2\x94\x82 \xe2\x94\x82 \xe2\x94\x82 \xe2\x94\x82  summary:     (28) merge zero known (esc)
  \xe2\x94\x82 \xe2\x94\x82 \xe2\x94\x82 \xe2\x94\x82 \xe2\x94\x82 \xe2\x94\x82 (esc)
  \xe2\x97\x8b \xe2\x94\x82 \xe2\x94\x82 \xe2\x94\x82 \xe2\x94\x82 \xe2\x94\x82  changeset:   27:886ed638191b (esc)
  \xe2\x94\x82\xe2\x95\xb1 \xe2\x95\xb1 \xe2\x95\xb1 \xe2\x95\xb1 \xe2\x95\xb1   parent:      21:d42a756af44d (esc)
  \xe2\x94\x82 \xe2\x94\x82 \xe2\x94\x82 \xe2\x94\x82 \xe2\x94\x82    user:        test (esc)
  \xe2\x94\x82 \xe2\x94\x82 \xe2\x94\x82 \xe2\x94\x82 \xe2\x94\x82    date:        Thu Jan 01 00:00:27 1970 +0000 (esc)
  \xe2\x94\x82 \xe2\x94\x82 \xe2\x94\x82 \xe2\x94\x82 \xe2\x94\x82    summary:     (27) collapse (esc)
  \xe2\x94\x82 \xe2\x94\x82 \xe2\x94\x82 \xe2\x94\x82 \xe2\x94\x82 (esc)
  \xe2\x94\x82 \xe2\x94\x82 \xe2\x97\x8b\xe2\x94\x80\xe2\x94\x80\xe2\x94\x80\xe2\x94\xa4  changeset:   26:7f25b6c2f0b9 (esc)
  \xe2\x94\x82 \xe2\x94\x82 \xe2\x94\x82 \xe2\x94\x82 \xe2\x94\x82  parent:      18:1aa84d96232a (esc)
  \xe2\x94\x82 \xe2\x94\x82 \xe2\x94\x82 \xe2\x94\x82 \xe2\x94\x82  parent:      25:91da8ed57247 (esc)
  \xe2\x94\x82 \xe2\x94\x82 \xe2\x94\x82 \xe2\x94\x82 \xe2\x94\x82  user:        test (esc)
  \xe2\x94\x82 \xe2\x94\x82 \xe2\x94\x82 \xe2\x94\x82 \xe2\x94\x82  date:        Thu Jan 01 00:00:26 1970 +0000 (esc)
  \xe2\x94\x82 \xe2\x94\x82 \xe2\x94\x82 \xe2\x94\x82 \xe2\x94\x82  summary:     (26) merge one known; far right (esc)
  \xe2\x94\x82 \xe2\x94\x82 \xe2\x94\x82 \xe2\x94\x82 \xe2\x94\x82 (esc)
  \xe2\x94\x9c\xe2\x94\x80\xe2\x94\x80\xe2\x94\x80\xe2\x97\x8b \xe2\x94\x82 \xe2\x94\x82  changeset:   25:91da8ed57247 (esc)
  \xe2\x94\x82 \xe2\x94\x82 \xe2\x94\x82 \xe2\x94\x82 \xe2\x94\x82  parent:      21:d42a756af44d (esc)
  \xe2\x94\x82 \xe2\x94\x82 \xe2\x94\x82 \xe2\x94\x82 \xe2\x94\x82  parent:      24:a9c19a3d96b7 (esc)
  \xe2\x94\x82 \xe2\x94\x82 \xe2\x94\x82 \xe2\x94\x82 \xe2\x94\x82  user:        test (esc)
  \xe2\x94\x82 \xe2\x94\x82 \xe2\x94\x82 \xe2\x94\x82 \xe2\x94\x82  date:        Thu Jan 01 00:00:25 1970 +0000 (esc)
  \xe2\x94\x82 \xe2\x94\x82 \xe2\x94\x82 \xe2\x94\x82 \xe2\x94\x82  summary:     (25) merge one known; far left (esc)
  \xe2\x94\x82 \xe2\x94\x82 \xe2\x94\x82 \xe2\x94\x82 \xe2\x94\x82 (esc)
  \xe2\x94\x82 \xe2\x94\x82 \xe2\x97\x8b \xe2\x94\x82 \xe2\x94\x82  changeset:   24:a9c19a3d96b7 (esc)
  \xe2\x94\x82 \xe2\x94\x82 \xe2\x94\x82\xe2\x95\xb2\xe2\x94\x82 \xe2\x94\x82  parent:      0:e6eb3150255d (esc)
  \xe2\x94\x82 \xe2\x94\x82 \xe2\x94\x82 \xe2\x94\x82 \xe2\x94\x82  parent:      23:a01cddf0766d (esc)
  \xe2\x94\x82 \xe2\x94\x82 \xe2\x94\x82 \xe2\x94\x82 \xe2\x94\x82  user:        test (esc)
  \xe2\x94\x82 \xe2\x94\x82 \xe2\x94\x82 \xe2\x94\x82 \xe2\x94\x82  date:        Thu Jan 01 00:00:24 1970 +0000 (esc)
  \xe2\x94\x82 \xe2\x94\x82 \xe2\x94\x82 \xe2\x94\x82 \xe2\x94\x82  summary:     (24) merge one known; immediate right (esc)
  \xe2\x94\x82 \xe2\x94\x82 \xe2\x94\x82 \xe2\x94\x82 \xe2\x94\x82 (esc)
  \xe2\x94\x82 \xe2\x94\x82 \xe2\x97\x8b \xe2\x94\x82 \xe2\x94\x82  changeset:   23:a01cddf0766d (esc)
  \xe2\x94\x82 \xe2\x94\x82\xe2\x95\xb1\xe2\x94\x82 \xe2\x94\x82 \xe2\x94\x82  parent:      1:6db2ef61d156 (esc)
  \xe2\x94\x82 \xe2\x94\x82 \xe2\x94\x82 \xe2\x94\x82 \xe2\x94\x82  parent:      22:e0d9cccacb5d (esc)
  \xe2\x94\x82 \xe2\x94\x82 \xe2\x94\x82 \xe2\x94\x82 \xe2\x94\x82  user:        test (esc)
  \xe2\x94\x82 \xe2\x94\x82 \xe2\x94\x82 \xe2\x94\x82 \xe2\x94\x82  date:        Thu Jan 01 00:00:23 1970 +0000 (esc)
  \xe2\x94\x82 \xe2\x94\x82 \xe2\x94\x82 \xe2\x94\x82 \xe2\x94\x82  summary:     (23) merge one known; immediate left (esc)
  \xe2\x94\x82 \xe2\x94\x82 \xe2\x94\x82 \xe2\x94\x82 \xe2\x94\x82 (esc)
  \xe2\x94\x9c\xe2\x94\x80\xe2\x94\x80\xe2\x94\x80\xe2\x97\x8b\xe2\x94\x80\xe2\x94\x80\xe2\x94\x80\xe2\x94\xa4  changeset:   22:e0d9cccacb5d (esc)
  \xe2\x94\x82 \xe2\x94\x82   \xe2\x94\x82 \xe2\x94\x82  parent:      18:1aa84d96232a (esc)
  \xe2\x94\x82 \xe2\x94\x82  \xe2\x95\xb1 \xe2\x95\xb1   parent:      21:d42a756af44d (esc)
  \xe2\x94\x82 \xe2\x94\x82 \xe2\x94\x82 \xe2\x94\x82    user:        test (esc)
  \xe2\x94\x82 \xe2\x94\x82 \xe2\x94\x82 \xe2\x94\x82    date:        Thu Jan 01 00:00:22 1970 +0000 (esc)
  \xe2\x94\x82 \xe2\x94\x82 \xe2\x94\x82 \xe2\x94\x82    summary:     (22) merge two known; one far left, one far right (esc)
  \xe2\x94\x82 \xe2\x94\x82 \xe2\x94\x82 \xe2\x94\x82 (esc)
  \xe2\x97\x8b \xe2\x94\x82 \xe2\x94\x82 \xe2\x94\x82  changeset:   21:d42a756af44d (esc)
  \xe2\x94\x82\xe2\x95\xb2 \xe2\x95\xb2 \xe2\x95\xb2 \xe2\x95\xb2   parent:      19:31ddc2c1573b (esc)
  \xe2\x94\x82 \xe2\x94\x82 \xe2\x94\x82 \xe2\x94\x82 \xe2\x94\x82  parent:      20:d30ed6450e32 (esc)
  \xe2\x94\x82 \xe2\x94\x82 \xe2\x94\x82 \xe2\x94\x82 \xe2\x94\x82  user:        test (esc)
  \xe2\x94\x82 \xe2\x94\x82 \xe2\x94\x82 \xe2\x94\x82 \xe2\x94\x82  date:        Thu Jan 01 00:00:21 1970 +0000 (esc)
  \xe2\x94\x82 \xe2\x94\x82 \xe2\x94\x82 \xe2\x94\x82 \xe2\x94\x82  summary:     (21) expand (esc)
  \xe2\x94\x82 \xe2\x94\x82 \xe2\x94\x82 \xe2\x94\x82 \xe2\x94\x82 (esc)
  \xe2\x94\x82 \xe2\x97\x8b\xe2\x94\x80\xe2\x94\x80\xe2\x94\x80\xe2\x94\xbc\xe2\x94\x80\xe2\x94\xa4  changeset:   20:d30ed6450e32 (esc)
  \xe2\x94\x82   \xe2\x94\x82 \xe2\x94\x82 \xe2\x94\x82  parent:      0:e6eb3150255d (esc)
  \xe2\x94\x82  \xe2\x95\xb1 \xe2\x95\xb1 \xe2\x95\xb1   parent:      18:1aa84d96232a (esc)
  \xe2\x94\x82 \xe2\x94\x82 \xe2\x94\x82 \xe2\x94\x82    user:        test (esc)
  \xe2\x94\x82 \xe2\x94\x82 \xe2\x94\x82 \xe2\x94\x82    date:        Thu Jan 01 00:00:20 1970 +0000 (esc)
  \xe2\x94\x82 \xe2\x94\x82 \xe2\x94\x82 \xe2\x94\x82    summary:     (20) merge two known; two far right (esc)
  \xe2\x94\x82 \xe2\x94\x82 \xe2\x94\x82 \xe2\x94\x82 (esc)
  \xe2\x97\x8b \xe2\x94\x82 \xe2\x94\x82 \xe2\x94\x82  changeset:   19:31ddc2c1573b (esc)
  \xe2\x94\x82\xe2\x95\xb2 \xe2\x95\xb2 \xe2\x95\xb2 \xe2\x95\xb2   parent:      15:1dda3f72782d (esc)
  \xe2\x94\x82 \xe2\x94\x82 \xe2\x94\x82 \xe2\x94\x82 \xe2\x94\x82  parent:      17:44765d7c06e0 (esc)
  \xe2\x94\x82 \xe2\x94\x82 \xe2\x94\x82 \xe2\x94\x82 \xe2\x94\x82  user:        test (esc)
  \xe2\x94\x82 \xe2\x94\x82 \xe2\x94\x82 \xe2\x94\x82 \xe2\x94\x82  date:        Thu Jan 01 00:00:19 1970 +0000 (esc)
  \xe2\x94\x82 \xe2\x94\x82 \xe2\x94\x82 \xe2\x94\x82 \xe2\x94\x82  summary:     (19) expand (esc)
  \xe2\x94\x82 \xe2\x94\x82 \xe2\x94\x82 \xe2\x94\x82 \xe2\x94\x82 (esc)
  \xe2\x94\x9c\xe2\x94\x80\xe2\x94\x80\xe2\x94\x80\xe2\x94\xbc\xe2\x94\x80\xe2\x94\x80\xe2\x94\x80\xe2\x97\x8b  changeset:   18:1aa84d96232a (esc)
  \xe2\x94\x82 \xe2\x94\x82 \xe2\x94\x82 \xe2\x94\x82    parent:      1:6db2ef61d156 (esc)
  \xe2\x94\x82 \xe2\x94\x82 \xe2\x94\x82 \xe2\x94\x82    parent:      15:1dda3f72782d (esc)
  \xe2\x94\x82 \xe2\x94\x82 \xe2\x94\x82 \xe2\x94\x82    user:        test (esc)
  \xe2\x94\x82 \xe2\x94\x82 \xe2\x94\x82 \xe2\x94\x82    date:        Thu Jan 01 00:00:18 1970 +0000 (esc)
  \xe2\x94\x82 \xe2\x94\x82 \xe2\x94\x82 \xe2\x94\x82    summary:     (18) merge two known; two far left (esc)
  \xe2\x94\x82 \xe2\x94\x82 \xe2\x94\x82 \xe2\x94\x82 (esc)
  \xe2\x94\x82 \xe2\x97\x8b \xe2\x94\x82 \xe2\x94\x82  changeset:   17:44765d7c06e0 (esc)
  \xe2\x94\x82 \xe2\x94\x82\xe2\x95\xb2 \xe2\x95\xb2 \xe2\x95\xb2   parent:      12:86b91144a6e9 (esc)
  \xe2\x94\x82 \xe2\x94\x82 \xe2\x94\x82 \xe2\x94\x82 \xe2\x94\x82  parent:      16:3677d192927d (esc)
  \xe2\x94\x82 \xe2\x94\x82 \xe2\x94\x82 \xe2\x94\x82 \xe2\x94\x82  user:        test (esc)
  \xe2\x94\x82 \xe2\x94\x82 \xe2\x94\x82 \xe2\x94\x82 \xe2\x94\x82  date:        Thu Jan 01 00:00:17 1970 +0000 (esc)
  \xe2\x94\x82 \xe2\x94\x82 \xe2\x94\x82 \xe2\x94\x82 \xe2\x94\x82  summary:     (17) expand (esc)
  \xe2\x94\x82 \xe2\x94\x82 \xe2\x94\x82 \xe2\x94\x82 \xe2\x94\x82 (esc)
  \xe2\x94\x82 \xe2\x94\x82 \xe2\x97\x8b\xe2\x94\x80\xe2\x94\x80\xe2\x94\x80\xe2\x94\xa4  changeset:   16:3677d192927d (esc)
  \xe2\x94\x82 \xe2\x94\x82 \xe2\x94\x82 \xe2\x94\x82 \xe2\x94\x82  parent:      0:e6eb3150255d (esc)
  \xe2\x94\x82 \xe2\x94\x82 \xe2\x94\x82\xe2\x95\xb1 \xe2\x95\xb1   parent:      1:6db2ef61d156 (esc)
  \xe2\x94\x82 \xe2\x94\x82 \xe2\x94\x82 \xe2\x94\x82    user:        test (esc)
  \xe2\x94\x82 \xe2\x94\x82 \xe2\x94\x82 \xe2\x94\x82    date:        Thu Jan 01 00:00:16 1970 +0000 (esc)
  \xe2\x94\x82 \xe2\x94\x82 \xe2\x94\x82 \xe2\x94\x82    summary:     (16) merge two known; one immediate right, one near right (esc)
  \xe2\x94\x82 \xe2\x94\x82 \xe2\x94\x82 \xe2\x94\x82 (esc)
  \xe2\x97\x8b \xe2\x94\x82 \xe2\x94\x82 \xe2\x94\x82  changeset:   15:1dda3f72782d (esc)
  \xe2\x94\x82\xe2\x95\xb2 \xe2\x95\xb2 \xe2\x95\xb2 \xe2\x95\xb2   parent:      13:22d8966a97e3 (esc)
  \xe2\x94\x82 \xe2\x94\x82 \xe2\x94\x82 \xe2\x94\x82 \xe2\x94\x82  parent:      14:8eac370358ef (esc)
  \xe2\x94\x82 \xe2\x94\x82 \xe2\x94\x82 \xe2\x94\x82 \xe2\x94\x82  user:        test (esc)
  \xe2\x94\x82 \xe2\x94\x82 \xe2\x94\x82 \xe2\x94\x82 \xe2\x94\x82  date:        Thu Jan 01 00:00:15 1970 +0000 (esc)
  \xe2\x94\x82 \xe2\x94\x82 \xe2\x94\x82 \xe2\x94\x82 \xe2\x94\x82  summary:     (15) expand (esc)
  \xe2\x94\x82 \xe2\x94\x82 \xe2\x94\x82 \xe2\x94\x82 \xe2\x94\x82 (esc)
  \xe2\x94\x82 \xe2\x97\x8b\xe2\x94\x80\xe2\x94\x80\xe2\x94\x80\xe2\x94\x80\xe2\x94\x80\xe2\x94\xa4  changeset:   14:8eac370358ef (esc)
  \xe2\x94\x82 \xe2\x94\x82 \xe2\x94\x82 \xe2\x94\x82 \xe2\x94\x82  parent:      0:e6eb3150255d (esc)
  \xe2\x94\x82 \xe2\x94\x82\xe2\x95\xb1 \xe2\x95\xb1 \xe2\x95\xb1   parent:      12:86b91144a6e9 (esc)
  \xe2\x94\x82 \xe2\x94\x82 \xe2\x94\x82 \xe2\x94\x82    user:        test (esc)
  \xe2\x94\x82 \xe2\x94\x82 \xe2\x94\x82 \xe2\x94\x82    date:        Thu Jan 01 00:00:14 1970 +0000 (esc)
  \xe2\x94\x82 \xe2\x94\x82 \xe2\x94\x82 \xe2\x94\x82    summary:     (14) merge two known; one immediate right, one far right (esc)
  \xe2\x94\x82 \xe2\x94\x82 \xe2\x94\x82 \xe2\x94\x82 (esc)
  \xe2\x97\x8b \xe2\x94\x82 \xe2\x94\x82 \xe2\x94\x82  changeset:   13:22d8966a97e3 (esc)
  \xe2\x94\x82\xe2\x95\xb2 \xe2\x95\xb2 \xe2\x95\xb2 \xe2\x95\xb2   parent:      9:7010c0af0a35 (esc)
  \xe2\x94\x82 \xe2\x94\x82 \xe2\x94\x82 \xe2\x94\x82 \xe2\x94\x82  parent:      11:832d76e6bdf2 (esc)
  \xe2\x94\x82 \xe2\x94\x82 \xe2\x94\x82 \xe2\x94\x82 \xe2\x94\x82  user:        test (esc)
  \xe2\x94\x82 \xe2\x94\x82 \xe2\x94\x82 \xe2\x94\x82 \xe2\x94\x82  date:        Thu Jan 01 00:00:13 1970 +0000 (esc)
  \xe2\x94\x82 \xe2\x94\x82 \xe2\x94\x82 \xe2\x94\x82 \xe2\x94\x82  summary:     (13) expand (esc)
  \xe2\x94\x82 \xe2\x94\x82 \xe2\x94\x82 \xe2\x94\x82 \xe2\x94\x82 (esc)
  \xe2\x94\x9c\xe2\x94\x80\xe2\x94\x80\xe2\x94\x80\xe2\x97\x8b \xe2\x94\x82 \xe2\x94\x82  changeset:   12:86b91144a6e9 (esc)
  \xe2\x94\x82 \xe2\x94\x82 \xe2\x94\x82\xe2\x95\xb1 \xe2\x95\xb1   parent:      1:6db2ef61d156 (esc)
  \xe2\x94\x82 \xe2\x94\x82 \xe2\x94\x82 \xe2\x94\x82    parent:      9:7010c0af0a35 (esc)
  \xe2\x94\x82 \xe2\x94\x82 \xe2\x94\x82 \xe2\x94\x82    user:        test (esc)
  \xe2\x94\x82 \xe2\x94\x82 \xe2\x94\x82 \xe2\x94\x82    date:        Thu Jan 01 00:00:12 1970 +0000 (esc)
  \xe2\x94\x82 \xe2\x94\x82 \xe2\x94\x82 \xe2\x94\x82    summary:     (12) merge two known; one immediate right, one far left (esc)
  \xe2\x94\x82 \xe2\x94\x82 \xe2\x94\x82 \xe2\x94\x82 (esc)
  \xe2\x94\x82 \xe2\x97\x8b \xe2\x94\x82 \xe2\x94\x82  changeset:   11:832d76e6bdf2 (esc)
  \xe2\x94\x82 \xe2\x94\x82\xe2\x95\xb2 \xe2\x95\xb2 \xe2\x95\xb2   parent:      6:b105a072e251 (esc)
  \xe2\x94\x82 \xe2\x94\x82 \xe2\x94\x82 \xe2\x94\x82 \xe2\x94\x82  parent:      10:74c64d036d72 (esc)
  \xe2\x94\x82 \xe2\x94\x82 \xe2\x94\x82 \xe2\x94\x82 \xe2\x94\x82  user:        test (esc)
  \xe2\x94\x82 \xe2\x94\x82 \xe2\x94\x82 \xe2\x94\x82 \xe2\x94\x82  date:        Thu Jan 01 00:00:11 1970 +0000 (esc)
  \xe2\x94\x82 \xe2\x94\x82 \xe2\x94\x82 \xe2\x94\x82 \xe2\x94\x82  summary:     (11) expand (esc)
  \xe2\x94\x82 \xe2\x94\x82 \xe2\x94\x82 \xe2\x94\x82 \xe2\x94\x82 (esc)
  \xe2\x94\x82 \xe2\x94\x82 \xe2\x97\x8b\xe2\x94\x80\xe2\x94\x80\xe2\x94\x80\xe2\x94\xa4  changeset:   10:74c64d036d72 (esc)
  \xe2\x94\x82 \xe2\x94\x82 \xe2\x94\x82 \xe2\x94\x82 \xe2\x94\x82  parent:      0:e6eb3150255d (esc)
  \xe2\x94\x82 \xe2\x94\x82\xe2\x95\xb1 \xe2\x95\xb1 \xe2\x95\xb1   parent:      6:b105a072e251 (esc)
  \xe2\x94\x82 \xe2\x94\x82 \xe2\x94\x82 \xe2\x94\x82    user:        test (esc)
  \xe2\x94\x82 \xe2\x94\x82 \xe2\x94\x82 \xe2\x94\x82    date:        Thu Jan 01 00:00:10 1970 +0000 (esc)
  \xe2\x94\x82 \xe2\x94\x82 \xe2\x94\x82 \xe2\x94\x82    summary:     (10) merge two known; one immediate left, one near right (esc)
  \xe2\x94\x82 \xe2\x94\x82 \xe2\x94\x82 \xe2\x94\x82 (esc)
  \xe2\x97\x8b \xe2\x94\x82 \xe2\x94\x82 \xe2\x94\x82  changeset:   9:7010c0af0a35 (esc)
  \xe2\x94\x82\xe2\x95\xb2 \xe2\x95\xb2 \xe2\x95\xb2 \xe2\x95\xb2   parent:      7:b632bb1b1224 (esc)
  \xe2\x94\x82 \xe2\x94\x82 \xe2\x94\x82 \xe2\x94\x82 \xe2\x94\x82  parent:      8:7a0b11f71937 (esc)
  \xe2\x94\x82 \xe2\x94\x82 \xe2\x94\x82 \xe2\x94\x82 \xe2\x94\x82  user:        test (esc)
  \xe2\x94\x82 \xe2\x94\x82 \xe2\x94\x82 \xe2\x94\x82 \xe2\x94\x82  date:        Thu Jan 01 00:00:09 1970 +0000 (esc)
  \xe2\x94\x82 \xe2\x94\x82 \xe2\x94\x82 \xe2\x94\x82 \xe2\x94\x82  summary:     (9) expand (esc)
  \xe2\x94\x82 \xe2\x94\x82 \xe2\x94\x82 \xe2\x94\x82 \xe2\x94\x82 (esc)
  \xe2\x94\x82 \xe2\x97\x8b\xe2\x94\x80\xe2\x94\x80\xe2\x94\x80\xe2\x94\x80\xe2\x94\x80\xe2\x94\xa4  changeset:   8:7a0b11f71937 (esc)
  \xe2\x94\x82 \xe2\x94\x82 \xe2\x94\x82 \xe2\x94\x82 \xe2\x94\x82  parent:      0:e6eb3150255d (esc)
  \xe2\x94\x82\xe2\x95\xb1 \xe2\x95\xb1 \xe2\x95\xb1 \xe2\x95\xb1   parent:      7:b632bb1b1224 (esc)
  \xe2\x94\x82 \xe2\x94\x82 \xe2\x94\x82 \xe2\x94\x82    user:        test (esc)
  \xe2\x94\x82 \xe2\x94\x82 \xe2\x94\x82 \xe2\x94\x82    date:        Thu Jan 01 00:00:08 1970 +0000 (esc)
  \xe2\x94\x82 \xe2\x94\x82 \xe2\x94\x82 \xe2\x94\x82    summary:     (8) merge two known; one immediate left, one far right (esc)
  \xe2\x94\x82 \xe2\x94\x82 \xe2\x94\x82 \xe2\x94\x82 (esc)
  \xe2\x97\x8b \xe2\x94\x82 \xe2\x94\x82 \xe2\x94\x82  changeset:   7:b632bb1b1224 (esc)
  \xe2\x94\x82\xe2\x95\xb2 \xe2\x95\xb2 \xe2\x95\xb2 \xe2\x95\xb2   parent:      2:3d9a33b8d1e1 (esc)
  \xe2\x94\x82 \xe2\x94\x82 \xe2\x94\x82 \xe2\x94\x82 \xe2\x94\x82  parent:      5:4409d547b708 (esc)
  \xe2\x94\x82 \xe2\x94\x82 \xe2\x94\x82 \xe2\x94\x82 \xe2\x94\x82  user:        test (esc)
  \xe2\x94\x82 \xe2\x94\x82 \xe2\x94\x82 \xe2\x94\x82 \xe2\x94\x82  date:        Thu Jan 01 00:00:07 1970 +0000 (esc)
  \xe2\x94\x82 \xe2\x94\x82 \xe2\x94\x82 \xe2\x94\x82 \xe2\x94\x82  summary:     (7) expand (esc)
  \xe2\x94\x82 \xe2\x94\x82 \xe2\x94\x82 \xe2\x94\x82 \xe2\x94\x82 (esc)
  \xe2\x94\x9c\xe2\x94\x80\xe2\x94\x80\xe2\x94\x80\xe2\x97\x8b \xe2\x94\x82 \xe2\x94\x82  changeset:   6:b105a072e251 (esc)
  \xe2\x94\x82 \xe2\x94\x82\xe2\x95\xb1 \xe2\x95\xb1 \xe2\x95\xb1   parent:      2:3d9a33b8d1e1 (esc)
  \xe2\x94\x82 \xe2\x94\x82 \xe2\x94\x82 \xe2\x94\x82    parent:      5:4409d547b708 (esc)
  \xe2\x94\x82 \xe2\x94\x82 \xe2\x94\x82 \xe2\x94\x82    user:        test (esc)
  \xe2\x94\x82 \xe2\x94\x82 \xe2\x94\x82 \xe2\x94\x82    date:        Thu Jan 01 00:00:06 1970 +0000 (esc)
  \xe2\x94\x82 \xe2\x94\x82 \xe2\x94\x82 \xe2\x94\x82    summary:     (6) merge two known; one immediate left, one far left (esc)
  \xe2\x94\x82 \xe2\x94\x82 \xe2\x94\x82 \xe2\x94\x82 (esc)
  \xe2\x94\x82 \xe2\x97\x8b \xe2\x94\x82 \xe2\x94\x82  changeset:   5:4409d547b708 (esc)
  \xe2\x94\x82 \xe2\x94\x82\xe2\x95\xb2 \xe2\x95\xb2 \xe2\x95\xb2   parent:      3:27eef8ed80b4 (esc)
  \xe2\x94\x82 \xe2\x94\x82 \xe2\x94\x82 \xe2\x94\x82 \xe2\x94\x82  parent:      4:26a8bac39d9f (esc)
  \xe2\x94\x82 \xe2\x94\x82 \xe2\x94\x82 \xe2\x94\x82 \xe2\x94\x82  user:        test (esc)
  \xe2\x94\x82 \xe2\x94\x82 \xe2\x94\x82 \xe2\x94\x82 \xe2\x94\x82  date:        Thu Jan 01 00:00:05 1970 +0000 (esc)
  \xe2\x94\x82 \xe2\x94\x82 \xe2\x94\x82 \xe2\x94\x82 \xe2\x94\x82  summary:     (5) expand (esc)
  \xe2\x94\x82 \xe2\x94\x82 \xe2\x94\x82 \xe2\x94\x82 \xe2\x94\x82 (esc)
  \xe2\x94\x82 \xe2\x94\x82 \xe2\x97\x8b \xe2\x94\x82 \xe2\x94\x82  changeset:   4:26a8bac39d9f (esc)
  \xe2\x94\x82 \xe2\x94\x82\xe2\x95\xb1\xe2\x94\x82\xe2\x95\xb1 \xe2\x95\xb1   parent:      1:6db2ef61d156 (esc)
  \xe2\x94\x82 \xe2\x94\x82 \xe2\x94\x82 \xe2\x94\x82    parent:      3:27eef8ed80b4 (esc)
  \xe2\x94\x82 \xe2\x94\x82 \xe2\x94\x82 \xe2\x94\x82    user:        test (esc)
  \xe2\x94\x82 \xe2\x94\x82 \xe2\x94\x82 \xe2\x94\x82    date:        Thu Jan 01 00:00:04 1970 +0000 (esc)
  \xe2\x94\x82 \xe2\x94\x82 \xe2\x94\x82 \xe2\x94\x82    summary:     (4) merge two known; one immediate left, one immediate right (esc)
  \xe2\x94\x82 \xe2\x94\x82 \xe2\x94\x82 \xe2\x94\x82 (esc)
  \xe2\x94\x82 \xe2\x97\x8b \xe2\x94\x82 \xe2\x94\x82  changeset:   3:27eef8ed80b4 (esc)
  \xe2\x94\x82\xe2\x95\xb1 \xe2\x95\xb1 \xe2\x95\xb1   user:        test (esc)
  \xe2\x94\x82 \xe2\x94\x82 \xe2\x94\x82    date:        Thu Jan 01 00:00:03 1970 +0000 (esc)
  \xe2\x94\x82 \xe2\x94\x82 \xe2\x94\x82    summary:     (3) collapse (esc)
  \xe2\x94\x82 \xe2\x94\x82 \xe2\x94\x82 (esc)
  \xe2\x97\x8b \xe2\x94\x82 \xe2\x94\x82  changeset:   2:3d9a33b8d1e1 (esc)
  \xe2\x94\x82\xe2\x95\xb1 \xe2\x95\xb1   user:        test (esc)
  \xe2\x94\x82 \xe2\x94\x82    date:        Thu Jan 01 00:00:02 1970 +0000 (esc)
  \xe2\x94\x82 \xe2\x94\x82    summary:     (2) collapse (esc)
  \xe2\x94\x82 \xe2\x94\x82 (esc)
  \xe2\x97\x8b \xe2\x94\x82  changeset:   1:6db2ef61d156 (esc)
  \xe2\x94\x82\xe2\x95\xb1   user:        test (esc)
  \xe2\x94\x82    date:        Thu Jan 01 00:00:01 1970 +0000 (esc)
  \xe2\x94\x82    summary:     (1) collapse (esc)
  \xe2\x94\x82 (esc)
  \xe2\x97\x8b  changeset:   0:e6eb3150255d (esc)
     user:        test
     date:        Thu Jan 01 00:00:00 1970 +0000
     summary:     (0) root
  
File glog:
  $ hg log -G a
  \xe2\x97\x8d  changeset:   34:fea3ac5810e0 (esc)
  \xe2\x94\x82  tag:         tip (esc)
  \xe2\x94\x82  parent:      32:d06dffa21a31 (esc)
  \xe2\x94\x82  user:        test (esc)
  \xe2\x94\x82  date:        Thu Jan 01 00:00:34 1970 +0000 (esc)
  \xe2\x94\x82  summary:     (34) head (esc)
  \xe2\x94\x82 (esc)
  \xe2\x94\x82 \xe2\x97\x8b  changeset:   33:68608f5145f9 (esc)
  \xe2\x94\x82 \xe2\x94\x82  parent:      18:1aa84d96232a (esc)
  \xe2\x94\x82 \xe2\x94\x82  user:        test (esc)
  \xe2\x94\x82 \xe2\x94\x82  date:        Thu Jan 01 00:00:33 1970 +0000 (esc)
  \xe2\x94\x82 \xe2\x94\x82  summary:     (33) head (esc)
  \xe2\x94\x82 \xe2\x94\x82 (esc)
  \xe2\x97\x8b \xe2\x94\x82  changeset:   32:d06dffa21a31 (esc)
  \xe2\x94\x82\xe2\x95\xb2 \xe2\x95\xb2   parent:      27:886ed638191b (esc)
  \xe2\x94\x82 \xe2\x94\x82 \xe2\x94\x82  parent:      31:621d83e11f67 (esc)
  \xe2\x94\x82 \xe2\x94\x82 \xe2\x94\x82  user:        test (esc)
  \xe2\x94\x82 \xe2\x94\x82 \xe2\x94\x82  date:        Thu Jan 01 00:00:32 1970 +0000 (esc)
  \xe2\x94\x82 \xe2\x94\x82 \xe2\x94\x82  summary:     (32) expand (esc)
  \xe2\x94\x82 \xe2\x94\x82 \xe2\x94\x82 (esc)
  \xe2\x94\x82 \xe2\x97\x8b \xe2\x94\x82  changeset:   31:621d83e11f67 (esc)
  \xe2\x94\x82 \xe2\x94\x82\xe2\x95\xb2 \xe2\x95\xb2   parent:      21:d42a756af44d (esc)
  \xe2\x94\x82 \xe2\x94\x82 \xe2\x94\x82 \xe2\x94\x82  parent:      30:6e11cd4b648f (esc)
  \xe2\x94\x82 \xe2\x94\x82 \xe2\x94\x82 \xe2\x94\x82  user:        test (esc)
  \xe2\x94\x82 \xe2\x94\x82 \xe2\x94\x82 \xe2\x94\x82  date:        Thu Jan 01 00:00:31 1970 +0000 (esc)
  \xe2\x94\x82 \xe2\x94\x82 \xe2\x94\x82 \xe2\x94\x82  summary:     (31) expand (esc)
  \xe2\x94\x82 \xe2\x94\x82 \xe2\x94\x82 \xe2\x94\x82 (esc)
  \xe2\x94\x82 \xe2\x94\x82 \xe2\x97\x8b \xe2\x94\x82  changeset:   30:6e11cd4b648f (esc)
  \xe2\x94\x82 \xe2\x94\x82 \xe2\x94\x82\xe2\x95\xb2 \xe2\x95\xb2   parent:      28:44ecd0b9ae99 (esc)
  \xe2\x94\x82 \xe2\x94\x82 \xe2\x94\x82 \xe2\x94\x82 \xe2\x94\x82  parent:      29:cd9bb2be7593 (esc)
  \xe2\x94\x82 \xe2\x94\x82 \xe2\x94\x82 \xe2\x94\x82 \xe2\x94\x82  user:        test (esc)
  \xe2\x94\x82 \xe2\x94\x82 \xe2\x94\x82 \xe2\x94\x82 \xe2\x94\x82  date:        Thu Jan 01 00:00:30 1970 +0000 (esc)
  \xe2\x94\x82 \xe2\x94\x82 \xe2\x94\x82 \xe2\x94\x82 \xe2\x94\x82  summary:     (30) expand (esc)
  \xe2\x94\x82 \xe2\x94\x82 \xe2\x94\x82 \xe2\x94\x82 \xe2\x94\x82 (esc)
  \xe2\x94\x82 \xe2\x94\x82 \xe2\x94\x82 \xe2\x97\x8b \xe2\x94\x82  changeset:   29:cd9bb2be7593 (esc)
  \xe2\x94\x82 \xe2\x94\x82 \xe2\x94\x82 \xe2\x94\x82 \xe2\x94\x82  parent:      0:e6eb3150255d (esc)
  \xe2\x94\x82 \xe2\x94\x82 \xe2\x94\x82 \xe2\x94\x82 \xe2\x94\x82  user:        test (esc)
  \xe2\x94\x82 \xe2\x94\x82 \xe2\x94\x82 \xe2\x94\x82 \xe2\x94\x82  date:        Thu Jan 01 00:00:29 1970 +0000 (esc)
  \xe2\x94\x82 \xe2\x94\x82 \xe2\x94\x82 \xe2\x94\x82 \xe2\x94\x82  summary:     (29) regular commit (esc)
  \xe2\x94\x82 \xe2\x94\x82 \xe2\x94\x82 \xe2\x94\x82 \xe2\x94\x82 (esc)
  \xe2\x94\x82 \xe2\x94\x82 \xe2\x97\x8b \xe2\x94\x82 \xe2\x94\x82  changeset:   28:44ecd0b9ae99 (esc)
  \xe2\x94\x82 \xe2\x94\x82 \xe2\x94\x82\xe2\x95\xb2 \xe2\x95\xb2 \xe2\x95\xb2   parent:      1:6db2ef61d156 (esc)
  \xe2\x94\x82 \xe2\x94\x82 \xe2\x94\x82 \xe2\x94\x82 \xe2\x94\x82 \xe2\x94\x82  parent:      26:7f25b6c2f0b9 (esc)
  \xe2\x94\x82 \xe2\x94\x82 \xe2\x94\x82 \xe2\x94\x82 \xe2\x94\x82 \xe2\x94\x82  user:        test (esc)
  \xe2\x94\x82 \xe2\x94\x82 \xe2\x94\x82 \xe2\x94\x82 \xe2\x94\x82 \xe2\x94\x82  date:        Thu Jan 01 00:00:28 1970 +0000 (esc)
  \xe2\x94\x82 \xe2\x94\x82 \xe2\x94\x82 \xe2\x94\x82 \xe2\x94\x82 \xe2\x94\x82  summary:     (28) merge zero known (esc)
  \xe2\x94\x82 \xe2\x94\x82 \xe2\x94\x82 \xe2\x94\x82 \xe2\x94\x82 \xe2\x94\x82 (esc)
  \xe2\x97\x8b \xe2\x94\x82 \xe2\x94\x82 \xe2\x94\x82 \xe2\x94\x82 \xe2\x94\x82  changeset:   27:886ed638191b (esc)
  \xe2\x94\x82\xe2\x95\xb1 \xe2\x95\xb1 \xe2\x95\xb1 \xe2\x95\xb1 \xe2\x95\xb1   parent:      21:d42a756af44d (esc)
  \xe2\x94\x82 \xe2\x94\x82 \xe2\x94\x82 \xe2\x94\x82 \xe2\x94\x82    user:        test (esc)
  \xe2\x94\x82 \xe2\x94\x82 \xe2\x94\x82 \xe2\x94\x82 \xe2\x94\x82    date:        Thu Jan 01 00:00:27 1970 +0000 (esc)
  \xe2\x94\x82 \xe2\x94\x82 \xe2\x94\x82 \xe2\x94\x82 \xe2\x94\x82    summary:     (27) collapse (esc)
  \xe2\x94\x82 \xe2\x94\x82 \xe2\x94\x82 \xe2\x94\x82 \xe2\x94\x82 (esc)
  \xe2\x94\x82 \xe2\x94\x82 \xe2\x97\x8b\xe2\x94\x80\xe2\x94\x80\xe2\x94\x80\xe2\x94\xa4  changeset:   26:7f25b6c2f0b9 (esc)
  \xe2\x94\x82 \xe2\x94\x82 \xe2\x94\x82 \xe2\x94\x82 \xe2\x94\x82  parent:      18:1aa84d96232a (esc)
  \xe2\x94\x82 \xe2\x94\x82 \xe2\x94\x82 \xe2\x94\x82 \xe2\x94\x82  parent:      25:91da8ed57247 (esc)
  \xe2\x94\x82 \xe2\x94\x82 \xe2\x94\x82 \xe2\x94\x82 \xe2\x94\x82  user:        test (esc)
  \xe2\x94\x82 \xe2\x94\x82 \xe2\x94\x82 \xe2\x94\x82 \xe2\x94\x82  date:        Thu Jan 01 00:00:26 1970 +0000 (esc)
  \xe2\x94\x82 \xe2\x94\x82 \xe2\x94\x82 \xe2\x94\x82 \xe2\x94\x82  summary:     (26) merge one known; far right (esc)
  \xe2\x94\x82 \xe2\x94\x82 \xe2\x94\x82 \xe2\x94\x82 \xe2\x94\x82 (esc)
  \xe2\x94\x9c\xe2\x94\x80\xe2\x94\x80\xe2\x94\x80\xe2\x97\x8b \xe2\x94\x82 \xe2\x94\x82  changeset:   25:91da8ed57247 (esc)
  \xe2\x94\x82 \xe2\x94\x82 \xe2\x94\x82 \xe2\x94\x82 \xe2\x94\x82  parent:      21:d42a756af44d (esc)
  \xe2\x94\x82 \xe2\x94\x82 \xe2\x94\x82 \xe2\x94\x82 \xe2\x94\x82  parent:      24:a9c19a3d96b7 (esc)
  \xe2\x94\x82 \xe2\x94\x82 \xe2\x94\x82 \xe2\x94\x82 \xe2\x94\x82  user:        test (esc)
  \xe2\x94\x82 \xe2\x94\x82 \xe2\x94\x82 \xe2\x94\x82 \xe2\x94\x82  date:        Thu Jan 01 00:00:25 1970 +0000 (esc)
  \xe2\x94\x82 \xe2\x94\x82 \xe2\x94\x82 \xe2\x94\x82 \xe2\x94\x82  summary:     (25) merge one known; far left (esc)
  \xe2\x94\x82 \xe2\x94\x82 \xe2\x94\x82 \xe2\x94\x82 \xe2\x94\x82 (esc)
  \xe2\x94\x82 \xe2\x94\x82 \xe2\x97\x8b \xe2\x94\x82 \xe2\x94\x82  changeset:   24:a9c19a3d96b7 (esc)
  \xe2\x94\x82 \xe2\x94\x82 \xe2\x94\x82\xe2\x95\xb2\xe2\x94\x82 \xe2\x94\x82  parent:      0:e6eb3150255d (esc)
  \xe2\x94\x82 \xe2\x94\x82 \xe2\x94\x82 \xe2\x94\x82 \xe2\x94\x82  parent:      23:a01cddf0766d (esc)
  \xe2\x94\x82 \xe2\x94\x82 \xe2\x94\x82 \xe2\x94\x82 \xe2\x94\x82  user:        test (esc)
  \xe2\x94\x82 \xe2\x94\x82 \xe2\x94\x82 \xe2\x94\x82 \xe2\x94\x82  date:        Thu Jan 01 00:00:24 1970 +0000 (esc)
  \xe2\x94\x82 \xe2\x94\x82 \xe2\x94\x82 \xe2\x94\x82 \xe2\x94\x82  summary:     (24) merge one known; immediate right (esc)
  \xe2\x94\x82 \xe2\x94\x82 \xe2\x94\x82 \xe2\x94\x82 \xe2\x94\x82 (esc)
  \xe2\x94\x82 \xe2\x94\x82 \xe2\x97\x8b \xe2\x94\x82 \xe2\x94\x82  changeset:   23:a01cddf0766d (esc)
  \xe2\x94\x82 \xe2\x94\x82\xe2\x95\xb1\xe2\x94\x82 \xe2\x94\x82 \xe2\x94\x82  parent:      1:6db2ef61d156 (esc)
  \xe2\x94\x82 \xe2\x94\x82 \xe2\x94\x82 \xe2\x94\x82 \xe2\x94\x82  parent:      22:e0d9cccacb5d (esc)
  \xe2\x94\x82 \xe2\x94\x82 \xe2\x94\x82 \xe2\x94\x82 \xe2\x94\x82  user:        test (esc)
  \xe2\x94\x82 \xe2\x94\x82 \xe2\x94\x82 \xe2\x94\x82 \xe2\x94\x82  date:        Thu Jan 01 00:00:23 1970 +0000 (esc)
  \xe2\x94\x82 \xe2\x94\x82 \xe2\x94\x82 \xe2\x94\x82 \xe2\x94\x82  summary:     (23) merge one known; immediate left (esc)
  \xe2\x94\x82 \xe2\x94\x82 \xe2\x94\x82 \xe2\x94\x82 \xe2\x94\x82 (esc)
  \xe2\x94\x9c\xe2\x94\x80\xe2\x94\x80\xe2\x94\x80\xe2\x97\x8b\xe2\x94\x80\xe2\x94\x80\xe2\x94\x80\xe2\x94\xa4  changeset:   22:e0d9cccacb5d (esc)
  \xe2\x94\x82 \xe2\x94\x82   \xe2\x94\x82 \xe2\x94\x82  parent:      18:1aa84d96232a (esc)
  \xe2\x94\x82 \xe2\x94\x82  \xe2\x95\xb1 \xe2\x95\xb1   parent:      21:d42a756af44d (esc)
  \xe2\x94\x82 \xe2\x94\x82 \xe2\x94\x82 \xe2\x94\x82    user:        test (esc)
  \xe2\x94\x82 \xe2\x94\x82 \xe2\x94\x82 \xe2\x94\x82    date:        Thu Jan 01 00:00:22 1970 +0000 (esc)
  \xe2\x94\x82 \xe2\x94\x82 \xe2\x94\x82 \xe2\x94\x82    summary:     (22) merge two known; one far left, one far right (esc)
  \xe2\x94\x82 \xe2\x94\x82 \xe2\x94\x82 \xe2\x94\x82 (esc)
  \xe2\x97\x8b \xe2\x94\x82 \xe2\x94\x82 \xe2\x94\x82  changeset:   21:d42a756af44d (esc)
  \xe2\x94\x82\xe2\x95\xb2 \xe2\x95\xb2 \xe2\x95\xb2 \xe2\x95\xb2   parent:      19:31ddc2c1573b (esc)
  \xe2\x94\x82 \xe2\x94\x82 \xe2\x94\x82 \xe2\x94\x82 \xe2\x94\x82  parent:      20:d30ed6450e32 (esc)
  \xe2\x94\x82 \xe2\x94\x82 \xe2\x94\x82 \xe2\x94\x82 \xe2\x94\x82  user:        test (esc)
  \xe2\x94\x82 \xe2\x94\x82 \xe2\x94\x82 \xe2\x94\x82 \xe2\x94\x82  date:        Thu Jan 01 00:00:21 1970 +0000 (esc)
  \xe2\x94\x82 \xe2\x94\x82 \xe2\x94\x82 \xe2\x94\x82 \xe2\x94\x82  summary:     (21) expand (esc)
  \xe2\x94\x82 \xe2\x94\x82 \xe2\x94\x82 \xe2\x94\x82 \xe2\x94\x82 (esc)
  \xe2\x94\x82 \xe2\x97\x8b\xe2\x94\x80\xe2\x94\x80\xe2\x94\x80\xe2\x94\xbc\xe2\x94\x80\xe2\x94\xa4  changeset:   20:d30ed6450e32 (esc)
  \xe2\x94\x82   \xe2\x94\x82 \xe2\x94\x82 \xe2\x94\x82  parent:      0:e6eb3150255d (esc)
  \xe2\x94\x82  \xe2\x95\xb1 \xe2\x95\xb1 \xe2\x95\xb1   parent:      18:1aa84d96232a (esc)
  \xe2\x94\x82 \xe2\x94\x82 \xe2\x94\x82 \xe2\x94\x82    user:        test (esc)
  \xe2\x94\x82 \xe2\x94\x82 \xe2\x94\x82 \xe2\x94\x82    date:        Thu Jan 01 00:00:20 1970 +0000 (esc)
  \xe2\x94\x82 \xe2\x94\x82 \xe2\x94\x82 \xe2\x94\x82    summary:     (20) merge two known; two far right (esc)
  \xe2\x94\x82 \xe2\x94\x82 \xe2\x94\x82 \xe2\x94\x82 (esc)
  \xe2\x97\x8b \xe2\x94\x82 \xe2\x94\x82 \xe2\x94\x82  changeset:   19:31ddc2c1573b (esc)
  \xe2\x94\x82\xe2\x95\xb2 \xe2\x95\xb2 \xe2\x95\xb2 \xe2\x95\xb2   parent:      15:1dda3f72782d (esc)
  \xe2\x94\x82 \xe2\x94\x82 \xe2\x94\x82 \xe2\x94\x82 \xe2\x94\x82  parent:      17:44765d7c06e0 (esc)
  \xe2\x94\x82 \xe2\x94\x82 \xe2\x94\x82 \xe2\x94\x82 \xe2\x94\x82  user:        test (esc)
  \xe2\x94\x82 \xe2\x94\x82 \xe2\x94\x82 \xe2\x94\x82 \xe2\x94\x82  date:        Thu Jan 01 00:00:19 1970 +0000 (esc)
  \xe2\x94\x82 \xe2\x94\x82 \xe2\x94\x82 \xe2\x94\x82 \xe2\x94\x82  summary:     (19) expand (esc)
  \xe2\x94\x82 \xe2\x94\x82 \xe2\x94\x82 \xe2\x94\x82 \xe2\x94\x82 (esc)
  \xe2\x94\x9c\xe2\x94\x80\xe2\x94\x80\xe2\x94\x80\xe2\x94\xbc\xe2\x94\x80\xe2\x94\x80\xe2\x94\x80\xe2\x97\x8b  changeset:   18:1aa84d96232a (esc)
  \xe2\x94\x82 \xe2\x94\x82 \xe2\x94\x82 \xe2\x94\x82    parent:      1:6db2ef61d156 (esc)
  \xe2\x94\x82 \xe2\x94\x82 \xe2\x94\x82 \xe2\x94\x82    parent:      15:1dda3f72782d (esc)
  \xe2\x94\x82 \xe2\x94\x82 \xe2\x94\x82 \xe2\x94\x82    user:        test (esc)
  \xe2\x94\x82 \xe2\x94\x82 \xe2\x94\x82 \xe2\x94\x82    date:        Thu Jan 01 00:00:18 1970 +0000 (esc)
  \xe2\x94\x82 \xe2\x94\x82 \xe2\x94\x82 \xe2\x94\x82    summary:     (18) merge two known; two far left (esc)
  \xe2\x94\x82 \xe2\x94\x82 \xe2\x94\x82 \xe2\x94\x82 (esc)
  \xe2\x94\x82 \xe2\x97\x8b \xe2\x94\x82 \xe2\x94\x82  changeset:   17:44765d7c06e0 (esc)
  \xe2\x94\x82 \xe2\x94\x82\xe2\x95\xb2 \xe2\x95\xb2 \xe2\x95\xb2   parent:      12:86b91144a6e9 (esc)
  \xe2\x94\x82 \xe2\x94\x82 \xe2\x94\x82 \xe2\x94\x82 \xe2\x94\x82  parent:      16:3677d192927d (esc)
  \xe2\x94\x82 \xe2\x94\x82 \xe2\x94\x82 \xe2\x94\x82 \xe2\x94\x82  user:        test (esc)
  \xe2\x94\x82 \xe2\x94\x82 \xe2\x94\x82 \xe2\x94\x82 \xe2\x94\x82  date:        Thu Jan 01 00:00:17 1970 +0000 (esc)
  \xe2\x94\x82 \xe2\x94\x82 \xe2\x94\x82 \xe2\x94\x82 \xe2\x94\x82  summary:     (17) expand (esc)
  \xe2\x94\x82 \xe2\x94\x82 \xe2\x94\x82 \xe2\x94\x82 \xe2\x94\x82 (esc)
  \xe2\x94\x82 \xe2\x94\x82 \xe2\x97\x8b\xe2\x94\x80\xe2\x94\x80\xe2\x94\x80\xe2\x94\xa4  changeset:   16:3677d192927d (esc)
  \xe2\x94\x82 \xe2\x94\x82 \xe2\x94\x82 \xe2\x94\x82 \xe2\x94\x82  parent:      0:e6eb3150255d (esc)
  \xe2\x94\x82 \xe2\x94\x82 \xe2\x94\x82\xe2\x95\xb1 \xe2\x95\xb1   parent:      1:6db2ef61d156 (esc)
  \xe2\x94\x82 \xe2\x94\x82 \xe2\x94\x82 \xe2\x94\x82    user:        test (esc)
  \xe2\x94\x82 \xe2\x94\x82 \xe2\x94\x82 \xe2\x94\x82    date:        Thu Jan 01 00:00:16 1970 +0000 (esc)
  \xe2\x94\x82 \xe2\x94\x82 \xe2\x94\x82 \xe2\x94\x82    summary:     (16) merge two known; one immediate right, one near right (esc)
  \xe2\x94\x82 \xe2\x94\x82 \xe2\x94\x82 \xe2\x94\x82 (esc)
  \xe2\x97\x8b \xe2\x94\x82 \xe2\x94\x82 \xe2\x94\x82  changeset:   15:1dda3f72782d (esc)
  \xe2\x94\x82\xe2\x95\xb2 \xe2\x95\xb2 \xe2\x95\xb2 \xe2\x95\xb2   parent:      13:22d8966a97e3 (esc)
  \xe2\x94\x82 \xe2\x94\x82 \xe2\x94\x82 \xe2\x94\x82 \xe2\x94\x82  parent:      14:8eac370358ef (esc)
  \xe2\x94\x82 \xe2\x94\x82 \xe2\x94\x82 \xe2\x94\x82 \xe2\x94\x82  user:        test (esc)
  \xe2\x94\x82 \xe2\x94\x82 \xe2\x94\x82 \xe2\x94\x82 \xe2\x94\x82  date:        Thu Jan 01 00:00:15 1970 +0000 (esc)
  \xe2\x94\x82 \xe2\x94\x82 \xe2\x94\x82 \xe2\x94\x82 \xe2\x94\x82  summary:     (15) expand (esc)
  \xe2\x94\x82 \xe2\x94\x82 \xe2\x94\x82 \xe2\x94\x82 \xe2\x94\x82 (esc)
  \xe2\x94\x82 \xe2\x97\x8b\xe2\x94\x80\xe2\x94\x80\xe2\x94\x80\xe2\x94\x80\xe2\x94\x80\xe2\x94\xa4  changeset:   14:8eac370358ef (esc)
  \xe2\x94\x82 \xe2\x94\x82 \xe2\x94\x82 \xe2\x94\x82 \xe2\x94\x82  parent:      0:e6eb3150255d (esc)
  \xe2\x94\x82 \xe2\x94\x82\xe2\x95\xb1 \xe2\x95\xb1 \xe2\x95\xb1   parent:      12:86b91144a6e9 (esc)
  \xe2\x94\x82 \xe2\x94\x82 \xe2\x94\x82 \xe2\x94\x82    user:        test (esc)
  \xe2\x94\x82 \xe2\x94\x82 \xe2\x94\x82 \xe2\x94\x82    date:        Thu Jan 01 00:00:14 1970 +0000 (esc)
  \xe2\x94\x82 \xe2\x94\x82 \xe2\x94\x82 \xe2\x94\x82    summary:     (14) merge two known; one immediate right, one far right (esc)
  \xe2\x94\x82 \xe2\x94\x82 \xe2\x94\x82 \xe2\x94\x82 (esc)
  \xe2\x97\x8b \xe2\x94\x82 \xe2\x94\x82 \xe2\x94\x82  changeset:   13:22d8966a97e3 (esc)
  \xe2\x94\x82\xe2\x95\xb2 \xe2\x95\xb2 \xe2\x95\xb2 \xe2\x95\xb2   parent:      9:7010c0af0a35 (esc)
  \xe2\x94\x82 \xe2\x94\x82 \xe2\x94\x82 \xe2\x94\x82 \xe2\x94\x82  parent:      11:832d76e6bdf2 (esc)
  \xe2\x94\x82 \xe2\x94\x82 \xe2\x94\x82 \xe2\x94\x82 \xe2\x94\x82  user:        test (esc)
  \xe2\x94\x82 \xe2\x94\x82 \xe2\x94\x82 \xe2\x94\x82 \xe2\x94\x82  date:        Thu Jan 01 00:00:13 1970 +0000 (esc)
  \xe2\x94\x82 \xe2\x94\x82 \xe2\x94\x82 \xe2\x94\x82 \xe2\x94\x82  summary:     (13) expand (esc)
  \xe2\x94\x82 \xe2\x94\x82 \xe2\x94\x82 \xe2\x94\x82 \xe2\x94\x82 (esc)
  \xe2\x94\x9c\xe2\x94\x80\xe2\x94\x80\xe2\x94\x80\xe2\x97\x8b \xe2\x94\x82 \xe2\x94\x82  changeset:   12:86b91144a6e9 (esc)
  \xe2\x94\x82 \xe2\x94\x82 \xe2\x94\x82\xe2\x95\xb1 \xe2\x95\xb1   parent:      1:6db2ef61d156 (esc)
  \xe2\x94\x82 \xe2\x94\x82 \xe2\x94\x82 \xe2\x94\x82    parent:      9:7010c0af0a35 (esc)
  \xe2\x94\x82 \xe2\x94\x82 \xe2\x94\x82 \xe2\x94\x82    user:        test (esc)
  \xe2\x94\x82 \xe2\x94\x82 \xe2\x94\x82 \xe2\x94\x82    date:        Thu Jan 01 00:00:12 1970 +0000 (esc)
  \xe2\x94\x82 \xe2\x94\x82 \xe2\x94\x82 \xe2\x94\x82    summary:     (12) merge two known; one immediate right, one far left (esc)
  \xe2\x94\x82 \xe2\x94\x82 \xe2\x94\x82 \xe2\x94\x82 (esc)
  \xe2\x94\x82 \xe2\x97\x8b \xe2\x94\x82 \xe2\x94\x82  changeset:   11:832d76e6bdf2 (esc)
  \xe2\x94\x82 \xe2\x94\x82\xe2\x95\xb2 \xe2\x95\xb2 \xe2\x95\xb2   parent:      6:b105a072e251 (esc)
  \xe2\x94\x82 \xe2\x94\x82 \xe2\x94\x82 \xe2\x94\x82 \xe2\x94\x82  parent:      10:74c64d036d72 (esc)
  \xe2\x94\x82 \xe2\x94\x82 \xe2\x94\x82 \xe2\x94\x82 \xe2\x94\x82  user:        test (esc)
  \xe2\x94\x82 \xe2\x94\x82 \xe2\x94\x82 \xe2\x94\x82 \xe2\x94\x82  date:        Thu Jan 01 00:00:11 1970 +0000 (esc)
  \xe2\x94\x82 \xe2\x94\x82 \xe2\x94\x82 \xe2\x94\x82 \xe2\x94\x82  summary:     (11) expand (esc)
  \xe2\x94\x82 \xe2\x94\x82 \xe2\x94\x82 \xe2\x94\x82 \xe2\x94\x82 (esc)
  \xe2\x94\x82 \xe2\x94\x82 \xe2\x97\x8b\xe2\x94\x80\xe2\x94\x80\xe2\x94\x80\xe2\x94\xa4  changeset:   10:74c64d036d72 (esc)
  \xe2\x94\x82 \xe2\x94\x82 \xe2\x94\x82 \xe2\x94\x82 \xe2\x94\x82  parent:      0:e6eb3150255d (esc)
  \xe2\x94\x82 \xe2\x94\x82\xe2\x95\xb1 \xe2\x95\xb1 \xe2\x95\xb1   parent:      6:b105a072e251 (esc)
  \xe2\x94\x82 \xe2\x94\x82 \xe2\x94\x82 \xe2\x94\x82    user:        test (esc)
  \xe2\x94\x82 \xe2\x94\x82 \xe2\x94\x82 \xe2\x94\x82    date:        Thu Jan 01 00:00:10 1970 +0000 (esc)
  \xe2\x94\x82 \xe2\x94\x82 \xe2\x94\x82 \xe2\x94\x82    summary:     (10) merge two known; one immediate left, one near right (esc)
  \xe2\x94\x82 \xe2\x94\x82 \xe2\x94\x82 \xe2\x94\x82 (esc)
  \xe2\x97\x8b \xe2\x94\x82 \xe2\x94\x82 \xe2\x94\x82  changeset:   9:7010c0af0a35 (esc)
  \xe2\x94\x82\xe2\x95\xb2 \xe2\x95\xb2 \xe2\x95\xb2 \xe2\x95\xb2   parent:      7:b632bb1b1224 (esc)
  \xe2\x94\x82 \xe2\x94\x82 \xe2\x94\x82 \xe2\x94\x82 \xe2\x94\x82  parent:      8:7a0b11f71937 (esc)
  \xe2\x94\x82 \xe2\x94\x82 \xe2\x94\x82 \xe2\x94\x82 \xe2\x94\x82  user:        test (esc)
  \xe2\x94\x82 \xe2\x94\x82 \xe2\x94\x82 \xe2\x94\x82 \xe2\x94\x82  date:        Thu Jan 01 00:00:09 1970 +0000 (esc)
  \xe2\x94\x82 \xe2\x94\x82 \xe2\x94\x82 \xe2\x94\x82 \xe2\x94\x82  summary:     (9) expand (esc)
  \xe2\x94\x82 \xe2\x94\x82 \xe2\x94\x82 \xe2\x94\x82 \xe2\x94\x82 (esc)
  \xe2\x94\x82 \xe2\x97\x8b\xe2\x94\x80\xe2\x94\x80\xe2\x94\x80\xe2\x94\x80\xe2\x94\x80\xe2\x94\xa4  changeset:   8:7a0b11f71937 (esc)
  \xe2\x94\x82 \xe2\x94\x82 \xe2\x94\x82 \xe2\x94\x82 \xe2\x94\x82  parent:      0:e6eb3150255d (esc)
  \xe2\x94\x82\xe2\x95\xb1 \xe2\x95\xb1 \xe2\x95\xb1 \xe2\x95\xb1   parent:      7:b632bb1b1224 (esc)
  \xe2\x94\x82 \xe2\x94\x82 \xe2\x94\x82 \xe2\x94\x82    user:        test (esc)
  \xe2\x94\x82 \xe2\x94\x82 \xe2\x94\x82 \xe2\x94\x82    date:        Thu Jan 01 00:00:08 1970 +0000 (esc)
  \xe2\x94\x82 \xe2\x94\x82 \xe2\x94\x82 \xe2\x94\x82    summary:     (8) merge two known; one immediate left, one far right (esc)
  \xe2\x94\x82 \xe2\x94\x82 \xe2\x94\x82 \xe2\x94\x82 (esc)
  \xe2\x97\x8b \xe2\x94\x82 \xe2\x94\x82 \xe2\x94\x82  changeset:   7:b632bb1b1224 (esc)
  \xe2\x94\x82\xe2\x95\xb2 \xe2\x95\xb2 \xe2\x95\xb2 \xe2\x95\xb2   parent:      2:3d9a33b8d1e1 (esc)
  \xe2\x94\x82 \xe2\x94\x82 \xe2\x94\x82 \xe2\x94\x82 \xe2\x94\x82  parent:      5:4409d547b708 (esc)
  \xe2\x94\x82 \xe2\x94\x82 \xe2\x94\x82 \xe2\x94\x82 \xe2\x94\x82  user:        test (esc)
  \xe2\x94\x82 \xe2\x94\x82 \xe2\x94\x82 \xe2\x94\x82 \xe2\x94\x82  date:        Thu Jan 01 00:00:07 1970 +0000 (esc)
  \xe2\x94\x82 \xe2\x94\x82 \xe2\x94\x82 \xe2\x94\x82 \xe2\x94\x82  summary:     (7) expand (esc)
  \xe2\x94\x82 \xe2\x94\x82 \xe2\x94\x82 \xe2\x94\x82 \xe2\x94\x82 (esc)
  \xe2\x94\x9c\xe2\x94\x80\xe2\x94\x80\xe2\x94\x80\xe2\x97\x8b \xe2\x94\x82 \xe2\x94\x82  changeset:   6:b105a072e251 (esc)
  \xe2\x94\x82 \xe2\x94\x82\xe2\x95\xb1 \xe2\x95\xb1 \xe2\x95\xb1   parent:      2:3d9a33b8d1e1 (esc)
  \xe2\x94\x82 \xe2\x94\x82 \xe2\x94\x82 \xe2\x94\x82    parent:      5:4409d547b708 (esc)
  \xe2\x94\x82 \xe2\x94\x82 \xe2\x94\x82 \xe2\x94\x82    user:        test (esc)
  \xe2\x94\x82 \xe2\x94\x82 \xe2\x94\x82 \xe2\x94\x82    date:        Thu Jan 01 00:00:06 1970 +0000 (esc)
  \xe2\x94\x82 \xe2\x94\x82 \xe2\x94\x82 \xe2\x94\x82    summary:     (6) merge two known; one immediate left, one far left (esc)
  \xe2\x94\x82 \xe2\x94\x82 \xe2\x94\x82 \xe2\x94\x82 (esc)
  \xe2\x94\x82 \xe2\x97\x8b \xe2\x94\x82 \xe2\x94\x82  changeset:   5:4409d547b708 (esc)
  \xe2\x94\x82 \xe2\x94\x82\xe2\x95\xb2 \xe2\x95\xb2 \xe2\x95\xb2   parent:      3:27eef8ed80b4 (esc)
  \xe2\x94\x82 \xe2\x94\x82 \xe2\x94\x82 \xe2\x94\x82 \xe2\x94\x82  parent:      4:26a8bac39d9f (esc)
  \xe2\x94\x82 \xe2\x94\x82 \xe2\x94\x82 \xe2\x94\x82 \xe2\x94\x82  user:        test (esc)
  \xe2\x94\x82 \xe2\x94\x82 \xe2\x94\x82 \xe2\x94\x82 \xe2\x94\x82  date:        Thu Jan 01 00:00:05 1970 +0000 (esc)
  \xe2\x94\x82 \xe2\x94\x82 \xe2\x94\x82 \xe2\x94\x82 \xe2\x94\x82  summary:     (5) expand (esc)
  \xe2\x94\x82 \xe2\x94\x82 \xe2\x94\x82 \xe2\x94\x82 \xe2\x94\x82 (esc)
  \xe2\x94\x82 \xe2\x94\x82 \xe2\x97\x8b \xe2\x94\x82 \xe2\x94\x82  changeset:   4:26a8bac39d9f (esc)
  \xe2\x94\x82 \xe2\x94\x82\xe2\x95\xb1\xe2\x94\x82\xe2\x95\xb1 \xe2\x95\xb1   parent:      1:6db2ef61d156 (esc)
  \xe2\x94\x82 \xe2\x94\x82 \xe2\x94\x82 \xe2\x94\x82    parent:      3:27eef8ed80b4 (esc)
  \xe2\x94\x82 \xe2\x94\x82 \xe2\x94\x82 \xe2\x94\x82    user:        test (esc)
  \xe2\x94\x82 \xe2\x94\x82 \xe2\x94\x82 \xe2\x94\x82    date:        Thu Jan 01 00:00:04 1970 +0000 (esc)
  \xe2\x94\x82 \xe2\x94\x82 \xe2\x94\x82 \xe2\x94\x82    summary:     (4) merge two known; one immediate left, one immediate right (esc)
  \xe2\x94\x82 \xe2\x94\x82 \xe2\x94\x82 \xe2\x94\x82 (esc)
  \xe2\x94\x82 \xe2\x97\x8b \xe2\x94\x82 \xe2\x94\x82  changeset:   3:27eef8ed80b4 (esc)
  \xe2\x94\x82\xe2\x95\xb1 \xe2\x95\xb1 \xe2\x95\xb1   user:        test (esc)
  \xe2\x94\x82 \xe2\x94\x82 \xe2\x94\x82    date:        Thu Jan 01 00:00:03 1970 +0000 (esc)
  \xe2\x94\x82 \xe2\x94\x82 \xe2\x94\x82    summary:     (3) collapse (esc)
  \xe2\x94\x82 \xe2\x94\x82 \xe2\x94\x82 (esc)
  \xe2\x97\x8b \xe2\x94\x82 \xe2\x94\x82  changeset:   2:3d9a33b8d1e1 (esc)
  \xe2\x94\x82\xe2\x95\xb1 \xe2\x95\xb1   user:        test (esc)
  \xe2\x94\x82 \xe2\x94\x82    date:        Thu Jan 01 00:00:02 1970 +0000 (esc)
  \xe2\x94\x82 \xe2\x94\x82    summary:     (2) collapse (esc)
  \xe2\x94\x82 \xe2\x94\x82 (esc)
  \xe2\x97\x8b \xe2\x94\x82  changeset:   1:6db2ef61d156 (esc)
  \xe2\x94\x82\xe2\x95\xb1   user:        test (esc)
  \xe2\x94\x82    date:        Thu Jan 01 00:00:01 1970 +0000 (esc)
  \xe2\x94\x82    summary:     (1) collapse (esc)
  \xe2\x94\x82 (esc)
  \xe2\x97\x8b  changeset:   0:e6eb3150255d (esc)
     user:        test
     date:        Thu Jan 01 00:00:00 1970 +0000
     summary:     (0) root
  
File glog per revset:

  $ hg log -G -r 'file("a")'
  \xe2\x97\x8d  changeset:   34:fea3ac5810e0 (esc)
  \xe2\x94\x82  tag:         tip (esc)
  \xe2\x94\x82  parent:      32:d06dffa21a31 (esc)
  \xe2\x94\x82  user:        test (esc)
  \xe2\x94\x82  date:        Thu Jan 01 00:00:34 1970 +0000 (esc)
  \xe2\x94\x82  summary:     (34) head (esc)
  \xe2\x94\x82 (esc)
  \xe2\x94\x82 \xe2\x97\x8b  changeset:   33:68608f5145f9 (esc)
  \xe2\x94\x82 \xe2\x94\x82  parent:      18:1aa84d96232a (esc)
  \xe2\x94\x82 \xe2\x94\x82  user:        test (esc)
  \xe2\x94\x82 \xe2\x94\x82  date:        Thu Jan 01 00:00:33 1970 +0000 (esc)
  \xe2\x94\x82 \xe2\x94\x82  summary:     (33) head (esc)
  \xe2\x94\x82 \xe2\x94\x82 (esc)
  \xe2\x97\x8b \xe2\x94\x82  changeset:   32:d06dffa21a31 (esc)
  \xe2\x94\x82\xe2\x95\xb2 \xe2\x95\xb2   parent:      27:886ed638191b (esc)
  \xe2\x94\x82 \xe2\x94\x82 \xe2\x94\x82  parent:      31:621d83e11f67 (esc)
  \xe2\x94\x82 \xe2\x94\x82 \xe2\x94\x82  user:        test (esc)
  \xe2\x94\x82 \xe2\x94\x82 \xe2\x94\x82  date:        Thu Jan 01 00:00:32 1970 +0000 (esc)
  \xe2\x94\x82 \xe2\x94\x82 \xe2\x94\x82  summary:     (32) expand (esc)
  \xe2\x94\x82 \xe2\x94\x82 \xe2\x94\x82 (esc)
  \xe2\x94\x82 \xe2\x97\x8b \xe2\x94\x82  changeset:   31:621d83e11f67 (esc)
  \xe2\x94\x82 \xe2\x94\x82\xe2\x95\xb2 \xe2\x95\xb2   parent:      21:d42a756af44d (esc)
  \xe2\x94\x82 \xe2\x94\x82 \xe2\x94\x82 \xe2\x94\x82  parent:      30:6e11cd4b648f (esc)
  \xe2\x94\x82 \xe2\x94\x82 \xe2\x94\x82 \xe2\x94\x82  user:        test (esc)
  \xe2\x94\x82 \xe2\x94\x82 \xe2\x94\x82 \xe2\x94\x82  date:        Thu Jan 01 00:00:31 1970 +0000 (esc)
  \xe2\x94\x82 \xe2\x94\x82 \xe2\x94\x82 \xe2\x94\x82  summary:     (31) expand (esc)
  \xe2\x94\x82 \xe2\x94\x82 \xe2\x94\x82 \xe2\x94\x82 (esc)
  \xe2\x94\x82 \xe2\x94\x82 \xe2\x97\x8b \xe2\x94\x82  changeset:   30:6e11cd4b648f (esc)
  \xe2\x94\x82 \xe2\x94\x82 \xe2\x94\x82\xe2\x95\xb2 \xe2\x95\xb2   parent:      28:44ecd0b9ae99 (esc)
  \xe2\x94\x82 \xe2\x94\x82 \xe2\x94\x82 \xe2\x94\x82 \xe2\x94\x82  parent:      29:cd9bb2be7593 (esc)
  \xe2\x94\x82 \xe2\x94\x82 \xe2\x94\x82 \xe2\x94\x82 \xe2\x94\x82  user:        test (esc)
  \xe2\x94\x82 \xe2\x94\x82 \xe2\x94\x82 \xe2\x94\x82 \xe2\x94\x82  date:        Thu Jan 01 00:00:30 1970 +0000 (esc)
  \xe2\x94\x82 \xe2\x94\x82 \xe2\x94\x82 \xe2\x94\x82 \xe2\x94\x82  summary:     (30) expand (esc)
  \xe2\x94\x82 \xe2\x94\x82 \xe2\x94\x82 \xe2\x94\x82 \xe2\x94\x82 (esc)
  \xe2\x94\x82 \xe2\x94\x82 \xe2\x94\x82 \xe2\x97\x8b \xe2\x94\x82  changeset:   29:cd9bb2be7593 (esc)
  \xe2\x94\x82 \xe2\x94\x82 \xe2\x94\x82 \xe2\x94\x82 \xe2\x94\x82  parent:      0:e6eb3150255d (esc)
  \xe2\x94\x82 \xe2\x94\x82 \xe2\x94\x82 \xe2\x94\x82 \xe2\x94\x82  user:        test (esc)
  \xe2\x94\x82 \xe2\x94\x82 \xe2\x94\x82 \xe2\x94\x82 \xe2\x94\x82  date:        Thu Jan 01 00:00:29 1970 +0000 (esc)
  \xe2\x94\x82 \xe2\x94\x82 \xe2\x94\x82 \xe2\x94\x82 \xe2\x94\x82  summary:     (29) regular commit (esc)
  \xe2\x94\x82 \xe2\x94\x82 \xe2\x94\x82 \xe2\x94\x82 \xe2\x94\x82 (esc)
  \xe2\x94\x82 \xe2\x94\x82 \xe2\x97\x8b \xe2\x94\x82 \xe2\x94\x82  changeset:   28:44ecd0b9ae99 (esc)
  \xe2\x94\x82 \xe2\x94\x82 \xe2\x94\x82\xe2\x95\xb2 \xe2\x95\xb2 \xe2\x95\xb2   parent:      1:6db2ef61d156 (esc)
  \xe2\x94\x82 \xe2\x94\x82 \xe2\x94\x82 \xe2\x94\x82 \xe2\x94\x82 \xe2\x94\x82  parent:      26:7f25b6c2f0b9 (esc)
  \xe2\x94\x82 \xe2\x94\x82 \xe2\x94\x82 \xe2\x94\x82 \xe2\x94\x82 \xe2\x94\x82  user:        test (esc)
  \xe2\x94\x82 \xe2\x94\x82 \xe2\x94\x82 \xe2\x94\x82 \xe2\x94\x82 \xe2\x94\x82  date:        Thu Jan 01 00:00:28 1970 +0000 (esc)
  \xe2\x94\x82 \xe2\x94\x82 \xe2\x94\x82 \xe2\x94\x82 \xe2\x94\x82 \xe2\x94\x82  summary:     (28) merge zero known (esc)
  \xe2\x94\x82 \xe2\x94\x82 \xe2\x94\x82 \xe2\x94\x82 \xe2\x94\x82 \xe2\x94\x82 (esc)
  \xe2\x97\x8b \xe2\x94\x82 \xe2\x94\x82 \xe2\x94\x82 \xe2\x94\x82 \xe2\x94\x82  changeset:   27:886ed638191b (esc)
  \xe2\x94\x82\xe2\x95\xb1 \xe2\x95\xb1 \xe2\x95\xb1 \xe2\x95\xb1 \xe2\x95\xb1   parent:      21:d42a756af44d (esc)
  \xe2\x94\x82 \xe2\x94\x82 \xe2\x94\x82 \xe2\x94\x82 \xe2\x94\x82    user:        test (esc)
  \xe2\x94\x82 \xe2\x94\x82 \xe2\x94\x82 \xe2\x94\x82 \xe2\x94\x82    date:        Thu Jan 01 00:00:27 1970 +0000 (esc)
  \xe2\x94\x82 \xe2\x94\x82 \xe2\x94\x82 \xe2\x94\x82 \xe2\x94\x82    summary:     (27) collapse (esc)
  \xe2\x94\x82 \xe2\x94\x82 \xe2\x94\x82 \xe2\x94\x82 \xe2\x94\x82 (esc)
  \xe2\x94\x82 \xe2\x94\x82 \xe2\x97\x8b\xe2\x94\x80\xe2\x94\x80\xe2\x94\x80\xe2\x94\xa4  changeset:   26:7f25b6c2f0b9 (esc)
  \xe2\x94\x82 \xe2\x94\x82 \xe2\x94\x82 \xe2\x94\x82 \xe2\x94\x82  parent:      18:1aa84d96232a (esc)
  \xe2\x94\x82 \xe2\x94\x82 \xe2\x94\x82 \xe2\x94\x82 \xe2\x94\x82  parent:      25:91da8ed57247 (esc)
  \xe2\x94\x82 \xe2\x94\x82 \xe2\x94\x82 \xe2\x94\x82 \xe2\x94\x82  user:        test (esc)
  \xe2\x94\x82 \xe2\x94\x82 \xe2\x94\x82 \xe2\x94\x82 \xe2\x94\x82  date:        Thu Jan 01 00:00:26 1970 +0000 (esc)
  \xe2\x94\x82 \xe2\x94\x82 \xe2\x94\x82 \xe2\x94\x82 \xe2\x94\x82  summary:     (26) merge one known; far right (esc)
  \xe2\x94\x82 \xe2\x94\x82 \xe2\x94\x82 \xe2\x94\x82 \xe2\x94\x82 (esc)
  \xe2\x94\x9c\xe2\x94\x80\xe2\x94\x80\xe2\x94\x80\xe2\x97\x8b \xe2\x94\x82 \xe2\x94\x82  changeset:   25:91da8ed57247 (esc)
  \xe2\x94\x82 \xe2\x94\x82 \xe2\x94\x82 \xe2\x94\x82 \xe2\x94\x82  parent:      21:d42a756af44d (esc)
  \xe2\x94\x82 \xe2\x94\x82 \xe2\x94\x82 \xe2\x94\x82 \xe2\x94\x82  parent:      24:a9c19a3d96b7 (esc)
  \xe2\x94\x82 \xe2\x94\x82 \xe2\x94\x82 \xe2\x94\x82 \xe2\x94\x82  user:        test (esc)
  \xe2\x94\x82 \xe2\x94\x82 \xe2\x94\x82 \xe2\x94\x82 \xe2\x94\x82  date:        Thu Jan 01 00:00:25 1970 +0000 (esc)
  \xe2\x94\x82 \xe2\x94\x82 \xe2\x94\x82 \xe2\x94\x82 \xe2\x94\x82  summary:     (25) merge one known; far left (esc)
  \xe2\x94\x82 \xe2\x94\x82 \xe2\x94\x82 \xe2\x94\x82 \xe2\x94\x82 (esc)
  \xe2\x94\x82 \xe2\x94\x82 \xe2\x97\x8b \xe2\x94\x82 \xe2\x94\x82  changeset:   24:a9c19a3d96b7 (esc)
  \xe2\x94\x82 \xe2\x94\x82 \xe2\x94\x82\xe2\x95\xb2\xe2\x94\x82 \xe2\x94\x82  parent:      0:e6eb3150255d (esc)
  \xe2\x94\x82 \xe2\x94\x82 \xe2\x94\x82 \xe2\x94\x82 \xe2\x94\x82  parent:      23:a01cddf0766d (esc)
  \xe2\x94\x82 \xe2\x94\x82 \xe2\x94\x82 \xe2\x94\x82 \xe2\x94\x82  user:        test (esc)
  \xe2\x94\x82 \xe2\x94\x82 \xe2\x94\x82 \xe2\x94\x82 \xe2\x94\x82  date:        Thu Jan 01 00:00:24 1970 +0000 (esc)
  \xe2\x94\x82 \xe2\x94\x82 \xe2\x94\x82 \xe2\x94\x82 \xe2\x94\x82  summary:     (24) merge one known; immediate right (esc)
  \xe2\x94\x82 \xe2\x94\x82 \xe2\x94\x82 \xe2\x94\x82 \xe2\x94\x82 (esc)
  \xe2\x94\x82 \xe2\x94\x82 \xe2\x97\x8b \xe2\x94\x82 \xe2\x94\x82  changeset:   23:a01cddf0766d (esc)
  \xe2\x94\x82 \xe2\x94\x82\xe2\x95\xb1\xe2\x94\x82 \xe2\x94\x82 \xe2\x94\x82  parent:      1:6db2ef61d156 (esc)
  \xe2\x94\x82 \xe2\x94\x82 \xe2\x94\x82 \xe2\x94\x82 \xe2\x94\x82  parent:      22:e0d9cccacb5d (esc)
  \xe2\x94\x82 \xe2\x94\x82 \xe2\x94\x82 \xe2\x94\x82 \xe2\x94\x82  user:        test (esc)
  \xe2\x94\x82 \xe2\x94\x82 \xe2\x94\x82 \xe2\x94\x82 \xe2\x94\x82  date:        Thu Jan 01 00:00:23 1970 +0000 (esc)
  \xe2\x94\x82 \xe2\x94\x82 \xe2\x94\x82 \xe2\x94\x82 \xe2\x94\x82  summary:     (23) merge one known; immediate left (esc)
  \xe2\x94\x82 \xe2\x94\x82 \xe2\x94\x82 \xe2\x94\x82 \xe2\x94\x82 (esc)
  \xe2\x94\x9c\xe2\x94\x80\xe2\x94\x80\xe2\x94\x80\xe2\x97\x8b\xe2\x94\x80\xe2\x94\x80\xe2\x94\x80\xe2\x94\xa4  changeset:   22:e0d9cccacb5d (esc)
  \xe2\x94\x82 \xe2\x94\x82   \xe2\x94\x82 \xe2\x94\x82  parent:      18:1aa84d96232a (esc)
  \xe2\x94\x82 \xe2\x94\x82  \xe2\x95\xb1 \xe2\x95\xb1   parent:      21:d42a756af44d (esc)
  \xe2\x94\x82 \xe2\x94\x82 \xe2\x94\x82 \xe2\x94\x82    user:        test (esc)
  \xe2\x94\x82 \xe2\x94\x82 \xe2\x94\x82 \xe2\x94\x82    date:        Thu Jan 01 00:00:22 1970 +0000 (esc)
  \xe2\x94\x82 \xe2\x94\x82 \xe2\x94\x82 \xe2\x94\x82    summary:     (22) merge two known; one far left, one far right (esc)
  \xe2\x94\x82 \xe2\x94\x82 \xe2\x94\x82 \xe2\x94\x82 (esc)
  \xe2\x97\x8b \xe2\x94\x82 \xe2\x94\x82 \xe2\x94\x82  changeset:   21:d42a756af44d (esc)
  \xe2\x94\x82\xe2\x95\xb2 \xe2\x95\xb2 \xe2\x95\xb2 \xe2\x95\xb2   parent:      19:31ddc2c1573b (esc)
  \xe2\x94\x82 \xe2\x94\x82 \xe2\x94\x82 \xe2\x94\x82 \xe2\x94\x82  parent:      20:d30ed6450e32 (esc)
  \xe2\x94\x82 \xe2\x94\x82 \xe2\x94\x82 \xe2\x94\x82 \xe2\x94\x82  user:        test (esc)
  \xe2\x94\x82 \xe2\x94\x82 \xe2\x94\x82 \xe2\x94\x82 \xe2\x94\x82  date:        Thu Jan 01 00:00:21 1970 +0000 (esc)
  \xe2\x94\x82 \xe2\x94\x82 \xe2\x94\x82 \xe2\x94\x82 \xe2\x94\x82  summary:     (21) expand (esc)
  \xe2\x94\x82 \xe2\x94\x82 \xe2\x94\x82 \xe2\x94\x82 \xe2\x94\x82 (esc)
  \xe2\x94\x82 \xe2\x97\x8b\xe2\x94\x80\xe2\x94\x80\xe2\x94\x80\xe2\x94\xbc\xe2\x94\x80\xe2\x94\xa4  changeset:   20:d30ed6450e32 (esc)
  \xe2\x94\x82   \xe2\x94\x82 \xe2\x94\x82 \xe2\x94\x82  parent:      0:e6eb3150255d (esc)
  \xe2\x94\x82  \xe2\x95\xb1 \xe2\x95\xb1 \xe2\x95\xb1   parent:      18:1aa84d96232a (esc)
  \xe2\x94\x82 \xe2\x94\x82 \xe2\x94\x82 \xe2\x94\x82    user:        test (esc)
  \xe2\x94\x82 \xe2\x94\x82 \xe2\x94\x82 \xe2\x94\x82    date:        Thu Jan 01 00:00:20 1970 +0000 (esc)
  \xe2\x94\x82 \xe2\x94\x82 \xe2\x94\x82 \xe2\x94\x82    summary:     (20) merge two known; two far right (esc)
  \xe2\x94\x82 \xe2\x94\x82 \xe2\x94\x82 \xe2\x94\x82 (esc)
  \xe2\x97\x8b \xe2\x94\x82 \xe2\x94\x82 \xe2\x94\x82  changeset:   19:31ddc2c1573b (esc)
  \xe2\x94\x82\xe2\x95\xb2 \xe2\x95\xb2 \xe2\x95\xb2 \xe2\x95\xb2   parent:      15:1dda3f72782d (esc)
  \xe2\x94\x82 \xe2\x94\x82 \xe2\x94\x82 \xe2\x94\x82 \xe2\x94\x82  parent:      17:44765d7c06e0 (esc)
  \xe2\x94\x82 \xe2\x94\x82 \xe2\x94\x82 \xe2\x94\x82 \xe2\x94\x82  user:        test (esc)
  \xe2\x94\x82 \xe2\x94\x82 \xe2\x94\x82 \xe2\x94\x82 \xe2\x94\x82  date:        Thu Jan 01 00:00:19 1970 +0000 (esc)
  \xe2\x94\x82 \xe2\x94\x82 \xe2\x94\x82 \xe2\x94\x82 \xe2\x94\x82  summary:     (19) expand (esc)
  \xe2\x94\x82 \xe2\x94\x82 \xe2\x94\x82 \xe2\x94\x82 \xe2\x94\x82 (esc)
  \xe2\x94\x9c\xe2\x94\x80\xe2\x94\x80\xe2\x94\x80\xe2\x94\xbc\xe2\x94\x80\xe2\x94\x80\xe2\x94\x80\xe2\x97\x8b  changeset:   18:1aa84d96232a (esc)
  \xe2\x94\x82 \xe2\x94\x82 \xe2\x94\x82 \xe2\x94\x82    parent:      1:6db2ef61d156 (esc)
  \xe2\x94\x82 \xe2\x94\x82 \xe2\x94\x82 \xe2\x94\x82    parent:      15:1dda3f72782d (esc)
  \xe2\x94\x82 \xe2\x94\x82 \xe2\x94\x82 \xe2\x94\x82    user:        test (esc)
  \xe2\x94\x82 \xe2\x94\x82 \xe2\x94\x82 \xe2\x94\x82    date:        Thu Jan 01 00:00:18 1970 +0000 (esc)
  \xe2\x94\x82 \xe2\x94\x82 \xe2\x94\x82 \xe2\x94\x82    summary:     (18) merge two known; two far left (esc)
  \xe2\x94\x82 \xe2\x94\x82 \xe2\x94\x82 \xe2\x94\x82 (esc)
  \xe2\x94\x82 \xe2\x97\x8b \xe2\x94\x82 \xe2\x94\x82  changeset:   17:44765d7c06e0 (esc)
  \xe2\x94\x82 \xe2\x94\x82\xe2\x95\xb2 \xe2\x95\xb2 \xe2\x95\xb2   parent:      12:86b91144a6e9 (esc)
  \xe2\x94\x82 \xe2\x94\x82 \xe2\x94\x82 \xe2\x94\x82 \xe2\x94\x82  parent:      16:3677d192927d (esc)
  \xe2\x94\x82 \xe2\x94\x82 \xe2\x94\x82 \xe2\x94\x82 \xe2\x94\x82  user:        test (esc)
  \xe2\x94\x82 \xe2\x94\x82 \xe2\x94\x82 \xe2\x94\x82 \xe2\x94\x82  date:        Thu Jan 01 00:00:17 1970 +0000 (esc)
  \xe2\x94\x82 \xe2\x94\x82 \xe2\x94\x82 \xe2\x94\x82 \xe2\x94\x82  summary:     (17) expand (esc)
  \xe2\x94\x82 \xe2\x94\x82 \xe2\x94\x82 \xe2\x94\x82 \xe2\x94\x82 (esc)
  \xe2\x94\x82 \xe2\x94\x82 \xe2\x97\x8b\xe2\x94\x80\xe2\x94\x80\xe2\x94\x80\xe2\x94\xa4  changeset:   16:3677d192927d (esc)
  \xe2\x94\x82 \xe2\x94\x82 \xe2\x94\x82 \xe2\x94\x82 \xe2\x94\x82  parent:      0:e6eb3150255d (esc)
  \xe2\x94\x82 \xe2\x94\x82 \xe2\x94\x82\xe2\x95\xb1 \xe2\x95\xb1   parent:      1:6db2ef61d156 (esc)
  \xe2\x94\x82 \xe2\x94\x82 \xe2\x94\x82 \xe2\x94\x82    user:        test (esc)
  \xe2\x94\x82 \xe2\x94\x82 \xe2\x94\x82 \xe2\x94\x82    date:        Thu Jan 01 00:00:16 1970 +0000 (esc)
  \xe2\x94\x82 \xe2\x94\x82 \xe2\x94\x82 \xe2\x94\x82    summary:     (16) merge two known; one immediate right, one near right (esc)
  \xe2\x94\x82 \xe2\x94\x82 \xe2\x94\x82 \xe2\x94\x82 (esc)
  \xe2\x97\x8b \xe2\x94\x82 \xe2\x94\x82 \xe2\x94\x82  changeset:   15:1dda3f72782d (esc)
  \xe2\x94\x82\xe2\x95\xb2 \xe2\x95\xb2 \xe2\x95\xb2 \xe2\x95\xb2   parent:      13:22d8966a97e3 (esc)
  \xe2\x94\x82 \xe2\x94\x82 \xe2\x94\x82 \xe2\x94\x82 \xe2\x94\x82  parent:      14:8eac370358ef (esc)
  \xe2\x94\x82 \xe2\x94\x82 \xe2\x94\x82 \xe2\x94\x82 \xe2\x94\x82  user:        test (esc)
  \xe2\x94\x82 \xe2\x94\x82 \xe2\x94\x82 \xe2\x94\x82 \xe2\x94\x82  date:        Thu Jan 01 00:00:15 1970 +0000 (esc)
  \xe2\x94\x82 \xe2\x94\x82 \xe2\x94\x82 \xe2\x94\x82 \xe2\x94\x82  summary:     (15) expand (esc)
  \xe2\x94\x82 \xe2\x94\x82 \xe2\x94\x82 \xe2\x94\x82 \xe2\x94\x82 (esc)
  \xe2\x94\x82 \xe2\x97\x8b\xe2\x94\x80\xe2\x94\x80\xe2\x94\x80\xe2\x94\x80\xe2\x94\x80\xe2\x94\xa4  changeset:   14:8eac370358ef (esc)
  \xe2\x94\x82 \xe2\x94\x82 \xe2\x94\x82 \xe2\x94\x82 \xe2\x94\x82  parent:      0:e6eb3150255d (esc)
  \xe2\x94\x82 \xe2\x94\x82\xe2\x95\xb1 \xe2\x95\xb1 \xe2\x95\xb1   parent:      12:86b91144a6e9 (esc)
  \xe2\x94\x82 \xe2\x94\x82 \xe2\x94\x82 \xe2\x94\x82    user:        test (esc)
  \xe2\x94\x82 \xe2\x94\x82 \xe2\x94\x82 \xe2\x94\x82    date:        Thu Jan 01 00:00:14 1970 +0000 (esc)
  \xe2\x94\x82 \xe2\x94\x82 \xe2\x94\x82 \xe2\x94\x82    summary:     (14) merge two known; one immediate right, one far right (esc)
  \xe2\x94\x82 \xe2\x94\x82 \xe2\x94\x82 \xe2\x94\x82 (esc)
  \xe2\x97\x8b \xe2\x94\x82 \xe2\x94\x82 \xe2\x94\x82  changeset:   13:22d8966a97e3 (esc)
  \xe2\x94\x82\xe2\x95\xb2 \xe2\x95\xb2 \xe2\x95\xb2 \xe2\x95\xb2   parent:      9:7010c0af0a35 (esc)
  \xe2\x94\x82 \xe2\x94\x82 \xe2\x94\x82 \xe2\x94\x82 \xe2\x94\x82  parent:      11:832d76e6bdf2 (esc)
  \xe2\x94\x82 \xe2\x94\x82 \xe2\x94\x82 \xe2\x94\x82 \xe2\x94\x82  user:        test (esc)
  \xe2\x94\x82 \xe2\x94\x82 \xe2\x94\x82 \xe2\x94\x82 \xe2\x94\x82  date:        Thu Jan 01 00:00:13 1970 +0000 (esc)
  \xe2\x94\x82 \xe2\x94\x82 \xe2\x94\x82 \xe2\x94\x82 \xe2\x94\x82  summary:     (13) expand (esc)
  \xe2\x94\x82 \xe2\x94\x82 \xe2\x94\x82 \xe2\x94\x82 \xe2\x94\x82 (esc)
  \xe2\x94\x9c\xe2\x94\x80\xe2\x94\x80\xe2\x94\x80\xe2\x97\x8b \xe2\x94\x82 \xe2\x94\x82  changeset:   12:86b91144a6e9 (esc)
  \xe2\x94\x82 \xe2\x94\x82 \xe2\x94\x82\xe2\x95\xb1 \xe2\x95\xb1   parent:      1:6db2ef61d156 (esc)
  \xe2\x94\x82 \xe2\x94\x82 \xe2\x94\x82 \xe2\x94\x82    parent:      9:7010c0af0a35 (esc)
  \xe2\x94\x82 \xe2\x94\x82 \xe2\x94\x82 \xe2\x94\x82    user:        test (esc)
  \xe2\x94\x82 \xe2\x94\x82 \xe2\x94\x82 \xe2\x94\x82    date:        Thu Jan 01 00:00:12 1970 +0000 (esc)
  \xe2\x94\x82 \xe2\x94\x82 \xe2\x94\x82 \xe2\x94\x82    summary:     (12) merge two known; one immediate right, one far left (esc)
  \xe2\x94\x82 \xe2\x94\x82 \xe2\x94\x82 \xe2\x94\x82 (esc)
  \xe2\x94\x82 \xe2\x97\x8b \xe2\x94\x82 \xe2\x94\x82  changeset:   11:832d76e6bdf2 (esc)
  \xe2\x94\x82 \xe2\x94\x82\xe2\x95\xb2 \xe2\x95\xb2 \xe2\x95\xb2   parent:      6:b105a072e251 (esc)
  \xe2\x94\x82 \xe2\x94\x82 \xe2\x94\x82 \xe2\x94\x82 \xe2\x94\x82  parent:      10:74c64d036d72 (esc)
  \xe2\x94\x82 \xe2\x94\x82 \xe2\x94\x82 \xe2\x94\x82 \xe2\x94\x82  user:        test (esc)
  \xe2\x94\x82 \xe2\x94\x82 \xe2\x94\x82 \xe2\x94\x82 \xe2\x94\x82  date:        Thu Jan 01 00:00:11 1970 +0000 (esc)
  \xe2\x94\x82 \xe2\x94\x82 \xe2\x94\x82 \xe2\x94\x82 \xe2\x94\x82  summary:     (11) expand (esc)
  \xe2\x94\x82 \xe2\x94\x82 \xe2\x94\x82 \xe2\x94\x82 \xe2\x94\x82 (esc)
  \xe2\x94\x82 \xe2\x94\x82 \xe2\x97\x8b\xe2\x94\x80\xe2\x94\x80\xe2\x94\x80\xe2\x94\xa4  changeset:   10:74c64d036d72 (esc)
  \xe2\x94\x82 \xe2\x94\x82 \xe2\x94\x82 \xe2\x94\x82 \xe2\x94\x82  parent:      0:e6eb3150255d (esc)
  \xe2\x94\x82 \xe2\x94\x82\xe2\x95\xb1 \xe2\x95\xb1 \xe2\x95\xb1   parent:      6:b105a072e251 (esc)
  \xe2\x94\x82 \xe2\x94\x82 \xe2\x94\x82 \xe2\x94\x82    user:        test (esc)
  \xe2\x94\x82 \xe2\x94\x82 \xe2\x94\x82 \xe2\x94\x82    date:        Thu Jan 01 00:00:10 1970 +0000 (esc)
  \xe2\x94\x82 \xe2\x94\x82 \xe2\x94\x82 \xe2\x94\x82    summary:     (10) merge two known; one immediate left, one near right (esc)
  \xe2\x94\x82 \xe2\x94\x82 \xe2\x94\x82 \xe2\x94\x82 (esc)
  \xe2\x97\x8b \xe2\x94\x82 \xe2\x94\x82 \xe2\x94\x82  changeset:   9:7010c0af0a35 (esc)
  \xe2\x94\x82\xe2\x95\xb2 \xe2\x95\xb2 \xe2\x95\xb2 \xe2\x95\xb2   parent:      7:b632bb1b1224 (esc)
  \xe2\x94\x82 \xe2\x94\x82 \xe2\x94\x82 \xe2\x94\x82 \xe2\x94\x82  parent:      8:7a0b11f71937 (esc)
  \xe2\x94\x82 \xe2\x94\x82 \xe2\x94\x82 \xe2\x94\x82 \xe2\x94\x82  user:        test (esc)
  \xe2\x94\x82 \xe2\x94\x82 \xe2\x94\x82 \xe2\x94\x82 \xe2\x94\x82  date:        Thu Jan 01 00:00:09 1970 +0000 (esc)
  \xe2\x94\x82 \xe2\x94\x82 \xe2\x94\x82 \xe2\x94\x82 \xe2\x94\x82  summary:     (9) expand (esc)
  \xe2\x94\x82 \xe2\x94\x82 \xe2\x94\x82 \xe2\x94\x82 \xe2\x94\x82 (esc)
  \xe2\x94\x82 \xe2\x97\x8b\xe2\x94\x80\xe2\x94\x80\xe2\x94\x80\xe2\x94\x80\xe2\x94\x80\xe2\x94\xa4  changeset:   8:7a0b11f71937 (esc)
  \xe2\x94\x82 \xe2\x94\x82 \xe2\x94\x82 \xe2\x94\x82 \xe2\x94\x82  parent:      0:e6eb3150255d (esc)
  \xe2\x94\x82\xe2\x95\xb1 \xe2\x95\xb1 \xe2\x95\xb1 \xe2\x95\xb1   parent:      7:b632bb1b1224 (esc)
  \xe2\x94\x82 \xe2\x94\x82 \xe2\x94\x82 \xe2\x94\x82    user:        test (esc)
  \xe2\x94\x82 \xe2\x94\x82 \xe2\x94\x82 \xe2\x94\x82    date:        Thu Jan 01 00:00:08 1970 +0000 (esc)
  \xe2\x94\x82 \xe2\x94\x82 \xe2\x94\x82 \xe2\x94\x82    summary:     (8) merge two known; one immediate left, one far right (esc)
  \xe2\x94\x82 \xe2\x94\x82 \xe2\x94\x82 \xe2\x94\x82 (esc)
  \xe2\x97\x8b \xe2\x94\x82 \xe2\x94\x82 \xe2\x94\x82  changeset:   7:b632bb1b1224 (esc)
  \xe2\x94\x82\xe2\x95\xb2 \xe2\x95\xb2 \xe2\x95\xb2 \xe2\x95\xb2   parent:      2:3d9a33b8d1e1 (esc)
  \xe2\x94\x82 \xe2\x94\x82 \xe2\x94\x82 \xe2\x94\x82 \xe2\x94\x82  parent:      5:4409d547b708 (esc)
  \xe2\x94\x82 \xe2\x94\x82 \xe2\x94\x82 \xe2\x94\x82 \xe2\x94\x82  user:        test (esc)
  \xe2\x94\x82 \xe2\x94\x82 \xe2\x94\x82 \xe2\x94\x82 \xe2\x94\x82  date:        Thu Jan 01 00:00:07 1970 +0000 (esc)
  \xe2\x94\x82 \xe2\x94\x82 \xe2\x94\x82 \xe2\x94\x82 \xe2\x94\x82  summary:     (7) expand (esc)
  \xe2\x94\x82 \xe2\x94\x82 \xe2\x94\x82 \xe2\x94\x82 \xe2\x94\x82 (esc)
  \xe2\x94\x9c\xe2\x94\x80\xe2\x94\x80\xe2\x94\x80\xe2\x97\x8b \xe2\x94\x82 \xe2\x94\x82  changeset:   6:b105a072e251 (esc)
  \xe2\x94\x82 \xe2\x94\x82\xe2\x95\xb1 \xe2\x95\xb1 \xe2\x95\xb1   parent:      2:3d9a33b8d1e1 (esc)
  \xe2\x94\x82 \xe2\x94\x82 \xe2\x94\x82 \xe2\x94\x82    parent:      5:4409d547b708 (esc)
  \xe2\x94\x82 \xe2\x94\x82 \xe2\x94\x82 \xe2\x94\x82    user:        test (esc)
  \xe2\x94\x82 \xe2\x94\x82 \xe2\x94\x82 \xe2\x94\x82    date:        Thu Jan 01 00:00:06 1970 +0000 (esc)
  \xe2\x94\x82 \xe2\x94\x82 \xe2\x94\x82 \xe2\x94\x82    summary:     (6) merge two known; one immediate left, one far left (esc)
  \xe2\x94\x82 \xe2\x94\x82 \xe2\x94\x82 \xe2\x94\x82 (esc)
  \xe2\x94\x82 \xe2\x97\x8b \xe2\x94\x82 \xe2\x94\x82  changeset:   5:4409d547b708 (esc)
  \xe2\x94\x82 \xe2\x94\x82\xe2\x95\xb2 \xe2\x95\xb2 \xe2\x95\xb2   parent:      3:27eef8ed80b4 (esc)
  \xe2\x94\x82 \xe2\x94\x82 \xe2\x94\x82 \xe2\x94\x82 \xe2\x94\x82  parent:      4:26a8bac39d9f (esc)
  \xe2\x94\x82 \xe2\x94\x82 \xe2\x94\x82 \xe2\x94\x82 \xe2\x94\x82  user:        test (esc)
  \xe2\x94\x82 \xe2\x94\x82 \xe2\x94\x82 \xe2\x94\x82 \xe2\x94\x82  date:        Thu Jan 01 00:00:05 1970 +0000 (esc)
  \xe2\x94\x82 \xe2\x94\x82 \xe2\x94\x82 \xe2\x94\x82 \xe2\x94\x82  summary:     (5) expand (esc)
  \xe2\x94\x82 \xe2\x94\x82 \xe2\x94\x82 \xe2\x94\x82 \xe2\x94\x82 (esc)
  \xe2\x94\x82 \xe2\x94\x82 \xe2\x97\x8b \xe2\x94\x82 \xe2\x94\x82  changeset:   4:26a8bac39d9f (esc)
  \xe2\x94\x82 \xe2\x94\x82\xe2\x95\xb1\xe2\x94\x82\xe2\x95\xb1 \xe2\x95\xb1   parent:      1:6db2ef61d156 (esc)
  \xe2\x94\x82 \xe2\x94\x82 \xe2\x94\x82 \xe2\x94\x82    parent:      3:27eef8ed80b4 (esc)
  \xe2\x94\x82 \xe2\x94\x82 \xe2\x94\x82 \xe2\x94\x82    user:        test (esc)
  \xe2\x94\x82 \xe2\x94\x82 \xe2\x94\x82 \xe2\x94\x82    date:        Thu Jan 01 00:00:04 1970 +0000 (esc)
  \xe2\x94\x82 \xe2\x94\x82 \xe2\x94\x82 \xe2\x94\x82    summary:     (4) merge two known; one immediate left, one immediate right (esc)
  \xe2\x94\x82 \xe2\x94\x82 \xe2\x94\x82 \xe2\x94\x82 (esc)
  \xe2\x94\x82 \xe2\x97\x8b \xe2\x94\x82 \xe2\x94\x82  changeset:   3:27eef8ed80b4 (esc)
  \xe2\x94\x82\xe2\x95\xb1 \xe2\x95\xb1 \xe2\x95\xb1   user:        test (esc)
  \xe2\x94\x82 \xe2\x94\x82 \xe2\x94\x82    date:        Thu Jan 01 00:00:03 1970 +0000 (esc)
  \xe2\x94\x82 \xe2\x94\x82 \xe2\x94\x82    summary:     (3) collapse (esc)
  \xe2\x94\x82 \xe2\x94\x82 \xe2\x94\x82 (esc)
  \xe2\x97\x8b \xe2\x94\x82 \xe2\x94\x82  changeset:   2:3d9a33b8d1e1 (esc)
  \xe2\x94\x82\xe2\x95\xb1 \xe2\x95\xb1   user:        test (esc)
  \xe2\x94\x82 \xe2\x94\x82    date:        Thu Jan 01 00:00:02 1970 +0000 (esc)
  \xe2\x94\x82 \xe2\x94\x82    summary:     (2) collapse (esc)
  \xe2\x94\x82 \xe2\x94\x82 (esc)
  \xe2\x97\x8b \xe2\x94\x82  changeset:   1:6db2ef61d156 (esc)
  \xe2\x94\x82\xe2\x95\xb1   user:        test (esc)
  \xe2\x94\x82    date:        Thu Jan 01 00:00:01 1970 +0000 (esc)
  \xe2\x94\x82    summary:     (1) collapse (esc)
  \xe2\x94\x82 (esc)
  \xe2\x97\x8b  changeset:   0:e6eb3150255d (esc)
     user:        test
     date:        Thu Jan 01 00:00:00 1970 +0000
     summary:     (0) root
  

File glog per revset (only merges):

  $ hg log -G -r 'file("a")' -m
  \xe2\x97\x8b  changeset:   32:d06dffa21a31 (esc)
  \xe2\x94\x82\xe2\x95\xb2   parent:      27:886ed638191b (esc)
  \xe2\x94\x82 \xe2\x94\x86  parent:      31:621d83e11f67 (esc)
  \xe2\x94\x82 \xe2\x94\x86  user:        test (esc)
  \xe2\x94\x82 \xe2\x94\x86  date:        Thu Jan 01 00:00:32 1970 +0000 (esc)
  \xe2\x94\x82 \xe2\x94\x86  summary:     (32) expand (esc)
  \xe2\x94\x82 \xe2\x94\x86 (esc)
  \xe2\x97\x8b \xe2\x94\x86  changeset:   31:621d83e11f67 (esc)
  \xe2\x94\x82\xe2\x95\xb2\xe2\x94\x86  parent:      21:d42a756af44d (esc)
  \xe2\x94\x82 \xe2\x94\x86  parent:      30:6e11cd4b648f (esc)
  \xe2\x94\x82 \xe2\x94\x86  user:        test (esc)
  \xe2\x94\x82 \xe2\x94\x86  date:        Thu Jan 01 00:00:31 1970 +0000 (esc)
  \xe2\x94\x82 \xe2\x94\x86  summary:     (31) expand (esc)
  \xe2\x94\x82 \xe2\x94\x86 (esc)
  \xe2\x97\x8b \xe2\x94\x86  changeset:   30:6e11cd4b648f (esc)
  \xe2\x94\x82\xe2\x95\xb2 \xe2\x95\xb2   parent:      28:44ecd0b9ae99 (esc)
  \xe2\x94\x82 \xe2\x95\xa7 \xe2\x94\x86  parent:      29:cd9bb2be7593 (esc)
  \xe2\x94\x82   \xe2\x94\x86  user:        test (esc)
  \xe2\x94\x82   \xe2\x94\x86  date:        Thu Jan 01 00:00:30 1970 +0000 (esc)
  \xe2\x94\x82   \xe2\x94\x86  summary:     (30) expand (esc)
  \xe2\x94\x82  \xe2\x95\xb1 (esc)
  \xe2\x97\x8b \xe2\x94\x86  changeset:   28:44ecd0b9ae99 (esc)
  \xe2\x94\x82\xe2\x95\xb2 \xe2\x95\xb2   parent:      1:6db2ef61d156 (esc)
  \xe2\x94\x82 \xe2\x95\xa7 \xe2\x94\x86  parent:      26:7f25b6c2f0b9 (esc)
  \xe2\x94\x82   \xe2\x94\x86  user:        test (esc)
  \xe2\x94\x82   \xe2\x94\x86  date:        Thu Jan 01 00:00:28 1970 +0000 (esc)
  \xe2\x94\x82   \xe2\x94\x86  summary:     (28) merge zero known (esc)
  \xe2\x94\x82  \xe2\x95\xb1 (esc)
  \xe2\x97\x8b \xe2\x94\x86  changeset:   26:7f25b6c2f0b9 (esc)
  \xe2\x94\x82\xe2\x95\xb2 \xe2\x95\xb2   parent:      18:1aa84d96232a (esc)
  \xe2\x94\x82 \xe2\x94\x82 \xe2\x94\x86  parent:      25:91da8ed57247 (esc)
  \xe2\x94\x82 \xe2\x94\x82 \xe2\x94\x86  user:        test (esc)
  \xe2\x94\x82 \xe2\x94\x82 \xe2\x94\x86  date:        Thu Jan 01 00:00:26 1970 +0000 (esc)
  \xe2\x94\x82 \xe2\x94\x82 \xe2\x94\x86  summary:     (26) merge one known; far right (esc)
  \xe2\x94\x82 \xe2\x94\x82 \xe2\x94\x86 (esc)
  \xe2\x94\x82 \xe2\x97\x8b \xe2\x94\x86  changeset:   25:91da8ed57247 (esc)
  \xe2\x94\x82 \xe2\x94\x82\xe2\x95\xb2\xe2\x94\x86  parent:      21:d42a756af44d (esc)
  \xe2\x94\x82 \xe2\x94\x82 \xe2\x94\x86  parent:      24:a9c19a3d96b7 (esc)
  \xe2\x94\x82 \xe2\x94\x82 \xe2\x94\x86  user:        test (esc)
  \xe2\x94\x82 \xe2\x94\x82 \xe2\x94\x86  date:        Thu Jan 01 00:00:25 1970 +0000 (esc)
  \xe2\x94\x82 \xe2\x94\x82 \xe2\x94\x86  summary:     (25) merge one known; far left (esc)
  \xe2\x94\x82 \xe2\x94\x82 \xe2\x94\x86 (esc)
  \xe2\x94\x82 \xe2\x97\x8b \xe2\x94\x86  changeset:   24:a9c19a3d96b7 (esc)
  \xe2\x94\x82 \xe2\x94\x82\xe2\x95\xb2 \xe2\x95\xb2   parent:      0:e6eb3150255d (esc)
  \xe2\x94\x82 \xe2\x94\x82 \xe2\x95\xa7 \xe2\x94\x86  parent:      23:a01cddf0766d (esc)
  \xe2\x94\x82 \xe2\x94\x82   \xe2\x94\x86  user:        test (esc)
  \xe2\x94\x82 \xe2\x94\x82   \xe2\x94\x86  date:        Thu Jan 01 00:00:24 1970 +0000 (esc)
  \xe2\x94\x82 \xe2\x94\x82   \xe2\x94\x86  summary:     (24) merge one known; immediate right (esc)
  \xe2\x94\x82 \xe2\x94\x82  \xe2\x95\xb1 (esc)
  \xe2\x94\x82 \xe2\x97\x8b \xe2\x94\x86  changeset:   23:a01cddf0766d (esc)
  \xe2\x94\x82 \xe2\x94\x82\xe2\x95\xb2 \xe2\x95\xb2   parent:      1:6db2ef61d156 (esc)
  \xe2\x94\x82 \xe2\x94\x82 \xe2\x95\xa7 \xe2\x94\x86  parent:      22:e0d9cccacb5d (esc)
  \xe2\x94\x82 \xe2\x94\x82   \xe2\x94\x86  user:        test (esc)
  \xe2\x94\x82 \xe2\x94\x82   \xe2\x94\x86  date:        Thu Jan 01 00:00:23 1970 +0000 (esc)
  \xe2\x94\x82 \xe2\x94\x82   \xe2\x94\x86  summary:     (23) merge one known; immediate left (esc)
  \xe2\x94\x82 \xe2\x94\x82  \xe2\x95\xb1 (esc)
  \xe2\x94\x82 \xe2\x97\x8b \xe2\x94\x86  changeset:   22:e0d9cccacb5d (esc)
  \xe2\x94\x82\xe2\x95\xb1\xe2\x94\x86\xe2\x95\xb1   parent:      18:1aa84d96232a (esc)
  \xe2\x94\x82 \xe2\x94\x86    parent:      21:d42a756af44d (esc)
  \xe2\x94\x82 \xe2\x94\x86    user:        test (esc)
  \xe2\x94\x82 \xe2\x94\x86    date:        Thu Jan 01 00:00:22 1970 +0000 (esc)
  \xe2\x94\x82 \xe2\x94\x86    summary:     (22) merge two known; one far left, one far right (esc)
  \xe2\x94\x82 \xe2\x94\x86 (esc)
  \xe2\x94\x82 \xe2\x97\x8b  changeset:   21:d42a756af44d (esc)
  \xe2\x94\x82 \xe2\x94\x82\xe2\x95\xb2   parent:      19:31ddc2c1573b (esc)
  \xe2\x94\x82 \xe2\x94\x82 \xe2\x94\x82  parent:      20:d30ed6450e32 (esc)
  \xe2\x94\x82 \xe2\x94\x82 \xe2\x94\x82  user:        test (esc)
  \xe2\x94\x82 \xe2\x94\x82 \xe2\x94\x82  date:        Thu Jan 01 00:00:21 1970 +0000 (esc)
  \xe2\x94\x82 \xe2\x94\x82 \xe2\x94\x82  summary:     (21) expand (esc)
  \xe2\x94\x82 \xe2\x94\x82 \xe2\x94\x82 (esc)
  \xe2\x94\x9c\xe2\x94\x80\xe2\x94\x80\xe2\x94\x80\xe2\x97\x8b  changeset:   20:d30ed6450e32 (esc)
  \xe2\x94\x82 \xe2\x94\x82 \xe2\x94\x82  parent:      0:e6eb3150255d (esc)
  \xe2\x94\x82 \xe2\x94\x82 \xe2\x95\xa7  parent:      18:1aa84d96232a (esc)
  \xe2\x94\x82 \xe2\x94\x82    user:        test (esc)
  \xe2\x94\x82 \xe2\x94\x82    date:        Thu Jan 01 00:00:20 1970 +0000 (esc)
  \xe2\x94\x82 \xe2\x94\x82    summary:     (20) merge two known; two far right (esc)
  \xe2\x94\x82 \xe2\x94\x82 (esc)
  \xe2\x94\x82 \xe2\x97\x8b  changeset:   19:31ddc2c1573b (esc)
  \xe2\x94\x82 \xe2\x94\x82\xe2\x95\xb2   parent:      15:1dda3f72782d (esc)
  \xe2\x94\x82 \xe2\x94\x82 \xe2\x94\x82  parent:      17:44765d7c06e0 (esc)
  \xe2\x94\x82 \xe2\x94\x82 \xe2\x94\x82  user:        test (esc)
  \xe2\x94\x82 \xe2\x94\x82 \xe2\x94\x82  date:        Thu Jan 01 00:00:19 1970 +0000 (esc)
  \xe2\x94\x82 \xe2\x94\x82 \xe2\x94\x82  summary:     (19) expand (esc)
  \xe2\x94\x82 \xe2\x94\x82 \xe2\x94\x82 (esc)
  \xe2\x97\x8b \xe2\x94\x82 \xe2\x94\x82  changeset:   18:1aa84d96232a (esc)
  \xe2\x94\x82\xe2\x95\xb2\xe2\x94\x82 \xe2\x94\x82  parent:      1:6db2ef61d156 (esc)
  \xe2\x95\xa7 \xe2\x94\x82 \xe2\x94\x82  parent:      15:1dda3f72782d (esc)
    \xe2\x94\x82 \xe2\x94\x82  user:        test (esc)
    \xe2\x94\x82 \xe2\x94\x82  date:        Thu Jan 01 00:00:18 1970 +0000 (esc)
    \xe2\x94\x82 \xe2\x94\x82  summary:     (18) merge two known; two far left (esc)
   \xe2\x95\xb1 \xe2\x95\xb1 (esc)
  \xe2\x94\x82 \xe2\x97\x8b  changeset:   17:44765d7c06e0 (esc)
  \xe2\x94\x82 \xe2\x94\x82\xe2\x95\xb2   parent:      12:86b91144a6e9 (esc)
  \xe2\x94\x82 \xe2\x94\x82 \xe2\x94\x82  parent:      16:3677d192927d (esc)
  \xe2\x94\x82 \xe2\x94\x82 \xe2\x94\x82  user:        test (esc)
  \xe2\x94\x82 \xe2\x94\x82 \xe2\x94\x82  date:        Thu Jan 01 00:00:17 1970 +0000 (esc)
  \xe2\x94\x82 \xe2\x94\x82 \xe2\x94\x82  summary:     (17) expand (esc)
  \xe2\x94\x82 \xe2\x94\x82 \xe2\x94\x82 (esc)
  \xe2\x94\x82 \xe2\x94\x82 \xe2\x97\x8b  changeset:   16:3677d192927d (esc)
  \xe2\x94\x82 \xe2\x94\x82 \xe2\x94\x82\xe2\x95\xb2   parent:      0:e6eb3150255d (esc)
  \xe2\x94\x82 \xe2\x94\x82 \xe2\x95\xa7 \xe2\x95\xa7  parent:      1:6db2ef61d156 (esc)
  \xe2\x94\x82 \xe2\x94\x82      user:        test (esc)
  \xe2\x94\x82 \xe2\x94\x82      date:        Thu Jan 01 00:00:16 1970 +0000 (esc)
  \xe2\x94\x82 \xe2\x94\x82      summary:     (16) merge two known; one immediate right, one near right (esc)
  \xe2\x94\x82 \xe2\x94\x82 (esc)
  \xe2\x97\x8b \xe2\x94\x82  changeset:   15:1dda3f72782d (esc)
  \xe2\x94\x82\xe2\x95\xb2 \xe2\x95\xb2   parent:      13:22d8966a97e3 (esc)
  \xe2\x94\x82 \xe2\x94\x82 \xe2\x94\x82  parent:      14:8eac370358ef (esc)
  \xe2\x94\x82 \xe2\x94\x82 \xe2\x94\x82  user:        test (esc)
  \xe2\x94\x82 \xe2\x94\x82 \xe2\x94\x82  date:        Thu Jan 01 00:00:15 1970 +0000 (esc)
  \xe2\x94\x82 \xe2\x94\x82 \xe2\x94\x82  summary:     (15) expand (esc)
  \xe2\x94\x82 \xe2\x94\x82 \xe2\x94\x82 (esc)
  \xe2\x94\x82 \xe2\x97\x8b \xe2\x94\x82  changeset:   14:8eac370358ef (esc)
  \xe2\x94\x82 \xe2\x94\x82\xe2\x95\xb2\xe2\x94\x82  parent:      0:e6eb3150255d (esc)
  \xe2\x94\x82 \xe2\x95\xa7 \xe2\x94\x82  parent:      12:86b91144a6e9 (esc)
  \xe2\x94\x82   \xe2\x94\x82  user:        test (esc)
  \xe2\x94\x82   \xe2\x94\x82  date:        Thu Jan 01 00:00:14 1970 +0000 (esc)
  \xe2\x94\x82   \xe2\x94\x82  summary:     (14) merge two known; one immediate right, one far right (esc)
  \xe2\x94\x82  \xe2\x95\xb1 (esc)
  \xe2\x97\x8b \xe2\x94\x82  changeset:   13:22d8966a97e3 (esc)
  \xe2\x94\x82\xe2\x95\xb2 \xe2\x95\xb2   parent:      9:7010c0af0a35 (esc)
  \xe2\x94\x82 \xe2\x94\x82 \xe2\x94\x82  parent:      11:832d76e6bdf2 (esc)
  \xe2\x94\x82 \xe2\x94\x82 \xe2\x94\x82  user:        test (esc)
  \xe2\x94\x82 \xe2\x94\x82 \xe2\x94\x82  date:        Thu Jan 01 00:00:13 1970 +0000 (esc)
  \xe2\x94\x82 \xe2\x94\x82 \xe2\x94\x82  summary:     (13) expand (esc)
  \xe2\x94\x82 \xe2\x94\x82 \xe2\x94\x82 (esc)
  \xe2\x94\x9c\xe2\x94\x80\xe2\x94\x80\xe2\x94\x80\xe2\x97\x8b  changeset:   12:86b91144a6e9 (esc)
  \xe2\x94\x82 \xe2\x94\x82 \xe2\x94\x82  parent:      1:6db2ef61d156 (esc)
  \xe2\x94\x82 \xe2\x94\x82 \xe2\x95\xa7  parent:      9:7010c0af0a35 (esc)
  \xe2\x94\x82 \xe2\x94\x82    user:        test (esc)
  \xe2\x94\x82 \xe2\x94\x82    date:        Thu Jan 01 00:00:12 1970 +0000 (esc)
  \xe2\x94\x82 \xe2\x94\x82    summary:     (12) merge two known; one immediate right, one far left (esc)
  \xe2\x94\x82 \xe2\x94\x82 (esc)
  \xe2\x94\x82 \xe2\x97\x8b  changeset:   11:832d76e6bdf2 (esc)
  \xe2\x94\x82 \xe2\x94\x82\xe2\x95\xb2   parent:      6:b105a072e251 (esc)
  \xe2\x94\x82 \xe2\x94\x82 \xe2\x94\x82  parent:      10:74c64d036d72 (esc)
  \xe2\x94\x82 \xe2\x94\x82 \xe2\x94\x82  user:        test (esc)
  \xe2\x94\x82 \xe2\x94\x82 \xe2\x94\x82  date:        Thu Jan 01 00:00:11 1970 +0000 (esc)
  \xe2\x94\x82 \xe2\x94\x82 \xe2\x94\x82  summary:     (11) expand (esc)
  \xe2\x94\x82 \xe2\x94\x82 \xe2\x94\x82 (esc)
  \xe2\x94\x82 \xe2\x94\x82 \xe2\x97\x8b  changeset:   10:74c64d036d72 (esc)
  \xe2\x94\x82 \xe2\x94\x82\xe2\x95\xb1\xe2\x94\x82  parent:      0:e6eb3150255d (esc)
  \xe2\x94\x82 \xe2\x94\x82 \xe2\x95\xa7  parent:      6:b105a072e251 (esc)
  \xe2\x94\x82 \xe2\x94\x82    user:        test (esc)
  \xe2\x94\x82 \xe2\x94\x82    date:        Thu Jan 01 00:00:10 1970 +0000 (esc)
  \xe2\x94\x82 \xe2\x94\x82    summary:     (10) merge two known; one immediate left, one near right (esc)
  \xe2\x94\x82 \xe2\x94\x82 (esc)
  \xe2\x97\x8b \xe2\x94\x82  changeset:   9:7010c0af0a35 (esc)
  \xe2\x94\x82\xe2\x95\xb2 \xe2\x95\xb2   parent:      7:b632bb1b1224 (esc)
  \xe2\x94\x82 \xe2\x94\x82 \xe2\x94\x82  parent:      8:7a0b11f71937 (esc)
  \xe2\x94\x82 \xe2\x94\x82 \xe2\x94\x82  user:        test (esc)
  \xe2\x94\x82 \xe2\x94\x82 \xe2\x94\x82  date:        Thu Jan 01 00:00:09 1970 +0000 (esc)
  \xe2\x94\x82 \xe2\x94\x82 \xe2\x94\x82  summary:     (9) expand (esc)
  \xe2\x94\x82 \xe2\x94\x82 \xe2\x94\x82 (esc)
  \xe2\x94\x82 \xe2\x97\x8b \xe2\x94\x82  changeset:   8:7a0b11f71937 (esc)
  \xe2\x94\x82\xe2\x95\xb1\xe2\x94\x82 \xe2\x94\x82  parent:      0:e6eb3150255d (esc)
  \xe2\x94\x82 \xe2\x95\xa7 \xe2\x94\x82  parent:      7:b632bb1b1224 (esc)
  \xe2\x94\x82   \xe2\x94\x82  user:        test (esc)
  \xe2\x94\x82   \xe2\x94\x82  date:        Thu Jan 01 00:00:08 1970 +0000 (esc)
  \xe2\x94\x82   \xe2\x94\x82  summary:     (8) merge two known; one immediate left, one far right (esc)
  \xe2\x94\x82  \xe2\x95\xb1 (esc)
  \xe2\x97\x8b \xe2\x94\x82  changeset:   7:b632bb1b1224 (esc)
  \xe2\x94\x82\xe2\x95\xb2 \xe2\x95\xb2   parent:      2:3d9a33b8d1e1 (esc)
  \xe2\x94\x82 \xe2\x95\xa7 \xe2\x94\x82  parent:      5:4409d547b708 (esc)
  \xe2\x94\x82   \xe2\x94\x82  user:        test (esc)
  \xe2\x94\x82   \xe2\x94\x82  date:        Thu Jan 01 00:00:07 1970 +0000 (esc)
  \xe2\x94\x82   \xe2\x94\x82  summary:     (7) expand (esc)
  \xe2\x94\x82  \xe2\x95\xb1 (esc)
  \xe2\x94\x82 \xe2\x97\x8b  changeset:   6:b105a072e251 (esc)
  \xe2\x94\x82\xe2\x95\xb1\xe2\x94\x82  parent:      2:3d9a33b8d1e1 (esc)
  \xe2\x94\x82 \xe2\x95\xa7  parent:      5:4409d547b708 (esc)
  \xe2\x94\x82    user:        test (esc)
  \xe2\x94\x82    date:        Thu Jan 01 00:00:06 1970 +0000 (esc)
  \xe2\x94\x82    summary:     (6) merge two known; one immediate left, one far left (esc)
  \xe2\x94\x82 (esc)
  \xe2\x97\x8b  changeset:   5:4409d547b708 (esc)
  \xe2\x94\x82\xe2\x95\xb2   parent:      3:27eef8ed80b4 (esc)
  \xe2\x94\x82 \xe2\x95\xa7  parent:      4:26a8bac39d9f (esc)
  \xe2\x94\x82    user:        test (esc)
  \xe2\x94\x82    date:        Thu Jan 01 00:00:05 1970 +0000 (esc)
  \xe2\x94\x82    summary:     (5) expand (esc)
  \xe2\x94\x82 (esc)
  \xe2\x97\x8b  changeset:   4:26a8bac39d9f (esc)
  \xe2\x94\x82\xe2\x95\xb2   parent:      1:6db2ef61d156 (esc)
  \xe2\x95\xa7 \xe2\x95\xa7  parent:      3:27eef8ed80b4 (esc)
       user:        test
       date:        Thu Jan 01 00:00:04 1970 +0000
       summary:     (4) merge two known; one immediate left, one immediate right
  

Empty revision range - display nothing:
  $ hg log -G -r 1..0

  $ cd ..

#if no-outer-repo

From outer space:
  $ hg log -G -l1 repo
  \xe2\x97\x8d  changeset:   34:fea3ac5810e0 (esc)
  \xe2\x94\x82  tag:         tip (esc)
  \xe2\x95\xa7  parent:      32:d06dffa21a31 (esc)
     user:        test
     date:        Thu Jan 01 00:00:34 1970 +0000
     summary:     (34) head
  
  $ hg log -G -l1 repo/a
  \xe2\x97\x8d  changeset:   34:fea3ac5810e0 (esc)
  \xe2\x94\x82  tag:         tip (esc)
  \xe2\x95\xa7  parent:      32:d06dffa21a31 (esc)
     user:        test
     date:        Thu Jan 01 00:00:34 1970 +0000
     summary:     (34) head
  
  $ hg log -G -l1 repo/missing

#endif

File log with revs != cset revs:
  $ hg init flog
  $ cd flog
  $ echo one >one
  $ hg add one
  $ hg commit -mone
  $ echo two >two
  $ hg add two
  $ hg commit -mtwo
  $ echo more >two
  $ hg commit -mmore
  $ hg log -G two
  \xe2\x97\x8d  changeset:   2:12c28321755b (esc)
  \xe2\x94\x82  tag:         tip (esc)
  \xe2\x94\x82  user:        test (esc)
  \xe2\x94\x82  date:        Thu Jan 01 00:00:00 1970 +0000 (esc)
  \xe2\x94\x82  summary:     more (esc)
  \xe2\x94\x82 (esc)
  \xe2\x97\x8b  changeset:   1:5ac72c0599bf (esc)
  \xe2\x94\x82  user:        test (esc)
  \xe2\x95\xa7  date:        Thu Jan 01 00:00:00 1970 +0000 (esc)
     summary:     two
  

Issue1896: File log with explicit style
  $ hg log -G --style=default one
  \xe2\x97\x8b  changeset:   0:3d578b4a1f53 (esc)
     user:        test
     date:        Thu Jan 01 00:00:00 1970 +0000
     summary:     one
  
Issue2395: glog --style header and footer
  $ hg log -G --style=xml one
  <?xml version="1.0"?>
  <log>
  \xe2\x97\x8b  <logentry revision="0" node="3d578b4a1f537d5fcf7301bfa9c0b97adfaa6fb1"> (esc)
     <author email="test">test</author>
     <date>1970-01-01T00:00:00+00:00</date>
     <msg xml:space="preserve">one</msg>
     </logentry>
  </log>

  $ cd ..

Incoming and outgoing:

  $ hg clone -U -r31 repo repo2
  adding changesets
  adding manifests
  adding file changes
  added 31 changesets with 31 changes to 1 files
  new changesets e6eb3150255d:621d83e11f67
  $ cd repo2

  $ hg incoming --graph ../repo
  comparing with ../repo
  searching for changes
  \xe2\x97\x8b  changeset:   34:fea3ac5810e0 (esc)
  \xe2\x94\x82  tag:         tip (esc)
  \xe2\x94\x82  parent:      32:d06dffa21a31 (esc)
  \xe2\x94\x82  user:        test (esc)
  \xe2\x94\x82  date:        Thu Jan 01 00:00:34 1970 +0000 (esc)
  \xe2\x94\x82  summary:     (34) head (esc)
  \xe2\x94\x82 (esc)
  \xe2\x94\x82 \xe2\x97\x8b  changeset:   33:68608f5145f9 (esc)
  \xe2\x94\x82    parent:      18:1aa84d96232a (esc)
  \xe2\x94\x82    user:        test (esc)
  \xe2\x94\x82    date:        Thu Jan 01 00:00:33 1970 +0000 (esc)
  \xe2\x94\x82    summary:     (33) head (esc)
  \xe2\x94\x82 (esc)
  \xe2\x97\x8b  changeset:   32:d06dffa21a31 (esc)
  \xe2\x94\x82  parent:      27:886ed638191b (esc)
  \xe2\x94\x82  parent:      31:621d83e11f67 (esc)
  \xe2\x94\x82  user:        test (esc)
  \xe2\x94\x82  date:        Thu Jan 01 00:00:32 1970 +0000 (esc)
  \xe2\x94\x82  summary:     (32) expand (esc)
  \xe2\x94\x82 (esc)
  \xe2\x97\x8b  changeset:   27:886ed638191b (esc)
     parent:      21:d42a756af44d
     user:        test
     date:        Thu Jan 01 00:00:27 1970 +0000
     summary:     (27) collapse
  
  $ cd ..

  $ hg -R repo outgoing --graph repo2
  comparing with repo2
  searching for changes
  \xe2\x97\x8d  changeset:   34:fea3ac5810e0 (esc)
  \xe2\x94\x82  tag:         tip (esc)
  \xe2\x94\x82  parent:      32:d06dffa21a31 (esc)
  \xe2\x94\x82  user:        test (esc)
  \xe2\x94\x82  date:        Thu Jan 01 00:00:34 1970 +0000 (esc)
  \xe2\x94\x82  summary:     (34) head (esc)
  \xe2\x94\x82 (esc)
  \xe2\x94\x82 \xe2\x97\x8b  changeset:   33:68608f5145f9 (esc)
  \xe2\x94\x82    parent:      18:1aa84d96232a (esc)
  \xe2\x94\x82    user:        test (esc)
  \xe2\x94\x82    date:        Thu Jan 01 00:00:33 1970 +0000 (esc)
  \xe2\x94\x82    summary:     (33) head (esc)
  \xe2\x94\x82 (esc)
  \xe2\x97\x8b  changeset:   32:d06dffa21a31 (esc)
  \xe2\x94\x82  parent:      27:886ed638191b (esc)
  \xe2\x94\x82  parent:      31:621d83e11f67 (esc)
  \xe2\x94\x82  user:        test (esc)
  \xe2\x94\x82  date:        Thu Jan 01 00:00:32 1970 +0000 (esc)
  \xe2\x94\x82  summary:     (32) expand (esc)
  \xe2\x94\x82 (esc)
  \xe2\x97\x8b  changeset:   27:886ed638191b (esc)
     parent:      21:d42a756af44d
     user:        test
     date:        Thu Jan 01 00:00:27 1970 +0000
     summary:     (27) collapse
  

File + limit with revs != cset revs:
  $ cd repo
  $ touch b
  $ hg ci -Aqm0
  $ hg log -G -l2 a
  \xe2\x97\x8b  changeset:   34:fea3ac5810e0 (esc)
  \xe2\x94\x82  parent:      32:d06dffa21a31 (esc)
  \xe2\x95\xa7  user:        test (esc)
     date:        Thu Jan 01 00:00:34 1970 +0000
     summary:     (34) head
  
  \xe2\x97\x8b  changeset:   33:68608f5145f9 (esc)
  \xe2\x94\x82  parent:      18:1aa84d96232a (esc)
  \xe2\x95\xa7  user:        test (esc)
     date:        Thu Jan 01 00:00:33 1970 +0000
     summary:     (33) head
  

File + limit + -ra:b, (b - a) < limit:
  $ hg log -G -l3000 -r32:tip a
  \xe2\x97\x8b  changeset:   34:fea3ac5810e0 (esc)
  \xe2\x94\x82  parent:      32:d06dffa21a31 (esc)
  \xe2\x94\x82  user:        test (esc)
  \xe2\x94\x82  date:        Thu Jan 01 00:00:34 1970 +0000 (esc)
  \xe2\x94\x82  summary:     (34) head (esc)
  \xe2\x94\x82 (esc)
  \xe2\x94\x82 \xe2\x97\x8b  changeset:   33:68608f5145f9 (esc)
  \xe2\x94\x82 \xe2\x94\x82  parent:      18:1aa84d96232a (esc)
  \xe2\x94\x82 \xe2\x95\xa7  user:        test (esc)
  \xe2\x94\x82    date:        Thu Jan 01 00:00:33 1970 +0000 (esc)
  \xe2\x94\x82    summary:     (33) head (esc)
  \xe2\x94\x82 (esc)
  \xe2\x97\x8b  changeset:   32:d06dffa21a31 (esc)
  \xe2\x94\x82\xe2\x95\xb2   parent:      27:886ed638191b (esc)
  \xe2\x95\xa7 \xe2\x95\xa7  parent:      31:621d83e11f67 (esc)
       user:        test
       date:        Thu Jan 01 00:00:32 1970 +0000
       summary:     (32) expand
  

Point out a common and an uncommon unshown parent

  $ hg log -G -r 'rev(8) or rev(9)'
  \xe2\x97\x8b  changeset:   9:7010c0af0a35 (esc)
  \xe2\x94\x82\xe2\x95\xb2   parent:      7:b632bb1b1224 (esc)
  \xe2\x94\x82 \xe2\x95\xa7  parent:      8:7a0b11f71937 (esc)
  \xe2\x94\x82    user:        test (esc)
  \xe2\x94\x82    date:        Thu Jan 01 00:00:09 1970 +0000 (esc)
  \xe2\x94\x82    summary:     (9) expand (esc)
  \xe2\x94\x82 (esc)
  \xe2\x97\x8b  changeset:   8:7a0b11f71937 (esc)
  \xe2\x94\x82\xe2\x95\xb2   parent:      0:e6eb3150255d (esc)
  \xe2\x95\xa7 \xe2\x95\xa7  parent:      7:b632bb1b1224 (esc)
       user:        test
       date:        Thu Jan 01 00:00:08 1970 +0000
       summary:     (8) merge two known; one immediate left, one far right
  

File + limit + -ra:b, b < tip:

  $ hg log -G -l1 -r32:34 a
  \xe2\x97\x8b  changeset:   34:fea3ac5810e0 (esc)
  \xe2\x94\x82  parent:      32:d06dffa21a31 (esc)
  \xe2\x95\xa7  user:        test (esc)
     date:        Thu Jan 01 00:00:34 1970 +0000
     summary:     (34) head
  

file(File) + limit + -ra:b, b < tip:

  $ hg log -G -l1 -r32:34 -r 'file("a")'
  \xe2\x97\x8b  changeset:   34:fea3ac5810e0 (esc)
  \xe2\x94\x82  parent:      32:d06dffa21a31 (esc)
  \xe2\x95\xa7  user:        test (esc)
     date:        Thu Jan 01 00:00:34 1970 +0000
     summary:     (34) head
  

limit(file(File) and a::b), b < tip:

  $ hg log -G -r 'limit(file("a") and 32::34, 1)'
  \xe2\x97\x8b  changeset:   32:d06dffa21a31 (esc)
  \xe2\x94\x82\xe2\x95\xb2   parent:      27:886ed638191b (esc)
  \xe2\x95\xa7 \xe2\x95\xa7  parent:      31:621d83e11f67 (esc)
       user:        test
       date:        Thu Jan 01 00:00:32 1970 +0000
       summary:     (32) expand
  

File + limit + -ra:b, b < tip:

  $ hg log -G -r 'limit(file("a") and 34::32, 1)'

File + limit + -ra:b, b < tip, (b - a) < limit:

  $ hg log -G -l10 -r33:34 a
  \xe2\x97\x8b  changeset:   34:fea3ac5810e0 (esc)
  \xe2\x94\x82  parent:      32:d06dffa21a31 (esc)
  \xe2\x95\xa7  user:        test (esc)
     date:        Thu Jan 01 00:00:34 1970 +0000
     summary:     (34) head
  
  \xe2\x97\x8b  changeset:   33:68608f5145f9 (esc)
  \xe2\x94\x82  parent:      18:1aa84d96232a (esc)
  \xe2\x95\xa7  user:        test (esc)
     date:        Thu Jan 01 00:00:33 1970 +0000
     summary:     (33) head
  

Do not crash or produce strange graphs if history is buggy

  $ hg branch branch
  marked working directory as branch branch
  (branches are permanent and global, did you want a bookmark?)
  $ commit 36 "buggy merge: identical parents" 35 35
  $ hg log -G -l5
  \xe2\x97\x8d  changeset:   36:08a19a744424 (esc)
  \xe2\x94\x82  branch:      branch (esc)
  \xe2\x94\x82  tag:         tip (esc)
  \xe2\x94\x82  parent:      35:9159c3644c5e (esc)
  \xe2\x94\x82  parent:      35:9159c3644c5e (esc)
  \xe2\x94\x82  user:        test (esc)
  \xe2\x94\x82  date:        Thu Jan 01 00:00:36 1970 +0000 (esc)
  \xe2\x94\x82  summary:     (36) buggy merge: identical parents (esc)
  \xe2\x94\x82 (esc)
  \xe2\x97\x8b  changeset:   35:9159c3644c5e (esc)
  \xe2\x94\x82  user:        test (esc)
  \xe2\x94\x82  date:        Thu Jan 01 00:00:00 1970 +0000 (esc)
  \xe2\x94\x82  summary:     0 (esc)
  \xe2\x94\x82 (esc)
  \xe2\x97\x8b  changeset:   34:fea3ac5810e0 (esc)
  \xe2\x94\x82  parent:      32:d06dffa21a31 (esc)
  \xe2\x94\x82  user:        test (esc)
  \xe2\x94\x82  date:        Thu Jan 01 00:00:34 1970 +0000 (esc)
  \xe2\x94\x82  summary:     (34) head (esc)
  \xe2\x94\x82 (esc)
  \xe2\x94\x82 \xe2\x97\x8b  changeset:   33:68608f5145f9 (esc)
  \xe2\x94\x82 \xe2\x94\x82  parent:      18:1aa84d96232a (esc)
  \xe2\x94\x82 \xe2\x95\xa7  user:        test (esc)
  \xe2\x94\x82    date:        Thu Jan 01 00:00:33 1970 +0000 (esc)
  \xe2\x94\x82    summary:     (33) head (esc)
  \xe2\x94\x82 (esc)
  \xe2\x97\x8b  changeset:   32:d06dffa21a31 (esc)
  \xe2\x94\x82\xe2\x95\xb2   parent:      27:886ed638191b (esc)
  \xe2\x95\xa7 \xe2\x95\xa7  parent:      31:621d83e11f67 (esc)
       user:        test
       date:        Thu Jan 01 00:00:32 1970 +0000
       summary:     (32) expand
  

Test log -G options

  $ testlog() {
  >   hg log -G --print-revset "$@"
  >   hg log --template 'nodetag {rev}\n' "$@" | grep nodetag \
  >     | sed 's/.*nodetag/nodetag/' > log.nodes
  >   hg log -G --template 'nodetag {rev}\n' "$@" | grep nodetag \
  >     | sed 's/.*nodetag/nodetag/' > glog.nodes
  >   (cmp log.nodes glog.nodes || diff -u log.nodes glog.nodes) \
  >     | grep '^[-+@ ]' || :
  > }

glog always reorders nodes which explains the difference with log

  $ testlog -r 27 -r 25 -r 21 -r 34 -r 32 -r 31
  ['27', '25', '21', '34', '32', '31']
  []
  <baseset- [21, 25, 27, 31, 32, 34]>
  --- log.nodes	* (glob)
  +++ glog.nodes	* (glob)
  @@ -1,6 +1,6 @@
  -nodetag 27
  -nodetag 25
  -nodetag 21
   nodetag 34
   nodetag 32
   nodetag 31
  +nodetag 27
  +nodetag 25
  +nodetag 21
  $ testlog -u test -u not-a-user
  []
  (or
    (list
      (func
        (symbol 'user')
        (string 'test'))
      (func
        (symbol 'user')
        (string 'not-a-user'))))
  <filteredset
    <spanset- 0:37>,
    <addset
      <filteredset
        <fullreposet+ 0:37>,
        <user 'test'>>,
      <filteredset
        <fullreposet+ 0:37>,
        <user 'not-a-user'>>>>
  $ testlog -b not-a-branch
  abort: unknown revision 'not-a-branch'!
  abort: unknown revision 'not-a-branch'!
  abort: unknown revision 'not-a-branch'!
  $ testlog -b 35 -b 36 --only-branch branch
  []
  (or
    (list
      (func
        (symbol 'branch')
        (string 'default'))
      (or
        (list
          (func
            (symbol 'branch')
            (string 'branch'))
          (func
            (symbol 'branch')
            (string 'branch'))))))
  <filteredset
    <spanset- 0:37>,
    <addset
      <filteredset
        <fullreposet+ 0:37>,
        <branch 'default'>>,
      <addset
        <filteredset
          <fullreposet+ 0:37>,
          <branch 'branch'>>,
        <filteredset
          <fullreposet+ 0:37>,
          <branch 'branch'>>>>>
  $ testlog -k expand -k merge
  []
  (or
    (list
      (func
        (symbol 'keyword')
        (string 'expand'))
      (func
        (symbol 'keyword')
        (string 'merge'))))
  <filteredset
    <spanset- 0:37>,
    <addset
      <filteredset
        <fullreposet+ 0:37>,
        <keyword 'expand'>>,
      <filteredset
        <fullreposet+ 0:37>,
        <keyword 'merge'>>>>
  $ testlog --only-merges
  []
  (func
    (symbol 'merge')
    None)
  <filteredset
    <spanset- 0:37>,
    <merge>>
  $ testlog --no-merges
  []
  (not
    (func
      (symbol 'merge')
      None))
  <filteredset
    <spanset- 0:37>,
    <not
      <filteredset
        <spanset- 0:37>,
        <merge>>>>
  $ testlog --date '2 0 to 4 0'
  []
  (func
    (symbol 'date')
    (string '2 0 to 4 0'))
  <filteredset
    <spanset- 0:37>,
    <date '2 0 to 4 0'>>
  $ hg log -G -d 'brace ) in a date'
  hg: parse error: invalid date: 'brace ) in a date'
  [255]
  $ testlog --prune 31 --prune 32
  []
  (not
    (or
      (list
        (func
          (symbol 'ancestors')
          (string '31'))
        (func
          (symbol 'ancestors')
          (string '32')))))
  <filteredset
    <spanset- 0:37>,
    <not
      <addset
        <filteredset
          <spanset- 0:37>,
          <generatorsetdesc+>>,
        <filteredset
          <spanset- 0:37>,
          <generatorsetdesc+>>>>>

Dedicated repo for --follow and paths filtering. The g is crafted to
have 2 filelog topological heads in a linear changeset graph.

  $ cd ..
  $ hg init follow
  $ cd follow
  $ testlog --follow
  []
  []
  <baseset []>
  $ testlog -rnull
  ['null']
  []
  <baseset [-1]>
  $ echo a > a
  $ echo aa > aa
  $ echo f > f
  $ hg ci -Am "add a" a aa f
  $ hg cp a b
  $ hg cp f g
  $ hg ci -m "copy a b"
  $ mkdir dir
  $ hg mv b dir
  $ echo g >> g
  $ echo f >> f
  $ hg ci -m "mv b dir/b"
  $ hg mv a b
  $ hg cp -f f g
  $ echo a > d
  $ hg add d
  $ hg ci -m "mv a b; add d"
  $ hg mv dir/b e
  $ hg ci -m "mv dir/b e"
  $ hg log -G --template '({rev}) {desc|firstline}\n'
  \xe2\x97\x8d  (4) mv dir/b e (esc)
  \xe2\x94\x82 (esc)
  \xe2\x97\x8b  (3) mv a b; add d (esc)
  \xe2\x94\x82 (esc)
  \xe2\x97\x8b  (2) mv b dir/b (esc)
  \xe2\x94\x82 (esc)
  \xe2\x97\x8b  (1) copy a b (esc)
  \xe2\x94\x82 (esc)
  \xe2\x97\x8b  (0) add a (esc)
  

  $ testlog a
  []
  (func
    (symbol 'filelog')
    (string 'a'))
  <filteredset
    <spanset- 0:5>, set([0])>
  $ testlog a b
  []
  (or
    (list
      (func
        (symbol 'filelog')
        (string 'a'))
      (func
        (symbol 'filelog')
        (string 'b'))))
  <filteredset
    <spanset- 0:5>,
    <addset
      <baseset+ [0]>,
      <baseset+ [1]>>>

Test falling back to slow path for non-existing files

  $ testlog a c
  []
  (func
    (symbol '_matchfiles')
    (list
      (string 'r:')
      (string 'd:relpath')
      (string 'p:a')
      (string 'p:c')))
  <filteredset
    <spanset- 0:5>,
    <matchfiles patterns=['a', 'c'], include=[] exclude=[], default='relpath', rev=2147483647>>

Test multiple --include/--exclude/paths

  $ testlog --include a --include e --exclude b --exclude e a e
  []
  (func
    (symbol '_matchfiles')
    (list
      (string 'r:')
      (string 'd:relpath')
      (string 'p:a')
      (string 'p:e')
      (string 'i:a')
      (string 'i:e')
      (string 'x:b')
      (string 'x:e')))
  <filteredset
    <spanset- 0:5>,
    <matchfiles patterns=['a', 'e'], include=['a', 'e'] exclude=['b', 'e'], default='relpath', rev=2147483647>>

Test glob expansion of pats

  $ expandglobs=`$PYTHON -c "import mercurial.util; \
  >   print(mercurial.util.expandglobs and 'true' or 'false')"`
  $ if [ $expandglobs = "true" ]; then
  >    testlog 'a*';
  > else
  >    testlog a*;
  > fi;
  []
  (func
    (symbol 'filelog')
    (string 'aa'))
  <filteredset
    <spanset- 0:5>, set([0])>

Test --follow on a non-existent directory

  $ testlog -f dir
  abort: cannot follow file not in parent revision: "dir"
  abort: cannot follow file not in parent revision: "dir"
  abort: cannot follow file not in parent revision: "dir"

Test --follow on a directory

  $ hg up -q '.^'
  $ testlog -f dir
  []
  (func
    (symbol '_matchfiles')
    (list
      (string 'r:')
      (string 'd:relpath')
      (string 'p:dir')))
  <filteredset
    <generatorsetdesc->,
    <matchfiles patterns=['dir'], include=[] exclude=[], default='relpath', rev=2147483647>>
  $ hg up -q tip

Test --follow on file not in parent revision

  $ testlog -f a
  abort: cannot follow file not in parent revision: "a"
  abort: cannot follow file not in parent revision: "a"
  abort: cannot follow file not in parent revision: "a"

Test --follow and patterns

  $ testlog -f 'glob:*'
  []
  (func
    (symbol '_matchfiles')
    (list
      (string 'r:')
      (string 'd:relpath')
      (string 'p:glob:*')))
  <filteredset
    <generatorsetdesc->,
    <matchfiles patterns=['glob:*'], include=[] exclude=[], default='relpath', rev=2147483647>>

Test --follow on a single rename

  $ hg up -q 2
  $ testlog -f a
  []
  []
  <generatorsetdesc->

Test --follow and multiple renames

  $ hg up -q tip
  $ testlog -f e
  []
  []
  <generatorsetdesc->

Test --follow and multiple filelog heads

  $ hg up -q 2
  $ testlog -f g
  []
  []
  <generatorsetdesc->
  $ cat log.nodes
  nodetag 2
  nodetag 1
  nodetag 0
  $ hg up -q tip
  $ testlog -f g
  []
  []
  <generatorsetdesc->
  $ cat log.nodes
  nodetag 3
  nodetag 2
  nodetag 0

Test --follow and multiple files

  $ testlog -f g e
  []
  []
  <generatorsetdesc->
  $ cat log.nodes
  nodetag 4
  nodetag 3
  nodetag 2
  nodetag 1
  nodetag 0

Test --follow null parent

  $ hg up -q null
  $ testlog -f
  []
  []
  <baseset []>

Test --follow-first

  $ hg up -q 3
  $ echo ee > e
  $ hg ci -Am "add another e" e
  created new head
  $ hg merge --tool internal:other 4
  0 files updated, 1 files merged, 1 files removed, 0 files unresolved
  (branch merge, don't forget to commit)
  $ echo merge > e
  $ hg ci -m "merge 5 and 4"
  $ testlog --follow-first
  []
  []
  <generatorsetdesc->

Cannot compare with log --follow-first FILE as it never worked

  $ hg log -G --print-revset --follow-first e
  []
  []
  <generatorsetdesc->
  $ hg log -G --follow-first e --template '{rev} {desc|firstline}\n'
  \xe2\x97\x8d  6 merge 5 and 4 (esc)
  \xe2\x94\x82\xe2\x95\xb2 (esc)
  \xe2\x94\x82 \xe2\x95\xa7 (esc)
  \xe2\x97\x8b  5 add another e (esc)
  \xe2\x94\x82 (esc)
  \xe2\x95\xa7 (esc)

Test --copies

  $ hg log -G --copies --template "{rev} {desc|firstline} \
  >   copies: {file_copies_switch}\n"
  \xe2\x97\x8d  6 merge 5 and 4   copies: (esc)
  \xe2\x94\x82\xe2\x95\xb2 (esc)
  \xe2\x94\x82 \xe2\x97\x8b  5 add another e   copies: (esc)
  \xe2\x94\x82 \xe2\x94\x82 (esc)
  \xe2\x97\x8b \xe2\x94\x82  4 mv dir/b e   copies: e (dir/b) (esc)
  \xe2\x94\x82\xe2\x95\xb1 (esc)
  \xe2\x97\x8b  3 mv a b; add d   copies: b (a)g (f) (esc)
  \xe2\x94\x82 (esc)
  \xe2\x97\x8b  2 mv b dir/b   copies: dir/b (b) (esc)
  \xe2\x94\x82 (esc)
  \xe2\x97\x8b  1 copy a b   copies: b (a)g (f) (esc)
  \xe2\x94\x82 (esc)
  \xe2\x97\x8b  0 add a   copies: (esc)
  
Test "set:..." and parent revision

  $ hg up -q 4
  $ testlog "set:copied()"
  []
  (func
    (symbol '_matchfiles')
    (list
      (string 'r:')
      (string 'd:relpath')
      (string 'p:set:copied()')))
  <filteredset
    <spanset- 0:7>,
    <matchfiles patterns=['set:copied()'], include=[] exclude=[], default='relpath', rev=2147483647>>
  $ testlog --include "set:copied()"
  []
  (func
    (symbol '_matchfiles')
    (list
      (string 'r:')
      (string 'd:relpath')
      (string 'i:set:copied()')))
  <filteredset
    <spanset- 0:7>,
    <matchfiles patterns=[], include=['set:copied()'] exclude=[], default='relpath', rev=2147483647>>
  $ testlog -r "sort(file('set:copied()'), -rev)"
  ["sort(file('set:copied()'), -rev)"]
  []
  <filteredset
    <fullreposet- 0:7>,
    <matchfiles patterns=['set:copied()'], include=[] exclude=[], default='glob', rev=None>>

Test --removed

  $ testlog --removed
  []
  []
  <spanset- 0:7>
  $ testlog --removed a
  []
  (func
    (symbol '_matchfiles')
    (list
      (string 'r:')
      (string 'd:relpath')
      (string 'p:a')))
  <filteredset
    <spanset- 0:7>,
    <matchfiles patterns=['a'], include=[] exclude=[], default='relpath', rev=2147483647>>
  $ testlog --removed --follow a
  []
  (func
    (symbol '_matchfiles')
    (list
      (string 'r:')
      (string 'd:relpath')
      (string 'p:a')))
  <filteredset
    <generatorsetdesc->,
    <matchfiles patterns=['a'], include=[] exclude=[], default='relpath', rev=2147483647>>

Test --patch and --stat with --follow and --follow-first

  $ hg up -q 3
  $ hg log -G --git --patch b
  \xe2\x97\x8b  changeset:   1:216d4c92cf98 (esc)
  \xe2\x94\x82  user:        test (esc)
  \xe2\x95\xa7  date:        Thu Jan 01 00:00:00 1970 +0000 (esc)
     summary:     copy a b
  
     diff --git a/a b/b
     copy from a
     copy to b
  

  $ hg log -G --git --stat b
  \xe2\x97\x8b  changeset:   1:216d4c92cf98 (esc)
  \xe2\x94\x82  user:        test (esc)
  \xe2\x95\xa7  date:        Thu Jan 01 00:00:00 1970 +0000 (esc)
     summary:     copy a b
  
      b |  0
      1 files changed, 0 insertions(+), 0 deletions(-)
  

  $ hg log -G --git --patch --follow b
  \xe2\x97\x8b  changeset:   1:216d4c92cf98 (esc)
  \xe2\x94\x82  user:        test (esc)
  \xe2\x94\x82  date:        Thu Jan 01 00:00:00 1970 +0000 (esc)
  \xe2\x94\x82  summary:     copy a b (esc)
  \xe2\x94\x82 (esc)
  \xe2\x94\x82  diff --git a/a b/b (esc)
  \xe2\x94\x82  copy from a (esc)
  \xe2\x94\x82  copy to b (esc)
  \xe2\x94\x82 (esc)
  \xe2\x97\x8b  changeset:   0:f8035bb17114 (esc)
     user:        test
     date:        Thu Jan 01 00:00:00 1970 +0000
     summary:     add a
  
     diff --git a/a b/a
     new file mode 100644
     --- /dev/null
     +++ b/a
     @@ -0,0 +1,1 @@
     +a
  

  $ hg log -G --git --stat --follow b
  \xe2\x97\x8b  changeset:   1:216d4c92cf98 (esc)
  \xe2\x94\x82  user:        test (esc)
  \xe2\x94\x82  date:        Thu Jan 01 00:00:00 1970 +0000 (esc)
  \xe2\x94\x82  summary:     copy a b (esc)
  \xe2\x94\x82 (esc)
  \xe2\x94\x82   b |  0 (esc)
  \xe2\x94\x82   1 files changed, 0 insertions(+), 0 deletions(-) (esc)
  \xe2\x94\x82 (esc)
  \xe2\x97\x8b  changeset:   0:f8035bb17114 (esc)
     user:        test
     date:        Thu Jan 01 00:00:00 1970 +0000
     summary:     add a
  
      a |  1 +
      1 files changed, 1 insertions(+), 0 deletions(-)
  

  $ hg up -q 6
  $ hg log -G --git --patch --follow-first e
  \xe2\x97\x8d  changeset:   6:fc281d8ff18d (esc)
  \xe2\x94\x82\xe2\x95\xb2   tag:         tip (esc)
  \xe2\x94\x82 \xe2\x95\xa7  parent:      5:99b31f1c2782 (esc)
  \xe2\x94\x82    parent:      4:17d952250a9d (esc)
  \xe2\x94\x82    user:        test (esc)
  \xe2\x94\x82    date:        Thu Jan 01 00:00:00 1970 +0000 (esc)
  \xe2\x94\x82    summary:     merge 5 and 4 (esc)
  \xe2\x94\x82 (esc)
  \xe2\x94\x82    diff --git a/e b/e (esc)
  \xe2\x94\x82    --- a/e (esc)
  \xe2\x94\x82    +++ b/e (esc)
  \xe2\x94\x82    @@ -1,1 +1,1 @@ (esc)
  \xe2\x94\x82    -ee (esc)
  \xe2\x94\x82    +merge (esc)
  \xe2\x94\x82 (esc)
  \xe2\x97\x8b  changeset:   5:99b31f1c2782 (esc)
  \xe2\x94\x82  parent:      3:5918b8d165d1 (esc)
  \xe2\x95\xa7  user:        test (esc)
     date:        Thu Jan 01 00:00:00 1970 +0000
     summary:     add another e
  
     diff --git a/e b/e
     new file mode 100644
     --- /dev/null
     +++ b/e
     @@ -0,0 +1,1 @@
     +ee
  

Test old-style --rev

  $ hg tag 'foo-bar'
  $ testlog -r 'foo-bar'
  ['foo-bar']
  []
  <baseset [6]>

Test --follow and forward --rev

  $ hg up -q 6
  $ echo g > g
  $ hg ci -Am 'add g' g
  created new head
  $ hg up -q 2
  $ hg log -G --template "{rev} {desc|firstline}\n"
  \xe2\x97\x8b  8 add g (esc)
  \xe2\x94\x82 (esc)
  \xe2\x94\x82 \xe2\x97\x8b  7 Added tag foo-bar for changeset fc281d8ff18d (esc)
  \xe2\x94\x82\xe2\x95\xb1 (esc)
  \xe2\x97\x8b  6 merge 5 and 4 (esc)
  \xe2\x94\x82\xe2\x95\xb2 (esc)
  \xe2\x94\x82 \xe2\x97\x8b  5 add another e (esc)
  \xe2\x94\x82 \xe2\x94\x82 (esc)
  \xe2\x97\x8b \xe2\x94\x82  4 mv dir/b e (esc)
  \xe2\x94\x82\xe2\x95\xb1 (esc)
  \xe2\x97\x8b  3 mv a b; add d (esc)
  \xe2\x94\x82 (esc)
  \xe2\x97\x8d  2 mv b dir/b (esc)
  \xe2\x94\x82 (esc)
  \xe2\x97\x8b  1 copy a b (esc)
  \xe2\x94\x82 (esc)
  \xe2\x97\x8b  0 add a (esc)
  
  $ hg archive -r 7 archive
  $ grep changessincelatesttag archive/.hg_archival.txt
  changessincelatesttag: 1
  $ rm -r archive

changessincelatesttag with no prior tag
  $ hg archive -r 4 archive
  $ grep changessincelatesttag archive/.hg_archival.txt
  changessincelatesttag: 5

  $ hg export 'all()'
  # HG changeset patch
  # User test
  # Date 0 0
  #      Thu Jan 01 00:00:00 1970 +0000
  # Node ID f8035bb17114da16215af3436ec5222428ace8ee
  # Parent  0000000000000000000000000000000000000000
  add a
  
  diff -r 000000000000 -r f8035bb17114 a
  --- /dev/null	Thu Jan 01 00:00:00 1970 +0000
  +++ b/a	Thu Jan 01 00:00:00 1970 +0000
  @@ -0,0 +1,1 @@
  +a
  diff -r 000000000000 -r f8035bb17114 aa
  --- /dev/null	Thu Jan 01 00:00:00 1970 +0000
  +++ b/aa	Thu Jan 01 00:00:00 1970 +0000
  @@ -0,0 +1,1 @@
  +aa
  diff -r 000000000000 -r f8035bb17114 f
  --- /dev/null	Thu Jan 01 00:00:00 1970 +0000
  +++ b/f	Thu Jan 01 00:00:00 1970 +0000
  @@ -0,0 +1,1 @@
  +f
  # HG changeset patch
  # User test
  # Date 0 0
  #      Thu Jan 01 00:00:00 1970 +0000
  # Node ID 216d4c92cf98ff2b4641d508b76b529f3d424c92
  # Parent  f8035bb17114da16215af3436ec5222428ace8ee
  copy a b
  
  diff -r f8035bb17114 -r 216d4c92cf98 b
  --- /dev/null	Thu Jan 01 00:00:00 1970 +0000
  +++ b/b	Thu Jan 01 00:00:00 1970 +0000
  @@ -0,0 +1,1 @@
  +a
  diff -r f8035bb17114 -r 216d4c92cf98 g
  --- /dev/null	Thu Jan 01 00:00:00 1970 +0000
  +++ b/g	Thu Jan 01 00:00:00 1970 +0000
  @@ -0,0 +1,1 @@
  +f
  # HG changeset patch
  # User test
  # Date 0 0
  #      Thu Jan 01 00:00:00 1970 +0000
  # Node ID bb573313a9e8349099b6ea2b2fb1fc7f424446f3
  # Parent  216d4c92cf98ff2b4641d508b76b529f3d424c92
  mv b dir/b
  
  diff -r 216d4c92cf98 -r bb573313a9e8 b
  --- a/b	Thu Jan 01 00:00:00 1970 +0000
  +++ /dev/null	Thu Jan 01 00:00:00 1970 +0000
  @@ -1,1 +0,0 @@
  -a
  diff -r 216d4c92cf98 -r bb573313a9e8 dir/b
  --- /dev/null	Thu Jan 01 00:00:00 1970 +0000
  +++ b/dir/b	Thu Jan 01 00:00:00 1970 +0000
  @@ -0,0 +1,1 @@
  +a
  diff -r 216d4c92cf98 -r bb573313a9e8 f
  --- a/f	Thu Jan 01 00:00:00 1970 +0000
  +++ b/f	Thu Jan 01 00:00:00 1970 +0000
  @@ -1,1 +1,2 @@
   f
  +f
  diff -r 216d4c92cf98 -r bb573313a9e8 g
  --- a/g	Thu Jan 01 00:00:00 1970 +0000
  +++ b/g	Thu Jan 01 00:00:00 1970 +0000
  @@ -1,1 +1,2 @@
   f
  +g
  # HG changeset patch
  # User test
  # Date 0 0
  #      Thu Jan 01 00:00:00 1970 +0000
  # Node ID 5918b8d165d1364e78a66d02e66caa0133c5d1ed
  # Parent  bb573313a9e8349099b6ea2b2fb1fc7f424446f3
  mv a b; add d
  
  diff -r bb573313a9e8 -r 5918b8d165d1 a
  --- a/a	Thu Jan 01 00:00:00 1970 +0000
  +++ /dev/null	Thu Jan 01 00:00:00 1970 +0000
  @@ -1,1 +0,0 @@
  -a
  diff -r bb573313a9e8 -r 5918b8d165d1 b
  --- /dev/null	Thu Jan 01 00:00:00 1970 +0000
  +++ b/b	Thu Jan 01 00:00:00 1970 +0000
  @@ -0,0 +1,1 @@
  +a
  diff -r bb573313a9e8 -r 5918b8d165d1 d
  --- /dev/null	Thu Jan 01 00:00:00 1970 +0000
  +++ b/d	Thu Jan 01 00:00:00 1970 +0000
  @@ -0,0 +1,1 @@
  +a
  diff -r bb573313a9e8 -r 5918b8d165d1 g
  --- a/g	Thu Jan 01 00:00:00 1970 +0000
  +++ b/g	Thu Jan 01 00:00:00 1970 +0000
  @@ -1,2 +1,2 @@
   f
  -g
  +f
  # HG changeset patch
  # User test
  # Date 0 0
  #      Thu Jan 01 00:00:00 1970 +0000
  # Node ID 17d952250a9d03cc3dc77b199ab60e959b9b0260
  # Parent  5918b8d165d1364e78a66d02e66caa0133c5d1ed
  mv dir/b e
  
  diff -r 5918b8d165d1 -r 17d952250a9d dir/b
  --- a/dir/b	Thu Jan 01 00:00:00 1970 +0000
  +++ /dev/null	Thu Jan 01 00:00:00 1970 +0000
  @@ -1,1 +0,0 @@
  -a
  diff -r 5918b8d165d1 -r 17d952250a9d e
  --- /dev/null	Thu Jan 01 00:00:00 1970 +0000
  +++ b/e	Thu Jan 01 00:00:00 1970 +0000
  @@ -0,0 +1,1 @@
  +a
  # HG changeset patch
  # User test
  # Date 0 0
  #      Thu Jan 01 00:00:00 1970 +0000
  # Node ID 99b31f1c2782e2deb1723cef08930f70fc84b37b
  # Parent  5918b8d165d1364e78a66d02e66caa0133c5d1ed
  add another e
  
  diff -r 5918b8d165d1 -r 99b31f1c2782 e
  --- /dev/null	Thu Jan 01 00:00:00 1970 +0000
  +++ b/e	Thu Jan 01 00:00:00 1970 +0000
  @@ -0,0 +1,1 @@
  +ee
  # HG changeset patch
  # User test
  # Date 0 0
  #      Thu Jan 01 00:00:00 1970 +0000
  # Node ID fc281d8ff18d999ad6497b3d27390bcd695dcc73
  # Parent  99b31f1c2782e2deb1723cef08930f70fc84b37b
  # Parent  17d952250a9d03cc3dc77b199ab60e959b9b0260
  merge 5 and 4
  
  diff -r 99b31f1c2782 -r fc281d8ff18d dir/b
  --- a/dir/b	Thu Jan 01 00:00:00 1970 +0000
  +++ /dev/null	Thu Jan 01 00:00:00 1970 +0000
  @@ -1,1 +0,0 @@
  -a
  diff -r 99b31f1c2782 -r fc281d8ff18d e
  --- a/e	Thu Jan 01 00:00:00 1970 +0000
  +++ b/e	Thu Jan 01 00:00:00 1970 +0000
  @@ -1,1 +1,1 @@
  -ee
  +merge
  # HG changeset patch
  # User test
  # Date 0 0
  #      Thu Jan 01 00:00:00 1970 +0000
  # Node ID 02dbb8e276b8ab7abfd07cab50c901647e75c2dd
  # Parent  fc281d8ff18d999ad6497b3d27390bcd695dcc73
  Added tag foo-bar for changeset fc281d8ff18d
  
  diff -r fc281d8ff18d -r 02dbb8e276b8 .hgtags
  --- /dev/null	Thu Jan 01 00:00:00 1970 +0000
  +++ b/.hgtags	Thu Jan 01 00:00:00 1970 +0000
  @@ -0,0 +1,1 @@
  +fc281d8ff18d999ad6497b3d27390bcd695dcc73 foo-bar
  # HG changeset patch
  # User test
  # Date 0 0
  #      Thu Jan 01 00:00:00 1970 +0000
  # Node ID 24c2e826ddebf80f9dcd60b856bdb8e6715c5449
  # Parent  fc281d8ff18d999ad6497b3d27390bcd695dcc73
  add g
  
  diff -r fc281d8ff18d -r 24c2e826ddeb g
  --- a/g	Thu Jan 01 00:00:00 1970 +0000
  +++ b/g	Thu Jan 01 00:00:00 1970 +0000
  @@ -1,2 +1,1 @@
  -f
  -f
  +g
  $ testlog --follow -r6 -r8 -r5 -r7 -r4
  ['6', '8', '5', '7', '4']
  []
  <generatorsetdesc->

Test --follow-first and forward --rev

  $ testlog --follow-first -r6 -r8 -r5 -r7 -r4
  ['6', '8', '5', '7', '4']
  []
  <generatorsetdesc->

Test --follow and backward --rev

  $ testlog --follow -r6 -r5 -r7 -r8 -r4
  ['6', '5', '7', '8', '4']
  []
  <generatorsetdesc->

Test --follow-first and backward --rev

  $ testlog --follow-first -r6 -r5 -r7 -r8 -r4
  ['6', '5', '7', '8', '4']
  []
  <generatorsetdesc->

Test --follow with --rev of graphlog extension

  $ hg --config extensions.graphlog= glog -qfr1
  \xe2\x97\x8b  1:216d4c92cf98 (esc)
  \xe2\x94\x82 (esc)
  \xe2\x97\x8b  0:f8035bb17114 (esc)
  

Test subdir

  $ hg up -q 3
  $ cd dir
  $ testlog .
  []
  (func
    (symbol '_matchfiles')
    (list
      (string 'r:')
      (string 'd:relpath')
      (string 'p:.')))
  <filteredset
    <spanset- 0:9>,
    <matchfiles patterns=['.'], include=[] exclude=[], default='relpath', rev=2147483647>>
  $ testlog ../b
  []
  (func
    (symbol 'filelog')
    (string '../b'))
  <filteredset
    <spanset- 0:9>, set([1])>
  $ testlog -f ../b
  []
  []
  <generatorsetdesc->
  $ cd ..

Test --hidden
 (enable obsolete)

  $ cat >> $HGRCPATH << EOF
  > [experimental]
  > evolution.createmarkers=True
  > EOF

  $ hg debugobsolete `hg id --debug -i -r 8`
  obsoleted 1 changesets
  $ testlog
  []
  []
  <spanset- 0:9>
  $ testlog --hidden
  []
  []
  <spanset- 0:9>
  $ hg log -G --template '{rev} {desc}\n'
  \xe2\x97\x8b  7 Added tag foo-bar for changeset fc281d8ff18d (esc)
  \xe2\x94\x82 (esc)
  \xe2\x97\x8b  6 merge 5 and 4 (esc)
  \xe2\x94\x82\xe2\x95\xb2 (esc)
  \xe2\x94\x82 \xe2\x97\x8b  5 add another e (esc)
  \xe2\x94\x82 \xe2\x94\x82 (esc)
  \xe2\x97\x8b \xe2\x94\x82  4 mv dir/b e (esc)
  \xe2\x94\x82\xe2\x95\xb1 (esc)
  \xe2\x97\x8d  3 mv a b; add d (esc)
  \xe2\x94\x82 (esc)
  \xe2\x97\x8b  2 mv b dir/b (esc)
  \xe2\x94\x82 (esc)
  \xe2\x97\x8b  1 copy a b (esc)
  \xe2\x94\x82 (esc)
  \xe2\x97\x8b  0 add a (esc)
  

A template without trailing newline should do something sane

  $ hg log -G -r ::2 --template '{rev} {desc}'
  \xe2\x97\x8b  2 mv b dir/b (esc)
  \xe2\x94\x82 (esc)
  \xe2\x97\x8b  1 copy a b (esc)
  \xe2\x94\x82 (esc)
  \xe2\x97\x8b  0 add a (esc)
  

Extra newlines must be preserved

  $ hg log -G -r ::2 --template '\n{rev} {desc}\n\n'
  \xe2\x97\x8b (esc)
  \xe2\x94\x82  2 mv b dir/b (esc)
  \xe2\x94\x82 (esc)
  \xe2\x97\x8b (esc)
  \xe2\x94\x82  1 copy a b (esc)
  \xe2\x94\x82 (esc)
  \xe2\x97\x8b (esc)
     0 add a
  

The almost-empty template should do something sane too ...

  $ hg log -G -r ::2 --template '\n'
  \xe2\x97\x8b (esc)
  \xe2\x94\x82 (esc)
  \xe2\x97\x8b (esc)
  \xe2\x94\x82 (esc)
  \xe2\x97\x8b (esc)
  

issue3772

  $ hg log -G -r :null
  \xe2\x97\x8b  changeset:   0:f8035bb17114 (esc)
  \xe2\x94\x82  user:        test (esc)
  \xe2\x94\x82  date:        Thu Jan 01 00:00:00 1970 +0000 (esc)
  \xe2\x94\x82  summary:     add a (esc)
  \xe2\x94\x82 (esc)
  \xe2\x97\x8b  changeset:   -1:000000000000 (esc)
     user:
     date:        Thu Jan 01 00:00:00 1970 +0000
  
  $ hg log -G -r null:null
  \xe2\x97\x8b  changeset:   -1:000000000000 (esc)
     user:
     date:        Thu Jan 01 00:00:00 1970 +0000
  

should not draw line down to null due to the magic of fullreposet

  $ hg log -G -r 'all()' | tail -6
  \xe2\x94\x82 (esc)
  \xe2\x97\x8b  changeset:   0:f8035bb17114 (esc)
     user:        test
     date:        Thu Jan 01 00:00:00 1970 +0000
     summary:     add a
  

  $ hg log -G -r 'branch(default)' | tail -6
  \xe2\x94\x82 (esc)
  \xe2\x97\x8b  changeset:   0:f8035bb17114 (esc)
     user:        test
     date:        Thu Jan 01 00:00:00 1970 +0000
     summary:     add a
  

working-directory revision

  $ hg log -G -qr '. + wdir()'
  \xe2\x97\x8b  2147483647:ffffffffffff (esc)
  \xe2\x94\x82 (esc)
  \xe2\x97\x8d  3:5918b8d165d1 (esc)
  \xe2\x94\x82 (esc)
  \xe2\x95\xa7 (esc)

node template with changesetprinter:

  $ hg log -Gqr 5:7 --config ui.graphnodetemplate='"{rev}"'
  7  7:02dbb8e276b8
  \xe2\x94\x82 (esc)
  6    6:fc281d8ff18d
  \xe2\x94\x82\xe2\x95\xb2 (esc)
  \xe2\x94\x82 \xe2\x95\xa7 (esc)
  5  5:99b31f1c2782
  \xe2\x94\x82 (esc)
  \xe2\x95\xa7 (esc)

node template with changesettemplater (shared cache variable):

  $ hg log -Gr 5:7 -T '{latesttag % "{rev} {tag}+{distance}"}\n' \
  > --config ui.graphnodetemplate='{ifeq(latesttagdistance, 0, "#", graphnode)}'
  \xe2\x97\x8b  7 foo-bar+1 (esc)
  \xe2\x94\x82 (esc)
  #    6 foo-bar+0
  \xe2\x94\x82\xe2\x95\xb2 (esc)
  \xe2\x94\x82 \xe2\x95\xa7 (esc)
  \xe2\x97\x8b  5 null+5 (esc)
  \xe2\x94\x82 (esc)
  \xe2\x95\xa7 (esc)

label() should just work in node template:

  $ hg log -Gqr 7 --config extensions.color= --color=debug \
  > --config ui.graphnodetemplate='{label("branch.{branch}", rev)}'
  [branch.default\xe2\x94\x827]  [log.node|7:02dbb8e276b8] (esc)
  \xe2\x94\x82 (esc)
  \xe2\x95\xa7 (esc)

  $ cd ..

change graph edge styling

  $ cd repo

Setting HGPLAIN ignores graphmod styling:

  $ HGPLAIN=1 hg log -G -r 'file("a")' -m
  @  changeset:   36:08a19a744424
  |  branch:      branch
  |  tag:         tip
  |  parent:      35:9159c3644c5e
  |  parent:      35:9159c3644c5e
  |  user:        test
  |  date:        Thu Jan 01 00:00:36 1970 +0000
  |  summary:     (36) buggy merge: identical parents
  |
  o    changeset:   32:d06dffa21a31
  |\   parent:      27:886ed638191b
  | |  parent:      31:621d83e11f67
  | |  user:        test
  | |  date:        Thu Jan 01 00:00:32 1970 +0000
  | |  summary:     (32) expand
  | |
  o |  changeset:   31:621d83e11f67
  |\|  parent:      21:d42a756af44d
  | |  parent:      30:6e11cd4b648f
  | |  user:        test
  | |  date:        Thu Jan 01 00:00:31 1970 +0000
  | |  summary:     (31) expand
  | |
  o |    changeset:   30:6e11cd4b648f
  |\ \   parent:      28:44ecd0b9ae99
  | | |  parent:      29:cd9bb2be7593
  | | |  user:        test
  | | |  date:        Thu Jan 01 00:00:30 1970 +0000
  | | |  summary:     (30) expand
  | | |
  o | |    changeset:   28:44ecd0b9ae99
  |\ \ \   parent:      1:6db2ef61d156
  | | | |  parent:      26:7f25b6c2f0b9
  | | | |  user:        test
  | | | |  date:        Thu Jan 01 00:00:28 1970 +0000
  | | | |  summary:     (28) merge zero known
  | | | |
  o | | |    changeset:   26:7f25b6c2f0b9
  |\ \ \ \   parent:      18:1aa84d96232a
  | | | | |  parent:      25:91da8ed57247
  | | | | |  user:        test
  | | | | |  date:        Thu Jan 01 00:00:26 1970 +0000
  | | | | |  summary:     (26) merge one known; far right
  | | | | |
  | o-----+  changeset:   25:91da8ed57247
  | | | | |  parent:      21:d42a756af44d
  | | | | |  parent:      24:a9c19a3d96b7
  | | | | |  user:        test
  | | | | |  date:        Thu Jan 01 00:00:25 1970 +0000
  | | | | |  summary:     (25) merge one known; far left
  | | | | |
  | o | | |    changeset:   24:a9c19a3d96b7
  | |\ \ \ \   parent:      0:e6eb3150255d
  | | | | | |  parent:      23:a01cddf0766d
  | | | | | |  user:        test
  | | | | | |  date:        Thu Jan 01 00:00:24 1970 +0000
  | | | | | |  summary:     (24) merge one known; immediate right
  | | | | | |
  | o---+ | |  changeset:   23:a01cddf0766d
  | | | | | |  parent:      1:6db2ef61d156
  | | | | | |  parent:      22:e0d9cccacb5d
  | | | | | |  user:        test
  | | | | | |  date:        Thu Jan 01 00:00:23 1970 +0000
  | | | | | |  summary:     (23) merge one known; immediate left
  | | | | | |
  | o-------+  changeset:   22:e0d9cccacb5d
  | | | | | |  parent:      18:1aa84d96232a
  |/ / / / /   parent:      21:d42a756af44d
  | | | | |    user:        test
  | | | | |    date:        Thu Jan 01 00:00:22 1970 +0000
  | | | | |    summary:     (22) merge two known; one far left, one far right
  | | | | |
  | | | | o    changeset:   21:d42a756af44d
  | | | | |\   parent:      19:31ddc2c1573b
  | | | | | |  parent:      20:d30ed6450e32
  | | | | | |  user:        test
  | | | | | |  date:        Thu Jan 01 00:00:21 1970 +0000
  | | | | | |  summary:     (21) expand
  | | | | | |
  +-+-------o  changeset:   20:d30ed6450e32
  | | | | |    parent:      0:e6eb3150255d
  | | | | |    parent:      18:1aa84d96232a
  | | | | |    user:        test
  | | | | |    date:        Thu Jan 01 00:00:20 1970 +0000
  | | | | |    summary:     (20) merge two known; two far right
  | | | | |
  | | | | o    changeset:   19:31ddc2c1573b
  | | | | |\   parent:      15:1dda3f72782d
  | | | | | |  parent:      17:44765d7c06e0
  | | | | | |  user:        test
  | | | | | |  date:        Thu Jan 01 00:00:19 1970 +0000
  | | | | | |  summary:     (19) expand
  | | | | | |
  o---+---+ |  changeset:   18:1aa84d96232a
    | | | | |  parent:      1:6db2ef61d156
   / / / / /   parent:      15:1dda3f72782d
  | | | | |    user:        test
  | | | | |    date:        Thu Jan 01 00:00:18 1970 +0000
  | | | | |    summary:     (18) merge two known; two far left
  | | | | |
  | | | | o    changeset:   17:44765d7c06e0
  | | | | |\   parent:      12:86b91144a6e9
  | | | | | |  parent:      16:3677d192927d
  | | | | | |  user:        test
  | | | | | |  date:        Thu Jan 01 00:00:17 1970 +0000
  | | | | | |  summary:     (17) expand
  | | | | | |
  +-+-------o  changeset:   16:3677d192927d
  | | | | |    parent:      0:e6eb3150255d
  | | | | |    parent:      1:6db2ef61d156
  | | | | |    user:        test
  | | | | |    date:        Thu Jan 01 00:00:16 1970 +0000
  | | | | |    summary:     (16) merge two known; one immediate right, one near right
  | | | | |
  | | | o |    changeset:   15:1dda3f72782d
  | | | |\ \   parent:      13:22d8966a97e3
  | | | | | |  parent:      14:8eac370358ef
  | | | | | |  user:        test
  | | | | | |  date:        Thu Jan 01 00:00:15 1970 +0000
  | | | | | |  summary:     (15) expand
  | | | | | |
  +-------o |  changeset:   14:8eac370358ef
  | | | | |/   parent:      0:e6eb3150255d
  | | | | |    parent:      12:86b91144a6e9
  | | | | |    user:        test
  | | | | |    date:        Thu Jan 01 00:00:14 1970 +0000
  | | | | |    summary:     (14) merge two known; one immediate right, one far right
  | | | | |
  | | | o |    changeset:   13:22d8966a97e3
  | | | |\ \   parent:      9:7010c0af0a35
  | | | | | |  parent:      11:832d76e6bdf2
  | | | | | |  user:        test
  | | | | | |  date:        Thu Jan 01 00:00:13 1970 +0000
  | | | | | |  summary:     (13) expand
  | | | | | |
  | +---+---o  changeset:   12:86b91144a6e9
  | | | | |    parent:      1:6db2ef61d156
  | | | | |    parent:      9:7010c0af0a35
  | | | | |    user:        test
  | | | | |    date:        Thu Jan 01 00:00:12 1970 +0000
  | | | | |    summary:     (12) merge two known; one immediate right, one far left
  | | | | |
  | | | | o    changeset:   11:832d76e6bdf2
  | | | | |\   parent:      6:b105a072e251
  | | | | | |  parent:      10:74c64d036d72
  | | | | | |  user:        test
  | | | | | |  date:        Thu Jan 01 00:00:11 1970 +0000
  | | | | | |  summary:     (11) expand
  | | | | | |
  +---------o  changeset:   10:74c64d036d72
  | | | | |/   parent:      0:e6eb3150255d
  | | | | |    parent:      6:b105a072e251
  | | | | |    user:        test
  | | | | |    date:        Thu Jan 01 00:00:10 1970 +0000
  | | | | |    summary:     (10) merge two known; one immediate left, one near right
  | | | | |
  | | | o |    changeset:   9:7010c0af0a35
  | | | |\ \   parent:      7:b632bb1b1224
  | | | | | |  parent:      8:7a0b11f71937
  | | | | | |  user:        test
  | | | | | |  date:        Thu Jan 01 00:00:09 1970 +0000
  | | | | | |  summary:     (9) expand
  | | | | | |
  +-------o |  changeset:   8:7a0b11f71937
  | | | |/ /   parent:      0:e6eb3150255d
  | | | | |    parent:      7:b632bb1b1224
  | | | | |    user:        test
  | | | | |    date:        Thu Jan 01 00:00:08 1970 +0000
  | | | | |    summary:     (8) merge two known; one immediate left, one far right
  | | | | |
  | | | o |    changeset:   7:b632bb1b1224
  | | | |\ \   parent:      2:3d9a33b8d1e1
  | | | | | |  parent:      5:4409d547b708
  | | | | | |  user:        test
  | | | | | |  date:        Thu Jan 01 00:00:07 1970 +0000
  | | | | | |  summary:     (7) expand
  | | | | | |
  | | | +---o  changeset:   6:b105a072e251
  | | | | |/   parent:      2:3d9a33b8d1e1
  | | | | |    parent:      5:4409d547b708
  | | | | |    user:        test
  | | | | |    date:        Thu Jan 01 00:00:06 1970 +0000
  | | | | |    summary:     (6) merge two known; one immediate left, one far left
  | | | | |
  | | | o |    changeset:   5:4409d547b708
  | | | |\ \   parent:      3:27eef8ed80b4
  | | | | | |  parent:      4:26a8bac39d9f
  | | | | | |  user:        test
  | | | | | |  date:        Thu Jan 01 00:00:05 1970 +0000
  | | | | | |  summary:     (5) expand
  | | | | | |
  | +---o | |  changeset:   4:26a8bac39d9f
  | | | |/ /   parent:      1:6db2ef61d156
  | | | | |    parent:      3:27eef8ed80b4
  | | | | |    user:        test
  | | | | |    date:        Thu Jan 01 00:00:04 1970 +0000
  | | | | |    summary:     (4) merge two known; one immediate left, one immediate right
  | | | | |

.. unless HGPLAINEXCEPT=graph is set:

  $ HGPLAIN=1 HGPLAINEXCEPT=graph hg log -G -r 'file("a")' -m
  \xe2\x97\x8d  changeset:   36:08a19a744424 (esc)
  \xe2\x94\x86  branch:      branch (esc)
  \xe2\x94\x86  tag:         tip (esc)
  \xe2\x94\x86  parent:      35:9159c3644c5e (esc)
  \xe2\x94\x86  parent:      35:9159c3644c5e (esc)
  \xe2\x94\x86  user:        test (esc)
  \xe2\x94\x86  date:        Thu Jan 01 00:00:36 1970 +0000 (esc)
  \xe2\x94\x86  summary:     (36) buggy merge: identical parents (esc)
  \xe2\x94\x86 (esc)
  \xe2\x97\x8b  changeset:   32:d06dffa21a31 (esc)
  \xe2\x94\x82\xe2\x95\xb2   parent:      27:886ed638191b (esc)
  \xe2\x94\x82 \xe2\x94\x86  parent:      31:621d83e11f67 (esc)
  \xe2\x94\x82 \xe2\x94\x86  user:        test (esc)
  \xe2\x94\x82 \xe2\x94\x86  date:        Thu Jan 01 00:00:32 1970 +0000 (esc)
  \xe2\x94\x82 \xe2\x94\x86  summary:     (32) expand (esc)
  \xe2\x94\x82 \xe2\x94\x86 (esc)
  \xe2\x97\x8b \xe2\x94\x86  changeset:   31:621d83e11f67 (esc)
  \xe2\x94\x82\xe2\x95\xb2\xe2\x94\x86  parent:      21:d42a756af44d (esc)
  \xe2\x94\x82 \xe2\x94\x86  parent:      30:6e11cd4b648f (esc)
  \xe2\x94\x82 \xe2\x94\x86  user:        test (esc)
  \xe2\x94\x82 \xe2\x94\x86  date:        Thu Jan 01 00:00:31 1970 +0000 (esc)
  \xe2\x94\x82 \xe2\x94\x86  summary:     (31) expand (esc)
  \xe2\x94\x82 \xe2\x94\x86 (esc)
  \xe2\x97\x8b \xe2\x94\x86  changeset:   30:6e11cd4b648f (esc)
  \xe2\x94\x82\xe2\x95\xb2 \xe2\x95\xb2   parent:      28:44ecd0b9ae99 (esc)
  \xe2\x94\x82 \xe2\x95\xa7 \xe2\x94\x86  parent:      29:cd9bb2be7593 (esc)
  \xe2\x94\x82   \xe2\x94\x86  user:        test (esc)
  \xe2\x94\x82   \xe2\x94\x86  date:        Thu Jan 01 00:00:30 1970 +0000 (esc)
  \xe2\x94\x82   \xe2\x94\x86  summary:     (30) expand (esc)
  \xe2\x94\x82  \xe2\x95\xb1 (esc)
  \xe2\x97\x8b \xe2\x94\x86  changeset:   28:44ecd0b9ae99 (esc)
  \xe2\x94\x82\xe2\x95\xb2 \xe2\x95\xb2   parent:      1:6db2ef61d156 (esc)
  \xe2\x94\x82 \xe2\x95\xa7 \xe2\x94\x86  parent:      26:7f25b6c2f0b9 (esc)
  \xe2\x94\x82   \xe2\x94\x86  user:        test (esc)
  \xe2\x94\x82   \xe2\x94\x86  date:        Thu Jan 01 00:00:28 1970 +0000 (esc)
  \xe2\x94\x82   \xe2\x94\x86  summary:     (28) merge zero known (esc)
  \xe2\x94\x82  \xe2\x95\xb1 (esc)
  \xe2\x97\x8b \xe2\x94\x86  changeset:   26:7f25b6c2f0b9 (esc)
  \xe2\x94\x82\xe2\x95\xb2 \xe2\x95\xb2   parent:      18:1aa84d96232a (esc)
  \xe2\x94\x82 \xe2\x94\x82 \xe2\x94\x86  parent:      25:91da8ed57247 (esc)
  \xe2\x94\x82 \xe2\x94\x82 \xe2\x94\x86  user:        test (esc)
  \xe2\x94\x82 \xe2\x94\x82 \xe2\x94\x86  date:        Thu Jan 01 00:00:26 1970 +0000 (esc)
  \xe2\x94\x82 \xe2\x94\x82 \xe2\x94\x86  summary:     (26) merge one known; far right (esc)
  \xe2\x94\x82 \xe2\x94\x82 \xe2\x94\x86 (esc)
  \xe2\x94\x82 \xe2\x97\x8b \xe2\x94\x86  changeset:   25:91da8ed57247 (esc)
  \xe2\x94\x82 \xe2\x94\x82\xe2\x95\xb2\xe2\x94\x86  parent:      21:d42a756af44d (esc)
  \xe2\x94\x82 \xe2\x94\x82 \xe2\x94\x86  parent:      24:a9c19a3d96b7 (esc)
  \xe2\x94\x82 \xe2\x94\x82 \xe2\x94\x86  user:        test (esc)
  \xe2\x94\x82 \xe2\x94\x82 \xe2\x94\x86  date:        Thu Jan 01 00:00:25 1970 +0000 (esc)
  \xe2\x94\x82 \xe2\x94\x82 \xe2\x94\x86  summary:     (25) merge one known; far left (esc)
  \xe2\x94\x82 \xe2\x94\x82 \xe2\x94\x86 (esc)
  \xe2\x94\x82 \xe2\x97\x8b \xe2\x94\x86  changeset:   24:a9c19a3d96b7 (esc)
  \xe2\x94\x82 \xe2\x94\x82\xe2\x95\xb2 \xe2\x95\xb2   parent:      0:e6eb3150255d (esc)
  \xe2\x94\x82 \xe2\x94\x82 \xe2\x95\xa7 \xe2\x94\x86  parent:      23:a01cddf0766d (esc)
  \xe2\x94\x82 \xe2\x94\x82   \xe2\x94\x86  user:        test (esc)
  \xe2\x94\x82 \xe2\x94\x82   \xe2\x94\x86  date:        Thu Jan 01 00:00:24 1970 +0000 (esc)
  \xe2\x94\x82 \xe2\x94\x82   \xe2\x94\x86  summary:     (24) merge one known; immediate right (esc)
  \xe2\x94\x82 \xe2\x94\x82  \xe2\x95\xb1 (esc)
  \xe2\x94\x82 \xe2\x97\x8b \xe2\x94\x86  changeset:   23:a01cddf0766d (esc)
  \xe2\x94\x82 \xe2\x94\x82\xe2\x95\xb2 \xe2\x95\xb2   parent:      1:6db2ef61d156 (esc)
  \xe2\x94\x82 \xe2\x94\x82 \xe2\x95\xa7 \xe2\x94\x86  parent:      22:e0d9cccacb5d (esc)
  \xe2\x94\x82 \xe2\x94\x82   \xe2\x94\x86  user:        test (esc)
  \xe2\x94\x82 \xe2\x94\x82   \xe2\x94\x86  date:        Thu Jan 01 00:00:23 1970 +0000 (esc)
  \xe2\x94\x82 \xe2\x94\x82   \xe2\x94\x86  summary:     (23) merge one known; immediate left (esc)
  \xe2\x94\x82 \xe2\x94\x82  \xe2\x95\xb1 (esc)
  \xe2\x94\x82 \xe2\x97\x8b \xe2\x94\x86  changeset:   22:e0d9cccacb5d (esc)
  \xe2\x94\x82\xe2\x95\xb1\xe2\x94\x86\xe2\x95\xb1   parent:      18:1aa84d96232a (esc)
  \xe2\x94\x82 \xe2\x94\x86    parent:      21:d42a756af44d (esc)
  \xe2\x94\x82 \xe2\x94\x86    user:        test (esc)
  \xe2\x94\x82 \xe2\x94\x86    date:        Thu Jan 01 00:00:22 1970 +0000 (esc)
  \xe2\x94\x82 \xe2\x94\x86    summary:     (22) merge two known; one far left, one far right (esc)
  \xe2\x94\x82 \xe2\x94\x86 (esc)
  \xe2\x94\x82 \xe2\x97\x8b  changeset:   21:d42a756af44d (esc)
  \xe2\x94\x82 \xe2\x94\x82\xe2\x95\xb2   parent:      19:31ddc2c1573b (esc)
  \xe2\x94\x82 \xe2\x94\x82 \xe2\x94\x82  parent:      20:d30ed6450e32 (esc)
  \xe2\x94\x82 \xe2\x94\x82 \xe2\x94\x82  user:        test (esc)
  \xe2\x94\x82 \xe2\x94\x82 \xe2\x94\x82  date:        Thu Jan 01 00:00:21 1970 +0000 (esc)
  \xe2\x94\x82 \xe2\x94\x82 \xe2\x94\x82  summary:     (21) expand (esc)
  \xe2\x94\x82 \xe2\x94\x82 \xe2\x94\x82 (esc)
  \xe2\x94\x9c\xe2\x94\x80\xe2\x94\x80\xe2\x94\x80\xe2\x97\x8b  changeset:   20:d30ed6450e32 (esc)
  \xe2\x94\x82 \xe2\x94\x82 \xe2\x94\x82  parent:      0:e6eb3150255d (esc)
  \xe2\x94\x82 \xe2\x94\x82 \xe2\x95\xa7  parent:      18:1aa84d96232a (esc)
  \xe2\x94\x82 \xe2\x94\x82    user:        test (esc)
  \xe2\x94\x82 \xe2\x94\x82    date:        Thu Jan 01 00:00:20 1970 +0000 (esc)
  \xe2\x94\x82 \xe2\x94\x82    summary:     (20) merge two known; two far right (esc)
  \xe2\x94\x82 \xe2\x94\x82 (esc)
  \xe2\x94\x82 \xe2\x97\x8b  changeset:   19:31ddc2c1573b (esc)
  \xe2\x94\x82 \xe2\x94\x82\xe2\x95\xb2   parent:      15:1dda3f72782d (esc)
  \xe2\x94\x82 \xe2\x94\x82 \xe2\x94\x82  parent:      17:44765d7c06e0 (esc)
  \xe2\x94\x82 \xe2\x94\x82 \xe2\x94\x82  user:        test (esc)
  \xe2\x94\x82 \xe2\x94\x82 \xe2\x94\x82  date:        Thu Jan 01 00:00:19 1970 +0000 (esc)
  \xe2\x94\x82 \xe2\x94\x82 \xe2\x94\x82  summary:     (19) expand (esc)
  \xe2\x94\x82 \xe2\x94\x82 \xe2\x94\x82 (esc)
  \xe2\x97\x8b \xe2\x94\x82 \xe2\x94\x82  changeset:   18:1aa84d96232a (esc)
  \xe2\x94\x82\xe2\x95\xb2\xe2\x94\x82 \xe2\x94\x82  parent:      1:6db2ef61d156 (esc)
  \xe2\x95\xa7 \xe2\x94\x82 \xe2\x94\x82  parent:      15:1dda3f72782d (esc)
    \xe2\x94\x82 \xe2\x94\x82  user:        test (esc)
    \xe2\x94\x82 \xe2\x94\x82  date:        Thu Jan 01 00:00:18 1970 +0000 (esc)
    \xe2\x94\x82 \xe2\x94\x82  summary:     (18) merge two known; two far left (esc)
   \xe2\x95\xb1 \xe2\x95\xb1 (esc)
  \xe2\x94\x82 \xe2\x97\x8b  changeset:   17:44765d7c06e0 (esc)
  \xe2\x94\x82 \xe2\x94\x82\xe2\x95\xb2   parent:      12:86b91144a6e9 (esc)
  \xe2\x94\x82 \xe2\x94\x82 \xe2\x94\x82  parent:      16:3677d192927d (esc)
  \xe2\x94\x82 \xe2\x94\x82 \xe2\x94\x82  user:        test (esc)
  \xe2\x94\x82 \xe2\x94\x82 \xe2\x94\x82  date:        Thu Jan 01 00:00:17 1970 +0000 (esc)
  \xe2\x94\x82 \xe2\x94\x82 \xe2\x94\x82  summary:     (17) expand (esc)
  \xe2\x94\x82 \xe2\x94\x82 \xe2\x94\x82 (esc)
  \xe2\x94\x82 \xe2\x94\x82 \xe2\x97\x8b  changeset:   16:3677d192927d (esc)
  \xe2\x94\x82 \xe2\x94\x82 \xe2\x94\x82\xe2\x95\xb2   parent:      0:e6eb3150255d (esc)
  \xe2\x94\x82 \xe2\x94\x82 \xe2\x95\xa7 \xe2\x95\xa7  parent:      1:6db2ef61d156 (esc)
  \xe2\x94\x82 \xe2\x94\x82      user:        test (esc)
  \xe2\x94\x82 \xe2\x94\x82      date:        Thu Jan 01 00:00:16 1970 +0000 (esc)
  \xe2\x94\x82 \xe2\x94\x82      summary:     (16) merge two known; one immediate right, one near right (esc)
  \xe2\x94\x82 \xe2\x94\x82 (esc)
  \xe2\x97\x8b \xe2\x94\x82  changeset:   15:1dda3f72782d (esc)
  \xe2\x94\x82\xe2\x95\xb2 \xe2\x95\xb2   parent:      13:22d8966a97e3 (esc)
  \xe2\x94\x82 \xe2\x94\x82 \xe2\x94\x82  parent:      14:8eac370358ef (esc)
  \xe2\x94\x82 \xe2\x94\x82 \xe2\x94\x82  user:        test (esc)
  \xe2\x94\x82 \xe2\x94\x82 \xe2\x94\x82  date:        Thu Jan 01 00:00:15 1970 +0000 (esc)
  \xe2\x94\x82 \xe2\x94\x82 \xe2\x94\x82  summary:     (15) expand (esc)
  \xe2\x94\x82 \xe2\x94\x82 \xe2\x94\x82 (esc)
  \xe2\x94\x82 \xe2\x97\x8b \xe2\x94\x82  changeset:   14:8eac370358ef (esc)
  \xe2\x94\x82 \xe2\x94\x82\xe2\x95\xb2\xe2\x94\x82  parent:      0:e6eb3150255d (esc)
  \xe2\x94\x82 \xe2\x95\xa7 \xe2\x94\x82  parent:      12:86b91144a6e9 (esc)
  \xe2\x94\x82   \xe2\x94\x82  user:        test (esc)
  \xe2\x94\x82   \xe2\x94\x82  date:        Thu Jan 01 00:00:14 1970 +0000 (esc)
  \xe2\x94\x82   \xe2\x94\x82  summary:     (14) merge two known; one immediate right, one far right (esc)
  \xe2\x94\x82  \xe2\x95\xb1 (esc)
  \xe2\x97\x8b \xe2\x94\x82  changeset:   13:22d8966a97e3 (esc)
  \xe2\x94\x82\xe2\x95\xb2 \xe2\x95\xb2   parent:      9:7010c0af0a35 (esc)
  \xe2\x94\x82 \xe2\x94\x82 \xe2\x94\x82  parent:      11:832d76e6bdf2 (esc)
  \xe2\x94\x82 \xe2\x94\x82 \xe2\x94\x82  user:        test (esc)
  \xe2\x94\x82 \xe2\x94\x82 \xe2\x94\x82  date:        Thu Jan 01 00:00:13 1970 +0000 (esc)
  \xe2\x94\x82 \xe2\x94\x82 \xe2\x94\x82  summary:     (13) expand (esc)
  \xe2\x94\x82 \xe2\x94\x82 \xe2\x94\x82 (esc)
  \xe2\x94\x9c\xe2\x94\x80\xe2\x94\x80\xe2\x94\x80\xe2\x97\x8b  changeset:   12:86b91144a6e9 (esc)
  \xe2\x94\x82 \xe2\x94\x82 \xe2\x94\x82  parent:      1:6db2ef61d156 (esc)
  \xe2\x94\x82 \xe2\x94\x82 \xe2\x95\xa7  parent:      9:7010c0af0a35 (esc)
  \xe2\x94\x82 \xe2\x94\x82    user:        test (esc)
  \xe2\x94\x82 \xe2\x94\x82    date:        Thu Jan 01 00:00:12 1970 +0000 (esc)
  \xe2\x94\x82 \xe2\x94\x82    summary:     (12) merge two known; one immediate right, one far left (esc)
  \xe2\x94\x82 \xe2\x94\x82 (esc)
  \xe2\x94\x82 \xe2\x97\x8b  changeset:   11:832d76e6bdf2 (esc)
  \xe2\x94\x82 \xe2\x94\x82\xe2\x95\xb2   parent:      6:b105a072e251 (esc)
  \xe2\x94\x82 \xe2\x94\x82 \xe2\x94\x82  parent:      10:74c64d036d72 (esc)
  \xe2\x94\x82 \xe2\x94\x82 \xe2\x94\x82  user:        test (esc)
  \xe2\x94\x82 \xe2\x94\x82 \xe2\x94\x82  date:        Thu Jan 01 00:00:11 1970 +0000 (esc)
  \xe2\x94\x82 \xe2\x94\x82 \xe2\x94\x82  summary:     (11) expand (esc)
  \xe2\x94\x82 \xe2\x94\x82 \xe2\x94\x82 (esc)
  \xe2\x94\x82 \xe2\x94\x82 \xe2\x97\x8b  changeset:   10:74c64d036d72 (esc)
  \xe2\x94\x82 \xe2\x94\x82\xe2\x95\xb1\xe2\x94\x82  parent:      0:e6eb3150255d (esc)
  \xe2\x94\x82 \xe2\x94\x82 \xe2\x95\xa7  parent:      6:b105a072e251 (esc)
  \xe2\x94\x82 \xe2\x94\x82    user:        test (esc)
  \xe2\x94\x82 \xe2\x94\x82    date:        Thu Jan 01 00:00:10 1970 +0000 (esc)
  \xe2\x94\x82 \xe2\x94\x82    summary:     (10) merge two known; one immediate left, one near right (esc)
  \xe2\x94\x82 \xe2\x94\x82 (esc)
  \xe2\x97\x8b \xe2\x94\x82  changeset:   9:7010c0af0a35 (esc)
  \xe2\x94\x82\xe2\x95\xb2 \xe2\x95\xb2   parent:      7:b632bb1b1224 (esc)
  \xe2\x94\x82 \xe2\x94\x82 \xe2\x94\x82  parent:      8:7a0b11f71937 (esc)
  \xe2\x94\x82 \xe2\x94\x82 \xe2\x94\x82  user:        test (esc)
  \xe2\x94\x82 \xe2\x94\x82 \xe2\x94\x82  date:        Thu Jan 01 00:00:09 1970 +0000 (esc)
  \xe2\x94\x82 \xe2\x94\x82 \xe2\x94\x82  summary:     (9) expand (esc)
  \xe2\x94\x82 \xe2\x94\x82 \xe2\x94\x82 (esc)
  \xe2\x94\x82 \xe2\x97\x8b \xe2\x94\x82  changeset:   8:7a0b11f71937 (esc)
  \xe2\x94\x82\xe2\x95\xb1\xe2\x94\x82 \xe2\x94\x82  parent:      0:e6eb3150255d (esc)
  \xe2\x94\x82 \xe2\x95\xa7 \xe2\x94\x82  parent:      7:b632bb1b1224 (esc)
  \xe2\x94\x82   \xe2\x94\x82  user:        test (esc)
  \xe2\x94\x82   \xe2\x94\x82  date:        Thu Jan 01 00:00:08 1970 +0000 (esc)
  \xe2\x94\x82   \xe2\x94\x82  summary:     (8) merge two known; one immediate left, one far right (esc)
  \xe2\x94\x82  \xe2\x95\xb1 (esc)
  \xe2\x97\x8b \xe2\x94\x82  changeset:   7:b632bb1b1224 (esc)
  \xe2\x94\x82\xe2\x95\xb2 \xe2\x95\xb2   parent:      2:3d9a33b8d1e1 (esc)
  \xe2\x94\x82 \xe2\x95\xa7 \xe2\x94\x82  parent:      5:4409d547b708 (esc)
  \xe2\x94\x82   \xe2\x94\x82  user:        test (esc)
  \xe2\x94\x82   \xe2\x94\x82  date:        Thu Jan 01 00:00:07 1970 +0000 (esc)
  \xe2\x94\x82   \xe2\x94\x82  summary:     (7) expand (esc)
  \xe2\x94\x82  \xe2\x95\xb1 (esc)
  \xe2\x94\x82 \xe2\x97\x8b  changeset:   6:b105a072e251 (esc)
  \xe2\x94\x82\xe2\x95\xb1\xe2\x94\x82  parent:      2:3d9a33b8d1e1 (esc)
  \xe2\x94\x82 \xe2\x95\xa7  parent:      5:4409d547b708 (esc)
  \xe2\x94\x82    user:        test (esc)
  \xe2\x94\x82    date:        Thu Jan 01 00:00:06 1970 +0000 (esc)
  \xe2\x94\x82    summary:     (6) merge two known; one immediate left, one far left (esc)
  \xe2\x94\x82 (esc)
  \xe2\x97\x8b  changeset:   5:4409d547b708 (esc)
  \xe2\x94\x82\xe2\x95\xb2   parent:      3:27eef8ed80b4 (esc)
  \xe2\x94\x82 \xe2\x95\xa7  parent:      4:26a8bac39d9f (esc)
  \xe2\x94\x82    user:        test (esc)
  \xe2\x94\x82    date:        Thu Jan 01 00:00:05 1970 +0000 (esc)
  \xe2\x94\x82    summary:     (5) expand (esc)
  \xe2\x94\x82 (esc)
  \xe2\x97\x8b  changeset:   4:26a8bac39d9f (esc)
  \xe2\x94\x82\xe2\x95\xb2   parent:      1:6db2ef61d156 (esc)
  \xe2\x95\xa7 \xe2\x95\xa7  parent:      3:27eef8ed80b4 (esc)
       user:        test
       date:        Thu Jan 01 00:00:04 1970 +0000
       summary:     (4) merge two known; one immediate left, one immediate right
  
  $ cd ..
  $ cd repo

behavior with newlines

  $ hg log -G -r ::2 -T '{rev} {desc}'
  \xe2\x97\x8b  2 (2) collapse (esc)
  \xe2\x94\x82 (esc)
  \xe2\x97\x8b  1 (1) collapse (esc)
  \xe2\x94\x82 (esc)
  \xe2\x97\x8b  0 (0) root (esc)
  

  $ hg log -G -r ::2 -T '{rev} {desc}\n'
  \xe2\x97\x8b  2 (2) collapse (esc)
  \xe2\x94\x82 (esc)
  \xe2\x97\x8b  1 (1) collapse (esc)
  \xe2\x94\x82 (esc)
  \xe2\x97\x8b  0 (0) root (esc)
  

  $ hg log -G -r ::2 -T '{rev} {desc}\n\n'
  \xe2\x97\x8b  2 (2) collapse (esc)
  \xe2\x94\x82 (esc)
  \xe2\x97\x8b  1 (1) collapse (esc)
  \xe2\x94\x82 (esc)
  \xe2\x97\x8b  0 (0) root (esc)
  

  $ hg log -G -r ::2 -T '\n{rev} {desc}'
  \xe2\x97\x8b (esc)
  \xe2\x94\x82  2 (2) collapse (esc)
  \xe2\x97\x8b (esc)
  \xe2\x94\x82  1 (1) collapse (esc)
  \xe2\x97\x8b (esc)
     0 (0) root

  $ hg log -G -r ::2 -T '{rev} {desc}\n\n\n'
  \xe2\x97\x8b  2 (2) collapse (esc)
  \xe2\x94\x82 (esc)
  \xe2\x94\x82 (esc)
  \xe2\x97\x8b  1 (1) collapse (esc)
  \xe2\x94\x82 (esc)
  \xe2\x94\x82 (esc)
  \xe2\x97\x8b  0 (0) root (esc)
  
  
  $ cd ..

When inserting extra line nodes to handle more than 2 parents, ensure that
the right node styles are used (issue5174):

  $ hg init repo-issue5174
  $ cd repo-issue5174
  $ echo a > f0
  $ hg ci -Aqm 0
  $ echo a > f1
  $ hg ci -Aqm 1
  $ echo a > f2
  $ hg ci -Aqm 2
  $ hg co ".^"
  0 files updated, 0 files merged, 1 files removed, 0 files unresolved
  $ echo a > f3
  $ hg ci -Aqm 3
  $ hg co ".^^"
  0 files updated, 0 files merged, 2 files removed, 0 files unresolved
  $ echo a > f4
  $ hg ci -Aqm 4
  $ hg merge -r 2
  2 files updated, 0 files merged, 0 files removed, 0 files unresolved
  (branch merge, don't forget to commit)
  $ hg ci -qm 5
  $ hg merge -r 3
  1 files updated, 0 files merged, 0 files removed, 0 files unresolved
  (branch merge, don't forget to commit)
  $ hg ci -qm 6
  $ hg log -G -r '0 | 1 | 2 | 6'
  \xe2\x97\x8d  changeset:   6:851fe89689ad (esc)
  \xe2\x94\x86\xe2\x95\xb2   tag:         tip (esc)
  \xe2\x94\x86 \xe2\x94\x86  parent:      5:4f1e3cf15f5d (esc)
  \xe2\x94\x86 \xe2\x94\x86  parent:      3:b74ba7084d2d (esc)
  \xe2\x94\x86 \xe2\x94\x86  user:        test (esc)
  \xe2\x94\x86 \xe2\x94\x86  date:        Thu Jan 01 00:00:00 1970 +0000 (esc)
  \xe2\x94\x86 \xe2\x94\x86  summary:     6 (esc)
  \xe2\x94\x86 \xe2\x94\x86 (esc)
  \xe2\x94\x86 \xe2\x95\xb2 (esc)
  \xe2\x94\x86 \xe2\x94\x86\xe2\x95\xb2 (esc)
  \xe2\x94\x86 \xe2\x97\x8b \xe2\x94\x86  changeset:   2:3e6599df4cce (esc)
  \xe2\x94\x86 \xe2\x94\x86\xe2\x95\xb1   user:        test (esc)
  \xe2\x94\x86 \xe2\x94\x86    date:        Thu Jan 01 00:00:00 1970 +0000 (esc)
  \xe2\x94\x86 \xe2\x94\x86    summary:     2 (esc)
  \xe2\x94\x86 \xe2\x94\x86 (esc)
  \xe2\x94\x86 \xe2\x97\x8b  changeset:   1:bd9a55143933 (esc)
  \xe2\x94\x86\xe2\x95\xb1   user:        test (esc)
  \xe2\x94\x86    date:        Thu Jan 01 00:00:00 1970 +0000 (esc)
  \xe2\x94\x86    summary:     1 (esc)
  \xe2\x94\x86 (esc)
  \xe2\x97\x8b  changeset:   0:870a5edc339c (esc)
     user:        test
     date:        Thu Jan 01 00:00:00 1970 +0000
     summary:     0
  

  $ cd ..

Multiple roots (issue5440):

  $ hg init multiroots
  $ cd multiroots
  $ cat <<EOF > .hg/hgrc
  > [ui]
  > logtemplate = '{rev} {desc}\n\n'
  > EOF

  $ touch foo
  $ hg ci -Aqm foo
  $ hg co -q null
  $ touch bar
  $ hg ci -Aqm bar

  $ hg log -Gr null:
  \xe2\x97\x8d  1 bar (esc)
  \xe2\x94\x82 (esc)
  \xe2\x94\x82 \xe2\x97\x8b  0 foo (esc)
  \xe2\x94\x82\xe2\x95\xb1 (esc)
  \xe2\x97\x8b  -1 (esc)
  
  $ hg log -Gr null+0
  \xe2\x97\x8b  0 foo (esc)
  \xe2\x94\x82 (esc)
  \xe2\x97\x8b  -1 (esc)
  
  $ hg log -Gr null+1
  \xe2\x97\x8d  1 bar (esc)
  \xe2\x94\x82 (esc)
  \xe2\x97\x8b  -1 (esc)
  

  $ cd ..
