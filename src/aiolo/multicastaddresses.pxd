# cython: language_level=3

from . cimport addresses, servers

cdef class MultiCastAddress(addresses.Address):
    cdef public servers.Server server
