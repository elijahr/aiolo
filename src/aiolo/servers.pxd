# cython: language_level=3

cimport cython

from . cimport lo


@cython.no_gc_clear
cdef class Server:
    cdef public dict routing
    cdef lo.lo_server lo_server
    cpdef public str url
    cdef object sock

cdef void on_error(int num, const char *msg, const char *path) nogil

cdef int router(
    const char *path,
    const char *argtypes,
    lo.lo_arg ** argv,
    int argc,
    lo.lo_message raw_msg,
    void *_route
) nogil except 1