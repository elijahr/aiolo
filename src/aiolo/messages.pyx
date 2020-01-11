# cython: language_level=3


from . cimport lo
from . import routes
from . cimport utils


cdef class Message:
    def __cinit__(self, route: routes.Route, *data):
        self.route = route
        self.data = data

    def __init__(self, route: routes.Route, *data):
        pass

    def __repr__(self):
        return 'Message(%r, *%r)' % (self.route, self.data)

    cdef lo.lo_message lo_message(self):
        return utils.pyargs_to_lomessage(self.route.lotypes, self.data)
