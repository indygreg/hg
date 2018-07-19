Test template map files and styles
==================================

  $ hg init a
  $ cd a
  $ echo a > a
  $ hg add a
  $ echo line 1 > b
  $ echo line 2 >> b
  $ hg commit -l b -d '1000000 0' -u 'User Name <user@hostname>'

  $ hg add b
  $ echo other 1 > c
  $ echo other 2 >> c
  $ echo >> c
  $ echo other 3 >> c
  $ hg commit -l c -d '1100000 0' -u 'A. N. Other <other@place>'

  $ hg add c
  $ hg commit -m 'no person' -d '1200000 0' -u 'other@place'
  $ echo c >> c
  $ hg commit -m 'no user, no domain' -d '1300000 0' -u 'person'

  $ echo foo > .hg/branch
  $ hg commit -m 'new branch' -d '1400000 0' -u 'person'

  $ hg co -q 3
  $ echo other 4 >> d
  $ hg add d
  $ hg commit -m 'new head' -d '1500000 0' -u 'person'

  $ hg merge -q foo
  $ hg commit -m 'merge' -d '1500001 0' -u 'person'

Second branch starting at nullrev:

  $ hg update null
  0 files updated, 0 files merged, 4 files removed, 0 files unresolved
  $ echo second > second
  $ hg add second
  $ hg commit -m second -d '1000000 0' -u 'User Name <user@hostname>'
  created new head

  $ echo third > third
  $ hg add third
  $ hg mv second fourth
  $ hg commit -m third -d "2020-01-01 10:01"

Make sure user/global hgrc does not affect tests

  $ echo '[ui]' > .hg/hgrc
  $ echo 'logtemplate =' >> .hg/hgrc
  $ echo 'style =' >> .hg/hgrc

Add some simple styles to settings

  $ cat <<'EOF' >> .hg/hgrc
  > [templates]
  > simple = "{rev}\n"
  > simple2 = {rev}\n
  > rev = "should not precede {rev} keyword\n"
  > EOF

  $ hg log -l1 -Tsimple
  8
  $ hg log -l1 -Tsimple2
  8
  $ hg log -l1 -Trev
  should not precede 8 keyword
  $ hg log -l1 -T '{simple}'
  8

Map file shouldn't see user templates:

  $ cat <<EOF > tmpl
  > changeset = 'nothing expanded:{simple}\n'
  > EOF
  $ hg log -l1 --style ./tmpl
  nothing expanded:

Test templates and style maps in files:

  $ echo "{rev}" > tmpl
  $ hg log -l1 -T./tmpl
  8
  $ hg log -l1 -Tblah/blah
  blah/blah (no-eol)

  $ printf 'changeset = "{rev}\\n"\n' > map-simple
  $ hg log -l1 -T./map-simple
  8

 a map file may have [templates] and [templatealias] sections:

  $ cat <<'EOF' > map-simple
  > [templates]
  > changeset = "{a}\n"
  > [templatealias]
  > a = rev
  > EOF
  $ hg log -l1 -T./map-simple
  8

 so it can be included in hgrc

  $ cat <<EOF > myhgrc
  > %include $HGRCPATH
  > %include map-simple
  > [templates]
  > foo = "{changeset}"
  > EOF
  $ HGRCPATH=./myhgrc hg log -l1 -Tfoo
  8
  $ HGRCPATH=./myhgrc hg log -l1 -T'{a}\n'
  8

Test template map inheritance

  $ echo "__base__ = map-cmdline.default" > map-simple
  $ printf 'cset = "changeset: ***{rev}***\\n"\n' >> map-simple
  $ hg log -l1 -T./map-simple
  changeset: ***8***
  tag:         tip
  user:        test
  date:        Wed Jan 01 10:01:00 2020 +0000
  summary:     third
  

Test docheader, docfooter and separator in template map

  $ cat <<'EOF' > map-myjson
  > docheader = '\{\n'
  > docfooter = '\n}\n'
  > separator = ',\n'
  > changeset = ' {dict(rev, node|short)|json}'
  > EOF
  $ hg log -l2 -T./map-myjson
  {
   {"node": "95c24699272e", "rev": 8},
   {"node": "29114dbae42b", "rev": 7}
  }

Test docheader, docfooter and separator in [templates] section

  $ cat <<'EOF' >> .hg/hgrc
  > [templates]
  > myjson = ' {dict(rev, node|short)|json}'
  > myjson:docheader = '\{\n'
  > myjson:docfooter = '\n}\n'
  > myjson:separator = ',\n'
  > :docheader = 'should not be selected as a docheader for literal templates\n'
  > EOF
  $ hg log -l2 -Tmyjson
  {
   {"node": "95c24699272e", "rev": 8},
   {"node": "29114dbae42b", "rev": 7}
  }
  $ hg log -l1 -T'{rev}\n'
  8

Template should precede style option

  $ hg log -l1 --style default -T '{rev}\n'
  8

Add a commit with empty description, to ensure that the templates
below will omit the description line.

  $ echo c >> c
  $ hg add c
  $ hg commit -qm ' '

Default style is like normal output. Phases style should be the same
as default style, except for extra phase lines.

  $ hg log > log.out
  $ hg log --style default > style.out
  $ cmp log.out style.out || diff -u log.out style.out
  $ hg log -T phases > phases.out
  $ diff -U 0 log.out phases.out | egrep -v '^---|^\+\+\+|^@@'
  +phase:       draft
  +phase:       draft
  +phase:       draft
  +phase:       draft
  +phase:       draft
  +phase:       draft
  +phase:       draft
  +phase:       draft
  +phase:       draft
  +phase:       draft

  $ hg log -v > log.out
  $ hg log -v --style default > style.out
  $ cmp log.out style.out || diff -u log.out style.out
  $ hg log -v -T phases > phases.out
  $ diff -U 0 log.out phases.out | egrep -v '^---|^\+\+\+|^@@'
  +phase:       draft
  +phase:       draft
  +phase:       draft
  +phase:       draft
  +phase:       draft
  +phase:       draft
  +phase:       draft
  +phase:       draft
  +phase:       draft
  +phase:       draft

  $ hg log -q > log.out
  $ hg log -q --style default > style.out
  $ cmp log.out style.out || diff -u log.out style.out
  $ hg log -q -T phases > phases.out
  $ cmp log.out phases.out || diff -u log.out phases.out

  $ hg log --debug > log.out
  $ hg log --debug --style default > style.out
  $ cmp log.out style.out || diff -u log.out style.out
  $ hg log --debug -T phases > phases.out
  $ cmp log.out phases.out || diff -u log.out phases.out

Default style of working-directory revision should also be the same (but
date may change while running tests):

  $ hg log -r 'wdir()' | sed 's|^date:.*|date:|' > log.out
  $ hg log -r 'wdir()' --style default | sed 's|^date:.*|date:|' > style.out
  $ cmp log.out style.out || diff -u log.out style.out

  $ hg log -r 'wdir()' -v | sed 's|^date:.*|date:|' > log.out
  $ hg log -r 'wdir()' -v --style default | sed 's|^date:.*|date:|' > style.out
  $ cmp log.out style.out || diff -u log.out style.out

  $ hg log -r 'wdir()' -q > log.out
  $ hg log -r 'wdir()' -q --style default > style.out
  $ cmp log.out style.out || diff -u log.out style.out

  $ hg log -r 'wdir()' --debug | sed 's|^date:.*|date:|' > log.out
  $ hg log -r 'wdir()' --debug --style default \
  > | sed 's|^date:.*|date:|' > style.out
  $ cmp log.out style.out || diff -u log.out style.out

Default style should also preserve color information (issue2866):

  $ cp $HGRCPATH $HGRCPATH-bak
  $ cat <<EOF >> $HGRCPATH
  > [extensions]
  > color=
  > EOF

  $ hg --color=debug log > log.out
  $ hg --color=debug log --style default > style.out
  $ cmp log.out style.out || diff -u log.out style.out
  $ hg --color=debug log -T phases > phases.out
  $ diff -U 0 log.out phases.out | egrep -v '^---|^\+\+\+|^@@'
  +[log.phase|phase:       draft]
  +[log.phase|phase:       draft]
  +[log.phase|phase:       draft]
  +[log.phase|phase:       draft]
  +[log.phase|phase:       draft]
  +[log.phase|phase:       draft]
  +[log.phase|phase:       draft]
  +[log.phase|phase:       draft]
  +[log.phase|phase:       draft]
  +[log.phase|phase:       draft]

  $ hg --color=debug -v log > log.out
  $ hg --color=debug -v log --style default > style.out
  $ cmp log.out style.out || diff -u log.out style.out
  $ hg --color=debug -v log -T phases > phases.out
  $ diff -U 0 log.out phases.out | egrep -v '^---|^\+\+\+|^@@'
  +[log.phase|phase:       draft]
  +[log.phase|phase:       draft]
  +[log.phase|phase:       draft]
  +[log.phase|phase:       draft]
  +[log.phase|phase:       draft]
  +[log.phase|phase:       draft]
  +[log.phase|phase:       draft]
  +[log.phase|phase:       draft]
  +[log.phase|phase:       draft]
  +[log.phase|phase:       draft]

  $ hg --color=debug -q log > log.out
  $ hg --color=debug -q log --style default > style.out
  $ cmp log.out style.out || diff -u log.out style.out
  $ hg --color=debug -q log -T phases > phases.out
  $ cmp log.out phases.out || diff -u log.out phases.out

  $ hg --color=debug --debug log > log.out
  $ hg --color=debug --debug log --style default > style.out
  $ cmp log.out style.out || diff -u log.out style.out
  $ hg --color=debug --debug log -T phases > phases.out
  $ cmp log.out phases.out || diff -u log.out phases.out

  $ mv $HGRCPATH-bak $HGRCPATH

Remove commit with empty commit message, so as to not pollute further
tests.

  $ hg --config extensions.strip= strip -q .

Revision with no copies (used to print a traceback):

  $ hg tip -v --template '\n'
  

Compact style works:

  $ hg log -Tcompact
  8[tip]   95c24699272e   2020-01-01 10:01 +0000   test
    third
  
  7:-1   29114dbae42b   1970-01-12 13:46 +0000   user
    second
  
  6:5,4   d41e714fe50d   1970-01-18 08:40 +0000   person
    merge
  
  5:3   13207e5a10d9   1970-01-18 08:40 +0000   person
    new head
  
  4   bbe44766e73d   1970-01-17 04:53 +0000   person
    new branch
  
  3   10e46f2dcbf4   1970-01-16 01:06 +0000   person
    no user, no domain
  
  2   97054abb4ab8   1970-01-14 21:20 +0000   other
    no person
  
  1   b608e9d1a3f0   1970-01-13 17:33 +0000   other
    other 1
  
  0   1e4e1b8f71e0   1970-01-12 13:46 +0000   user
    line 1
  

  $ hg log -v --style compact
  8[tip]   95c24699272e   2020-01-01 10:01 +0000   test
    third
  
  7:-1   29114dbae42b   1970-01-12 13:46 +0000   User Name <user@hostname>
    second
  
  6:5,4   d41e714fe50d   1970-01-18 08:40 +0000   person
    merge
  
  5:3   13207e5a10d9   1970-01-18 08:40 +0000   person
    new head
  
  4   bbe44766e73d   1970-01-17 04:53 +0000   person
    new branch
  
  3   10e46f2dcbf4   1970-01-16 01:06 +0000   person
    no user, no domain
  
  2   97054abb4ab8   1970-01-14 21:20 +0000   other@place
    no person
  
  1   b608e9d1a3f0   1970-01-13 17:33 +0000   A. N. Other <other@place>
    other 1
  other 2
  
  other 3
  
  0   1e4e1b8f71e0   1970-01-12 13:46 +0000   User Name <user@hostname>
    line 1
  line 2
  

  $ hg log --debug --style compact
  8[tip]:7,-1   95c24699272e   2020-01-01 10:01 +0000   test
    third
  
  7:-1,-1   29114dbae42b   1970-01-12 13:46 +0000   User Name <user@hostname>
    second
  
  6:5,4   d41e714fe50d   1970-01-18 08:40 +0000   person
    merge
  
  5:3,-1   13207e5a10d9   1970-01-18 08:40 +0000   person
    new head
  
  4:3,-1   bbe44766e73d   1970-01-17 04:53 +0000   person
    new branch
  
  3:2,-1   10e46f2dcbf4   1970-01-16 01:06 +0000   person
    no user, no domain
  
  2:1,-1   97054abb4ab8   1970-01-14 21:20 +0000   other@place
    no person
  
  1:0,-1   b608e9d1a3f0   1970-01-13 17:33 +0000   A. N. Other <other@place>
    other 1
  other 2
  
  other 3
  
  0:-1,-1   1e4e1b8f71e0   1970-01-12 13:46 +0000   User Name <user@hostname>
    line 1
  line 2
  

Test xml styles:

  $ hg log --style xml -r 'not all()'
  <?xml version="1.0"?>
  <log>
  </log>

  $ hg log --style xml
  <?xml version="1.0"?>
  <log>
  <logentry revision="8" node="95c24699272ef57d062b8bccc32c878bf841784a">
  <tag>tip</tag>
  <author email="test">test</author>
  <date>2020-01-01T10:01:00+00:00</date>
  <msg xml:space="preserve">third</msg>
  </logentry>
  <logentry revision="7" node="29114dbae42b9f078cf2714dbe3a86bba8ec7453">
  <parent revision="-1" node="0000000000000000000000000000000000000000" />
  <author email="user@hostname">User Name</author>
  <date>1970-01-12T13:46:40+00:00</date>
  <msg xml:space="preserve">second</msg>
  </logentry>
  <logentry revision="6" node="d41e714fe50d9e4a5f11b4d595d543481b5f980b">
  <parent revision="5" node="13207e5a10d9fd28ec424934298e176197f2c67f" />
  <parent revision="4" node="bbe44766e73d5f11ed2177f1838de10c53ef3e74" />
  <author email="person">person</author>
  <date>1970-01-18T08:40:01+00:00</date>
  <msg xml:space="preserve">merge</msg>
  </logentry>
  <logentry revision="5" node="13207e5a10d9fd28ec424934298e176197f2c67f">
  <parent revision="3" node="10e46f2dcbf4823578cf180f33ecf0b957964c47" />
  <author email="person">person</author>
  <date>1970-01-18T08:40:00+00:00</date>
  <msg xml:space="preserve">new head</msg>
  </logentry>
  <logentry revision="4" node="bbe44766e73d5f11ed2177f1838de10c53ef3e74">
  <branch>foo</branch>
  <author email="person">person</author>
  <date>1970-01-17T04:53:20+00:00</date>
  <msg xml:space="preserve">new branch</msg>
  </logentry>
  <logentry revision="3" node="10e46f2dcbf4823578cf180f33ecf0b957964c47">
  <author email="person">person</author>
  <date>1970-01-16T01:06:40+00:00</date>
  <msg xml:space="preserve">no user, no domain</msg>
  </logentry>
  <logentry revision="2" node="97054abb4ab824450e9164180baf491ae0078465">
  <author email="other@place">other</author>
  <date>1970-01-14T21:20:00+00:00</date>
  <msg xml:space="preserve">no person</msg>
  </logentry>
  <logentry revision="1" node="b608e9d1a3f0273ccf70fb85fd6866b3482bf965">
  <author email="other@place">A. N. Other</author>
  <date>1970-01-13T17:33:20+00:00</date>
  <msg xml:space="preserve">other 1
  other 2
  
  other 3</msg>
  </logentry>
  <logentry revision="0" node="1e4e1b8f71e05681d422154f5421e385fec3454f">
  <author email="user@hostname">User Name</author>
  <date>1970-01-12T13:46:40+00:00</date>
  <msg xml:space="preserve">line 1
  line 2</msg>
  </logentry>
  </log>

  $ hg log -v --style xml
  <?xml version="1.0"?>
  <log>
  <logentry revision="8" node="95c24699272ef57d062b8bccc32c878bf841784a">
  <tag>tip</tag>
  <author email="test">test</author>
  <date>2020-01-01T10:01:00+00:00</date>
  <msg xml:space="preserve">third</msg>
  <paths>
  <path action="A">fourth</path>
  <path action="A">third</path>
  <path action="R">second</path>
  </paths>
  <copies>
  <copy source="second">fourth</copy>
  </copies>
  </logentry>
  <logentry revision="7" node="29114dbae42b9f078cf2714dbe3a86bba8ec7453">
  <parent revision="-1" node="0000000000000000000000000000000000000000" />
  <author email="user@hostname">User Name</author>
  <date>1970-01-12T13:46:40+00:00</date>
  <msg xml:space="preserve">second</msg>
  <paths>
  <path action="A">second</path>
  </paths>
  </logentry>
  <logentry revision="6" node="d41e714fe50d9e4a5f11b4d595d543481b5f980b">
  <parent revision="5" node="13207e5a10d9fd28ec424934298e176197f2c67f" />
  <parent revision="4" node="bbe44766e73d5f11ed2177f1838de10c53ef3e74" />
  <author email="person">person</author>
  <date>1970-01-18T08:40:01+00:00</date>
  <msg xml:space="preserve">merge</msg>
  <paths>
  </paths>
  </logentry>
  <logentry revision="5" node="13207e5a10d9fd28ec424934298e176197f2c67f">
  <parent revision="3" node="10e46f2dcbf4823578cf180f33ecf0b957964c47" />
  <author email="person">person</author>
  <date>1970-01-18T08:40:00+00:00</date>
  <msg xml:space="preserve">new head</msg>
  <paths>
  <path action="A">d</path>
  </paths>
  </logentry>
  <logentry revision="4" node="bbe44766e73d5f11ed2177f1838de10c53ef3e74">
  <branch>foo</branch>
  <author email="person">person</author>
  <date>1970-01-17T04:53:20+00:00</date>
  <msg xml:space="preserve">new branch</msg>
  <paths>
  </paths>
  </logentry>
  <logentry revision="3" node="10e46f2dcbf4823578cf180f33ecf0b957964c47">
  <author email="person">person</author>
  <date>1970-01-16T01:06:40+00:00</date>
  <msg xml:space="preserve">no user, no domain</msg>
  <paths>
  <path action="M">c</path>
  </paths>
  </logentry>
  <logentry revision="2" node="97054abb4ab824450e9164180baf491ae0078465">
  <author email="other@place">other</author>
  <date>1970-01-14T21:20:00+00:00</date>
  <msg xml:space="preserve">no person</msg>
  <paths>
  <path action="A">c</path>
  </paths>
  </logentry>
  <logentry revision="1" node="b608e9d1a3f0273ccf70fb85fd6866b3482bf965">
  <author email="other@place">A. N. Other</author>
  <date>1970-01-13T17:33:20+00:00</date>
  <msg xml:space="preserve">other 1
  other 2
  
  other 3</msg>
  <paths>
  <path action="A">b</path>
  </paths>
  </logentry>
  <logentry revision="0" node="1e4e1b8f71e05681d422154f5421e385fec3454f">
  <author email="user@hostname">User Name</author>
  <date>1970-01-12T13:46:40+00:00</date>
  <msg xml:space="preserve">line 1
  line 2</msg>
  <paths>
  <path action="A">a</path>
  </paths>
  </logentry>
  </log>

  $ hg log --debug --style xml
  <?xml version="1.0"?>
  <log>
  <logentry revision="8" node="95c24699272ef57d062b8bccc32c878bf841784a">
  <tag>tip</tag>
  <parent revision="7" node="29114dbae42b9f078cf2714dbe3a86bba8ec7453" />
  <parent revision="-1" node="0000000000000000000000000000000000000000" />
  <author email="test">test</author>
  <date>2020-01-01T10:01:00+00:00</date>
  <msg xml:space="preserve">third</msg>
  <paths>
  <path action="A">fourth</path>
  <path action="A">third</path>
  <path action="R">second</path>
  </paths>
  <copies>
  <copy source="second">fourth</copy>
  </copies>
  <extra key="branch">default</extra>
  </logentry>
  <logentry revision="7" node="29114dbae42b9f078cf2714dbe3a86bba8ec7453">
  <parent revision="-1" node="0000000000000000000000000000000000000000" />
  <parent revision="-1" node="0000000000000000000000000000000000000000" />
  <author email="user@hostname">User Name</author>
  <date>1970-01-12T13:46:40+00:00</date>
  <msg xml:space="preserve">second</msg>
  <paths>
  <path action="A">second</path>
  </paths>
  <extra key="branch">default</extra>
  </logentry>
  <logentry revision="6" node="d41e714fe50d9e4a5f11b4d595d543481b5f980b">
  <parent revision="5" node="13207e5a10d9fd28ec424934298e176197f2c67f" />
  <parent revision="4" node="bbe44766e73d5f11ed2177f1838de10c53ef3e74" />
  <author email="person">person</author>
  <date>1970-01-18T08:40:01+00:00</date>
  <msg xml:space="preserve">merge</msg>
  <paths>
  </paths>
  <extra key="branch">default</extra>
  </logentry>
  <logentry revision="5" node="13207e5a10d9fd28ec424934298e176197f2c67f">
  <parent revision="3" node="10e46f2dcbf4823578cf180f33ecf0b957964c47" />
  <parent revision="-1" node="0000000000000000000000000000000000000000" />
  <author email="person">person</author>
  <date>1970-01-18T08:40:00+00:00</date>
  <msg xml:space="preserve">new head</msg>
  <paths>
  <path action="A">d</path>
  </paths>
  <extra key="branch">default</extra>
  </logentry>
  <logentry revision="4" node="bbe44766e73d5f11ed2177f1838de10c53ef3e74">
  <branch>foo</branch>
  <parent revision="3" node="10e46f2dcbf4823578cf180f33ecf0b957964c47" />
  <parent revision="-1" node="0000000000000000000000000000000000000000" />
  <author email="person">person</author>
  <date>1970-01-17T04:53:20+00:00</date>
  <msg xml:space="preserve">new branch</msg>
  <paths>
  </paths>
  <extra key="branch">foo</extra>
  </logentry>
  <logentry revision="3" node="10e46f2dcbf4823578cf180f33ecf0b957964c47">
  <parent revision="2" node="97054abb4ab824450e9164180baf491ae0078465" />
  <parent revision="-1" node="0000000000000000000000000000000000000000" />
  <author email="person">person</author>
  <date>1970-01-16T01:06:40+00:00</date>
  <msg xml:space="preserve">no user, no domain</msg>
  <paths>
  <path action="M">c</path>
  </paths>
  <extra key="branch">default</extra>
  </logentry>
  <logentry revision="2" node="97054abb4ab824450e9164180baf491ae0078465">
  <parent revision="1" node="b608e9d1a3f0273ccf70fb85fd6866b3482bf965" />
  <parent revision="-1" node="0000000000000000000000000000000000000000" />
  <author email="other@place">other</author>
  <date>1970-01-14T21:20:00+00:00</date>
  <msg xml:space="preserve">no person</msg>
  <paths>
  <path action="A">c</path>
  </paths>
  <extra key="branch">default</extra>
  </logentry>
  <logentry revision="1" node="b608e9d1a3f0273ccf70fb85fd6866b3482bf965">
  <parent revision="0" node="1e4e1b8f71e05681d422154f5421e385fec3454f" />
  <parent revision="-1" node="0000000000000000000000000000000000000000" />
  <author email="other@place">A. N. Other</author>
  <date>1970-01-13T17:33:20+00:00</date>
  <msg xml:space="preserve">other 1
  other 2
  
  other 3</msg>
  <paths>
  <path action="A">b</path>
  </paths>
  <extra key="branch">default</extra>
  </logentry>
  <logentry revision="0" node="1e4e1b8f71e05681d422154f5421e385fec3454f">
  <parent revision="-1" node="0000000000000000000000000000000000000000" />
  <parent revision="-1" node="0000000000000000000000000000000000000000" />
  <author email="user@hostname">User Name</author>
  <date>1970-01-12T13:46:40+00:00</date>
  <msg xml:space="preserve">line 1
  line 2</msg>
  <paths>
  <path action="A">a</path>
  </paths>
  <extra key="branch">default</extra>
  </logentry>
  </log>


Test JSON style:

  $ hg log -k nosuch -Tjson
  [
  ]

  $ hg log -qr . -Tjson
  [
   {
    "node": "95c24699272ef57d062b8bccc32c878bf841784a",
    "rev": 8
   }
  ]

  $ hg log -vpr . -Tjson --stat
  [
   {
    "bookmarks": [],
    "branch": "default",
    "date": [1577872860, 0],
    "desc": "third",
    "diff": "diff -r 29114dbae42b -r 95c24699272e fourth\n--- /dev/null\tThu Jan 01 00:00:00 1970 +0000\n+++ b/fourth\tWed Jan 01 10:01:00 2020 +0000\n@@ -0,0 +1,1 @@\n+second\ndiff -r 29114dbae42b -r 95c24699272e second\n--- a/second\tMon Jan 12 13:46:40 1970 +0000\n+++ /dev/null\tThu Jan 01 00:00:00 1970 +0000\n@@ -1,1 +0,0 @@\n-second\ndiff -r 29114dbae42b -r 95c24699272e third\n--- /dev/null\tThu Jan 01 00:00:00 1970 +0000\n+++ b/third\tWed Jan 01 10:01:00 2020 +0000\n@@ -0,0 +1,1 @@\n+third\n",
    "diffstat": " fourth |  1 +\n second |  1 -\n third  |  1 +\n 3 files changed, 2 insertions(+), 1 deletions(-)\n",
    "files": ["fourth", "second", "third"],
    "node": "95c24699272ef57d062b8bccc32c878bf841784a",
    "parents": ["29114dbae42b9f078cf2714dbe3a86bba8ec7453"],
    "phase": "draft",
    "rev": 8,
    "tags": ["tip"],
    "user": "test"
   }
  ]

honor --git but not format-breaking diffopts
  $ hg --config diff.noprefix=True log --git -vpr . -Tjson
  [
   {
    "bookmarks": [],
    "branch": "default",
    "date": [1577872860, 0],
    "desc": "third",
    "diff": "diff --git a/second b/fourth\nrename from second\nrename to fourth\ndiff --git a/third b/third\nnew file mode 100644\n--- /dev/null\n+++ b/third\n@@ -0,0 +1,1 @@\n+third\n",
    "files": ["fourth", "second", "third"],
    "node": "95c24699272ef57d062b8bccc32c878bf841784a",
    "parents": ["29114dbae42b9f078cf2714dbe3a86bba8ec7453"],
    "phase": "draft",
    "rev": 8,
    "tags": ["tip"],
    "user": "test"
   }
  ]

  $ hg log -T json
  [
   {
    "bookmarks": [],
    "branch": "default",
    "date": [1577872860, 0],
    "desc": "third",
    "node": "95c24699272ef57d062b8bccc32c878bf841784a",
    "parents": ["29114dbae42b9f078cf2714dbe3a86bba8ec7453"],
    "phase": "draft",
    "rev": 8,
    "tags": ["tip"],
    "user": "test"
   },
   {
    "bookmarks": [],
    "branch": "default",
    "date": [1000000, 0],
    "desc": "second",
    "node": "29114dbae42b9f078cf2714dbe3a86bba8ec7453",
    "parents": ["0000000000000000000000000000000000000000"],
    "phase": "draft",
    "rev": 7,
    "tags": [],
    "user": "User Name <user@hostname>"
   },
   {
    "bookmarks": [],
    "branch": "default",
    "date": [1500001, 0],
    "desc": "merge",
    "node": "d41e714fe50d9e4a5f11b4d595d543481b5f980b",
    "parents": ["13207e5a10d9fd28ec424934298e176197f2c67f", "bbe44766e73d5f11ed2177f1838de10c53ef3e74"],
    "phase": "draft",
    "rev": 6,
    "tags": [],
    "user": "person"
   },
   {
    "bookmarks": [],
    "branch": "default",
    "date": [1500000, 0],
    "desc": "new head",
    "node": "13207e5a10d9fd28ec424934298e176197f2c67f",
    "parents": ["10e46f2dcbf4823578cf180f33ecf0b957964c47"],
    "phase": "draft",
    "rev": 5,
    "tags": [],
    "user": "person"
   },
   {
    "bookmarks": [],
    "branch": "foo",
    "date": [1400000, 0],
    "desc": "new branch",
    "node": "bbe44766e73d5f11ed2177f1838de10c53ef3e74",
    "parents": ["10e46f2dcbf4823578cf180f33ecf0b957964c47"],
    "phase": "draft",
    "rev": 4,
    "tags": [],
    "user": "person"
   },
   {
    "bookmarks": [],
    "branch": "default",
    "date": [1300000, 0],
    "desc": "no user, no domain",
    "node": "10e46f2dcbf4823578cf180f33ecf0b957964c47",
    "parents": ["97054abb4ab824450e9164180baf491ae0078465"],
    "phase": "draft",
    "rev": 3,
    "tags": [],
    "user": "person"
   },
   {
    "bookmarks": [],
    "branch": "default",
    "date": [1200000, 0],
    "desc": "no person",
    "node": "97054abb4ab824450e9164180baf491ae0078465",
    "parents": ["b608e9d1a3f0273ccf70fb85fd6866b3482bf965"],
    "phase": "draft",
    "rev": 2,
    "tags": [],
    "user": "other@place"
   },
   {
    "bookmarks": [],
    "branch": "default",
    "date": [1100000, 0],
    "desc": "other 1\nother 2\n\nother 3",
    "node": "b608e9d1a3f0273ccf70fb85fd6866b3482bf965",
    "parents": ["1e4e1b8f71e05681d422154f5421e385fec3454f"],
    "phase": "draft",
    "rev": 1,
    "tags": [],
    "user": "A. N. Other <other@place>"
   },
   {
    "bookmarks": [],
    "branch": "default",
    "date": [1000000, 0],
    "desc": "line 1\nline 2",
    "node": "1e4e1b8f71e05681d422154f5421e385fec3454f",
    "parents": ["0000000000000000000000000000000000000000"],
    "phase": "draft",
    "rev": 0,
    "tags": [],
    "user": "User Name <user@hostname>"
   }
  ]

  $ hg heads -v -Tjson
  [
   {
    "bookmarks": [],
    "branch": "default",
    "date": [1577872860, 0],
    "desc": "third",
    "files": ["fourth", "second", "third"],
    "node": "95c24699272ef57d062b8bccc32c878bf841784a",
    "parents": ["29114dbae42b9f078cf2714dbe3a86bba8ec7453"],
    "phase": "draft",
    "rev": 8,
    "tags": ["tip"],
    "user": "test"
   },
   {
    "bookmarks": [],
    "branch": "default",
    "date": [1500001, 0],
    "desc": "merge",
    "files": [],
    "node": "d41e714fe50d9e4a5f11b4d595d543481b5f980b",
    "parents": ["13207e5a10d9fd28ec424934298e176197f2c67f", "bbe44766e73d5f11ed2177f1838de10c53ef3e74"],
    "phase": "draft",
    "rev": 6,
    "tags": [],
    "user": "person"
   },
   {
    "bookmarks": [],
    "branch": "foo",
    "date": [1400000, 0],
    "desc": "new branch",
    "files": [],
    "node": "bbe44766e73d5f11ed2177f1838de10c53ef3e74",
    "parents": ["10e46f2dcbf4823578cf180f33ecf0b957964c47"],
    "phase": "draft",
    "rev": 4,
    "tags": [],
    "user": "person"
   }
  ]

  $ hg log --debug -Tjson
  [
   {
    "added": ["fourth", "third"],
    "bookmarks": [],
    "branch": "default",
    "date": [1577872860, 0],
    "desc": "third",
    "extra": {"branch": "default"},
    "manifest": "94961b75a2da554b4df6fb599e5bfc7d48de0c64",
    "modified": [],
    "node": "95c24699272ef57d062b8bccc32c878bf841784a",
    "parents": ["29114dbae42b9f078cf2714dbe3a86bba8ec7453"],
    "phase": "draft",
    "removed": ["second"],
    "rev": 8,
    "tags": ["tip"],
    "user": "test"
   },
   {
    "added": ["second"],
    "bookmarks": [],
    "branch": "default",
    "date": [1000000, 0],
    "desc": "second",
    "extra": {"branch": "default"},
    "manifest": "f2dbc354b94e5ec0b4f10680ee0cee816101d0bf",
    "modified": [],
    "node": "29114dbae42b9f078cf2714dbe3a86bba8ec7453",
    "parents": ["0000000000000000000000000000000000000000"],
    "phase": "draft",
    "removed": [],
    "rev": 7,
    "tags": [],
    "user": "User Name <user@hostname>"
   },
   {
    "added": [],
    "bookmarks": [],
    "branch": "default",
    "date": [1500001, 0],
    "desc": "merge",
    "extra": {"branch": "default"},
    "manifest": "4dc3def4f9b4c6e8de820f6ee74737f91e96a216",
    "modified": [],
    "node": "d41e714fe50d9e4a5f11b4d595d543481b5f980b",
    "parents": ["13207e5a10d9fd28ec424934298e176197f2c67f", "bbe44766e73d5f11ed2177f1838de10c53ef3e74"],
    "phase": "draft",
    "removed": [],
    "rev": 6,
    "tags": [],
    "user": "person"
   },
   {
    "added": ["d"],
    "bookmarks": [],
    "branch": "default",
    "date": [1500000, 0],
    "desc": "new head",
    "extra": {"branch": "default"},
    "manifest": "4dc3def4f9b4c6e8de820f6ee74737f91e96a216",
    "modified": [],
    "node": "13207e5a10d9fd28ec424934298e176197f2c67f",
    "parents": ["10e46f2dcbf4823578cf180f33ecf0b957964c47"],
    "phase": "draft",
    "removed": [],
    "rev": 5,
    "tags": [],
    "user": "person"
   },
   {
    "added": [],
    "bookmarks": [],
    "branch": "foo",
    "date": [1400000, 0],
    "desc": "new branch",
    "extra": {"branch": "foo"},
    "manifest": "cb5a1327723bada42f117e4c55a303246eaf9ccc",
    "modified": [],
    "node": "bbe44766e73d5f11ed2177f1838de10c53ef3e74",
    "parents": ["10e46f2dcbf4823578cf180f33ecf0b957964c47"],
    "phase": "draft",
    "removed": [],
    "rev": 4,
    "tags": [],
    "user": "person"
   },
   {
    "added": [],
    "bookmarks": [],
    "branch": "default",
    "date": [1300000, 0],
    "desc": "no user, no domain",
    "extra": {"branch": "default"},
    "manifest": "cb5a1327723bada42f117e4c55a303246eaf9ccc",
    "modified": ["c"],
    "node": "10e46f2dcbf4823578cf180f33ecf0b957964c47",
    "parents": ["97054abb4ab824450e9164180baf491ae0078465"],
    "phase": "draft",
    "removed": [],
    "rev": 3,
    "tags": [],
    "user": "person"
   },
   {
    "added": ["c"],
    "bookmarks": [],
    "branch": "default",
    "date": [1200000, 0],
    "desc": "no person",
    "extra": {"branch": "default"},
    "manifest": "6e0e82995c35d0d57a52aca8da4e56139e06b4b1",
    "modified": [],
    "node": "97054abb4ab824450e9164180baf491ae0078465",
    "parents": ["b608e9d1a3f0273ccf70fb85fd6866b3482bf965"],
    "phase": "draft",
    "removed": [],
    "rev": 2,
    "tags": [],
    "user": "other@place"
   },
   {
    "added": ["b"],
    "bookmarks": [],
    "branch": "default",
    "date": [1100000, 0],
    "desc": "other 1\nother 2\n\nother 3",
    "extra": {"branch": "default"},
    "manifest": "4e8d705b1e53e3f9375e0e60dc7b525d8211fe55",
    "modified": [],
    "node": "b608e9d1a3f0273ccf70fb85fd6866b3482bf965",
    "parents": ["1e4e1b8f71e05681d422154f5421e385fec3454f"],
    "phase": "draft",
    "removed": [],
    "rev": 1,
    "tags": [],
    "user": "A. N. Other <other@place>"
   },
   {
    "added": ["a"],
    "bookmarks": [],
    "branch": "default",
    "date": [1000000, 0],
    "desc": "line 1\nline 2",
    "extra": {"branch": "default"},
    "manifest": "a0c8bcbbb45c63b90b70ad007bf38961f64f2af0",
    "modified": [],
    "node": "1e4e1b8f71e05681d422154f5421e385fec3454f",
    "parents": ["0000000000000000000000000000000000000000"],
    "phase": "draft",
    "removed": [],
    "rev": 0,
    "tags": [],
    "user": "User Name <user@hostname>"
   }
  ]

Error if style not readable:

#if unix-permissions no-root
  $ touch q
  $ chmod 0 q
  $ hg log --style ./q
  abort: Permission denied: ./q
  [255]
#endif

Error if no style:

  $ hg log --style notexist
  abort: style 'notexist' not found
  (available styles: bisect, changelog, compact, default, phases, show, status, xml)
  [255]

  $ hg log -T list
  available styles: bisect, changelog, compact, default, phases, show, status, xml
  abort: specify a template
  [255]

Error if style missing key:

  $ echo 'q = q' > t
  $ hg log --style ./t
  abort: "changeset" not in template map
  [255]

Error if style missing value:

  $ echo 'changeset =' > t
  $ hg log --style t
  hg: parse error at t:1: missing value
  [255]

Error if include fails:

  $ echo 'changeset = q' >> t
#if unix-permissions no-root
  $ hg log --style ./t
  abort: template file ./q: Permission denied
  [255]
  $ rm -f q
#endif

Include works:

  $ echo '{rev}' > q
  $ hg log --style ./t
  8
  7
  6
  5
  4
  3
  2
  1
  0

  $ hg phase -r 5 --public
  $ hg phase -r 7 --secret --force

Missing non-standard names give no error (backward compatibility):

  $ echo "changeset = '{c}'" > t
  $ hg log --style ./t

Defining non-standard name works:

  $ cat <<EOF > t
  > changeset = '{c}'
  > c = q
  > EOF
  $ hg log --style ./t
  8
  7
  6
  5
  4
  3
  2
  1
  0

ui.style works:

  $ echo '[ui]' > .hg/hgrc
  $ echo 'style = t' >> .hg/hgrc
  $ hg log
  8
  7
  6
  5
  4
  3
  2
  1
  0

Issue338:

  $ hg log --style=changelog > changelog

  $ cat changelog
  2020-01-01  test  <test>
  
  	* fourth, second, third:
  	third
  	[95c24699272e] [tip]
  
  1970-01-12  User Name  <user@hostname>
  
  	* second:
  	second
  	[29114dbae42b]
  
  1970-01-18  person  <person>
  
  	* merge
  	[d41e714fe50d]
  
  	* d:
  	new head
  	[13207e5a10d9]
  
  1970-01-17  person  <person>
  
  	* new branch
  	[bbe44766e73d] <foo>
  
  1970-01-16  person  <person>
  
  	* c:
  	no user, no domain
  	[10e46f2dcbf4]
  
  1970-01-14  other  <other@place>
  
  	* c:
  	no person
  	[97054abb4ab8]
  
  1970-01-13  A. N. Other  <other@place>
  
  	* b:
  	other 1 other 2
  
  	other 3
  	[b608e9d1a3f0]
  
  1970-01-12  User Name  <user@hostname>
  
  	* a:
  	line 1 line 2
  	[1e4e1b8f71e0]
  

Issue2130: xml output for 'hg heads' is malformed

  $ hg heads --style changelog
  2020-01-01  test  <test>
  
  	* fourth, second, third:
  	third
  	[95c24699272e] [tip]
  
  1970-01-18  person  <person>
  
  	* merge
  	[d41e714fe50d]
  
  1970-01-17  person  <person>
  
  	* new branch
  	[bbe44766e73d] <foo>
  

Add a dummy commit to make up for the instability of the above:

  $ echo a > a
  $ hg add a
  $ hg ci -m future

Add a commit that does all possible modifications at once

  $ echo modify >> third
  $ touch b
  $ hg add b
  $ hg mv fourth fifth
  $ hg rm a
  $ hg ci -m "Modify, add, remove, rename"

Check the status template

  $ cat <<EOF >> $HGRCPATH
  > [extensions]
  > color=
  > EOF

  $ hg log -T status -r 10
  changeset:   10:0f9759ec227a
  tag:         tip
  user:        test
  date:        Thu Jan 01 00:00:00 1970 +0000
  summary:     Modify, add, remove, rename
  files:
  M third
  A b
  A fifth
  R a
  R fourth
  
  $ hg log -T status -C -r 10
  changeset:   10:0f9759ec227a
  tag:         tip
  user:        test
  date:        Thu Jan 01 00:00:00 1970 +0000
  summary:     Modify, add, remove, rename
  files:
  M third
  A b
  A fifth
    fourth
  R a
  R fourth
  
  $ hg log -T status -C -r 10 -v
  changeset:   10:0f9759ec227a
  tag:         tip
  user:        test
  date:        Thu Jan 01 00:00:00 1970 +0000
  description:
  Modify, add, remove, rename
  
  files:
  M third
  A b
  A fifth
    fourth
  R a
  R fourth
  
  $ hg log -T status -C -r 10 --debug
  changeset:   10:0f9759ec227a4859c2014a345cd8a859022b7c6c
  tag:         tip
  phase:       secret
  parent:      9:bf9dfba36635106d6a73ccc01e28b762da60e066
  parent:      -1:0000000000000000000000000000000000000000
  manifest:    8:89dd546f2de0a9d6d664f58d86097eb97baba567
  user:        test
  date:        Thu Jan 01 00:00:00 1970 +0000
  extra:       branch=default
  description:
  Modify, add, remove, rename
  
  files:
  M third
  A b
  A fifth
    fourth
  R a
  R fourth
  
  $ hg log -T status -C -r 10 --quiet
  10:0f9759ec227a
  $ hg --color=debug log -T status -r 10
  [log.changeset changeset.secret|changeset:   10:0f9759ec227a]
  [log.tag|tag:         tip]
  [log.user|user:        test]
  [log.date|date:        Thu Jan 01 00:00:00 1970 +0000]
  [log.summary|summary:     Modify, add, remove, rename]
  [ui.note log.files|files:]
  [status.modified|M third]
  [status.added|A b]
  [status.added|A fifth]
  [status.removed|R a]
  [status.removed|R fourth]
  
  $ hg --color=debug log -T status -C -r 10
  [log.changeset changeset.secret|changeset:   10:0f9759ec227a]
  [log.tag|tag:         tip]
  [log.user|user:        test]
  [log.date|date:        Thu Jan 01 00:00:00 1970 +0000]
  [log.summary|summary:     Modify, add, remove, rename]
  [ui.note log.files|files:]
  [status.modified|M third]
  [status.added|A b]
  [status.added|A fifth]
  [status.copied|  fourth]
  [status.removed|R a]
  [status.removed|R fourth]
  
  $ hg --color=debug log -T status -C -r 10 -v
  [log.changeset changeset.secret|changeset:   10:0f9759ec227a]
  [log.tag|tag:         tip]
  [log.user|user:        test]
  [log.date|date:        Thu Jan 01 00:00:00 1970 +0000]
  [ui.note log.description|description:]
  [ui.note log.description|Modify, add, remove, rename]
  
  [ui.note log.files|files:]
  [status.modified|M third]
  [status.added|A b]
  [status.added|A fifth]
  [status.copied|  fourth]
  [status.removed|R a]
  [status.removed|R fourth]
  
  $ hg --color=debug log -T status -C -r 10 --debug
  [log.changeset changeset.secret|changeset:   10:0f9759ec227a4859c2014a345cd8a859022b7c6c]
  [log.tag|tag:         tip]
  [log.phase|phase:       secret]
  [log.parent changeset.secret|parent:      9:bf9dfba36635106d6a73ccc01e28b762da60e066]
  [log.parent changeset.public|parent:      -1:0000000000000000000000000000000000000000]
  [ui.debug log.manifest|manifest:    8:89dd546f2de0a9d6d664f58d86097eb97baba567]
  [log.user|user:        test]
  [log.date|date:        Thu Jan 01 00:00:00 1970 +0000]
  [ui.debug log.extra|extra:       branch=default]
  [ui.note log.description|description:]
  [ui.note log.description|Modify, add, remove, rename]
  
  [ui.note log.files|files:]
  [status.modified|M third]
  [status.added|A b]
  [status.added|A fifth]
  [status.copied|  fourth]
  [status.removed|R a]
  [status.removed|R fourth]
  
  $ hg --color=debug log -T status -C -r 10 --quiet
  [log.node|10:0f9759ec227a]

Check the bisect template

  $ hg bisect -g 1
  $ hg bisect -b 3 --noupdate
  Testing changeset 2:97054abb4ab8 (2 changesets remaining, ~1 tests)
  $ hg log -T bisect -r 0:4
  changeset:   0:1e4e1b8f71e0
  bisect:      good (implicit)
  user:        User Name <user@hostname>
  date:        Mon Jan 12 13:46:40 1970 +0000
  summary:     line 1
  
  changeset:   1:b608e9d1a3f0
  bisect:      good
  user:        A. N. Other <other@place>
  date:        Tue Jan 13 17:33:20 1970 +0000
  summary:     other 1
  
  changeset:   2:97054abb4ab8
  bisect:      untested
  user:        other@place
  date:        Wed Jan 14 21:20:00 1970 +0000
  summary:     no person
  
  changeset:   3:10e46f2dcbf4
  bisect:      bad
  user:        person
  date:        Fri Jan 16 01:06:40 1970 +0000
  summary:     no user, no domain
  
  changeset:   4:bbe44766e73d
  bisect:      bad (implicit)
  branch:      foo
  user:        person
  date:        Sat Jan 17 04:53:20 1970 +0000
  summary:     new branch
  
  $ hg log --debug -T bisect -r 0:4
  changeset:   0:1e4e1b8f71e05681d422154f5421e385fec3454f
  bisect:      good (implicit)
  phase:       public
  parent:      -1:0000000000000000000000000000000000000000
  parent:      -1:0000000000000000000000000000000000000000
  manifest:    0:a0c8bcbbb45c63b90b70ad007bf38961f64f2af0
  user:        User Name <user@hostname>
  date:        Mon Jan 12 13:46:40 1970 +0000
  files+:      a
  extra:       branch=default
  description:
  line 1
  line 2
  
  
  changeset:   1:b608e9d1a3f0273ccf70fb85fd6866b3482bf965
  bisect:      good
  phase:       public
  parent:      0:1e4e1b8f71e05681d422154f5421e385fec3454f
  parent:      -1:0000000000000000000000000000000000000000
  manifest:    1:4e8d705b1e53e3f9375e0e60dc7b525d8211fe55
  user:        A. N. Other <other@place>
  date:        Tue Jan 13 17:33:20 1970 +0000
  files+:      b
  extra:       branch=default
  description:
  other 1
  other 2
  
  other 3
  
  
  changeset:   2:97054abb4ab824450e9164180baf491ae0078465
  bisect:      untested
  phase:       public
  parent:      1:b608e9d1a3f0273ccf70fb85fd6866b3482bf965
  parent:      -1:0000000000000000000000000000000000000000
  manifest:    2:6e0e82995c35d0d57a52aca8da4e56139e06b4b1
  user:        other@place
  date:        Wed Jan 14 21:20:00 1970 +0000
  files+:      c
  extra:       branch=default
  description:
  no person
  
  
  changeset:   3:10e46f2dcbf4823578cf180f33ecf0b957964c47
  bisect:      bad
  phase:       public
  parent:      2:97054abb4ab824450e9164180baf491ae0078465
  parent:      -1:0000000000000000000000000000000000000000
  manifest:    3:cb5a1327723bada42f117e4c55a303246eaf9ccc
  user:        person
  date:        Fri Jan 16 01:06:40 1970 +0000
  files:       c
  extra:       branch=default
  description:
  no user, no domain
  
  
  changeset:   4:bbe44766e73d5f11ed2177f1838de10c53ef3e74
  bisect:      bad (implicit)
  branch:      foo
  phase:       draft
  parent:      3:10e46f2dcbf4823578cf180f33ecf0b957964c47
  parent:      -1:0000000000000000000000000000000000000000
  manifest:    3:cb5a1327723bada42f117e4c55a303246eaf9ccc
  user:        person
  date:        Sat Jan 17 04:53:20 1970 +0000
  extra:       branch=foo
  description:
  new branch
  
  
  $ hg log -v -T bisect -r 0:4
  changeset:   0:1e4e1b8f71e0
  bisect:      good (implicit)
  user:        User Name <user@hostname>
  date:        Mon Jan 12 13:46:40 1970 +0000
  files:       a
  description:
  line 1
  line 2
  
  
  changeset:   1:b608e9d1a3f0
  bisect:      good
  user:        A. N. Other <other@place>
  date:        Tue Jan 13 17:33:20 1970 +0000
  files:       b
  description:
  other 1
  other 2
  
  other 3
  
  
  changeset:   2:97054abb4ab8
  bisect:      untested
  user:        other@place
  date:        Wed Jan 14 21:20:00 1970 +0000
  files:       c
  description:
  no person
  
  
  changeset:   3:10e46f2dcbf4
  bisect:      bad
  user:        person
  date:        Fri Jan 16 01:06:40 1970 +0000
  files:       c
  description:
  no user, no domain
  
  
  changeset:   4:bbe44766e73d
  bisect:      bad (implicit)
  branch:      foo
  user:        person
  date:        Sat Jan 17 04:53:20 1970 +0000
  description:
  new branch
  
  
  $ hg --color=debug log -T bisect -r 0:4
  [log.changeset changeset.public|changeset:   0:1e4e1b8f71e0]
  [log.bisect bisect.good|bisect:      good (implicit)]
  [log.user|user:        User Name <user@hostname>]
  [log.date|date:        Mon Jan 12 13:46:40 1970 +0000]
  [log.summary|summary:     line 1]
  
  [log.changeset changeset.public|changeset:   1:b608e9d1a3f0]
  [log.bisect bisect.good|bisect:      good]
  [log.user|user:        A. N. Other <other@place>]
  [log.date|date:        Tue Jan 13 17:33:20 1970 +0000]
  [log.summary|summary:     other 1]
  
  [log.changeset changeset.public|changeset:   2:97054abb4ab8]
  [log.bisect bisect.untested|bisect:      untested]
  [log.user|user:        other@place]
  [log.date|date:        Wed Jan 14 21:20:00 1970 +0000]
  [log.summary|summary:     no person]
  
  [log.changeset changeset.public|changeset:   3:10e46f2dcbf4]
  [log.bisect bisect.bad|bisect:      bad]
  [log.user|user:        person]
  [log.date|date:        Fri Jan 16 01:06:40 1970 +0000]
  [log.summary|summary:     no user, no domain]
  
  [log.changeset changeset.draft|changeset:   4:bbe44766e73d]
  [log.bisect bisect.bad|bisect:      bad (implicit)]
  [log.branch|branch:      foo]
  [log.user|user:        person]
  [log.date|date:        Sat Jan 17 04:53:20 1970 +0000]
  [log.summary|summary:     new branch]
  
  $ hg --color=debug log --debug -T bisect -r 0:4
  [log.changeset changeset.public|changeset:   0:1e4e1b8f71e05681d422154f5421e385fec3454f]
  [log.bisect bisect.good|bisect:      good (implicit)]
  [log.phase|phase:       public]
  [log.parent changeset.public|parent:      -1:0000000000000000000000000000000000000000]
  [log.parent changeset.public|parent:      -1:0000000000000000000000000000000000000000]
  [ui.debug log.manifest|manifest:    0:a0c8bcbbb45c63b90b70ad007bf38961f64f2af0]
  [log.user|user:        User Name <user@hostname>]
  [log.date|date:        Mon Jan 12 13:46:40 1970 +0000]
  [ui.debug log.files|files+:      a]
  [ui.debug log.extra|extra:       branch=default]
  [ui.note log.description|description:]
  [ui.note log.description|line 1
  line 2]
  
  
  [log.changeset changeset.public|changeset:   1:b608e9d1a3f0273ccf70fb85fd6866b3482bf965]
  [log.bisect bisect.good|bisect:      good]
  [log.phase|phase:       public]
  [log.parent changeset.public|parent:      0:1e4e1b8f71e05681d422154f5421e385fec3454f]
  [log.parent changeset.public|parent:      -1:0000000000000000000000000000000000000000]
  [ui.debug log.manifest|manifest:    1:4e8d705b1e53e3f9375e0e60dc7b525d8211fe55]
  [log.user|user:        A. N. Other <other@place>]
  [log.date|date:        Tue Jan 13 17:33:20 1970 +0000]
  [ui.debug log.files|files+:      b]
  [ui.debug log.extra|extra:       branch=default]
  [ui.note log.description|description:]
  [ui.note log.description|other 1
  other 2
  
  other 3]
  
  
  [log.changeset changeset.public|changeset:   2:97054abb4ab824450e9164180baf491ae0078465]
  [log.bisect bisect.untested|bisect:      untested]
  [log.phase|phase:       public]
  [log.parent changeset.public|parent:      1:b608e9d1a3f0273ccf70fb85fd6866b3482bf965]
  [log.parent changeset.public|parent:      -1:0000000000000000000000000000000000000000]
  [ui.debug log.manifest|manifest:    2:6e0e82995c35d0d57a52aca8da4e56139e06b4b1]
  [log.user|user:        other@place]
  [log.date|date:        Wed Jan 14 21:20:00 1970 +0000]
  [ui.debug log.files|files+:      c]
  [ui.debug log.extra|extra:       branch=default]
  [ui.note log.description|description:]
  [ui.note log.description|no person]
  
  
  [log.changeset changeset.public|changeset:   3:10e46f2dcbf4823578cf180f33ecf0b957964c47]
  [log.bisect bisect.bad|bisect:      bad]
  [log.phase|phase:       public]
  [log.parent changeset.public|parent:      2:97054abb4ab824450e9164180baf491ae0078465]
  [log.parent changeset.public|parent:      -1:0000000000000000000000000000000000000000]
  [ui.debug log.manifest|manifest:    3:cb5a1327723bada42f117e4c55a303246eaf9ccc]
  [log.user|user:        person]
  [log.date|date:        Fri Jan 16 01:06:40 1970 +0000]
  [ui.debug log.files|files:       c]
  [ui.debug log.extra|extra:       branch=default]
  [ui.note log.description|description:]
  [ui.note log.description|no user, no domain]
  
  
  [log.changeset changeset.draft|changeset:   4:bbe44766e73d5f11ed2177f1838de10c53ef3e74]
  [log.bisect bisect.bad|bisect:      bad (implicit)]
  [log.branch|branch:      foo]
  [log.phase|phase:       draft]
  [log.parent changeset.public|parent:      3:10e46f2dcbf4823578cf180f33ecf0b957964c47]
  [log.parent changeset.public|parent:      -1:0000000000000000000000000000000000000000]
  [ui.debug log.manifest|manifest:    3:cb5a1327723bada42f117e4c55a303246eaf9ccc]
  [log.user|user:        person]
  [log.date|date:        Sat Jan 17 04:53:20 1970 +0000]
  [ui.debug log.extra|extra:       branch=foo]
  [ui.note log.description|description:]
  [ui.note log.description|new branch]
  
  
  $ hg --color=debug log -v -T bisect -r 0:4
  [log.changeset changeset.public|changeset:   0:1e4e1b8f71e0]
  [log.bisect bisect.good|bisect:      good (implicit)]
  [log.user|user:        User Name <user@hostname>]
  [log.date|date:        Mon Jan 12 13:46:40 1970 +0000]
  [ui.note log.files|files:       a]
  [ui.note log.description|description:]
  [ui.note log.description|line 1
  line 2]
  
  
  [log.changeset changeset.public|changeset:   1:b608e9d1a3f0]
  [log.bisect bisect.good|bisect:      good]
  [log.user|user:        A. N. Other <other@place>]
  [log.date|date:        Tue Jan 13 17:33:20 1970 +0000]
  [ui.note log.files|files:       b]
  [ui.note log.description|description:]
  [ui.note log.description|other 1
  other 2
  
  other 3]
  
  
  [log.changeset changeset.public|changeset:   2:97054abb4ab8]
  [log.bisect bisect.untested|bisect:      untested]
  [log.user|user:        other@place]
  [log.date|date:        Wed Jan 14 21:20:00 1970 +0000]
  [ui.note log.files|files:       c]
  [ui.note log.description|description:]
  [ui.note log.description|no person]
  
  
  [log.changeset changeset.public|changeset:   3:10e46f2dcbf4]
  [log.bisect bisect.bad|bisect:      bad]
  [log.user|user:        person]
  [log.date|date:        Fri Jan 16 01:06:40 1970 +0000]
  [ui.note log.files|files:       c]
  [ui.note log.description|description:]
  [ui.note log.description|no user, no domain]
  
  
  [log.changeset changeset.draft|changeset:   4:bbe44766e73d]
  [log.bisect bisect.bad|bisect:      bad (implicit)]
  [log.branch|branch:      foo]
  [log.user|user:        person]
  [log.date|date:        Sat Jan 17 04:53:20 1970 +0000]
  [ui.note log.description|description:]
  [ui.note log.description|new branch]
  
  
  $ hg bisect --reset

  $ cd ..

Set up latesttag repository:

  $ hg init latesttag
  $ cd latesttag

  $ echo a > file
  $ hg ci -Am a -d '0 0'
  adding file

  $ echo b >> file
  $ hg ci -m b -d '1 0'

  $ echo c >> head1
  $ hg ci -Am h1c -d '2 0'
  adding head1

  $ hg update -q 1
  $ echo d >> head2
  $ hg ci -Am h2d -d '3 0'
  adding head2
  created new head

  $ echo e >> head2
  $ hg ci -m h2e -d '4 0'

  $ hg merge -q
  $ hg ci -m merge -d '5 -3600'

  $ hg tag -r 1 -m t1 -d '6 0' t1
  $ hg tag -r 2 -m t2 -d '7 0' t2
  $ hg tag -r 3 -m t3 -d '8 0' t3
  $ hg tag -r 4 -m t4 -d '4 0' t4 # older than t2, but should not matter
  $ hg tag -r 5 -m t5 -d '9 0' t5
  $ hg tag -r 3 -m at3 -d '10 0' at3

  $ cd ..

Style path expansion: issue1948 - ui.style option doesn't work on OSX
if it is a relative path

  $ mkdir -p home/styles

  $ cat > home/styles/teststyle <<EOF
  > changeset = 'test {rev}:{node|short}\n'
  > EOF

  $ HOME=`pwd`/home; export HOME

  $ cat > latesttag/.hg/hgrc <<EOF
  > [ui]
  > style = ~/styles/teststyle
  > EOF

  $ hg -R latesttag tip
  test 11:97e5943b523a

Test recursive showlist template (issue1989):

  $ cat > style1989 <<EOF
  > changeset = '{file_mods}{manifest}{extras}'
  > file_mod  = 'M|{author|person}\n'
  > manifest = '{rev},{author}\n'
  > extra = '{key}: {author}\n'
  > EOF

  $ hg -R latesttag log -r tip --style=style1989
  M|test
  11,test
  branch: test
