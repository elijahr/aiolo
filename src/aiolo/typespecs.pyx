# cython: language_level=3

import datetime
from typing import Iterable, List
from libc.stdlib cimport malloc, free

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

from libc.string cimport memcpy

from . import types
from . cimport abstractspecs, lo, messages, midis, timetags


__all__ = [
    'TypeSpec',
    'UINT8_MAX', 'INT32_MIN', 'INT32_MAX', 'INT64_MIN', 'INT64_MAX',
    'INT32', 'FLOAT', 'STRING', 'BLOB', 'INT64', 'TIMETAG', 'DOUBLE',
    'SYMBOL', 'CHAR', 'MIDI', 'TRUE', 'FALSE', 'NIL', 'INFINITUM',
    'INFINITY', 'ARGDEF_INT_LOOKUP',
    'ANY_ARGS', 'NO_ARGS',
]


UINT8_MAX = _UINT8_MAX
INT32_MIN = -_INT32_MIN # Why is this not negative in the first place?
INT32_MAX = _INT32_MAX
INT64_MIN = -_INT64_MIN # Why is this not negative in the first place?
INT64_MAX = _INT64_MAX

# Below are defined in lo_osc_types.h

# basic OSC types
# 32 bit signed integer.
INT32  = 'i'
cpdef char LO_INT32 = ord(INT32)

# 32 bit IEEE-754 float.
FLOAT  = 'f'
cpdef char LO_FLOAT = ord(FLOAT)

# Standard C, NULL terminated string.
STRING  = 's'
cpdef char LO_STRING = ord(STRING)

# OSC binary blob type. Accessed using the lo_blob_*() functions.
BLOB  = 'b'
cpdef char LO_BLOB = ord(BLOB)

# extended OSC types
# 64 bit signed integer.
INT64  = 'h'
cpdef char LO_INT64 = ord(INT64)

# OSC TimeTag type, represented by the lo_timetag structure.
TIMETAG  = 't'
cpdef char LO_TIMETAG = ord(TIMETAG)

# 64 bit IEEE-754 double.
DOUBLE  = 'd'
cpdef char LO_DOUBLE = ord(DOUBLE)

# Standard C, NULL terminated, string. Used in systems which
# distinguish strings and symbols.
SYMBOL  = 'S'
cpdef char LO_SYMBOL = ord(SYMBOL)

# Standard C, 8 bit, char variable.
CHAR  = 'c'
cpdef char LO_CHAR = ord(CHAR)

# A 4 byte MIDI packet.
MIDI  = 'm'
cpdef char LO_MIDI = ord(MIDI)

# Symbol representing the value True.
TRUE  = 'T'
cpdef char LO_TRUE = ord(TRUE)

# Symbol representing the value False.
FALSE  = 'F'
cpdef char LO_FALSE = ord(FALSE)

# Symbol representing the value Nil.
NIL  = 'N'
cpdef char LO_NIL = ord(NIL)

# Symbol representing the value Infinitum.
INFINITUM  = 'I'
cpdef char LO_INFINITUM = ord(INFINITUM)


INFINITY = float('inf')
INFINITIES = (INFINITY, -INFINITY)


IF not PYPY:
    cdef array.array TYPESPEC_ARRAY_TEMPLATE = array.array('b')
    cdef array.array BLOB_ARRAY_TEMPLATE = array.array('b')


ARGDEF_INT_LOOKUP = {
    int: LO_INT64,
    float: LO_DOUBLE,
    str: LO_STRING,
    bytes: LO_BLOB,
    array.array: LO_BLOB,
    midis.Midi: LO_MIDI,
    timetags.TimeTag: LO_TIMETAG,
    datetime.datetime: LO_TIMETAG,
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

ARGTYPE_NAMES = {
    LO_INT32: 'INT32',
    LO_FLOAT: 'FLOAT',
    LO_STRING: 'STRING',
    LO_BLOB: 'BLOB',
    LO_INT64: 'INT64',
    LO_TIMETAG: 'TIMETAG',
    LO_DOUBLE: 'DOUBLE',
    LO_SYMBOL: 'SYMBOL',
    LO_CHAR: 'CHAR',
    LO_MIDI: 'MIDI',
    LO_TRUE: 'TRUE',
    LO_FALSE: 'FALSE',
    LO_NIL: 'NIL',
    LO_INFINITUM: 'INFINITUM',
}

_ARGTYPES = [
    LO_INT32,
    LO_FLOAT,
    LO_STRING,
    LO_BLOB,
    LO_INT64,
    LO_TIMETAG,
    LO_DOUBLE,
    LO_SYMBOL,
    LO_CHAR,
    LO_MIDI,
    LO_TRUE,
    LO_FALSE,
    LO_NIL,
    LO_INFINITUM,
]

IF PYPY:
    cdef object ARGTYPES = array.array('b', _ARGTYPES)
    cdef object ARGTYPES_INTS = array.array('b', [LO_INT64, LO_INT32])
    cdef object ARGTYPES_FLOATS = array.array('b', [LO_FLOAT, LO_DOUBLE])
    cdef object ARGTYPES_STRINGS = array.array('b', [LO_STRING, LO_SYMBOL, LO_CHAR])
ELSE:
    cdef array.array ARGTYPES = array.array('b', _ARGTYPES)
    cdef array.array ARGTYPES_INTS = array.array('b', [LO_INT64, LO_INT32])
    cdef array.array ARGTYPES_FLOATS = array.array('b', [LO_FLOAT, LO_DOUBLE])
    cdef array.array ARGTYPES_STRINGS = array.array('b', [LO_STRING, LO_SYMBOL, LO_CHAR])

TYPES_CHAR = (str, int)

ARGVALS_TRUE = (True, 1)

ARGVALS_FALSE = (False, 0)

cdef tuple EMPTY_STRINGS = (b'', '')


BASIC_TYPES = (
    str,
    bytes,
    array.array,
    int,
    bool,
    float,
    type(None),
    timetags.TimeTag,
    midis.Midi,
)


cdef class TypeSpec(abstractspecs.AbstractSpec):
    def __cinit__(self, typespec: types.TypeSpecTypes):
        cdef TypeSpec a
        IF PYPY:
            self.array = array.array('b')
        ELSE:
            self.array = array.copy(TYPESPEC_ARRAY_TEMPLATE)
        self.none = False

        if isinstance(typespec, TypeSpec):
            a = (<TypeSpec>typespec)
            if a.none:
                self.none = True
            else:
                IF PYPY:
                    self.array.extend(a.array)
                ELSE:
                    array.extend(self.array, a.array)
        elif typespec is None:
            self.none = True
        else:
            flatten_typespec_into(typespec, self.array)

    def __init__(self, typespec: types.TypeSpecTypes):
        pass

    def __hash__(self):
        return hash('TypeSpec:%s' % self.simplerepr)

    def __repr__(self):
        if self.matches_any:
            return 'ANY_ARGS'
        elif self.matches_no:
            return 'NO_ARGS'
        return '%s(%r)' % (self.__class__.__name__, self.as_str)

    @property
    def simplerepr(self):
        if self.matches_any:
            return 'ANY_ARGS'
        elif self.matches_no:
            return 'NO_ARGS'
        return repr(self.as_str)

    def __eq__(self, other: types.TypeSpecTypes) -> bool:
        if isinstance(other, str):
            return self.as_str == other
        elif not isinstance(other, TypeSpec):
            other = TypeSpec(other)
        return self.array == other.array \
               and self.matches_any == other.matches_any \
               and self.matches_no == other.matches_no

    def __lt__(self, other: 'TypeSpec') -> bool:
        if isinstance(other, str):
            return self.as_str < other
        elif self.matches_any:
            return False
        elif not isinstance(other, TypeSpec):
            other = TypeSpec(other)
        if other.matches_any:
            return True
        return self.array < other.array

    def __contains__(self, other: types.TypeSpecTypes) -> bool:
        if not isinstance(other, TypeSpec):
            other = TypeSpec(other)
        if self.matches_any or other.matches_any and not (self.matches_no or other.matches_no):
            # TODO: what's the routing behavior in lo for any args / no args?
            # Need to ensure we reflect that here.
            return True
        elif self.matches_no != other.matches_no:
            return False
        return other.as_str in self.as_str

    def __add__(self, other: types.TypeSpecTypes) -> TypeSpec:
        if not isinstance(other, TypeSpec):
            other = TypeSpec(other)
        if self.matches_any or other.matches_any:
            if self.matches_any == other.matches_any:
                return self
            else:
                raise ValueError('Cannot combine %r and %r' % (self, other))
        elif self.matches_no or other.matches_no:
            if self.matches_no == other.matches_no:
                return self
            else:
                raise ValueError('Cannot combine %r and %r' % (self, other))
        return TypeSpec(self.array + other.array)

    @property
    def matches_any(self):
        return self.none

    @property
    def matches_no(self):
        return not self.matches_any and len(self) == 0

    cpdef list unpack_message(self, messages.Message message):
        cdef:
            lo.lo_arg** argv = lo.lo_message_get_argv((<messages.Message>message).lo_message)
            int argc = lo.lo_message_get_argc((<messages.Message>message).lo_message)

        return self.unpack_args(argv, argc)

    cdef list unpack_args(self, lo.lo_arg ** argv, int argc):
        cdef:
            IF PYPY:
                object typespec_array = self.array
            ELSE:
                array.array typespec_array = self.array
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
                    self, len(typespec_array), argc))

        while i < argc:
            arg = argv[i]
            if typespec_array[i] == LO_INT32:
                data.append(arg.i32)
            elif typespec_array[i] == LO_FLOAT:
                data.append(<float>arg.f)
            elif typespec_array[i] == LO_STRING:
                s = <bytes>&arg.s
                data.append(s.decode('utf8'))
            elif typespec_array[i] == LO_BLOB:
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
            elif typespec_array[i] == LO_INT64:
                data.append(arg.i64)
            elif typespec_array[i] == LO_TIMETAG:
                timestamp = timetags.lo_timetag_to_unix_timestamp(<lo.lo_timetag>arg.t)
                data.append(timetags.TimeTag(timestamp))
            elif typespec_array[i] == LO_DOUBLE:
                data.append(arg.d)
            elif typespec_array[i] == LO_SYMBOL:
                s = <bytes>&arg.S
                data.append(s.decode('utf8'))
            elif typespec_array[i] == LO_CHAR:
                data.append((<bytes>arg.c).decode('utf8'))
            elif typespec_array[i] == LO_MIDI:
                data.append(midis.Midi(arg.m[0], arg.m[1], arg.m[2], arg.m[3]))
            elif typespec_array[i] == LO_TRUE:
                data.append(True)
            elif typespec_array[i] == LO_FALSE:
                data.append(False)
            elif typespec_array[i] == LO_NIL:
                data.append(None)
            elif typespec_array[i] == LO_INFINITUM:
                data.append(float('inf'))
            else:
                raise ValueError('Unknown type %r' % self.as_str[i])
            i += 1
        return data

    cdef lo.lo_message pack_lo_message(self, object args: Iterable[types.MessageTypes]) except NULL:
        cdef:
            IF PYPY:
                object typespec_array = self.array
            ELSE:
                array.array typespec_array = self.array
            lo.lo_message lo_message
            lo.lo_blob lo_blob
            uint8_t * midi_p
            bytes byarg
            char * charg
            int32_t size

        flat = []
        flatten_args_into(args, flat)
        args = flat

        if len(typespec_array) != len(args):
            raise ValueError(
                'Argument length does not match typespec %r (length %s), got %r (length %s)' % (
                    self.as_str, len(typespec_array), args, len(args)))

        lo_message = lo.lo_message_new()
        if lo_message is NULL:
            raise MemoryError
        for i, (argtype, arg) in enumerate(zip(typespec_array, args)):
            if argtype in ARGTYPES_INTS and isinstance(arg, int):
                if argtype == LO_INT64:
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
                if argtype == LO_FLOAT:
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
                if argtype == LO_STRING:
                    if charg is NULL:
                        raise TypeError('Invalid type for STRING: %s' % repr(arg))
                    elif lo.lo_message_add_string(lo_message, charg) != 0:
                        raise MemoryError
                elif argtype == LO_SYMBOL:
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
            elif argtype == LO_BLOB:
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
            elif argtype == LO_TIMETAG:
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
            elif argtype == LO_MIDI:
                if isinstance(arg, array.array):
                    arg = midis.Midi(*arg)
                elif not isinstance(arg, midis.Midi):
                    raise TypeError('Invalid type for MIDI: %s' % (repr(arg)))
                if lo.lo_message_add_midi(lo_message, (<midis.Midi>arg).data) != 0:
                    raise MemoryError
            elif argtype == LO_NIL and arg is None:
                if lo.lo_message_add_nil(lo_message) != 0:
                    raise MemoryError
            elif argtype == LO_TRUE and isinstance(arg, (int, bool)):
                if arg not in ARGVALS_TRUE:
                    raise ValueError('Invalid value for TRUE: %s' % repr(arg))
                if lo.lo_message_add_true(lo_message) != 0:
                    raise MemoryError
            elif argtype == LO_FALSE and isinstance(arg, (int, bool)):
                if arg not in ARGVALS_FALSE:
                    raise ValueError('Invalid value for FALSE: %s' % repr(arg))
                if lo.lo_message_add_false(lo_message) != 0:
                    raise MemoryError
            elif argtype == LO_INFINITUM and isinstance(arg, float):
                if arg != float('inf'):
                    raise ValueError('Invalid value for INFINITUM: %s' % repr(arg))
                if lo.lo_message_add_infinitum(lo_message) != 0:
                    raise MemoryError
            elif argtype not in ARGTYPES:
                raise ValueError('Invalid argtype %s' % repr(argtype))
            else:
                raise TypeError('Invalid type for %s: %s' % (ARGTYPE_NAMES[argtype], repr(arg)))
        return lo_message

    @classmethod
    def guess(cls, args: Iterable[types.MessageTypes]) -> array.array:
        return cls(guess_for_arg_list(args))


cpdef object guess_for_arg_list(object args: Iterable[types.MessageTypes]):
    IF PYPY:
        cdef object raw_typespec = array.array('b')
    ELSE:
        cdef array.array raw_typespec = array.copy(TYPESPEC_ARRAY_TEMPLATE)
    for arg in args:
        if arg is True:
            raw_typespec.append(LO_TRUE)
        elif arg is False:
            raw_typespec.append(LO_FALSE)
        else:
            try:
                raw_typespec.append(ARGDEF_INT_LOOKUP[arg])
            except (KeyError, TypeError):
                try:
                    raw_typespec.append(ARGDEF_INT_LOOKUP[type(arg)])
                except KeyError:
                    raise TypeError('Unsupported argument value %r' % arg)
    return raw_typespec


cpdef bint flatten_typespec_into(
    object typespec: types.TypeSpecTypes,
    object into: array.array
) except 0:
    if typespec is True:
        into.append(LO_TRUE)
        return True
    elif typespec is False:
        into.append(LO_FALSE)
        return True
    else:
        try:
            into.append(ARGDEF_INT_LOOKUP[typespec])
        except (KeyError, TypeError):
            pass
        else:
            return True
    if isinstance(typespec, TypeSpec):
        IF PYPY:
            into.extend(typespec.array)
        ELSE:
            array.extend(into, typespec.array)
    elif isinstance(typespec, array.array):
        IF PYPY:
            into.extend(typespec)
        ELSE:
            array.extend(into, typespec)
    elif isinstance(typespec, str):
        IF PYPY:
            into.extend(array.array('b', typespec.encode('utf8')))
        ELSE:
            array.extend(into, array.array('b', typespec.encode('utf8')))
    elif typespec in EMPTY_STRINGS:
        pass
    else:
        try:
            for a in typespec:
                flatten_typespec_into(a, into)
        except TypeError:
            raise TypeError('Invalid typespec value %r' % typespec)
    return True


cpdef bint flatten_args_into(object data: Iterable, list into: List) except 0:
    try:
        for item in data:
            if isinstance(item, BASIC_TYPES):
                into.append(item)
            else:
                flatten_args_into(item, into)
    except TypeError:
        # not iterable
        into.append(data)
    return True


ANY_ARGS = TypeSpec(None)
NO_ARGS = TypeSpec('')
