# Copyright 2018 Gregory Szorc <gregory.szorc@gmail.com>
#
# This software may be used and distributed according to the terms of the
# GNU General Public License version 2 or any later version.

from __future__ import absolute_import

import abc

# Names of the SSH protocol implementations.
SSHV1 = 'ssh-v1'
# These are advertised over the wire. Increment the counters at the end
# to reflect BC breakages.
SSHV2 = 'exp-ssh-v2-0001'
HTTPV2 = 'exp-http-v2-0001'

# All available wire protocol transports.
TRANSPORTS = {
    SSHV1: {
        'transport': 'ssh',
        'version': 1,
    },
    SSHV2: {
        'transport': 'ssh',
        'version': 2,
    },
    'http-v1': {
        'transport': 'http',
        'version': 1,
    },
    HTTPV2: {
        'transport': 'http',
        'version': 2,
    }
}

class bytesresponse(object):
    """A wire protocol response consisting of raw bytes."""
    def __init__(self, data):
        self.data = data

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

class baseprotocolhandler(object):
    """Abstract base class for wire protocol handlers.

    A wire protocol handler serves as an interface between protocol command
    handlers and the wire protocol transport layer. Protocol handlers provide
    methods to read command arguments, redirect stdio for the duration of
    the request, handle response types, etc.
    """

    __metaclass__ = abc.ABCMeta

    @abc.abstractproperty
    def name(self):
        """The name of the protocol implementation.

        Used for uniquely identifying the transport type.
        """

    @abc.abstractmethod
    def getargs(self, args):
        """return the value for arguments in <args>

        returns a list of values (same order as <args>)"""

    @abc.abstractmethod
    def forwardpayload(self, fp):
        """Read the raw payload and forward to a file.

        The payload is read in full before the function returns.
        """

    @abc.abstractmethod
    def mayberedirectstdio(self):
        """Context manager to possibly redirect stdio.

        The context manager yields a file-object like object that receives
        stdout and stderr output when the context manager is active. Or it
        yields ``None`` if no I/O redirection occurs.

        The intent of this context manager is to capture stdio output
        so it may be sent in the response. Some transports support streaming
        stdio to the client in real time. For these transports, stdio output
        won't be captured.
        """

    @abc.abstractmethod
    def client(self):
        """Returns a string representation of this client (as bytes)."""

    @abc.abstractmethod
    def addcapabilities(self, repo, caps):
        """Adds advertised capabilities specific to this protocol.

        Receives the list of capabilities collected so far.

        Returns a list of capabilities. The passed in argument can be returned.
        """

    @abc.abstractmethod
    def checkperm(self, perm):
        """Validate that the client has permissions to perform a request.

        The argument is the permission required to proceed. If the client
        doesn't have that permission, the exception should raise or abort
        in a protocol specific manner.
        """
