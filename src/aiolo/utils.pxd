# cython: language_level=3

from typing import Iterable, Union

from . cimport lo
from . cimport timetags

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

cpdef bytes ensure_lotypes(types: Union[str, bytes, Iterable, None])

cdef lo.lo_message pyargs_to_lomessage(object lotypes, object args)

cdef object lomessage_to_pyargs(char * lotypes, lo.lo_arg ** argv, int argc)

cdef int message_add_timetag(lo.lo_message lo_message, timetags.TimeTag timetag)
