# cython: language_level=3


from . cimport abstractservers, lo


cdef class ThreadedServer(abstractservers.AbstractServer):
    # private
    cdef lo.lo_server_thread lo_server_thread
    cdef object initialized_event

    cdef int lo_server_start(self) except -1
    cdef int lo_server_stop(self) except -1


cdef int server_thread_init(lo.lo_server_thread s, void* user_data) nogil

cdef void server_thread_cleanup(lo.lo_server_thread s, void* user_data) nogil