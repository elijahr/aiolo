# cython: language_level=3

from . cimport lo

cdef class TimeTag:
    cdef lo.lo_timetag * lo_timetag_p
    cdef lo.lo_timetag lo_timetag