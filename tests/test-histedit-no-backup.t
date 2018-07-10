  $ . "$TESTDIR/histedit-helpers.sh"

Enable extension used by this test
  $ cat >>$HGRCPATH <<EOF
  > [extensions]
  > histedit=
  > EOF

Repo setup:
  $ hg init foo
  $ cd foo
  $ echo first>file
  $ hg ci -qAm one
  $ echo second>>file
  $ hg ci -m two
  $ echo third>>file
  $ hg ci -m three
  $ echo forth>>file
  $ hg ci -m four
  $ hg log -G --style compact
  @  3[tip]   7d5187087c79   1970-01-01 00:00 +0000   test
  |    four
  |
  o  2   80d23dfa866d   1970-01-01 00:00 +0000   test
  |    three
  |
  o  1   6153eb23e623   1970-01-01 00:00 +0000   test
  |    two
  |
  o  0   36b4bdd91f5b   1970-01-01 00:00 +0000   test
       one
  
Check when --no-backup is not passed
  $ hg histedit -r '36b4bdd91f5b' --commands - << EOF
  > pick 36b4bdd91f5b 0 one
  > pick 6153eb23e623 1 two
  > roll 80d23dfa866d 2 three
  > edit 7d5187087c79 3 four
  > EOF
  merging file
  Editing (7d5187087c79), you may commit or record as needed now.
  (hg histedit --continue to resume)
  [1]

  $ hg histedit --abort
  1 files updated, 0 files merged, 0 files removed, 0 files unresolved
  saved backup bundle to $TESTTMP/foo/.hg/strip-backup/1d8f701c7b35-cf7be322-backup.hg
  saved backup bundle to $TESTTMP/foo/.hg/strip-backup/5c0056670bce-b54b65d0-backup.hg

  $ hg st
  $ hg diff
  $ hg log -G --style compact
  @  3[tip]   7d5187087c79   1970-01-01 00:00 +0000   test
  |    four
  |
  o  2   80d23dfa866d   1970-01-01 00:00 +0000   test
  |    three
  |
  o  1   6153eb23e623   1970-01-01 00:00 +0000   test
  |    two
  |
  o  0   36b4bdd91f5b   1970-01-01 00:00 +0000   test
       one
  

Check when --no-backup is passed
  $ hg histedit -r '36b4bdd91f5b' --commands - << EOF
  > pick 36b4bdd91f5b 0 one
  > pick 6153eb23e623 1 two
  > roll 80d23dfa866d 2 three
  > edit 7d5187087c79 3 four
  > EOF
  merging file
  Editing (7d5187087c79), you may commit or record as needed now.
  (hg histedit --continue to resume)
  [1]

  $ hg histedit --abort --no-backup
  1 files updated, 0 files merged, 0 files removed, 0 files unresolved

  $ hg st
  $ hg diff
  $ hg log -G --style compact
  @  3[tip]   7d5187087c79   1970-01-01 00:00 +0000   test
  |    four
  |
  o  2   80d23dfa866d   1970-01-01 00:00 +0000   test
  |    three
  |
  o  1   6153eb23e623   1970-01-01 00:00 +0000   test
  |    two
  |
  o  0   36b4bdd91f5b   1970-01-01 00:00 +0000   test
       one
  
==========================================
Test history-editing-backup config option|
==========================================
Test when `history-editing-backup` config option is enabled:
  $ hg histedit -r '36b4bdd91f5b' --commands - << EOF
  > pick 36b4bdd91f5b 0 one
  > pick 6153eb23e623 1 two
  > roll 80d23dfa866d 2 three
  > edit 7d5187087c79 3 four
  > EOF
  merging file
  Editing (7d5187087c79), you may commit or record as needed now.
  (hg histedit --continue to resume)
  [1]
  $ hg histedit --abort
  1 files updated, 0 files merged, 0 files removed, 0 files unresolved
  saved backup bundle to $TESTTMP/foo/.hg/strip-backup/1d8f701c7b35-cf7be322-backup.hg
  saved backup bundle to $TESTTMP/foo/.hg/strip-backup/5c0056670bce-b54b65d0-backup.hg

Test when `history-editing-backup` config option is not enabled
Enable config option:
  $ cat >>$HGRCPATH <<EOF
  > [ui]
  > history-editing-backup=False
  > EOF

  $ hg histedit -r '36b4bdd91f5b' --commands - << EOF
  > pick 36b4bdd91f5b 0 one
  > pick 6153eb23e623 1 two
  > roll 80d23dfa866d 2 three
  > edit 7d5187087c79 3 four
  > EOF
  merging file
  Editing (7d5187087c79), you may commit or record as needed now.
  (hg histedit --continue to resume)
  [1]
  $ hg histedit --abort
  1 files updated, 0 files merged, 0 files removed, 0 files unresolved
