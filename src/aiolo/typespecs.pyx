# cython: language_level=3

import datetime
from typing import Iterable, List

IF not PYPY:
    from cpython cimport array

import array

from . import types
from . cimport abstractspecs, midis, timetags


__all__ = [
    'TypeSpec',
    'INT32', 'FLOAT', 'STRING', 'BLOB', 'INT64', 'TIMETAG', 'DOUBLE',
    'SYMBOL', 'CHAR', 'MIDI', 'TRUE', 'FALSE', 'NIL', 'INFINITUM',
    'LO_TYPE_LOOKUP', 'ANY_ARGS', 'NO_ARGS',
]

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


IF not PYPY:
    cdef array.array TYPESPEC_ARRAY_TEMPLATE = array.array('b')


LO_TYPE_LOOKUP = {
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
    float('inf'): LO_INFINITUM,

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
}

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
                raw_typespec.append(LO_TYPE_LOOKUP[arg])
            except (KeyError, TypeError):
                try:
                    raw_typespec.append(LO_TYPE_LOOKUP[type(arg)])
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
            into.append(LO_TYPE_LOOKUP[typespec])
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


cpdef TypeSpec _ANY_ARGS = TypeSpec(None)
cpdef TypeSpec _NO_ARGS = TypeSpec('')
ANY_ARGS = _ANY_ARGS
NO_ARGS = _NO_ARGS
