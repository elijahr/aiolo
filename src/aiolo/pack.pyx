# cython: language_level=3

import datetime

from typing import Iterable

IF not PYPY:
    from cpython cimport array

import array

from libc.stdint cimport \
    uint8_t, int32_t, uint32_t, \
    UINT8_MAX as _UINT8_MAX, \
    INT32_MIN as _INT32_MIN, \
    INT32_MAX as _INT32_MAX, \
    INT64_MAX as _INT64_MIN, \
    INT64_MAX as _INT64_MAX

from libc.stdlib cimport malloc, free
from libc.string cimport memcpy

from . import types
from . cimport lo, midis, timetags, typespecs


__all__ = ['UINT8_MAX', 'INT32_MIN', 'INT32_MAX', 'INT64_MIN', 'INT64_MAX', 'INFINITY']


UINT8_MAX = _UINT8_MAX
INT32_MIN = -_INT32_MIN # Why is this not negative in the first place?
INT32_MAX = _INT32_MAX
INT64_MIN = -_INT64_MIN # Why is this not negative in the first place?
INT64_MAX = _INT64_MAX

TYPES_CHAR = (str, int)

ARGVALS_TRUE = (True, 1)

ARGVALS_FALSE = (False, 0)

INFINITY = float('inf')

INFINITIES = (INFINITY, -INFINITY)

ARGTYPE_NAMES = {
    typespecs.LO_INT32: 'INT32',
    typespecs.LO_FLOAT: 'FLOAT',
    typespecs.LO_STRING: 'STRING',
    typespecs.LO_BLOB: 'BLOB',
    typespecs.LO_INT64: 'INT64',
    typespecs.LO_TIMETAG: 'TIMETAG',
    typespecs.LO_DOUBLE: 'DOUBLE',
    typespecs.LO_SYMBOL: 'SYMBOL',
    typespecs.LO_CHAR: 'CHAR',
    typespecs.LO_MIDI: 'MIDI',
    typespecs.LO_TRUE: 'TRUE',
    typespecs.LO_FALSE: 'FALSE',
    typespecs.LO_NIL: 'NIL',
    typespecs.LO_INFINITUM: 'INFINITUM',
}

_ARGTYPES = [
    typespecs.LO_INT32,
    typespecs.LO_FLOAT,
    typespecs.LO_STRING,
    typespecs.LO_BLOB,
    typespecs.LO_INT64,
    typespecs.LO_TIMETAG,
    typespecs.LO_DOUBLE,
    typespecs.LO_SYMBOL,
    typespecs.LO_CHAR,
    typespecs.LO_MIDI,
    typespecs.LO_TRUE,
    typespecs.LO_FALSE,
    typespecs.LO_NIL,
    typespecs.LO_INFINITUM,
]

IF PYPY:
    cdef object ARGTYPES = array.array('b', _ARGTYPES)
    cdef object ARGTYPES_INTS = array.array('b', [typespecs.LO_INT64, typespecs.LO_INT32])
    cdef object ARGTYPES_FLOATS = array.array('b', [typespecs.LO_FLOAT, typespecs.LO_DOUBLE])
    cdef object ARGTYPES_STRINGS = array.array('b', [typespecs.LO_STRING, typespecs.LO_SYMBOL, typespecs.LO_CHAR])
ELSE:
    cdef array.array BLOB_ARRAY_TEMPLATE = array.array('b')
    cdef array.array ARGTYPES = array.array('b', _ARGTYPES)
    cdef array.array ARGTYPES_INTS = array.array('b', [typespecs.LO_INT64, typespecs.LO_INT32])
    cdef array.array ARGTYPES_FLOATS = array.array('b', [typespecs.LO_FLOAT, typespecs.LO_DOUBLE])
    cdef array.array ARGTYPES_STRINGS = array.array('b', [typespecs.LO_STRING, typespecs.LO_SYMBOL, typespecs.LO_CHAR])


cdef list unpack_args(typespecs.TypeSpec typespec, lo.lo_arg ** argv, int argc):
    cdef:
        IF PYPY:
            object typespec_array = typespec.array
        ELSE:
            array.array typespec_array = typespec.array
        int i = 0
        int j
        uint32_t blobsize
        lo.lo_arg * arg
        void * raw_blob
        IF PYPY:
            object blob
        ELSE:
            array.array blob
        list data = []

    if len(typespec_array) != argc:
        raise ValueError(
            '%r: argument length does not match typespec length %s, got length %s' % (
                typespec, len(typespec_array), argc))

    while i < argc:
        arg = argv[i]
        if typespec_array[i] == typespecs.LO_INT32:
            data.append(arg.i32)
        elif typespec_array[i] == typespecs.LO_FLOAT:
            data.append(<float>arg.f)
        elif typespec_array[i] == typespecs.LO_STRING:
            s = <bytes>&arg.s
            data.append(s.decode('utf8'))
        elif typespec_array[i] == typespecs.LO_BLOB:
            blobsize = lo.lo_blob_datasize(<lo.lo_blob>&(arg.blob))
            IF PYPY:
                blob = array.array('b')
                raw_blob = malloc(blobsize)
                memcpy(raw_blob, lo.lo_blob_dataptr(<lo.lo_blob>&(arg.blob)), blobsize)
                for j in range(blobsize):
                    blob.append((<char*>raw_blob)[j])
                free(raw_blob)
            ELSE:
                blob = array.clone(BLOB_ARRAY_TEMPLATE, blobsize, zero=True)
                memcpy(<void*>blob.data.as_voidptr, lo.lo_blob_dataptr(<lo.lo_blob>&(arg.blob)), blobsize)
            data.append(blob)
        elif typespec_array[i] == typespecs.LO_INT64:
            data.append(arg.i64)
        elif typespec_array[i] == typespecs.LO_TIMETAG:
            timestamp = timetags.lo_timetag_to_unix_timestamp(<lo.lo_timetag>arg.t)
            data.append(timetags.TimeTag(timestamp))
        elif typespec_array[i] == typespecs.LO_DOUBLE:
            data.append(arg.d)
        elif typespec_array[i] == typespecs.LO_SYMBOL:
            s = <bytes>&arg.S
            data.append(s.decode('utf8'))
        elif typespec_array[i] == typespecs.LO_CHAR:
            data.append((<bytes>arg.c).decode('utf8'))
        elif typespec_array[i] == typespecs.LO_MIDI:
            data.append(midis.Midi(arg.m[0], arg.m[1], arg.m[2], arg.m[3]))
        elif typespec_array[i] == typespecs.LO_TRUE:
            data.append(True)
        elif typespec_array[i] == typespecs.LO_FALSE:
            data.append(False)
        elif typespec_array[i] == typespecs.LO_NIL:
            data.append(None)
        elif typespec_array[i] == typespecs.LO_INFINITUM:
            data.append(float('inf'))
        else:
            raise ValueError('Unknown type %r' % typespec.as_str[i])
        i += 1
    return data

cdef lo.lo_message pack_lo_message(typespecs.TypeSpec typespec, object args: Iterable[types.MessageTypes]) except NULL:
    cdef:
        IF PYPY:
            object typespec_array = typespec.array
        ELSE:
            array.array typespec_array = typespec.array
        lo.lo_message lo_message
        lo.lo_blob lo_blob
        uint8_t * midi_p
        bytes byarg
        char * charg
        int32_t size

    flat = []
    typespecs.flatten_args_into(args, flat)
    args = flat

    if len(typespec_array) != len(args):
        raise ValueError(
            'Argument length does not match typespec %r (length %s), got %r (length %s)' % (
                typespec.as_str, len(typespec_array), args, len(args)))

    lo_message = lo.lo_message_new()
    if lo_message is NULL:
        raise MemoryError
    for i, (argtype, arg) in enumerate(zip(typespec_array, args)):
        if argtype in ARGTYPES_INTS and isinstance(arg, int):
            if argtype == typespecs.LO_INT64:
                if not (INT64_MIN <= arg <= INT64_MAX):
                    raise OverflowError('Invalid value for INT32: %s (overflow)' % repr(arg))
                if lo.lo_message_add_int64(lo_message, arg) != 0:
                    raise MemoryError
            else:
                if not (INT32_MIN <= arg <= INT32_MAX):
                    raise OverflowError('Invalid value for INT32: %s (overflow)' % repr(arg))
                if lo.lo_message_add_int32(lo_message, int(arg)) != 0:
                    raise MemoryError
        elif argtype in ARGTYPES_FLOATS and isinstance(arg, float):
            if arg in INFINITIES:
                raise ValueError('Invalid value for %s: %s' % (ARGTYPE_NAMES[argtype], repr(arg)))
            if argtype == typespecs.LO_FLOAT:
                if float(<float>arg) != arg:
                    raise OverflowError('Invalid value for FLOAT: %s (overflow)' % repr(arg))
                elif lo.lo_message_add_float(lo_message, arg) != 0:
                    raise MemoryError
            else:
                if float(<double>arg) != arg:
                    raise OverflowError('Invalid value for DOUBLE: %s (overflow)' % repr(arg))
                elif lo.lo_message_add_double(lo_message, arg) != 0:
                    raise MemoryError
        elif argtype in ARGTYPES_STRINGS:
            byarg = None
            charg = NULL
            if isinstance(arg, array.array):
                IF PYPY:
                    byarg = arg.tobytes()
                    charg = <char*>byarg
                ELSE:
                    charg = (<array.array>arg).data.as_chars
            elif isinstance(arg, str):
                byarg = arg.encode('utf8')
                charg = <char*>byarg
            if argtype == typespecs.LO_STRING:
                if charg is NULL:
                    raise TypeError('Invalid type for STRING: %s' % repr(arg))
                elif lo.lo_message_add_string(lo_message, charg) != 0:
                    raise MemoryError
            elif argtype == typespecs.LO_SYMBOL:
                if charg is NULL:
                    raise TypeError('Invalid type for SYMBOL: %s' % repr(arg))
                elif lo.lo_message_add_symbol(lo_message, charg) != 0:
                    raise MemoryError

            # CHAR below
            elif isinstance(arg, int):
                if lo.lo_message_add_char(lo_message, arg) != 0:
                    raise MemoryError
            elif charg is NULL:
                raise TypeError('Invalid type for CHAR: %s' % repr(arg))
            elif len(arg) != 1:
                raise OverflowError('Invalid value for CHAR: %s (must be a single char)' % repr(arg))
            else:
                if lo.lo_message_add_char(lo_message, charg[0]) != 0:
                    raise MemoryError
        elif argtype == typespecs.LO_BLOB:
            byarg = None
            charg = NULL
            size = 0
            if isinstance(arg, array.array):
                size = <int32_t>len(arg)
                IF PYPY:
                    byarg = arg.tobytes()
                    charg = <char*>byarg
                ELSE:
                    charg = (<array.array>arg).data.as_chars
            elif isinstance(arg, bytes):
                byarg = arg
                size = <int32_t>len(byarg)
                charg = <char*>byarg
            else:
                raise TypeError('Invalid type for BLOB: %s' % (repr(arg)))
            if not size:
                raise ValueError('Invalid value for BLOB: %s (must have length >= 1)' % repr(arg))
            lo_blob = lo.lo_blob_new(size, <void*>charg)
            if lo_blob is NULL:
                raise MemoryError
            if lo.lo_message_add_blob(lo_message, lo_blob) != 0:
                raise MemoryError
            lo.lo_blob_free(lo_blob)
        elif argtype == typespecs.LO_TIMETAG:
            if isinstance(arg, timetags.TimeTag):
                timetag = arg
            elif isinstance(arg, (float, int)):
                timetag = timetags.TimeTag(arg)
            elif isinstance(arg, datetime.datetime):
                timetag = timetags.TimeTag(arg)
            else:
                raise TypeError('Invalid type for TIMETAG: %s' % (repr(arg)))
            if lo.lo_message_add_timetag(lo_message, (<timetags.TimeTag>timetag).lo_timetag) != 0:
                raise MemoryError
        elif argtype == typespecs.LO_MIDI:
            if isinstance(arg, array.array):
                arg = midis.Midi(*arg)
            elif not isinstance(arg, midis.Midi):
                raise TypeError('Invalid type for MIDI: %s' % (repr(arg)))
            if lo.lo_message_add_midi(lo_message, (<midis.Midi>arg).data) != 0:
                raise MemoryError
        elif argtype == typespecs.LO_NIL and arg is None:
            if lo.lo_message_add_nil(lo_message) != 0:
                raise MemoryError
        elif argtype == typespecs.LO_TRUE and isinstance(arg, (int, bool)):
            if arg not in ARGVALS_TRUE:
                raise ValueError('Invalid value for TRUE: %s' % repr(arg))
            if lo.lo_message_add_true(lo_message) != 0:
                raise MemoryError
        elif argtype == typespecs.LO_FALSE and isinstance(arg, (int, bool)):
            if arg not in ARGVALS_FALSE:
                raise ValueError('Invalid value for FALSE: %s' % repr(arg))
            if lo.lo_message_add_false(lo_message) != 0:
                raise MemoryError
        elif argtype == typespecs.LO_INFINITUM and isinstance(arg, float):
            if arg != float('inf'):
                raise ValueError('Invalid value for INFINITUM: %s' % repr(arg))
            if lo.lo_message_add_infinitum(lo_message) != 0:
                raise MemoryError
        elif argtype not in ARGTYPES:
            raise ValueError('Invalid argtype %s' % repr(argtype))
        else:
            raise TypeError('Invalid type for %s: %s' % (ARGTYPE_NAMES[argtype], repr(arg)))
    return lo_message
