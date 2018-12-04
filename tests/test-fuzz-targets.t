#require test-repo

  $ cd $TESTDIR/../contrib/fuzz

which(1) could exit nonzero, but that's fine because we'll still end
up without a valid executable, so we don't need to check $? here.

  $ if which gmake >/dev/null 2>&1; then
  >     MAKE=gmake
  > else
  >     MAKE=make
  > fi

  $ havefuzz() {
  >     cat > $TESTTMP/dummy.cc <<EOF
  > #include <stdlib.h>
  > #include <stdint.h>
  > int LLVMFuzzerTestOneInput(const uint8_t *Data, size_t Size) { return 0; }
  > int main(int argc, char **argv) {
  >     const char data[] = "asdf";
  >     return LLVMFuzzerTestOneInput((const uint8_t *)data, 4);
  > }
  > EOF
  >     $CXX $TESTTMP/dummy.cc -o $TESTTMP/dummy \
  >        -fsanitize=fuzzer-no-link,address || return 1
  > }

#if clang-libfuzzer
  $ CXX=clang++ havefuzz || exit 80
  $ $MAKE -s clean all
#endif
#if no-clang-libfuzzer clang-6.0
  $ CXX=clang++-6.0 havefuzz || exit 80
  $ $MAKE -s clean all CC=clang-6.0 CXX=clang++-6.0
#endif
#if no-clang-libfuzzer no-clang-6.0
  $ exit 80
#endif

Just run the fuzzers for five seconds each to verify it works at all.
  $ ./bdiff -max_total_time 5
  $ ./mpatch -max_total_time 5
  $ ./xdiff -max_total_time 5
