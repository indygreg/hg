Test template syntax and basic functionality
============================================

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

Set up phase:

  $ hg phase -r 5 --public
  $ hg phase -r 7 --secret --force

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
  $ hg log -R a -r 2 --template '{sub("n", r"\\x2d", desc)}\n'
  \x2do perso\x2d
  $ hg log -R a -r 2 --template '{sub("n", "\x2d", "no perso\x6e")}\n'
  -o perso-
  $ hg log -R a -r 2 --template '{sub("n", r"\\x2d", r"no perso\x6e")}\n'
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
