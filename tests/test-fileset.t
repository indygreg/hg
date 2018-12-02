  $ fileset() {
  >   hg debugfileset --all-files "$@"
  > }

  $ hg init repo
  $ cd repo
  $ echo a > a1
  $ echo a > a2
  $ echo b > b1
  $ echo b > b2
  $ hg ci -Am addfiles
  adding a1
  adding a2
  adding b1
  adding b2

Test operators and basic patterns

  $ fileset -v a1
  (symbol 'a1')
  * matcher:
  <patternmatcher patterns='a1$'>
  a1
  $ fileset -v 'a*'
  (symbol 'a*')
  * matcher:
  <patternmatcher patterns='a[^/]*$'>
  a1
  a2
  $ fileset -v '"re:a\d"'
  (string 're:a\\d')
  * matcher:
  <patternmatcher patterns='a\\d'>
  a1
  a2
  $ fileset -v '!re:"a\d"'
  (not
    (kindpat
      (symbol 're')
      (string 'a\\d')))
  * matcher:
  <predicatenmatcher
    pred=<not
      <patternmatcher patterns='a\\d'>>>
  b1
  b2
  $ fileset -v 'path:a1 or glob:b?'
  (or
    (kindpat
      (symbol 'path')
      (symbol 'a1'))
    (kindpat
      (symbol 'glob')
      (symbol 'b?')))
  * matcher:
  <patternmatcher patterns='a1(?:/|$)|b.$'>
  a1
  b1
  b2
  $ fileset -v --no-show-matcher 'a1 or a2'
  (or
    (symbol 'a1')
    (symbol 'a2'))
  a1
  a2
  $ fileset 'a1 | a2'
  a1
  a2
  $ fileset 'a* and "*1"'
  a1
  $ fileset 'a* & "*1"'
  a1
  $ fileset 'not (r"a*")'
  b1
  b2
  $ fileset '! ("a*")'
  b1
  b2
  $ fileset 'a* - a1'
  a2
  $ fileset 'a_b'
  $ fileset '"\xy"'
  hg: parse error: invalid \x escape* (glob)
  [255]

Test invalid syntax

  $ fileset -v '"added"()'
  (func
    (string 'added')
    None)
  hg: parse error: not a symbol
  [255]
  $ fileset -v '()()'
  (func
    (group
      None)
    None)
  hg: parse error: not a symbol
  [255]
  $ fileset -v -- '-x'
  (negate
    (symbol 'x'))
  hg: parse error: can't use negate operator in this context
  [255]
  $ fileset -v -- '-()'
  (negate
    (group
      None))
  hg: parse error: can't use negate operator in this context
  [255]
  $ fileset -p parsed 'a, b, c'
  * parsed:
  (list
    (symbol 'a')
    (symbol 'b')
    (symbol 'c'))
  hg: parse error: can't use a list in this context
  (see 'hg help "filesets.x or y"')
  [255]

  $ fileset '"path":.'
  hg: parse error: not a symbol
  [255]
  $ fileset 'path:foo bar'
  hg: parse error at 9: invalid token
  [255]
  $ fileset 'foo:bar:baz'
  hg: parse error: not a symbol
  [255]
  $ fileset 'foo:bar()'
  hg: parse error: pattern must be a string
  [255]
  $ fileset 'foo:bar'
  hg: parse error: invalid pattern kind: foo
  [255]

Show parsed tree at stages:

  $ fileset -p unknown a
  abort: invalid stage name: unknown
  [255]

  $ fileset -p parsed 'path:a1 or glob:b?'
  * parsed:
  (or
    (kindpat
      (symbol 'path')
      (symbol 'a1'))
    (kindpat
      (symbol 'glob')
      (symbol 'b?')))
  a1
  b1
  b2

  $ fileset -p all -s 'a1 or a2 or (grep("b") & clean())'
  * parsed:
  (or
    (symbol 'a1')
    (symbol 'a2')
    (group
      (and
        (func
          (symbol 'grep')
          (string 'b'))
        (func
          (symbol 'clean')
          None))))
  * analyzed:
  (or
    (symbol 'a1')
    (symbol 'a2')
    (and
      (func
        (symbol 'grep')
        (string 'b'))
      (withstatus
        (func
          (symbol 'clean')
          None)
        (string 'clean'))))
  * optimized:
  (or
    (patterns
      (symbol 'a1')
      (symbol 'a2'))
    (and
      (withstatus
        (func
          (symbol 'clean')
          None)
        (string 'clean'))
      (func
        (symbol 'grep')
        (string 'b'))))
  * matcher:
  <unionmatcher matchers=[
    <patternmatcher patterns='a1$|a2$'>,
    <intersectionmatcher
      m1=<predicatenmatcher pred=clean>,
      m2=<predicatenmatcher pred=grep('b')>>]>
  a1
  a2
  b1
  b2

Union of basic patterns:

  $ fileset -p optimized -s -r. 'a1 or a2 or path:b1'
  * optimized:
  (patterns
    (symbol 'a1')
    (symbol 'a2')
    (kindpat
      (symbol 'path')
      (symbol 'b1')))
  * matcher:
  <patternmatcher patterns='a1$|a2$|b1(?:/|$)'>
  a1
  a2
  b1

OR expression should be reordered by weight:

  $ fileset -p optimized -s -r. 'grep("a") or a1 or grep("b") or b2'
  * optimized:
  (or
    (patterns
      (symbol 'a1')
      (symbol 'b2'))
    (func
      (symbol 'grep')
      (string 'a'))
    (func
      (symbol 'grep')
      (string 'b')))
  * matcher:
  <unionmatcher matchers=[
    <patternmatcher patterns='a1$|b2$'>,
    <predicatenmatcher pred=grep('a')>,
    <predicatenmatcher pred=grep('b')>]>
  a1
  a2
  b1
  b2

Use differencematcher for 'x and not y':

  $ fileset -p optimized -s 'a* and not a1'
  * optimized:
  (minus
    (symbol 'a*')
    (symbol 'a1'))
  * matcher:
  <differencematcher
    m1=<patternmatcher patterns='a[^/]*$'>,
    m2=<patternmatcher patterns='a1$'>>
  a2

  $ fileset -p optimized -s '!binary() and a*'
  * optimized:
  (minus
    (symbol 'a*')
    (func
      (symbol 'binary')
      None))
  * matcher:
  <differencematcher
    m1=<patternmatcher patterns='a[^/]*$'>,
    m2=<predicatenmatcher pred=binary>>
  a1
  a2

'x - y' is rewritten to 'x and not y' first so the operands can be reordered:

  $ fileset -p analyzed -p optimized -s 'a* - a1'
  * analyzed:
  (and
    (symbol 'a*')
    (not
      (symbol 'a1')))
  * optimized:
  (minus
    (symbol 'a*')
    (symbol 'a1'))
  * matcher:
  <differencematcher
    m1=<patternmatcher patterns='a[^/]*$'>,
    m2=<patternmatcher patterns='a1$'>>
  a2

  $ fileset -p analyzed -p optimized -s 'binary() - a*'
  * analyzed:
  (and
    (func
      (symbol 'binary')
      None)
    (not
      (symbol 'a*')))
  * optimized:
  (and
    (not
      (symbol 'a*'))
    (func
      (symbol 'binary')
      None))
  * matcher:
  <intersectionmatcher
    m1=<predicatenmatcher
      pred=<not
        <patternmatcher patterns='a[^/]*$'>>>,
    m2=<predicatenmatcher pred=binary>>

Test files status

  $ rm a1
  $ hg rm a2
  $ echo b >> b2
  $ hg cp b1 c1
  $ echo c > c2
  $ echo c > c3
  $ cat > .hgignore <<EOF
  > \.hgignore
  > 2$
  > EOF
  $ fileset 'modified()'
  b2
  $ fileset 'added()'
  c1
  $ fileset 'removed()'
  a2
  $ fileset 'deleted()'
  a1
  $ fileset 'missing()'
  a1
  $ fileset 'unknown()'
  c3
  $ fileset 'ignored()'
  .hgignore
  c2
  $ fileset 'hgignore()'
  .hgignore
  a2
  b2
  c2
  $ fileset 'clean()'
  b1
  $ fileset 'copied()'
  c1

Test files status in different revisions

  $ hg status -m
  M b2
  $ fileset -r0 'revs("wdir()", modified())' --traceback
  b2
  $ hg status -a
  A c1
  $ fileset -r0 'revs("wdir()", added())'
  c1
  $ hg status --change 0 -a
  A a1
  A a2
  A b1
  A b2
  $ hg status -mru
  M b2
  R a2
  ? c3
  $ fileset -r0 'added() and revs("wdir()", modified() or removed() or unknown())'
  a2
  b2
  $ fileset -r0 'added() or revs("wdir()", added())'
  a1
  a2
  b1
  b2
  c1

Test insertion of status hints

  $ fileset -p optimized 'added()'
  * optimized:
  (withstatus
    (func
      (symbol 'added')
      None)
    (string 'added'))
  c1

  $ fileset -p optimized 'a* & removed()'
  * optimized:
  (and
    (symbol 'a*')
    (withstatus
      (func
        (symbol 'removed')
        None)
      (string 'removed')))
  a2

  $ fileset -p optimized 'a* - removed()'
  * optimized:
  (minus
    (symbol 'a*')
    (withstatus
      (func
        (symbol 'removed')
        None)
      (string 'removed')))
  a1

  $ fileset -p analyzed -p optimized '(added() + removed()) - a*'
  * analyzed:
  (and
    (withstatus
      (or
        (func
          (symbol 'added')
          None)
        (func
          (symbol 'removed')
          None))
      (string 'added removed'))
    (not
      (symbol 'a*')))
  * optimized:
  (and
    (not
      (symbol 'a*'))
    (withstatus
      (or
        (func
          (symbol 'added')
          None)
        (func
          (symbol 'removed')
          None))
      (string 'added removed')))
  c1

  $ fileset -p optimized 'a* + b* + added() + unknown()'
  * optimized:
  (withstatus
    (or
      (patterns
        (symbol 'a*')
        (symbol 'b*'))
      (func
        (symbol 'added')
        None)
      (func
        (symbol 'unknown')
        None))
    (string 'added unknown'))
  a1
  a2
  b1
  b2
  c1
  c3

  $ fileset -p analyzed -p optimized 'removed() & missing() & a*'
  * analyzed:
  (and
    (withstatus
      (and
        (func
          (symbol 'removed')
          None)
        (func
          (symbol 'missing')
          None))
      (string 'removed missing'))
    (symbol 'a*'))
  * optimized:
  (and
    (symbol 'a*')
    (withstatus
      (and
        (func
          (symbol 'removed')
          None)
        (func
          (symbol 'missing')
          None))
      (string 'removed missing')))

  $ fileset -p optimized 'clean() & revs(0, added())'
  * optimized:
  (and
    (withstatus
      (func
        (symbol 'clean')
        None)
      (string 'clean'))
    (func
      (symbol 'revs')
      (list
        (symbol '0')
        (withstatus
          (func
            (symbol 'added')
            None)
          (string 'added')))))
  b1

  $ fileset -p optimized 'clean() & status(null, 0, b* & added())'
  * optimized:
  (and
    (withstatus
      (func
        (symbol 'clean')
        None)
      (string 'clean'))
    (func
      (symbol 'status')
      (list
        (symbol 'null')
        (symbol '0')
        (and
          (symbol 'b*')
          (withstatus
            (func
              (symbol 'added')
              None)
            (string 'added'))))))
  b1

Test files properties

  >>> open('bin', 'wb').write(b'\0a') and None
  $ fileset 'binary()'
  bin
  $ fileset 'binary() and unknown()'
  bin
  $ echo '^bin$' >> .hgignore
  $ fileset 'binary() and ignored()'
  bin
  $ hg add bin
  $ fileset 'binary()'
  bin

  $ fileset -p optimized -s 'binary() and b*'
  * optimized:
  (and
    (symbol 'b*')
    (func
      (symbol 'binary')
      None))
  * matcher:
  <intersectionmatcher
    m1=<patternmatcher patterns='b[^/]*$'>,
    m2=<predicatenmatcher pred=binary>>
  bin

  $ fileset 'grep("b{1}")'
  .hgignore
  b1
  b2
  c1
  $ fileset 'grep("missingparens(")'
  hg: parse error: invalid match pattern: (unbalanced parenthesis|missing \)).* (re)
  [255]

#if execbit
  $ chmod +x b2
  $ fileset 'exec()'
  b2
#endif

#if symlink
  $ ln -s b2 b2link
  $ fileset 'symlink() and unknown()'
  b2link
  $ hg add b2link
#endif

#if no-windows
  $ echo foo > con.xml
  $ fileset 'not portable()'
  con.xml
  $ hg --config ui.portablefilenames=ignore add con.xml
#endif

  >>> open('1k', 'wb').write(b' '*1024) and None
  >>> open('2k', 'wb').write(b' '*2048) and None
  $ hg add 1k 2k
  $ fileset 'size("bar")'
  hg: parse error: couldn't parse size: bar
  [255]
  $ fileset '(1k, 2k)'
  hg: parse error: can't use a list in this context
  (see 'hg help "filesets.x or y"')
  [255]
  $ fileset 'size(1k)'
  1k
  $ fileset '(1k or 2k) and size("< 2k")'
  1k
  $ fileset '(1k or 2k) and size("<=2k")'
  1k
  2k
  $ fileset '(1k or 2k) and size("> 1k")'
  2k
  $ fileset '(1k or 2k) and size(">=1K")'
  1k
  2k
  $ fileset '(1k or 2k) and size(".5KB - 1.5kB")'
  1k
  $ fileset 'size("1M")'
  $ fileset 'size("1 GB")'

Test merge states

  $ hg ci -m manychanges
  $ hg file -r . 'set:copied() & modified()'
  [1]
  $ hg up -C 0
  * files updated, 0 files merged, * files removed, 0 files unresolved (glob)
  $ echo c >> b2
  $ hg ci -m diverging b2
  created new head
  $ fileset 'resolved()'
  $ fileset 'unresolved()'
  $ hg merge
  merging b2
  warning: conflicts while merging b2! (edit, then use 'hg resolve --mark')
  * files updated, 0 files merged, 1 files removed, 1 files unresolved (glob)
  use 'hg resolve' to retry unresolved file merges or 'hg merge --abort' to abandon
  [1]
  $ fileset 'resolved()'
  $ fileset 'unresolved()'
  b2
  $ echo e > b2
  $ hg resolve -m b2
  (no more unresolved files)
  $ fileset 'resolved()'
  b2
  $ fileset 'unresolved()'
  $ hg ci -m merge

Test subrepo predicate

  $ hg init sub
  $ echo a > sub/suba
  $ hg -R sub add sub/suba
  $ hg -R sub ci -m sub
  $ echo 'sub = sub' > .hgsub
  $ hg init sub2
  $ echo b > sub2/b
  $ hg -R sub2 ci -Am sub2
  adding b
  $ echo 'sub2 = sub2' >> .hgsub
  $ fileset 'subrepo()'
  $ hg add .hgsub
  $ fileset 'subrepo()'
  sub
  sub2
  $ fileset 'subrepo("sub")'
  sub
  $ fileset 'subrepo("glob:*")'
  sub
  sub2
  $ hg ci -m subrepo

Test that .hgsubstate is updated as appropriate during a conversion.  The
saverev property is enough to alter the hashes of the subrepo.

  $ hg init ../converted
  $ hg --config extensions.convert= convert --config convert.hg.saverev=True  \
  >      sub ../converted/sub
  initializing destination ../converted/sub repository
  scanning source...
  sorting...
  converting...
  0 sub
  $ hg clone -U sub2 ../converted/sub2
  $ hg --config extensions.convert= convert --config convert.hg.saverev=True  \
  >      . ../converted
  scanning source...
  sorting...
  converting...
  4 addfiles
  3 manychanges
  2 diverging
  1 merge
  0 subrepo
  no ".hgsubstate" updates will be made for "sub2"
  $ hg up -q -R ../converted -r tip
  $ hg --cwd ../converted cat sub/suba sub2/b -r tip
  a
  b
  $ oldnode=`hg log -r tip -T "{node}\n"`
  $ newnode=`hg log -R ../converted -r tip -T "{node}\n"`
  $ [ "$oldnode" != "$newnode" ] || echo "nothing changed"

Test with a revision

  $ hg log -G --template '{rev} {desc}\n'
  @  4 subrepo
  |
  o    3 merge
  |\
  | o  2 diverging
  | |
  o |  1 manychanges
  |/
  o  0 addfiles
  
  $ echo unknown > unknown
  $ fileset -r1 'modified()'
  b2
  $ fileset -r1 'added() and c1'
  c1
  $ fileset -r1 'removed()'
  a2
  $ fileset -r1 'deleted()'
  $ fileset -r1 'unknown()'
  $ fileset -r1 'ignored()'
  $ fileset -r1 'hgignore()'
  .hgignore
  a2
  b2
  bin
  c2
  sub2
  $ fileset -r1 'binary()'
  bin
  $ fileset -r1 'size(1k)'
  1k
  $ fileset -r3 'resolved()'
  $ fileset -r3 'unresolved()'

#if execbit
  $ fileset -r1 'exec()'
  b2
#endif

#if symlink
  $ fileset -r1 'symlink()'
  b2link
#endif

#if no-windows
  $ fileset -r1 'not portable()'
  con.xml
  $ hg forget 'con.xml'
#endif

  $ fileset -r4 'subrepo("re:su.*")'
  sub
  sub2
  $ fileset -r4 'subrepo(re:su.*)'
  sub
  sub2
  $ fileset -r4 'subrepo("sub")'
  sub
  $ fileset -r4 'b2 or c1'
  b2
  c1

  >>> open('dos', 'wb').write(b"dos\r\n") and None
  >>> open('mixed', 'wb').write(b"dos\r\nunix\n") and None
  >>> open('mac', 'wb').write(b"mac\r") and None
  $ hg add dos mixed mac

(remove a1, to examine safety of 'eol' on removed files)
  $ rm a1

  $ fileset 'eol(dos)'
  dos
  mixed
  $ fileset 'eol(unix)'
  .hgignore
  .hgsub
  .hgsubstate
  b1
  b2
  b2.orig
  c1
  c2
  c3
  con.xml (no-windows !)
  mixed
  unknown
  $ fileset 'eol(mac)'
  mac

Test safety of 'encoding' on removed files

  $ fileset 'encoding("ascii")'
  .hgignore
  .hgsub
  .hgsubstate
  1k
  2k
  b1
  b2
  b2.orig
  b2link (symlink !)
  bin
  c1
  c2
  c3
  con.xml (no-windows !)
  dos
  mac
  mixed
  unknown

Test 'revs(...)'
================

small reminder of the repository state

  $ hg log -G
  @  changeset:   4:* (glob)
  |  tag:         tip
  |  user:        test
  |  date:        Thu Jan 01 00:00:00 1970 +0000
  |  summary:     subrepo
  |
  o    changeset:   3:* (glob)
  |\   parent:      2:55b05bdebf36
  | |  parent:      1:* (glob)
  | |  user:        test
  | |  date:        Thu Jan 01 00:00:00 1970 +0000
  | |  summary:     merge
  | |
  | o  changeset:   2:55b05bdebf36
  | |  parent:      0:8a9576c51c1f
  | |  user:        test
  | |  date:        Thu Jan 01 00:00:00 1970 +0000
  | |  summary:     diverging
  | |
  o |  changeset:   1:* (glob)
  |/   user:        test
  |    date:        Thu Jan 01 00:00:00 1970 +0000
  |    summary:     manychanges
  |
  o  changeset:   0:8a9576c51c1f
     user:        test
     date:        Thu Jan 01 00:00:00 1970 +0000
     summary:     addfiles
  
  $ hg status --change 0
  A a1
  A a2
  A b1
  A b2
  $ hg status --change 1
  M b2
  A 1k
  A 2k
  A b2link (no-windows !)
  A bin
  A c1
  A con.xml (no-windows !)
  R a2
  $ hg status --change 2
  M b2
  $ hg status --change 3
  M b2
  A 1k
  A 2k
  A b2link (no-windows !)
  A bin
  A c1
  A con.xml (no-windows !)
  R a2
  $ hg status --change 4
  A .hgsub
  A .hgsubstate
  $ hg status
  A dos
  A mac
  A mixed
  R con.xml (no-windows !)
  ! a1
  ? b2.orig
  ? c3
  ? unknown

Test files at -r0 should be filtered by files at wdir
-----------------------------------------------------

  $ fileset -r0 'tracked() and revs("wdir()", tracked())'
  a1
  b1
  b2

Test that "revs()" work at all
------------------------------

  $ fileset "revs('2', modified())"
  b2

Test that "revs()" work for file missing in the working copy/current context
----------------------------------------------------------------------------

(a2 not in working copy)

  $ fileset "revs('0', added())"
  a1
  a2
  b1
  b2

(none of the file exist in "0")

  $ fileset -r 0 "revs('4', added())"
  .hgsub
  .hgsubstate

Call with empty revset
--------------------------

  $ fileset "revs('2-2', modified())"

Call with revset matching multiple revs
---------------------------------------

  $ fileset "revs('0+4', added())"
  .hgsub
  .hgsubstate
  a1
  a2
  b1
  b2

overlapping set

  $ fileset "revs('1+2', modified())"
  b2

test 'status(...)'
=================

Simple case
-----------

  $ fileset "status(3, 4, added())"
  .hgsub
  .hgsubstate

use rev to restrict matched file
-----------------------------------------

  $ hg status --removed --rev 0 --rev 1
  R a2
  $ fileset "status(0, 1, removed())"
  a2
  $ fileset "tracked() and status(0, 1, removed())"
  $ fileset -r 4 "status(0, 1, removed())"
  a2
  $ fileset -r 4 "tracked() and status(0, 1, removed())"
  $ fileset "revs('4', tracked() and status(0, 1, removed()))"
  $ fileset "revs('0', tracked() and status(0, 1, removed()))"
  a2

check wdir()
------------

  $ hg status --removed  --rev 4
  R con.xml (no-windows !)
  $ fileset "status(4, 'wdir()', removed())"
  con.xml (no-windows !)

  $ hg status --removed --rev 2
  R a2
  $ fileset "status('2', 'wdir()', removed())"
  a2

test backward status
--------------------

  $ hg status --removed --rev 0 --rev 4
  R a2
  $ hg status --added --rev 4 --rev 0
  A a2
  $ fileset "status(4, 0, added())"
  a2

test cross branch status
------------------------

  $ hg status --added --rev 1 --rev 2
  A a2
  $ fileset "status(1, 2, added())"
  a2

test with multi revs revset
---------------------------
  $ hg status --added --rev 0:1 --rev 3:4
  A .hgsub
  A .hgsubstate
  A 1k
  A 2k
  A b2link (no-windows !)
  A bin
  A c1
  A con.xml (no-windows !)
  $ fileset "status('0:1', '3:4', added())"
  .hgsub
  .hgsubstate
  1k
  2k
  b2link (no-windows !)
  bin
  c1
  con.xml (no-windows !)

tests with empty value
----------------------

Fully empty revset

  $ fileset "status('', '4', added())"
  hg: parse error: first argument to status must be a revision
  [255]
  $ fileset "status('2', '', added())"
  hg: parse error: second argument to status must be a revision
  [255]

Empty revset will error at the revset layer

  $ fileset "status(' ', '4', added())"
  hg: parse error at 1: not a prefix: end
  ( 
    ^ here)
  [255]
  $ fileset "status('2', ' ', added())"
  hg: parse error at 1: not a prefix: end
  ( 
    ^ here)
  [255]
