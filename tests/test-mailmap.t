Create a repo and add some commits

  $ hg init mm
  $ cd mm
  $ echo "Test content" > testfile1
  $ hg add testfile1
  $ hg commit -m "First commit" -u "Proper <commit@m.c>"
  $ echo "Test content 2" > testfile2
  $ hg add testfile2
  $ hg commit -m "Second commit" -u "Commit Name 2 <commit2@m.c>"
  $ echo "Test content 3" > testfile3
  $ hg add testfile3
  $ hg commit -m "Third commit" -u "Commit Name 3 <commit3@m.c>"
  $ echo "Test content 4" > testfile4
  $ hg add testfile4
  $ hg commit -m "Fourth commit" -u "Commit Name 4 <commit4@m.c>"

Add a .mailmap file with each possible entry type plus comments
  $ cat > .mailmap << EOF
  > # Comment shouldn't break anything
  > <proper@m.c> <commit@m.c> # Should update email only
  > Proper Name 2 <commit2@m.c> # Should update name only
  > Proper Name 3 <proper@m.c> <commit3@m.c> # Should update name, email due to email
  > Proper Name 4 <proper@m.c> Commit Name 4 <commit4@m.c> # Should update name, email due to name, email
  > EOF
  $ hg add .mailmap
  $ hg commit -m "Add mailmap file" -u "Testuser <test123@m.c>"

Output of commits should be normal without filter
  $ hg log -T "{author}\n" -r "all()"
  Proper <commit@m.c>
  Commit Name 2 <commit2@m.c>
  Commit Name 3 <commit3@m.c>
  Commit Name 4 <commit4@m.c>
  Testuser <test123@m.c>

Output of commits with filter shows their mailmap values
  $ hg log -T "{mailmap(author)}\n" -r "all()"
  Proper <proper@m.c>
  Proper Name 2 <commit2@m.c>
  Proper Name 3 <proper@m.c>
  Proper Name 4 <proper@m.c>
  Testuser <test123@m.c>

Add new mailmap entry for testuser
  $ cat >> .mailmap << EOF
  > <newmmentry@m.c> <test123@m.c>
  > EOF

Output of commits with filter shows their updated mailmap values
  $ hg log -T "{mailmap(author)}\n" -r "all()"
  Proper <proper@m.c>
  Proper Name 2 <commit2@m.c>
  Proper Name 3 <proper@m.c>
  Proper Name 4 <proper@m.c>
  Testuser <newmmentry@m.c>

A commit with improperly formatted user field should not break the filter
  $ echo "some more test content" > testfile1
  $ hg commit -m "Commit with improper user field" -u "Improper user"
  $ hg log -T "{mailmap(author)}\n" -r "all()"
  Proper <proper@m.c>
  Proper Name 2 <commit2@m.c>
  Proper Name 3 <proper@m.c>
  Proper Name 4 <proper@m.c>
  Testuser <newmmentry@m.c>
  Improper user

No TypeError beacause of invalid input

  $ hg log -T '{mailmap(termwidth)}\n' -r0
  80
