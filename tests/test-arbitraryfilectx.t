#if symlink
#else
  $ hg import -q --bypass - <<EOF
  > # HG changeset patch
  > # User test
  > # Date 0 0
  > base
  > 
  > diff --git a/A b/A
  > new file mode 100644
  > --- /dev/null
  > +++ b/A
  > @@ -0,0 +1,1 @@
  > +foo
  > \ No newline at end of file
  > diff --git a/B b/B
  > new file mode 100644
  > --- /dev/null
  > +++ b/B
  > @@ -0,0 +1,1 @@
  > +foo
  > \ No newline at end of file
  > diff --git a/real_A b/real_A
  > new file mode 100644
  > --- /dev/null
  > +++ b/real_A
  > @@ -0,0 +1,1 @@
  > +A
  > \ No newline at end of file
  > diff --git a/sym_A b/sym_A
  > new file mode 120000
  > --- /dev/null
  > +++ b/sym_A
  > @@ -0,0 +1,1 @@
  > +A
  > \ No newline at end of file
  > EOF
  $ hg up -q
#endif
#if symlink
#else
  $ hg eval "not filecmp.cmp('real_A', 'sym_A')"
  False (no-eol)
#endif