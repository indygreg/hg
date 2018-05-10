from __future__ import absolute_import, print_function

import os
from mercurial import (
    dispatch,
    ui as uimod,
)
from mercurial.utils import (
    stringutil,
)

# ensure errors aren't buffered
testui = uimod.ui()
testui.pushbuffer()
testui.write((b'buffered\n'))
testui.warn((b'warning\n'))
testui.write_err(b'error\n')
print(stringutil.pprint(testui.popbuffer(), bprefix=True).decode('ascii'))

# test dispatch.dispatch with the same ui object
hgrc = open(os.environ["HGRCPATH"], 'wb')
hgrc.write(b'[extensions]\n')
hgrc.write(b'color=\n')
hgrc.close()

ui_ = uimod.ui.load()
ui_.setconfig(b'ui', b'formatted', b'True')

# we're not interested in the output, so write that to devnull
ui_.fout = open(os.devnull, 'wb')

# call some arbitrary command just so we go through
# color's wrapped _runcommand twice.
def runcmd():
    dispatch.dispatch(dispatch.request([b'version', b'-q'], ui_))

runcmd()
print("colored? %s" % (ui_._colormode is not None))
runcmd()
print("colored? %s" % (ui_._colormode is not None))
