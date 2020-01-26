# cython: language_level=3

from cpython cimport array
import array

cdef class AbstractSpec:
    cpdef public array.array array
    cpdef public bint none
