  $ cat <<'EOF' >> "$HGRCPATH"
  > [extensions]
  > convert =
  > [templates]
  > l = '{rev}:{node|short} p={p1rev},{p2rev} m={manifest} f={files|json}'
  > EOF

  $ check_convert_identity () {
  >     hg convert -q "$1" "$1.converted"
  >     hg outgoing -q -R "$1.converted" "$1"
  >     if [ "$?" != 1 ]; then
  >         echo '*** BUG: hash changes on convert ***'
  >         hg log -R "$1.converted" -GTl
  >     fi
  > }

Files added at both parents:

  $ hg init added-both
  $ cd added-both
  $ touch a b c
  $ hg ci -qAm0 a
  $ hg ci -qAm1 b
  $ hg up -q 0
  $ hg ci -qAm2 c

  $ hg merge
  1 files updated, 0 files merged, 0 files removed, 0 files unresolved
  (branch merge, don't forget to commit)
  $ hg ci --debug -m merge
  committing files:
  b
  not reusing manifest (no file change in changelog, but manifest differs)
  committing manifest
  committing changelog
  updating the branch cache
  committed changeset 3:7aa8a293f5d97377037afc21e871e036e718d659
  $ hg log -GTl
  @    3:7aa8a293f5d9 p=2,1 m=3:8667461869a1 f=[]
  |\
  | o  2:e0ea47086fce p=0,-1 m=2:b2e5b07f9374 f=["c"]
  | |
  o |  1:64d01526d4c2 p=0,-1 m=1:686dbf0aeca4 f=["b"]
  |/
  o  0:487a0a245cea p=-1,-1 m=0:8515d4bfda76 f=["a"]
  

  $ cd ..
  $ check_convert_identity added-both

Files added at both parents, but the other removed at the merge:
(In this case, ctx.files() after the commit contains the removed file "b", but
its manifest does not differ from p1.)

  $ hg init added-both-removed-at-merge
  $ cd added-both-removed-at-merge
  $ touch a b c
  $ hg ci -qAm0 a
  $ hg ci -qAm1 b
  $ hg up -q 0
  $ hg ci -qAm2 c

  $ hg merge
  1 files updated, 0 files merged, 0 files removed, 0 files unresolved
  (branch merge, don't forget to commit)
  $ hg rm -f b
  $ hg ci --debug -m merge
  committing files:
  committing manifest
  committing changelog
  updating the branch cache
  committed changeset 3:915745f3ca3d9d699925269474c2d0a9526e8dfa
  $ hg log -GTl
  @    3:915745f3ca3d p=2,1 m=3:8e9cf3456921 f=["b"]
  |\
  | o  2:e0ea47086fce p=0,-1 m=2:b2e5b07f9374 f=["c"]
  | |
  o |  1:64d01526d4c2 p=0,-1 m=1:686dbf0aeca4 f=["b"]
  |/
  o  0:487a0a245cea p=-1,-1 m=0:8515d4bfda76 f=["a"]
  

  $ cd ..
  $ check_convert_identity added-both

An identical file added at both parents:

  $ hg init added-identical
  $ cd added-identical
  $ touch a b
  $ hg ci -qAm0 a
  $ hg ci -qAm1 b
  $ hg up -q 0
  $ touch b
  $ hg ci -qAm2 b

  $ hg merge
  0 files updated, 0 files merged, 0 files removed, 0 files unresolved
  (branch merge, don't forget to commit)
  $ hg ci --debug -m merge
  reusing manifest from p1 (no file change)
  committing changelog
  updating the branch cache
  committed changeset 3:de26182cd210f0c3fb175ca7616704ab963d3024
  $ hg log -GTl
  @    3:de26182cd210 p=2,1 m=1:686dbf0aeca4 f=[]
  |\
  | o  2:f00991f11eca p=0,-1 m=1:686dbf0aeca4 f=["b"]
  | |
  o |  1:64d01526d4c2 p=0,-1 m=1:686dbf0aeca4 f=["b"]
  |/
  o  0:487a0a245cea p=-1,-1 m=0:8515d4bfda76 f=["a"]
  

  $ cd ..
  $ check_convert_identity added-identical

#if execbit

An identical file added at both parents, but the flag differs. Take local:

  $ hg init flag-change-take-p1
  $ cd flag-change-take-p1
  $ touch a b
  $ hg ci -qAm0 a
  $ hg ci -qAm1 b
  $ hg up -q 0
  $ touch b
  $ chmod +x b
  $ hg ci -qAm2 b

  $ hg merge
  warning: cannot merge flags for b without common ancestor - keeping local flags
  1 files updated, 0 files merged, 0 files removed, 0 files unresolved
  (branch merge, don't forget to commit)
  $ chmod +x b
  $ hg ci --debug -m merge
  committing files:
  b
  reusing manifest form p1 (listed files actually unchanged)
  committing changelog
  updating the branch cache
  committed changeset 3:c8d50407916ef8a5a97cb6e36ca9bc844a6ee13e
  $ hg log -GTl
  @    3:c8d50407916e p=2,1 m=2:36b69ba4b24b f=[]
  |\
  | o  2:99451f16b3f5 p=0,-1 m=2:36b69ba4b24b f=["b"]
  | |
  o |  1:64d01526d4c2 p=0,-1 m=1:686dbf0aeca4 f=["b"]
  |/
  o  0:487a0a245cea p=-1,-1 m=0:8515d4bfda76 f=["a"]
  
  $ hg files -vr3
           0   a
           0 x b

  $ cd ..
  $ check_convert_identity flag-change-take-p1

An identical file added at both parents, but the flag differs. Take other:

  $ hg init flag-change-take-p2
  $ cd flag-change-take-p2
  $ touch a b
  $ hg ci -qAm0 a
  $ hg ci -qAm1 b
  $ hg up -q 0
  $ touch b
  $ chmod +x b
  $ hg ci -qAm2 b

  $ hg merge
  warning: cannot merge flags for b without common ancestor - keeping local flags
  1 files updated, 0 files merged, 0 files removed, 0 files unresolved
  (branch merge, don't forget to commit)
  $ chmod -x b
  $ hg ci --debug -m merge
  committing files:
  b
  committing manifest
  committing changelog
  updating the branch cache
  committed changeset 3:06a62a687d87c7d8944743dee1ee9d8c66b3f6e3
  $ hg log -GTl
  @    3:06a62a687d87 p=2,1 m=3:2a315ba1aa45 f=["b"]
  |\
  | o  2:99451f16b3f5 p=0,-1 m=2:36b69ba4b24b f=["b"]
  | |
  o |  1:64d01526d4c2 p=0,-1 m=1:686dbf0aeca4 f=["b"]
  |/
  o  0:487a0a245cea p=-1,-1 m=0:8515d4bfda76 f=["a"]
  
  $ hg files -vr3
           0   a
           0   b

  $ cd ..
  $ check_convert_identity flag-change-take-p2

#endif

An identical file added at both parents, one more file added at p2:

  $ hg init added-some-p2
  $ cd added-some-p2
  $ touch a b c
  $ hg ci -qAm0 a
  $ hg ci -qAm1 b
  $ hg ci -qAm2 c
  $ hg up -q 0
  $ touch b
  $ hg ci -qAm3 b

  $ hg merge
  1 files updated, 0 files merged, 0 files removed, 0 files unresolved
  (branch merge, don't forget to commit)
  $ hg ci --debug -m merge
  committing files:
  c
  not reusing manifest (no file change in changelog, but manifest differs)
  committing manifest
  committing changelog
  updating the branch cache
  committed changeset 4:f7fbc4e4d9a8fde03ba475adad675578c8bf472d
  $ hg log -GTl
  @    4:f7fbc4e4d9a8 p=3,2 m=3:92acd5bfd716 f=[]
  |\
  | o  3:e9d9f3cc981f p=0,-1 m=1:686dbf0aeca4 f=["b"]
  | |
  o |  2:93c5529a4ec7 p=1,-1 m=2:ae25a31b30b3 f=["c"]
  | |
  o |  1:64d01526d4c2 p=0,-1 m=1:686dbf0aeca4 f=["b"]
  |/
  o  0:487a0a245cea p=-1,-1 m=0:8515d4bfda76 f=["a"]
  

  $ cd ..
  $ check_convert_identity added-some-p2

An identical file added at both parents, one more file added at p1:
(In this case, p1 manifest is reused at the merge commit, which means the
manifest DAG does not have the same shape as the changelog.)

  $ hg init added-some-p1
  $ cd added-some-p1
  $ touch a b
  $ hg ci -qAm0 a
  $ hg ci -qAm1 b
  $ hg up -q 0
  $ touch b c
  $ hg ci -qAm2 b
  $ hg ci -qAm3 c

  $ hg merge
  0 files updated, 0 files merged, 0 files removed, 0 files unresolved
  (branch merge, don't forget to commit)
  $ hg ci --debug -m merge
  reusing manifest from p1 (no file change)
  committing changelog
  updating the branch cache
  committed changeset 4:a9f0f589a913f5a149dc10dfbd5af726977c36c4
  $ hg log -GTl
  @    4:a9f0f589a913 p=3,1 m=2:ae25a31b30b3 f=[]
  |\
  | o  3:b8dc385241b5 p=2,-1 m=2:ae25a31b30b3 f=["c"]
  | |
  | o  2:f00991f11eca p=0,-1 m=1:686dbf0aeca4 f=["b"]
  | |
  o |  1:64d01526d4c2 p=0,-1 m=1:686dbf0aeca4 f=["b"]
  |/
  o  0:487a0a245cea p=-1,-1 m=0:8515d4bfda76 f=["a"]
  

  $ cd ..
  $ check_convert_identity added-some-p1

A file added at p2, a named branch created at p1:

  $ hg init named-branch-p1
  $ cd named-branch-p1
  $ touch a b
  $ hg ci -qAm0 a
  $ hg ci -qAm1 b
  $ hg up -q 0
  $ hg branch -q foo
  $ hg ci -m2

  $ hg merge default
  1 files updated, 0 files merged, 0 files removed, 0 files unresolved
  (branch merge, don't forget to commit)
  $ hg ci --debug -m merge
  committing files:
  b
  not reusing manifest (no file change in changelog, but manifest differs)
  committing manifest
  committing changelog
  updating the branch cache
  committed changeset 3:fb97d83b02fd072295cfc2171f21b7d38509bfd7
  $ hg log -GT'{l} branch={branch}'
  @    3:fb97d83b02fd p=2,1 m=2:9091c64f4ea1 f=[] branch=foo
  |\
  | o  2:a3a9fa6587e5 p=0,-1 m=0:8515d4bfda76 f=[] branch=foo
  | |
  o |  1:64d01526d4c2 p=0,-1 m=1:686dbf0aeca4 f=["b"] branch=default
  |/
  o  0:487a0a245cea p=-1,-1 m=0:8515d4bfda76 f=["a"] branch=default
  

  $ cd ..
  $ check_convert_identity named-branch-p1

A file added at p1, a named branch created at p2:
(In this case, p1 manifest is reused at the merge commit, which means the
manifest DAG does not have the same shape as the changelog.)

  $ hg init named-branch-p2
  $ cd named-branch-p2
  $ touch a b
  $ hg ci -qAm0 a
  $ hg branch -q foo
  $ hg ci -m1
  $ hg up -q 0
  $ hg ci -qAm1 b

  $ hg merge foo
  0 files updated, 0 files merged, 0 files removed, 0 files unresolved
  (branch merge, don't forget to commit)
  $ hg ci --debug -m merge
  reusing manifest from p1 (no file change)
  committing changelog
  updating the branch cache
  committed changeset 3:036823e24692218324d4af43b07ff89f8a000096
  $ hg log -GT'{l} branch={branch}'
  @    3:036823e24692 p=2,1 m=1:686dbf0aeca4 f=[] branch=default
  |\
  | o  2:64d01526d4c2 p=0,-1 m=1:686dbf0aeca4 f=["b"] branch=default
  | |
  o |  1:da38c8e00727 p=0,-1 m=0:8515d4bfda76 f=[] branch=foo
  |/
  o  0:487a0a245cea p=-1,-1 m=0:8515d4bfda76 f=["a"] branch=default
  

  $ cd ..
  $ check_convert_identity named-branch-p2

A file changed once at both parents, but amended to have identical content:

  $ hg init amend-p1
  $ cd amend-p1
  $ touch a
  $ hg ci -qAm0 a
  $ echo foo > a
  $ hg ci -m1
  $ hg up -q 0
  $ echo bar > a
  $ hg ci -qm2
  $ echo foo > a
  $ hg ci -qm3 --amend

  $ hg merge
  0 files updated, 0 files merged, 0 files removed, 0 files unresolved
  (branch merge, don't forget to commit)
  $ hg ci --debug -m merge
  reusing manifest from p1 (no file change)
  committing changelog
  updating the branch cache
  committed changeset 3:314e5bc5adf5c58ea571efabe33eedba20a201aa
  $ hg log -GT'{l} branch={branch}'
  @    3:314e5bc5adf5 p=2,1 m=1:d33ea248bd73 f=[] branch=default
  |\
  | o  2:de9c64f226a3 p=0,-1 m=1:d33ea248bd73 f=["a"] branch=default
  | |
  o |  1:6a74aec01b3c p=0,-1 m=1:d33ea248bd73 f=["a"] branch=default
  |/
  o  0:487a0a245cea p=-1,-1 m=0:8515d4bfda76 f=["a"] branch=default
  

  $ cd ..
  $ check_convert_identity amend-p1
