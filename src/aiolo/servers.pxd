# cython: language_level=3

from . cimport abstractservers, lo

cdef class Server(abstractservers.AbstractServer):
    # private
    cdef object sock
    cdef lo.lo_server _lo_server

    cdef void lo_server_start(self)
    cdef void lo_server_stop(self)
    cdef void _on_sock_readable(Server self, object loop)
