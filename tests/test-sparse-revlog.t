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
  .hg/store/data/_s_p_a_r_s_e-_r_e_v_l_o_g-_t_e_s_t-_f_i_l_e.d: size=59303048
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
      snapshot  :      165 ( 3.30%)
        lvl-0   :              4 ( 0.08%)
        lvl-1   :             17 ( 0.34%)
        lvl-2   :             46 ( 0.92%)
        lvl-3   :             62 ( 1.24%)
        lvl-4   :             36 ( 0.72%)
      deltas    :     4836 (96.70%)
  revision size : 59303048
      snapshot  :  6105443 (10.30%)
        lvl-0   :         804187 ( 1.36%)
        lvl-1   :        1476228 ( 2.49%)
        lvl-2   :        1752567 ( 2.96%)
        lvl-3   :        1461776 ( 2.46%)
        lvl-4   :         610685 ( 1.03%)
      deltas    : 53197605 (89.70%)
  
  chunks        :     5001
      0x78 (x)  :     5001 (100.00%)
  chunks size   : 59303048
      0x78 (x)  : 59303048 (100.00%)
  
  avg chain length  :       17
  max chain length  :       45
  max chain reach   : 26194433
  compression ratio :       29
  
  uncompressed data size (min/max/avg) : 346468 / 346472 / 346471
  full revision size (min/max/avg)     : 200992 / 201080 / 201046
  inter-snapshot size (min/max/avg)    : 11610 / 172762 / 32927
      level-1   (min/max/avg)          : 15619 / 172762 / 86836
      level-2   (min/max/avg)          : 13055 / 85219 / 38099
      level-3   (min/max/avg)          : 11610 / 42645 / 23577
      level-4   (min/max/avg)          : 12928 / 20205 / 16963
  delta size (min/max/avg)             : 10649 / 106863 / 11000
  
  deltas against prev  : 4162 (86.06%)
      where prev = p1  : 4120     (98.99%)
      where prev = p2  :    0     ( 0.00%)
      other            :   42     ( 1.01%)
  deltas against p1    :  653 (13.50%)
  deltas against p2    :   21 ( 0.43%)
  deltas against other :    0 ( 0.00%)
