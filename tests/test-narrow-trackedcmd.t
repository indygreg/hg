#testcases flat tree
  $ . "$TESTDIR/narrow-library.sh"

#if tree
  $ cat << EOF >> $HGRCPATH
  > [experimental]
  > treemanifest = 1
  > EOF
#endif

  $ hg init master
  $ cd master
  $ cat >> .hg/hgrc <<EOF
  > [narrow]
  > serveellipses=True
  > EOF

  $ mkdir inside
  $ echo 'inside' > inside/f
  $ hg add inside/f
  $ hg commit -m 'add inside'

  $ mkdir widest
  $ echo 'widest' > widest/f
  $ hg add widest/f
  $ hg commit -m 'add widest'

  $ mkdir outside
  $ echo 'outside' > outside/f
  $ hg add outside/f
  $ hg commit -m 'add outside'

  $ cd ..

narrow clone the inside file

  $ hg clone --narrow ssh://user@dummy/master narrow --include inside
  requesting all changes
  adding changesets
  adding manifests
  adding file changes
  added 2 changesets with 1 changes to 1 files
  new changesets *:* (glob)
  updating to branch default
  1 files updated, 0 files merged, 0 files removed, 0 files unresolved
  $ cd narrow
  $ hg tracked
  I path:inside
  $ ls
  inside
  $ cat inside/f
  inside
  $ cd ..

add more upstream files which we will include in a wider narrow spec

  $ cd master

  $ mkdir wider
  $ echo 'wider' > wider/f
  $ hg add wider/f
  $ echo 'widest v2' > widest/f
  $ hg commit -m 'add wider, update widest'

  $ echo 'widest v3' > widest/f
  $ hg commit -m 'update widest v3'

  $ echo 'inside v2' > inside/f
  $ hg commit -m 'update inside'

  $ mkdir outside2
  $ echo 'outside2' > outside2/f
  $ hg add outside2/f
  $ hg commit -m 'add outside2'

  $ echo 'widest v4' > widest/f
  $ hg commit -m 'update widest v4'

  $ hg log -T "{if(ellipsis, '...')}{rev}: {desc}\n"
  7: update widest v4
  6: add outside2
  5: update inside
  4: update widest v3
  3: add wider, update widest
  2: add outside
  1: add widest
  0: add inside

  $ cd ..

Testing the --import-rules flag of `hg tracked` command

  $ cd narrow
  $ hg tracked --import-rules
  hg tracked: option --import-rules requires argument
  hg tracked [OPTIONS]... [REMOTE]
  
  show or change the current narrowspec
  
  options ([+] can be repeated):
  
      --addinclude VALUE [+]       new paths to include
      --removeinclude VALUE [+]    old paths to no longer include
      --addexclude VALUE [+]       new paths to exclude
      --import-rules VALUE         import narrowspecs from a file
      --removeexclude VALUE [+]    old paths to no longer exclude
      --clear                      whether to replace the existing narrowspec
      --force-delete-local-changes forces deletion of local changes when
                                   narrowing
   -e --ssh CMD                    specify ssh command to use
      --remotecmd CMD              specify hg command to run on the remote side
      --insecure                   do not verify server certificate (ignoring
                                   web.cacerts config)
  
  (use 'hg tracked -h' to show more help)
  [255]
  $ hg tracked --import-rules doesnotexist
  abort: cannot read narrowspecs from '$TESTTMP/narrow/doesnotexist': $ENOENT$
  [255]

  $ cat > specs <<EOF
  > %include foo
  > [include]
  > path:widest/
  > [exclude]
  > path:inside/
  > EOF

  $ hg tracked --import-rules specs
  abort: including other spec files using '%include' is not supported in narrowspec
  [255]

  $ cat > specs <<EOF
  > [include]
  > outisde
  > [exclude]
  > inside
  > EOF

  $ hg tracked --import-rules specs
  comparing with ssh://user@dummy/master
  searching for changes
  looking for local changes to affected paths
  deleting data/inside/f.i
  deleting meta/inside/00manifest.i (tree !)
  no changes found
  saved backup bundle to $TESTTMP/narrow/.hg/strip-backup/*-widen.hg (glob)
  adding changesets
  adding manifests
  adding file changes
  added 2 changesets with 0 changes to 0 files
  new changesets *:* (glob)
  $ hg tracked
  I path:outisde
  X path:inside

Testing the --import-rules flag with --addinclude and --addexclude

  $ cat > specs <<EOF
  > [include]
  > widest
  > EOF

  $ hg tracked --import-rules specs --addinclude 'wider/'
  comparing with ssh://user@dummy/master
  searching for changes
  no changes found
  saved backup bundle to $TESTTMP/narrow/.hg/strip-backup/*-widen.hg (glob)
  adding changesets
  adding manifests
  adding file changes
  added 3 changesets with 1 changes to 1 files
  new changesets *:* (glob)
  $ hg tracked
  I path:outisde
  I path:wider
  I path:widest
  X path:inside

  $ cat > specs <<EOF
  > [exclude]
  > outside2
  > EOF

  $ hg tracked --import-rules specs --addexclude 'widest'
  comparing with ssh://user@dummy/master
  searching for changes
  looking for local changes to affected paths
  deleting data/widest/f.i
  deleting meta/widest/00manifest.i (tree !)
  $ hg tracked
  I path:outisde
  I path:wider
  X path:inside
  X path:outside2
  X path:widest

  $ hg tracked --import-rules specs --clear
  The --clear option is not yet supported.
  [1]

Testing with passing a out of wdir file

  $ cat > ../nspecs <<EOF
  > [include]
  > widest
  > EOF

  $ hg tracked --import-rules ../nspecs
  comparing with ssh://user@dummy/master
  searching for changes
  no changes found
  saved backup bundle to $TESTTMP/narrow/.hg/strip-backup/*-widen.hg (glob)
  adding changesets
  adding manifests
  adding file changes
  added 3 changesets with 0 changes to 0 files
  new changesets *:* (glob)
