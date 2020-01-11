# cython: language_level=3

import datetime
from typing import Union

from libc.stdint cimport uint32_t
from libc.stdlib cimport malloc, free


from . cimport lo


EPOCH = datetime.datetime.utcfromtimestamp(0)


cdef class TimeTag:
    def __cinit__(self, timestamp: Union[float, int]):
        # The number of seconds since Jan 1st 1900 in the UTC timezone.
        sec = int(timestamp)
        # The fractions of a second offset from above, expressed as 1/2^32nds of a second
        frac = (timestamp % 1) / (1/2**32)
        self.lo_timetag_p = <lo.lo_timetag*>malloc(sizeof(lo.lo_timetag))
        if self.lo_timetag_p is NULL:
            raise MemoryError
        self.lo_timetag = self.lo_timetag_p[0]
        self.lo_timetag.sec = <uint32_t>sec
        self.lo_timetag.frac = <uint32_t>frac

    def __init__(self, timestamp: Union[float]):
        pass

    def __dealloc__(self):
        free(self.lo_timetag_p)

    def __repr__(self):
        return 'TimeTag(%r)' % self.timestamp

    @property
    def timestamp(self):
        return timestamp_from_lo_timetag(self.lo_timetag)

    def __lt__(self, other):
        return self.timestamp < other.timestamp

    def __le__(self, other):
        return self.timestamp <= other.timestamp

    def __eq__(self, other):
        return self.timestamp == other.timestamp

    def __ne__(self, other):
        return self.timestamp != other.timestamp

    def __gt__(self, other):
        return self.timestamp > other.timestamp

    def __ge__(self, other):
        return self.timestamp >= other.timestamp

    @classmethod
    def from_datetime(cls, dt: datetime.datetime):
        timestamp = (dt - EPOCH).total_seconds()
        return TimeTag(timestamp)


cdef int timestamp_from_lo_timetag(lo.lo_timetag lo_timetag):
    return lo_timetag.sec + ((<float>lo_timetag.frac) * (1/2**32))
