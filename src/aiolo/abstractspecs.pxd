# cython: language_level=3

IF not PYPY:
    from cpython cimport array

import array

cdef class AbstractSpec:
    IF PYPY:
        cpdef public object array
    ELSE:
        cpdef public array.array array
    cpdef public bint none
