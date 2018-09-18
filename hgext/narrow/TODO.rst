Integration with the share extension needs improvement. Right now
we've seen some odd bugs, and the way we modify the contents of the
.hg/shared file is unfortunate. See wrappostshare() and unsharenarrowspec().

Resolve commentary on narrowrepo.wraprepo.narrowrepository.status
about the filtering of status being done at an awkward layer. This
came up the import to hgext, but nobody's got concrete improvement
ideas as of then.

Address commentary in manifest.excludedmanifestrevlog.add -
specifically we should improve the collaboration with core so that
add() never gets called on an excluded directory and we can improve
the stand-in to raise a ProgrammingError.

Reason more completely about rename-filtering logic in
narrowfilelog. There could be some surprises lurking there.

Formally document the narrowspec format. Unify with sparse, if at all
possible. For bonus points, unify with the server-specified narrowspec
format.

narrowrepo.setnarrowpats() or narrowspec.save() need to make sure
they're holding the wlock.
