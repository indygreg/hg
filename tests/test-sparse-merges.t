test merging things outside of the sparse checkout

  $ hg init myrepo
  $ cd myrepo
  $ cat > .hg/hgrc <<EOF
  > [extensions]
  > sparse=
  > EOF

  $ echo foo > foo
  $ echo bar > bar
  $ hg add foo bar
  $ hg commit -m initial

  $ hg branch feature
  marked working directory as branch feature
  (branches are permanent and global, did you want a bookmark?)
  $ echo bar2 >> bar
  $ hg commit -m 'feature - bar2'

  $ hg update -q default
  $ hg debugsparse --exclude 'bar**'

  $ hg merge feature
  temporarily included 1 file(s) in the sparse checkout for merging
  1 files updated, 0 files merged, 0 files removed, 0 files unresolved
  (branch merge, don't forget to commit)

Verify bar was merged temporarily

  $ ls
  bar
  foo
  $ hg status
  M bar

Verify bar disappears automatically when the working copy becomes clean

  $ hg commit -m "merged"
  cleaned up 1 temporarily added file(s) from the sparse checkout
  $ hg status
  $ ls
  foo

  $ hg cat -r . bar
  bar
  bar2

Test merging things outside of the sparse checkout that are not in the working
copy

  $ hg strip -q -r . --config extensions.strip=
  $ hg up -q feature
  $ touch branchonly
  $ hg ci -Aqm 'add branchonly'

  $ hg up -q default
  $ hg debugsparse -X branchonly
  $ hg merge feature
  temporarily included 2 file(s) in the sparse checkout for merging
  2 files updated, 0 files merged, 0 files removed, 0 files unresolved
  (branch merge, don't forget to commit)

  $ cd ..

Tests merging a file which is modified in one branch and deleted in another and
file is excluded from sparse checkout

  $ hg init ytest
  $ cd ytest
  $ echo "syntax: glob" >> .hgignore
  $ echo "*.orig" >> .hgignore
  $ hg ci -Aqm "added .hgignore"
  $ for ch in a d; do echo foo > $ch; hg ci -Aqm "added "$ch; done;
  $ cat >> .hg/hgrc <<EOF
  > [alias]
  > glog = log -GT "{rev}:{node|short} {desc}"
  > [extensions]
  > sparse =
  > EOF

  $ hg glog
  @  2:f29feff37cfc added d
  |
  o  1:617125d27d6b added a
  |
  o  0:53f3774ed939 added .hgignore
  
  $ hg rm d
  $ hg ci -m "removed d"

  $ hg up '.^'
  1 files updated, 0 files merged, 0 files removed, 0 files unresolved
  $ hg debugsparse --reset
  $ echo bar >> d
  $ hg ci -Am "added bar to d"
  created new head

  $ hg glog
  @  4:6527874a90e4 added bar to d
  |
  | o  3:372c8558de45 removed d
  |/
  o  2:f29feff37cfc added d
  |
  o  1:617125d27d6b added a
  |
  o  0:53f3774ed939 added .hgignore
  
  $ hg debugsparse --exclude "d"
  $ ls
  a

  $ hg merge
  temporarily included 1 file(s) in the sparse checkout for merging
  file 'd' was deleted in other [merge rev] but was modified in local [working copy].
  What do you want to do?
  use (c)hanged version, (d)elete, or leave (u)nresolved? u
  0 files updated, 0 files merged, 0 files removed, 1 files unresolved
  use 'hg resolve' to retry unresolved file merges or 'hg merge --abort' to abandon
  [1]

  $ cd ..

Testing merging of a file which is renamed+modified on one side and modified on
another

  $ hg init mvtest
  $ cd mvtest
  $ echo "syntax: glob" >> .hgignore
  $ echo "*.orig" >> .hgignore
  $ hg ci -Aqm "added .hgignore"
  $ for ch in a d; do echo foo > $ch; hg ci -Aqm "added "$ch; done;
  $ cat >> .hg/hgrc <<EOF
  > [alias]
  > glog = log -GT "{rev}:{node|short} {desc}"
  > [extensions]
  > sparse =
  > EOF

  $ hg glog
  @  2:f29feff37cfc added d
  |
  o  1:617125d27d6b added a
  |
  o  0:53f3774ed939 added .hgignore
  
  $ echo babar >> a
  $ hg ci -m "added babar to a"

  $ hg up '.^'
  1 files updated, 0 files merged, 0 files removed, 0 files unresolved
  $ hg mv a amove
  $ hg ci -m "moved a to amove"
  created new head

  $ hg up 3
  1 files updated, 0 files merged, 1 files removed, 0 files unresolved
  $ hg glog
  o  4:5d1e85955f6d moved a to amove
  |
  | @  3:a06e41a6c16c added babar to a
  |/
  o  2:f29feff37cfc added d
  |
  o  1:617125d27d6b added a
  |
  o  0:53f3774ed939 added .hgignore
  
  $ hg debugsparse --exclude "a"
  $ ls
  d

  $ hg merge
  temporarily included 1 file(s) in the sparse checkout for merging
  merging a and amove to amove
  0 files updated, 1 files merged, 0 files removed, 0 files unresolved
  (branch merge, don't forget to commit)

  $ hg up -C 4
  cleaned up 1 temporarily added file(s) from the sparse checkout
  1 files updated, 0 files merged, 0 files removed, 0 files unresolved

  $ hg merge
  merging amove and a to amove
  abort: cannot add 'a' - it is outside the sparse checkout
  (include file with `hg debugsparse --include <pattern>` or use `hg add -s <file>` to include file directory while adding)
  [255]
