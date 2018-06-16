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

Test arithmetic operators have the right precedence:

  $ hg log -l 1 -T '{date(date, "%Y") + 5 * 10} {date(date, "%Y") - 2 * 3}\n'
  2020 1964
  $ hg log -l 1 -T '{date(date, "%Y") * 5 + 10} {date(date, "%Y") * 3 - 2}\n'
  9860 5908

Test division:

  $ hg debugtemplate -r0 -v '{5 / 2} {mod(5, 2)}\n'
  (template
    (/
      (integer '5')
      (integer '2'))
    (string ' ')
    (func
      (symbol 'mod')
      (list
        (integer '5')
        (integer '2')))
    (string '\n'))
  * keywords: 
  * functions: mod
  2 1
  $ hg debugtemplate -r0 -v '{5 / -2} {mod(5, -2)}\n'
  (template
    (/
      (integer '5')
      (negate
        (integer '2')))
    (string ' ')
    (func
      (symbol 'mod')
      (list
        (integer '5')
        (negate
          (integer '2'))))
    (string '\n'))
  * keywords: 
  * functions: mod
  -3 -1
  $ hg debugtemplate -r0 -v '{-5 / 2} {mod(-5, 2)}\n'
  (template
    (/
      (negate
        (integer '5'))
      (integer '2'))
    (string ' ')
    (func
      (symbol 'mod')
      (list
        (negate
          (integer '5'))
        (integer '2')))
    (string '\n'))
  * keywords: 
  * functions: mod
  -3 1
  $ hg debugtemplate -r0 -v '{-5 / -2} {mod(-5, -2)}\n'
  (template
    (/
      (negate
        (integer '5'))
      (negate
        (integer '2')))
    (string ' ')
    (func
      (symbol 'mod')
      (list
        (negate
          (integer '5'))
        (negate
          (integer '2'))))
    (string '\n'))
  * keywords: 
  * functions: mod
  2 -1

Filters bind closer than arithmetic:

  $ hg debugtemplate -r0 -v '{revset(".")|count - 1}\n'
  (template
    (-
      (|
        (func
          (symbol 'revset')
          (string '.'))
        (symbol 'count'))
      (integer '1'))
    (string '\n'))
  * keywords: 
  * functions: count, revset
  0

But negate binds closer still:

  $ hg debugtemplate -r0 -v '{1-3|stringify}\n'
  (template
    (-
      (integer '1')
      (|
        (integer '3')
        (symbol 'stringify')))
    (string '\n'))
  * keywords: 
  * functions: stringify
  hg: parse error: arithmetic only defined on integers
  [255]
  $ hg debugtemplate -r0 -v '{-3|stringify}\n'
  (template
    (|
      (negate
        (integer '3'))
      (symbol 'stringify'))
    (string '\n'))
  * keywords: 
  * functions: stringify
  -3

Filters bind as close as map operator:

  $ hg debugtemplate -r0 -v '{desc|splitlines % "{line}\n"}'
  (template
    (%
      (|
        (symbol 'desc')
        (symbol 'splitlines'))
      (template
        (symbol 'line')
        (string '\n'))))
  * keywords: desc, line
  * functions: splitlines
  line 1
  line 2

Keyword arguments:

  $ hg debugtemplate -r0 -v '{foo=bar|baz}'
  (template
    (keyvalue
      (symbol 'foo')
      (|
        (symbol 'bar')
        (symbol 'baz'))))
  * keywords: bar, foo
  * functions: baz
  hg: parse error: can't use a key-value pair in this context
  [255]

  $ hg debugtemplate '{pad("foo", width=10, left=true)}\n'
         foo

Call function which takes named arguments by filter syntax:

  $ hg debugtemplate '{" "|separate}'
  $ hg debugtemplate '{("not", "an", "argument", "list")|separate}'
  hg: parse error: unknown method 'list'
  [255]

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

  $ hg log --template '{join(file_copies, ",\n")}\n' -r .
  fourth (second)
  $ hg log -T '{file_copies % "{source} -> {name}\n"}' -r .
  second -> fourth
  $ hg log -T '{rev} {ifcontains("fourth", file_copies, "t", "f")}\n' -r .:7
  8 t
  7 f

Working-directory revision has special identifiers, though they are still
experimental:

  $ hg log -r 'wdir()' -T '{rev}:{node}\n'
  2147483647:ffffffffffffffffffffffffffffffffffffffff

Some keywords are invalid for working-directory revision, but they should
never cause crash:

  $ hg log -r 'wdir()' -T '{manifest}\n'
  

Internal resources shouldn't be exposed (issue5699):

  $ hg log -r. -T '{cache}{ctx}{repo}{revcache}{templ}{ui}'

Never crash on internal resource not available:

  $ hg --cwd .. debugtemplate '{"c0bebeef"|shortest}\n'
  abort: template resource not available: repo
  [255]

  $ hg config -T '{author}'

Quoting for ui.logtemplate

  $ hg tip --config "ui.logtemplate={rev}\n"
  8
  $ hg tip --config "ui.logtemplate='{rev}\n'"
  8
  $ hg tip --config 'ui.logtemplate="{rev}\n"'
  8
  $ hg tip --config 'ui.logtemplate=n{rev}\n'
  n8

Check that recursive reference does not fall into RuntimeError (issue4758):

 common mistake:

  $ cat << EOF > issue4758
  > changeset = '{changeset}\n'
  > EOF
  $ hg log --style ./issue4758
  abort: recursive reference 'changeset' in template
  [255]

 circular reference:

  $ cat << EOF > issue4758
  > changeset = '{foo}'
  > foo = '{changeset}'
  > EOF
  $ hg log --style ./issue4758
  abort: recursive reference 'foo' in template
  [255]

 buildmap() -> gettemplate(), where no thunk was made:

  $ cat << EOF > issue4758
  > changeset = '{files % changeset}\n'
  > EOF
  $ hg log --style ./issue4758
  abort: recursive reference 'changeset' in template
  [255]

 not a recursion if a keyword of the same name exists:

  $ cat << EOF > issue4758
  > changeset = '{tags % rev}'
  > rev = '{rev} {tag}\n'
  > EOF
  $ hg log --style ./issue4758 -r tip
  8 tip

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
  >         p1rev p2rev p1node p2node; do
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

Error on syntax:

  $ cat <<EOF > t
  > changeset = '{c}'
  > c = q
  > x = "f
  > EOF
  $ echo '[ui]' > .hg/hgrc
  $ echo 'style = t' >> .hg/hgrc
  $ hg log
  hg: parse error at t:3: unmatched quotes
  [255]

  $ hg log -T '{date'
  hg: parse error at 1: unterminated template expansion
  ({date
    ^ here)
  [255]
  $ hg log -T '{date(}'
  hg: parse error at 6: not a prefix: end
  ({date(}
         ^ here)
  [255]
  $ hg log -T '{date)}'
  hg: parse error at 5: invalid token
  ({date)}
        ^ here)
  [255]
  $ hg log -T '{date date}'
  hg: parse error at 6: invalid token
  ({date date}
         ^ here)
  [255]

  $ hg log -T '{}'
  hg: parse error at 1: not a prefix: end
  ({}
    ^ here)
  [255]
  $ hg debugtemplate -v '{()}'
  (template
    (group
      None))
  * keywords: 
  * functions: 
  hg: parse error: missing argument
  [255]

Behind the scenes, this would throw TypeError without intype=bytes

  $ hg log -l 3 --template '{date|obfuscate}\n'
  &#48;&#46;&#48;&#48;
  &#48;&#46;&#48;&#48;
  &#49;&#53;&#55;&#55;&#56;&#55;&#50;&#56;&#54;&#48;&#46;&#48;&#48;

Behind the scenes, this will throw a ValueError

  $ hg log -l 3 --template 'line: {desc|shortdate}\n'
  hg: parse error: invalid date: 'Modify, add, remove, rename'
  (template filter 'shortdate' is not compatible with keyword 'desc')
  [255]

Behind the scenes, this would throw AttributeError without intype=bytes

  $ hg log -l 3 --template 'line: {date|escape}\n'
  line: 0.00
  line: 0.00
  line: 1577872860.00

  $ hg log -l 3 --template 'line: {extras|localdate}\n'
  hg: parse error: localdate expects a date information
  [255]

Behind the scenes, this will throw ValueError

  $ hg tip --template '{author|email|date}\n'
  hg: parse error: date expects a date information
  [255]

  $ hg tip -T '{author|email|shortdate}\n'
  hg: parse error: invalid date: 'test'
  (template filter 'shortdate' is not compatible with keyword 'author')
  [255]

  $ hg tip -T '{get(extras, "branch")|shortdate}\n'
  hg: parse error: invalid date: 'default'
  (incompatible use of template filter 'shortdate')
  [255]

Error in nested template:

  $ hg log -T '{"date'
  hg: parse error at 2: unterminated string
  ({"date
     ^ here)
  [255]

  $ hg log -T '{"foo{date|?}"}'
  hg: parse error at 11: syntax error
  ({"foo{date|?}"}
              ^ here)
  [255]

Thrown an error if a template function doesn't exist

  $ hg tip --template '{foo()}\n'
  hg: parse error: unknown function 'foo'
  [255]

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

Test new-style inline templating:

  $ hg log -R latesttag -r tip --template 'modified files: {file_mods % " {file}\n"}\n'
  modified files:  .hgtags
  

  $ hg log -R latesttag -r tip -T '{rev % "a"}\n'
  hg: parse error: 11 is not iterable of mappings
  (keyword 'rev' does not support map operation)
  [255]
  $ hg log -R latesttag -r tip -T '{get(extras, "unknown") % "a"}\n'
  hg: parse error: None is not iterable of mappings
  [255]
  $ hg log -R latesttag -r tip -T '{extras % "{key}\n" % "{key}\n"}'
  hg: parse error: list of strings is not mappable
  [255]

Test new-style inline templating of non-list/dict type:

  $ hg log -R latesttag -r tip -T '{manifest}\n'
  11:2bc6e9006ce2
  $ hg log -R latesttag -r tip -T 'string length: {manifest|count}\n'
  string length: 15
  $ hg log -R latesttag -r tip -T '{manifest % "{rev}:{node}"}\n'
  11:2bc6e9006ce29882383a22d39fd1f4e66dd3e2fc

  $ hg log -R latesttag -r tip -T '{get(extras, "branch") % "{key}: {value}\n"}'
  branch: default
  $ hg log -R latesttag -r tip -T '{get(extras, "unknown") % "{key}\n"}'
  hg: parse error: None is not iterable of mappings
  [255]
  $ hg log -R latesttag -r tip -T '{min(extras) % "{key}: {value}\n"}'
  branch: default
  $ hg log -R latesttag -l1 -T '{min(revset("0:9")) % "{rev}:{node|short}\n"}'
  0:ce3cec86e6c2
  $ hg log -R latesttag -l1 -T '{max(revset("0:9")) % "{rev}:{node|short}\n"}'
  9:fbc7cd862e9c

Test dot operator precedence:

  $ hg debugtemplate -R latesttag -r0 -v '{manifest.node|short}\n'
  (template
    (|
      (.
        (symbol 'manifest')
        (symbol 'node'))
      (symbol 'short'))
    (string '\n'))
  * keywords: manifest, node, rev
  * functions: formatnode, short
  89f4071fec70

 (the following examples are invalid, but seem natural in parsing POV)

  $ hg debugtemplate -R latesttag -r0 -v '{foo|bar.baz}\n' 2> /dev/null
  (template
    (|
      (symbol 'foo')
      (.
        (symbol 'bar')
        (symbol 'baz')))
    (string '\n'))
  [255]
  $ hg debugtemplate -R latesttag -r0 -v '{foo.bar()}\n' 2> /dev/null
  (template
    (.
      (symbol 'foo')
      (func
        (symbol 'bar')
        None))
    (string '\n'))
  * keywords: foo
  * functions: bar
  [255]

Test evaluation of dot operator:

  $ hg log -R latesttag -l1 -T '{min(revset("0:9")).node}\n'
  ce3cec86e6c26bd9bdfc590a6b92abc9680f1796
  $ hg log -R latesttag -r0 -T '{extras.branch}\n'
  default
  $ hg log -R latesttag -r0 -T '{date.unixtime} {localdate(date, "+0200").tzoffset}\n'
  0 -7200

  $ hg log -R latesttag -l1 -T '{author.invalid}\n'
  hg: parse error: 'test' is not a dictionary
  (keyword 'author' does not support member operation)
  [255]
  $ hg log -R latesttag -l1 -T '{min("abc").invalid}\n'
  hg: parse error: 'a' is not a dictionary
  [255]

Test integer literal:

  $ hg debugtemplate -v '{(0)}\n'
  (template
    (group
      (integer '0'))
    (string '\n'))
  * keywords: 
  * functions: 
  0
  $ hg debugtemplate -v '{(123)}\n'
  (template
    (group
      (integer '123'))
    (string '\n'))
  * keywords: 
  * functions: 
  123
  $ hg debugtemplate -v '{(-4)}\n'
  (template
    (group
      (negate
        (integer '4')))
    (string '\n'))
  * keywords: 
  * functions: 
  -4
  $ hg debugtemplate '{(-)}\n'
  hg: parse error at 3: not a prefix: )
  ({(-)}\n
      ^ here)
  [255]
  $ hg debugtemplate '{(-a)}\n'
  hg: parse error: negation needs an integer argument
  [255]

top-level integer literal is interpreted as symbol (i.e. variable name):

  $ hg debugtemplate -D 1=one -v '{1}\n'
  (template
    (integer '1')
    (string '\n'))
  * keywords: 
  * functions: 
  one
  $ hg debugtemplate -D 1=one -v '{if("t", "{1}")}\n'
  (template
    (func
      (symbol 'if')
      (list
        (string 't')
        (template
          (integer '1'))))
    (string '\n'))
  * keywords: 
  * functions: if
  one
  $ hg debugtemplate -D 1=one -v '{1|stringify}\n'
  (template
    (|
      (integer '1')
      (symbol 'stringify'))
    (string '\n'))
  * keywords: 
  * functions: stringify
  one

unless explicit symbol is expected:

  $ hg log -Ra -r0 -T '{desc|1}\n'
  hg: parse error: expected a symbol, got 'integer'
  [255]
  $ hg log -Ra -r0 -T '{1()}\n'
  hg: parse error: expected a symbol, got 'integer'
  [255]

Test string literal:

  $ hg debugtemplate -Ra -r0 -v '{"string with no template fragment"}\n'
  (template
    (string 'string with no template fragment')
    (string '\n'))
  * keywords: 
  * functions: 
  string with no template fragment
  $ hg debugtemplate -Ra -r0 -v '{"template: {rev}"}\n'
  (template
    (template
      (string 'template: ')
      (symbol 'rev'))
    (string '\n'))
  * keywords: rev
  * functions: 
  template: 0
  $ hg debugtemplate -Ra -r0 -v '{r"rawstring: {rev}"}\n'
  (template
    (string 'rawstring: {rev}')
    (string '\n'))
  * keywords: 
  * functions: 
  rawstring: {rev}
  $ hg debugtemplate -Ra -r0 -v '{files % r"rawstring: {file}"}\n'
  (template
    (%
      (symbol 'files')
      (string 'rawstring: {file}'))
    (string '\n'))
  * keywords: files
  * functions: 
  rawstring: {file}

Test string escaping:

  $ hg log -R latesttag -r 0 --template '>\n<>\\n<{if(rev, "[>\n<>\\n<]")}>\n<>\\n<\n'
  >
  <>\n<[>
  <>\n<]>
  <>\n<

  $ hg log -R latesttag -r 0 \
  > --config ui.logtemplate='>\n<>\\n<{if(rev, "[>\n<>\\n<]")}>\n<>\\n<\n'
  >
  <>\n<[>
  <>\n<]>
  <>\n<

  $ hg log -R latesttag -r 0 -T esc \
  > --config templates.esc='>\n<>\\n<{if(rev, "[>\n<>\\n<]")}>\n<>\\n<\n'
  >
  <>\n<[>
  <>\n<]>
  <>\n<

  $ cat <<'EOF' > esctmpl
  > changeset = '>\n<>\\n<{if(rev, "[>\n<>\\n<]")}>\n<>\\n<\n'
  > EOF
  $ hg log -R latesttag -r 0 --style ./esctmpl
  >
  <>\n<[>
  <>\n<]>
  <>\n<

Test string escaping of quotes:

  $ hg log -Ra -r0 -T '{"\""}\n'
  "
  $ hg log -Ra -r0 -T '{"\\\""}\n'
  \"
  $ hg log -Ra -r0 -T '{r"\""}\n'
  \"
  $ hg log -Ra -r0 -T '{r"\\\""}\n'
  \\\"


  $ hg log -Ra -r0 -T '{"\""}\n'
  "
  $ hg log -Ra -r0 -T '{"\\\""}\n'
  \"
  $ hg log -Ra -r0 -T '{r"\""}\n'
  \"
  $ hg log -Ra -r0 -T '{r"\\\""}\n'
  \\\"

Test exception in quoted template. single backslash before quotation mark is
stripped before parsing:

  $ cat <<'EOF' > escquotetmpl
  > changeset = "\" \\" \\\" \\\\" {files % \"{file}\"}\n"
  > EOF
  $ cd latesttag
  $ hg log -r 2 --style ../escquotetmpl
  " \" \" \\" head1

  $ hg log -r 2 -T esc --config templates.esc='"{\"valid\"}\n"'
  valid
  $ hg log -r 2 -T esc --config templates.esc="'"'{\'"'"'valid\'"'"'}\n'"'"
  valid

Test compatibility with 2.9.2-3.4 of escaped quoted strings in nested
_evalifliteral() templates (issue4733):

  $ hg log -r 2 -T '{if(rev, "\"{rev}")}\n'
  "2
  $ hg log -r 2 -T '{if(rev, "{if(rev, \"\\\"{rev}\")}")}\n'
  "2
  $ hg log -r 2 -T '{if(rev, "{if(rev, \"{if(rev, \\\"\\\\\\\"{rev}\\\")}\")}")}\n'
  "2

  $ hg log -r 2 -T '{if(rev, "\\\"")}\n'
  \"
  $ hg log -r 2 -T '{if(rev, "{if(rev, \"\\\\\\\"\")}")}\n'
  \"
  $ hg log -r 2 -T '{if(rev, "{if(rev, \"{if(rev, \\\"\\\\\\\\\\\\\\\"\\\")}\")}")}\n'
  \"

  $ hg log -r 2 -T '{if(rev, r"\\\"")}\n'
  \\\"
  $ hg log -r 2 -T '{if(rev, "{if(rev, r\"\\\\\\\"\")}")}\n'
  \\\"
  $ hg log -r 2 -T '{if(rev, "{if(rev, \"{if(rev, r\\\"\\\\\\\\\\\\\\\"\\\")}\")}")}\n'
  \\\"

escaped single quotes and errors:

  $ hg log -r 2 -T "{if(rev, '{if(rev, \'foo\')}')}"'\n'
  foo
  $ hg log -r 2 -T "{if(rev, '{if(rev, r\'foo\')}')}"'\n'
  foo
  $ hg log -r 2 -T '{if(rev, "{if(rev, \")}")}\n'
  hg: parse error at 21: unterminated string
  ({if(rev, "{if(rev, \")}")}\n
                        ^ here)
  [255]
  $ hg log -r 2 -T '{if(rev, \"\\"")}\n'
  hg: parse error: trailing \ in string
  [255]
  $ hg log -r 2 -T '{if(rev, r\"\\"")}\n'
  hg: parse error: trailing \ in string
  [255]

  $ cd ..

Test leading backslashes:

  $ cd latesttag
  $ hg log -r 2 -T '\{rev} {files % "\{file}"}\n'
  {rev} {file}
  $ hg log -r 2 -T '\\{rev} {files % "\\{file}"}\n'
  \2 \head1
  $ hg log -r 2 -T '\\\{rev} {files % "\\\{file}"}\n'
  \{rev} \{file}
  $ cd ..

Test leading backslashes in "if" expression (issue4714):

  $ cd latesttag
  $ hg log -r 2 -T '{if("1", "\{rev}")} {if("1", r"\{rev}")}\n'
  {rev} \{rev}
  $ hg log -r 2 -T '{if("1", "\\{rev}")} {if("1", r"\\{rev}")}\n'
  \2 \\{rev}
  $ hg log -r 2 -T '{if("1", "\\\{rev}")} {if("1", r"\\\{rev}")}\n'
  \{rev} \\\{rev}
  $ cd ..

"string-escape"-ed "\x5c\x786e" becomes r"\x6e" (once) or r"n" (twice)

  $ hg log -R a -r 0 --template '{if("1", "\x5c\x786e", "NG")}\n'
  \x6e
  $ hg log -R a -r 0 --template '{if("1", r"\x5c\x786e", "NG")}\n'
  \x5c\x786e
  $ hg log -R a -r 0 --template '{if("", "NG", "\x5c\x786e")}\n'
  \x6e
  $ hg log -R a -r 0 --template '{if("", "NG", r"\x5c\x786e")}\n'
  \x5c\x786e

  $ hg log -R a -r 2 --template '{ifeq("no perso\x6e", desc, "\x5c\x786e", "NG")}\n'
  \x6e
  $ hg log -R a -r 2 --template '{ifeq(r"no perso\x6e", desc, "NG", r"\x5c\x786e")}\n'
  \x5c\x786e
  $ hg log -R a -r 2 --template '{ifeq(desc, "no perso\x6e", "\x5c\x786e", "NG")}\n'
  \x6e
  $ hg log -R a -r 2 --template '{ifeq(desc, r"no perso\x6e", "NG", r"\x5c\x786e")}\n'
  \x5c\x786e

  $ hg log -R a -r 8 --template '{join(files, "\n")}\n'
  fourth
  second
  third
  $ hg log -R a -r 8 --template '{join(files, r"\n")}\n'
  fourth\nsecond\nthird

  $ hg log -R a -r 2 --template '{rstdoc("1st\n\n2nd", "htm\x6c")}'
  <p>
  1st
  </p>
  <p>
  2nd
  </p>
  $ hg log -R a -r 2 --template '{rstdoc(r"1st\n\n2nd", "html")}'
  <p>
  1st\n\n2nd
  </p>
  $ hg log -R a -r 2 --template '{rstdoc("1st\n\n2nd", r"htm\x6c")}'
  1st
  
  2nd

  $ hg log -R a -r 2 --template '{strip(desc, "\x6e")}\n'
  o perso
  $ hg log -R a -r 2 --template '{strip(desc, r"\x6e")}\n'
  no person
  $ hg log -R a -r 2 --template '{strip("no perso\x6e", "\x6e")}\n'
  o perso
  $ hg log -R a -r 2 --template '{strip(r"no perso\x6e", r"\x6e")}\n'
  no perso

  $ hg log -R a -r 2 --template '{sub("\\x6e", "\x2d", desc)}\n'
  -o perso-
  $ hg log -R a -r 2 --template '{sub(r"\\x6e", "-", desc)}\n'
  no person
  $ hg log -R a -r 2 --template '{sub("n", r"\x2d", desc)}\n'
  \x2do perso\x2d
  $ hg log -R a -r 2 --template '{sub("n", "\x2d", "no perso\x6e")}\n'
  -o perso-
  $ hg log -R a -r 2 --template '{sub("n", r"\x2d", r"no perso\x6e")}\n'
  \x2do perso\x6e

  $ hg log -R a -r 8 --template '{files % "{file}\n"}'
  fourth
  second
  third

Test string escaping in nested expression:

  $ hg log -R a -r 8 --template '{ifeq(r"\x6e", if("1", "\x5c\x786e"), join(files, "\x5c\x786e"))}\n'
  fourth\x6esecond\x6ethird
  $ hg log -R a -r 8 --template '{ifeq(if("1", r"\x6e"), "\x5c\x786e", join(files, "\x5c\x786e"))}\n'
  fourth\x6esecond\x6ethird

  $ hg log -R a -r 8 --template '{join(files, ifeq(branch, "default", "\x5c\x786e"))}\n'
  fourth\x6esecond\x6ethird
  $ hg log -R a -r 8 --template '{join(files, ifeq(branch, "default", r"\x5c\x786e"))}\n'
  fourth\x5c\x786esecond\x5c\x786ethird

  $ hg log -R a -r 3:4 --template '{rev}:{sub(if("1", "\x6e"), ifeq(branch, "foo", r"\x5c\x786e", "\x5c\x786e"), desc)}\n'
  3:\x6eo user, \x6eo domai\x6e
  4:\x5c\x786eew bra\x5c\x786ech

Test quotes in nested expression are evaluated just like a $(command)
substitution in POSIX shells:

  $ hg log -R a -r 8 -T '{"{"{rev}:{node|short}"}"}\n'
  8:95c24699272e
  $ hg log -R a -r 8 -T '{"{"\{{rev}} \"{node|short}\""}"}\n'
  {8} "95c24699272e"

Test recursive evaluation:

  $ hg init r
  $ cd r
  $ echo a > a
  $ hg ci -Am '{rev}'
  adding a
  $ hg log -r 0 --template '{if(rev, desc)}\n'
  {rev}
  $ hg log -r 0 --template '{if(rev, "{author} {rev}")}\n'
  test 0

  $ hg branch -q 'text.{rev}'
  $ echo aa >> aa
  $ hg ci -u '{node|short}' -m 'desc to be wrapped desc to be wrapped'

  $ hg log -l1 --template '{fill(desc, "20", author, branch)}'
  {node|short}desc to
  text.{rev}be wrapped
  text.{rev}desc to be
  text.{rev}wrapped (no-eol)
  $ hg log -l1 --template '{fill(desc, "20", "{node|short}:", "text.{rev}:")}'
  bcc7ff960b8e:desc to
  text.1:be wrapped
  text.1:desc to be
  text.1:wrapped (no-eol)
  $ hg log -l1 -T '{fill(desc, date, "", "")}\n'
  hg: parse error: fill expects an integer width
  [255]

  $ COLUMNS=25 hg log -l1 --template '{fill(desc, termwidth, "{node|short}:", "termwidth.{rev}:")}'
  bcc7ff960b8e:desc to be
  termwidth.1:wrapped desc
  termwidth.1:to be wrapped (no-eol)

  $ hg log -l 1 --template '{sub(r"[0-9]", "-", author)}'
  {node|short} (no-eol)
  $ hg log -l 1 --template '{sub(r"[0-9]", "-", "{node|short}")}'
  bcc-ff---b-e (no-eol)

  $ cat >> .hg/hgrc <<EOF
  > [extensions]
  > color=
  > [color]
  > mode=ansi
  > text.{rev} = red
  > text.1 = green
  > EOF
  $ hg log --color=always -l 1 --template '{label(branch, "text\n")}'
  \x1b[0;31mtext\x1b[0m (esc)
  $ hg log --color=always -l 1 --template '{label("text.{rev}", "text\n")}'
  \x1b[0;32mtext\x1b[0m (esc)

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

Test bad template with better error message

  $ hg log -Gv -R a --template '{desc|user()}'
  hg: parse error: expected a symbol, got 'func'
  [255]

Test broken string escapes:

  $ hg log -T "bogus\\" -R a
  hg: parse error: trailing \ in string
  [255]
  $ hg log -T "\\xy" -R a
  hg: parse error: invalid \x escape* (glob)
  [255]

Templater supports aliases of symbol and func() styles:

  $ hg clone -q a aliases
  $ cd aliases
  $ cat <<EOF >> .hg/hgrc
  > [templatealias]
  > r = rev
  > rn = "{r}:{node|short}"
  > status(c, files) = files % "{c} {file}\n"
  > utcdate(d) = localdate(d, "UTC")
  > EOF

  $ hg debugtemplate -vr0 '{rn} {utcdate(date)|isodate}\n'
  (template
    (symbol 'rn')
    (string ' ')
    (|
      (func
        (symbol 'utcdate')
        (symbol 'date'))
      (symbol 'isodate'))
    (string '\n'))
  * expanded:
  (template
    (template
      (symbol 'rev')
      (string ':')
      (|
        (symbol 'node')
        (symbol 'short')))
    (string ' ')
    (|
      (func
        (symbol 'localdate')
        (list
          (symbol 'date')
          (string 'UTC')))
      (symbol 'isodate'))
    (string '\n'))
  * keywords: date, node, rev
  * functions: isodate, localdate, short
  0:1e4e1b8f71e0 1970-01-12 13:46 +0000

  $ hg debugtemplate -vr0 '{status("A", file_adds)}'
  (template
    (func
      (symbol 'status')
      (list
        (string 'A')
        (symbol 'file_adds'))))
  * expanded:
  (template
    (%
      (symbol 'file_adds')
      (template
        (string 'A')
        (string ' ')
        (symbol 'file')
        (string '\n'))))
  * keywords: file, file_adds
  * functions: 
  A a

A unary function alias can be called as a filter:

  $ hg debugtemplate -vr0 '{date|utcdate|isodate}\n'
  (template
    (|
      (|
        (symbol 'date')
        (symbol 'utcdate'))
      (symbol 'isodate'))
    (string '\n'))
  * expanded:
  (template
    (|
      (func
        (symbol 'localdate')
        (list
          (symbol 'date')
          (string 'UTC')))
      (symbol 'isodate'))
    (string '\n'))
  * keywords: date
  * functions: isodate, localdate
  1970-01-12 13:46 +0000

Aliases should be applied only to command arguments and templates in hgrc.
Otherwise, our stock styles and web templates could be corrupted:

  $ hg log -r0 -T '{rn} {utcdate(date)|isodate}\n'
  0:1e4e1b8f71e0 1970-01-12 13:46 +0000

  $ hg log -r0 --config ui.logtemplate='"{rn} {utcdate(date)|isodate}\n"'
  0:1e4e1b8f71e0 1970-01-12 13:46 +0000

  $ cat <<EOF > tmpl
  > changeset = 'nothing expanded:{rn}\n'
  > EOF
  $ hg log -r0 --style ./tmpl
  nothing expanded:

Aliases in formatter:

  $ hg branches -T '{pad(branch, 7)} {rn}\n'
  default 6:d41e714fe50d
  foo     4:bbe44766e73d

Aliases should honor HGPLAIN:

  $ HGPLAIN= hg log -r0 -T 'nothing expanded:{rn}\n'
  nothing expanded:
  $ HGPLAINEXCEPT=templatealias hg log -r0 -T '{rn}\n'
  0:1e4e1b8f71e0

Unparsable alias:

  $ hg debugtemplate --config templatealias.bad='x(' -v '{bad}'
  (template
    (symbol 'bad'))
  abort: bad definition of template alias "bad": at 2: not a prefix: end
  [255]
  $ hg log --config templatealias.bad='x(' -T '{bad}'
  abort: bad definition of template alias "bad": at 2: not a prefix: end
  [255]

  $ cd ..

Test that template function in extension is registered as expected

  $ cd a

  $ cat <<EOF > $TESTTMP/customfunc.py
  > from mercurial import registrar
  > 
  > templatefunc = registrar.templatefunc()
  > 
  > @templatefunc(b'custom()')
  > def custom(context, mapping, args):
  >     return b'custom'
  > EOF
  $ cat <<EOF > .hg/hgrc
  > [extensions]
  > customfunc = $TESTTMP/customfunc.py
  > EOF

  $ hg log -r . -T "{custom()}\n" --config customfunc.enabled=true
  custom

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

