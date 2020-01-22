# cython: language_level=3


from cpython.ref cimport Py_INCREF, Py_DECREF


from . import exceptions, logs, routes, typedefs
from . cimport  argdefs, lo, multicasts, paths

__all__ = ['AbstractServer']


_SERVER_START_ERROR = None


cdef char * NO_IFACE = <char*>0
cdef char * NO_IP = <char*>0


cdef class AbstractServer:
    def __cinit__(self, *, url: str = None, multicast: multicasts.MultiCast = None):
        if url and multicast:
            raise ValueError('Provide either url or multicast, not both (got %r, %r)' % (url, multicast))
        self.url = url
        self.multicast = multicast
        self.routing = {}
        self._queue_enabled = True # default is on

    def __init__(self, *, url: str = None, multicast: multicasts.MultiCast = None):
        pass

    def __repr__(self):
        if self.url:
            return '%s(url=%r)' % (self.__class__.__name__, self.url)
        return '%s(multicast=%r)' % (self.__class__.__name__, self.multicast)

    @property
    def running(self):
        return self.lo_server() is not NULL

    @property
    def port(self):
        if self.running:
            return lo.lo_server_get_port(self.lo_server())
        elif self.url:
            burl = self.url.encode('utf8')
            return lo.lo_url_get_port(burl)
        return self.multicast.port

    @property
    def protocol(self):
        if self.running:
            return lo.lo_server_get_protocol(self.lo_server())
        elif self.url:
            burl = self.url.encode('utf8')
            return lo.lo_url_get_protocol(burl)
        # multicast uses UDP, of course
        from aiolo import PROTO_UDP
        return PROTO_UDP

    @property
    def queue_enabled(self):
        return self._queue_enabled

    @queue_enabled.setter
    def queue_enabled(self, value):
        cdef bint val = bool(value)
        if self.running:
            lo.lo_server_enable_queue(self.lo_server(), val, val)
        self._queue_enabled = val

    def start(self):
        if self.running:
            raise exceptions.StartError('Server already running, cannot start again')
        self.lo_server_start()

        lo.lo_server_enable_queue(self.lo_server(), self.queue_enabled, 0)

        # Steal a ref for error_context
        Py_INCREF(self)
        lo.lo_server_set_error_context(self.lo_server(), <void*>self)
        for route in self.routing.values():
            self._add_route(route)

    def stop(self):
        if not self.running:
            raise exceptions.StopError('Server not started, cannot stop')
        self.lo_server_stop()
        for route in self.routing.values():
            Py_DECREF(route)
        # Unsteal the error_context ref
        Py_DECREF(self)
        logs.logger.debug('%r: stopped', self)

    def route(self, route: typedefs.RouteTypes, argdef: typedefs.ArgdefTypes = None) -> routes.Route:
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

    def unroute(self, route: typedefs.RouteTypes, argdef: typedefs.ArgdefTypes = None) -> routes.Route:
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

    @property
    def events_pending(self) -> bool:
        return bool(lo.lo_server_events_pending(self.lo_server()))

    @property
    def next_event_delay(self) -> float:
        return lo.lo_server_next_event_delay(self.lo_server())

    def _add_route(self, route: routes.Route):
        cdef:
            char * path = (<paths.Path>route.path).charp()
            char * argdef = (<argdefs.Argdef>route.argdef).charp()
        # Steal ref
        Py_INCREF(route)
        lo.lo_server_add_method(
            self.lo_server(),
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
            self.lo_server(),
            path,
            argdef)
        # Unsteal ref
        Py_DECREF(route)
        logs.logger.debug('%r: removed route %r' % (self, route))

    cdef lo.lo_server lo_server(self):
        raise NotImplementedError

    cdef void lo_server_start(self):
        raise NotImplementedError

    cdef void lo_server_stop(self):
        raise NotImplementedError


cdef str route_key(paths.Path path, argdefs.Argdef argdef):
    return '%r:%r' % (path, argdef)


cdef object pop_server_start_error():
    global _SERVER_START_ERROR
    try:
        return _SERVER_START_ERROR
    finally:
        _SERVER_START_ERROR = None


cdef void set_server_start_error(str msg):
    global _SERVER_START_ERROR
    _SERVER_START_ERROR = msg


cdef void on_error(int num, const char *m, const char *p) nogil:
    cdef void * error_context = lo.lo_error_get_context()
    with gil:
        msg = (<bytes>m).decode('utf8')
        if error_context is NULL:
            # This is an error during start, so no context has been set yet
            set_server_start_error(msg)
            msg = 'server start error %s: %s' % (num, msg)
        else:
            server = <AbstractServer>error_context
            msg = "%s: error %s: %s" % (server, num, msg)
        if p is not NULL:
            path = (<bytes>p).decode('utf8')
            msg += ' (%s)' % path
        logs.logger.error(msg)


cdef int router(
    const char *path,
    const char *argtypes,
    lo.lo_arg ** argv,
    int argc,
    lo.lo_message raw_msg,
    void *_route
) nogil except 1:
    cdef int retval = 0
    cdef lo.lo_timetag lo_timetag
    with gil:
        route = <object>_route
        try:
            data = argdefs.Argdef(argtypes).unpack_args(argv, argc)
            logs.logger.debug('%r: received message %r', route, data)
            route.pub_soon_threadsafe(data)
        except BaseException as exc:
            logs.logger.exception(exc)
            retval = 1
            raise
    return retval
