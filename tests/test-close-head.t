  $ hg init test-content
  $ cd test-content
  $ hg debugbuilddag '+2*2*3*4'
  $ hg bookmark -r 1 @
  $ hg log -G --template '{rev}:{node|short}'
  o  4:e7bd5218ca15
  |
  | o  3:6100d3090acf
  |/
  | o  2:fa942426a6fd
  |/
  | o  1:66f7d451a68b
  |/
  o  0:1ea73414a91b
  
  $ hg --config extensions.closehead= close-head -m 'Not a head' 0 1
  abort: revision is not an open head: 0
  [255]
  $ hg --config extensions.closehead= close-head -m 'Not a head' -r 0 1
  abort: revision is not an open head: 0
  [255]
  $ hg --config extensions.closehead= close-head -m 'Close old heads' -r 1 2
  $ hg bookmark
     @                         1:66f7d451a68b
  $ hg heads
  changeset:   4:e7bd5218ca15
  parent:      0:1ea73414a91b
  user:        debugbuilddag
  date:        Thu Jan 01 00:00:04 1970 +0000
  summary:     r4
  
  changeset:   3:6100d3090acf
  parent:      0:1ea73414a91b
  user:        debugbuilddag
  date:        Thu Jan 01 00:00:03 1970 +0000
  summary:     r3
  
  $ hg --config extensions.closehead= close-head -m 'Close more old heads' 4
  $ hg heads
  changeset:   3:6100d3090acf
  parent:      0:1ea73414a91b
  user:        debugbuilddag
  date:        Thu Jan 01 00:00:03 1970 +0000
  summary:     r3
  
  $ hg --config extensions.closehead= close-head -m 'Not a head' 0
  abort: revision is not an open head: 0
  [255]
  $ hg --config extensions.closehead= close-head -m 'Already closed head' 1
  abort: revision is not an open head: 1
  [255]

  $ hg init ../test-empty
  $ cd ../test-empty
  $ hg debugbuilddag '+1'
  $ hg log -G --template '{rev}:{node|short}'
  o  0:1ea73414a91b
  
  $ hg --config extensions.closehead= close-head -m 'Close initial revision' 0
  $ hg heads
  [1]
