# cython: language_level=3

cdef class Route:
    cdef public str path
    cdef public str lotypes
    cdef list subs
    cdef object loop
