# cython: language_level=3


from . cimport argdefs, lo, multicasts, paths

cdef char * NO_IFACE
cdef char * NO_IP


cdef class AbstractServer:
    # public
    cpdef public str url
    cpdef public multicasts.MultiCast multicast

    # private
    cdef bint _queue_enabled
    cdef dict routing

    cdef lo.lo_server lo_server(self)
    cdef void lo_server_start(self)
    cdef void lo_server_stop(self)

cdef str route_key(paths.Path path, argdefs.Argdef argdef)

cdef object pop_server_start_error()

cdef void set_server_start_error(str msg)

cdef void on_error(int num, const char *m, const char *p) nogil

cdef int router(
    const char *path,
    const char *argtypes,
    lo.lo_arg ** argv,
    int argc,
    lo.lo_message raw_msg,
    void *_route
) nogil except 1
