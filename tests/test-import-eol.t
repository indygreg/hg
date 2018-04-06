  $ cat > makepatch.py <<EOF
  > import sys
  > f = open(sys.argv[2], 'wb')
  > w = f.write
  > w(b'test message\n')
  > w(b'diff --git a/a b/a\n')
  > w(b'--- a/a\n')
  > w(b'+++ b/a\n')
  > w(b'@@ -1,5 +1,5 @@\n')
  > w(b' a\n')
  > w(b'-bbb\r\n')
  > w(b'+yyyy\r\n')
  > w(b' cc\r\n')
  > w({'empty:lf': b' \n',
  >    'empty:crlf': b' \r\n',
  >    'empty:stripped-lf': b'\n',
  >    'empty:stripped-crlf': b'\r\n'}[sys.argv[1]])
  > w(b' d\n')
  > w(b'-e\n')
  > w(b'\ No newline at end of file\n')
  > w(b'+z\r\n')
  > w(b'\ No newline at end of file\r\n')
  > EOF

  $ hg init repo
  $ cd repo
  $ echo '\.diff' > .hgignore


Test different --eol values

  $ $PYTHON -c 'open("a", "wb").write(b"a\nbbb\ncc\n\nd\ne")'
  $ hg ci -Am adda
  adding .hgignore
  adding a
  $ $PYTHON ../makepatch.py empty:lf eol.diff
  $ $PYTHON ../makepatch.py empty:crlf eol-empty-crlf.diff
  $ $PYTHON ../makepatch.py empty:stripped-lf eol-empty-stripped-lf.diff
  $ $PYTHON ../makepatch.py empty:stripped-crlf eol-empty-stripped-crlf.diff

invalid eol

  $ hg --config patch.eol='LFCR' import eol.diff
  applying eol.diff
  abort: unsupported line endings type: LFCR
  [255]
  $ hg revert -a


force LF

  $ hg --traceback --config patch.eol='LF' import eol.diff
  applying eol.diff
  $ hg id
  9e4ef7b3d4af tip
  $ cat a
  a
  yyyy
  cc
  
  d
  e (no-eol)
  $ hg st

 (test empty-line variants: all of them should generate the same revision)

  $ hg up -qC 0
  $ hg --config patch.eol='LF' import eol-empty-crlf.diff
  applying eol-empty-crlf.diff
  $ hg id
  9e4ef7b3d4af tip

  $ hg up -qC 0
  $ hg --config patch.eol='LF' import eol-empty-stripped-lf.diff
  applying eol-empty-stripped-lf.diff
  $ hg id
  9e4ef7b3d4af tip

  $ hg up -qC 0
  $ hg --config patch.eol='LF' import eol-empty-stripped-crlf.diff
  applying eol-empty-stripped-crlf.diff
  $ hg id
  9e4ef7b3d4af tip

force CRLF

  $ hg up -C 0
  1 files updated, 0 files merged, 0 files removed, 0 files unresolved
  $ hg --traceback --config patch.eol='CRLF' import eol.diff
  applying eol.diff
  $ cat a
  a\r (esc)
  yyyy\r (esc)
  cc\r (esc)
  \r (esc)
  d\r (esc)
  e (no-eol)
  $ hg st


auto EOL on LF file

  $ hg up -C 0
  1 files updated, 0 files merged, 0 files removed, 0 files unresolved
  $ hg --traceback --config patch.eol='auto' import eol.diff
  applying eol.diff
  $ cat a
  a
  yyyy
  cc
  
  d
  e (no-eol)
  $ hg st


auto EOL on CRLF file

  $ $PYTHON -c 'open("a", "wb").write(b"a\r\nbbb\r\ncc\r\n\r\nd\r\ne")'
  $ hg commit -m 'switch EOLs in a'
  $ hg --traceback --config patch.eol='auto' import eol.diff
  applying eol.diff
  $ cat a
  a\r (esc)
  yyyy\r (esc)
  cc\r (esc)
  \r (esc)
  d\r (esc)
  e (no-eol)
  $ hg st


auto EOL on new file or source without any EOL

  $ $PYTHON -c 'open("noeol", "wb").write(b"noeol")'
  $ hg add noeol
  $ hg commit -m 'add noeol'
  $ $PYTHON -c 'open("noeol", "wb").write(b"noeol\r\nnoeol\n")'
  $ $PYTHON -c 'open("neweol", "wb").write(b"neweol\nneweol\r\n")'
  $ hg add neweol
  $ hg diff --git > noeol.diff
  $ hg revert --no-backup noeol neweol
  $ rm neweol
  $ hg --traceback --config patch.eol='auto' import -m noeol noeol.diff
  applying noeol.diff
  $ cat noeol
  noeol\r (esc)
  noeol
  $ cat neweol
  neweol
  neweol\r (esc)
  $ hg st


Test --eol and binary patches

  $ $PYTHON -c 'open("b", "wb").write(b"a\x00\nb\r\nd")'
  $ hg ci -Am addb
  adding b
  $ $PYTHON -c 'open("b", "wb").write(b"a\x00\nc\r\nd")'
  $ hg diff --git > bin.diff
  $ hg revert --no-backup b

binary patch with --eol

  $ hg import --config patch.eol='CRLF' -m changeb bin.diff
  applying bin.diff
  $ cat b
  a\x00 (esc)
  c\r (esc)
  d (no-eol)
  $ hg st
  $ cd ..
