# cython: language_level=3

cimport cython

from . cimport bundles, lo, messages

@cython.no_gc
cdef class Address:

    # private
    cdef lo.lo_address lo_address
    cdef bint _no_delay
    cdef bint _stream_slip

    cpdef int send_bundle(Address self, bundles.Bundle bundle)
    cpdef int send_message(Address self, messages.Message message)