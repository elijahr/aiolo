# cython: language_level=3

IF not PYPY:
    from cpython cimport array

import array

cdef class AbstractSpec:
    IF PYPY:
        cdef public object array
    ELSE:
        cdef public array.array array
    cdef public bint none
