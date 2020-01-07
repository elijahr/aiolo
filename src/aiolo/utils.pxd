# cython: language_level=3

from . cimport lo

# 32 bit signed integer.
cdef char LO_INT32
# 32 bit IEEE-754 float.
cdef char LO_FLOAT
# Standard C, NULL terminated string.
cdef char LO_STRING
# OSC binary blob type. Accessed using the lo_blob_*() functions.
cdef char LO_BLOB

# extended OSC types
# 64 bit signed integer.
cdef char LO_INT64
# OSC TimeTag type, represented by the lo_timetag structure.
cdef char LO_TIMETAG
# 64 bit IEEE-754 double.
cdef char LO_DOUBLE
# Standard C, NULL terminated, string. Used in systems which
# distinguish strings and symbols.
cdef char LO_SYMBOL
# Standard C, 8 bit, char variable.
cdef char LO_CHAR
# A 4 byte MIDI packet.
cdef char LO_MIDI
# Symbol representing the value True.
cdef char LO_TRUE
# Symbol representing the value False.
cdef char LO_FALSE
# Symbol representing the value Nil.
cdef char LO_NIL
# Symbol representing the value Infinitum.
cdef char LO_INFINITUM

cdef bytes pytypes_to_lotypes(object types)

cdef lo.lo_message pyargs_to_lomessage(object lotypes, object args)

cdef object lomessage_to_pyargs(char * lotypes, lo.lo_arg ** argv, int argc)
