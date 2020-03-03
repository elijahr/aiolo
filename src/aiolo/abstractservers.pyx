# cython: language_level=3

import functools
import threading
from typing import Union, Set

from cpython.ref cimport Py_INCREF, Py_DECREF

from . import exceptions, logs, protos, routes, types
from . cimport lo, multicasts, paths, typespecs, pack

__all__ = ['AbstractServer']


_SERVER_START_ERROR = None


cdef char * NO_IFACE = <char*>0
cdef char * NO_IP = <char*>0


cdef class AbstractServer:
    def __cinit__(
        self,
        *,
        url: Union[str, None] = None,
        port: Union[str, int, None] = None,
        proto: Union[str, int, None] = None,
        multicast: Union[multicasts.MultiCast, None] = None,
        **kwargs,
    ):
        url, port, proto, multicast = self._validate(url, port, proto, multicast)

        self._url = url
        self._port = port
        self._proto = proto
        self._multicast = multicast
        self._queue_enabled = True # default is on
        self.routing = {}
        self.startstoplock = threading.RLock()

    def __init__(
        self,
        *,
        url: Union[str, None] = None,
        port: Union[str, int, None] = None,
        proto: Union[str, int, None] = None,
        multicast: Union[multicasts.MultiCast, None] = None,
        **kwargs,
    ):
        pass

    def __repr__(self):
        if self._url:
            return '%s(url=%r)' % (self.__class__.__name__, self._url)
        elif self._proto:
            return '%s(port=%r, proto=%r)' % (self.__class__.__name__, self._port, self.proto_name)
        elif self._multicast:
            return '%s(multicast=%r)' % (self.__class__.__name__, self._multicast)
        return '%s(port=%r)' % (self.__class__.__name__, self._port)

    def _validate(
        self,
        url: Union[str],
        port: Union[str, int, None],
        proto: Union[str, int, None],
        multicast: multicasts.MultiCast,
    ):
        if self.running:
            raise ValueError('Cannot update server vars while server is running')
        if proto is not None and url is not None:
            raise ValueError('proto and url are invalid args together')
        elif proto is not None and multicast is not None:
            raise ValueError('proto and multicast are invalid args together')
        elif url is not None and multicast is not None:
            raise ValueError('url and multicast are invalid args together')
        elif port is not None and multicast is not None:
            raise ValueError('port and multicast are invalid args together')
        elif port is not None and url is not None:
            raise ValueError('port and url are invalid args together')

        if proto is None:
            proto = protos.PROTO_DEFAULT
        else:
            proto = protos.get_proto_id(proto)

        if isinstance(port, int):
            port = str(port)
        elif port is not None and not isinstance(port, str):
            raise TypeError('Invalid port value %s' % repr(port))

        if url is not None and not isinstance(url, str):
            raise TypeError('Invalid url value %s' % repr(url))

        if multicast is not None and not isinstance(multicast, multicasts.MultiCast):
            raise TypeError('Invalid multicast value %s' % repr(multicast))

        if proto == protos.PROTO_UNIX:
            if not port or not port.startswith('/'):
                raise ValueError('When using PROTO_UNIX, port must be a socket path')
        elif proto not in (protos.PROTO_UDP, protos.PROTO_DEFAULT) and port is None:
            raise ValueError(
                'Protocol %s requires port argument to be a port number or service name' % protos.PROTOS[proto])

        return url, port, proto, multicast

    @property
    def running(self):
        return self.lo_server is not NULL

    @property
    def url(self):
        if self._url:
            return self._url
        elif self.running:
            return (<bytes>lo.lo_server_get_url(self.lo_server)).decode('utf8')

    @url.setter
    def url(self, url):
        url = self._validate(url, self._port, self._proto, self._multicast)[0]
        self._url = url

    @property
    def proto(self) -> int:
        if self._proto:
            return self._proto
        elif self._url:
            burl = self._url.encode('utf8')
            proto = lo.lo_url_get_protocol(burl)
        elif self.multicast:
            return protos.PROTO_UDP
        elif self.running:
            proto = lo.lo_server_get_protocol(self.lo_server)
        else:
            return protos.PROTO_DEFAULT
        return protos.get_proto_id(proto)

    @proto.setter
    def proto(self, proto: Union[str, int, None]):
        proto = self._validate(self._url, self._port, proto, self._multicast)[2]
        self._proto = proto

    @property
    def proto_name(self) -> str:
        return protos.PROTOS[self.proto]

    @property
    def port(self) -> str:
        if self.running:
            return str(lo.lo_server_get_port(self.lo_server))
        elif self._port:
            return self._port
        elif self._url:
            burl = self._url.encode('utf8')
            return (<bytes>lo.lo_url_get_port(burl)).decode('utf8')
        elif self.multicast:
            return self.multicast.port
        return self._port

    @port.setter
    def port(self, port: Union[str, int, None]):
        port = self._validate(self._url, port, self._proto, self._multicast)[1]
        self._port = port

    @property
    def multicast(self) -> multicasts.MultiCast:
        return self._multicast

    @multicast.setter
    def multicast(self, multicast: multicasts.MultiCast):
        multicast = self._validate(self._url, self._port, self._proto, multicast)[3]
        self._multicast = multicast

    @property
    def queue_enabled(self) -> bool:
        return self._queue_enabled

    @queue_enabled.setter
    def queue_enabled(self, value: bool):
        cdef bint val = bool(value)
        if self.running:
            lo.lo_server_enable_queue(self.lo_server, val, val)
        self._queue_enabled = val

    @property
    def events_pending(self) -> bool:
        return bool(lo.lo_server_events_pending(self.lo_server))

    @property
    def next_event_delay(self) -> float:
        return lo.lo_server_next_event_delay(self.lo_server)

    def start(self, timeout: Union[float, int] = -1):
        if not self.startstoplock.acquire(timeout=timeout):
            raise exceptions.StartError('Timed out waiting for lock')
        try:
            if self.running:
                raise exceptions.StartError('%r already running, cannot start again' % self)

            self.lo_server_start()

            # Steal a ref for error_context
            Py_INCREF(self)

            # Add a handler for any path and any args; the handler handles routing in python-land
            if lo.lo_server_add_method(
                self.lo_server,
                NULL,
                NULL,
                <lo.lo_method_handler>router,
                <void*>self
            ) is NULL:
                self.stop(force=True)
                raise exceptions.StartError('Could not add default method')

            lo.lo_server_enable_queue(self.lo_server, self._queue_enabled, 0)

            lo.lo_server_set_error_context(self.lo_server, <void*>self)
            IF DEBUG: logs.logger.debug('%r: started', self)

        finally:
            self.startstoplock.release()

    def stop(self, timeout: Union[float, int] = -1, force: bool = False):
        if not self.startstoplock.acquire(timeout=timeout):
            raise exceptions.StopError('Timed out waiting for lock')
        try:
            if not force and not self.running:
                raise exceptions.StopError('%r not started, cannot stop' % self)
            self.lo_server_stop()
            # Unsteal the error_context ref
            Py_DECREF(self)
            IF DEBUG: logs.logger.debug('%r: stopped', self)
        finally:
            self.startstoplock.release()

    def route(self, route: types.RouteTypes, typespec: types.TypeSpecTypes = '') -> routes.Route:
        """
        Create a route for this server
        """
        if isinstance(route, routes.Route):
            if typespec:
                raise ValueError("Cannot provide route and typespec together")
            path = <paths.Path>route.path
            typespec = <typespecs.TypeSpec>route.typespec
        else:
            path = paths.Path(route)
            typespec = typespecs.TypeSpec(typespec)
            route = routes.Route(path, typespec)

        key = (path.as_bytes, typespec.as_bytes)
        if key in self.routing:
            # no-op
            return self.routing[key]
        else:
            if route.is_pattern and not route.matches_any_path:
                raise exceptions.RouteError('Cannot add pattern route %r as method definition' % route)
            IF DEBUG: logs.logger.debug('%r: added route %r' % (self, route))
            self.routing[key] = route
            self.match.cache_clear()
            return route

    def unroute(self, route: types.RouteTypes, typespec: types.TypeSpecTypes = '') -> routes.Route:
        if isinstance(route, routes.Route):
            if typespec:
                raise ValueError("Cannot provide route and typespec together")
            path = <paths.Path>route.path
            typespec = <typespecs.TypeSpec>route.typespec
        else:
            path = paths.Path(route)
            typespec = typespecs.TypeSpec(typespec)
            route = routes.Route(path, typespec)

        key = (path.as_bytes, typespec.as_bytes)
        if key not in self.routing:
            raise exceptions.RouteError('%r: %r was not routed' % (self, route))
        else:
            del self.routing[key]
            self.match.cache_clear()
            IF DEBUG: logs.logger.debug('%r: removed route %r' % (self, route))
        return route

    @functools.lru_cache(maxsize=None)
    def match(self, route: types.RouteTypes, typespec: types.TypeSpecTypes = '') -> Set[routes.Route]:
        if isinstance(route, routes.Route):
            if typespec:
                raise ValueError("Cannot provide route and typespec together")
        else:
            route = routes.Route(route, typespec)
        matches = set()
        for other in self.routing.values():
            if route == other or other in route or route in other:
                matches.add(other)
        IF DEBUG:
            if matches:
                logs.logger.debug('%r: found matches %r for %r' % (self, matches, route))
        if not matches:
            logs.logger.warning('%r: no matches found for %s' % (self, route))
        return matches

    cdef int lo_server_start(self) except -1:
        raise NotImplementedError

    cdef int lo_server_stop(self) except -1:
        raise NotImplementedError


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
    const char *path_bytes,
    const char *typespec_bytes,
    lo.lo_arg ** argv,
    int argc,
    lo.lo_message raw_msg,
    void *_server
) nogil except 1:
    cdef int retval = 0
    cdef lo.lo_timetag lo_timetag
    with gil:
        server = <AbstractServer>_server
        path_str = (<bytes>path_bytes).decode('utf8')
        typespec_str = (<bytes>typespec_bytes).decode('utf8')
        try:
            IF DEBUG: logs.logger.debug('%r: unpacking data for path %r, typespec %r (length %s)', server, path_str, typespec_str, argc)
            for route in server.match(path_str, typespec_str):
                if route.matches_any_args:
                    typespec = <typespecs.TypeSpec>typespecs.TypeSpec(typespec_str)
                else:
                    typespec = <typespecs.TypeSpec>route.typespec
                IF DEBUG: logs.logger.debug('%r: unpacking data for route %r', server, route)
                data = pack.unpack_args(typespec, argv, argc)
                IF DEBUG: logs.logger.debug('%r: received message %r', server, data)
                route.pub_soon_threadsafe(data)
        except BaseException as exc:
            logs.logger.exception(exc)
            retval = 1
            raise
    return retval
