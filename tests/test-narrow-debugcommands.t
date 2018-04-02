  $ . "$TESTDIR/narrow-library.sh"
  $ hg init repo
  $ cd repo
  $ cat << EOF > .hg/narrowspec
  > [includes]
  > path:foo
  > [excludes]
  > EOF
  $ echo treemanifest >> .hg/requires
  $ echo narrowhg-experimental >> .hg/requires
  $ mkdir -p foo/bar
  $ echo b > foo/f
  $ echo c > foo/bar/f
  $ hg commit -Am hi
  adding foo/bar/f
  adding foo/f
  $ hg debugindex -m
     rev linkrev nodeid       p1           p2
       0       0 14a5d056d75a 000000000000 000000000000
  $ hg debugindex --dir foo
     rev linkrev nodeid       p1           p2
       0       0 e635c7857aef 000000000000 000000000000
  $ hg debugindex --dir foo/
     rev linkrev nodeid       p1           p2
       0       0 e635c7857aef 000000000000 000000000000
  $ hg debugindex --dir foo/bar
     rev linkrev nodeid       p1           p2
       0       0 e091d4224761 000000000000 000000000000
  $ hg debugindex --dir foo/bar/
     rev linkrev nodeid       p1           p2
       0       0 e091d4224761 000000000000 000000000000
  $ hg debugdata -m 0
  foo\x00e635c7857aef92ac761ce5741a99da159abbbb24t (esc)
  $ hg debugdata --dir foo 0
  bar\x00e091d42247613adff5d41b67f15fe7189ee97b39t (esc)
  f\x001e88685f5ddec574a34c70af492f95b6debc8741 (esc)
  $ hg debugdata --dir foo/ 0
  bar\x00e091d42247613adff5d41b67f15fe7189ee97b39t (esc)
  f\x001e88685f5ddec574a34c70af492f95b6debc8741 (esc)
  $ hg debugdata --dir foo/bar 0
  f\x00149da44f2a4e14f488b7bd4157945a9837408c00 (esc)
  $ hg debugdata --dir foo/bar/ 0
  f\x00149da44f2a4e14f488b7bd4157945a9837408c00 (esc)
