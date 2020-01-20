# cython: language_level=3


from . cimport lo, multicasts

cdef char * NO_IFACE
cdef char * NO_IP

cdef class Server:
    cdef public dict routing
    cdef lo.lo_server lo_server
    cpdef public str url
    cdef object sock
    cdef multicasts.MultiCast multicast

    cdef void _server_recv_noblock(Server self, object loop, bint retry)

cdef void on_error(int num, const char *msg, const char *path) nogil

cdef int router(
    const char *path,
    const char *argtypes,
    lo.lo_arg ** argv,
    int argc,
    lo.lo_message raw_msg,
    void *_route
) nogil except 1