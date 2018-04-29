#require test-repo

  $ cd $TESTDIR/../contrib/fuzz

#if clang-libfuzzer
  $ make -s clean all
#endif
#if no-clang-libfuzzer clang-6.0
  $ make -s clean all CC=clang-6.0 CXX=clang++-6.0
#endif
#if no-clang-libfuzzer no-clang-6.0
  $ exit 80
#endif

Just run the fuzzers for five seconds each to verify it works at all.
  $ ./bdiff -max_total_time 5
  $ ./mpatch -max_total_time 5
  $ ./xdiff -max_total_time 5
