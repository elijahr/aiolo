# cython: language_level=3

from libc.stdint cimport uint32_t

from . cimport lo

cdef uint32_t JAN_1970

cdef class TimeTag:
    cdef lo.lo_timetag * lo_timetag_p
    cdef lo.lo_timetag lo_timetag

cdef double lo_timetag_to_timestamp(lo.lo_timetag lo_timetag)

cpdef double timetag_parts_to_timestamp(uint32_t sec, uint32_t frac)
