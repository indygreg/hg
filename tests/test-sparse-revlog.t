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
  .hg/store/data/_s_p_a_r_s_e-_r_e_v_l_o_g-_t_e_s_t-_f_i_l_e.d: size=63812493
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
      snapshot  :      179 ( 3.58%)
        lvl-0   :              4 ( 0.08%)
        lvl-1   :             49 ( 0.98%)
        lvl-2   :             56 ( 1.12%)
        lvl-3   :             63 ( 1.26%)
        lvl-4   :              7 ( 0.14%)
      deltas    :     4822 (96.42%)
  revision size : 63812493
      snapshot  : 10745878 (16.84%)
        lvl-0   :         804204 ( 1.26%)
        lvl-1   :        4986508 ( 7.81%)
        lvl-2   :        2858810 ( 4.48%)
        lvl-3   :        1958906 ( 3.07%)
        lvl-4   :         137450 ( 0.22%)
      deltas    : 53066615 (83.16%)
  
  chunks        :     5001
      0x78 (x)  :     5001 (100.00%)
  chunks size   : 63812493
      0x78 (x)  : 63812493 (100.00%)
  
  avg chain length  :       17
  max chain length  :       45
  max chain reach   : 27506743
  compression ratio :       27
  
  uncompressed data size (min/max/avg) : 346468 / 346472 / 346471
  full revision size (min/max/avg)     : 201007 / 201077 / 201051
  inter-snapshot size (min/max/avg)    : 13223 / 172097 / 56809
      level-1   (min/max/avg)          : 13223 / 172097 / 101765
      level-2   (min/max/avg)          : 28558 / 85237 / 51050
      level-3   (min/max/avg)          : 14647 / 41752 / 31093
      level-4   (min/max/avg)          : 18596 / 20760 / 19635
  delta size (min/max/avg)             : 10649 / 104791 / 11005
  
  deltas against prev  : 4171 (86.50%)
      where prev = p1  : 4127     (98.95%)
      where prev = p2  :    0     ( 0.00%)
      other            :   44     ( 1.05%)
  deltas against p1    :  633 (13.13%)
  deltas against p2    :   18 ( 0.37%)
  deltas against other :    0 ( 0.00%)
