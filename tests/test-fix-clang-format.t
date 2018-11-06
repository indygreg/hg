#require clang-format

Test that a simple "hg fix" configuration for clang-format works.

  $ cat >> $HGRCPATH <<EOF
  > [extensions]
  > fix =
  > [experimental]
  > evolution.createmarkers=True
  > evolution.allowunstable=True
  > [fix]
  > clang-format:command=clang-format --style=Google --assume-filename={rootpath}
  > clang-format:linerange=--lines={first}:{last}
  > clang-format:pattern=set:**.cpp or **.hpp
  > EOF

  $ hg init repo
  $ cd repo

  $ printf "void foo(){int x=2;}\n" > foo.cpp
  $ printf "void\nfoo();\n" > foo.hpp
  $ hg commit -Am "foo commit"
  adding foo.cpp
  adding foo.hpp
  $ hg cat -r tip *
  void foo(){int x=2;}
  void
  foo();
  $ hg fix -r tip
  $ hg cat -r tip *
  void foo() { int x = 2; }
  void foo();

  $ cd ..
