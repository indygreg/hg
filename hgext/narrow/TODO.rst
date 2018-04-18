Integration with the share extension needs improvement. Right now
we've seen some odd bugs, and the way we modify the contents of the
.hg/shared file is unfortunate. See wrappostshare() and unsharenarrowspec().

Resolve commentary on narrowrepo.wraprepo.narrowrepository.status
about the filtering of status being done at an awkward layer. This
came up the import to hgext, but nobody's got concrete improvement
ideas as of then.

Fold most (or preferably all) of narrowrevlog.py into core.

Address commentary in narrowrevlog.excludedmanifestrevlog.add -
specifically we should improve the collaboration with core so that
add() never gets called on an excluded directory and we can improve
the stand-in to raise a ProgrammingError.

Figure out how to correctly produce narrowmanifestrevlog and
narrowfilelog instances instead of monkeypatching regular revlogs at
runtime to our subclass. Even better, merge the narrowing logic
directly into core.

Reason more completely about rename-filtering logic in
narrowfilelog. There could be some surprises lurking there.

Formally document the narrowspec format. Unify with sparse, if at all
possible. For bonus points, unify with the server-specified narrowspec
format.

narrowrepo.setnarrowpats() or narrowspec.save() need to make sure
they're holding the wlock.

Implement a simple version of the expandnarrow wireproto command for
core. Having configurable shorthands for narrowspecs has been useful
at Google (and sparse has a similar feature from Facebook), so it
probably makes sense to implement the feature in core. (Google's
handler is entirely custom to Google, with a custom format related to
bazel's build language, so it's not in the narrowhg distribution.)
