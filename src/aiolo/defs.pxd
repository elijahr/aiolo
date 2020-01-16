# cython: language_level=3


cdef class Def:
    cdef object _str
    cdef object _bytes
    cdef char * charp(self)