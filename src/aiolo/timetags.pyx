# cython: language_level=3

import datetime
from typing import Union

from libc.stdint cimport uint32_t
from libc.stdlib cimport malloc, free


from . import typedefs
from . cimport lo


EPOCH = datetime.datetime.utcfromtimestamp(0)


cdef class TimeTag:
    def __cinit__(self, timetag: typedefs.TimeTagTypes = None):
        if timetag is None:
            timetag = datetime.datetime.utcnow()
        if isinstance(timetag, datetime.datetime):
            timetag = (timetag - EPOCH).total_seconds()
        # The number of seconds since Jan 1st 1900 in the UTC timezone.
        sec = int(timetag)
        # The fractions of a second offset from above, expressed as 1/2^32nds of a second
        frac = (timetag % 1) / (1 / 2 ** 32)
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
    def timestamp(self) -> float:
        return float(self)

    @property
    def dt(self) -> datetime.datetime:
        return datetime.datetime.utcfromtimestamp(self.timestamp)

    def __int__(self):
        return int(float(self))

    def __float__(self):
        return lo_timetag_to_timestamp(self.lo_timetag)

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

    def __add__(self, other):
        if not isinstance(other, (int, float, datetime.timedelta)):
            raise ValueError('Can only add int, float, or timedelta to TimeTag, got %s' % type(other))
        if isinstance(other, datetime.timedelta):
            other = other.total_seconds()
        return self.__class__(self.timestamp + other)

    @classmethod
    def from_timetag_parts(cls, sec: int, frac: int):
        return TimeTag(timetag_parts_to_timestamp(sec, frac))


cdef float lo_timetag_to_timestamp(lo.lo_timetag lo_timetag):
    return timetag_parts_to_timestamp(lo_timetag.sec, lo_timetag.frac)


cpdef float timetag_parts_to_timestamp(int sec, int frac):
    return sec + ((<float>frac) * (1/2**32))
