# cython: language_level=3

import asyncio
import socket

from cpython.ref cimport Py_INCREF, Py_DECREF


from . import exceptions, logs, routes, typedefs
from . cimport argdefs, lo, paths


cdef class Server:
    def __cinit__(self, *, url: str):
        self.url = url
        self.routing = {}
        self.lo_server = NULL

    def __init__(self, *, url: str):
        pass

    def __dealloc__(self):
        # objects are retained by no_gc_clear so that we can properly
        # cleanup the socket and stolen route references when this
        # instance is garbage collected
        if self.running:
            self.stop()

    def __repr__(self):
        return 'Server(%r)' % self.url

    @property
    def running(self):
        return self.lo_server is not NULL

    @property
    def port(self):
        burl = self.url.encode('utf8')
        return lo.lo_url_get_port(burl)

    def start(self):
        if self.running:
            raise exceptions.StartError('Server already running, cannot start again')
        burl = self.url.encode('utf8')
        self.lo_server = lo.lo_server_new_from_url(burl, on_error)
        if self.lo_server is NULL:
            raise MemoryError

        for route in self.routing.values():
            self._add_route(route)

        self.sock = socket.socket(fileno=lo.lo_server_get_socket_fd(self.lo_server))
        loop = asyncio.get_event_loop()
        loop.add_reader(self.sock, self._on_sock_ready)
        logs.logger.debug('%r: started, listening on %r', self, loop)

    def stop(self):
        if not self.running:
            raise exceptions.StopError('Server not started, cannot stop')
        lo.lo_server_free(self.lo_server)
        self.lo_server = NULL
        for route in self.routing.values():
            Py_DECREF(route)
        try:
            self.sock.close()
        except OSError:
            pass
        self.sock = None
        logs.logger.debug('%r: stopped', self)

    def route(self, route: routes.RouteTypes, argdef: typedefs.ArgdefTypes = None) -> routes.Route:
        """
        Create a route for this server
        """
        if isinstance(route, routes.Route):
            if argdef:
                raise ValueError("Cannot provide route and argtypes together")
            path = <paths.Path>route.path
            argdef = <argdefs.Argdef>route.argdef
        else:
            path = paths.Path(route)
            argdef = argdefs.Argdef(argdef)
            route = None
        key = route_key(path, argdef)
        try:
            return self.routing[key]
        except KeyError:
            if route is None:
                route = routes.Route(path, argdef)
            if route.is_pattern:
                raise ValueError('Cannot add pattern route %r as method definition' % route)
            if self.running:
                self._add_route(route)
            self.routing[key] = route
            return route

    def unroute(self, route: routes.RouteTypes, argdef: typedefs.ArgdefTypes = None) -> routes.Route:
        if isinstance(route, routes.Route):
            if argdef:
                raise ValueError("Cannot provide route and argdef together")
            path = <paths.Path>route.path
            argdef = <argdefs.Argdef>route.argdef
        else:
            path = paths.Path(route)
            argdef = argdefs.Argdef(argdef)
            route = None
        key = route_key(path, argdef)
        try:
            route = self.routing[key]
        except KeyError:
            pass
        else:
            del self.routing[key]
            if self.running:
                self._del_route(route)
        return route

    def _on_sock_ready(self):
        logs.logger.debug('%r: incoming data on socket', self)
        while True:
            count = lo.lo_server_recv_noblock(self.lo_server, 0)
            if count == 0:
                break
            logs.logger.debug('%r: processed %r bytes', self, count)

    def _add_route(self, route: routes.Route):
        cdef:
            char * path = (<paths.Path>route.path).charp()
            char * argdef = (<argdefs.Argdef>route.argdef).charp()
        # Steal a ref
        Py_INCREF(route)
        lo.lo_server_add_method(
            self.lo_server,
            path,
            argdef,
            <lo.lo_method_handler>router,
            <void*>route)
        logs.logger.debug('%r: added route %r' % (self, route))

    def _del_route(self, route: routes.Route):
        cdef:
            char * path = (<paths.Path>route.path).charp()
            char * argdef = (<argdefs.Argdef>route.argdef).charp()
        lo.lo_server_del_method(
            self.lo_server,
            path,
            argdef,
        )
        # Unsteal the ref
        Py_DECREF(route)
        logs.logger.debug('%r: removed route %r' % (self, route))


def route_key(path: paths.Path, argdef: argdefs.Argdef):
    return '%r:%r' % (path, argdef)


cdef void on_error(int num, const char *msg, const char *path) nogil:
    with gil:
        m = (<bytes>msg)
        m = m.decode('utf8')
        logs.logger.error("liblo server error %s: %s" % (num, m))


cdef int router(
    const char *path,
    const char *argtypes,
    lo.lo_arg ** argv,
    int argc,
    lo.lo_message raw_msg,
    void *_route
) nogil except 1:
    cdef int retval = 0
    with gil:
        route = <object>_route
        try:
            data = argdefs.Argdef(argtypes).unpack_args(argv, argc)
            logs.logger.debug('%r: received message %r', route, data)
            route.pub(data)
        except BaseException as exc:
            logs.logger.exception(exc)
            retval = 1
            raise
    return retval