# cython: language_level=3

from typing import Any
from libc.stdlib cimport malloc, free

IF not PYPY:
    from cpython cimport array

import array

from . import routes, types
from . cimport addresses, typespecs, lo, timetags


__all__ = ['Message']


IF not PYPY:
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

    IF PYPY:
        def raw(Message self) -> array.array:
            cdef size_t length = lo.lo_message_length(self.lo_message, self.route.path.as_bytes)
            cdef void* raw = malloc(length)
            arr = array.array('B')
            lo.lo_message_serialise(self.lo_message, self.route.path.as_bytes, raw, &length)
            for i in range(length):
                arr.append((<char*>raw)[i])
            try:
                return arr
            finally:
                free(raw)
    ELSE:
        def raw(Message self) -> array.array:
            cdef size_t length = lo.lo_message_length(self.lo_message, self.route.path.as_bytes)
            cdef array.array arr = array.clone(MESSAGE_ARRAY_TEMPLATE, length, zero=True)
            lo.lo_message_serialise(self.lo_message, self.route.path.as_bytes, <void*>arr.data.as_voidptr, &length)
            return arr
