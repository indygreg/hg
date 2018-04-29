#require clang-libfuzzer test-repo
  $ cd $TESTDIR/../contrib/fuzz
  $ make
Just run the fuzzers for five seconds each to verify it works at all.
  $ ./bdiff -max_total_time 5
  $ ./xdiff -max_total_time 5
