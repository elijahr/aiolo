# cython: language_level=3

from libc.stdint cimport uint32_t

from . cimport lo

cdef uint32_t _JAN_1970
cdef uint32_t _FRAC_PER_SEC


cdef class FrozenTimeTag:
    cdef lo.lo_timetag * lo_timetag_p
    cdef lo.lo_timetag lo_timetag

cdef class TimeTag(FrozenTimeTag):
    pass


# Not exported to Python
cdef lo.lo_timetag * timetag_to_lo_timetag_ptr(object timetag) except NULL

cdef lo.lo_timetag * timetag_parts_to_lo_timetag_ptr(uint32_t sec, uint32_t frac) except NULL

cdef lo.lo_timetag * copy_lo_timetag_ptr(lo.lo_timetag * orig) except NULL

cdef double lo_timetag_to_unix_timestamp(lo.lo_timetag lo_timetag)

cdef double lo_timetag_to_osc_timestamp(lo.lo_timetag lo_timetag)


# Exported to Python
cpdef double timetag_parts_to_unix_timestamp(uint32_t sec, uint32_t frac)

cpdef double timetag_parts_to_osc_timestamp(uint32_t sec, uint32_t frac)

cpdef double osc_timestamp_to_unix_timestamp(double osc_timestamp)

cpdef double unix_timestamp_to_osc_timestamp(double unix_timestamp)

cpdef object osc_timestamp_to_timetag_parts(double osc_timestamp)

cpdef object unix_timestamp_to_timetag_parts(double unix_timestamp)
