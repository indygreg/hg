bdiff.o: ../../mercurial/bdiff.c
	clang -g -O1 -fsanitize=fuzzer-no-link,address -c -o bdiff.o \
	  ../../mercurial/bdiff.c

bdiff: bdiff.cc bdiff.o
	clang -DHG_FUZZER_INCLUDE_MAIN=1 -g -O1 -fsanitize=fuzzer-no-link,address \
	  -I../../mercurial bdiff.cc bdiff.o -o bdiff

bdiff-oss-fuzz.o: ../../mercurial/bdiff.c
	$$CC $$CFLAGS -c -o bdiff-oss-fuzz.o ../../mercurial/bdiff.c

bdiff_fuzzer: bdiff.cc bdiff-oss-fuzz.o
	$$CXX $$CXXFLAGS -std=c++11 -I../../mercurial bdiff.cc \
	  bdiff-oss-fuzz.o -lFuzzingEngine -o $$OUT/bdiff_fuzzer

x%.o: ../../mercurial/thirdparty/xdiff/x%.c ../../mercurial/thirdparty/xdiff/*.h
	clang -g -O1 -fsanitize=fuzzer-no-link,address -c \
	  -o $@ \
	  $<

xdiff: xdiff.cc xdiffi.o xprepare.o  xutils.o
	clang -DHG_FUZZER_INCLUDE_MAIN=1 -g -O1 -fsanitize=fuzzer-no-link,address \
	  -I../../mercurial xdiff.cc \
	  xdiffi.o xprepare.o xutils.o -o xdiff

fuzz-x%.o: ../../mercurial/thirdparty/xdiff/x%.c ../../mercurial/thirdparty/xdiff/*.h
	$$CC $$CFLAGS -c \
	  -o $@ \
	  $<

xdiff_fuzzer: xdiff.cc fuzz-xdiffi.o fuzz-xprepare.o  fuzz-xutils.o
	$$CXX $$CXXFLAGS -std=c++11 -I../../mercurial xdiff.cc \
	  fuzz-xdiffi.o fuzz-xprepare.o fuzz-xutils.o \
	  -lFuzzingEngine -o $$OUT/xdiff_fuzzer

all: bdiff xdiff

oss-fuzz: bdiff_fuzzer xdiff_fuzzer

.PHONY: all oss-fuzz
