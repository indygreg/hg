# showstack.py - extension to dump a Python stack trace on signal
#
# binds to both SIGQUIT (Ctrl-\) and SIGINFO (Ctrl-T on BSDs)
"""dump stack trace when receiving SIGQUIT (Ctrl-\) and SIGINFO (Ctrl-T on BSDs)
"""

from __future__ import absolute_import, print_function
import signal
import sys
import traceback

def sigshow(*args):
    sys.stderr.write("\n")
    traceback.print_stack(args[1], limit=10, file=sys.stderr)
    sys.stderr.write("----\n")

def sigexit(*args):
    sigshow(*args)
    print('alarm!')
    sys.exit(1)

def extsetup(ui):
    signal.signal(signal.SIGQUIT, sigshow)
    signal.signal(signal.SIGALRM, sigexit)
    try:
        signal.signal(signal.SIGINFO, sigshow)
    except AttributeError:
        pass
