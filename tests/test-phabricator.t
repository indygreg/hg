#require vcr
  $ cat >> $HGRCPATH <<EOF
  > [extensions]
  > phabricator = 
  > EOF
  $ hg init repo
  $ cd repo
  $ cat >> .hg/hgrc <<EOF
  > [phabricator]
  > url = https://phab.mercurial-scm.org/
  > callsign = HG
  > 
  > [auth]
  > hgphab.schemes = https
  > hgphab.prefix = phab.mercurial-scm.org
  > # When working on the extension and making phabricator interaction
  > # changes, edit this to be a real phabricator token. When done, edit
  > # it back, and make sure to also edit your VCR transcripts to match
  > # whatever value you put here.
  > hgphab.phabtoken = cli-hahayouwish
  > EOF
  $ VCR="$TESTDIR/phabricator"

Error is handled reasonably. We override the phabtoken here so that
when you're developing changes to phabricator.py you can edit the
above config and have a real token in the test but not have to edit
this test.
  $ hg phabread --config auth.hgphab.phabtoken=cli-notavalidtoken \
  >  --test-vcr "$VCR/phabread-conduit-error.json" D4480 | head
  abort: Conduit Error (ERR-INVALID-AUTH): API token "cli-notavalidtoken" has the wrong length. API tokens should be 32 characters long.

Basic phabread:
  $ hg phabread --test-vcr "$VCR/phabread-4480.json" D4480 | head
  # HG changeset patch
  exchangev2: start to implement pull with wire protocol v2
  
  Wire protocol version 2 will take a substantially different
  approach to exchange than version 1 (at least as far as pulling
  is concerned).
  
  This commit establishes a new exchangev2 module for holding
  code related to exchange using wire protocol v2. I could have
  added things to the existing exchange module. But it is already

phabupdate with an accept:
  $ hg phabupdate --accept D4564 \
  > -m 'I think I like where this is headed. Will read rest of series later.'\
  >  --test-vcr "$VCR/accept-4564.json"

Create a differential diff:
  $ echo alpha > alpha
  $ hg ci --addremove -m 'create alpha for phabricator test'
  adding alpha
  $ hg phabsend -r . --test-vcr "$VCR/phabsend-create-alpha.json"
  D4596 - created - 5206a4fa1e6c: create alpha for phabricator test
  saved backup bundle to $TESTTMP/repo/.hg/strip-backup/5206a4fa1e6c-dec9e777-phabsend.hg
  $ echo more >> alpha
  $ HGEDITOR=true hg ci --amend
  saved backup bundle to $TESTTMP/repo/.hg/strip-backup/d8f232f7d799-c573510a-amend.hg
  $ echo beta > beta
  $ hg ci --addremove -m 'create beta for phabricator test'
  adding beta
  $ hg phabsend -r ".^::" --test-vcr "$VCR/phabsend-update-alpha-create-beta.json"
  D4596 - updated - f70265671c65: create alpha for phabricator test
  D4597 - created - 1a5640df7bbf: create beta for phabricator test
  saved backup bundle to $TESTTMP/repo/.hg/strip-backup/1a5640df7bbf-6daf3e6e-phabsend.hg

Template keywords
  $ hg log -T'{rev} {phabreview|json}\n'
  1 {"id": "D4597", "url": "https://phab.mercurial-scm.org/D4597"}
  0 {"id": "D4596", "url": "https://phab.mercurial-scm.org/D4596"}

  $ hg log -T'{rev} {phabreview.url} {phabreview.id}\n'
  1 https://phab.mercurial-scm.org/D4597 D4597
  0 https://phab.mercurial-scm.org/D4596 D4596

  $ cd ..
