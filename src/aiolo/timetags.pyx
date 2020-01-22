# cython: language_level=3

import datetime
import operator
from typing import Tuple, Callable, Any, Union

from libc.stdint cimport uint32_t, uint64_t
from libc.stdlib cimport malloc, free


from . import typedefs
from . cimport lo


__all__ = [
    'JAN_1970', 'FRAC_PER_SEC', 'EPOCH_UTC', 'EPOCH_OSC',
    'FrozenTimeTag', 'TimeTag',
    'timetag_parts_to_unix_timestamp',
    'timetag_parts_to_osc_timestamp',
    'osc_timestamp_to_unix_timestamp',
    'unix_timestamp_to_osc_timestamp',
    'osc_timestamp_to_timetag_parts',
    'unix_timestamp_to_timetag_parts',
    'TT_IMMEDIATE',
]


# The number of seconds between midnight Jan 1 1900 UTC (OSC epoch) and midnight Jan 1 1970 UTC (UNIX epoch)
cdef uint32_t _JAN_1970 = 0x83aa7e80

JAN_1970 = _JAN_1970

# The number of `frac` per 1 second, approx 200 picoseconds
cdef uint32_t _FRAC_PER_SEC = 4294967295

FRAC_PER_SEC = _FRAC_PER_SEC

EPOCH_UTC = datetime.datetime.fromtimestamp(0, datetime.timezone.utc)
EPOCH_OSC = datetime.datetime(1900, 1, 1, 0, 0, 0, 0, datetime.timezone.utc)


cdef class FrozenTimeTag:
    def __cinit__(self, timetag: typedefs.TimeTagTypes = None):
        cdef lo.lo_timetag lo_timetag
        self.lo_timetag_p = timetag_to_lo_timetag_ptr(timetag)
        self.lo_timetag = self.lo_timetag_p[0]

    def __init__(self, timestamp: typedefs.TimeTagTypes = None):
        pass

    def __dealloc__(self):
        free(self.lo_timetag_p)

    def __repr__(self):
        return '%s(%s)' % (self.__class__.__name__, repr((self.sec, self.frac)))

    def __int__(self) -> int:
        return int(lo_timetag_to_osc_timestamp(self.lo_timetag))

    def __float__(self) -> float:
        return lo_timetag_to_osc_timestamp(self.lo_timetag)

    def __getitem__(self, index) -> int:
        if index == 0:
            return self.sec
        elif index == 1:
            return self.frac
        raise IndexError

    def __iter__(self) -> Tuple[int, int]:
        return iter((self.sec, self.frac))

    def operate(self, other: Union[int, float, datetime.timedelta], op: Callable) -> tuple:
        cdef double delta
        if isinstance(other, (int, float)):
            delta = other
        elif isinstance(other, datetime.timedelta):
            delta = other.total_seconds()
        else:
            raise ValueError('Invalid value for %r operation %s: %r' % (self.__class__.__name__, op.__name__, other))
        return osc_timestamp_to_timetag_parts(op(self.osc_timestamp, delta))

    def compare(self, other: typedefs.TimeTagTypes, op: Callable) -> bool:
        cdef double osc_timestamp
        if isinstance(other, tuple):
            osc_timestamp = timetag_parts_to_osc_timestamp(other[0], other[1])
        elif isinstance(other, FrozenTimeTag):
            osc_timestamp = other.osc_timestamp
        elif isinstance(other, (int, float)):
            osc_timestamp = other
        elif isinstance(other, datetime.datetime):
            if not other.tzinfo:
                raise ValueError('Cannot compare %r with naive datetime %r' % (self, other))
            osc_timestamp = unix_timestamp_to_osc_timestamp(other.timestamp())
        else:
            raise ValueError('Invalid value for %r compare operation: %r' % (self.__class__.__name__, other))
        return op(osc_timestamp_to_timetag_parts(self.osc_timestamp), osc_timestamp_to_timetag_parts(osc_timestamp))

    def __not__(self):
        return bool(self.osc_timestamp)

    def __abs__(self):
        return operator.abs(self.osc_timestamp)

    def __lt__(self, other: typedefs.TimeTagTypes) -> bool:
        return (<FrozenTimeTag>self).compare(other, operator.lt)

    def __le__(self, other: typedefs.TimeTagTypes) -> bool:
        return (<FrozenTimeTag>self).compare(other, operator.le)

    def __eq__(self, other: typedefs.TimeTagTypes) -> bool:
        return (<FrozenTimeTag>self).compare(other, operator.eq)

    def __ne__(self, other: typedefs.TimeTagTypes) -> bool:
        return (<FrozenTimeTag>self).compare(other, operator.ne)

    def __gt__(self, other: typedefs.TimeTagTypes) -> bool:
        return (<FrozenTimeTag>self).compare(other, operator.gt)

    def __ge__(self, other: typedefs.TimeTagTypes) -> bool:
        return (<FrozenTimeTag>self).compare(other, operator.ge)

    def __add__(self, other: Union[int, float, datetime.timedelta]) -> TimeTag:
        return TimeTag((<FrozenTimeTag>self).operate(other, operator.add))

    def __sub__(self, other: Union[int, float, datetime.timedelta]) -> TimeTag:
        return TimeTag((<FrozenTimeTag>self).operate(other, operator.sub))

    __radd__ = __add__
    __rsub__ = __sub__

    @property
    def unix_timestamp(self) -> float:
        return lo_timetag_to_unix_timestamp(self.lo_timetag)

    @property
    def osc_timestamp(self) -> float:
        return lo_timetag_to_osc_timestamp(self.lo_timetag)

    @property
    def dt(self) -> datetime.datetime:
        # Note that this conversion loses precision, since OSC timetags have 1/32 second precision,
        # but Python datetimes only have microsecond precision.
        return datetime.datetime.fromtimestamp(
            lo_timetag_to_unix_timestamp(self.lo_timetag),
            datetime.timezone.utc
        )

    @property
    def sec(self) -> int:
        return self.lo_timetag.sec

    @property
    def frac(self) -> int:
        return self.lo_timetag.frac


cdef class TimeTag(FrozenTimeTag):

    @property
    def sec(self) -> int:
        return self.lo_timetag.sec

    @sec.setter
    def sec(self, value: int):
        self.lo_timetag.sec = value

    @property
    def frac(self) -> int:
        return self.lo_timetag.frac

    @frac.setter
    def frac(self, value: int):
        self.lo_timetag.frac = value

    def __iadd__(self, other: Union[int, float, datetime.timedelta]) -> TimeTag:
        self.sec, self.frac = (<TimeTag>self).operate(other, operator.add)
        return self

    def __isub__(self, other: Union[int, float, datetime.timedelta]) -> TimeTag:
        self.sec, self.frac = (<TimeTag>self).operate(other, operator.sub)
        return self


cdef lo.lo_timetag * timetag_to_lo_timetag_ptr(object timetag) except NULL:
    cdef:
        uint32_t sec
        uint32_t frac
        object parts

    if timetag is None:
        # Optimization when None is passed, just copy from TT_IMMEDIATE
        return copy_lo_timetag_ptr((<FrozenTimeTag>TT_IMMEDIATE).lo_timetag_p)

    elif isinstance(timetag, (tuple, FrozenTimeTag)):
        parts = timetag

    elif isinstance(timetag, datetime.timedelta):
        # Indicates a time in the future, relative to right now
        delta = timetag
        dt = delta + datetime.datetime.now(datetime.timezone.utc)
        unix_timestamp = dt.astimezone(datetime.timezone.utc).timestamp()
        parts = unix_timestamp_to_timetag_parts(unix_timestamp)

    elif isinstance(timetag, datetime.datetime):
        if not timetag.tzinfo:
            raise ValueError('datetime value for timetag must have tzinfo')
        unix_timestamp = timetag.astimezone(datetime.timezone.utc).timestamp()
        parts = unix_timestamp_to_timetag_parts(unix_timestamp)

    elif isinstance(timetag, (int, float)):
        unix_timestamp = timetag
        parts = unix_timestamp_to_timetag_parts(unix_timestamp)

    else:
        raise ValueError('Invalid timetag value %s' % repr(timetag))

    sec, frac = parts[0], parts[1]
    return timetag_parts_to_lo_timetag_ptr(sec, frac)


cdef lo.lo_timetag * timetag_parts_to_lo_timetag_ptr(uint32_t sec, uint32_t frac) except NULL:
    lo_timetag_p = <lo.lo_timetag*>malloc(sizeof(lo.lo_timetag))
    if lo_timetag_p is NULL:
        raise MemoryError
    lo_timetag_p[0].sec = sec
    lo_timetag_p[0].frac = frac
    return lo_timetag_p


cdef lo.lo_timetag * copy_lo_timetag_ptr(lo.lo_timetag * orig) except NULL:
    return timetag_parts_to_lo_timetag_ptr(orig.sec, orig.frac)


cdef double lo_timetag_to_unix_timestamp(lo.lo_timetag lo_timetag):
    return timetag_parts_to_unix_timestamp(lo_timetag.sec, lo_timetag.frac)


cdef double lo_timetag_to_osc_timestamp(lo.lo_timetag lo_timetag):
    return timetag_parts_to_osc_timestamp(lo_timetag.sec, lo_timetag.frac)


cpdef double timetag_parts_to_unix_timestamp(uint32_t sec, uint32_t frac):
    return osc_timestamp_to_unix_timestamp(timetag_parts_to_osc_timestamp(sec, frac))


cpdef double timetag_parts_to_osc_timestamp(uint32_t sec, uint32_t frac):
    return int(sec) + (float(frac) / _FRAC_PER_SEC)


cpdef double osc_timestamp_to_unix_timestamp(double osc_timestamp):
    return osc_timestamp - JAN_1970


cpdef double unix_timestamp_to_osc_timestamp(double unix_timestamp):
    return unix_timestamp + JAN_1970


cpdef object osc_timestamp_to_timetag_parts(double osc_timestamp):
    # The number of seconds since Jan 1st 1900 in the UTC timezone.
    sec = int(osc_timestamp)
    # The fractions of a second offset from above, expressed as 1/2^32nds of a second
    frac = int((osc_timestamp % 1) * _FRAC_PER_SEC)
    return sec, frac


cpdef object unix_timestamp_to_timetag_parts(double unix_timestamp):
    return osc_timestamp_to_timetag_parts(unix_timestamp_to_osc_timestamp(unix_timestamp))


TT_IMMEDIATE = FrozenTimeTag((0, 1))
