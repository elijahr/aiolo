# cython: language_level=3

import datetime
from typing import Tuple

from libc.stdint cimport uint32_t, uint64_t
from libc.stdlib cimport malloc, free


from . import typedefs
from . cimport lo

cdef uint32_t JAN_1970 = 0x83aa7e80

EPOCH_UTC = datetime.datetime.fromtimestamp(0, datetime.timezone.utc)
EPOCH_OSC = datetime.datetime(1900, 1, 1, 0, 0, 0, 0, datetime.timezone.utc)


cdef class TimeTag:
    def __cinit__(self, timetag: typedefs.TimeTagTypes = None):
        cdef lo.lo_timetag lo_timetag
        cdef uint32_t sec
        cdef uint32_t frac
        if timetag is None:
            lo_timetag = (<TimeTag>TT_IMMEDIATE).lo_timetag
            sec = lo_timetag.sec
            frac = lo_timetag.frac
        else:
            if isinstance(timetag, datetime.datetime):
                if not timetag.tzinfo:
                    raise ValueError('datetime value for timetag must have tzinfo')
                timetag = timetag.astimezone(datetime.timezone.utc).timestamp()

            # The number of seconds since Jan 1st 1900 in the UTC timezone.
            sec = int(timetag) + JAN_1970
            # The fractions of a second offset from above, expressed as 1/2^32nds of a second
            frac = int((timetag % 1) * 4294967295)
        self.lo_timetag_p = <lo.lo_timetag*>malloc(sizeof(lo.lo_timetag))
        if self.lo_timetag_p is NULL:
            raise MemoryError
        self.lo_timetag = self.lo_timetag_p[0]
        self.lo_timetag.sec = sec
        self.lo_timetag.frac = frac

    def __init__(self, timestamp: typedefs.TimeTagTypes = None):
        pass

    def __dealloc__(self):
        free(self.lo_timetag_p)

    def __repr__(self):
        return 'TimeTag(%r)' % self.dt

    @property
    def timestamp(self) -> float:
        return lo_timetag_to_timestamp(self.lo_timetag)

    @property
    def dt(self) -> datetime.datetime:
        return datetime.datetime.fromtimestamp(
            lo_timetag_to_timestamp(self.lo_timetag),
            datetime.timezone.utc
        )

    def __int__(self):
        return int(lo_timetag_to_timestamp(self.lo_timetag))

    def __float__(self):
        return lo_timetag_to_timestamp(self.lo_timetag)

    def __lt__(self, other):
        if not isinstance(other, TimeTag):
            other = TimeTag(other)
        return self.timestamp < other.timestamp

    def __le__(self, other):
        if not isinstance(other, TimeTag):
            other = TimeTag(other)
        return self.timestamp <= other.timestamp

    def __eq__(self, other):
        if not isinstance(other, TimeTag):
            other = TimeTag(other)
        return self.timestamp == other.timestamp

    def __ne__(self, other):
        if not isinstance(other, TimeTag):
            other = TimeTag(other)
        return self.timestamp != other.timestamp

    def __gt__(self, other):
        if not isinstance(other, TimeTag):
            other = TimeTag(other)
        return self.timestamp > other.timestamp

    def __ge__(self, other):
        if not isinstance(other, TimeTag):
            other = TimeTag(other)
        return self.timestamp >= other.timestamp

    def __add__(self, other):
        if not isinstance(other, (int, float, datetime.timedelta)):
            raise ValueError('Can only add int, float, or timedelta to TimeTag, got %s' % type(other))
        if isinstance(other, datetime.timedelta):
            other = other.total_seconds()
        return self.__class__(self.timestamp + other)

    @property
    def timetag_parts(self) -> Tuple[int, int]:
        return self.lo_timetag.sec, self.lo_timetag.frac

    @classmethod
    def from_timetag_parts(cls, sec: int, frac: int) -> TimeTag:
        return cls(timetag_parts_to_timestamp(sec, frac))


cdef double lo_timetag_to_timestamp(lo.lo_timetag lo_timetag):
    return timetag_parts_to_timestamp(lo_timetag.sec, lo_timetag.frac)


cpdef double timetag_parts_to_timestamp(uint32_t sec, uint32_t frac):
    return (int(sec) - JAN_1970) + (float(frac) / 4294967295)


TT_IMMEDIATE = TimeTag.from_timetag_parts(0, 1)
