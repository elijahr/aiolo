# cython: language_level=3

from . cimport abstractservers

cdef class AioServer(abstractservers.AbstractServer):
    # private
    cdef object sock

    cdef int lo_server_start(self) except -1
    cdef int lo_server_stop(self) except -1
    cdef void _on_sock_readable(AioServer self)
