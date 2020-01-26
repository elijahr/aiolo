# cython: language_level=3

from . cimport lo


cdef class Message:
    cdef public object route
    cdef lo.lo_message lo_message
