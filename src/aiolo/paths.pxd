# cython: language_level=3

from . cimport abstractspecs


cdef class Path(abstractspecs.AbstractSpec):
    cpdef public object pattern


cpdef Path _ANY_PATH
