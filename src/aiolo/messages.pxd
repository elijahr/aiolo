# cython: language_level=3

from . cimport lo, typespecs


cdef class Message:
    cdef public object route
    cdef public typespecs.TypeSpec typespec
    cdef lo.lo_message lo_message
