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

0: https://github.com/google/oss-fuzz/blob/master/docs/new_project_guide.md
