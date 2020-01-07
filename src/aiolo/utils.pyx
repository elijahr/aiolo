# cython: language_level=3

from libc.stdint cimport uint64_t, uint32_t, int32_t, int64_t, uint8_t, INT32_MAX, INT64_MAX
from libc.stdlib cimport malloc, free

from . cimport lo
from . import midi
from . import timetag

# Below are defined in lo_osc_types.h

# basic OSC types
# 32 bit signed integer.
cdef char LO_INT32 = b'i'
# 32 bit IEEE-754 float.
cdef char LO_FLOAT = b'f'
# Standard C, NULL terminated string.
cdef char LO_STRING = b's'
# OSC binary blob type. Accessed using the lo_blob_*() functions.
cdef char LO_BLOB = b'b'

# extended OSC types
# 64 bit signed integer.
cdef char LO_INT64 = b'h'
# OSC TimeTag type, represented by the lo_timetag structure.
cdef char LO_TIMETAG = b't'
# 64 bit IEEE-754 double.
cdef char LO_DOUBLE = b'd'
# Standard C, NULL terminated, string. Used in systems which
# distinguish strings and symbols.
cdef char LO_SYMBOL = b'S'
# Standard C, 8 bit, char variable.
cdef char LO_CHAR = b'c'
# A 4 byte MIDI packet.
cdef char LO_MIDI = b'm'
# Symbol representing the value True.
cdef char LO_TRUE = b'T'
# Symbol representing the value False.
cdef char LO_FALSE = b'F'
# Symbol representing the value Nil.
cdef char LO_NIL = b'N'
# Symbol representing the value Infinitum.
cdef char LO_INFINITUM = b'I'


INFINITY = float('inf')


TYPE_MAP = {
    int: LO_INT64,
    float: LO_DOUBLE,
    str: LO_STRING,
    bytes: LO_BLOB,
    bytearray: LO_BLOB,
    midi.Midi: LO_MIDI,
    timetag.TimeTag: LO_TIMETAG,
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


cdef bytes pytypes_to_lotypes(object types):
    """
    Transform an iterable of Python type objects into a liblo type definition string.

    :param types: iterable of types
    :return: bytes
    """
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
        lo.lo_message lo_msg
        lo.lo_blob lo_blob
        lo.lo_timetag * lo_tt_p
        uint8_t * midi_p
        unsigned char * blob

    if isinstance(lotypes, str):
        lotypes = lotypes.encode('utf8')

    lotypes = bytearray(lotypes)

    lo_msg = lo.lo_message_new()
    if lo_msg is NULL:
        raise MemoryError
    for i, (lotype, arg) in enumerate(zip(lotypes, args)):
        if lotype == LO_INT32:
            if arg > INT32_MAX:
                raise ValueError('Cannot cast %s to int32_t' % arg)
            lo.lo_message_add_int32(lo_msg, <int32_t>arg)
        elif lotype == LO_INT64:
            if arg > INT64_MAX:
                raise ValueError('Cannot cast %s to int64_t' % arg)
            lo.lo_message_add_int64(lo_msg, <int64_t>arg)
        elif lotype in (LO_FLOAT, LO_DOUBLE):
            lo.lo_message_add_double(lo_msg, <double>arg)
        elif lotype == LO_INFINITUM:
            lo.lo_message_add_infinitum(lo_msg)
        elif lotype == LO_STRING:
            barg = arg.encode('utf8')
            lo.lo_message_add_string(lo_msg, barg)
        elif lotype == LO_BLOB:
            if not len(arg):
                # Or should we just add nil?
                raise ValueError('Cannot send empty blob %r' % arg)
            arg = bytes(arg)
            blob = <unsigned char*>arg
            lo_blob = lo.lo_blob_new(<int32_t>(len(arg)), <void*>blob)
            if lo_blob is NULL:
                raise MemoryError
            lo.lo_message_add_blob(lo_msg, lo_blob)
            lo.lo_blob_free(lo_blob)
        elif lotype == LO_TIMETAG:
            lo_tt_p = <lo.lo_timetag*>(malloc(sizeof(lo.lo_timetag)))
            lo_tt_p[0].sec = arg[0]
            lo_tt_p[0].frac = arg[1]
            lo.lo_message_add_timetag(lo_msg, lo_tt_p[0])
            free(lo_tt_p)
        elif lotype == LO_MIDI:
            midi_p = <uint8_t*>(malloc(sizeof(uint8_t) * 4))
            midi_p[0] = <uint8_t>arg[0]
            midi_p[1] = <uint8_t>arg[1]
            midi_p[2] = <uint8_t>arg[2]
            midi_p[3] = <uint8_t>arg[3]
            lo.lo_message_add_midi(lo_msg, midi_p)
            free(midi_p)
        elif lotype == LO_NIL:
            lo.lo_message_add_nil(lo_msg)
        elif lotype == LO_TRUE:
            lo.lo_message_add_true(lo_msg)
        elif lotype == LO_FALSE:
            lo.lo_message_add_false(lo_msg)
        else:
            raise ValueError('Unhandled type %s: %s' % (type(arg), repr(arg)))
    return lo_msg


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
            data.append((arg.t.sec, arg.t.frac))
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