# cython: language_level=3

from typing import Iterable, Union, Iterator, Any
from libc.stdlib cimport malloc, free

cimport cython

IF not PYPY:
    from cpython cimport array

import array

from .timetags import TT_IMMEDIATE
from . import types
from . cimport lo, messages, paths, timetags


IF not PYPY:
    cdef array.array BUNDLE_ARRAY_TEMPLATE = array.array('B')

__all__ = ['Bundle']


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
        if isinstance(msgs, messages.Message):
            self.msgs = [msgs]
        else:
            self.msgs = []
            if msgs:
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

    def __iadd__(Bundle self, other: types.BundleTypes):
        return self.add(other)

    def __len__(Bundle self) -> int:
        return len((<Bundle>self).msgs)

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
