# Extension to write out fake unsupported records into the merge state
#
#

from __future__ import absolute_import

from mercurial import (
    merge,
    registrar,
)

cmdtable = {}
command = registrar.command(cmdtable)

@command(b'fakemergerecord',
         [(b'X', b'mandatory', None, b'add a fake mandatory record'),
          (b'x', b'advisory', None, b'add a fake advisory record')], '')
def fakemergerecord(ui, repo, *pats, **opts):
    with repo.wlock():
        ms = merge.mergestate.read(repo)
        records = ms._makerecords()
        if opts.get('mandatory'):
            records.append((b'X', b'mandatory record'))
        if opts.get('advisory'):
            records.append((b'x', b'advisory record'))
        ms._writerecords(records)
