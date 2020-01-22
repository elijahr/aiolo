# cython: language_level=3

import datetime
from typing import Iterable


from libc.stdint cimport uint8_t, int32_t, \
    UINT8_MAX as _UINT8_MAX, \
    INT32_MIN as _INT32_MIN, \
    INT32_MAX as _INT32_MAX, \
    INT64_MAX as _INT64_MIN, \
    INT64_MAX as _INT64_MAX

from . import typedefs
from . cimport defs, lo, midis, timetags


__all__ = [
    'Argdef',
    'UINT8_MAX', 'INT32_MIN', 'INT32_MAX', 'INT64_MIN', 'INT64_MAX',
    'INT32', 'FLOAT', 'STRING', 'BLOB', 'INT64', 'TIMETAG', 'DOUBLE',
    'SYMBOL', 'CHAR', 'MIDI', 'TRUE', 'FALSE', 'NIL', 'INFINITUM',
    'INFINITY',
    'ANY_ARGS', 'NO_ARGS',
    'guess_argtypes',
]


UINT8_MAX = _UINT8_MAX
INT32_MIN = -_INT32_MIN # Why is this not negative in the first place?
INT32_MAX = _INT32_MAX
INT64_MIN = -_INT64_MIN # Why is this not negative in the first place?
INT64_MAX = _INT64_MAX

# Below are defined in lo_osc_types.h

# basic OSC typedefs
# 32 bit signed integer.
INT32 = b'i'
cpdef char LO_INT32 = ord(INT32)

# 32 bit IEEE-754 float.
FLOAT = b'f'
cpdef char LO_FLOAT = ord(FLOAT)

# Standard C, NULL terminated string.
STRING = b's'
cpdef char LO_STRING = ord(STRING)

# OSC binary blob type. Accessed using the lo_blob_*() functions.
BLOB = b'b'
cpdef char LO_BLOB = ord(BLOB)

# extended OSC typedefs
# 64 bit signed integer.
INT64 = b'h'
cpdef char LO_INT64 = ord(INT64)

# OSC TimeTag type, represented by the lo_timetag structure.
TIMETAG = b't'
cpdef char LO_TIMETAG = ord(TIMETAG)

# 64 bit IEEE-754 double.
DOUBLE = b'd'
cpdef char LO_DOUBLE = ord(DOUBLE)

# Standard C, NULL terminated, string. Used in systems which
# distinguish strings and symbols.
SYMBOL = b'S'
cpdef char LO_SYMBOL = ord(SYMBOL)

# Standard C, 8 bit, char variable.
CHAR = b'c'
cpdef char LO_CHAR = ord(CHAR)

# A 4 byte MIDI packet.
MIDI = b'm'
cpdef char LO_MIDI = ord(MIDI)

# Symbol representing the value True.
TRUE = b'T'
cpdef char LO_TRUE = ord(TRUE)

# Symbol representing the value False.
FALSE = b'F'
cpdef char LO_FALSE = ord(FALSE)

# Symbol representing the value Nil.
NIL = b'N'
cpdef char LO_NIL = ord(NIL)

# Symbol representing the value Infinitum.
INFINITUM = b'I'
cpdef char LO_INFINITUM = ord(INFINITUM)


INFINITY = float('inf')


cdef dict ARGDEF_INT_LOOKUP = {
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

    INT32: LO_INT32,
    FLOAT: LO_FLOAT,
    STRING: LO_STRING,
    BLOB: LO_BLOB,
    INT64: LO_INT64,
    TIMETAG: LO_TIMETAG,
    DOUBLE: LO_DOUBLE,
    SYMBOL: LO_SYMBOL,
    CHAR: LO_CHAR,
    MIDI: LO_MIDI,
    TRUE: LO_TRUE,
    FALSE: LO_FALSE,
    NIL: LO_NIL,
    INFINITUM: LO_INFINITUM,

    INT32.decode('utf8'): LO_INT32,
    FLOAT.decode('utf8'): LO_FLOAT,
    STRING.decode('utf8'): LO_STRING,
    BLOB.decode('utf8'): LO_BLOB,
    INT64.decode('utf8'): LO_INT64,
    TIMETAG.decode('utf8'): LO_TIMETAG,
    DOUBLE.decode('utf8'): LO_DOUBLE,
    SYMBOL.decode('utf8'): LO_SYMBOL,
    CHAR.decode('utf8'): LO_CHAR,
    MIDI.decode('utf8'): LO_MIDI,
    TRUE.decode('utf8'): LO_TRUE,
    FALSE.decode('utf8'): LO_FALSE,
    NIL.decode('utf8'): LO_NIL,
    INFINITUM.decode('utf8'): LO_INFINITUM,

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

cdef tuple EMPTY_STRINGS = (b'', '')
cdef tuple BOOLS_OR_NONE = (True, False, None)


cdef class Argdef(defs.Def):
    def __cinit__(self, argdef: typedefs.ArgdefTypes):
        if argdef is not None and argdef != ANY_ARGS:
            self._bytes = bytes(flatten_argtypes(argdef))
            self._str = self._bytes.decode('utf8')

    def __init__(self, argdef: typedefs.ArgdefTypes):
        pass

    @property
    def matches_any(self):
        return self._bytes is None

    @property
    def matches_none(self):
        return self._bytes == b''

    cdef lo.lo_message build_lo_message(Argdef self, object args: Iterable[typedefs.MessageTypes]) except NULL:
        cdef:
            lo.lo_message lo_message
            lo.lo_blob lo_blob
            uint8_t * midi_p
            char * blob
            int32_t blobsize

        if self.matches_any:
            argtypes = guess_argtypes(args)
        else:
            argtypes = bytearray(self._bytes)

        if len(argtypes) != len(args):
            raise ValueError(
                'Argument length does match argdef %r (length %s), got %r (length %s)' % (
                    argtypes, len(argtypes), args, len(args)))

        lo_message = lo.lo_message_new()
        if lo_message is NULL:
            raise MemoryError
        for i, (argtype, arg) in enumerate(zip(argtypes, args)):
            if argtype == LO_INT32:
                try:
                    arg = int(arg)
                except TypeError:
                    raise ValueError('Invalid LO_INT32 value %s' % repr(arg))
                if not (INT32_MIN <= arg <= INT32_MAX):
                    raise ValueError('Cannot cast %s to int32_t' % arg)
                if lo.lo_message_add_int32(lo_message, int(arg)) != 0:
                    raise MemoryError
            elif argtype == LO_INT64:
                try:
                    arg = int(arg)
                except TypeError:
                    raise ValueError('Invalid LO_INT64 value %s' % repr(arg))
                if not (INT64_MIN <= arg <= INT64_MAX):
                    raise ValueError('Cannot cast %s to int64_t' % arg)
                if lo.lo_message_add_int64(lo_message, arg) != 0:
                    raise MemoryError
            elif argtype == LO_FLOAT:
                try:
                    arg = float(arg)
                except TypeError:
                    raise ValueError('Invalid LO_FLOAT value %s' % repr(arg))
                if lo.lo_message_add_float(lo_message, float(arg)) != 0:
                    raise MemoryError
            elif argtype == LO_DOUBLE:
                try:
                    arg = float(arg)
                except TypeError:
                    raise ValueError('Invalid LO_DOUBLE value %s' % repr(arg))
                if lo.lo_message_add_double(lo_message, float(arg)) != 0:
                    raise MemoryError
            elif argtype == LO_STRING:
                if isinstance(arg, str):
                    barg = arg.encode('utf8')
                elif isinstance(arg, bytearray):
                    barg = bytes(arg)
                elif isinstance(arg, bytes):
                    barg = arg
                else:
                    barg = str(arg).encode('utf8')
                if lo.lo_message_add_string(lo_message, barg) != 0:
                    raise MemoryError
            elif argtype == LO_SYMBOL:
                if isinstance(arg, bytearray):
                    barg = bytes(arg)
                elif isinstance(arg, bytes):
                    barg = arg
                else:
                    barg = str(arg).encode('utf8')
                if lo.lo_message_add_symbol(lo_message, barg) != 0:
                    raise MemoryError
            elif argtype == LO_CHAR:
                if isinstance(arg, bytearray):
                    barg = bytes(arg)
                elif isinstance(arg, bytes):
                    barg = arg
                elif isinstance(arg, (int, float)):
                    barg = bytearray([int(arg)])
                else:
                    barg = str(arg).encode('utf8')
                if len(barg) != 1:
                    raise ValueError('LO_CHAR must be a single character, got %s' % repr(barg))
                if lo.lo_message_add_char(lo_message, barg[0]) != 0:
                    raise MemoryError
            elif argtype == LO_BLOB:
                if isinstance(arg, bytearray):
                    barg = bytes(arg)
                elif isinstance(arg, bytes):
                    barg = arg
                else:
                    barg = str(arg).encode('utf8')
                if not len(barg):
                    raise ValueError('Cannot send empty LO_BLOB')
                blob = <char*>barg
                size = len(blob)
                blobsize = <int32_t>size
                lo_blob = lo.lo_blob_new(blobsize, <void*>blob)
                if lo_blob is NULL:
                    raise MemoryError
                if lo.lo_message_add_blob(lo_message, lo_blob) != 0:
                    raise MemoryError
                lo.lo_blob_free(lo_blob)
            elif argtype == LO_TIMETAG:
                if isinstance(arg, timetags.TimeTag):
                    timetag = arg
                elif isinstance(arg, (float, int)):
                    timetag = timetags.TimeTag(arg)
                elif isinstance(arg, datetime.datetime):
                    timetag = timetags.TimeTag(arg)
                else:
                    raise ValueError('Invalid LO_TIMETAG value %s' % repr(arg))
                if lo.lo_message_add_timetag(lo_message, (<timetags.TimeTag>timetag).lo_timetag) != 0:
                    raise MemoryError
            elif argtype == LO_MIDI:
                if isinstance(arg, bytearray):
                    try:
                        arg = midis.Midi(*arg)
                    except TypeError as exc:
                        raise ValueError(str(exc))
                elif not isinstance(arg, midis.Midi):
                    raise ValueError('Invalid LO_MIDI value %s' % repr(arg))
                if lo.lo_message_add_midi(lo_message, (<midis.Midi>arg).data) != 0:
                    raise MemoryError
            elif argtype == LO_NIL:
                if arg is not None:
                    raise ValueError('Invalid LO_NIL value %s' % repr(arg))
                if lo.lo_message_add_nil(lo_message) != 0:
                    raise MemoryError
            elif argtype == LO_TRUE:
                if not arg:
                    raise ValueError('Invalid LO_TRUE value %s' % repr(arg))
                if lo.lo_message_add_true(lo_message) != 0:
                    raise MemoryError
            elif argtype == LO_FALSE:
                if arg:
                    raise ValueError('Invalid LO_FALSE value %s' % repr(arg))
                if lo.lo_message_add_false(lo_message) != 0:
                    raise MemoryError
            elif argtype == LO_INFINITUM:
                if arg != float('inf'):
                    raise ValueError
                if lo.lo_message_add_infinitum(lo_message) != 0:
                    raise MemoryError
            else:
                raise ValueError('Unhandled type %r: %s' % (type(arg), repr(arg)))
        return lo_message

    cdef list unpack_args(self, lo.lo_arg ** argv, int argc):
        cdef:
            int i = 0
            int j
            int blobsize
            char * blobdata
            lo.lo_arg * arg
            char * argtypes = self._bytes
            list data = []
        while i < argc:
            arg = argv[i]
            if argtypes[i] == LO_INT32:
                data.append(arg.i32)
            elif argtypes[i] == LO_FLOAT:
                data.append(<float>arg.f)
            elif argtypes[i] == LO_STRING:
                s = <bytes>&arg.s
                data.append(s.decode('utf8'))
            elif argtypes[i] == LO_BLOB:
                blobsize = lo.lo_blob_datasize(arg)
                blobdata = <char*>lo.lo_blob_dataptr(arg)
                blob = bytearray(blobsize)
                j = 0
                while j < blobsize:
                    blob[j] = blobdata[j]
                    j += 1
                data.append(bytes(blob))
            elif argtypes[i] == LO_INT64:
                data.append(arg.i64)
            elif argtypes[i] == LO_TIMETAG:
                timestamp = timetags.lo_timetag_to_unix_timestamp(<lo.lo_timetag>arg.t)
                data.append(timetags.TimeTag(timestamp))
            elif argtypes[i] == LO_DOUBLE:
                data.append(arg.d)
            elif argtypes[i] == LO_SYMBOL:
                s = <bytes>&arg.S
                data.append(s.decode('utf8'))
            elif argtypes[i] == LO_CHAR:
                data.append(<bytes>arg.c)
            elif argtypes[i] == LO_MIDI:
                data.append(midis.Midi(arg.m[0], arg.m[1], arg.m[2], arg.m[3]))
            elif argtypes[i] == LO_TRUE:
                data.append(True)
            elif argtypes[i] == LO_FALSE:
                data.append(False)
            elif argtypes[i] == LO_NIL:
                data.append(None)
            elif argtypes[i] == LO_INFINITUM:
                data.append(float('inf'))
            else:
                raise ValueError('Unknown type %r' % <bytes>argtypes[i])
            i += 1
        return data


cpdef bytes guess_argtypes(object args: Iterable[typedefs.MessageTypes]):
    argtypes = bytearray()
    for arg in args:
        if arg in BOOLS_OR_NONE:
            lookup = arg
        else:
            lookup = type(arg)
        try:
            argtypes.append(ARGDEF_INT_LOOKUP[lookup])
        except KeyError:
            raise ValueError('Unsupported argument value %r' % arg)
    return bytes(argtypes)


def flatten_argtypes(argtypes: typedefs.ArgdefTypes) -> bytearray:
    try:
        return bytearray([ARGDEF_INT_LOOKUP[argtypes]])
    except (KeyError, TypeError):
        pass
    if isinstance(argtypes, Argdef):
        return bytearray(bytes(argtypes))
    elif isinstance(argtypes, bytes):
        return bytearray(argtypes)
    elif isinstance(argtypes, bytearray):
        return argtypes
    elif hasattr(argtypes, '__iter__'):
        arr = bytearray()
        for argtype in argtypes:
            arr += flatten_argtypes(argtype)
        return arr
    elif argtypes in EMPTY_STRINGS:
        return bytearray()
    raise ValueError('Invalid argdef value %r' % argtypes)


ANY_ARGS = Argdef(None)
NO_ARGS = Argdef('')
