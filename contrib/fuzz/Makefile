fuzzutil.o: fuzzutil.cc fuzzutil.h
	$$CXX $$CXXFLAGS -g -O1 -fsanitize=fuzzer-no-link,address \
	  -std=c++17 \
	  -I../../mercurial -c -o fuzzutil.o fuzzutil.cc

fuzzutil-oss-fuzz.o: fuzzutil.cc fuzzutil.h
	$$CXX $$CXXFLAGS -std=c++17 \
	  -I../../mercurial -c -o fuzzutil-oss-fuzz.o fuzzutil.cc

bdiff.o: ../../mercurial/bdiff.c
	$$CC $$CFLAGS -fsanitize=fuzzer-no-link,address -c -o bdiff.o \
	  ../../mercurial/bdiff.c

bdiff: bdiff.cc bdiff.o fuzzutil.o
	$$CXX $$CXXFLAGS -DHG_FUZZER_INCLUDE_MAIN=1 -g -O1 -fsanitize=fuzzer-no-link,address \
	  -std=c++17 \
	  -I../../mercurial bdiff.cc bdiff.o fuzzutil.o -o bdiff

bdiff-oss-fuzz.o: ../../mercurial/bdiff.c
	$$CC $$CFLAGS -c -o bdiff-oss-fuzz.o ../../mercurial/bdiff.c

bdiff_fuzzer: bdiff.cc bdiff-oss-fuzz.o fuzzutil-oss-fuzz.o
	$$CXX $$CXXFLAGS -std=c++17 -I../../mercurial bdiff.cc \
	  bdiff-oss-fuzz.o fuzzutil-oss-fuzz.o -lFuzzingEngine -o \
	  $$OUT/bdiff_fuzzer

x%.o: ../../mercurial/thirdparty/xdiff/x%.c ../../mercurial/thirdparty/xdiff/*.h
	$$CC -g -O1 -fsanitize=fuzzer-no-link,address -c \
	  -o $@ \
	  $<

xdiff: xdiff.cc xdiffi.o xprepare.o xutils.o fuzzutil.o
	$$CXX $$CXXFLAGS -DHG_FUZZER_INCLUDE_MAIN=1 -g -O1 -fsanitize=fuzzer-no-link,address \
	  -I../../mercurial xdiff.cc \
	  xdiffi.o xprepare.o xutils.o fuzzutil.o -o xdiff

fuzz-x%.o: ../../mercurial/thirdparty/xdiff/x%.c ../../mercurial/thirdparty/xdiff/*.h
	$$CC $$CFLAGS -c \
	  -o $@ \
	  $<

xdiff_fuzzer: xdiff.cc fuzz-xdiffi.o fuzz-xprepare.o fuzz-xutils.o fuzzutil-oss-fuzz.o
	$$CXX $$CXXFLAGS -std=c++17 -I../../mercurial xdiff.cc \
	  fuzz-xdiffi.o fuzz-xprepare.o fuzz-xutils.o fuzzutil-oss-fuzz.o \
	  -lFuzzingEngine -o $$OUT/xdiff_fuzzer

all: bdiff xdiff

clean:
	rm *.o *_fuzzer \
	  bdiff \
	  xdiff

oss-fuzz: bdiff_fuzzer xdiff_fuzzer

.PHONY: all clean oss-fuzz
