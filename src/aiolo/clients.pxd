# cython: language_level=3

cimport cython

from . cimport addresses


@cython.no_gc
cdef class Client(addresses.Address):
    pass