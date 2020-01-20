# cython: language_level=3

from . cimport lo

cdef class Message:
    cdef public object route
    cdef tuple data
    cdef lo.lo_message lo_message

