# cython: language_level=3

from . cimport abstractspecs

cdef class Path(abstractspecs.AbstractSpec):
    pass


cpdef bint pattern_match(string, pattern)