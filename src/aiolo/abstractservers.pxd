# cython: language_level=3


from . cimport typespecs, lo, multicasts, paths

cdef char * NO_IFACE
cdef char * NO_IP


cdef class AbstractServer:
    # private
    cdef str _url
    cdef str _port
    cdef int _proto
    cdef multicasts.MultiCast _multicast
    cdef bint _queue_enabled
    cdef dict routing
    cdef object startstoplock
    cdef lo.lo_server lo_server

    cdef int lo_server_start(self) except -1
    cdef int lo_server_stop(self) except -1

cdef object pop_server_start_error()

cdef void set_server_start_error(str msg)

cdef void on_error(int num, const char *m, const char *p) nogil

cdef int router(
    const char *path,
    const char *typespec_array,
    lo.lo_arg ** argv,
    int argc,
    lo.lo_message raw_msg,
    void *_route
) nogil except 1
