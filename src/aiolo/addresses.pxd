# cython: language_level=3

cimport cython

from . cimport lo


@cython.no_gc
cdef class Address:

    # private
    cdef lo.lo_address lo_address
    cdef bint _no_delay
    cdef bint _stream_slip