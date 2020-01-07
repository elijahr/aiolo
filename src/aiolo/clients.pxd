# cython: language_level=3

from . cimport lo


cdef class Client:

    # private
    cdef lo.lo_address _lo_address
