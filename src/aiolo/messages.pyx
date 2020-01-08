# cython: language_level=3


from . cimport lo
from . cimport routes
from . cimport utils


cdef class Message:
    def __cinit__(self, route: routes.Route, *data):
        self.route = route
        self.lo_message = utils.pyargs_to_lomessage(route.lotypes, data)

    def __init__(self, route: routes.Route, *data):
        pass

    def __repr__(self):
        return 'Message(%r)' % self.route

    def __dealloc__(self):
        if self.lo_message is not NULL:
            lo.lo_message_free(self.lo_message)

