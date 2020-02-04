# cython: language_level=3


cdef class Sub:
    cdef object inbox
    cdef public object route


cdef class Subs:
    cdef set _subs
