# cborutil.py - CBOR extensions
#
# Copyright 2018 Gregory Szorc <gregory.szorc@gmail.com>
#
# This software may be used and distributed according to the terms of the
# GNU General Public License version 2 or any later version.

from __future__ import absolute_import

import struct

from ..thirdparty.cbor.cbor2 import (
    decoder as decodermod,
)

# Very short very of RFC 7049...
#
# Each item begins with a byte. The 3 high bits of that byte denote the
# "major type." The lower 5 bits denote the "subtype." Each major type
# has its own encoding mechanism.
#
# Most types have lengths. However, bytestring, string, array, and map
# can be indefinite length. These are denotes by a subtype with value 31.
# Sub-components of those types then come afterwards and are terminated
# by a "break" byte.

MAJOR_TYPE_UINT = 0
MAJOR_TYPE_NEGINT = 1
MAJOR_TYPE_BYTESTRING = 2
MAJOR_TYPE_STRING = 3
MAJOR_TYPE_ARRAY = 4
MAJOR_TYPE_MAP = 5
MAJOR_TYPE_SEMANTIC = 6
MAJOR_TYPE_SPECIAL = 7

SUBTYPE_MASK = 0b00011111

SUBTYPE_HALF_FLOAT = 25
SUBTYPE_SINGLE_FLOAT = 26
SUBTYPE_DOUBLE_FLOAT = 27
SUBTYPE_INDEFINITE = 31

# Indefinite types begin with their major type ORd with information value 31.
BEGIN_INDEFINITE_BYTESTRING = struct.pack(
    r'>B', MAJOR_TYPE_BYTESTRING << 5 | SUBTYPE_INDEFINITE)
BEGIN_INDEFINITE_ARRAY = struct.pack(
    r'>B', MAJOR_TYPE_ARRAY << 5 | SUBTYPE_INDEFINITE)
BEGIN_INDEFINITE_MAP = struct.pack(
    r'>B', MAJOR_TYPE_MAP << 5 | SUBTYPE_INDEFINITE)

ENCODED_LENGTH_1 = struct.Struct(r'>B')
ENCODED_LENGTH_2 = struct.Struct(r'>BB')
ENCODED_LENGTH_3 = struct.Struct(r'>BH')
ENCODED_LENGTH_4 = struct.Struct(r'>BL')
ENCODED_LENGTH_5 = struct.Struct(r'>BQ')

# The break ends an indefinite length item.
BREAK = b'\xff'
BREAK_INT = 255

def encodelength(majortype, length):
    """Obtain a value encoding the major type and its length."""
    if length < 24:
        return ENCODED_LENGTH_1.pack(majortype << 5 | length)
    elif length < 256:
        return ENCODED_LENGTH_2.pack(majortype << 5 | 24, length)
    elif length < 65536:
        return ENCODED_LENGTH_3.pack(majortype << 5 | 25, length)
    elif length < 4294967296:
        return ENCODED_LENGTH_4.pack(majortype << 5 | 26, length)
    else:
        return ENCODED_LENGTH_5.pack(majortype << 5 | 27, length)

def streamencodebytestring(v):
    yield encodelength(MAJOR_TYPE_BYTESTRING, len(v))
    yield v

def streamencodebytestringfromiter(it):
    """Convert an iterator of chunks to an indefinite bytestring.

    Given an input that is iterable and each element in the iterator is
    representable as bytes, emit an indefinite length bytestring.
    """
    yield BEGIN_INDEFINITE_BYTESTRING

    for chunk in it:
        yield encodelength(MAJOR_TYPE_BYTESTRING, len(chunk))
        yield chunk

    yield BREAK

def streamencodeindefinitebytestring(source, chunksize=65536):
    """Given a large source buffer, emit as an indefinite length bytestring.

    This is a generator of chunks constituting the encoded CBOR data.
    """
    yield BEGIN_INDEFINITE_BYTESTRING

    i = 0
    l = len(source)

    while True:
        chunk = source[i:i + chunksize]
        i += len(chunk)

        yield encodelength(MAJOR_TYPE_BYTESTRING, len(chunk))
        yield chunk

        if i >= l:
            break

    yield BREAK

def streamencodeint(v):
    if v >= 18446744073709551616 or v < -18446744073709551616:
        raise ValueError('big integers not supported')

    if v >= 0:
        yield encodelength(MAJOR_TYPE_UINT, v)
    else:
        yield encodelength(MAJOR_TYPE_NEGINT, abs(v) - 1)

def streamencodearray(l):
    """Encode a known size iterable to an array."""

    yield encodelength(MAJOR_TYPE_ARRAY, len(l))

    for i in l:
        for chunk in streamencode(i):
            yield chunk

def streamencodearrayfromiter(it):
    """Encode an iterator of items to an indefinite length array."""

    yield BEGIN_INDEFINITE_ARRAY

    for i in it:
        for chunk in streamencode(i):
            yield chunk

    yield BREAK

def _mixedtypesortkey(v):
    return type(v).__name__, v

def streamencodeset(s):
    # https://www.iana.org/assignments/cbor-tags/cbor-tags.xhtml defines
    # semantic tag 258 for finite sets.
    yield encodelength(MAJOR_TYPE_SEMANTIC, 258)

    for chunk in streamencodearray(sorted(s, key=_mixedtypesortkey)):
        yield chunk

def streamencodemap(d):
    """Encode dictionary to a generator.

    Does not supporting indefinite length dictionaries.
    """
    yield encodelength(MAJOR_TYPE_MAP, len(d))

    for key, value in sorted(d.iteritems(),
                             key=lambda x: _mixedtypesortkey(x[0])):
        for chunk in streamencode(key):
            yield chunk
        for chunk in streamencode(value):
            yield chunk

def streamencodemapfromiter(it):
    """Given an iterable of (key, value), encode to an indefinite length map."""
    yield BEGIN_INDEFINITE_MAP

    for key, value in it:
        for chunk in streamencode(key):
            yield chunk
        for chunk in streamencode(value):
            yield chunk

    yield BREAK

def streamencodebool(b):
    # major type 7, simple value 20 and 21.
    yield b'\xf5' if b else b'\xf4'

def streamencodenone(v):
    # major type 7, simple value 22.
    yield b'\xf6'

STREAM_ENCODERS = {
    bytes: streamencodebytestring,
    int: streamencodeint,
    list: streamencodearray,
    tuple: streamencodearray,
    dict: streamencodemap,
    set: streamencodeset,
    bool: streamencodebool,
    type(None): streamencodenone,
}

def streamencode(v):
    """Encode a value in a streaming manner.

    Given an input object, encode it to CBOR recursively.

    Returns a generator of CBOR encoded bytes. There is no guarantee
    that each emitted chunk fully decodes to a value or sub-value.

    Encoding is deterministic - unordered collections are sorted.
    """
    fn = STREAM_ENCODERS.get(v.__class__)

    if not fn:
        raise ValueError('do not know how to encode %s' % type(v))

    return fn(v)

def readindefinitebytestringtoiter(fh, expectheader=True):
    """Read an indefinite bytestring to a generator.

    Receives an object with a ``read(X)`` method to read N bytes.

    If ``expectheader`` is True, it is expected that the first byte read
    will represent an indefinite length bytestring. Otherwise, we
    expect the first byte to be part of the first bytestring chunk.
    """
    read = fh.read
    decodeuint = decodermod.decode_uint
    byteasinteger = decodermod.byte_as_integer

    if expectheader:
        initial = decodermod.byte_as_integer(read(1))

        majortype = initial >> 5
        subtype = initial & SUBTYPE_MASK

        if majortype != MAJOR_TYPE_BYTESTRING:
            raise decodermod.CBORDecodeError(
                'expected major type %d; got %d' % (MAJOR_TYPE_BYTESTRING,
                                                    majortype))

        if subtype != SUBTYPE_INDEFINITE:
            raise decodermod.CBORDecodeError(
                'expected indefinite subtype; got %d' % subtype)

    # The indefinite bytestring is composed of chunks of normal bytestrings.
    # Read chunks until we hit a BREAK byte.

    while True:
        # We need to sniff for the BREAK byte.
        initial = byteasinteger(read(1))

        if initial == BREAK_INT:
            break

        length = decodeuint(fh, initial & SUBTYPE_MASK)
        chunk = read(length)

        if len(chunk) != length:
            raise decodermod.CBORDecodeError(
                'failed to read bytestring chunk: got %d bytes; expected %d' % (
                    len(chunk), length))

        yield chunk
