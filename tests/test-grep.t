  $ hg init t
  $ cd t
  $ echo import > port
  $ hg add port
  $ hg commit -m 0 -u spam -d '0 0'
  $ echo export >> port
  $ hg commit -m 1 -u eggs -d '1 0'
  $ echo export > port
  $ echo vaportight >> port
  $ echo 'import/export' >> port
  $ hg commit -m 2 -u spam -d '2 0'
  $ echo 'import/export' >> port
  $ hg commit -m 3 -u eggs -d '3 0'
  $ head -n 3 port > port1
  $ mv port1 port
  $ hg commit -m 4 -u spam -d '4 0'

pattern error

  $ hg grep '**test**'
  grep: invalid match pattern: nothing to repeat
  [1]

simple

  $ hg grep -r tip:0 '.*'
  port:4:export
  port:4:vaportight
  port:4:import/export
  $ hg grep -r tip:0 port port
  port:4:export
  port:4:vaportight
  port:4:import/export

simple with color

  $ hg --config extensions.color= grep --config color.mode=ansi \
  >     --color=always port port -r tip:0
  \x1b[0;35mport\x1b[0m\x1b[0;36m:\x1b[0m\x1b[0;32m4\x1b[0m\x1b[0;36m:\x1b[0mex\x1b[0;31;1mport\x1b[0m (esc)
  \x1b[0;35mport\x1b[0m\x1b[0;36m:\x1b[0m\x1b[0;32m4\x1b[0m\x1b[0;36m:\x1b[0mva\x1b[0;31;1mport\x1b[0might (esc)
  \x1b[0;35mport\x1b[0m\x1b[0;36m:\x1b[0m\x1b[0;32m4\x1b[0m\x1b[0;36m:\x1b[0mim\x1b[0;31;1mport\x1b[0m/ex\x1b[0;31;1mport\x1b[0m (esc)

simple templated

  $ hg grep port -r tip:0 \
  > -T '{file}:{rev}:{node|short}:{texts % "{if(matched, text|upper, text)}"}\n'
  port:4:914fa752cdea:exPORT
  port:4:914fa752cdea:vaPORTight
  port:4:914fa752cdea:imPORT/exPORT

  $ hg grep port -r tip:0 -T '{file}:{rev}:{texts}\n'
  port:4:export
  port:4:vaportight
  port:4:import/export

  $ hg grep port -r tip:0 -T '{file}:{tags}:{texts}\n'
  port:tip:export
  port:tip:vaportight
  port:tip:import/export

simple JSON (no "change" field)

  $ hg grep -r tip:0 -Tjson port
  [
   {
    "date": [4, 0],
    "file": "port",
    "line_number": 1,
    "node": "914fa752cdea87777ac1a8d5c858b0c736218f6c",
    "rev": 4,
    "texts": [{"matched": false, "text": "ex"}, {"matched": true, "text": "port"}],
    "user": "spam"
   },
   {
    "date": [4, 0],
    "file": "port",
    "line_number": 2,
    "node": "914fa752cdea87777ac1a8d5c858b0c736218f6c",
    "rev": 4,
    "texts": [{"matched": false, "text": "va"}, {"matched": true, "text": "port"}, {"matched": false, "text": "ight"}],
    "user": "spam"
   },
   {
    "date": [4, 0],
    "file": "port",
    "line_number": 3,
    "node": "914fa752cdea87777ac1a8d5c858b0c736218f6c",
    "rev": 4,
    "texts": [{"matched": false, "text": "im"}, {"matched": true, "text": "port"}, {"matched": false, "text": "/ex"}, {"matched": true, "text": "port"}],
    "user": "spam"
   }
  ]

simple JSON without matching lines

  $ hg grep -r tip:0 -Tjson -l port
  [
   {
    "date": [4, 0],
    "file": "port",
    "line_number": 1,
    "node": "914fa752cdea87777ac1a8d5c858b0c736218f6c",
    "rev": 4,
    "user": "spam"
   }
  ]

all

  $ hg grep --traceback --all -nu port port
  port:4:4:-:spam:import/export
  port:3:4:+:eggs:import/export
  port:2:1:-:spam:import
  port:2:2:-:spam:export
  port:2:1:+:spam:export
  port:2:2:+:spam:vaportight
  port:2:3:+:spam:import/export
  port:1:2:+:eggs:export
  port:0:1:+:spam:import

all JSON

  $ hg grep --all -Tjson port port
  [
   {
    "change": "-",
    "date": [4, 0],
    "file": "port",
    "line_number": 4,
    "node": "914fa752cdea87777ac1a8d5c858b0c736218f6c",
    "rev": 4,
    "texts": [{"matched": false, "text": "im"}, {"matched": true, "text": "port"}, {"matched": false, "text": "/ex"}, {"matched": true, "text": "port"}],
    "user": "spam"
   },
   {
    "change": "+",
    "date": [3, 0],
    "file": "port",
    "line_number": 4,
    "node": "95040cfd017d658c536071c6290230a613c4c2a6",
    "rev": 3,
    "texts": [{"matched": false, "text": "im"}, {"matched": true, "text": "port"}, {"matched": false, "text": "/ex"}, {"matched": true, "text": "port"}],
    "user": "eggs"
   },
   {
    "change": "-",
    "date": [2, 0],
    "file": "port",
    "line_number": 1,
    "node": "3b325e3481a1f07435d81dfdbfa434d9a0245b47",
    "rev": 2,
    "texts": [{"matched": false, "text": "im"}, {"matched": true, "text": "port"}],
    "user": "spam"
   },
   {
    "change": "-",
    "date": [2, 0],
    "file": "port",
    "line_number": 2,
    "node": "3b325e3481a1f07435d81dfdbfa434d9a0245b47",
    "rev": 2,
    "texts": [{"matched": false, "text": "ex"}, {"matched": true, "text": "port"}],
    "user": "spam"
   },
   {
    "change": "+",
    "date": [2, 0],
    "file": "port",
    "line_number": 1,
    "node": "3b325e3481a1f07435d81dfdbfa434d9a0245b47",
    "rev": 2,
    "texts": [{"matched": false, "text": "ex"}, {"matched": true, "text": "port"}],
    "user": "spam"
   },
   {
    "change": "+",
    "date": [2, 0],
    "file": "port",
    "line_number": 2,
    "node": "3b325e3481a1f07435d81dfdbfa434d9a0245b47",
    "rev": 2,
    "texts": [{"matched": false, "text": "va"}, {"matched": true, "text": "port"}, {"matched": false, "text": "ight"}],
    "user": "spam"
   },
   {
    "change": "+",
    "date": [2, 0],
    "file": "port",
    "line_number": 3,
    "node": "3b325e3481a1f07435d81dfdbfa434d9a0245b47",
    "rev": 2,
    "texts": [{"matched": false, "text": "im"}, {"matched": true, "text": "port"}, {"matched": false, "text": "/ex"}, {"matched": true, "text": "port"}],
    "user": "spam"
   },
   {
    "change": "+",
    "date": [1, 0],
    "file": "port",
    "line_number": 2,
    "node": "8b20f75c158513ff5ac80bd0e5219bfb6f0eb587",
    "rev": 1,
    "texts": [{"matched": false, "text": "ex"}, {"matched": true, "text": "port"}],
    "user": "eggs"
   },
   {
    "change": "+",
    "date": [0, 0],
    "file": "port",
    "line_number": 1,
    "node": "f31323c9217050ba245ee8b537c713ec2e8ab226",
    "rev": 0,
    "texts": [{"matched": false, "text": "im"}, {"matched": true, "text": "port"}],
    "user": "spam"
   }
  ]

other

  $ hg grep -r tip:0 -l port port
  port:4
  $ hg grep -r tip:0 import port
  port:4:import/export

  $ hg cp port port2
  $ hg commit -m 4 -u spam -d '5 0'

follow

  $ hg grep -r tip:0 --traceback -f 'import\n\Z' port2
  port:0:import
  
  $ echo deport >> port2
  $ hg commit -m 5 -u eggs -d '6 0'
  $ hg grep -f --all -nu port port2
  port2:6:4:+:eggs:deport
  port:4:4:-:spam:import/export
  port:3:4:+:eggs:import/export
  port:2:1:-:spam:import
  port:2:2:-:spam:export
  port:2:1:+:spam:export
  port:2:2:+:spam:vaportight
  port:2:3:+:spam:import/export
  port:1:2:+:eggs:export
  port:0:1:+:spam:import

  $ hg up -q null
  $ hg grep -r 'reverse(:.)' -f port
  port:0:import

Test wdir
(at least, this shouldn't crash)

  $ hg up -q
  $ echo wport >> port2
  $ hg stat
  M port2
  $ hg grep -r 'wdir()' port
  port2:2147483647:export
  port2:2147483647:vaportight
  port2:2147483647:import/export
  port2:2147483647:deport
  port2:2147483647:wport

  $ cd ..
  $ hg init t2
  $ cd t2
  $ hg grep -r tip:0 foobar foo
  [1]
  $ hg grep -r tip:0 foobar
  [1]
  $ echo blue >> color
  $ echo black >> color
  $ hg add color
  $ hg ci -m 0
  $ echo orange >> color
  $ hg ci -m 1
  $ echo black > color
  $ hg ci -m 2
  $ echo orange >> color
  $ echo blue >> color
  $ hg ci -m 3
  $ hg grep -r tip:0 orange
  color:3:orange
  $ hg grep --all orange
  color:3:+:orange
  color:2:-:orange
  color:1:+:orange

  $ hg grep --diff orange
  color:3:+:orange
  color:2:-:orange
  color:1:+:orange

test substring match: '^' should only match at the beginning

  $ hg grep -r tip:0 '^.' --config extensions.color= --color debug
  [grep.filename|color][grep.sep|:][grep.rev|3][grep.sep|:][grep.match|b]lack
  [grep.filename|color][grep.sep|:][grep.rev|3][grep.sep|:][grep.match|o]range
  [grep.filename|color][grep.sep|:][grep.rev|3][grep.sep|:][grep.match|b]lue

match in last "line" without newline

  $ $PYTHON -c 'fp = open("noeol", "wb"); fp.write(b"no infinite loop"); fp.close();'
  $ hg ci -Amnoeol
  adding noeol
  $ hg grep -r tip:0 loop
  noeol:4:no infinite loop

  $ cd ..

Issue685: traceback in grep -r after rename

Got a traceback when using grep on a single
revision with renamed files.

  $ hg init issue685
  $ cd issue685
  $ echo octarine > color
  $ hg ci -Amcolor
  adding color
  $ hg rename color colour
  $ hg ci -Am rename
  $ hg grep -r tip:0 octarine
  colour:1:octarine
  color:0:octarine

Used to crash here

  $ hg grep -r 1 octarine
  colour:1:octarine
  $ cd ..


Issue337: test that grep follows parent-child relationships instead
of just using revision numbers.

  $ hg init issue337
  $ cd issue337

  $ echo white > color
  $ hg commit -A -m "0 white"
  adding color

  $ echo red > color
  $ hg commit -A -m "1 red"

  $ hg update 0
  1 files updated, 0 files merged, 0 files removed, 0 files unresolved
  $ echo black > color
  $ hg commit -A -m "2 black"
  created new head

  $ hg update --clean 1
  1 files updated, 0 files merged, 0 files removed, 0 files unresolved
  $ echo blue > color
  $ hg commit -A -m "3 blue"

  $ hg grep --all red
  color:3:-:red
  color:1:+:red

  $ hg grep --diff red
  color:3:-:red
  color:1:+:red

Issue3885: test that changing revision order does not alter the
revisions printed, just their order.

  $ hg grep --all red -r "all()"
  color:1:+:red
  color:3:-:red

  $ hg grep --all red -r "reverse(all())"
  color:3:-:red
  color:1:+:red

  $ hg grep --diff red -r "all()"
  color:1:+:red
  color:3:-:red

  $ hg grep --diff red -r "reverse(all())"
  color:3:-:red
  color:1:+:red

  $ cd ..

  $ hg init a
  $ cd a
  $ cp "$TESTDIR/binfile.bin" .
  $ hg add binfile.bin
  $ hg ci -m 'add binfile.bin'
  $ hg grep "MaCam" --all
  binfile.bin:0:+: Binary file matches

  $ hg grep "MaCam" --diff
  binfile.bin:0:+: Binary file matches

  $ cd ..

Test for showing working of allfiles flag

  $ hg init sng
  $ cd sng
  $ echo "unmod" >> um
  $ hg ci -A -m "adds unmod to um"
  adding um
  $ echo "something else" >> new
  $ hg ci -A -m "second commit"
  adding new
  $ hg grep -r "." "unmod"
  [1]
  $ hg grep -r "." "unmod" --all-files
  um:1:unmod

With --all-files, the working directory is searched by default

  $ echo modified >> new
  $ hg grep --all-files mod
  new:2147483647:modified
  um:2147483647:unmod

 which can be overridden by -rREV

  $ hg grep --all-files -r. mod
  um:1:unmod

commands.all-files can be negated by --no-all-files

  $ hg grep --config commands.grep.all-files=True mod
  new:2147483647:modified
  um:2147483647:unmod
  $ hg grep --config commands.grep.all-files=True --no-all-files mod
  um:0:unmod

--diff --all-files makes no sense since --diff is the option to grep history

  $ hg grep --diff --all-files um
  abort: --diff and --all-files are mutually exclusive
  [255]

but --diff should precede the commands.grep.all-files option

  $ hg grep --config commands.grep.all-files=True --diff mod
  um:0:+:unmod

  $ cd ..

Fix_Wdir(): test that passing wdir() t -r flag does greps on the
files modified in the working directory

  $ cd a
  $ echo "abracadara" >> a
  $ hg add a
  $ hg grep -r "wdir()" "abra"
  a:2147483647:abracadara

  $ cd ..

Change Default of grep, that is, the files not in current working directory
should not be grepp-ed on
  $ hg init ab
  $ cd ab
  $ echo "some text">>file1
  $ hg add file1
  $ hg commit -m "adds file1"
  $ hg mv file1 file2
  $ hg grep "some"
  file2:2147483647:some text
