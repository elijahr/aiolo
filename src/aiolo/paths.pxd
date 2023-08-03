# cython: language_level=3

from . cimport abstractspecs


cdef class Path(abstractspecs.AbstractSpec):
    cdef public object pattern


cdef Path _ANY_PATH
