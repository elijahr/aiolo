# cython: language_level=3

cdef class MultiCast:
    cdef char * _group
    cdef char * _port
    cdef char * _iface
    cdef char * _ip