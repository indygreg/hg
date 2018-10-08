CC = clang
CXX = clang++

all: bdiff mpatch xdiff

fuzzutil.o: fuzzutil.cc fuzzutil.h
	$(CXX) $(CXXFLAGS) -g -O1 -fsanitize=fuzzer-no-link,address \
	  -std=c++17 \
	  -I../../mercurial -c -o fuzzutil.o fuzzutil.cc

fuzzutil-oss-fuzz.o: fuzzutil.cc fuzzutil.h
	$(CXX) $(CXXFLAGS) -std=c++17 \
	  -I../../mercurial -c -o fuzzutil-oss-fuzz.o fuzzutil.cc

bdiff.o: ../../mercurial/bdiff.c
	$(CC) $(CFLAGS) -fsanitize=fuzzer-no-link,address -c -o bdiff.o \
	  ../../mercurial/bdiff.c

bdiff: bdiff.cc bdiff.o fuzzutil.o
	$(CXX) $(CXXFLAGS) -DHG_FUZZER_INCLUDE_MAIN=1 -g -O1 -fsanitize=fuzzer-no-link,address \
	  -std=c++17 \
	  -I../../mercurial bdiff.cc bdiff.o fuzzutil.o -o bdiff

bdiff-oss-fuzz.o: ../../mercurial/bdiff.c
	$(CC) $(CFLAGS) -c -o bdiff-oss-fuzz.o ../../mercurial/bdiff.c

bdiff_fuzzer: bdiff.cc bdiff-oss-fuzz.o fuzzutil-oss-fuzz.o
	$(CXX) $(CXXFLAGS) -std=c++17 -I../../mercurial bdiff.cc \
	  bdiff-oss-fuzz.o fuzzutil-oss-fuzz.o -lFuzzingEngine -o \
	  $$OUT/bdiff_fuzzer

mpatch.o: ../../mercurial/mpatch.c
	$(CC) -g -O1 -fsanitize=fuzzer-no-link,address -c -o mpatch.o \
	  ../../mercurial/mpatch.c

mpatch: CXXFLAGS += -std=c++17
mpatch: mpatch.cc mpatch.o fuzzutil.o
	$(CXX) $(CXXFLAGS) -DHG_FUZZER_INCLUDE_MAIN=1 -g -O1 -fsanitize=fuzzer-no-link,address \
	  -I../../mercurial mpatch.cc mpatch.o fuzzutil.o -o mpatch

mpatch-oss-fuzz.o: ../../mercurial/mpatch.c
	$(CC) $(CFLAGS) -c -o mpatch-oss-fuzz.o ../../mercurial/mpatch.c

mpatch_fuzzer: mpatch.cc mpatch-oss-fuzz.o fuzzutil-oss-fuzz.o
	$(CXX) $(CXXFLAGS) -std=c++17 -I../../mercurial mpatch.cc \
	  mpatch-oss-fuzz.o fuzzutil-oss-fuzz.o -lFuzzingEngine -o \
	  $$OUT/mpatch_fuzzer

mpatch_corpus.zip:
	python mpatch_corpus.py $$OUT/mpatch_fuzzer_seed_corpus.zip

x%.o: ../../mercurial/thirdparty/xdiff/x%.c ../../mercurial/thirdparty/xdiff/*.h
	$(CC) -g -O1 -fsanitize=fuzzer-no-link,address -c \
	  -o $@ \
	  $<

xdiff: CXXFLAGS += -std=c++17
xdiff: xdiff.cc xdiffi.o xprepare.o xutils.o fuzzutil.o
	$(CXX) $(CXXFLAGS) -DHG_FUZZER_INCLUDE_MAIN=1 -g -O1 -fsanitize=fuzzer-no-link,address \
	  -I../../mercurial xdiff.cc \
	  xdiffi.o xprepare.o xutils.o fuzzutil.o -o xdiff

fuzz-x%.o: ../../mercurial/thirdparty/xdiff/x%.c ../../mercurial/thirdparty/xdiff/*.h
	$(CC) $(CFLAGS) -c \
	  -o $@ \
	  $<

xdiff_fuzzer: xdiff.cc fuzz-xdiffi.o fuzz-xprepare.o fuzz-xutils.o fuzzutil-oss-fuzz.o
	$(CXX) $(CXXFLAGS) -std=c++17 -I../../mercurial xdiff.cc \
	  fuzz-xdiffi.o fuzz-xprepare.o fuzz-xutils.o fuzzutil-oss-fuzz.o \
	  -lFuzzingEngine -o $$OUT/xdiff_fuzzer

# TODO use the $OUT env var instead of hardcoding /out
/out/sanpy/bin/python:
	cd /Python-2.7.15/ && ./configure --without-pymalloc --prefix=$$OUT/sanpy CFLAGS='-O1 -fno-omit-frame-pointer -g -fwrapv -fstack-protector-strong' LDFLAGS=-lasan  && ASAN_OPTIONS=detect_leaks=0 make && make install

sanpy: /out/sanpy/bin/python

manifest.o: sanpy ../../mercurial/cext/manifest.c
	$(CC) $(CFLAGS) `$$OUT/sanpy/bin/python-config --cflags` \
	  -I../../mercurial \
	  -c -o manifest.o ../../mercurial/cext/manifest.c

charencode.o: sanpy ../../mercurial/cext/charencode.c
	$(CC) $(CFLAGS) `$$OUT/sanpy/bin/python-config --cflags` \
	  -I../../mercurial \
	  -c -o charencode.o ../../mercurial/cext/charencode.c

parsers.o: sanpy ../../mercurial/cext/parsers.c
	$(CC) $(CFLAGS) `$$OUT/sanpy/bin/python-config --cflags` \
	  -I../../mercurial \
	  -c -o parsers.o ../../mercurial/cext/parsers.c

dirs.o: sanpy ../../mercurial/cext/dirs.c
	$(CC) $(CFLAGS) `$$OUT/sanpy/bin/python-config --cflags` \
	  -I../../mercurial \
	  -c -o dirs.o ../../mercurial/cext/dirs.c

pathencode.o: sanpy ../../mercurial/cext/pathencode.c
	$(CC) $(CFLAGS) `$$OUT/sanpy/bin/python-config --cflags` \
	  -I../../mercurial \
	  -c -o pathencode.o ../../mercurial/cext/pathencode.c

revlog.o: sanpy ../../mercurial/cext/revlog.c
	$(CC) $(CFLAGS) `$$OUT/sanpy/bin/python-config --cflags` \
	  -I../../mercurial \
	  -c -o revlog.o ../../mercurial/cext/revlog.c

manifest_fuzzer: sanpy manifest.cc manifest.o charencode.o parsers.o dirs.o pathencode.o revlog.o
	$(CXX) $(CXXFLAGS) `$$OUT/sanpy/bin/python-config --cflags` \
	  -Wno-register -Wno-macro-redefined \
	  -I../../mercurial manifest.cc \
	  manifest.o charencode.o parsers.o dirs.o pathencode.o revlog.o \
	  -lFuzzingEngine `$$OUT/sanpy/bin/python-config --ldflags` \
	  -o $$OUT/manifest_fuzzer

manifest_corpus.zip:
	python manifest_corpus.py $$OUT/manifest_fuzzer_seed_corpus.zip

clean:
	$(RM) *.o *_fuzzer \
	  bdiff \
	  mpatch \
	  xdiff

oss-fuzz: bdiff_fuzzer mpatch_fuzzer mpatch_corpus.zip xdiff_fuzzer manifest_fuzzer manifest_corpus.zip

.PHONY: all clean oss-fuzz sanpy
