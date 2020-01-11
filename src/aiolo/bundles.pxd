# cython: language_level=3

from . cimport lo
from . cimport messages


cdef class Bundle:
    cdef object timetag
    cdef lo.lo_bundle lo_bundle
    cdef list msgs

    cpdef void add_message(Bundle self, messages.Message message)
