====================================
Test delta choice with sparse revlog
====================================

Sparse-revlog usually shows the most gain on Manifest. However, it is simpler
to general an appropriate file, so we test with a single file instead. The
goal is to observe intermediate snapshot being created.

We need a large enough file. Part of the content needs to be replaced
repeatedly while some of it changes rarely.

  $ bundlepath="$TESTDIR/artifacts/cache/big-file-churn.hg"

  $ expectedhash=`cat "$bundlepath".md5`
  $ if [ ! -f "$bundlepath" ]; then
  >     echo 'skipped: missing artifact, run "'"$TESTDIR"'/artifacts/scripts/generate-churning-bundle.py"'
  >     exit 80
  > fi
  $ currenthash=`f -M "$bundlepath" | cut -d = -f 2`
  $ if [ "$currenthash" != "$expectedhash" ]; then
  >     echo 'skipped: outdated artifact, md5 "'"$currenthash"'" expected "'"$expectedhash"'" run "'"$TESTDIR"'/artifacts/scripts/generate-churning-bundle.py"'
  >     exit 80
  > fi

  $ cat >> $HGRCPATH << EOF
  > [format]
  > sparse-revlog = yes
  > [storage]
  > revlog.optimize-delta-parent-choice = yes
  > EOF
  $ hg init sparse-repo
  $ cd sparse-repo
  $ hg unbundle $bundlepath
  adding changesets
  adding manifests
  adding file changes
  added 5001 changesets with 5001 changes to 1 files (+89 heads)
  new changesets 9706f5af64f4:d9032adc8114 (5001 drafts)
  (run 'hg heads' to see heads, 'hg merge' to merge)
  $ hg up
  1 files updated, 0 files merged, 0 files removed, 0 files unresolved
  updated to "d9032adc8114: commit #5000"
  89 other heads for branch "default"

  $ hg log --stat -r 0:3
  changeset:   0:9706f5af64f4
  user:        test
  date:        Thu Jan 01 00:00:00 1970 +0000
  summary:     initial commit
  
   SPARSE-REVLOG-TEST-FILE |  10500 ++++++++++++++++++++++++++++++++++++++++++++++
   1 files changed, 10500 insertions(+), 0 deletions(-)
  
  changeset:   1:724907deaa5e
  user:        test
  date:        Thu Jan 01 00:00:00 1970 +0000
  summary:     commit #1
  
   SPARSE-REVLOG-TEST-FILE |  1068 +++++++++++++++++++++++-----------------------
   1 files changed, 534 insertions(+), 534 deletions(-)
  
  changeset:   2:62c41bce3e5d
  user:        test
  date:        Thu Jan 01 00:00:00 1970 +0000
  summary:     commit #2
  
   SPARSE-REVLOG-TEST-FILE |  1068 +++++++++++++++++++++++-----------------------
   1 files changed, 534 insertions(+), 534 deletions(-)
  
  changeset:   3:348a9cbd6959
  user:        test
  date:        Thu Jan 01 00:00:00 1970 +0000
  summary:     commit #3
  
   SPARSE-REVLOG-TEST-FILE |  1068 +++++++++++++++++++++++-----------------------
   1 files changed, 534 insertions(+), 534 deletions(-)
  

  $ f -s .hg/store/data/*.d
  .hg/store/data/_s_p_a_r_s_e-_r_e_v_l_o_g-_t_e_s_t-_f_i_l_e.d: size=59230936
  $ hg debugrevlog *
  format : 1
  flags  : generaldelta
  
  revisions     :     5001
      merges    :      625 (12.50%)
      normal    :     4376 (87.50%)
  revisions     :     5001
      empty     :        0 ( 0.00%)
                     text  :        0 (100.00%)
                     delta :        0 (100.00%)
      snapshot  :      176 ( 3.52%)
        lvl-0   :              3 ( 0.06%)
        lvl-1   :             17 ( 0.34%)
        lvl-2   :             45 ( 0.90%)
        lvl-3   :             56 ( 1.12%)
        lvl-4   :             55 ( 1.10%)
      deltas    :     4825 (96.48%)
  revision size : 59230936
      snapshot  :  5770371 ( 9.74%)
        lvl-0   :         602962 ( 1.02%)
        lvl-1   :        1534153 ( 2.59%)
        lvl-2   :        1604445 ( 2.71%)
        lvl-3   :        1218174 ( 2.06%)
        lvl-4   :         810637 ( 1.37%)
      deltas    : 53460565 (90.26%)
  
  chunks        :     5001
      0x78 (x)  :     5001 (100.00%)
  chunks size   : 59230936
      0x78 (x)  : 59230936 (100.00%)
  
  avg chain length  :       17
  max chain length  :       45
  max chain reach   : 25326012
  compression ratio :       29
  
  uncompressed data size (min/max/avg) : 346468 / 346472 / 346471
  full revision size (min/max/avg)     : 200897 / 201050 / 200987
  inter-snapshot size (min/max/avg)    : 11598 / 171990 / 29869
      level-1   (min/max/avg)          : 14037 / 171990 / 90244
      level-2   (min/max/avg)          : 11632 / 84456 / 35654
      level-3   (min/max/avg)          : 11598 / 41486 / 21753
      level-4   (min/max/avg)          : 11618 / 19913 / 14738
  delta size (min/max/avg)             : 10649 / 105209 / 11079
  
  deltas against prev  : 4156 (86.13%)
      where prev = p1  : 4120     (99.13%)
      where prev = p2  :    0     ( 0.00%)
      other            :   36     ( 0.87%)
  deltas against p1    :  646 (13.39%)
  deltas against p2    :   23 ( 0.48%)
  deltas against other :    0 ( 0.00%)
