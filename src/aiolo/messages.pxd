# cython: language_level=3

from . cimport addresses, lo, servers

cdef class Message:
    cdef public object route
    cdef tuple data
    cdef lo.lo_message lo_message
    cpdef int send_from(Message self, addresses.Address address, servers.Server server)
    cpdef int send(Message self, addresses.Address address)

