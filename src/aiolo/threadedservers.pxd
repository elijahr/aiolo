# cython: language_level=3


from . cimport abstractservers, lo


cdef class ThreadedServer(abstractservers.AbstractServer):
    # private
    cdef lo.lo_server_thread _lo_server_thread

    cdef void lo_server_start(self)
    cdef void lo_server_stop(self)


cdef int server_thread_init(lo.lo_server_thread s, void* user_data) nogil

cdef void server_thread_cleanup(lo.lo_server_thread s, void* user_data) nogil