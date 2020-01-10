# cython: language_level=3

cdef class Route:
    cdef public str path
    cdef public str lotypes
    cdef public object subs
