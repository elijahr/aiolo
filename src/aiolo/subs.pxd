# cython: language_level=3

from . cimport routes


cdef class Sub:
    cdef object inbox
    cdef public routes.Route route


cdef class Subs:
    cdef set _subs


cdef class InboxCoro:
    cdef public Sub sub
    cdef public bint _asyncio_future_blocking