# cython: language_level=3

from . cimport lo

cdef class Server:
    cdef dict routing
    cdef lo.lo_server lo_server
    cdef str url
    cdef object sock


cdef void on_error(int num, const char *msg, const char *path) nogil


cdef int router(
    const char *path,
    const char *lotypes,
    lo.lo_arg ** argv,
    int argc,
    lo.lo_message raw_msg,
    void *_route
) nogil