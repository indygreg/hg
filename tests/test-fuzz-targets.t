#require clang-libfuzzer test-repo
  $ cd $TESTDIR/../contrib/fuzz
  $ make
Just run the fuzzer for five seconds to verify it works at all.
  $ ./bdiff -max_total_time 5
