# logtoprocess.py - send ui.log() data to a subprocess
#
# Copyright 2016 Facebook, Inc.
#
# This software may be used and distributed according to the terms of the
# GNU General Public License version 2 or any later version.
"""send ui.log() data to a subprocess (EXPERIMENTAL)

This extension lets you specify a shell command per ui.log() event,
sending all remaining arguments to as environment variables to that command.

Each positional argument to the method results in a `MSG[N]` key in the
environment, starting at 1 (so `MSG1`, `MSG2`, etc.). Each keyword argument
is set as a `OPT_UPPERCASE_KEY` variable (so the key is uppercased, and
prefixed with `OPT_`). The original event name is passed in the `EVENT`
environment variable, and the process ID of mercurial is given in `HGPID`.

So given a call `ui.log('foo', 'bar', 'baz', spam='eggs'), a script configured
for the `foo` event can expect an environment with `MSG1=bar`, `MSG2=baz`, and
`OPT_SPAM=eggs`.

Scripts are configured in the `[logtoprocess]` section, each key an event name.
For example::

  [logtoprocess]
  commandexception = echo "$MSG2$MSG3" > /var/log/mercurial_exceptions.log

would log the warning message and traceback of any failed command dispatch.

Scripts are run asynchronously as detached daemon processes; mercurial will
not ensure that they exit cleanly.

"""

from __future__ import absolute_import

import os

from mercurial import (
    pycompat,
)
from mercurial.utils import (
    procutil,
)

# Note for extension authors: ONLY specify testedwith = 'ships-with-hg-core' for
# extensions which SHIP WITH MERCURIAL. Non-mainline extensions should
# be specifying the version(s) of Mercurial they are tested with, or
# leave the attribute unspecified.
testedwith = 'ships-with-hg-core'

def uisetup(ui):

    class logtoprocessui(ui.__class__):
        def log(self, event, *msg, **opts):
            """Map log events to external commands

            Arguments are passed on as environment variables.

            """
            script = self.config('logtoprocess', event)
            if script:
                if msg:
                    # try to format the log message given the remaining
                    # arguments
                    try:
                        # Format the message as blackbox does
                        formatted = msg[0] % msg[1:]
                    except (TypeError, KeyError):
                        # Failed to apply the arguments, ignore
                        formatted = msg[0]
                    messages = (formatted,) + msg[1:]
                else:
                    messages = msg
                env = {
                    b'EVENT': event,
                    b'HGPID': os.getpid(),
                }
                # positional arguments are listed as MSG[N] keys in the
                # environment
                env.update((b'MSG%d' % i, m) for i, m in enumerate(messages, 1))
                # keyword arguments get prefixed with OPT_ and uppercased
                env.update((b'OPT_%s' % key.upper(), value)
                           for key, value in pycompat.byteskwargs(opts).items())
                fullenv = procutil.shellenviron(env)
                procutil.runbgcommand(script, fullenv, shell=True)
            return super(logtoprocessui, self).log(event, *msg, **opts)

    # Replace the class for this instance and all clones created from it:
    ui.__class__ = logtoprocessui
