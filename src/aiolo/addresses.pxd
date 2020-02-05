# cython: language_level=3

from . cimport lo, messages

cdef class Address:

    # private
    cdef lo.lo_address lo_address
    cdef bint _no_delay
    cdef bint _stream_slip

    cdef int _message(self, messages.Message bundle) except -1
    cdef int _bundle(self, messages.Bundle bundle) except -1

cdef Address lo_address_to_address(lo.lo_address lo_address)