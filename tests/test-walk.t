  $ hg init t
  $ cd t
  $ mkdir -p beans
  $ for b in kidney navy turtle borlotti black pinto; do
  >     echo $b > beans/$b
  > done
  $ mkdir -p mammals/Procyonidae
  $ for m in cacomistle coatimundi raccoon; do
  >     echo $m > mammals/Procyonidae/$m
  > done
  $ echo skunk > mammals/skunk
  $ echo fennel > fennel
  $ echo fenugreek > fenugreek
  $ echo fiddlehead > fiddlehead
  $ hg addremove
  adding beans/black
  adding beans/borlotti
  adding beans/kidney
  adding beans/navy
  adding beans/pinto
  adding beans/turtle
  adding fennel
  adding fenugreek
  adding fiddlehead
  adding mammals/Procyonidae/cacomistle
  adding mammals/Procyonidae/coatimundi
  adding mammals/Procyonidae/raccoon
  adding mammals/skunk
  $ hg commit -m "commit #0"

  $ hg debugwalk -v
  * matcher:
  <alwaysmatcher>
  f  beans/black                     beans/black
  f  beans/borlotti                  beans/borlotti
  f  beans/kidney                    beans/kidney
  f  beans/navy                      beans/navy
  f  beans/pinto                     beans/pinto
  f  beans/turtle                    beans/turtle
  f  fennel                          fennel
  f  fenugreek                       fenugreek
  f  fiddlehead                      fiddlehead
  f  mammals/Procyonidae/cacomistle  mammals/Procyonidae/cacomistle
  f  mammals/Procyonidae/coatimundi  mammals/Procyonidae/coatimundi
  f  mammals/Procyonidae/raccoon     mammals/Procyonidae/raccoon
  f  mammals/skunk                   mammals/skunk
  $ hg debugwalk -v -I.
  * matcher:
  <includematcher includes='(?:)'>
  f  beans/black                     beans/black
  f  beans/borlotti                  beans/borlotti
  f  beans/kidney                    beans/kidney
  f  beans/navy                      beans/navy
  f  beans/pinto                     beans/pinto
  f  beans/turtle                    beans/turtle
  f  fennel                          fennel
  f  fenugreek                       fenugreek
  f  fiddlehead                      fiddlehead
  f  mammals/Procyonidae/cacomistle  mammals/Procyonidae/cacomistle
  f  mammals/Procyonidae/coatimundi  mammals/Procyonidae/coatimundi
  f  mammals/Procyonidae/raccoon     mammals/Procyonidae/raccoon
  f  mammals/skunk                   mammals/skunk

  $ cd mammals
  $ hg debugwalk -v
  * matcher:
  <alwaysmatcher>
  f  beans/black                     ../beans/black
  f  beans/borlotti                  ../beans/borlotti
  f  beans/kidney                    ../beans/kidney
  f  beans/navy                      ../beans/navy
  f  beans/pinto                     ../beans/pinto
  f  beans/turtle                    ../beans/turtle
  f  fennel                          ../fennel
  f  fenugreek                       ../fenugreek
  f  fiddlehead                      ../fiddlehead
  f  mammals/Procyonidae/cacomistle  Procyonidae/cacomistle
  f  mammals/Procyonidae/coatimundi  Procyonidae/coatimundi
  f  mammals/Procyonidae/raccoon     Procyonidae/raccoon
  f  mammals/skunk                   skunk
  $ hg debugwalk -v -X ../beans
  * matcher:
  <differencematcher
    m1=<alwaysmatcher>,
    m2=<includematcher includes='(?:beans(?:/|$))'>>
  f  fennel                          ../fennel
  f  fenugreek                       ../fenugreek
  f  fiddlehead                      ../fiddlehead
  f  mammals/Procyonidae/cacomistle  Procyonidae/cacomistle
  f  mammals/Procyonidae/coatimundi  Procyonidae/coatimundi
  f  mammals/Procyonidae/raccoon     Procyonidae/raccoon
  f  mammals/skunk                   skunk
  $ hg debugwalk -v -I '*k'
  * matcher:
  <includematcher includes='(?:mammals/[^/]*k(?:/|$))'>
  f  mammals/skunk  skunk
  $ hg debugwalk -v -I 'glob:*k'
  * matcher:
  <includematcher includes='(?:mammals/[^/]*k(?:/|$))'>
  f  mammals/skunk  skunk
  $ hg debugwalk -v -I 'relglob:*k'
  * matcher:
  <includematcher includes='(?:(?:|.*/)[^/]*k(?:/|$))'>
  f  beans/black    ../beans/black
  f  fenugreek      ../fenugreek
  f  mammals/skunk  skunk
  $ hg debugwalk -v -I 'relglob:*k' .
  * matcher:
  <intersectionmatcher
    m1=<patternmatcher patterns='(?:mammals(?:/|$))'>,
    m2=<includematcher includes='(?:(?:|.*/)[^/]*k(?:/|$))'>>
  f  mammals/skunk  skunk
  $ hg debugwalk -v -I 're:.*k$'
  * matcher:
  <includematcher includes='(?:.*k$)'>
  f  beans/black    ../beans/black
  f  fenugreek      ../fenugreek
  f  mammals/skunk  skunk
  $ hg debugwalk -v -I 'relre:.*k$'
  * matcher:
  <includematcher includes='(?:.*.*k$)'>
  f  beans/black    ../beans/black
  f  fenugreek      ../fenugreek
  f  mammals/skunk  skunk
  $ hg debugwalk -v -I 'path:beans'
  * matcher:
  <includematcher includes='(?:beans(?:/|$))'>
  f  beans/black     ../beans/black
  f  beans/borlotti  ../beans/borlotti
  f  beans/kidney    ../beans/kidney
  f  beans/navy      ../beans/navy
  f  beans/pinto     ../beans/pinto
  f  beans/turtle    ../beans/turtle
  $ hg debugwalk -v -I 'relpath:detour/../../beans'
  * matcher:
  <includematcher includes='(?:beans(?:/|$))'>
  f  beans/black     ../beans/black
  f  beans/borlotti  ../beans/borlotti
  f  beans/kidney    ../beans/kidney
  f  beans/navy      ../beans/navy
  f  beans/pinto     ../beans/pinto
  f  beans/turtle    ../beans/turtle

  $ hg debugwalk -v 'rootfilesin:'
  * matcher:
  <patternmatcher patterns='(?:[^/]+$)'>
  f  fennel      ../fennel
  f  fenugreek   ../fenugreek
  f  fiddlehead  ../fiddlehead
  $ hg debugwalk -v -I 'rootfilesin:'
  * matcher:
  <includematcher includes='(?:[^/]+$)'>
  f  fennel      ../fennel
  f  fenugreek   ../fenugreek
  f  fiddlehead  ../fiddlehead
  $ hg debugwalk -v 'rootfilesin:.'
  * matcher:
  <patternmatcher patterns='(?:[^/]+$)'>
  f  fennel      ../fennel
  f  fenugreek   ../fenugreek
  f  fiddlehead  ../fiddlehead
  $ hg debugwalk -v -I 'rootfilesin:.'
  * matcher:
  <includematcher includes='(?:[^/]+$)'>
  f  fennel      ../fennel
  f  fenugreek   ../fenugreek
  f  fiddlehead  ../fiddlehead
  $ hg debugwalk -v -X 'rootfilesin:'
  * matcher:
  <differencematcher
    m1=<alwaysmatcher>,
    m2=<includematcher includes='(?:[^/]+$)'>>
  f  beans/black                     ../beans/black
  f  beans/borlotti                  ../beans/borlotti
  f  beans/kidney                    ../beans/kidney
  f  beans/navy                      ../beans/navy
  f  beans/pinto                     ../beans/pinto
  f  beans/turtle                    ../beans/turtle
  f  mammals/Procyonidae/cacomistle  Procyonidae/cacomistle
  f  mammals/Procyonidae/coatimundi  Procyonidae/coatimundi
  f  mammals/Procyonidae/raccoon     Procyonidae/raccoon
  f  mammals/skunk                   skunk
  $ hg debugwalk -v 'rootfilesin:fennel'
  * matcher:
  <patternmatcher patterns='(?:fennel/[^/]+$)'>
  $ hg debugwalk -v -I 'rootfilesin:fennel'
  * matcher:
  <includematcher includes='(?:fennel/[^/]+$)'>
  $ hg debugwalk -v 'rootfilesin:skunk'
  * matcher:
  <patternmatcher patterns='(?:skunk/[^/]+$)'>
  $ hg debugwalk -v -I 'rootfilesin:skunk'
  * matcher:
  <includematcher includes='(?:skunk/[^/]+$)'>
  $ hg debugwalk -v 'rootfilesin:beans'
  * matcher:
  <patternmatcher patterns='(?:beans/[^/]+$)'>
  f  beans/black     ../beans/black
  f  beans/borlotti  ../beans/borlotti
  f  beans/kidney    ../beans/kidney
  f  beans/navy      ../beans/navy
  f  beans/pinto     ../beans/pinto
  f  beans/turtle    ../beans/turtle
  $ hg debugwalk -v -I 'rootfilesin:beans'
  * matcher:
  <includematcher includes='(?:beans/[^/]+$)'>
  f  beans/black     ../beans/black
  f  beans/borlotti  ../beans/borlotti
  f  beans/kidney    ../beans/kidney
  f  beans/navy      ../beans/navy
  f  beans/pinto     ../beans/pinto
  f  beans/turtle    ../beans/turtle
  $ hg debugwalk -v 'rootfilesin:mammals'
  * matcher:
  <patternmatcher patterns='(?:mammals/[^/]+$)'>
  f  mammals/skunk  skunk
  $ hg debugwalk -v -I 'rootfilesin:mammals'
  * matcher:
  <includematcher includes='(?:mammals/[^/]+$)'>
  f  mammals/skunk  skunk
  $ hg debugwalk -v 'rootfilesin:mammals/'
  * matcher:
  <patternmatcher patterns='(?:mammals/[^/]+$)'>
  f  mammals/skunk  skunk
  $ hg debugwalk -v -I 'rootfilesin:mammals/'
  * matcher:
  <includematcher includes='(?:mammals/[^/]+$)'>
  f  mammals/skunk  skunk
  $ hg debugwalk -v -X 'rootfilesin:mammals'
  * matcher:
  <differencematcher
    m1=<alwaysmatcher>,
    m2=<includematcher includes='(?:mammals/[^/]+$)'>>
  f  beans/black                     ../beans/black
  f  beans/borlotti                  ../beans/borlotti
  f  beans/kidney                    ../beans/kidney
  f  beans/navy                      ../beans/navy
  f  beans/pinto                     ../beans/pinto
  f  beans/turtle                    ../beans/turtle
  f  fennel                          ../fennel
  f  fenugreek                       ../fenugreek
  f  fiddlehead                      ../fiddlehead
  f  mammals/Procyonidae/cacomistle  Procyonidae/cacomistle
  f  mammals/Procyonidae/coatimundi  Procyonidae/coatimundi
  f  mammals/Procyonidae/raccoon     Procyonidae/raccoon

  $ hg debugwalk -v .
  * matcher:
  <patternmatcher patterns='(?:mammals(?:/|$))'>
  f  mammals/Procyonidae/cacomistle  Procyonidae/cacomistle
  f  mammals/Procyonidae/coatimundi  Procyonidae/coatimundi
  f  mammals/Procyonidae/raccoon     Procyonidae/raccoon
  f  mammals/skunk                   skunk
  $ hg debugwalk -v -I.
  * matcher:
  <includematcher includes='(?:mammals(?:/|$))'>
  f  mammals/Procyonidae/cacomistle  Procyonidae/cacomistle
  f  mammals/Procyonidae/coatimundi  Procyonidae/coatimundi
  f  mammals/Procyonidae/raccoon     Procyonidae/raccoon
  f  mammals/skunk                   skunk
  $ hg debugwalk -v Procyonidae
  * matcher:
  <patternmatcher patterns='(?:mammals/Procyonidae(?:/|$))'>
  f  mammals/Procyonidae/cacomistle  Procyonidae/cacomistle
  f  mammals/Procyonidae/coatimundi  Procyonidae/coatimundi
  f  mammals/Procyonidae/raccoon     Procyonidae/raccoon

  $ cd Procyonidae
  $ hg debugwalk -v .
  * matcher:
  <patternmatcher patterns='(?:mammals/Procyonidae(?:/|$))'>
  f  mammals/Procyonidae/cacomistle  cacomistle
  f  mammals/Procyonidae/coatimundi  coatimundi
  f  mammals/Procyonidae/raccoon     raccoon
  $ hg debugwalk -v ..
  * matcher:
  <patternmatcher patterns='(?:mammals(?:/|$))'>
  f  mammals/Procyonidae/cacomistle  cacomistle
  f  mammals/Procyonidae/coatimundi  coatimundi
  f  mammals/Procyonidae/raccoon     raccoon
  f  mammals/skunk                   ../skunk
  $ cd ..

  $ hg debugwalk -v ../beans
  * matcher:
  <patternmatcher patterns='(?:beans(?:/|$))'>
  f  beans/black     ../beans/black
  f  beans/borlotti  ../beans/borlotti
  f  beans/kidney    ../beans/kidney
  f  beans/navy      ../beans/navy
  f  beans/pinto     ../beans/pinto
  f  beans/turtle    ../beans/turtle
  $ hg debugwalk -v .
  * matcher:
  <patternmatcher patterns='(?:mammals(?:/|$))'>
  f  mammals/Procyonidae/cacomistle  Procyonidae/cacomistle
  f  mammals/Procyonidae/coatimundi  Procyonidae/coatimundi
  f  mammals/Procyonidae/raccoon     Procyonidae/raccoon
  f  mammals/skunk                   skunk
  $ hg debugwalk -v .hg
  abort: path 'mammals/.hg' is inside nested repo 'mammals'
  [255]
  $ hg debugwalk -v ../.hg
  abort: path contains illegal component: .hg
  [255]
  $ cd ..

  $ hg debugwalk -v -Ibeans
  * matcher:
  <includematcher includes='(?:beans(?:/|$))'>
  f  beans/black     beans/black
  f  beans/borlotti  beans/borlotti
  f  beans/kidney    beans/kidney
  f  beans/navy      beans/navy
  f  beans/pinto     beans/pinto
  f  beans/turtle    beans/turtle
  $ hg debugwalk -v -I '{*,{b,m}*/*}k'
  * matcher:
  <includematcher includes='(?:(?:[^/]*|(?:b|m)[^/]*/[^/]*)k(?:/|$))'>
  f  beans/black    beans/black
  f  fenugreek      fenugreek
  f  mammals/skunk  mammals/skunk
  $ hg debugwalk -v -Ibeans mammals
  * matcher:
  <intersectionmatcher
    m1=<patternmatcher patterns='(?:mammals(?:/|$))'>,
    m2=<includematcher includes='(?:beans(?:/|$))'>>
  $ hg debugwalk -v -Inon-existent
  * matcher:
  <includematcher includes='(?:non\\-existent(?:/|$))'>
  $ hg debugwalk -v -Inon-existent -Ibeans/black
  * matcher:
  <includematcher includes='(?:non\\-existent(?:/|$)|beans/black(?:/|$))'>
  f  beans/black  beans/black
  $ hg debugwalk -v -Ibeans beans/black
  * matcher:
  <intersectionmatcher
    m1=<patternmatcher patterns='(?:beans/black(?:/|$))'>,
    m2=<includematcher includes='(?:beans(?:/|$))'>>
  f  beans/black  beans/black  exact
  $ hg debugwalk -v -Ibeans/black beans
  * matcher:
  <intersectionmatcher
    m1=<patternmatcher patterns='(?:beans(?:/|$))'>,
    m2=<includematcher includes='(?:beans/black(?:/|$))'>>
  f  beans/black  beans/black
  $ hg debugwalk -v -Xbeans/black beans
  * matcher:
  <differencematcher
    m1=<patternmatcher patterns='(?:beans(?:/|$))'>,
    m2=<includematcher includes='(?:beans/black(?:/|$))'>>
  f  beans/borlotti  beans/borlotti
  f  beans/kidney    beans/kidney
  f  beans/navy      beans/navy
  f  beans/pinto     beans/pinto
  f  beans/turtle    beans/turtle
  $ hg debugwalk -v -Xbeans/black -Ibeans
  * matcher:
  <differencematcher
    m1=<includematcher includes='(?:beans(?:/|$))'>,
    m2=<includematcher includes='(?:beans/black(?:/|$))'>>
  f  beans/borlotti  beans/borlotti
  f  beans/kidney    beans/kidney
  f  beans/navy      beans/navy
  f  beans/pinto     beans/pinto
  f  beans/turtle    beans/turtle
  $ hg debugwalk -v -Xbeans/black beans/black
  * matcher:
  <differencematcher
    m1=<patternmatcher patterns='(?:beans/black(?:/|$))'>,
    m2=<includematcher includes='(?:beans/black(?:/|$))'>>
  $ hg debugwalk -v -Xbeans/black -Ibeans/black
  * matcher:
  <differencematcher
    m1=<includematcher includes='(?:beans/black(?:/|$))'>,
    m2=<includematcher includes='(?:beans/black(?:/|$))'>>
  $ hg debugwalk -v -Xbeans beans/black
  * matcher:
  <differencematcher
    m1=<patternmatcher patterns='(?:beans/black(?:/|$))'>,
    m2=<includematcher includes='(?:beans(?:/|$))'>>
  $ hg debugwalk -v -Xbeans -Ibeans/black
  * matcher:
  <differencematcher
    m1=<includematcher includes='(?:beans/black(?:/|$))'>,
    m2=<includematcher includes='(?:beans(?:/|$))'>>
  $ hg debugwalk -v 'glob:mammals/../beans/b*'
  * matcher:
  <patternmatcher patterns='(?:beans/b[^/]*$)'>
  f  beans/black     beans/black
  f  beans/borlotti  beans/borlotti
  $ hg debugwalk -v '-X*/Procyonidae' mammals
  * matcher:
  <differencematcher
    m1=<patternmatcher patterns='(?:mammals(?:/|$))'>,
    m2=<includematcher includes='(?:[^/]*/Procyonidae(?:/|$))'>>
  f  mammals/skunk  mammals/skunk
  $ hg debugwalk -v path:mammals
  * matcher:
  <patternmatcher patterns='(?:mammals(?:/|$))'>
  f  mammals/Procyonidae/cacomistle  mammals/Procyonidae/cacomistle
  f  mammals/Procyonidae/coatimundi  mammals/Procyonidae/coatimundi
  f  mammals/Procyonidae/raccoon     mammals/Procyonidae/raccoon
  f  mammals/skunk                   mammals/skunk
  $ hg debugwalk -v ..
  abort: .. not under root '$TESTTMP/t'
  [255]
  $ hg debugwalk -v beans/../..
  abort: beans/../.. not under root '$TESTTMP/t'
  [255]
  $ hg debugwalk -v .hg
  abort: path contains illegal component: .hg
  [255]
  $ hg debugwalk -v beans/../.hg
  abort: path contains illegal component: .hg
  [255]
  $ hg debugwalk -v beans/../.hg/data
  abort: path contains illegal component: .hg/data
  [255]
  $ hg debugwalk -v beans/.hg
  abort: path 'beans/.hg' is inside nested repo 'beans'
  [255]

Test explicit paths and excludes:

  $ hg debugwalk -v fennel -X fennel
  * matcher:
  <differencematcher
    m1=<patternmatcher patterns='(?:fennel(?:/|$))'>,
    m2=<includematcher includes='(?:fennel(?:/|$))'>>
  $ hg debugwalk -v fennel -X 'f*'
  * matcher:
  <differencematcher
    m1=<patternmatcher patterns='(?:fennel(?:/|$))'>,
    m2=<includematcher includes='(?:f[^/]*(?:/|$))'>>
  $ hg debugwalk -v beans/black -X 'path:beans'
  * matcher:
  <differencematcher
    m1=<patternmatcher patterns='(?:beans/black(?:/|$))'>,
    m2=<includematcher includes='(?:beans(?:/|$))'>>
  $ hg debugwalk -v -I 'path:beans/black' -X 'path:beans'
  * matcher:
  <differencematcher
    m1=<includematcher includes='(?:beans/black(?:/|$))'>,
    m2=<includematcher includes='(?:beans(?:/|$))'>>

Test absolute paths:

  $ hg debugwalk -v `pwd`/beans
  * matcher:
  <patternmatcher patterns='(?:beans(?:/|$))'>
  f  beans/black     beans/black
  f  beans/borlotti  beans/borlotti
  f  beans/kidney    beans/kidney
  f  beans/navy      beans/navy
  f  beans/pinto     beans/pinto
  f  beans/turtle    beans/turtle
  $ hg debugwalk -v `pwd`/..
  abort: $TESTTMP/t/.. not under root '$TESTTMP/t'
  [255]

Test patterns:

  $ hg debugwalk -v glob:\*
  * matcher:
  <patternmatcher patterns='(?:[^/]*$)'>
  f  fennel      fennel
  f  fenugreek   fenugreek
  f  fiddlehead  fiddlehead
#if eol-in-paths
  $ echo glob:glob > glob:glob
  $ hg addremove
  adding glob:glob
  warning: filename contains ':', which is reserved on Windows: 'glob:glob'
  $ hg debugwalk -v glob:\*
  * matcher:
  <patternmatcher patterns='(?:[^/]*$)'>
  f  fennel      fennel
  f  fenugreek   fenugreek
  f  fiddlehead  fiddlehead
  f  glob:glob   glob:glob
  $ hg debugwalk -v glob:glob
  * matcher:
  <patternmatcher patterns='(?:glob$)'>
  glob: $ENOENT$
  $ hg debugwalk -v glob:glob:glob
  * matcher:
  <patternmatcher patterns='(?:glob:glob$)'>
  f  glob:glob  glob:glob  exact
  $ hg debugwalk -v path:glob:glob
  * matcher:
  <patternmatcher patterns='(?:glob:glob(?:/|$))'>
  f  glob:glob  glob:glob  exact
  $ rm glob:glob
  $ hg addremove
  removing glob:glob
#endif

  $ hg debugwalk -v 'glob:**e'
  * matcher:
  <patternmatcher patterns='(?:.*e$)'>
  f  beans/turtle                    beans/turtle
  f  mammals/Procyonidae/cacomistle  mammals/Procyonidae/cacomistle

  $ hg debugwalk -v 're:.*[kb]$'
  * matcher:
  <patternmatcher patterns='(?:.*[kb]$)'>
  f  beans/black    beans/black
  f  fenugreek      fenugreek
  f  mammals/skunk  mammals/skunk

  $ hg debugwalk -v path:beans/black
  * matcher:
  <patternmatcher patterns='(?:beans/black(?:/|$))'>
  f  beans/black  beans/black  exact
  $ hg debugwalk -v path:beans//black
  * matcher:
  <patternmatcher patterns='(?:beans/black(?:/|$))'>
  f  beans/black  beans/black  exact

  $ hg debugwalk -v relglob:Procyonidae
  * matcher:
  <patternmatcher patterns='(?:(?:|.*/)Procyonidae$)'>
  $ hg debugwalk -v 'relglob:Procyonidae/**'
  * matcher:
  <patternmatcher patterns='(?:(?:|.*/)Procyonidae/.*$)'>
  f  mammals/Procyonidae/cacomistle  mammals/Procyonidae/cacomistle
  f  mammals/Procyonidae/coatimundi  mammals/Procyonidae/coatimundi
  f  mammals/Procyonidae/raccoon     mammals/Procyonidae/raccoon
  $ hg debugwalk -v 'relglob:Procyonidae/**' fennel
  * matcher:
  <patternmatcher patterns='(?:(?:|.*/)Procyonidae/.*$|fennel(?:/|$))'>
  f  fennel                          fennel                          exact
  f  mammals/Procyonidae/cacomistle  mammals/Procyonidae/cacomistle
  f  mammals/Procyonidae/coatimundi  mammals/Procyonidae/coatimundi
  f  mammals/Procyonidae/raccoon     mammals/Procyonidae/raccoon
  $ hg debugwalk -v beans 'glob:beans/*'
  * matcher:
  <patternmatcher patterns='(?:beans(?:/|$)|beans/[^/]*$)'>
  f  beans/black     beans/black
  f  beans/borlotti  beans/borlotti
  f  beans/kidney    beans/kidney
  f  beans/navy      beans/navy
  f  beans/pinto     beans/pinto
  f  beans/turtle    beans/turtle
  $ hg debugwalk -v 'glob:mamm**'
  * matcher:
  <patternmatcher patterns='(?:mamm.*$)'>
  f  mammals/Procyonidae/cacomistle  mammals/Procyonidae/cacomistle
  f  mammals/Procyonidae/coatimundi  mammals/Procyonidae/coatimundi
  f  mammals/Procyonidae/raccoon     mammals/Procyonidae/raccoon
  f  mammals/skunk                   mammals/skunk
  $ hg debugwalk -v 'glob:mamm**' fennel
  * matcher:
  <patternmatcher patterns='(?:mamm.*$|fennel(?:/|$))'>
  f  fennel                          fennel                          exact
  f  mammals/Procyonidae/cacomistle  mammals/Procyonidae/cacomistle
  f  mammals/Procyonidae/coatimundi  mammals/Procyonidae/coatimundi
  f  mammals/Procyonidae/raccoon     mammals/Procyonidae/raccoon
  f  mammals/skunk                   mammals/skunk
  $ hg debugwalk -v 'glob:j*'
  * matcher:
  <patternmatcher patterns='(?:j[^/]*$)'>
  $ hg debugwalk -v NOEXIST
  * matcher:
  <patternmatcher patterns='(?:NOEXIST(?:/|$))'>
  NOEXIST: * (glob)

#if fifo
  $ mkfifo fifo
  $ hg debugwalk -v fifo
  * matcher:
  <patternmatcher patterns='(?:fifo(?:/|$))'>
  fifo: unsupported file type (type is fifo)
#endif

  $ rm fenugreek
  $ hg debugwalk -v fenugreek
  * matcher:
  <patternmatcher patterns='(?:fenugreek(?:/|$))'>
  f  fenugreek  fenugreek  exact
  $ hg rm fenugreek
  $ hg debugwalk -v fenugreek
  * matcher:
  <patternmatcher patterns='(?:fenugreek(?:/|$))'>
  f  fenugreek  fenugreek  exact
  $ touch new
  $ hg debugwalk -v new
  * matcher:
  <patternmatcher patterns='(?:new(?:/|$))'>
  f  new  new  exact

  $ mkdir ignored
  $ touch ignored/file
  $ echo '^ignored$' > .hgignore
  $ hg debugwalk -v ignored
  * matcher:
  <patternmatcher patterns='(?:ignored(?:/|$))'>
  $ hg debugwalk -v ignored/file
  * matcher:
  <patternmatcher patterns='(?:ignored/file(?:/|$))'>
  f  ignored/file  ignored/file  exact

Test listfile and listfile0

  $ $PYTHON -c "open('listfile0', 'wb').write(b'fenugreek\0new\0')"
  $ hg debugwalk -v -I 'listfile0:listfile0'
  * matcher:
  <includematcher includes='(?:fenugreek(?:/|$)|new(?:/|$))'>
  f  fenugreek  fenugreek
  f  new        new
  $ $PYTHON -c "open('listfile', 'wb').write(b'fenugreek\nnew\r\nmammals/skunk\n')"
  $ hg debugwalk -v -I 'listfile:listfile'
  * matcher:
  <includematcher includes='(?:fenugreek(?:/|$)|new(?:/|$)|mammals/skunk(?:/|$))'>
  f  fenugreek      fenugreek
  f  mammals/skunk  mammals/skunk
  f  new            new

  $ cd ..
  $ hg debugwalk -v -R t t/mammals/skunk
  * matcher:
  <patternmatcher patterns='(?:mammals/skunk(?:/|$))'>
  f  mammals/skunk  t/mammals/skunk  exact
  $ mkdir t2
  $ cd t2
  $ hg debugwalk -v -R ../t ../t/mammals/skunk
  * matcher:
  <patternmatcher patterns='(?:mammals/skunk(?:/|$))'>
  f  mammals/skunk  ../t/mammals/skunk  exact
  $ hg debugwalk -v --cwd ../t mammals/skunk
  * matcher:
  <patternmatcher patterns='(?:mammals/skunk(?:/|$))'>
  f  mammals/skunk  mammals/skunk  exact

  $ cd ..

Test split patterns on overflow

  $ cd t
  $ echo fennel > overflow.list
  $ cat >> printnum.py <<EOF
  > from __future__ import print_function
  > for i in range(20000 // 100):
  >   print('x' * 100)
  > EOF
  $ $PYTHON printnum.py >> overflow.list
  $ echo fenugreek >> overflow.list
  $ hg debugwalk 'listfile:overflow.list' 2>&1 | egrep -v '^xxx'
  f  fennel     fennel     exact
  f  fenugreek  fenugreek  exact
  $ cd ..
