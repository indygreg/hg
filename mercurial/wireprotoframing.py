# wireprotoframing.py - unified framing protocol for wire protocol
#
# Copyright 2018 Gregory Szorc <gregory.szorc@gmail.com>
#
# This software may be used and distributed according to the terms of the
# GNU General Public License version 2 or any later version.

# This file contains functionality to support the unified frame-based wire
# protocol. For details about the protocol, see
# `hg help internals.wireprotocol`.

from __future__ import absolute_import

import struct

from . import (
    util,
)

FRAME_HEADER_SIZE = 4
DEFAULT_MAX_FRAME_SIZE = 32768

FRAME_TYPE_COMMAND_NAME = 0x01
FRAME_TYPE_COMMAND_ARGUMENT = 0x02
FRAME_TYPE_COMMAND_DATA = 0x03

FRAME_TYPES = {
    b'command-name': FRAME_TYPE_COMMAND_NAME,
    b'command-argument': FRAME_TYPE_COMMAND_ARGUMENT,
    b'command-data': FRAME_TYPE_COMMAND_DATA,
}

FLAG_COMMAND_NAME_EOS = 0x01
FLAG_COMMAND_NAME_HAVE_ARGS = 0x02
FLAG_COMMAND_NAME_HAVE_DATA = 0x04

FLAGS_COMMAND = {
    b'eos': FLAG_COMMAND_NAME_EOS,
    b'have-args': FLAG_COMMAND_NAME_HAVE_ARGS,
    b'have-data': FLAG_COMMAND_NAME_HAVE_DATA,
}

FLAG_COMMAND_ARGUMENT_CONTINUATION = 0x01
FLAG_COMMAND_ARGUMENT_EOA = 0x02

FLAGS_COMMAND_ARGUMENT = {
    b'continuation': FLAG_COMMAND_ARGUMENT_CONTINUATION,
    b'eoa': FLAG_COMMAND_ARGUMENT_EOA,
}

FLAG_COMMAND_DATA_CONTINUATION = 0x01
FLAG_COMMAND_DATA_EOS = 0x02

FLAGS_COMMAND_DATA = {
    b'continuation': FLAG_COMMAND_DATA_CONTINUATION,
    b'eos': FLAG_COMMAND_DATA_EOS,
}

# Maps frame types to their available flags.
FRAME_TYPE_FLAGS = {
    FRAME_TYPE_COMMAND_NAME: FLAGS_COMMAND,
    FRAME_TYPE_COMMAND_ARGUMENT: FLAGS_COMMAND_ARGUMENT,
    FRAME_TYPE_COMMAND_DATA: FLAGS_COMMAND_DATA,
}

ARGUMENT_FRAME_HEADER = struct.Struct(r'<HH')

def makeframe(frametype, frameflags, payload):
    """Assemble a frame into a byte array."""
    # TODO assert size of payload.
    frame = bytearray(FRAME_HEADER_SIZE + len(payload))

    l = struct.pack(r'<I', len(payload))
    frame[0:3] = l[0:3]
    frame[3] = (frametype << 4) | frameflags
    frame[4:] = payload

    return frame

def makeframefromhumanstring(s):
    """Given a string of the form: <type> <flags> <payload>, creates a frame.

    This can be used by user-facing applications and tests for creating
    frames easily without having to type out a bunch of constants.

    Frame type and flags can be specified by integer or named constant.
    Flags can be delimited by `|` to bitwise OR them together.
    """
    frametype, frameflags, payload = s.split(b' ', 2)

    if frametype in FRAME_TYPES:
        frametype = FRAME_TYPES[frametype]
    else:
        frametype = int(frametype)

    finalflags = 0
    validflags = FRAME_TYPE_FLAGS[frametype]
    for flag in frameflags.split(b'|'):
        if flag in validflags:
            finalflags |= validflags[flag]
        else:
            finalflags |= int(flag)

    payload = util.unescapestr(payload)

    return makeframe(frametype, finalflags, payload)

def createcommandframes(cmd, args, datafh=None):
    """Create frames necessary to transmit a request to run a command.

    This is a generator of bytearrays. Each item represents a frame
    ready to be sent over the wire to a peer.
    """
    flags = 0
    if args:
        flags |= FLAG_COMMAND_NAME_HAVE_ARGS
    if datafh:
        flags |= FLAG_COMMAND_NAME_HAVE_DATA

    if not flags:
        flags |= FLAG_COMMAND_NAME_EOS

    yield makeframe(FRAME_TYPE_COMMAND_NAME, flags, cmd)

    for i, k in enumerate(sorted(args)):
        v = args[k]
        last = i == len(args) - 1

        # TODO handle splitting of argument values across frames.
        payload = bytearray(ARGUMENT_FRAME_HEADER.size + len(k) + len(v))
        offset = 0
        ARGUMENT_FRAME_HEADER.pack_into(payload, offset, len(k), len(v))
        offset += ARGUMENT_FRAME_HEADER.size
        payload[offset:offset + len(k)] = k
        offset += len(k)
        payload[offset:offset + len(v)] = v

        flags = FLAG_COMMAND_ARGUMENT_EOA if last else 0
        yield makeframe(FRAME_TYPE_COMMAND_ARGUMENT, flags, payload)

    if datafh:
        while True:
            data = datafh.read(DEFAULT_MAX_FRAME_SIZE)

            done = False
            if len(data) == DEFAULT_MAX_FRAME_SIZE:
                flags = FLAG_COMMAND_DATA_CONTINUATION
            else:
                flags = FLAG_COMMAND_DATA_EOS
                assert datafh.read(1) == b''
                done = True

            yield makeframe(FRAME_TYPE_COMMAND_DATA, flags, data)

            if done:
                break
