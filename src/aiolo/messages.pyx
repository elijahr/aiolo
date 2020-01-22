# cython: language_level=3

from typing import Iterable

from . import routes, typedefs
from . cimport argdefs, midis, timetags


__all__ = ['Message']


cdef class Message:
    def __cinit__(self, route: typedefs.RouteTypes, *data: typedefs.MessageTypes):
        self.route = route if isinstance(route, routes.Route) else routes.Route(route, argdefs.guess_argtypes(data))
        self.data = tuple(flatten_message_data(data))
        self.lo_message = (<argdefs.Argdef>self.route.argdef).build_lo_message(self.data)

    def __init__(self, route: typedefs.RouteTypes, *data):
        pass

    def __repr__(self):
        return 'Message(%r, %r)' % (self.route, self.data)


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