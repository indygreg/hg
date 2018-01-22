#require test-repo jshint hg10

  $ . "$TESTDIR/helpers-testrepo.sh"

run jshint on all tracked files ending in .js except vendored dependencies

  $ cd "`dirname "$TESTDIR"`"

  $ testrepohg locate 'set:**.js' \
  > 2>/dev/null \
  > | xargs jshint
