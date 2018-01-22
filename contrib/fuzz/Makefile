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

all: bdiff

oss-fuzz: bdiff_fuzzer

.PHONY: all oss-fuzz
