# cython: language_level=3

cdef class MultiCast:
    cdef bytes _group
    cdef bytes _port
    cdef bytes _iface
    cdef bytes _ip