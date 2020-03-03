# cython: language_level=3

from typing import Any, Iterable, Union, Iterator

from libc.stdlib cimport malloc, free

cimport cython

IF not PYPY:
    from cpython cimport array

import array

from .timetags import TT_IMMEDIATE

from . import routes, types
from . cimport lo, paths, timetags, typespecs, pack


__all__ = ['Bundle', 'Message']


IF not PYPY:
    cdef array.array BUNDLE_ARRAY_TEMPLATE = array.array('B')
    cdef array.array MESSAGE_ARRAY_TEMPLATE = array.array('b')


@cython.freelist(10)
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
        self.lo_message = pack.pack_lo_message(typespec, args)

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
    def timetag(self):
        return timetags.lo_timetag_to_timetag(lo.lo_message_get_timestamp(self.lo_message))

    def unpack(Message self) -> list:
        cdef:
            int argc = lo.lo_message_get_argc(self.lo_message)
            lo.lo_arg** argv = lo.lo_message_get_argv(self.lo_message)
        return pack.unpack_args(<typespecs.TypeSpec>self.typespec, argv, argc)

    IF PYPY:
        def raw(Message self) -> array.array:
            cdef size_t length = lo.lo_message_length(self.lo_message, self.route.path.as_bytes)
            cdef void* raw = malloc(length)
            arr = array.array('b')
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


@cython.freelist(10)
cdef class Bundle:
    def __cinit__(
        self,
        msgs: Iterable[types.BundleTypes, None] = None,
        timetag: types.TimeTagTypes = None
    ):
        if timetag is None:
            # optimization, re-use TT_IMMEDIATE rather than construct a new one
            timetag = TT_IMMEDIATE
        elif not isinstance(timetag, timetags.TimeTag):
            timetag = timetags.TimeTag(timetag)
        self.timetag = timetag
        self.lo_bundle = lo.lo_bundle_new((<timetags.TimeTag>timetag).lo_timetag)
        if self.lo_bundle is NULL:
            raise MemoryError
        self.msgs = []
        if isinstance(msgs, messages.Message):
            self.add_message(msgs)
        elif msgs:
            for msg in msgs:
                self.add(msg)

    def __init__(
        self,
        msgs: Iterable[types.BundleTypes, None] = None,
        timetag: types.TimeTagTypes = None
    ):
        pass

    def __dealloc__(Bundle self):
        lo.lo_bundle_free(self.lo_bundle)

    def __repr__(Bundle self):
        return 'Bundle(%r, %r)' % (self.msgs, self.timetag)

    def __hash__(self):
        return hash(b'Bundle:' + bytes(self.raw()))

    def __eq__(Bundle self, other: Any) -> bool:
        if not isinstance(other, Bundle):
            return False
        return self.timetag == (<Bundle>other).timetag \
               and self.msgs == (<Bundle>other).msgs

    def __lt__(Bundle self, other: Any) -> bool:
        if not isinstance(other, Bundle):
            return False
        return self.timetag < (<Bundle>other).timetag

    def __gt__(Bundle self, other: Any) -> bool:
        if not isinstance(other, Bundle):
            return False
        return self.timetag > (<Bundle>other).timetag

    def __le__(Bundle self, other: Any) -> bool:
        if not isinstance(other, Bundle):
            return False
        return self.timetag <= (<Bundle>other).timetag

    def __ge__(Bundle self, other: Any) -> bool:
        if not isinstance(other, Bundle):
            return False
        return self.timetag >= (<Bundle>other).timetag

    def __add__(Bundle self, other: types.BundleTypes):
        return Bundle((<Bundle>self).msgs, self.timetag).add(other)

    def __len__(Bundle self) -> int:
        return lo.lo_bundle_count(self.lo_bundle)

    def __iter__(Bundle self) -> Iterator:
        return iter((<Bundle>self).msgs)

    def __getitem__(Bundle self, item) -> Union[Bundle, messages.Message]:
        return (<Bundle>self).msgs[item]

    IF PYPY:
        def raw(Bundle self) -> array.array:
            cdef size_t length = lo.lo_bundle_length(self.lo_bundle)
            cdef void* raw = malloc(length)
            arr = array.array('b')
            lo.lo_bundle_serialise(self.lo_bundle, raw, &length)
            for i in range(length):
                arr.append((<char*>raw)[i])
            try:
                return arr
            finally:
                free(raw)
    ELSE:
        def raw(Bundle self) -> array.array:
            cdef size_t length = lo.lo_bundle_length(self.lo_bundle)
            cdef array.array arr = array.clone(BUNDLE_ARRAY_TEMPLATE, length, zero=True)
            lo.lo_bundle_serialise(self.lo_bundle, <void*>arr.data.as_voidptr, &length)
            return arr

    cpdef object add(Bundle self, msg: types.BundleTypes):
        if isinstance(msg, messages.Message):
            self.add_message(msg)
        elif isinstance(msg, Bundle):
            self.add_bundle(msg)
        else:
            try:
                for item in msg:
                    if not isinstance(item, (Bundle, messages.Message)):
                        raise TypeError('Cannot add %s' % repr(item))
                    self.add(item)
            except TypeError:
                raise TypeError('Cannot add %s to bundle' % repr(msg))
        return self

    cpdef object add_message(Bundle self, messages.Message message):
        path = (<paths.Path>message.route.path).as_bytes
        cdef char * p = path
        if lo.lo_bundle_add_message(
            self.lo_bundle,
            p,
            (<messages.Message>message).lo_message
        ) != 0:
            raise MemoryError
        self.msgs.append(message)
        return None

    cpdef object add_bundle(Bundle self, Bundle bundle):
        if self.lo_bundle == bundle.lo_bundle:
            raise ValueError('Cannot add bundle to itself')
        if lo.lo_bundle_add_bundle(self.lo_bundle, bundle.lo_bundle) != 0:
            raise MemoryError
        self.msgs.append(bundle)
        return None
