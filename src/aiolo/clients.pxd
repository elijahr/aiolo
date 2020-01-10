# cython: language_level=3

from . cimport lo


cdef class Client:

    # private
    cdef lo.lo_address lo_address
    cdef object sock
    cdef object ready