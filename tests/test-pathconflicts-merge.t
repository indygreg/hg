
#if symlink
#else
  $ hg import -q --bypass - <<EOF
  > # HG changeset patch
  > link
  > 
  > diff --git a/a/b b/a/b
  > new file mode 120000
  > --- /dev/null
  > +++ b/a/b
  > @@ -0,0 +1,1 @@
  > +c
  > \ No newline at end of file
  > EOF
  $ hg up -q
#endif


#if symlink
#else
  $ cat a/b.old
  c (no-eol)
#endif
