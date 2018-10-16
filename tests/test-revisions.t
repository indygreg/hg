  $ hg init repo
  $ cd repo

  $ echo 0 > a
  $ hg ci -qAm 0
  $ for i in 5 8 14 43 167; do
  >   hg up -q 0
  >   echo $i > a
  >   hg ci -qm $i
  > done
  $ cat <<EOF >> .hg/hgrc
  > [alias]
  > l = log -T '{rev}:{shortest(node,1)}\n'
  > EOF

  $ hg l
  5:00f
  4:7ba5d
  3:7ba57
  2:72
  1:9
  0:b
  $ cat <<EOF >> .hg/hgrc
  > [experimental]
  > revisions.disambiguatewithin=not 4
  > EOF
  $ hg l
  5:00
  4:7ba5d
  3:7b
  2:72
  1:9
  0:b
9 was unambiguous and still is
  $ hg l -r 9
  1:9
7 was ambiguous and still is
  $ hg l -r 7
  abort: 00changelog.i@7: ambiguous identifier!
  [255]
7b is no longer ambiguous
  $ hg l -r 7b
  3:7b

  $ cd ..
