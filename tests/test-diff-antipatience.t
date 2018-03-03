#testcases bdiff xdiff

#if xdiff
#require xdiff
  $ cat >> $HGRCPATH <<EOF
  > [experimental]
  > xdiff = true
  > EOF
#endif

Test case that makes use of the weakness of patience diff algorithm

  $ hg init
  >>> open('a', 'wb').write(b'\n'.join(list(b'a' + b'x' * 10 + b'u' + b'x' * 30 + b'a\n')))
  $ hg commit -m 1 -A a
  >>> open('a', 'wb').write(b'\n'.join(list(b'b' + b'x' * 30 + b'u' + b'x' * 10 + b'b\n')))
#if xdiff
  $ hg diff
  diff -r f0aeecb49805 a
  --- a/a	Thu Jan 01 00:00:00 1970 +0000
  +++ b/a	Thu Jan 01 00:00:00 1970 +0000
  @@ -1,4 +1,4 @@
  -a
  +b
   x
   x
   x
  @@ -9,7 +9,6 @@
   x
   x
   x
  -u
   x
   x
   x
  @@ -30,6 +29,7 @@
   x
   x
   x
  +u
   x
   x
   x
  @@ -40,5 +40,5 @@
   x
   x
   x
  -a
  +b
   
#else
  $ hg diff
  diff -r f0aeecb49805 a
  --- a/a	Thu Jan 01 00:00:00 1970 +0000
  +++ b/a	Thu Jan 01 00:00:00 1970 +0000
  @@ -1,15 +1,4 @@
  -a
  -x
  -x
  -x
  -x
  -x
  -x
  -x
  -x
  -x
  -x
  -u
  +b
   x
   x
   x
  @@ -40,5 +29,16 @@
   x
   x
   x
  -a
  +u
  +x
  +x
  +x
  +x
  +x
  +x
  +x
  +x
  +x
  +x
  +b
   
#endif
