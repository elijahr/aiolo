# cython: language_level=3

from typing import Iterable

from . import exceptions, logs, routes, typedefs
from . cimport argdefs, lo, midis, paths, timetags


cdef class Message:
    def __cinit__(self, route: typedefs.RouteTypes, *data: typedefs.MessageTypes):
        self.route = route if isinstance(route, routes.Route) else routes.Route(route)
        self.data = tuple(flatten_message_data(data))
        self.lo_message = (<argdefs.Argdef>self.route.argdef).build_lo_message(self.data)

    def __init__(self, route: typedefs.RouteTypes, *data):
        pass

    def __repr__(self):
        return 'Message(%r, %r)' % (self.route, self.data)

    cdef object send(self, lo.lo_address lo_address):
        if self.route.path.matches_any:
            raise ValueError('Message must be sent to a specific path or pattern')
        logs.logger.debug('%r: sending', self)
        count = lo.lo_send_message(
            lo_address,
            (<paths.Path>self.route.path).charp(),
            self.lo_message
        )
        if lo.lo_address_errno(lo_address):
            raise exceptions.SendError(
                '%s (%s)' % ((<bytes>lo.lo_address_errstr(lo_address)).decode('utf8'),
                             str(lo.lo_address_errno(lo_address))))
        if count <= 0:
            raise exceptions.SendError(count)
        logs.logger.debug('%r: sent %s bytes', self, count)
        return count


BASIC_TYPES = (
    str,
    bytes,
    bytearray,
    int,
    bool,
    float,
    type(None),
    timetags.TimeTag,
    midis.Midi,
)


def flatten_message_data(data: Iterable) -> list:
    items = []
    try:
        for item in data:
            if isinstance(item, BASIC_TYPES):
                items.append(item)
            else:
                items += flatten_message_data(item)
    except TypeError:
        # not iterable
        items.append(data)
    return items