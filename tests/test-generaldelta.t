#require no-reposimplestore

Check whether size of generaldelta revlog is not bigger than its
regular equivalent. Test would fail if generaldelta was naive
implementation of parentdelta: third manifest revision would be fully
inserted due to big distance from its paren revision (zero).

  $ hg init repo --config format.generaldelta=no --config format.usegeneraldelta=no
  $ cd repo
  $ echo foo > foo
  $ echo bar > bar
  $ echo baz > baz
  $ hg commit -q -Am boo
  $ hg clone --pull . ../gdrepo -q --config format.generaldelta=yes
  $ for r in 1 2 3; do
  >   echo $r > foo
  >   hg commit -q -m $r
  >   hg up -q -r 0
  >   hg pull . -q -r $r -R ../gdrepo
  > done

  $ cd ..
  >>> from __future__ import print_function
  >>> import os
  >>> regsize = os.stat("repo/.hg/store/00manifest.i").st_size
  >>> gdsize = os.stat("gdrepo/.hg/store/00manifest.i").st_size
  >>> if regsize < gdsize:
  ...     print('generaldata increased size of manifest')

Verify rev reordering doesnt create invalid bundles (issue4462)
This requires a commit tree that when pulled will reorder manifest revs such
that the second manifest to create a file rev will be ordered before the first
manifest to create that file rev. We also need to do a partial pull to ensure
reordering happens. At the end we verify the linkrev points at the earliest
commit.

  $ hg init server --config format.generaldelta=True
  $ cd server
  $ touch a
  $ hg commit -Aqm a
  $ echo x > x
  $ echo y > y
  $ hg commit -Aqm xy
  $ hg up -q '.^'
  $ echo x > x
  $ echo z > z
  $ hg commit -Aqm xz
  $ hg up -q 1
  $ echo b > b
  $ hg commit -Aqm b
  $ hg merge -q 2
  $ hg commit -Aqm merge
  $ echo c > c
  $ hg commit -Aqm c
  $ hg log -G -T '{rev} {shortest(node)} {desc}'
  @  5 ebb8 c
  |
  o    4 baf7 merge
  |\
  | o  3 a129 b
  | |
  o |  2 958c xz
  | |
  | o  1 f00c xy
  |/
  o  0 3903 a
  
  $ cd ..
  $ hg init client --config format.generaldelta=false --config format.usegeneraldelta=false
  $ cd client
  $ hg pull -q ../server -r 4
  $ hg debugdeltachain x
      rev  chain# chainlen     prev   delta       size    rawsize  chainsize     ratio   lindist extradist extraratio
        0       1        1       -1    base          3          2          3   1.50000         3         0    0.00000

  $ cd ..

Test "usegeneraldelta" config
(repo are general delta, but incoming bundle are not re-deltafied)

delta coming from the server base delta server are not recompressed.
(also include the aggressive version for comparison)

  $ hg clone repo --pull --config format.usegeneraldelta=1 usegd
  requesting all changes
  adding changesets
  adding manifests
  adding file changes
  added 4 changesets with 6 changes to 3 files (+2 heads)
  new changesets 0ea3fcf9d01d:bba78d330d9c
  updating to branch default
  3 files updated, 0 files merged, 0 files removed, 0 files unresolved
  $ hg clone repo --pull --config format.generaldelta=1 full
  requesting all changes
  adding changesets
  adding manifests
  adding file changes
  added 4 changesets with 6 changes to 3 files (+2 heads)
  new changesets 0ea3fcf9d01d:bba78d330d9c
  updating to branch default
  3 files updated, 0 files merged, 0 files removed, 0 files unresolved
  $ hg -R repo debugdeltachain -m
      rev  chain# chainlen     prev   delta       size    rawsize  chainsize     ratio   lindist extradist extraratio
        0       1        1       -1    base        104        135        104   0.77037       104         0    0.00000
        1       1        2        0    prev         57        135        161   1.19259       161         0    0.00000
        2       1        3        1    prev         57        135        218   1.61481       218         0    0.00000
        3       2        1       -1    base        104        135        104   0.77037       104         0    0.00000
  $ hg -R usegd debugdeltachain -m
      rev  chain# chainlen     prev   delta       size    rawsize  chainsize     ratio   lindist extradist extraratio
        0       1        1       -1    base        104        135        104   0.77037       104         0    0.00000
        1       1        2        0      p1         57        135        161   1.19259       161         0    0.00000
        2       1        3        1    prev         57        135        218   1.61481       218         0    0.00000
        3       1        2        0      p1         57        135        161   1.19259       275       114    0.70807
  $ hg -R full debugdeltachain -m
      rev  chain# chainlen     prev   delta       size    rawsize  chainsize     ratio   lindist extradist extraratio
        0       1        1       -1    base        104        135        104   0.77037       104         0    0.00000
        1       1        2        0      p1         57        135        161   1.19259       161         0    0.00000
        2       1        2        0      p1         57        135        161   1.19259       218        57    0.35404
        3       1        2        0      p1         57        135        161   1.19259       275       114    0.70807

Test format.aggressivemergedeltas

  $ hg init --config format.generaldelta=1 aggressive
  $ cd aggressive
  $ cat << EOF >> .hg/hgrc
  > [format]
  > generaldelta = 1
  > EOF
  $ touch a b c d e
  $ hg commit -Aqm side1
  $ hg up -q null
  $ touch x y
  $ hg commit -Aqm side2

- Verify non-aggressive merge uses p1 (commit 1) as delta parent
  $ hg merge -q 0
  $ hg commit -q -m merge
  $ hg debugdeltachain -m
      rev  chain# chainlen     prev   delta       size    rawsize  chainsize     ratio   lindist extradist extraratio
        0       1        1       -1    base         59        215         59   0.27442        59         0    0.00000
        1       1        2        0    prev         61         86        120   1.39535       120         0    0.00000
        2       1        2        0      p2         62        301        121   0.40199       182        61    0.50413

  $ hg strip -q -r . --config extensions.strip=

- Verify aggressive merge uses p2 (commit 0) as delta parent
  $ hg up -q -C 1
  $ hg merge -q 0
  $ hg commit -q -m merge --config format.aggressivemergedeltas=True
  $ hg debugdeltachain -m
      rev  chain# chainlen     prev   delta       size    rawsize  chainsize     ratio   lindist extradist extraratio
        0       1        1       -1    base         59        215         59   0.27442        59         0    0.00000
        1       1        2        0    prev         61         86        120   1.39535       120         0    0.00000
        2       1        2        0      p2         62        301        121   0.40199       182        61    0.50413

Test that strip bundle use bundle2
  $ hg --config extensions.strip= strip .
  0 files updated, 0 files merged, 5 files removed, 0 files unresolved
  saved backup bundle to $TESTTMP/aggressive/.hg/strip-backup/1c5d4dc9a8b8-6c68e60c-backup.hg
  $ hg debugbundle .hg/strip-backup/*
  Stream params: {Compression: BZ}
  changegroup -- {nbchanges: 1, version: 02} (mandatory: True)
      1c5d4dc9a8b8d6e1750966d343e94db665e7a1e9
  cache:rev-branch-cache -- {} (mandatory: False)
  phase-heads -- {} (mandatory: True)
      1c5d4dc9a8b8d6e1750966d343e94db665e7a1e9 draft

  $ cd ..

test maxdeltachainspan

  $ hg init source-repo
  $ cd source-repo
  $ hg debugbuilddag --new-file '.+5:brancha$.+11:branchb$.+30:branchc<brancha+2<branchb+2'
# add an empty revision somewhere
  $ hg up tip
  14 files updated, 0 files merged, 0 files removed, 0 files unresolved
  $ hg rm .
  removing nf10
  removing nf11
  removing nf12
  removing nf13
  removing nf14
  removing nf15
  removing nf16
  removing nf17
  removing nf51
  removing nf52
  removing nf6
  removing nf7
  removing nf8
  removing nf9
  $ hg commit -m 'empty all'
  $ hg revert --all --rev 'p1(.)'
  adding nf10
  adding nf11
  adding nf12
  adding nf13
  adding nf14
  adding nf15
  adding nf16
  adding nf17
  adding nf51
  adding nf52
  adding nf6
  adding nf7
  adding nf8
  adding nf9
  $ hg commit -m 'restore all'
  $ hg up null
  0 files updated, 0 files merged, 14 files removed, 0 files unresolved
  $ 
  $ cd ..
  $ hg -R source-repo debugdeltachain -m
      rev  chain# chainlen     prev   delta       size    rawsize  chainsize     ratio   lindist extradist extraratio
        0       1        1       -1    base         46         45         46   1.02222        46         0    0.00000
        1       1        2        0      p1         57         90        103   1.14444       103         0    0.00000
        2       1        3        1      p1         57        135        160   1.18519       160         0    0.00000
        3       1        4        2      p1         57        180        217   1.20556       217         0    0.00000
        4       1        5        3      p1         57        225        274   1.21778       274         0    0.00000
        5       1        6        4      p1         57        270        331   1.22593       331         0    0.00000
        6       2        1       -1    base         46         45         46   1.02222        46         0    0.00000
        7       2        2        6      p1         57         90        103   1.14444       103         0    0.00000
        8       2        3        7      p1         57        135        160   1.18519       160         0    0.00000
        9       2        4        8      p1         57        180        217   1.20556       217         0    0.00000
       10       2        5        9      p1         58        226        275   1.21681       275         0    0.00000
       11       2        6       10      p1         58        272        333   1.22426       333         0    0.00000
       12       2        7       11      p1         58        318        391   1.22956       391         0    0.00000
       13       2        8       12      p1         58        364        449   1.23352       449         0    0.00000
       14       2        9       13      p1         58        410        507   1.23659       507         0    0.00000
       15       2       10       14      p1         58        456        565   1.23904       565         0    0.00000
       16       2       11       15      p1         58        502        623   1.24104       623         0    0.00000
       17       2       12       16      p1         58        548        681   1.24270       681         0    0.00000
       18       3        1       -1    base         47         46         47   1.02174        47         0    0.00000
       19       3        2       18      p1         58         92        105   1.14130       105         0    0.00000
       20       3        3       19      p1         58        138        163   1.18116       163         0    0.00000
       21       3        4       20      p1         58        184        221   1.20109       221         0    0.00000
       22       3        5       21      p1         58        230        279   1.21304       279         0    0.00000
       23       3        6       22      p1         58        276        337   1.22101       337         0    0.00000
       24       3        7       23      p1         58        322        395   1.22671       395         0    0.00000
       25       3        8       24      p1         58        368        453   1.23098       453         0    0.00000
       26       3        9       25      p1         58        414        511   1.23430       511         0    0.00000
       27       3       10       26      p1         58        460        569   1.23696       569         0    0.00000
       28       3       11       27      p1         58        506        627   1.23913       627         0    0.00000
       29       3       12       28      p1         58        552        685   1.24094       685         0    0.00000
       30       3       13       29      p1         58        598        743   1.24247       743         0    0.00000
       31       3       14       30      p1         58        644        801   1.24379       801         0    0.00000
       32       3       15       31      p1         58        690        859   1.24493       859         0    0.00000
       33       3       16       32      p1         58        736        917   1.24592       917         0    0.00000
       34       3       17       33      p1         58        782        975   1.24680       975         0    0.00000
       35       3       18       34      p1         58        828       1033   1.24758      1033         0    0.00000
       36       3       19       35      p1         58        874       1091   1.24828      1091         0    0.00000
       37       3       20       36      p1         58        920       1149   1.24891      1149         0    0.00000
       38       3       21       37      p1         58        966       1207   1.24948      1207         0    0.00000
       39       3       22       38      p1         58       1012       1265   1.25000      1265         0    0.00000
       40       3       23       39      p1         58       1058       1323   1.25047      1323         0    0.00000
       41       3       24       40      p1         58       1104       1381   1.25091      1381         0    0.00000
       42       3       25       41      p1         58       1150       1439   1.25130      1439         0    0.00000
       43       3       26       42      p1         58       1196       1497   1.25167      1497         0    0.00000
       44       3       27       43      p1         58       1242       1555   1.25201      1555         0    0.00000
       45       3       28       44      p1         58       1288       1613   1.25233      1613         0    0.00000
       46       3       29       45      p1         58       1334       1671   1.25262      1671         0    0.00000
       47       3       30       46      p1         58       1380       1729   1.25290      1729         0    0.00000
       48       3       31       47      p1         58       1426       1787   1.25316      1787         0    0.00000
       49       4        1       -1    base        197        316        197   0.62342       197         0    0.00000
       50       4        2       49      p1         58        362        255   0.70442       255         0    0.00000
       51       4        3       50    prev        356        594        611   1.02862       611         0    0.00000
       52       4        4       51      p1         58        640        669   1.04531       669         0    0.00000
       53       5        1       -1    base          0          0          0   0.00000         0         0    0.00000
       54       5        2       53      p1        376        640        376   0.58750       376         0    0.00000
  $ hg clone --pull source-repo --config experimental.maxdeltachainspan=2800 relax-chain --config format.generaldelta=yes
  requesting all changes
  adding changesets
  adding manifests
  adding file changes
  added 55 changesets with 53 changes to 53 files (+2 heads)
  new changesets 61246295ee1e:c930ac4a5b32
  updating to branch default
  14 files updated, 0 files merged, 0 files removed, 0 files unresolved
  $ hg -R relax-chain debugdeltachain -m
      rev  chain# chainlen     prev   delta       size    rawsize  chainsize     ratio   lindist extradist extraratio
        0       1        1       -1    base         46         45         46   1.02222        46         0    0.00000
        1       1        2        0      p1         57         90        103   1.14444       103         0    0.00000
        2       1        3        1      p1         57        135        160   1.18519       160         0    0.00000
        3       1        4        2      p1         57        180        217   1.20556       217         0    0.00000
        4       1        5        3      p1         57        225        274   1.21778       274         0    0.00000
        5       1        6        4      p1         57        270        331   1.22593       331         0    0.00000
        6       2        1       -1    base         46         45         46   1.02222        46         0    0.00000
        7       2        2        6      p1         57         90        103   1.14444       103         0    0.00000
        8       2        3        7      p1         57        135        160   1.18519       160         0    0.00000
        9       2        4        8      p1         57        180        217   1.20556       217         0    0.00000
       10       2        5        9      p1         58        226        275   1.21681       275         0    0.00000
       11       2        6       10      p1         58        272        333   1.22426       333         0    0.00000
       12       2        7       11      p1         58        318        391   1.22956       391         0    0.00000
       13       2        8       12      p1         58        364        449   1.23352       449         0    0.00000
       14       2        9       13      p1         58        410        507   1.23659       507         0    0.00000
       15       2       10       14      p1         58        456        565   1.23904       565         0    0.00000
       16       2       11       15      p1         58        502        623   1.24104       623         0    0.00000
       17       2       12       16      p1         58        548        681   1.24270       681         0    0.00000
       18       3        1       -1    base         47         46         47   1.02174        47         0    0.00000
       19       3        2       18      p1         58         92        105   1.14130       105         0    0.00000
       20       3        3       19      p1         58        138        163   1.18116       163         0    0.00000
       21       3        4       20      p1         58        184        221   1.20109       221         0    0.00000
       22       3        5       21      p1         58        230        279   1.21304       279         0    0.00000
       23       3        6       22      p1         58        276        337   1.22101       337         0    0.00000
       24       3        7       23      p1         58        322        395   1.22671       395         0    0.00000
       25       3        8       24      p1         58        368        453   1.23098       453         0    0.00000
       26       3        9       25      p1         58        414        511   1.23430       511         0    0.00000
       27       3       10       26      p1         58        460        569   1.23696       569         0    0.00000
       28       3       11       27      p1         58        506        627   1.23913       627         0    0.00000
       29       3       12       28      p1         58        552        685   1.24094       685         0    0.00000
       30       3       13       29      p1         58        598        743   1.24247       743         0    0.00000
       31       3       14       30      p1         58        644        801   1.24379       801         0    0.00000
       32       3       15       31      p1         58        690        859   1.24493       859         0    0.00000
       33       3       16       32      p1         58        736        917   1.24592       917         0    0.00000
       34       3       17       33      p1         58        782        975   1.24680       975         0    0.00000
       35       3       18       34      p1         58        828       1033   1.24758      1033         0    0.00000
       36       3       19       35      p1         58        874       1091   1.24828      1091         0    0.00000
       37       3       20       36      p1         58        920       1149   1.24891      1149         0    0.00000
       38       3       21       37      p1         58        966       1207   1.24948      1207         0    0.00000
       39       3       22       38      p1         58       1012       1265   1.25000      1265         0    0.00000
       40       3       23       39      p1         58       1058       1323   1.25047      1323         0    0.00000
       41       3       24       40      p1         58       1104       1381   1.25091      1381         0    0.00000
       42       3       25       41      p1         58       1150       1439   1.25130      1439         0    0.00000
       43       3       26       42      p1         58       1196       1497   1.25167      1497         0    0.00000
       44       3       27       43      p1         58       1242       1555   1.25201      1555         0    0.00000
       45       3       28       44      p1         58       1288       1613   1.25233      1613         0    0.00000
       46       3       29       45      p1         58       1334       1671   1.25262      1671         0    0.00000
       47       3       30       46      p1         58       1380       1729   1.25290      1729         0    0.00000
       48       3       31       47      p1         58       1426       1787   1.25316      1787         0    0.00000
       49       4        1       -1    base        197        316        197   0.62342       197         0    0.00000
       50       4        2       49      p1         58        362        255   0.70442       255         0    0.00000
       51       2       13       17      p1         58        594        739   1.24411      2781      2042    2.76319
       52       5        1       -1    base        369        640        369   0.57656       369         0    0.00000
       53       6        1       -1    base          0          0          0   0.00000         0         0    0.00000
       54       6        2       53      p1        376        640        376   0.58750       376         0    0.00000
  $ hg clone --pull source-repo --config experimental.maxdeltachainspan=0 noconst-chain --config format.generaldelta=yes
  requesting all changes
  adding changesets
  adding manifests
  adding file changes
  added 55 changesets with 53 changes to 53 files (+2 heads)
  new changesets 61246295ee1e:c930ac4a5b32
  updating to branch default
  14 files updated, 0 files merged, 0 files removed, 0 files unresolved
  $ hg -R noconst-chain debugdeltachain -m
      rev  chain# chainlen     prev   delta       size    rawsize  chainsize     ratio   lindist extradist extraratio
        0       1        1       -1    base         46         45         46   1.02222        46         0    0.00000
        1       1        2        0      p1         57         90        103   1.14444       103         0    0.00000
        2       1        3        1      p1         57        135        160   1.18519       160         0    0.00000
        3       1        4        2      p1         57        180        217   1.20556       217         0    0.00000
        4       1        5        3      p1         57        225        274   1.21778       274         0    0.00000
        5       1        6        4      p1         57        270        331   1.22593       331         0    0.00000
        6       2        1       -1    base         46         45         46   1.02222        46         0    0.00000
        7       2        2        6      p1         57         90        103   1.14444       103         0    0.00000
        8       2        3        7      p1         57        135        160   1.18519       160         0    0.00000
        9       2        4        8      p1         57        180        217   1.20556       217         0    0.00000
       10       2        5        9      p1         58        226        275   1.21681       275         0    0.00000
       11       2        6       10      p1         58        272        333   1.22426       333         0    0.00000
       12       2        7       11      p1         58        318        391   1.22956       391         0    0.00000
       13       2        8       12      p1         58        364        449   1.23352       449         0    0.00000
       14       2        9       13      p1         58        410        507   1.23659       507         0    0.00000
       15       2       10       14      p1         58        456        565   1.23904       565         0    0.00000
       16       2       11       15      p1         58        502        623   1.24104       623         0    0.00000
       17       2       12       16      p1         58        548        681   1.24270       681         0    0.00000
       18       3        1       -1    base         47         46         47   1.02174        47         0    0.00000
       19       3        2       18      p1         58         92        105   1.14130       105         0    0.00000
       20       3        3       19      p1         58        138        163   1.18116       163         0    0.00000
       21       3        4       20      p1         58        184        221   1.20109       221         0    0.00000
       22       3        5       21      p1         58        230        279   1.21304       279         0    0.00000
       23       3        6       22      p1         58        276        337   1.22101       337         0    0.00000
       24       3        7       23      p1         58        322        395   1.22671       395         0    0.00000
       25       3        8       24      p1         58        368        453   1.23098       453         0    0.00000
       26       3        9       25      p1         58        414        511   1.23430       511         0    0.00000
       27       3       10       26      p1         58        460        569   1.23696       569         0    0.00000
       28       3       11       27      p1         58        506        627   1.23913       627         0    0.00000
       29       3       12       28      p1         58        552        685   1.24094       685         0    0.00000
       30       3       13       29      p1         58        598        743   1.24247       743         0    0.00000
       31       3       14       30      p1         58        644        801   1.24379       801         0    0.00000
       32       3       15       31      p1         58        690        859   1.24493       859         0    0.00000
       33       3       16       32      p1         58        736        917   1.24592       917         0    0.00000
       34       3       17       33      p1         58        782        975   1.24680       975         0    0.00000
       35       3       18       34      p1         58        828       1033   1.24758      1033         0    0.00000
       36       3       19       35      p1         58        874       1091   1.24828      1091         0    0.00000
       37       3       20       36      p1         58        920       1149   1.24891      1149         0    0.00000
       38       3       21       37      p1         58        966       1207   1.24948      1207         0    0.00000
       39       3       22       38      p1         58       1012       1265   1.25000      1265         0    0.00000
       40       3       23       39      p1         58       1058       1323   1.25047      1323         0    0.00000
       41       3       24       40      p1         58       1104       1381   1.25091      1381         0    0.00000
       42       3       25       41      p1         58       1150       1439   1.25130      1439         0    0.00000
       43       3       26       42      p1         58       1196       1497   1.25167      1497         0    0.00000
       44       3       27       43      p1         58       1242       1555   1.25201      1555         0    0.00000
       45       3       28       44      p1         58       1288       1613   1.25233      1613         0    0.00000
       46       3       29       45      p1         58       1334       1671   1.25262      1671         0    0.00000
       47       3       30       46      p1         58       1380       1729   1.25290      1729         0    0.00000
       48       3       31       47      p1         58       1426       1787   1.25316      1787         0    0.00000
       49       1        7        5      p1         58        316        389   1.23101      2857      2468    6.34447
       50       1        8       49      p1         58        362        447   1.23481      2915      2468    5.52125
       51       2       13       17      p1         58        594        739   1.24411      2642      1903    2.57510
       52       2       14       51      p1         58        640        797   1.24531      2700      1903    2.38770
       53       4        1       -1    base          0          0          0   0.00000         0         0    0.00000
       54       4        2       53      p1        376        640        376   0.58750       376         0    0.00000
