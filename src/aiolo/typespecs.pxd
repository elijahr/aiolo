# cython: language_level=3

from typing import Iterable, List

IF not PYPY:
    from cpython cimport array

import array

from . import types
from . cimport abstractspecs

# 32 bit signed integer.
cpdef char LO_INT32
# 32 bit IEEE-754 float.
cpdef char LO_FLOAT
# Standard C, NULL terminated string.
cpdef char LO_STRING
# OSC binary blob type. Accessed using the lo_blob_*() functions.
cpdef char LO_BLOB

# extended OSC types
# 64 bit signed integer.
cpdef char LO_INT64
# OSC TimeTag type, represented by the lo_timetag structure.
cpdef char LO_TIMETAG
# 64 bit IEEE-754 double.
cpdef char LO_DOUBLE
# Standard C, NULL terminated, string. Used in systems which
# distinguish strings and symbols.
cpdef char LO_SYMBOL
# Standard C, 8 bit, char variable.
cpdef char LO_CHAR
# A 4 byte MIDI packet.
cpdef char LO_MIDI
# Symbol representing the value True.
cpdef char LO_TRUE
# Symbol representing the value False.
cpdef char LO_FALSE
# Symbol representing the value Nil.
cpdef char LO_NIL
# Symbol representing the value Infinitum.
cpdef char LO_INFINITUM

IF PYPY:
    cdef object ARGTYPES
    cdef object ARGTYPES_INTS
    cdef object ARGTYPES_FLOATS
    cdef object ARGTYPES_STRINGS
ELSE:
    cdef array.array ARGTYPES
    cdef array.array ARGTYPES_INTS
    cdef array.array ARGTYPES_FLOATS
    cdef array.array ARGTYPES_STRINGS

cdef tuple EMPTY_STRINGS

cdef class TypeSpec(abstractspecs.AbstractSpec):
    pass

cpdef object guess_for_arg_list(object args: Iterable[types.MessageTypes])

cpdef bint flatten_typespec_into(
    object typespec: types.TypeSpecTypes,
    object into: array.array
) except 0

cpdef bint flatten_args_into(object data: Iterable, list into: List) except 0

cpdef TypeSpec _ANY_ARGS
cpdef TypeSpec _NO_ARGS