# cython: language_level=3

from typing import Any

from cpython cimport array
import array

from . import routes, types
from . cimport addresses, typespecs, lo, timetags


__all__ = ['Message']


cdef array.array MESSAGE_ARRAY_TEMPLATE = array.array('B')


cdef class Message:
    def __cinit__(self, route: types.RouteTypes, *args: types.MessageTypes):
        cdef typespecs.TypeSpec typespec
        if not isinstance(route, routes.Route):
            typespec = typespecs.TypeSpec.guess(args)
            route = routes.Route(route, typespec)
        elif route.typespec.matches_any:
            typespec = typespecs.TypeSpec.guess(args)
        else:
            typespec = <typespecs.TypeSpec>route.typespec

        self.route = route
        self.typespec = typespec
        self.lo_message = typespec.pack_lo_message(args)

    def __init__(Message self, route: types.RouteTypes, *data):
        pass

    def __repr__(Message self):
        return 'Message(%r, %r)' % (self.route, self.unpack())

    def __hash__(self):
        return hash(b'Message:' + bytes(self.raw()))

    def __eq__(Message self, other: Any) -> bool:
        if not isinstance(other, Message):
            return False
        cdef message = <Message>other
        return self.raw() == other.raw()

    def __add__(Message self, other: types.BundleTypes):
        from aiolo import Bundle
        return Bundle(self).add(other)

    @property
    def source(self):
        return addresses.lo_address_to_address(lo.lo_message_get_source(self.lo_message))

    @property
    def timetag(self):
        return timetags.lo_timetag_to_timetag(lo.lo_message_get_timestamp(self.lo_message))

    def unpack(Message self) -> list:
        cdef:
            int argc = lo.lo_message_get_argc(self.lo_message)
            lo.lo_arg** argv = lo.lo_message_get_argv(self.lo_message)
        return (<typespecs.TypeSpec>self.typespec).unpack_args(argv, argc)

    def raw(Message self) -> array.array:
        cdef:
            size_t length
            array.array arr
            char * path = NULL

        if not self.route.path.matches_any:
            bpath = self.route.path.as_bytes
            path = bpath

        length = lo.lo_message_length(self.lo_message, path)
        arr = array.clone(MESSAGE_ARRAY_TEMPLATE, length, zero=True)
        lo.lo_message_serialise(self.lo_message, path, <void*>arr.data.as_voidptr, &length)
        return arr
    #
    # @classmethod
    # def from_raw(cls, route: routes.Route, data: array.array) -> Message:
    #

# cdef Message lo_message_to_message(object route, lo.lo_message lo_message):
#     cdef:
#         size_t length
#         array.array arr
#         char * path = NULL
#
#     if not route.path.matches_any:
#         bpath = route.path.as_bytes
#         path = bpath
#
#     length = lo.lo_message_length(lo_message, path)
#     arr = array.clone(MESSAGE_ARRAY_TEMPLATE, length, zero=True)
#     lo.lo_message_serialise(lo_message, path, <void*>arr.data.as_voidptr, &length)
#     return Message.from_raw(route, arr)

