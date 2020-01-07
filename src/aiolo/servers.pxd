# cython: language_level=3

from . cimport lo

cdef class Server:
    cdef object routes
    cdef object running
    cdef lo.lo_server_thread _lo_server_thread
    cdef object loop


cdef void on_error(int num, const char *msg, const char *path) nogil


cdef int router(const char *path, const char *types, lo.lo_arg ** argv, int argc, void *data, void *user_data) nogil