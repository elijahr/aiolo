# cython: language_level=3

import datetime
from typing import Iterable, Union

from . cimport timetags
from . cimport messages
from . cimport lo


cdef class Bundle:
    def __cinit__(
            self,
            msgs: Iterable[messages.Message] = None,
            timetag: Union[timetags.TimeTag, datetime.datetime, float, None] = None
    ):
        if timetag is None:
            timetag = datetime.datetime.now()
        if isinstance(timetag, datetime.datetime):
            timetag = timetags.TimeTag.from_datetime(timetag)
        self.timetag = timetag
        self.lo_bundle = bundle_new(timetag)
        if self.lo_bundle is NULL:
            raise MemoryError
        self.msgs = []
        if msgs:
            for msg in msgs:
                self.add_message(msg)

    def __init__(
            self,
            msgs: Iterable[messages.Message] = None,
            timetag: Union[timetags.TimeTag, datetime.datetime, float, None] = None
    ):
        pass

    def __repr__(self):
        return 'Bundle(%r, %r)' % (self.msgs, self.timetag)

    cpdef void add_message(Bundle self, messages.Message message):
        if lo.lo_bundle_add_message(self.lo_bundle, message.route.bpath, message.lo_message()) != 0:
            raise MemoryError
        self.msgs.append(message)

    def __dealloc__(self):
        lo.lo_bundle_free(self.lo_bundle)


cdef lo.lo_bundle bundle_new(timetags.TimeTag timetag):
    return lo.lo_bundle_new(timetag.lo_timetag)