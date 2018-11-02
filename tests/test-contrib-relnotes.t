#require test-repo py3exe
  $ . "$TESTDIR/helpers-testrepo.sh"

  $ cd $TESTDIR/..
  $ python3 contrib/relnotes 4.4 --stoprev 4.5
  changeset 3398603c5621: unexpected block in release notes directive feature
  New Features
  ============
  
  revert --interactive
  --------------------
  
  The revert command now accepts the flag --interactive to allow reverting only
  some of the changes to the specified files.
  
  Rebase with different destination per source revision
  -----------------------------------------------------
  
  Previously, rebase only supports one unique destination. Now "SRC" and
  "ALLSRC" can be used in rebase destination revset to precisely define
  destination per each individual source revision.
  
  For example, the following command could move some orphaned changesets to
  reasonable new places so they become no longer orphaned:
  
  hg rebase   -r 'orphan()-obsolete()'   -d 'max((successors(max(roots(ALLSRC) &
  ::SRC)^)-obsolete())::)'
  
  Accessing hidden changesets
  ---------------------------
  
  Set config option 'experimental.directaccess = True' to access hidden
  changesets from read only commands.
  
  githelp extension
  -----------------
  
  The "githelp" extension provides the "hg githelp" command. This command
  attempts to convert a "git" command to its Mercurial equivalent. The extension
  can be useful to Git users new to Mercurial.
  
  Other Changes
  -------------
  
  * When interactive revert is run against a revision other than the working
    directory parent, the diff shown is the diff to *apply* to the working
    directory, rather than the diff to *discard* from the working copy. This is
    in line with related user experiences with 'git' and appears to be less
    confusing with 'ui.interface=curses'.
  
  * Let 'hg rebase' avoid content-divergence by skipping obsolete changesets
    (and their descendants) when they are present in the rebase set along with
    one of their successors but none of their successors is in destination.
  
  * hgweb now displays phases of non-public changesets
  
  * The "HGPLAINEXCEPT" environment variable can now include "color" to allow
    automatic output colorization in otherwise automated environments.
  
  * A new unamend command in uncommit extension which undoes the effect of the
    amend command by creating a new changeset which was there before amend and
    moving the changes that were amended to the working directory.
  
  * A '--abort' flag to merge command to abort the ongoing merge.
  
  * An experimental flag '--rev' to 'hg branch' which can be used to change
    branch of changesets.
  
  Backwards Compatibility Changes
  ===============================
  
  * "log --follow-first -rREV", which is deprecated, now follows the first
    parent of merge revisions from the specified "REV" just like "log --follow
    -rREV".
  
  * "log --follow -rREV FILE.." now follows file history across copies and
    renames.
  
  Bug Fixes
  =========
  
  Issue 5165
  ----------
  
  Bookmark, whose name is longer than 255, can again be exchanged again between
  4.4+ client and servers.
  
  Performance Improvements
  ========================
  
  * bundle2 read I/O throughput significantly increased.
  
  * Significant memory use reductions when reading from bundle2 bundles.
  
    On the BSD repository, peak RSS during changegroup application decreased by
    ~185 MB from ~752 MB to ~567 MB.
  
  API Changes
  ===========
  
  * bundlerepo.bundlerepository.bundle and
    bundlerepo.bundlerepository.bundlefile are now prefixed with an underscore.
  
  * Rename bundlerepo.bundlerepository.bundlefilespos to _cgfilespos.
  
  * dirstate no longer provides a 'dirs()' method.  To test for the existence of
    a directory in the dirstate, use 'dirstate.hasdir(dirname)'.
  
  * bundle2 parts are no longer seekable by default.
  
  * mapping does not contain all template resources. use context.resource() in
    template functions.
  
  * "text=False|True" option is dropped from the vfs interface because of Python
    3 compatibility issue. Use "util.tonativeeol/fromnativeeol()" to convert EOL
    manually.
  
  * wireproto.streamres.__init__ no longer accepts a "reader" argument. Use the
    "gen" argument instead.
  
  * exchange.getbundlechunks() now returns a 2-tuple instead of just an
    iterator.
  
  
  === commands ===
   * amend: do not drop missing files (Bts:issue5732)
   * amend: do not take untracked files as modified or clean (Bts:issue5732)
   * amend: update .hgsubstate before committing a memctx (Bts:issue5677)
   * annotate: add support to specify hidden revs if directaccess config is set
   * bookmark: add methods to binary encode and decode bookmark values
   * bookmark: deprecate direct update of a bookmark value
   * bookmark: introduce a 'bookmarks' part
   * bookmark: introduce in advance a variant of the exchange test
   * bookmark: run 'pushkey' hooks after bookmark move, not 'prepushkey'
   * bookmark: use the 'bookmarks' bundle2 part to push bookmark update (Bts:issue5165)
   * bookmarks: add bookmarks to hidden revs if directaccess config is set
   * bookmarks: calculate visibility exceptions only once
   * bookmarks: display the obsfate of hidden revision we create a bookmark on
   * bookmarks: fix pushkey compatibility mode (Bts:issue5777)
   * bookmarks: use context managers for lock and transaction in update()
   * bookmarks: use context managers for locks and transaction in pushbookmark()
   * branch: add a --rev flag to change branch name of given revisions
   * branch: allow changing branch name to existing name if possible
   * clone: add support for storing remotenames while cloning
   * clone: use utility function to write hgrc
   * clonebundle: make it possible to retrieve the initial bundle through largefile
   * commands: use the new API to access hidden changesets in various commands
   * commandserver: restore cwd in case of exception
   * commandserver: unblock SIGCHLD
   * fileset: do not crash by unary negate operation
   * help: deprecate ui.slash in favor of slashpath template filter (Bts:issue5572)
   * log: allow matchfn to be non-null even if both --patch/--stat are off
   * log: build follow-log filematcher at once
   * log: don't expand aliases in revset built from command options
   * log: follow file history across copies even with -rREV (BC) (Bts:issue4959)
   * log: make "slowpath" condition slightly more readable
   * log: make opt2revset table a module constant
   * log: merge getlogrevs() and getgraphlogrevs()
   * log: remove temporary variable 'date' used only once
   * log: resolve --follow thoroughly in getlogrevs()
   * log: resolve --follow with -rREV in cmdutil.getlogrevs()
   * log: rewrite --follow-first -rREV like --follow for consistency (BC)
   * log: simplify 'x or ancestors(x)' expression
   * log: translate column labels at once (Bts:issue5750)
   * log: use revsetlang.formatspec() thoroughly
   * log: use revsetlang.formatspec() to concatenate list expression
   * log: use smartset.slice() to limit number of revisions to be displayed
   * merge: cache unknown dir checks (Bts:issue5716)
   * merge: check created file dirs for path conflicts only once (Bts:issue5716)
   * patch: add within-line color diff capacity
   * patch: catch unexpected case in _inlinediff
   * patch: do not break up multibyte character when highlighting word
   * patch: improve heuristics to not take the word "diff" as header (Bts:issue1879)
   * patch: reverse _inlinediff output for consistency
   * pull: clarify that -u only updates linearly
   * pull: hold wlock for the full operation when --update is used
   * pull: retrieve bookmarks through the binary part when possible
   * pull: store binary node in pullop.remotebookmarks
   * push: include a 'check:bookmarks' part when possible
   * push: restrict common discovery to the pushed set
   * revert: do not reverse hunks in interactive when REV is not parent (Bts:issue5096)
   * revert: support reverting to hidden cset if directaccess config is set
  
  === core ===
   * color: respect HGPLAINEXCEPT=color to allow colors while scripting (Bts:issue5749)
   * dirstate: add explicit methods for querying directories (API)
   * dispatch: abort if early boolean options can't be parsed
   * dispatch: add HGPLAIN=+strictflags to restrict early parsing of global options
   * dispatch: add option to not strip command args parsed by _earlygetopt()
   * dispatch: alias --repo to --repository while parsing early options
   * dispatch: fix early parsing of short option with value like -R=foo
   * dispatch: handle IOError when writing to stderr
   * dispatch: stop parsing of early boolean option at "--"
   * dispatch: verify result of early command parsing
   * exchange: return bundle info from getbundlechunks() (API)
   * filelog: add the ability to report the user facing name
   * localrepo: specify optional callback parameter to pathauditor as a keyword
   * revlog: choose between ifh and dfh once for all
   * revlog: don't use slicing to return parents
   * revlog: group delta computation methods under _deltacomputer object
   * revlog: group revision info into a dedicated structure
   * revlog: introduce 'deltainfo' to distinguish from 'delta'
   * revlog: rename 'rev' to 'base', as it is the base revision
   * revlog: separate diff computation from the collection of other info
   * revset: evaluate filesets against each revision for 'file()' (Bts:issue5778)
   * revset: parse x^:: as (x^):: (Bts:issue5764)
   * streamclone: add support for bundle2 based stream clone
   * streamclone: add support for cloning non append-only file
   * streamclone: also stream caches to the client
   * streamclone: define first iteration of version 2 of stream format
   * streamclone: move wire protocol status code from wireproto command
   * streamclone: rework canperformstreamclone
   * streamclone: tests phase exchange during stream clone
   * streamclone: use readexactly when reading stream v2
   * templater: fix crash by empty group expression
   * templater: keep default resources per template engine (API)
   * templater: look up symbols/resources as if they were separated (Bts:issue5699)
   * transaction: register summary callbacks only at start of transaction (BC)
   * util: whitelist NTFS for hardlink creation (Bts:issue4580)
   * vfs: drop text mode flag (API)
   * wireproto: drop support for reader interface from streamres (API)
  
  === extensions ===
   * convert: restore the ability to use bzr < 2.6.0 (Bts:issue5733)
   * histedit: add support to output nodechanges using formatter
   * largefiles: add a 'debuglfput' command to put largefile into the store
   * largefiles: add support for 'largefiles://' url scheme
   * largefiles: allow to run 'debugupgraderepo' on repo with largefiles
   * largefiles: explicitly set the source and sink types to 'hg' for lfconvert
   * largefiles: modernize how capabilities are added to the wire protocol
   * largefiles: pay attention to dropped standin files when updating largefiles
   * rebase: add concludememorynode(), and call it when rebasing in-memory
   * rebase: add the --inmemory option flag; assign a wctx object for the rebase
   * rebase: add ui.log calls for whether IMM used, whether rebasing WCP
   * rebase: disable 'inmemory' if the rebaseset contains the working copy
   * rebase: do not bail on uncomitted changes if rebasing in-memory
   * rebase: do not update if IMM; instead, set the overlaywctx's parents
   * rebase: don't run IMM if running rebase in a transaction
   * rebase: don't take out a dirstate guard for in-memory rebase
   * rebase: drop --style option
   * rebase: enable multidest by default
   * rebase: exclude descendants of obsoletes w/o a successor in dest (Bts:issue5300)
   * rebase: fix for hgsubversion
   * rebase: pass the wctx object (IMM or on-disk) to merge.update
   * rebase: pass wctx to rebasenode()
   * rebase: rerun a rebase on-disk if IMM merge conflicts arise
   * rebase: switch ui.log calls to common style
   * rebase: use fm.formatlist() and fm.formatdict() to support user template
  
  === hgweb ===
   * hgweb: disable diff.noprefix option for diffstat
   * hgweb: drop support of browsers that don't understand <canvas> (BC)
   * hgweb: only include graph-related data in jsdata variable on /graph pages (BC)
   * hgweb: stop adding strings to innerHTML of #graphnodes and #nodebgs (BC)
  
  === unsorted ===
   * archive: add support to specify hidden revs if directaccess config is set
   * atomicupdate: add an experimental option to use atomictemp when updating
   * bundle2: don't use seekable bundle2 parts by default (Bts:issue5691)
   * bundle: allow bundlerepo to support alternative manifest implementations
   * changelog: introduce a 'tiprev' method
   * changelog: use 'tiprev()' in 'tip()'
   * completion: add support for new "amend" command
   * crecord: fix revert -ir '.^' crash caused by 3649c3f2cd
   * debugssl: convert port number to int (Bts:issue5757)
   * diff: disable diff.noprefix option for diffstat (Bts:issue5759)
   * evolution: make reporting of new unstable changesets optional
   * extdata: abort if external command exits with non-zero status (BC)
   * fancyopts: add early-options parser compatible with getopt()
   * graphlog: add another graph node type, unstable, using character "*" (BC)
   * hgdemandimport: use correct hyperlink to python-bug in comments (Bts:issue5765)
   * httppeer: add support for tracing all http request made by the peer
   * identify: document -r. explicitly how to disable wdir scanning (Bts:issue5622)
   * lfs: register config options
   * match: do not weirdly include explicit files excluded by -X option
   * memfilectx: make changectx argument mandatory in constructor (API)
   * morestatus: don't crash with different drive letters for repo.root and CWD
   * outgoing: respect ":pushurl" paths (Bts:issue5365)
   * remove: print message for each file in verbose mode only while using '-A' (BC)
   * rewriteutil: use precheck() in uncommit and amend commands
   * scmutil: don't try to delete origbackup symlinks to directories (Bts:issue5731)
   * sshpeer: add support for request tracing
   * subrepo: add config option to reject any subrepo operations (SEC)
   * subrepo: disable git and svn subrepos by default (BC) (SEC)
   * subrepo: extend config option to disable subrepos by type (SEC)
   * subrepo: handle 'C:' style paths on the command line (Bts:issue5770)
   * subrepo: use per-type config options to enable subrepos
   * svnsubrepo: check if subrepo is missing when checking dirty state (Bts:issue5657)
   * test-bookmarks-pushpull: stabilize for Windows
   * test-run-tests: stabilize the test (Bts:issue5735)
   * tr-summary: keep a weakref to the unfiltered repository
   * unamend: fix command summary line
   * uncommit: unify functions _uncommitdirstate and _unamenddirstate to one
   * update: fix crash on bare update when directaccess is enabled
   * update: support updating to hidden cset if directaccess config is set
  
  === Behavior Changes ===
  
   * extdata: abort if external command exits with non-zero status (BC)
   * graphlog: add another graph node type, unstable, using character "*" (BC)
   * hgweb: drop support of browsers that don't understand <canvas> (BC)
   * hgweb: only include graph-related data in jsdata variable on /graph pages (BC)
   * hgweb: stop adding strings to innerHTML of #graphnodes and #nodebgs (BC)
   * log: follow file history across copies even with -rREV (BC) (Bts:issue4959)
   * log: rewrite --follow-first -rREV like --follow for consistency (BC)
   * remove: print message for each file in verbose mode only while using '-A' (BC)
   * subrepo: disable git and svn subrepos by default (BC) (SEC)
   * transaction: register summary callbacks only at start of transaction (BC)
  
  === Internal API Changes ===
  
   * dirstate: add explicit methods for querying directories (API)
   * exchange: return bundle info from getbundlechunks() (API)
   * memfilectx: make changectx argument mandatory in constructor (API)
   * templater: keep default resources per template engine (API)
   * vfs: drop text mode flag (API)
   * wireproto: drop support for reader interface from streamres (API)
