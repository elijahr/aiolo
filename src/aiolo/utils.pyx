# cython: language_level=3

import datetime
from typing import Union, Iterable

from libc.stdint cimport uint64_t, uint32_t, int32_t, int64_t, uint8_t, INT32_MAX, INT64_MAX
from libc.stdlib cimport malloc, free

from . cimport lo, timetags
from . import midis

# Below are defined in lo_osc_types.h

# basic OSC types
# 32 bit signed integer.
cpdef char LO_INT32 = b'i'
# 32 bit IEEE-754 float.
cpdef char LO_FLOAT = b'f'
# Standard C, NULL terminated string.
cpdef char LO_STRING = b's'
# OSC binary blob type. Accessed using the lo_blob_*() functions.
cpdef char LO_BLOB = b'b'

# extended OSC types
# 64 bit signed integer.
cpdef char LO_INT64 = b'h'
# OSC TimeTag type, represented by the lo_timetag structure.
cpdef char LO_TIMETAG = b't'
# 64 bit IEEE-754 double.
cpdef char LO_DOUBLE = b'd'
# Standard C, NULL terminated, string. Used in systems which
# distinguish strings and symbols.
cpdef char LO_SYMBOL = b'S'
# Standard C, 8 bit, char variable.
cpdef char LO_CHAR = b'c'
# A 4 byte MIDI packet.
cpdef char LO_MIDI = b'm'
# Symbol representing the value True.
cpdef char LO_TRUE = b'T'
# Symbol representing the value False.
cpdef char LO_FALSE = b'F'
# Symbol representing the value Nil.
cpdef char LO_NIL = b'N'
# Symbol representing the value Infinitum.
cpdef char LO_INFINITUM = b'I'


INFINITY = float('inf')


TYPE_MAP = {
    int: LO_INT64,
    float: LO_DOUBLE,
    str: LO_STRING,
    bytes: LO_BLOB,
    bytearray: LO_BLOB,
    midis.Midi: LO_MIDI,
    timetags.TimeTag: LO_TIMETAG,
    datetime.datetime: LO_TIMETAG,
    True: LO_TRUE,
    False: LO_FALSE,
    None: LO_NIL,
    type(None): LO_NIL,
    INFINITY: LO_INFINITUM,
    LO_INT32: LO_INT32,
    LO_FLOAT: LO_FLOAT,
    LO_STRING: LO_STRING,
    LO_BLOB: LO_BLOB,
    LO_INT64: LO_INT64,
    LO_TIMETAG: LO_TIMETAG,
    LO_DOUBLE: LO_DOUBLE,
    LO_SYMBOL: LO_SYMBOL,
    LO_CHAR: LO_CHAR,
    LO_MIDI: LO_MIDI,
    LO_TRUE: LO_TRUE,
    LO_FALSE: LO_FALSE,
    LO_NIL: LO_NIL,
    LO_INFINITUM: LO_INFINITUM,
}


cpdef bytes ensure_lotypes(types: Union[str, bytes, Iterable, None]):
    """
    Transform an iterable of types into a liblo type definition string.

    The types can be Python type objects, or strings/bytes representing liblo types (in which case this
    function simply validates that the types are valid).

    :param types: iterable of types
    :return: bytes
    """
    if types is None:
        types = b''

    if isinstance(types, bytes):
        lotypes = types.decode('utf8')
    elif isinstance(types, str):
        lotypes = types

    lotypes = bytearray()
    for t in types:
        if isinstance(t, str):
            t = ord(t.encode('utf8'))
        elif isinstance(t, bytes):
            t = ord(t)
        try:
            lotypes.append(TYPE_MAP[t])
        except KeyError:
            raise ValueError('Unknown type: %r' % t)
    return bytes(lotypes)


cdef lo.lo_message pyargs_to_lomessage(object lotypes, object args):
    cdef:
        lo.lo_message lo_message
        lo.lo_blob lo_blob
        uint8_t * midi_p
        lo.lo_timetag * tt_p
        unsigned char * blob

    if len(lotypes) != len(args):
        raise ValueError('Expected %s args, got %s' % (len(lotypes), len(args)))

    if isinstance(lotypes, str):
        lotypes = lotypes.encode('utf8')

    lotypes = bytearray(lotypes)

    lo_message = lo.lo_message_new()
    if lo_message is NULL:
        raise MemoryError
    for i, (lotype, arg) in enumerate(zip(lotypes, args)):
        if lotype == LO_INT32:
            if arg > INT32_MAX:
                raise ValueError('Cannot cast %s to int32_t' % arg)
            if lo.lo_message_add_int32(lo_message, <int32_t>int(arg)) != 0:
                raise MemoryError
        elif lotype == LO_INT64:
            if arg > INT64_MAX:
                raise ValueError('Cannot cast %s to int64_t' % arg)
            if lo.lo_message_add_int64(lo_message, <int64_t>int(arg)) != 0:
                raise MemoryError
        elif lotype in (LO_FLOAT, LO_DOUBLE):
            if lo.lo_message_add_double(lo_message, <double>float(arg)) != 0:
                raise MemoryError
        elif lotype == LO_INFINITUM:
            if lo.lo_message_add_infinitum(lo_message) != 0:
                raise MemoryError
        elif lotype == LO_STRING:
            barg = arg.encode('utf8')
            if lo.lo_message_add_string(lo_message, barg) != 0:
                raise MemoryError
        elif lotype == LO_BLOB:
            if not len(arg):
                # Or should we just add nil?
                raise ValueError('Cannot send empty blob %r' % arg)
            arg = bytes(arg)
            blob = <unsigned char*>arg
            lo_blob = lo.lo_blob_new(<int32_t>(len(arg)), <void*>blob)
            if lo_blob is NULL:
                raise MemoryError
            if lo.lo_message_add_blob(lo_message, lo_blob) != 0:
                raise MemoryError
            lo.lo_blob_free(lo_blob)
        elif lotype == LO_TIMETAG:
            if isinstance(arg, (float, int)):
                timetag = timetags.TimeTag(arg)
            elif isinstance(arg, datetime.datetime):
                timetag = timetags.TimeTag.from_datetime(arg)
            elif isinstance(arg, timetags.TimeTag):
                timetag = arg
            else:
                raise ValueError('Invalid TimeTag argument %r' % arg)
            if message_add_timetag(lo_message, timetag) != 0:
                raise MemoryError
        elif lotype == LO_MIDI:
            midi_p = <uint8_t*>(malloc(sizeof(uint8_t) * 4))
            midi_p[0] = <uint8_t>int(arg[0])
            midi_p[1] = <uint8_t>int(arg[1])
            midi_p[2] = <uint8_t>int(arg[2])
            midi_p[3] = <uint8_t>int(arg[3])
            if lo.lo_message_add_midi(lo_message, midi_p) != 0:
                raise MemoryError
            free(midi_p)
        elif lotype == LO_NIL:
            if lo.lo_message_add_nil(lo_message) != 0:
                raise MemoryError
        elif lotype == LO_TRUE:
            if lo.lo_message_add_true(lo_message) != 0:
                raise MemoryError
        elif lotype == LO_FALSE:
            if lo.lo_message_add_false(lo_message) != 0:
                raise MemoryError
        else:
            raise ValueError('Unhandled type %s: %s' % (type(arg), repr(arg)))
    return lo_message


cdef object lomessage_to_pyargs(char * lotypes, lo.lo_arg ** argv, int argc):
    cdef:
        int i = 0
        int blobsize
        unsigned char * blobdata
        lo.lo_arg * arg
    data = []
    while i < argc:
        arg = argv[i]
        if lotypes[i] == LO_INT32:
            data.append(arg.i32)
        elif lotypes[i] == LO_FLOAT:
            data.append(<float>arg.f)
        elif lotypes[i] == LO_STRING:
            s = <bytes>&arg.s
            data.append(s.decode('utf8'))
        elif lotypes[i] == LO_BLOB:
            blobdata = <unsigned char*>lo.lo_blob_dataptr(arg)
            data.append(<bytes>blobdata)
        elif lotypes[i] == LO_INT64:
            data.append(arg.i64)
        elif lotypes[i] == LO_TIMETAG:
            timestamp = timetags.timestamp_from_lo_timetag(<lo.lo_timetag>arg.t)
            data.append(timetags.TimeTag(timestamp))
        elif lotypes[i] == LO_DOUBLE:
            data.append(arg.f)
        elif lotypes[i] == LO_SYMBOL:
            s = <bytes>&arg.S
            data.append(s.decode('utf8'))
        elif lotypes[i] == LO_CHAR:
            data.append(<bytes>arg.c)
        elif lotypes[i] == LO_MIDI:
            data.append((arg.m[0], arg.m[1], arg.m[2], arg.m[3]))
        elif lotypes[i] == LO_TRUE:
            data.append(True)
        elif lotypes[i] == LO_FALSE:
            data.append(False)
        elif lotypes[i] == LO_NIL:
            data.append(None)
        elif lotypes[i] == LO_INFINITUM:
            data.append(float('inf'))
        else:
            raise ValueError('Unknown type %r' % <bytes>lotypes[i])
        i += 1
    return data


cdef int message_add_timetag(lo.lo_message lo_message, timetags.TimeTag timetag):
    return lo.lo_message_add_timetag(lo_message, timetag.lo_timetag)

