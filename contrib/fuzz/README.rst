How to add fuzzers (partially cribbed from oss-fuzz[0]):

  1) git clone https://github.com/google/oss-fuzz
  2) cd oss-fuzz
  3) python infra/helper.py build_image mercurial
  4) docker run --cap-add=SYS_PTRACE -it -v $HG_REPO_PATH:/hg-new \
         gcr.io/oss-fuzz/mercurial bash
  5) cd /src
  6) rm -r mercurial
  7) ln -s /hg-new mercurial
  8) cd mercurial
  9) compile
  10) ls $OUT

Step 9 is literally running the command "compile", which is part of
the docker container. Once you have that working, you can build the
fuzzers like this (in the oss-fuzz repo):

python infra/helper.py build_fuzzers --sanitizer address mercurial $HG_REPO_PATH

(you can also say "memory", "undefined" or "coverage" for
sanitizer). Then run the built fuzzers like this:

python infra/helper.py run_fuzzer mercurial -- $FUZZER

0: https://github.com/google/oss-fuzz/blob/master/docs/new_project_guide.md
