# cython: language_level=3

from . cimport bundles, lo, messages

cdef class Address:

    # private
    cdef lo.lo_address lo_address
    cdef bint _no_delay
    cdef bint _stream_slip

    cdef int _message(self, messages.Message bundle)
    cdef int _bundle(self, bundles.Bundle bundle)
