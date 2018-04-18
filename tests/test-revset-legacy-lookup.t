
  $ cat >> $HGRCPATH << EOF
  > [ui]
  > logtemplate="{rev}:{node|short} {desc} [{tags}]\n"
  > EOF

  $ hg init legacy-lookup
  $ cd legacy-lookup
  $ echo a > a
  $ hg add a
  $ hg commit -m 'first'
  $ echo aa > a
  $ hg commit -m 'second'
  $ hg log -G
  @  1:43114e71eddd second [tip]
  |
  o  0:a87874c6ec31 first []
  

Create a tag that looks like a revset

  $ hg tag 'rev(0)'
  $ hg log -G
  @  2:fb616635b18f Added tag rev(0) for changeset 43114e71eddd [tip]
  |
  o  1:43114e71eddd second [rev(0)]
  |
  o  0:a87874c6ec31 first []
  

See how various things are resolved
-----------------------------------

Revision numbers

  $ hg log -r '0'
  0:a87874c6ec31 first []
  $ hg log -r '1'
  1:43114e71eddd second [rev(0)]

"rev(x)" form (the one conflicting with the tags)
(resolved as a label)

  $ hg log -r 'rev(0)'
  1:43114e71eddd second [rev(0)]
  $ hg log -r 'rev(1)'
  1:43114e71eddd second [rev(0)]

same within a simple revspec
(still resolved as the label)

  $ hg log -r ':rev(0)'
  0:a87874c6ec31 first []
  1:43114e71eddd second [rev(0)]
  $ hg log -r 'rev(0):'
  1:43114e71eddd second [rev(0)]
  2:fb616635b18f Added tag rev(0) for changeset 43114e71eddd [tip]

within a more advances revset
(still resolved as the label)

  $ hg log -r 'rev(0) and branch(default)'
  0:a87874c6ec31 first []

with explicit revset resolution
(still resolved as the label)

  $ hg log -r 'revset(rev(0))'
  0:a87874c6ec31 first []

some of the above with quote to force its resolution as a label

  $ hg log -r ':"rev(0)"'
  0:a87874c6ec31 first []
  1:43114e71eddd second [rev(0)]
  $ hg log -r '"rev(0)":'
  1:43114e71eddd second [rev(0)]
  2:fb616635b18f Added tag rev(0) for changeset 43114e71eddd [tip]
  $ hg log -r '"rev(0)" and branch(default)'
  1:43114e71eddd second [rev(0)]

confusing bits within parents

  $ hg log -r '(rev(0))'
  0:a87874c6ec31 first []
  $ hg log -r '( rev(0))'
  0:a87874c6ec31 first []
  $ hg log -r '("rev(0)")'
  1:43114e71eddd second [rev(0)]

Test label with quote in them.

  $ hg tag '"foo"'

  $ hg log -r '"foo"'
  2:fb616635b18f Added tag rev(0) for changeset 43114e71eddd ["foo"]
  $ hg log -r '("foo")'
  abort: unknown revision 'foo'!
  [255]
  $ hg log -r 'revset("foo")'
  abort: unknown revision 'foo'!
  [255]
  $ hg log -r '("\"foo\"")'
  2:fb616635b18f Added tag rev(0) for changeset 43114e71eddd ["foo"]
  $ hg log -r 'revset("\"foo\"")'
  2:fb616635b18f Added tag rev(0) for changeset 43114e71eddd ["foo"]

Test label with dash in them.

  $ hg tag 'foo-bar'

  $ hg log -r 'foo-bar'
  3:a50aae922707 Added tag "foo" for changeset fb616635b18f [foo-bar]
  $ hg log -r '(foo-bar)'
  3:a50aae922707 Added tag "foo" for changeset fb616635b18f [foo-bar]
  $ hg log -r '"foo-bar"'
  3:a50aae922707 Added tag "foo" for changeset fb616635b18f [foo-bar]
  $ hg log -r '("foo-bar")'
  3:a50aae922707 Added tag "foo" for changeset fb616635b18f [foo-bar]

Test label with + in them.

  $ hg tag 'foo+bar'

  $ hg log -r 'foo+bar'
  4:bbf52b87b370 Added tag foo-bar for changeset a50aae922707 [foo+bar]
  $ hg log -r '(foo+bar)'
  abort: unknown revision 'foo'!
  [255]
  $ hg log -r 'revset(foo+bar)'
  abort: unknown revision 'foo'!
  [255]
  $ hg log -r '"foo+bar"'
  4:bbf52b87b370 Added tag foo-bar for changeset a50aae922707 [foo+bar]
  $ hg log -r '("foo+bar")'
  4:bbf52b87b370 Added tag foo-bar for changeset a50aae922707 [foo+bar]

Test tag with numeric version number.

  $ hg tag '1.2'

  $ hg log -r '1.2'
  5:ff42fde8edbb Added tag foo+bar for changeset bbf52b87b370 [1.2]
  $ hg log -r '(1.2)'
  5:ff42fde8edbb Added tag foo+bar for changeset bbf52b87b370 [1.2]
  $ hg log -r 'revset(1.2)'
  5:ff42fde8edbb Added tag foo+bar for changeset bbf52b87b370 [1.2]
  $ hg log -r '"1.2"'
  5:ff42fde8edbb Added tag foo+bar for changeset bbf52b87b370 [1.2]
  $ hg log -r '("1.2")'
  5:ff42fde8edbb Added tag foo+bar for changeset bbf52b87b370 [1.2]
  $ hg log -r '::"1.2"'
  0:a87874c6ec31 first []
  1:43114e71eddd second [rev(0)]
  2:fb616635b18f Added tag rev(0) for changeset 43114e71eddd ["foo"]
  3:a50aae922707 Added tag "foo" for changeset fb616635b18f [foo-bar]
  4:bbf52b87b370 Added tag foo-bar for changeset a50aae922707 [foo+bar]
  5:ff42fde8edbb Added tag foo+bar for changeset bbf52b87b370 [1.2]
  $ hg log -r '::1.2'
  0:a87874c6ec31 first []
  1:43114e71eddd second [rev(0)]
  2:fb616635b18f Added tag rev(0) for changeset 43114e71eddd ["foo"]
  3:a50aae922707 Added tag "foo" for changeset fb616635b18f [foo-bar]
  4:bbf52b87b370 Added tag foo-bar for changeset a50aae922707 [foo+bar]
  5:ff42fde8edbb Added tag foo+bar for changeset bbf52b87b370 [1.2]

Test tag with parenthesis (but not a valid revset)

  $ hg tag 'release_4.1(candidate1)'

  $ hg log -r 'release_4.1(candidate1)'
  6:db72e24fe069 Added tag 1.2 for changeset ff42fde8edbb [release_4.1(candidate1)]
  $ hg log -r '(release_4.1(candidate1))'
  hg: parse error: unknown identifier: release_4.1
  [255]
  $ hg log -r 'revset(release_4.1(candidate1))'
  hg: parse error: unknown identifier: release_4.1
  [255]
  $ hg log -r '"release_4.1(candidate1)"'
  6:db72e24fe069 Added tag 1.2 for changeset ff42fde8edbb [release_4.1(candidate1)]
  $ hg log -r '("release_4.1(candidate1)")'
  6:db72e24fe069 Added tag 1.2 for changeset ff42fde8edbb [release_4.1(candidate1)]
  $ hg log -r '::"release_4.1(candidate1)"'
  0:a87874c6ec31 first []
  1:43114e71eddd second [rev(0)]
  2:fb616635b18f Added tag rev(0) for changeset 43114e71eddd ["foo"]
  3:a50aae922707 Added tag "foo" for changeset fb616635b18f [foo-bar]
  4:bbf52b87b370 Added tag foo-bar for changeset a50aae922707 [foo+bar]
  5:ff42fde8edbb Added tag foo+bar for changeset bbf52b87b370 [1.2]
  6:db72e24fe069 Added tag 1.2 for changeset ff42fde8edbb [release_4.1(candidate1)]
  $ hg log -r '::release_4.1(candidate1)'
  hg: parse error: unknown identifier: release_4.1
  [255]

Test tag with parenthesis and other function like char

  $ hg tag 'release_4.1(arch=x86,arm)'

  $ hg log -r 'release_4.1(arch=x86,arm)'
  7:b29b25d7d687 Added tag release_4.1(candidate1) for changeset db72e24fe069 [release_4.1(arch=x86,arm)]
  $ hg log -r '(release_4.1(arch=x86,arm))'
  hg: parse error: unknown identifier: release_4.1
  [255]
  $ hg log -r 'revset(release_4.1(arch=x86,arm))'
  hg: parse error: unknown identifier: release_4.1
  [255]
  $ hg log -r '"release_4.1(arch=x86,arm)"'
  7:b29b25d7d687 Added tag release_4.1(candidate1) for changeset db72e24fe069 [release_4.1(arch=x86,arm)]
  $ hg log -r '("release_4.1(arch=x86,arm)")'
  7:b29b25d7d687 Added tag release_4.1(candidate1) for changeset db72e24fe069 [release_4.1(arch=x86,arm)]
  $ hg log -r '::"release_4.1(arch=x86,arm)"'
  0:a87874c6ec31 first []
  1:43114e71eddd second [rev(0)]
  2:fb616635b18f Added tag rev(0) for changeset 43114e71eddd ["foo"]
  3:a50aae922707 Added tag "foo" for changeset fb616635b18f [foo-bar]
  4:bbf52b87b370 Added tag foo-bar for changeset a50aae922707 [foo+bar]
  5:ff42fde8edbb Added tag foo+bar for changeset bbf52b87b370 [1.2]
  6:db72e24fe069 Added tag 1.2 for changeset ff42fde8edbb [release_4.1(candidate1)]
  7:b29b25d7d687 Added tag release_4.1(candidate1) for changeset db72e24fe069 [release_4.1(arch=x86,arm)]
  $ hg log -r '::release_4.1(arch=x86,arm)'
  hg: parse error: unknown identifier: release_4.1
  [255]

Test tag conflicting with revset function

  $ hg tag 'secret(team=foo,project=bar)'

  $ hg log -r 'secret(team=foo,project=bar)'
  8:6b2e2d4ea455 Added tag release_4.1(arch=x86,arm) for changeset b29b25d7d687 [secret(team=foo,project=bar)]
  $ hg log -r '(secret(team=foo,project=bar))'
  hg: parse error: secret takes no arguments
  [255]
  $ hg log -r 'revset(secret(team=foo,project=bar))'
  hg: parse error: secret takes no arguments
  [255]
  $ hg log -r '"secret(team=foo,project=bar)"'
  8:6b2e2d4ea455 Added tag release_4.1(arch=x86,arm) for changeset b29b25d7d687 [secret(team=foo,project=bar)]
  $ hg log -r '("secret(team=foo,project=bar)")'
  8:6b2e2d4ea455 Added tag release_4.1(arch=x86,arm) for changeset b29b25d7d687 [secret(team=foo,project=bar)]
  $ hg log -r '::"secret(team=foo,project=bar)"'
  0:a87874c6ec31 first []
  1:43114e71eddd second [rev(0)]
  2:fb616635b18f Added tag rev(0) for changeset 43114e71eddd ["foo"]
  3:a50aae922707 Added tag "foo" for changeset fb616635b18f [foo-bar]
  4:bbf52b87b370 Added tag foo-bar for changeset a50aae922707 [foo+bar]
  5:ff42fde8edbb Added tag foo+bar for changeset bbf52b87b370 [1.2]
  6:db72e24fe069 Added tag 1.2 for changeset ff42fde8edbb [release_4.1(candidate1)]
  7:b29b25d7d687 Added tag release_4.1(candidate1) for changeset db72e24fe069 [release_4.1(arch=x86,arm)]
  8:6b2e2d4ea455 Added tag release_4.1(arch=x86,arm) for changeset b29b25d7d687 [secret(team=foo,project=bar)]
  $ hg log -r '::secret(team=foo,project=bar)'
  hg: parse error: secret takes no arguments
  [255]

Test tag with space

  $ hg tag 'my little version'

  $ hg log -r 'my little version'
  9:269192bf8fc3 Added tag secret(team=foo,project=bar) for changeset 6b2e2d4ea455 [my little version]
  $ hg log -r '(my little version)'
  hg: parse error at 4: unexpected token: symbol
  ((my little version)
       ^ here)
  [255]
  $ hg log -r 'revset(my little version)'
  hg: parse error at 10: unexpected token: symbol
  (revset(my little version)
             ^ here)
  [255]
  $ hg log -r '"my little version"'
  9:269192bf8fc3 Added tag secret(team=foo,project=bar) for changeset 6b2e2d4ea455 [my little version]
  $ hg log -r '("my little version")'
  9:269192bf8fc3 Added tag secret(team=foo,project=bar) for changeset 6b2e2d4ea455 [my little version]
  $ hg log -r '::"my little version"'
  0:a87874c6ec31 first []
  1:43114e71eddd second [rev(0)]
  2:fb616635b18f Added tag rev(0) for changeset 43114e71eddd ["foo"]
  3:a50aae922707 Added tag "foo" for changeset fb616635b18f [foo-bar]
  4:bbf52b87b370 Added tag foo-bar for changeset a50aae922707 [foo+bar]
  5:ff42fde8edbb Added tag foo+bar for changeset bbf52b87b370 [1.2]
  6:db72e24fe069 Added tag 1.2 for changeset ff42fde8edbb [release_4.1(candidate1)]
  7:b29b25d7d687 Added tag release_4.1(candidate1) for changeset db72e24fe069 [release_4.1(arch=x86,arm)]
  8:6b2e2d4ea455 Added tag release_4.1(arch=x86,arm) for changeset b29b25d7d687 [secret(team=foo,project=bar)]
  9:269192bf8fc3 Added tag secret(team=foo,project=bar) for changeset 6b2e2d4ea455 [my little version]
  $ hg log -r '::my little version'
  hg: parse error at 5: invalid token
  (::my little version
        ^ here)
  [255]
