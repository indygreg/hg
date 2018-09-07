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
  .hg/store/data/_s_p_a_r_s_e-_r_e_v_l_o_g-_t_e_s_t-_f_i_l_e.d: size=59302280
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
      snapshot  :      168 ( 3.36%)
        lvl-0   :              4 ( 0.08%)
        lvl-1   :             18 ( 0.36%)
        lvl-2   :             39 ( 0.78%)
        lvl-3   :             54 ( 1.08%)
        lvl-4   :             53 ( 1.06%)
      deltas    :     4833 (96.64%)
  revision size : 59302280
      snapshot  :  5833942 ( 9.84%)
        lvl-0   :         804068 ( 1.36%)
        lvl-1   :        1378470 ( 2.32%)
        lvl-2   :        1608138 ( 2.71%)
        lvl-3   :        1222158 ( 2.06%)
        lvl-4   :         821108 ( 1.38%)
      deltas    : 53468338 (90.16%)
  
  chunks        :     5001
      0x78 (x)  :     5001 (100.00%)
  chunks size   : 59302280
      0x78 (x)  : 59302280 (100.00%)
  
  avg chain length  :       17
  max chain length  :       45
  max chain reach   : 22744720
  compression ratio :       29
  
  uncompressed data size (min/max/avg) : 346468 / 346472 / 346471
  full revision size (min/max/avg)     : 200985 / 201050 / 201017
  inter-snapshot size (min/max/avg)    : 11598 / 163304 / 30669
      level-1   (min/max/avg)          : 15616 / 163304 / 76581
      level-2   (min/max/avg)          : 11602 / 86428 / 41234
      level-3   (min/max/avg)          : 11598 / 42390 / 22632
      level-4   (min/max/avg)          : 11603 / 19649 / 15492
  delta size (min/max/avg)             : 10649 / 105465 / 11063
  
  deltas against prev  : 4167 (86.22%)
      where prev = p1  : 4129     (99.09%)
      where prev = p2  :    0     ( 0.00%)
      other            :   38     ( 0.91%)
  deltas against p1    :  643 (13.30%)
  deltas against p2    :   23 ( 0.48%)
  deltas against other :    0 ( 0.00%)
