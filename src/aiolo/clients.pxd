# cython: language_level=3

cimport cython

from . cimport lo

@cython.no_gc
cdef class Client:

    # private
    cdef lo.lo_address lo_address
