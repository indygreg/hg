Test template filters and functions
===================================

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

  $ hg phase -r 5 --public
  $ hg phase -r 7 --secret --force

Filters work:

  $ hg log --template '{author|domain}\n'
  
  hostname
  
  
  
  
  place
  place
  hostname

  $ hg log --template '{author|person}\n'
  test
  User Name
  person
  person
  person
  person
  other
  A. N. Other
  User Name

  $ hg log --template '{author|user}\n'
  test
  user
  person
  person
  person
  person
  other
  other
  user

  $ hg log --template '{date|date}\n'
  Wed Jan 01 10:01:00 2020 +0000
  Mon Jan 12 13:46:40 1970 +0000
  Sun Jan 18 08:40:01 1970 +0000
  Sun Jan 18 08:40:00 1970 +0000
  Sat Jan 17 04:53:20 1970 +0000
  Fri Jan 16 01:06:40 1970 +0000
  Wed Jan 14 21:20:00 1970 +0000
  Tue Jan 13 17:33:20 1970 +0000
  Mon Jan 12 13:46:40 1970 +0000

  $ hg log --template '{date|isodate}\n'
  2020-01-01 10:01 +0000
  1970-01-12 13:46 +0000
  1970-01-18 08:40 +0000
  1970-01-18 08:40 +0000
  1970-01-17 04:53 +0000
  1970-01-16 01:06 +0000
  1970-01-14 21:20 +0000
  1970-01-13 17:33 +0000
  1970-01-12 13:46 +0000

  $ hg log --template '{date|isodatesec}\n'
  2020-01-01 10:01:00 +0000
  1970-01-12 13:46:40 +0000
  1970-01-18 08:40:01 +0000
  1970-01-18 08:40:00 +0000
  1970-01-17 04:53:20 +0000
  1970-01-16 01:06:40 +0000
  1970-01-14 21:20:00 +0000
  1970-01-13 17:33:20 +0000
  1970-01-12 13:46:40 +0000

  $ hg log --template '{date|rfc822date}\n'
  Wed, 01 Jan 2020 10:01:00 +0000
  Mon, 12 Jan 1970 13:46:40 +0000
  Sun, 18 Jan 1970 08:40:01 +0000
  Sun, 18 Jan 1970 08:40:00 +0000
  Sat, 17 Jan 1970 04:53:20 +0000
  Fri, 16 Jan 1970 01:06:40 +0000
  Wed, 14 Jan 1970 21:20:00 +0000
  Tue, 13 Jan 1970 17:33:20 +0000
  Mon, 12 Jan 1970 13:46:40 +0000

  $ hg log --template '{desc|firstline}\n'
  third
  second
  merge
  new head
  new branch
  no user, no domain
  no person
  other 1
  line 1

  $ hg log --template '{node|short}\n'
  95c24699272e
  29114dbae42b
  d41e714fe50d
  13207e5a10d9
  bbe44766e73d
  10e46f2dcbf4
  97054abb4ab8
  b608e9d1a3f0
  1e4e1b8f71e0

  $ hg log --template '<changeset author="{author|xmlescape}"/>\n'
  <changeset author="test"/>
  <changeset author="User Name &lt;user@hostname&gt;"/>
  <changeset author="person"/>
  <changeset author="person"/>
  <changeset author="person"/>
  <changeset author="person"/>
  <changeset author="other@place"/>
  <changeset author="A. N. Other &lt;other@place&gt;"/>
  <changeset author="User Name &lt;user@hostname&gt;"/>

  $ hg log --template '{rev}: {children}\n'
  8: 
  7: 8:95c24699272e
  6: 
  5: 6:d41e714fe50d
  4: 6:d41e714fe50d
  3: 4:bbe44766e73d 5:13207e5a10d9
  2: 3:10e46f2dcbf4
  1: 2:97054abb4ab8
  0: 1:b608e9d1a3f0

Formatnode filter works:

  $ hg -q log -r 0 --template '{node|formatnode}\n'
  1e4e1b8f71e0

  $ hg log -r 0 --template '{node|formatnode}\n'
  1e4e1b8f71e0

  $ hg -v log -r 0 --template '{node|formatnode}\n'
  1e4e1b8f71e0

  $ hg --debug log -r 0 --template '{node|formatnode}\n'
  1e4e1b8f71e05681d422154f5421e385fec3454f

Age filter:

  $ hg init unstable-hash
  $ cd unstable-hash
  $ hg log --template '{date|age}\n' > /dev/null || exit 1

  >>> from __future__ import absolute_import
  >>> import datetime
  >>> fp = open('a', 'wb')
  >>> n = datetime.datetime.now() + datetime.timedelta(366 * 7)
  >>> fp.write(b'%d-%d-%d 00:00' % (n.year, n.month, n.day)) and None
  >>> fp.close()
  $ hg add a
  $ hg commit -m future -d "`cat a`"

  $ hg log -l1 --template '{date|age}\n'
  7 years from now

  $ cd ..
  $ rm -rf unstable-hash

Filename filters:

  $ hg debugtemplate '{"foo/bar"|basename}|{"foo/"|basename}|{"foo"|basename}|\n'
  bar||foo|
  $ hg debugtemplate '{"foo/bar"|dirname}|{"foo/"|dirname}|{"foo"|dirname}|\n'
  foo|foo||
  $ hg debugtemplate '{"foo/bar"|stripdir}|{"foo/"|stripdir}|{"foo"|stripdir}|\n'
  foo|foo|foo|

commondir() filter:

  $ hg debugtemplate '{""|splitlines|commondir}\n'
  
  $ hg debugtemplate '{"foo/bar\nfoo/baz\nfoo/foobar\n"|splitlines|commondir}\n'
  foo
  $ hg debugtemplate '{"foo/bar\nfoo/bar\n"|splitlines|commondir}\n'
  foo
  $ hg debugtemplate '{"/foo/bar\n/foo/bar\n"|splitlines|commondir}\n'
  foo
  $ hg debugtemplate '{"/foo\n/foo\n"|splitlines|commondir}\n'
  
  $ hg debugtemplate '{"foo/bar\nbar/baz"|splitlines|commondir}\n'
  
  $ hg debugtemplate '{"foo/bar\nbar/baz\nbar/foo\n"|splitlines|commondir}\n'
  
  $ hg debugtemplate '{"foo/../bar\nfoo/bar"|splitlines|commondir}\n'
  foo
  $ hg debugtemplate '{"foo\n/foo"|splitlines|commondir}\n'
  

  $ hg log -r null -T '{rev|commondir}'
  hg: parse error: argument is not a list of text
  (template filter 'commondir' is not compatible with keyword 'rev')
  [255]

Add a dummy commit to make up for the instability of the above:

  $ echo a > a
  $ hg add a
  $ hg ci -m future

Count filter:

  $ hg log -l1 --template '{node|count} {node|short|count}\n'
  40 12

  $ hg log -l1 --template '{revset("null^")|count} {revset(".")|count} {revset("0::3")|count}\n'
  0 1 4

  $ hg log -G --template '{rev}: children: {children|count}, \
  > tags: {tags|count}, file_adds: {file_adds|count}, \
  > ancestors: {revset("ancestors(%s)", rev)|count}'
  @  9: children: 0, tags: 1, file_adds: 1, ancestors: 3
  |
  o  8: children: 1, tags: 0, file_adds: 2, ancestors: 2
  |
  o  7: children: 1, tags: 0, file_adds: 1, ancestors: 1
  
  o    6: children: 0, tags: 0, file_adds: 0, ancestors: 7
  |\
  | o  5: children: 1, tags: 0, file_adds: 1, ancestors: 5
  | |
  o |  4: children: 1, tags: 0, file_adds: 0, ancestors: 5
  |/
  o  3: children: 2, tags: 0, file_adds: 0, ancestors: 4
  |
  o  2: children: 1, tags: 0, file_adds: 1, ancestors: 3
  |
  o  1: children: 1, tags: 0, file_adds: 1, ancestors: 2
  |
  o  0: children: 1, tags: 0, file_adds: 1, ancestors: 1
  

  $ hg log -l1 -T '{termwidth|count}\n'
  hg: parse error: not countable
  (template filter 'count' is not compatible with keyword 'termwidth')
  [255]

Upper/lower filters:

  $ hg log -r0 --template '{branch|upper}\n'
  DEFAULT
  $ hg log -r0 --template '{author|lower}\n'
  user name <user@hostname>
  $ hg log -r0 --template '{date|upper}\n'
  1000000.00

Add a commit that does all possible modifications at once

  $ echo modify >> third
  $ touch b
  $ hg add b
  $ hg mv fourth fifth
  $ hg rm a
  $ hg ci -m "Modify, add, remove, rename"

Pass generator object created by template function to filter

  $ hg log -l 1 --template '{if(author, author)|user}\n'
  test

Test diff function:

  $ hg diff -c 8
  diff -r 29114dbae42b -r 95c24699272e fourth
  --- /dev/null	Thu Jan 01 00:00:00 1970 +0000
  +++ b/fourth	Wed Jan 01 10:01:00 2020 +0000
  @@ -0,0 +1,1 @@
  +second
  diff -r 29114dbae42b -r 95c24699272e second
  --- a/second	Mon Jan 12 13:46:40 1970 +0000
  +++ /dev/null	Thu Jan 01 00:00:00 1970 +0000
  @@ -1,1 +0,0 @@
  -second
  diff -r 29114dbae42b -r 95c24699272e third
  --- /dev/null	Thu Jan 01 00:00:00 1970 +0000
  +++ b/third	Wed Jan 01 10:01:00 2020 +0000
  @@ -0,0 +1,1 @@
  +third

  $ hg log -r 8 -T "{diff()}"
  diff -r 29114dbae42b -r 95c24699272e fourth
  --- /dev/null	Thu Jan 01 00:00:00 1970 +0000
  +++ b/fourth	Wed Jan 01 10:01:00 2020 +0000
  @@ -0,0 +1,1 @@
  +second
  diff -r 29114dbae42b -r 95c24699272e second
  --- a/second	Mon Jan 12 13:46:40 1970 +0000
  +++ /dev/null	Thu Jan 01 00:00:00 1970 +0000
  @@ -1,1 +0,0 @@
  -second
  diff -r 29114dbae42b -r 95c24699272e third
  --- /dev/null	Thu Jan 01 00:00:00 1970 +0000
  +++ b/third	Wed Jan 01 10:01:00 2020 +0000
  @@ -0,0 +1,1 @@
  +third

  $ hg log -r 8 -T "{diff('glob:f*')}"
  diff -r 29114dbae42b -r 95c24699272e fourth
  --- /dev/null	Thu Jan 01 00:00:00 1970 +0000
  +++ b/fourth	Wed Jan 01 10:01:00 2020 +0000
  @@ -0,0 +1,1 @@
  +second

  $ hg log -r 8 -T "{diff('', 'glob:f*')}"
  diff -r 29114dbae42b -r 95c24699272e second
  --- a/second	Mon Jan 12 13:46:40 1970 +0000
  +++ /dev/null	Thu Jan 01 00:00:00 1970 +0000
  @@ -1,1 +0,0 @@
  -second
  diff -r 29114dbae42b -r 95c24699272e third
  --- /dev/null	Thu Jan 01 00:00:00 1970 +0000
  +++ b/third	Wed Jan 01 10:01:00 2020 +0000
  @@ -0,0 +1,1 @@
  +third

  $ hg log -r 8 -T "{diff('FOURTH'|lower)}"
  diff -r 29114dbae42b -r 95c24699272e fourth
  --- /dev/null	Thu Jan 01 00:00:00 1970 +0000
  +++ b/fourth	Wed Jan 01 10:01:00 2020 +0000
  @@ -0,0 +1,1 @@
  +second

  $ cd ..

latesttag() function:

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

  $ hg log -G --template "{rev}: {latesttag('re:^t[13]$') % '{tag}, C: {changes}, D: {distance}'}\n"
  @  11: t3, C: 9, D: 8
  |
  o  10: t3, C: 8, D: 7
  |
  o  9: t3, C: 7, D: 6
  |
  o  8: t3, C: 6, D: 5
  |
  o  7: t3, C: 5, D: 4
  |
  o  6: t3, C: 4, D: 3
  |
  o    5: t3, C: 3, D: 2
  |\
  | o  4: t3, C: 1, D: 1
  | |
  | o  3: t3, C: 0, D: 0
  | |
  o |  2: t1, C: 1, D: 1
  |/
  o  1: t1, C: 0, D: 0
  |
  o  0: null, C: 1, D: 1
  

  $ cd ..

Test filter() empty values:

  $ hg log -R a -r 1 -T '{filter(desc|splitlines) % "{line}\n"}'
  other 1
  other 2
  other 3
  $ hg log -R a -r 0 -T '{filter(dict(a=0, b=1) % "{ifeq(key, "a", "{value}\n")}")}'
  0

 0 should not be falsy

  $ hg log -R a -r 0 -T '{filter(revset("0:2"))}\n'
  0 1 2

Test filter() by expression:

  $ hg log -R a -r 1 -T '{filter(desc|splitlines, ifcontains("1", line, "t"))}\n'
  other 1
  $ hg log -R a -r 0 -T '{filter(dict(a=0, b=1), ifeq(key, "b", "t"))}\n'
  b=1

Test filter() shouldn't crash:

  $ hg log -R a -r 0 -T '{filter(extras)}\n'
  branch=default
  $ hg log -R a -r 0 -T '{filter(files)}\n'
  a

Test filter() unsupported arguments:

  $ hg log -R a -r 0 -T '{filter()}\n'
  hg: parse error: filter expects one or two arguments
  [255]
  $ hg log -R a -r 0 -T '{filter(date)}\n'
  hg: parse error: date is not iterable
  [255]
  $ hg log -R a -r 0 -T '{filter(rev)}\n'
  hg: parse error: 0 is not iterable
  [255]
  $ hg log -R a -r 0 -T '{filter(desc|firstline)}\n'
  hg: parse error: 'line 1' is not filterable
  [255]
  $ hg log -R a -r 0 -T '{filter(manifest)}\n'
  hg: parse error: '0:a0c8bcbbb45c' is not filterable
  [255]
  $ hg log -R a -r 0 -T '{filter(succsandmarkers)}\n'
  hg: parse error: not filterable without template
  [255]
  $ hg log -R a -r 0 -T '{filter(desc|splitlines % "{line}", "")}\n'
  hg: parse error: not filterable by expression
  [255]

Test manifest/get() can be join()-ed as string, though it's silly:

  $ hg log -R latesttag -r tip -T '{join(manifest, ".")}\n'
  1.1.:.2.b.c.6.e.9.0.0.6.c.e.2
  $ hg log -R latesttag -r tip -T '{join(get(extras, "branch"), ".")}\n'
  d.e.f.a.u.l.t

Test join() over string

  $ hg log -R latesttag -r tip -T '{join(rev|stringify, ".")}\n'
  1.1

Test join() over uniterable

  $ hg log -R latesttag -r tip -T '{join(rev, "")}\n'
  hg: parse error: 11 is not iterable
  [255]

Test min/max of integers

  $ hg log -R latesttag -l1 -T '{min(revset("9:10"))}\n'
  9
  $ hg log -R latesttag -l1 -T '{max(revset("9:10"))}\n'
  10

Test min/max over map operation:

  $ hg log -R latesttag -r3 -T '{min(tags % "{tag}")}\n'
  at3
  $ hg log -R latesttag -r3 -T '{max(tags % "{tag}")}\n'
  t3

Test min/max of strings:

  $ hg log -R latesttag -l1 -T '{min(desc)}\n'
  3
  $ hg log -R latesttag -l1 -T '{max(desc)}\n'
  t

Test min/max of non-iterable:

  $ hg debugtemplate '{min(1)}'
  hg: parse error: 1 is not iterable
  (min first argument should be an iterable)
  [255]
  $ hg debugtemplate '{max(2)}'
  hg: parse error: 2 is not iterable
  (max first argument should be an iterable)
  [255]

  $ hg log -R latesttag -l1 -T '{min(date)}'
  hg: parse error: date is not iterable
  (min first argument should be an iterable)
  [255]
  $ hg log -R latesttag -l1 -T '{max(date)}'
  hg: parse error: date is not iterable
  (max first argument should be an iterable)
  [255]

Test min/max of empty sequence:

  $ hg debugtemplate '{min("")}'
  hg: parse error: empty string
  (min first argument should be an iterable)
  [255]
  $ hg debugtemplate '{max("")}'
  hg: parse error: empty string
  (max first argument should be an iterable)
  [255]
  $ hg debugtemplate '{min(dict())}'
  hg: parse error: empty sequence
  (min first argument should be an iterable)
  [255]
  $ hg debugtemplate '{max(dict())}'
  hg: parse error: empty sequence
  (max first argument should be an iterable)
  [255]
  $ hg debugtemplate '{min(dict() % "")}'
  hg: parse error: empty sequence
  (min first argument should be an iterable)
  [255]
  $ hg debugtemplate '{max(dict() % "")}'
  hg: parse error: empty sequence
  (max first argument should be an iterable)
  [255]

Test min/max of if() result

  $ cd latesttag
  $ hg log -l1 -T '{min(if(true, revset("9:10"), ""))}\n'
  9
  $ hg log -l1 -T '{max(if(false, "", revset("9:10")))}\n'
  10
  $ hg log -l1 -T '{min(ifcontains("a", "aa", revset("9:10"), ""))}\n'
  9
  $ hg log -l1 -T '{max(ifcontains("a", "bb", "", revset("9:10")))}\n'
  10
  $ hg log -l1 -T '{min(ifeq(0, 0, revset("9:10"), ""))}\n'
  9
  $ hg log -l1 -T '{max(ifeq(0, 1, "", revset("9:10")))}\n'
  10
  $ cd ..

Test laziness of if() then/else clause

  $ hg debugtemplate '{count(0)}'
  hg: parse error: not countable
  (incompatible use of template filter 'count')
  [255]
  $ hg debugtemplate '{if(true, "", count(0))}'
  $ hg debugtemplate '{if(false, count(0), "")}'
  $ hg debugtemplate '{ifcontains("a", "aa", "", count(0))}'
  $ hg debugtemplate '{ifcontains("a", "bb", count(0), "")}'
  $ hg debugtemplate '{ifeq(0, 0, "", count(0))}'
  $ hg debugtemplate '{ifeq(0, 1, count(0), "")}'

Test the sub function of templating for expansion:

  $ hg log -R latesttag -r 10 --template '{sub("[0-9]", "x", "{rev}")}\n'
  xx

  $ hg log -R latesttag -r 10 -T '{sub("[", "x", rev)}\n'
  hg: parse error: sub got an invalid pattern: [
  [255]
  $ hg log -R latesttag -r 10 -T '{sub("[0-9]", r"\1", rev)}\n'
  hg: parse error: sub got an invalid replacement: \1
  [255]

Test the strip function with chars specified:

  $ hg log -R latesttag --template '{desc}\n'
  at3
  t5
  t4
  t3
  t2
  t1
  merge
  h2e
  h2d
  h1c
  b
  a

  $ hg log -R latesttag --template '{strip(desc, "te")}\n'
  at3
  5
  4
  3
  2
  1
  merg
  h2
  h2d
  h1c
  b
  a

Test date format:

  $ hg log -R latesttag --template 'date: {date(date, "%y %m %d %S %z")}\n'
  date: 70 01 01 10 +0000
  date: 70 01 01 09 +0000
  date: 70 01 01 04 +0000
  date: 70 01 01 08 +0000
  date: 70 01 01 07 +0000
  date: 70 01 01 06 +0000
  date: 70 01 01 05 +0100
  date: 70 01 01 04 +0000
  date: 70 01 01 03 +0000
  date: 70 01 01 02 +0000
  date: 70 01 01 01 +0000
  date: 70 01 01 00 +0000

Test invalid date:

  $ hg log -R latesttag -T '{date(rev)}\n'
  hg: parse error: date expects a date information
  [255]

Set up repository containing template fragments in commit metadata:

  $ hg init r
  $ cd r
  $ echo a > a
  $ hg ci -Am '{rev}'
  adding a

  $ hg branch -q 'text.{rev}'
  $ echo aa >> aa
  $ hg ci -u '{node|short}' -m 'desc to be wrapped desc to be wrapped'

color effect can be specified without quoting:

  $ hg log --color=always -l 1 --template '{label(red, "text\n")}'
  \x1b[0;31mtext\x1b[0m (esc)

color effects can be nested (issue5413)

  $ hg debugtemplate --color=always \
  > '{label(red, "red{label(magenta, "ma{label(cyan, "cyan")}{label(yellow, "yellow")}genta")}")}\n'
  \x1b[0;31mred\x1b[0;35mma\x1b[0;36mcyan\x1b[0m\x1b[0;31m\x1b[0;35m\x1b[0;33myellow\x1b[0m\x1b[0;31m\x1b[0;35mgenta\x1b[0m (esc)

pad() should interact well with color codes (issue5416)

  $ hg debugtemplate --color=always \
  > '{pad(label(red, "red"), 5, label(cyan, "-"))}\n'
  \x1b[0;31mred\x1b[0m\x1b[0;36m-\x1b[0m\x1b[0;36m-\x1b[0m (esc)

label should be no-op if color is disabled:

  $ hg log --color=never -l 1 --template '{label(red, "text\n")}'
  text
  $ hg log --config extensions.color=! -l 1 --template '{label(red, "text\n")}'
  text

Test branches inside if statement:

  $ hg log -r 0 --template '{if(branches, "yes", "no")}\n'
  no

Test dict constructor:

  $ hg log -r 0 -T '{dict(y=node|short, x=rev)}\n'
  y=f7769ec2ab97 x=0
  $ hg log -r 0 -T '{dict(x=rev, y=node|short) % "{key}={value}\n"}'
  x=0
  y=f7769ec2ab97
  $ hg log -r 0 -T '{dict(x=rev, y=node|short)|json}\n'
  {"x": 0, "y": "f7769ec2ab97"}
  $ hg log -r 0 -T '{dict()|json}\n'
  {}

  $ hg log -r 0 -T '{dict(rev, node=node|short)}\n'
  rev=0 node=f7769ec2ab97
  $ hg log -r 0 -T '{dict(rev, node|short)}\n'
  rev=0 node=f7769ec2ab97

  $ hg log -r 0 -T '{dict(rev, rev=rev)}\n'
  hg: parse error: duplicated dict key 'rev' inferred
  [255]
  $ hg log -r 0 -T '{dict(node, node|short)}\n'
  hg: parse error: duplicated dict key 'node' inferred
  [255]
  $ hg log -r 0 -T '{dict(1 + 2)}'
  hg: parse error: dict key cannot be inferred
  [255]

  $ hg log -r 0 -T '{dict(x=rev, x=node)}'
  hg: parse error: dict got multiple values for keyword argument 'x'
  [255]

Test get function:

  $ hg log -r 0 --template '{get(extras, "branch")}\n'
  default
  $ hg log -r 0 --template '{get(extras, "br{"anch"}")}\n'
  default
  $ hg log -r 0 --template '{get(files, "should_fail")}\n'
  hg: parse error: not a dictionary
  (get() expects a dict as first argument)
  [255]

Test json filter applied to wrapped object:

  $ hg log -r0 -T '{files|json}\n'
  ["a"]
  $ hg log -r0 -T '{extras|json}\n'
  {"branch": "default"}
  $ hg log -r0 -T '{date|json}\n'
  [0, 0]

Test json filter applied to map result:

  $ hg log -r0 -T '{json(extras % "{key}")}\n'
  ["branch"]

Test localdate(date, tz) function:

  $ TZ=JST-09 hg log -r0 -T '{date|localdate|isodate}\n'
  1970-01-01 09:00 +0900
  $ TZ=JST-09 hg log -r0 -T '{localdate(date, "UTC")|isodate}\n'
  1970-01-01 00:00 +0000
  $ TZ=JST-09 hg log -r0 -T '{localdate(date, "blahUTC")|isodate}\n'
  hg: parse error: localdate expects a timezone
  [255]
  $ TZ=JST-09 hg log -r0 -T '{localdate(date, "+0200")|isodate}\n'
  1970-01-01 02:00 +0200
  $ TZ=JST-09 hg log -r0 -T '{localdate(date, "0")|isodate}\n'
  1970-01-01 00:00 +0000
  $ TZ=JST-09 hg log -r0 -T '{localdate(date, 0)|isodate}\n'
  1970-01-01 00:00 +0000
  $ hg log -r0 -T '{localdate(date, "invalid")|isodate}\n'
  hg: parse error: localdate expects a timezone
  [255]
  $ hg log -r0 -T '{localdate(date, date)|isodate}\n'
  hg: parse error: localdate expects a timezone
  [255]

Test shortest(node) function:

  $ echo b > b
  $ hg ci -qAm b
  $ hg log --template '{shortest(node)}\n'
  e777
  bcc7
  f776
  $ hg log --template '{shortest(node, 10)}\n'
  e777603221
  bcc7ff960b
  f7769ec2ab
  $ hg log --template '{node|shortest}\n' -l1
  e777

  $ hg log -r 0 -T '{shortest(node, "1{"0"}")}\n'
  f7769ec2ab
  $ hg log -r 0 -T '{shortest(node, "not an int")}\n'
  hg: parse error: shortest() expects an integer minlength
  [255]

  $ hg log -r 'wdir()' -T '{node|shortest}\n'
  ffff

  $ hg log --template '{shortest("f")}\n' -l1
  f

  $ hg log --template '{shortest("0123456789012345678901234567890123456789")}\n' -l1
  0123456789012345678901234567890123456789

  $ hg log --template '{shortest("01234567890123456789012345678901234567890123456789")}\n' -l1
  01234567890123456789012345678901234567890123456789

  $ hg log --template '{shortest("not a hex string")}\n' -l1
  not a hex string

  $ hg log --template '{shortest("not a hex string, but it'\''s 40 bytes long")}\n' -l1
  not a hex string, but it's 40 bytes long

  $ hg log --template '{shortest("ffffffffffffffffffffffffffffffffffffffff")}\n' -l1
  ffff

  $ hg log --template '{shortest("fffffff")}\n' -l1
  ffff

  $ hg log --template '{shortest("ff")}\n' -l1
  ffff

  $ cd ..

Test shortest(node) with the repo having short hash collision:

  $ hg init hashcollision
  $ cd hashcollision
  $ cat <<EOF >> .hg/hgrc
  > [experimental]
  > evolution.createmarkers=True
  > EOF
  $ echo 0 > a
  $ hg ci -qAm 0
  $ for i in 17 129 248 242 480 580 617 1057 2857 4025; do
  >   hg up -q 0
  >   echo $i > a
  >   hg ci -qm $i
  > done
  $ hg up -q null
  $ hg log -r0: -T '{rev}:{node}\n'
  0:b4e73ffab476aa0ee32ed81ca51e07169844bc6a
  1:11424df6dc1dd4ea255eae2b58eaca7831973bbc
  2:11407b3f1b9c3e76a79c1ec5373924df096f0499
  3:11dd92fe0f39dfdaacdaa5f3997edc533875cfc4
  4:10776689e627b465361ad5c296a20a487e153ca4
  5:a00be79088084cb3aff086ab799f8790e01a976b
  6:a0b0acd79b4498d0052993d35a6a748dd51d13e6
  7:a0457b3450b8e1b778f1163b31a435802987fe5d
  8:c56256a09cd28e5764f32e8e2810d0f01e2e357a
  9:c5623987d205cd6d9d8389bfc40fff9dbb670b48
  10:c562ddd9c94164376c20b86b0b4991636a3bf84f
  $ hg debugobsolete a00be79088084cb3aff086ab799f8790e01a976b
  obsoleted 1 changesets
  $ hg debugobsolete c5623987d205cd6d9d8389bfc40fff9dbb670b48
  obsoleted 1 changesets
  $ hg debugobsolete c562ddd9c94164376c20b86b0b4991636a3bf84f
  obsoleted 1 changesets

 nodes starting with '11' (we don't have the revision number '11' though)

  $ hg log -r 1:3 -T '{rev}:{shortest(node, 0)}\n'
  1:1142
  2:1140
  3:11d

 '5:a00' is hidden, but still we have two nodes starting with 'a0'

  $ hg log -r 6:7 -T '{rev}:{shortest(node, 0)}\n'
  6:a0b
  7:a04

 node '10' conflicts with the revision number '10' even if it is hidden
 (we could exclude hidden revision numbers, but currently we don't)

  $ hg log -r 4 -T '{rev}:{shortest(node, 0)}\n'
  4:107
  $ hg log -r 4 -T '{rev}:{shortest(node, 0)}\n' --hidden
  4:107

 node 'c562' should be unique if the other 'c562' nodes are hidden
 (but we don't try the slow path to filter out hidden nodes for now)

  $ hg log -r 8 -T '{rev}:{node|shortest}\n'
  8:c5625
  $ hg log -r 8:10 -T '{rev}:{node|shortest}\n' --hidden
  8:c5625
  9:c5623
  10:c562d

  $ cd ..

Test pad function

  $ cd r

  $ hg log --template '{pad(rev, 20)} {author|user}\n'
  2                    test
  1                    {node|short}
  0                    test

  $ hg log --template '{pad(rev, 20, " ", True)} {author|user}\n'
                     2 test
                     1 {node|short}
                     0 test

  $ hg log --template '{pad(rev, 20, "-", False)} {author|user}\n'
  2------------------- test
  1------------------- {node|short}
  0------------------- test

Test template string in pad function

  $ hg log -r 0 -T '{pad("\{{rev}}", 10)} {author|user}\n'
  {0}        test

  $ hg log -r 0 -T '{pad(r"\{rev}", 10)} {author|user}\n'
  \{rev}     test

Test width argument passed to pad function

  $ hg log -r 0 -T '{pad(rev, "1{"0"}")} {author|user}\n'
  0          test
  $ hg log -r 0 -T '{pad(rev, "not an int")}\n'
  hg: parse error: pad() expects an integer width
  [255]

Test invalid fillchar passed to pad function

  $ hg log -r 0 -T '{pad(rev, 10, "")}\n'
  hg: parse error: pad() expects a single fill character
  [255]
  $ hg log -r 0 -T '{pad(rev, 10, "--")}\n'
  hg: parse error: pad() expects a single fill character
  [255]

Test boolean argument passed to pad function

 no crash

  $ hg log -r 0 -T '{pad(rev, 10, "-", "f{"oo"}")}\n'
  ---------0

 string/literal

  $ hg log -r 0 -T '{pad(rev, 10, "-", "false")}\n'
  ---------0
  $ hg log -r 0 -T '{pad(rev, 10, "-", false)}\n'
  0---------
  $ hg log -r 0 -T '{pad(rev, 10, "-", "")}\n'
  0---------

 unknown keyword is evaluated to ''

  $ hg log -r 0 -T '{pad(rev, 10, "-", unknownkeyword)}\n'
  0---------

Test separate function

  $ hg log -r 0 -T '{separate("-", "", "a", "b", "", "", "c", "")}\n'
  a-b-c
  $ hg log -r 0 -T '{separate(" ", "{rev}:{node|short}", author|user, branch)}\n'
  0:f7769ec2ab97 test default
  $ hg log -r 0 --color=always -T '{separate(" ", "a", label(red, "b"), "c", label(red, ""), "d")}\n'
  a \x1b[0;31mb\x1b[0m c d (esc)

Test boolean expression/literal passed to if function

  $ hg log -r 0 -T '{if(rev, "rev 0 is True")}\n'
  rev 0 is True
  $ hg log -r 0 -T '{if(0, "literal 0 is True as well")}\n'
  literal 0 is True as well
  $ hg log -r 0 -T '{if(min(revset(r"0")), "0 of hybriditem is also True")}\n'
  0 of hybriditem is also True
  $ hg log -r 0 -T '{if("", "", "empty string is False")}\n'
  empty string is False
  $ hg log -r 0 -T '{if(revset(r"0 - 0"), "", "empty list is False")}\n'
  empty list is False
  $ hg log -r 0 -T '{if(revset(r"0"), "non-empty list is True")}\n'
  non-empty list is True
  $ hg log -r 0 -T '{if(revset(r"0") % "", "list of empty strings is True")}\n'
  list of empty strings is True
  $ hg log -r 0 -T '{if(true, "true is True")}\n'
  true is True
  $ hg log -r 0 -T '{if(false, "", "false is False")}\n'
  false is False
  $ hg log -r 0 -T '{if("false", "non-empty string is True")}\n'
  non-empty string is True

Test ifcontains function

  $ hg log --template '{rev} {ifcontains(rev, "2 two 0", "is in the string", "is not")}\n'
  2 is in the string
  1 is not
  0 is in the string

  $ hg log -T '{rev} {ifcontains(rev, "2 two{" 0"}", "is in the string", "is not")}\n'
  2 is in the string
  1 is not
  0 is in the string

  $ hg log --template '{rev} {ifcontains("a", file_adds, "added a", "did not add a")}\n'
  2 did not add a
  1 did not add a
  0 added a

  $ hg log --debug -T '{rev}{ifcontains(1, parents, " is parent of 1")}\n'
  2 is parent of 1
  1
  0

  $ hg log -l1 -T '{ifcontains("branch", extras, "t", "f")}\n'
  t
  $ hg log -l1 -T '{ifcontains("branch", extras % "{key}", "t", "f")}\n'
  t
  $ hg log -l1 -T '{ifcontains("branc", extras % "{key}", "t", "f")}\n'
  f
  $ hg log -l1 -T '{ifcontains("branc", stringify(extras % "{key}"), "t", "f")}\n'
  t

Test revset function

  $ hg log --template '{rev} {ifcontains(rev, revset("."), "current rev", "not current rev")}\n'
  2 current rev
  1 not current rev
  0 not current rev

  $ hg log --template '{rev} {ifcontains(rev, revset(". + .^"), "match rev", "not match rev")}\n'
  2 match rev
  1 match rev
  0 not match rev

  $ hg log -T '{ifcontains(desc, revset(":"), "", "type not match")}\n' -l1
  type not match

  $ hg log --template '{rev} Parents: {revset("parents(%s)", rev)}\n'
  2 Parents: 1
  1 Parents: 0
  0 Parents: 

  $ cat >> .hg/hgrc <<EOF
  > [revsetalias]
  > myparents(\$1) = parents(\$1)
  > EOF
  $ hg log --template '{rev} Parents: {revset("myparents(%s)", rev)}\n'
  2 Parents: 1
  1 Parents: 0
  0 Parents: 

  $ hg log --template 'Rev: {rev}\n{revset("::%s", rev) % "Ancestor: {revision}\n"}\n'
  Rev: 2
  Ancestor: 0
  Ancestor: 1
  Ancestor: 2
  
  Rev: 1
  Ancestor: 0
  Ancestor: 1
  
  Rev: 0
  Ancestor: 0
  
  $ hg log --template '{revset("TIP"|lower)}\n' -l1
  2

  $ hg log -T '{revset("%s", "t{"ip"}")}\n' -l1
  2

 a list template is evaluated for each item of revset/parents

  $ hg log -T '{rev} p: {revset("p1(%s)", rev) % "{rev}:{node|short}"}\n'
  2 p: 1:bcc7ff960b8e
  1 p: 0:f7769ec2ab97
  0 p: 

  $ hg log --debug -T '{rev} p:{parents % " {rev}:{node|short}"}\n'
  2 p: 1:bcc7ff960b8e -1:000000000000
  1 p: 0:f7769ec2ab97 -1:000000000000
  0 p: -1:000000000000 -1:000000000000

 therefore, 'revcache' should be recreated for each rev

  $ hg log -T '{rev} {file_adds}\np {revset("p1(%s)", rev) % "{file_adds}"}\n'
  2 aa b
  p 
  1 
  p a
  0 a
  p 

  $ hg log --debug -T '{rev} {file_adds}\np {parents % "{file_adds}"}\n'
  2 aa b
  p 
  1 
  p a
  0 a
  p 

a revset item must be evaluated as an integer revision, not an offset from tip

  $ hg log -l 1 -T '{revset("null") % "{rev}:{node|short}"}\n'
  -1:000000000000
  $ hg log -l 1 -T '{revset("%s", "null") % "{rev}:{node|short}"}\n'
  -1:000000000000

join() should pick '{rev}' from revset items:

  $ hg log -R ../a -T '{join(revset("parents(%d)", rev), ", ")}\n' -r6
  4, 5

on the other hand, parents are formatted as '{rev}:{node|formatnode}' by
default. join() should agree with the default formatting:

  $ hg log -R ../a -T '{join(parents, ", ")}\n' -r6
  5:13207e5a10d9, 4:bbe44766e73d

  $ hg log -R ../a -T '{join(parents, ",\n")}\n' -r6 --debug
  5:13207e5a10d9fd28ec424934298e176197f2c67f,
  4:bbe44766e73d5f11ed2177f1838de10c53ef3e74

Invalid arguments passed to revset()

  $ hg log -T '{revset("%whatever", 0)}\n'
  hg: parse error: unexpected revspec format character w
  [255]
  $ hg log -T '{revset("%lwhatever", files)}\n'
  hg: parse error: unexpected revspec format character w
  [255]
  $ hg log -T '{revset("%s %s", 0)}\n'
  hg: parse error: missing argument for revspec
  [255]
  $ hg log -T '{revset("", 0)}\n'
  hg: parse error: too many revspec arguments specified
  [255]
  $ hg log -T '{revset("%s", 0, 1)}\n'
  hg: parse error: too many revspec arguments specified
  [255]
  $ hg log -T '{revset("%", 0)}\n'
  hg: parse error: incomplete revspec format character
  [255]
  $ hg log -T '{revset("%l", 0)}\n'
  hg: parse error: incomplete revspec format character
  [255]
  $ hg log -T '{revset("%d", 'foo')}\n'
  hg: parse error: invalid argument for revspec
  [255]
  $ hg log -T '{revset("%ld", files)}\n'
  hg: parse error: invalid argument for revspec
  [255]
  $ hg log -T '{revset("%ls", 0)}\n'
  hg: parse error: invalid argument for revspec
  [255]
  $ hg log -T '{revset("%b", 'foo')}\n'
  hg: parse error: invalid argument for revspec
  [255]
  $ hg log -T '{revset("%lb", files)}\n'
  hg: parse error: invalid argument for revspec
  [255]
  $ hg log -T '{revset("%r", 0)}\n'
  hg: parse error: invalid argument for revspec
  [255]

Test files function

  $ hg log -T "{rev}\n{join(files('*'), '\n')}\n"
  2
  a
  aa
  b
  1
  a
  0
  a

  $ hg log -T "{rev}\n{join(files('aa'), '\n')}\n"
  2
  aa
  1
  
  0
  
  $ hg rm a
  $ hg log -r "wdir()" -T "{rev}\n{join(files('*'), '\n')}\n"
  2147483647
  aa
  b
  $ hg revert a

Test relpath function

  $ hg log -r0 -T '{files % "{file|relpath}\n"}'
  a
  $ cd ..
  $ hg log -R r -r0 -T '{files % "{file|relpath}\n"}'
  r/a

Test stringify on sub expressions

  $ hg log -R a -r 8 --template '{join(files, if("1", if("1", ", ")))}\n'
  fourth, second, third
  $ hg log -R a -r 8 --template '{strip(if("1", if("1", "-abc-")), if("1", if("1", "-")))}\n'
  abc

Test splitlines

  $ hg log -Gv -R a --template "{splitlines(desc) % 'foo {line}\n'}"
  @  foo Modify, add, remove, rename
  |
  o  foo future
  |
  o  foo third
  |
  o  foo second
  
  o    foo merge
  |\
  | o  foo new head
  | |
  o |  foo new branch
  |/
  o  foo no user, no domain
  |
  o  foo no person
  |
  o  foo other 1
  |  foo other 2
  |  foo
  |  foo other 3
  o  foo line 1
     foo line 2

  $ hg log -R a -r0 -T '{desc|splitlines}\n'
  line 1 line 2
  $ hg log -R a -r0 -T '{join(desc|splitlines, "|")}\n'
  line 1|line 2

Test startswith
  $ hg log -Gv -R a --template "{startswith(desc)}"
  hg: parse error: startswith expects two arguments
  [255]

  $ hg log -Gv -R a --template "{startswith('line', desc)}"
  @
  |
  o
  |
  o
  |
  o
  
  o
  |\
  | o
  | |
  o |
  |/
  o
  |
  o
  |
  o
  |
  o  line 1
     line 2

Test word function (including index out of bounds graceful failure)

  $ hg log -Gv -R a --template "{word('1', desc)}"
  @  add,
  |
  o
  |
  o
  |
  o
  
  o
  |\
  | o  head
  | |
  o |  branch
  |/
  o  user,
  |
  o  person
  |
  o  1
  |
  o  1
  

Test word third parameter used as splitter

  $ hg log -Gv -R a --template "{word('0', desc, 'o')}"
  @  M
  |
  o  future
  |
  o  third
  |
  o  sec
  
  o    merge
  |\
  | o  new head
  | |
  o |  new branch
  |/
  o  n
  |
  o  n
  |
  o
  |
  o  line 1
     line 2

Test word error messages for not enough and too many arguments

  $ hg log -Gv -R a --template "{word('0')}"
  hg: parse error: word expects two or three arguments, got 1
  [255]

  $ hg log -Gv -R a --template "{word('0', desc, 'o', 'h', 'b', 'o', 'y')}"
  hg: parse error: word expects two or three arguments, got 7
  [255]

Test word for integer literal

  $ hg log -R a --template "{word(2, desc)}\n" -r0
  line

Test word for invalid numbers

  $ hg log -Gv -R a --template "{word('a', desc)}"
  hg: parse error: word expects an integer index
  [255]

Test word for out of range

  $ hg log -R a --template "{word(10000, desc)}"
  $ hg log -R a --template "{word(-10000, desc)}"

Test indent and not adding to empty lines

  $ hg log -T "-----\n{indent(desc, '>> ', ' > ')}\n" -r 0:1 -R a
  -----
   > line 1
  >> line 2
  -----
   > other 1
  >> other 2
  
  >> other 3

Test with non-strings like dates

  $ hg log -T "{indent(date, '   ')}\n" -r 2:3 -R a
     1200000.00
     1300000.00

json filter should escape HTML tags so that the output can be embedded in hgweb:

  $ hg log -T "{'<foo@example.org>'|json}\n" -R a -l1
  "\u003cfoo@example.org\u003e"

Set up repository for non-ascii encoding tests:

  $ hg init nonascii
  $ cd nonascii
  $ $PYTHON <<EOF
  > open('latin1', 'wb').write(b'\xe9')
  > open('utf-8', 'wb').write(b'\xc3\xa9')
  > EOF
  $ HGENCODING=utf-8 hg branch -q `cat utf-8`
  $ HGENCODING=utf-8 hg ci -qAm "non-ascii branch: `cat utf-8`" utf-8

json filter should try round-trip conversion to utf-8:

  $ HGENCODING=ascii hg log -T "{branch|json}\n" -r0
  "\u00e9"
  $ HGENCODING=ascii hg log -T "{desc|json}\n" -r0
  "non-ascii branch: \u00e9"

json filter should take input as utf-8 if it was converted from utf-8:

  $ HGENCODING=latin-1 hg log -T "{branch|json}\n" -r0
  "\u00e9"
  $ HGENCODING=latin-1 hg log -T "{desc|json}\n" -r0
  "non-ascii branch: \u00e9"

json filter takes input as utf-8b:

  $ HGENCODING=ascii hg log -T "{'`cat utf-8`'|json}\n" -l1
  "\u00e9"
  $ HGENCODING=ascii hg log -T "{'`cat latin1`'|json}\n" -l1
  "\udce9"

utf8 filter:

  $ HGENCODING=ascii hg log -T "round-trip: {branch|utf8|hex}\n" -r0
  round-trip: c3a9
  $ HGENCODING=latin1 hg log -T "decoded: {'`cat latin1`'|utf8|hex}\n" -l1
  decoded: c3a9
  $ HGENCODING=ascii hg log -T "replaced: {'`cat latin1`'|utf8|hex}\n" -l1
  abort: decoding near * (glob)
  [255]
  $ hg log -T "coerced to string: {rev|utf8}\n" -r0
  coerced to string: 0

pad width:

  $ HGENCODING=utf-8 hg debugtemplate "{pad('`cat utf-8`', 2, '-')}\n"
  \xc3\xa9- (esc)

  $ cd ..
