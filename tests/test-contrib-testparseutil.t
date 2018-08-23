  $ testparseutil="$TESTDIR"/../contrib/testparseutil.py

Internal test by doctest

  $ "$PYTHON" -m doctest "$testparseutil"

Tests for embedded python script

Typical cases

  $ "$PYTHON" "$testparseutil" -v pyembedded <<NO_CHECK_EOF
  >   >>> for f in [1, 2, 3]:
  >   ...     foo = 1
  >   >>> foo = 2
  >   $ echo "doctest is terminated by command, empty line, or comment"
  >   >>> foo = 31
  >   expected output of doctest fragment
  >   >>> foo = 32
  >   
  >   >>> foo = 33
  > 
  >   >>> foo = 34
  > comment
  >   >>> foo = 35
  > 
  >   $ "\$PYTHON" <<EOF
  >   > foo = 4
  >   > 
  >   > EOF
  >   $ cat > foo.py <<EOF
  >   > foo = 5
  >   > EOF
  >   $ cat >> foo.py <<EOF
  >   > foo = 6 # appended
  >   > EOF
  > 
  > NO_CHECK_EOF limit mark makes parsing ignore corresponded fragment
  > (this is useful to use bad code intentionally)
  > 
  >   $ "\$PYTHON" <<NO_CHECK_EOF
  >   > foo = 7 # this should be ignored at detection
  >   > NO_CHECK_EOF
  >   $ cat > foo.py <<NO_CHECK_EOF
  >   > foo = 8 # this should be ignored at detection
  >   > NO_CHECK_EOF
  > 
  > doctest fragment ended by EOF
  > 
  >   >>> foo = 9
  > NO_CHECK_EOF
  <stdin>:1: <anonymous> starts
    |for f in [1, 2, 3]:
    |    foo = 1
    |foo = 2
  <stdin>:4: <anonymous> ends
  <stdin>:5: <anonymous> starts
    |foo = 31
    |
    |foo = 32
    |
    |foo = 33
  <stdin>:10: <anonymous> ends
  <stdin>:11: <anonymous> starts
    |foo = 34
  <stdin>:12: <anonymous> ends
  <stdin>:13: <anonymous> starts
    |foo = 35
  <stdin>:14: <anonymous> ends
  <stdin>:16: <anonymous> starts
    |foo = 4
    |
  <stdin>:18: <anonymous> ends
  <stdin>:20: foo.py starts
    |foo = 5
  <stdin>:21: foo.py ends
  <stdin>:23: foo.py starts
    |foo = 6 # appended
  <stdin>:24: foo.py ends
  <stdin>:38: <anonymous> starts
    |foo = 9
  <stdin>:39: <anonymous> ends

Invalid test script

(similar test for shell script and hgrc configuration is omitted,
because this tests common base class of them)

  $ "$PYTHON" "$testparseutil" -v pyembedded <<NO_CHECK_EOF > detected
  >   $ "\$PYTHON" <<EOF
  >   > foo = 1
  > 
  >   $ "\$PYTHON" <<EOF
  >   > foo = 2
  >   $ cat > bar.py <<EOF
  >   > bar = 2 # this fragment will be detected as expected
  >   > EOF
  > 
  >   $ cat > foo.py <<EOF
  >   > foo = 3
  > NO_CHECK_EOF
  <stdin>:3: unexpected line for "heredoc python invocation"
  <stdin>:6: unexpected line for "heredoc python invocation"
  <stdin>:11: unexpected end of file for "heredoc .py file"
  [1]
  $ cat detected
  <stdin>:7: bar.py starts
    |bar = 2 # this fragment will be detected as expected
  <stdin>:8: bar.py ends

Tests for embedded shell script

  $ "$PYTHON" "$testparseutil" -v shembedded <<NO_CHECK_EOF
  >   $ cat > foo.sh <<EOF
  >   > foo = 1
  >   > 
  >   > foo = 2
  >   > EOF
  >   $ cat >> foo.sh <<EOF
  >   > foo = 3 # appended
  >   > EOF
  > 
  > NO_CHECK_EOF limit mark makes parsing ignore corresponded fragment
  > (this is useful to use bad code intentionally)
  > 
  >   $ cat > foo.sh <<NO_CHECK_EOF
  >   > # this should be ignored at detection
  >   > foo = 4
  >   > NO_CHECK_EOF
  > 
  > NO_CHECK_EOF
  <stdin>:2: foo.sh starts
    |foo = 1
    |
    |foo = 2
  <stdin>:5: foo.sh ends
  <stdin>:7: foo.sh starts
    |foo = 3 # appended
  <stdin>:8: foo.sh ends

Tests for embedded hgrc configuration

  $ "$PYTHON" "$testparseutil" -v hgrcembedded <<NO_CHECK_EOF
  >   $ cat > .hg/hgrc <<EOF
  >   > [ui]
  >   > verbose = true
  >   > 
  >   > # end of local configuration
  >   > EOF
  > 
  >   $ cat > \$HGRCPATH <<EOF
  >   > [extensions]
  >   > rebase =
  >   > # end of global configuration
  >   > EOF
  > 
  >   $ cat >> \$HGRCPATH <<EOF
  >   > # appended
  >   > [extensions]
  >   > rebase =!
  >   > EOF
  > 
  > NO_CHECK_EOF limit mark makes parsing ignore corresponded fragment
  > (this is useful to use bad code intentionally)
  > 
  >   $ cat > .hg/hgrc <<NO_CHECK_EOF
  >   > # this local configuration should be ignored at detection
  >   > [ui]
  >   > username = foo bar
  >   > NO_CHECK_EOF
  > 
  >   $ cat > \$HGRCPATH <<NO_CHECK_EOF
  >   > # this global configuration should be ignored at detection
  >   > [extensions]
  >   > foobar =
  >   > NO_CHECK_EOF
  > NO_CHECK_EOF
  <stdin>:2: .hg/hgrc starts
    |[ui]
    |verbose = true
    |
    |# end of local configuration
  <stdin>:6: .hg/hgrc ends
  <stdin>:9: $HGRCPATH starts
    |[extensions]
    |rebase =
    |# end of global configuration
  <stdin>:12: $HGRCPATH ends
  <stdin>:15: $HGRCPATH starts
    |# appended
    |[extensions]
    |rebase =!
  <stdin>:18: $HGRCPATH ends
