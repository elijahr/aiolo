# cython: language_level=3

from . cimport abstractservers, addresses

cdef class MultiCastAddress(addresses.Address):
    cdef public abstractservers.AbstractServer server
