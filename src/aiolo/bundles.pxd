# cython: language_level=3

from . cimport lo
from . cimport messages
from . cimport timetags


cdef class Bundle:
    cdef object timetag
    cdef lo.lo_bundle lo_bundle
    cdef list msgs

    cpdef void add_message(Bundle self, messages.Message message)


cdef lo.lo_bundle bundle_new(timetags.TimeTag timetag)