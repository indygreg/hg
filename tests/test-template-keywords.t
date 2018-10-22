Test template keywords
======================

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

Working-directory revision has special identifiers, though they are still
experimental:

  $ hg log -r 'wdir()' -T '{rev}:{node}\n'
  2147483647:ffffffffffffffffffffffffffffffffffffffff

  $ hg log -r 'wdir()' -Tjson --debug
  [
   {
    "added": [],
    "bookmarks": [],
    "branch": "default",
    "date": [0, 0],
    "desc": "",
    "extra": {"branch": "default"},
    "manifest": "ffffffffffffffffffffffffffffffffffffffff",
    "modified": [],
    "node": "ffffffffffffffffffffffffffffffffffffffff",
    "parents": ["95c24699272ef57d062b8bccc32c878bf841784a"],
    "phase": "draft",
    "removed": [],
    "rev": 2147483647,
    "tags": [],
    "user": "test"
   }
  ]

  $ hg log -r 'wdir()' -T '{manifest}\n'
  2147483647:ffffffffffff

Changectx-derived keywords are disabled within {manifest} as {node} changes:

  $ hg log -r0 -T 'outer:{p1node} {manifest % "inner:{p1node}"}\n'
  outer:0000000000000000000000000000000000000000 inner:

Check that {phase} works correctly on parents:

  $ cat << EOF > parentphase
  > changeset_debug = '{rev} ({phase}):{parents}\n'
  > parent = ' {rev} ({phase})'
  > EOF
  $ hg phase -r 5 --public
  $ hg phase -r 7 --secret --force
  $ hg log --debug -G --style ./parentphase
  @  8 (secret): 7 (secret) -1 (public)
  |
  o  7 (secret): -1 (public) -1 (public)
  
  o    6 (draft): 5 (public) 4 (draft)
  |\
  | o  5 (public): 3 (public) -1 (public)
  | |
  o |  4 (draft): 3 (public) -1 (public)
  |/
  o  3 (public): 2 (public) -1 (public)
  |
  o  2 (public): 1 (public) -1 (public)
  |
  o  1 (public): 0 (public) -1 (public)
  |
  o  0 (public): -1 (public) -1 (public)
  

Keys work:

  $ for key in author branch branches date desc file_adds file_dels file_mods \
  >         file_copies file_copies_switch files \
  >         manifest node parents rev tags diffstat extras \
  >         p1rev p2rev p1node p2node user; do
  >     for mode in '' --verbose --debug; do
  >         hg log $mode --template "$key$mode: {$key}\n"
  >     done
  > done
  author: test
  author: User Name <user@hostname>
  author: person
  author: person
  author: person
  author: person
  author: other@place
  author: A. N. Other <other@place>
  author: User Name <user@hostname>
  author--verbose: test
  author--verbose: User Name <user@hostname>
  author--verbose: person
  author--verbose: person
  author--verbose: person
  author--verbose: person
  author--verbose: other@place
  author--verbose: A. N. Other <other@place>
  author--verbose: User Name <user@hostname>
  author--debug: test
  author--debug: User Name <user@hostname>
  author--debug: person
  author--debug: person
  author--debug: person
  author--debug: person
  author--debug: other@place
  author--debug: A. N. Other <other@place>
  author--debug: User Name <user@hostname>
  branch: default
  branch: default
  branch: default
  branch: default
  branch: foo
  branch: default
  branch: default
  branch: default
  branch: default
  branch--verbose: default
  branch--verbose: default
  branch--verbose: default
  branch--verbose: default
  branch--verbose: foo
  branch--verbose: default
  branch--verbose: default
  branch--verbose: default
  branch--verbose: default
  branch--debug: default
  branch--debug: default
  branch--debug: default
  branch--debug: default
  branch--debug: foo
  branch--debug: default
  branch--debug: default
  branch--debug: default
  branch--debug: default
  branches: 
  branches: 
  branches: 
  branches: 
  branches: foo
  branches: 
  branches: 
  branches: 
  branches: 
  branches--verbose: 
  branches--verbose: 
  branches--verbose: 
  branches--verbose: 
  branches--verbose: foo
  branches--verbose: 
  branches--verbose: 
  branches--verbose: 
  branches--verbose: 
  branches--debug: 
  branches--debug: 
  branches--debug: 
  branches--debug: 
  branches--debug: foo
  branches--debug: 
  branches--debug: 
  branches--debug: 
  branches--debug: 
  date: 1577872860.00
  date: 1000000.00
  date: 1500001.00
  date: 1500000.00
  date: 1400000.00
  date: 1300000.00
  date: 1200000.00
  date: 1100000.00
  date: 1000000.00
  date--verbose: 1577872860.00
  date--verbose: 1000000.00
  date--verbose: 1500001.00
  date--verbose: 1500000.00
  date--verbose: 1400000.00
  date--verbose: 1300000.00
  date--verbose: 1200000.00
  date--verbose: 1100000.00
  date--verbose: 1000000.00
  date--debug: 1577872860.00
  date--debug: 1000000.00
  date--debug: 1500001.00
  date--debug: 1500000.00
  date--debug: 1400000.00
  date--debug: 1300000.00
  date--debug: 1200000.00
  date--debug: 1100000.00
  date--debug: 1000000.00
  desc: third
  desc: second
  desc: merge
  desc: new head
  desc: new branch
  desc: no user, no domain
  desc: no person
  desc: other 1
  other 2
  
  other 3
  desc: line 1
  line 2
  desc--verbose: third
  desc--verbose: second
  desc--verbose: merge
  desc--verbose: new head
  desc--verbose: new branch
  desc--verbose: no user, no domain
  desc--verbose: no person
  desc--verbose: other 1
  other 2
  
  other 3
  desc--verbose: line 1
  line 2
  desc--debug: third
  desc--debug: second
  desc--debug: merge
  desc--debug: new head
  desc--debug: new branch
  desc--debug: no user, no domain
  desc--debug: no person
  desc--debug: other 1
  other 2
  
  other 3
  desc--debug: line 1
  line 2
  file_adds: fourth third
  file_adds: second
  file_adds: 
  file_adds: d
  file_adds: 
  file_adds: 
  file_adds: c
  file_adds: b
  file_adds: a
  file_adds--verbose: fourth third
  file_adds--verbose: second
  file_adds--verbose: 
  file_adds--verbose: d
  file_adds--verbose: 
  file_adds--verbose: 
  file_adds--verbose: c
  file_adds--verbose: b
  file_adds--verbose: a
  file_adds--debug: fourth third
  file_adds--debug: second
  file_adds--debug: 
  file_adds--debug: d
  file_adds--debug: 
  file_adds--debug: 
  file_adds--debug: c
  file_adds--debug: b
  file_adds--debug: a
  file_dels: second
  file_dels: 
  file_dels: 
  file_dels: 
  file_dels: 
  file_dels: 
  file_dels: 
  file_dels: 
  file_dels: 
  file_dels--verbose: second
  file_dels--verbose: 
  file_dels--verbose: 
  file_dels--verbose: 
  file_dels--verbose: 
  file_dels--verbose: 
  file_dels--verbose: 
  file_dels--verbose: 
  file_dels--verbose: 
  file_dels--debug: second
  file_dels--debug: 
  file_dels--debug: 
  file_dels--debug: 
  file_dels--debug: 
  file_dels--debug: 
  file_dels--debug: 
  file_dels--debug: 
  file_dels--debug: 
  file_mods: 
  file_mods: 
  file_mods: 
  file_mods: 
  file_mods: 
  file_mods: c
  file_mods: 
  file_mods: 
  file_mods: 
  file_mods--verbose: 
  file_mods--verbose: 
  file_mods--verbose: 
  file_mods--verbose: 
  file_mods--verbose: 
  file_mods--verbose: c
  file_mods--verbose: 
  file_mods--verbose: 
  file_mods--verbose: 
  file_mods--debug: 
  file_mods--debug: 
  file_mods--debug: 
  file_mods--debug: 
  file_mods--debug: 
  file_mods--debug: c
  file_mods--debug: 
  file_mods--debug: 
  file_mods--debug: 
  file_copies: fourth (second)
  file_copies: 
  file_copies: 
  file_copies: 
  file_copies: 
  file_copies: 
  file_copies: 
  file_copies: 
  file_copies: 
  file_copies--verbose: fourth (second)
  file_copies--verbose: 
  file_copies--verbose: 
  file_copies--verbose: 
  file_copies--verbose: 
  file_copies--verbose: 
  file_copies--verbose: 
  file_copies--verbose: 
  file_copies--verbose: 
  file_copies--debug: fourth (second)
  file_copies--debug: 
  file_copies--debug: 
  file_copies--debug: 
  file_copies--debug: 
  file_copies--debug: 
  file_copies--debug: 
  file_copies--debug: 
  file_copies--debug: 
  file_copies_switch: 
  file_copies_switch: 
  file_copies_switch: 
  file_copies_switch: 
  file_copies_switch: 
  file_copies_switch: 
  file_copies_switch: 
  file_copies_switch: 
  file_copies_switch: 
  file_copies_switch--verbose: 
  file_copies_switch--verbose: 
  file_copies_switch--verbose: 
  file_copies_switch--verbose: 
  file_copies_switch--verbose: 
  file_copies_switch--verbose: 
  file_copies_switch--verbose: 
  file_copies_switch--verbose: 
  file_copies_switch--verbose: 
  file_copies_switch--debug: 
  file_copies_switch--debug: 
  file_copies_switch--debug: 
  file_copies_switch--debug: 
  file_copies_switch--debug: 
  file_copies_switch--debug: 
  file_copies_switch--debug: 
  file_copies_switch--debug: 
  file_copies_switch--debug: 
  files: fourth second third
  files: second
  files: 
  files: d
  files: 
  files: c
  files: c
  files: b
  files: a
  files--verbose: fourth second third
  files--verbose: second
  files--verbose: 
  files--verbose: d
  files--verbose: 
  files--verbose: c
  files--verbose: c
  files--verbose: b
  files--verbose: a
  files--debug: fourth second third
  files--debug: second
  files--debug: 
  files--debug: d
  files--debug: 
  files--debug: c
  files--debug: c
  files--debug: b
  files--debug: a
  manifest: 6:94961b75a2da
  manifest: 5:f2dbc354b94e
  manifest: 4:4dc3def4f9b4
  manifest: 4:4dc3def4f9b4
  manifest: 3:cb5a1327723b
  manifest: 3:cb5a1327723b
  manifest: 2:6e0e82995c35
  manifest: 1:4e8d705b1e53
  manifest: 0:a0c8bcbbb45c
  manifest--verbose: 6:94961b75a2da
  manifest--verbose: 5:f2dbc354b94e
  manifest--verbose: 4:4dc3def4f9b4
  manifest--verbose: 4:4dc3def4f9b4
  manifest--verbose: 3:cb5a1327723b
  manifest--verbose: 3:cb5a1327723b
  manifest--verbose: 2:6e0e82995c35
  manifest--verbose: 1:4e8d705b1e53
  manifest--verbose: 0:a0c8bcbbb45c
  manifest--debug: 6:94961b75a2da554b4df6fb599e5bfc7d48de0c64
  manifest--debug: 5:f2dbc354b94e5ec0b4f10680ee0cee816101d0bf
  manifest--debug: 4:4dc3def4f9b4c6e8de820f6ee74737f91e96a216
  manifest--debug: 4:4dc3def4f9b4c6e8de820f6ee74737f91e96a216
  manifest--debug: 3:cb5a1327723bada42f117e4c55a303246eaf9ccc
  manifest--debug: 3:cb5a1327723bada42f117e4c55a303246eaf9ccc
  manifest--debug: 2:6e0e82995c35d0d57a52aca8da4e56139e06b4b1
  manifest--debug: 1:4e8d705b1e53e3f9375e0e60dc7b525d8211fe55
  manifest--debug: 0:a0c8bcbbb45c63b90b70ad007bf38961f64f2af0
  node: 95c24699272ef57d062b8bccc32c878bf841784a
  node: 29114dbae42b9f078cf2714dbe3a86bba8ec7453
  node: d41e714fe50d9e4a5f11b4d595d543481b5f980b
  node: 13207e5a10d9fd28ec424934298e176197f2c67f
  node: bbe44766e73d5f11ed2177f1838de10c53ef3e74
  node: 10e46f2dcbf4823578cf180f33ecf0b957964c47
  node: 97054abb4ab824450e9164180baf491ae0078465
  node: b608e9d1a3f0273ccf70fb85fd6866b3482bf965
  node: 1e4e1b8f71e05681d422154f5421e385fec3454f
  node--verbose: 95c24699272ef57d062b8bccc32c878bf841784a
  node--verbose: 29114dbae42b9f078cf2714dbe3a86bba8ec7453
  node--verbose: d41e714fe50d9e4a5f11b4d595d543481b5f980b
  node--verbose: 13207e5a10d9fd28ec424934298e176197f2c67f
  node--verbose: bbe44766e73d5f11ed2177f1838de10c53ef3e74
  node--verbose: 10e46f2dcbf4823578cf180f33ecf0b957964c47
  node--verbose: 97054abb4ab824450e9164180baf491ae0078465
  node--verbose: b608e9d1a3f0273ccf70fb85fd6866b3482bf965
  node--verbose: 1e4e1b8f71e05681d422154f5421e385fec3454f
  node--debug: 95c24699272ef57d062b8bccc32c878bf841784a
  node--debug: 29114dbae42b9f078cf2714dbe3a86bba8ec7453
  node--debug: d41e714fe50d9e4a5f11b4d595d543481b5f980b
  node--debug: 13207e5a10d9fd28ec424934298e176197f2c67f
  node--debug: bbe44766e73d5f11ed2177f1838de10c53ef3e74
  node--debug: 10e46f2dcbf4823578cf180f33ecf0b957964c47
  node--debug: 97054abb4ab824450e9164180baf491ae0078465
  node--debug: b608e9d1a3f0273ccf70fb85fd6866b3482bf965
  node--debug: 1e4e1b8f71e05681d422154f5421e385fec3454f
  parents: 
  parents: -1:000000000000 
  parents: 5:13207e5a10d9 4:bbe44766e73d 
  parents: 3:10e46f2dcbf4 
  parents: 
  parents: 
  parents: 
  parents: 
  parents: 
  parents--verbose: 
  parents--verbose: -1:000000000000 
  parents--verbose: 5:13207e5a10d9 4:bbe44766e73d 
  parents--verbose: 3:10e46f2dcbf4 
  parents--verbose: 
  parents--verbose: 
  parents--verbose: 
  parents--verbose: 
  parents--verbose: 
  parents--debug: 7:29114dbae42b9f078cf2714dbe3a86bba8ec7453 -1:0000000000000000000000000000000000000000 
  parents--debug: -1:0000000000000000000000000000000000000000 -1:0000000000000000000000000000000000000000 
  parents--debug: 5:13207e5a10d9fd28ec424934298e176197f2c67f 4:bbe44766e73d5f11ed2177f1838de10c53ef3e74 
  parents--debug: 3:10e46f2dcbf4823578cf180f33ecf0b957964c47 -1:0000000000000000000000000000000000000000 
  parents--debug: 3:10e46f2dcbf4823578cf180f33ecf0b957964c47 -1:0000000000000000000000000000000000000000 
  parents--debug: 2:97054abb4ab824450e9164180baf491ae0078465 -1:0000000000000000000000000000000000000000 
  parents--debug: 1:b608e9d1a3f0273ccf70fb85fd6866b3482bf965 -1:0000000000000000000000000000000000000000 
  parents--debug: 0:1e4e1b8f71e05681d422154f5421e385fec3454f -1:0000000000000000000000000000000000000000 
  parents--debug: -1:0000000000000000000000000000000000000000 -1:0000000000000000000000000000000000000000 
  rev: 8
  rev: 7
  rev: 6
  rev: 5
  rev: 4
  rev: 3
  rev: 2
  rev: 1
  rev: 0
  rev--verbose: 8
  rev--verbose: 7
  rev--verbose: 6
  rev--verbose: 5
  rev--verbose: 4
  rev--verbose: 3
  rev--verbose: 2
  rev--verbose: 1
  rev--verbose: 0
  rev--debug: 8
  rev--debug: 7
  rev--debug: 6
  rev--debug: 5
  rev--debug: 4
  rev--debug: 3
  rev--debug: 2
  rev--debug: 1
  rev--debug: 0
  tags: tip
  tags: 
  tags: 
  tags: 
  tags: 
  tags: 
  tags: 
  tags: 
  tags: 
  tags--verbose: tip
  tags--verbose: 
  tags--verbose: 
  tags--verbose: 
  tags--verbose: 
  tags--verbose: 
  tags--verbose: 
  tags--verbose: 
  tags--verbose: 
  tags--debug: tip
  tags--debug: 
  tags--debug: 
  tags--debug: 
  tags--debug: 
  tags--debug: 
  tags--debug: 
  tags--debug: 
  tags--debug: 
  diffstat: 3: +2/-1
  diffstat: 1: +1/-0
  diffstat: 0: +0/-0
  diffstat: 1: +1/-0
  diffstat: 0: +0/-0
  diffstat: 1: +1/-0
  diffstat: 1: +4/-0
  diffstat: 1: +2/-0
  diffstat: 1: +1/-0
  diffstat--verbose: 3: +2/-1
  diffstat--verbose: 1: +1/-0
  diffstat--verbose: 0: +0/-0
  diffstat--verbose: 1: +1/-0
  diffstat--verbose: 0: +0/-0
  diffstat--verbose: 1: +1/-0
  diffstat--verbose: 1: +4/-0
  diffstat--verbose: 1: +2/-0
  diffstat--verbose: 1: +1/-0
  diffstat--debug: 3: +2/-1
  diffstat--debug: 1: +1/-0
  diffstat--debug: 0: +0/-0
  diffstat--debug: 1: +1/-0
  diffstat--debug: 0: +0/-0
  diffstat--debug: 1: +1/-0
  diffstat--debug: 1: +4/-0
  diffstat--debug: 1: +2/-0
  diffstat--debug: 1: +1/-0
  extras: branch=default
  extras: branch=default
  extras: branch=default
  extras: branch=default
  extras: branch=foo
  extras: branch=default
  extras: branch=default
  extras: branch=default
  extras: branch=default
  extras--verbose: branch=default
  extras--verbose: branch=default
  extras--verbose: branch=default
  extras--verbose: branch=default
  extras--verbose: branch=foo
  extras--verbose: branch=default
  extras--verbose: branch=default
  extras--verbose: branch=default
  extras--verbose: branch=default
  extras--debug: branch=default
  extras--debug: branch=default
  extras--debug: branch=default
  extras--debug: branch=default
  extras--debug: branch=foo
  extras--debug: branch=default
  extras--debug: branch=default
  extras--debug: branch=default
  extras--debug: branch=default
  p1rev: 7
  p1rev: -1
  p1rev: 5
  p1rev: 3
  p1rev: 3
  p1rev: 2
  p1rev: 1
  p1rev: 0
  p1rev: -1
  p1rev--verbose: 7
  p1rev--verbose: -1
  p1rev--verbose: 5
  p1rev--verbose: 3
  p1rev--verbose: 3
  p1rev--verbose: 2
  p1rev--verbose: 1
  p1rev--verbose: 0
  p1rev--verbose: -1
  p1rev--debug: 7
  p1rev--debug: -1
  p1rev--debug: 5
  p1rev--debug: 3
  p1rev--debug: 3
  p1rev--debug: 2
  p1rev--debug: 1
  p1rev--debug: 0
  p1rev--debug: -1
  p2rev: -1
  p2rev: -1
  p2rev: 4
  p2rev: -1
  p2rev: -1
  p2rev: -1
  p2rev: -1
  p2rev: -1
  p2rev: -1
  p2rev--verbose: -1
  p2rev--verbose: -1
  p2rev--verbose: 4
  p2rev--verbose: -1
  p2rev--verbose: -1
  p2rev--verbose: -1
  p2rev--verbose: -1
  p2rev--verbose: -1
  p2rev--verbose: -1
  p2rev--debug: -1
  p2rev--debug: -1
  p2rev--debug: 4
  p2rev--debug: -1
  p2rev--debug: -1
  p2rev--debug: -1
  p2rev--debug: -1
  p2rev--debug: -1
  p2rev--debug: -1
  p1node: 29114dbae42b9f078cf2714dbe3a86bba8ec7453
  p1node: 0000000000000000000000000000000000000000
  p1node: 13207e5a10d9fd28ec424934298e176197f2c67f
  p1node: 10e46f2dcbf4823578cf180f33ecf0b957964c47
  p1node: 10e46f2dcbf4823578cf180f33ecf0b957964c47
  p1node: 97054abb4ab824450e9164180baf491ae0078465
  p1node: b608e9d1a3f0273ccf70fb85fd6866b3482bf965
  p1node: 1e4e1b8f71e05681d422154f5421e385fec3454f
  p1node: 0000000000000000000000000000000000000000
  p1node--verbose: 29114dbae42b9f078cf2714dbe3a86bba8ec7453
  p1node--verbose: 0000000000000000000000000000000000000000
  p1node--verbose: 13207e5a10d9fd28ec424934298e176197f2c67f
  p1node--verbose: 10e46f2dcbf4823578cf180f33ecf0b957964c47
  p1node--verbose: 10e46f2dcbf4823578cf180f33ecf0b957964c47
  p1node--verbose: 97054abb4ab824450e9164180baf491ae0078465
  p1node--verbose: b608e9d1a3f0273ccf70fb85fd6866b3482bf965
  p1node--verbose: 1e4e1b8f71e05681d422154f5421e385fec3454f
  p1node--verbose: 0000000000000000000000000000000000000000
  p1node--debug: 29114dbae42b9f078cf2714dbe3a86bba8ec7453
  p1node--debug: 0000000000000000000000000000000000000000
  p1node--debug: 13207e5a10d9fd28ec424934298e176197f2c67f
  p1node--debug: 10e46f2dcbf4823578cf180f33ecf0b957964c47
  p1node--debug: 10e46f2dcbf4823578cf180f33ecf0b957964c47
  p1node--debug: 97054abb4ab824450e9164180baf491ae0078465
  p1node--debug: b608e9d1a3f0273ccf70fb85fd6866b3482bf965
  p1node--debug: 1e4e1b8f71e05681d422154f5421e385fec3454f
  p1node--debug: 0000000000000000000000000000000000000000
  p2node: 0000000000000000000000000000000000000000
  p2node: 0000000000000000000000000000000000000000
  p2node: bbe44766e73d5f11ed2177f1838de10c53ef3e74
  p2node: 0000000000000000000000000000000000000000
  p2node: 0000000000000000000000000000000000000000
  p2node: 0000000000000000000000000000000000000000
  p2node: 0000000000000000000000000000000000000000
  p2node: 0000000000000000000000000000000000000000
  p2node: 0000000000000000000000000000000000000000
  p2node--verbose: 0000000000000000000000000000000000000000
  p2node--verbose: 0000000000000000000000000000000000000000
  p2node--verbose: bbe44766e73d5f11ed2177f1838de10c53ef3e74
  p2node--verbose: 0000000000000000000000000000000000000000
  p2node--verbose: 0000000000000000000000000000000000000000
  p2node--verbose: 0000000000000000000000000000000000000000
  p2node--verbose: 0000000000000000000000000000000000000000
  p2node--verbose: 0000000000000000000000000000000000000000
  p2node--verbose: 0000000000000000000000000000000000000000
  p2node--debug: 0000000000000000000000000000000000000000
  p2node--debug: 0000000000000000000000000000000000000000
  p2node--debug: bbe44766e73d5f11ed2177f1838de10c53ef3e74
  p2node--debug: 0000000000000000000000000000000000000000
  p2node--debug: 0000000000000000000000000000000000000000
  p2node--debug: 0000000000000000000000000000000000000000
  p2node--debug: 0000000000000000000000000000000000000000
  p2node--debug: 0000000000000000000000000000000000000000
  p2node--debug: 0000000000000000000000000000000000000000
  user: test
  user: User Name <user@hostname>
  user: person
  user: person
  user: person
  user: person
  user: other@place
  user: A. N. Other <other@place>
  user: User Name <user@hostname>
  user--verbose: test
  user--verbose: User Name <user@hostname>
  user--verbose: person
  user--verbose: person
  user--verbose: person
  user--verbose: person
  user--verbose: other@place
  user--verbose: A. N. Other <other@place>
  user--verbose: User Name <user@hostname>
  user--debug: test
  user--debug: User Name <user@hostname>
  user--debug: person
  user--debug: person
  user--debug: person
  user--debug: person
  user--debug: other@place
  user--debug: A. N. Other <other@place>
  user--debug: User Name <user@hostname>

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

Test files list:

  $ hg log -l1 -T '{join(file_mods, " ")}\n'
  third
  $ hg log -l1 -T '{file_mods % "{file}\n"}'
  third
  $ hg log -l1 -T '{file_mods % "{path}\n"}'
  third

  $ hg log -l1 -T '{join(files, " ")}\n'
  a b fifth fourth third
  $ hg log -l1 -T '{files % "{file}\n"}'
  a
  b
  fifth
  fourth
  third
  $ hg log -l1 -T '{files % "{path}\n"}'
  a
  b
  fifth
  fourth
  third

Test file copies dict:

  $ hg log -r8 -T '{join(file_copies, " ")}\n'
  fourth (second)
  $ hg log -r8 -T '{file_copies % "{name} <- {source}\n"}'
  fourth <- second
  $ hg log -r8 -T '{file_copies % "{path} <- {source}\n"}'
  fourth <- second

  $ hg log -r8 -T '{join(file_copies_switch, " ")}\n'
  
  $ hg log -r8 -C -T '{join(file_copies_switch, " ")}\n'
  fourth (second)
  $ hg log -r8 -C -T '{file_copies_switch % "{name} <- {source}\n"}'
  fourth <- second
  $ hg log -r8 -C -T '{file_copies_switch % "{path} <- {source}\n"}'
  fourth <- second

Test file attributes:

  $ hg log -l1 -T '{files % "{status} {pad(size, 3, left=True)} {path}\n"}'
  R     a
  A   0 b
  A   7 fifth
  R     fourth
  M  13 third

Test file status including clean ones:

  $ hg log -r9 -T '{files("**") % "{status} {path}\n"}'
  A a
  C fourth
  C third

Test index keyword:

  $ hg log -l 2 -T '{index + 10}{files % " {index}:{file}"}\n'
  10 0:a 1:b 2:fifth 3:fourth 4:third
  11 0:a

  $ hg branches -T '{index} {branch}\n'
  0 default
  1 foo

ui verbosity:

  $ hg log -l1 -T '{verbosity}\n'
  
  $ hg log -l1 -T '{verbosity}\n' --debug
  debug
  $ hg log -l1 -T '{verbosity}\n' --quiet
  quiet
  $ hg log -l1 -T '{verbosity}\n' --verbose
  verbose

  $ cd ..

latesttag:

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

No tag set:

  $ hg log -G --template '{rev}: {latesttag}+{latesttagdistance}\n'
  @    5: null+5
  |\
  | o  4: null+4
  | |
  | o  3: null+3
  | |
  o |  2: null+3
  |/
  o  1: null+2
  |
  o  0: null+1
  

One common tag: longest path wins for {latesttagdistance}:

  $ hg tag -r 1 -m t1 -d '6 0' t1
  $ hg log -G --template '{rev}: {latesttag}+{latesttagdistance}\n'
  @  6: t1+4
  |
  o    5: t1+3
  |\
  | o  4: t1+2
  | |
  | o  3: t1+1
  | |
  o |  2: t1+1
  |/
  o  1: t1+0
  |
  o  0: null+1
  

One ancestor tag: closest wins:

  $ hg tag -r 2 -m t2 -d '7 0' t2
  $ hg log -G --template '{rev}: {latesttag}+{latesttagdistance}\n'
  @  7: t2+3
  |
  o  6: t2+2
  |
  o    5: t2+1
  |\
  | o  4: t1+2
  | |
  | o  3: t1+1
  | |
  o |  2: t2+0
  |/
  o  1: t1+0
  |
  o  0: null+1
  

Two branch tags: more recent wins if same number of changes:

  $ hg tag -r 3 -m t3 -d '8 0' t3
  $ hg log -G --template '{rev}: {latesttag}+{latesttagdistance}\n'
  @  8: t3+5
  |
  o  7: t3+4
  |
  o  6: t3+3
  |
  o    5: t3+2
  |\
  | o  4: t3+1
  | |
  | o  3: t3+0
  | |
  o |  2: t2+0
  |/
  o  1: t1+0
  |
  o  0: null+1
  

Two branch tags: fewest changes wins:

  $ hg tag -r 4 -m t4 -d '4 0' t4 # older than t2, but should not matter
  $ hg log -G --template "{rev}: {latesttag % '{tag}+{distance},{changes} '}\n"
  @  9: t4+5,6
  |
  o  8: t4+4,5
  |
  o  7: t4+3,4
  |
  o  6: t4+2,3
  |
  o    5: t4+1,2
  |\
  | o  4: t4+0,0
  | |
  | o  3: t3+0,0
  | |
  o |  2: t2+0,0
  |/
  o  1: t1+0,0
  |
  o  0: null+1,1
  

Merged tag overrides:

  $ hg tag -r 5 -m t5 -d '9 0' t5
  $ hg tag -r 3 -m at3 -d '10 0' at3
  $ hg log -G --template '{rev}: {latesttag}+{latesttagdistance}\n'
  @  11: t5+6
  |
  o  10: t5+5
  |
  o  9: t5+4
  |
  o  8: t5+3
  |
  o  7: t5+2
  |
  o  6: t5+1
  |
  o    5: t5+0
  |\
  | o  4: t4+0
  | |
  | o  3: at3:t3+0
  | |
  o |  2: t2+0
  |/
  o  1: t1+0
  |
  o  0: null+1
  

  $ hg log -G --template "{rev}: {latesttag % '{tag}+{distance},{changes} '}\n"
  @  11: t5+6,6
  |
  o  10: t5+5,5
  |
  o  9: t5+4,4
  |
  o  8: t5+3,3
  |
  o  7: t5+2,2
  |
  o  6: t5+1,1
  |
  o    5: t5+0,0
  |\
  | o  4: t4+0,0
  | |
  | o  3: at3+0,0 t3+0,0
  | |
  o |  2: t2+0,0
  |/
  o  1: t1+0,0
  |
  o  0: null+1,1
  

  $ cd ..

Set up repository containing template fragments in commit metadata:

  $ hg init r
  $ cd r
  $ echo a > a
  $ hg ci -Am '{rev}'
  adding a

  $ hg branch -q 'text.{rev}'
  $ echo aa >> aa
  $ hg ci -u '{node|short}' -m 'desc to be wrapped desc to be wrapped'

Test termwidth:

  $ COLUMNS=25 hg log -l1 --template '{fill(desc, termwidth, "{node|short}:", "termwidth.{rev}:")}'
  bcc7ff960b8e:desc to be
  termwidth.1:wrapped desc
  termwidth.1:to be wrapped (no-eol)

Just one more commit:

  $ echo b > b
  $ hg ci -qAm b

Test 'originalnode'

  $ hg log -r 1 -T '{revset("null") % "{node|short} {originalnode|short}"}\n'
  000000000000 bcc7ff960b8e
  $ hg log -r 0 -T '{manifest % "{node} {originalnode}"}\n'
  a0c8bcbbb45c63b90b70ad007bf38961f64f2af0 f7769ec2ab975ad19684098ad1ffd9b81ecc71a1

Test active bookmark templating

  $ hg book foo
  $ hg book bar
  $ hg log --template "{rev} {bookmarks % '{bookmark}{ifeq(bookmark, active, \"*\")} '}\n"
  2 bar* foo 
  1 
  0 
  $ hg log --template "{rev} {activebookmark}\n"
  2 bar
  1 
  0 
  $ hg bookmarks --inactive bar
  $ hg log --template "{rev} {activebookmark}\n"
  2 
  1 
  0 
  $ hg book -r1 baz
  $ hg log --template "{rev} {join(bookmarks, ' ')}\n"
  2 bar foo
  1 baz
  0 
  $ hg log --template "{rev} {ifcontains('foo', bookmarks, 't', 'f')}\n"
  2 t
  1 f
  0 f

Test namespaces dict

  $ hg --config extensions.revnamesext=$TESTDIR/revnamesext.py log -T '{rev}\n{namespaces % " {namespace} color={colorname} builtin={builtin}\n  {join(names, ",")}\n"}\n'
  2
   bookmarks color=bookmark builtin=True
    bar,foo
   tags color=tag builtin=True
    tip
   branches color=branch builtin=True
    text.{rev}
   revnames color=revname builtin=False
    r2
  
  1
   bookmarks color=bookmark builtin=True
    baz
   tags color=tag builtin=True
    
   branches color=branch builtin=True
    text.{rev}
   revnames color=revname builtin=False
    r1
  
  0
   bookmarks color=bookmark builtin=True
    
   tags color=tag builtin=True
    
   branches color=branch builtin=True
    default
   revnames color=revname builtin=False
    r0
  
  $ hg log -r2 -T '{namespaces % "{namespace}: {names}\n"}'
  bookmarks: bar foo
  tags: tip
  branches: text.{rev}
  $ hg log -r2 -T '{namespaces % "{namespace}:\n{names % " {name}\n"}"}'
  bookmarks:
   bar
   foo
  tags:
   tip
  branches:
   text.{rev}
  $ hg log -r2 -T '{get(namespaces, "bookmarks") % "{name}\n"}'
  bar
  foo
  $ hg log -r2 -T '{namespaces.bookmarks % "{bookmark}\n"}'
  bar
  foo

  $ cd ..

Test 'graphwidth' in 'hg log' on various topologies. The key here is that the
printed graphwidths 3, 5, 7, etc. should all line up in their respective
columns. We don't care about other aspects of the graph rendering here.

  $ hg init graphwidth
  $ cd graphwidth

  $ wrappabletext="a a a a a a a a a a a a"

  $ printf "first\n" > file
  $ hg add file
  $ hg commit -m "$wrappabletext"

  $ printf "first\nsecond\n" > file
  $ hg commit -m "$wrappabletext"

  $ hg checkout 0
  1 files updated, 0 files merged, 0 files removed, 0 files unresolved
  $ printf "third\nfirst\n" > file
  $ hg commit -m "$wrappabletext"
  created new head

  $ hg merge
  merging file
  0 files updated, 1 files merged, 0 files removed, 0 files unresolved
  (branch merge, don't forget to commit)

  $ hg log --graph -T "{graphwidth}"
  @  3
  |
  | @  5
  |/
  o  3
  
  $ hg commit -m "$wrappabletext"

  $ hg log --graph -T "{graphwidth}"
  @    5
  |\
  | o  5
  | |
  o |  5
  |/
  o  3
  

  $ hg checkout 0
  1 files updated, 0 files merged, 0 files removed, 0 files unresolved
  $ printf "third\nfirst\nsecond\n" > file
  $ hg commit -m "$wrappabletext"
  created new head

  $ hg log --graph -T "{graphwidth}"
  @  3
  |
  | o    7
  | |\
  +---o  7
  | |
  | o  5
  |/
  o  3
  

  $ hg log --graph -T "{graphwidth}" -r 3
  o    5
  |\
  ~ ~

  $ hg log --graph -T "{graphwidth}" -r 1
  o  3
  |
  ~

  $ hg merge
  1 files updated, 0 files merged, 0 files removed, 0 files unresolved
  (branch merge, don't forget to commit)
  $ hg commit -m "$wrappabletext"

  $ printf "seventh\n" >> file
  $ hg commit -m "$wrappabletext"

  $ hg log --graph -T "{graphwidth}"
  @  3
  |
  o    5
  |\
  | o  5
  | |
  o |    7
  |\ \
  | o |  7
  | |/
  o /  5
  |/
  o  3
  

The point of graphwidth is to allow wrapping that accounts for the space taken
by the graph.

  $ COLUMNS=10 hg log --graph -T "{fill(desc, termwidth - graphwidth)}"
  @  a a a a
  |  a a a a
  |  a a a a
  o    a a a
  |\   a a a
  | |  a a a
  | |  a a a
  | o  a a a
  | |  a a a
  | |  a a a
  | |  a a a
  o |    a a
  |\ \   a a
  | | |  a a
  | | |  a a
  | | |  a a
  | | |  a a
  | o |  a a
  | |/   a a
  | |    a a
  | |    a a
  | |    a a
  | |    a a
  o |  a a a
  |/   a a a
  |    a a a
  |    a a a
  o  a a a a
     a a a a
     a a a a

Something tricky happens when there are elided nodes; the next drawn row of
edges can be more than one column wider, but the graph width only increases by
one column. The remaining columns are added in between the nodes.

  $ hg log --graph -T "{graphwidth}" -r "0|2|4|5"
  o    5
  |\
  | \
  | :\
  o : :  7
  :/ /
  : o  5
  :/
  o  3
  

  $ cd ..
