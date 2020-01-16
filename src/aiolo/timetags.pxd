# cython: language_level=3

from . cimport lo

cdef class TimeTag:
    cdef lo.lo_timetag * lo_timetag_p
    cdef lo.lo_timetag lo_timetag

cdef float lo_timetag_to_timestamp(lo.lo_timetag lo_timetag)

cpdef float timetag_parts_to_timestamp(int sec, int frac)