# Copyright 2018 Gregory Szorc <gregory.szorc@gmail.com>
#
# This software may be used and distributed according to the terms of the
# GNU General Public License version 2 or any later version.

from __future__ import absolute_import

class ooberror(object):
    """wireproto reply: failure of a batch of operation

    Something failed during a batch call. The error message is stored in
    `self.message`.
    """
    def __init__(self, message):
        self.message = message

class pushres(object):
    """wireproto reply: success with simple integer return

    The call was successful and returned an integer contained in `self.res`.
    """
    def __init__(self, res, output):
        self.res = res
        self.output = output

class pusherr(object):
    """wireproto reply: failure

    The call failed. The `self.res` attribute contains the error message.
    """
    def __init__(self, res, output):
        self.res = res
        self.output = output

class streamres(object):
    """wireproto reply: binary stream

    The call was successful and the result is a stream.

    Accepts a generator containing chunks of data to be sent to the client.

    ``prefer_uncompressed`` indicates that the data is expected to be
    uncompressable and that the stream should therefore use the ``none``
    engine.
    """
    def __init__(self, gen=None, prefer_uncompressed=False):
        self.gen = gen
        self.prefer_uncompressed = prefer_uncompressed

class streamreslegacy(object):
    """wireproto reply: uncompressed binary stream

    The call was successful and the result is a stream.

    Accepts a generator containing chunks of data to be sent to the client.

    Like ``streamres``, but sends an uncompressed data for "version 1" clients
    using the application/mercurial-0.1 media type.
    """
    def __init__(self, gen=None):
        self.gen = gen
