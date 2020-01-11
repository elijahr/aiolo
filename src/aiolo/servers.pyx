# cython: language_level=3

import asyncio
import socket
from typing import Union, Iterable
from cpython.ref cimport Py_INCREF, Py_DECREF

from . import exceptions, logs, routes
from . cimport lo, utils


cdef class Server:
    def __cinit__(self, *, url: str):
        self.url = url
        self.routing = {}
        self.lo_server = NULL

    def __init__(self, *, url: str):
        pass

    def __dealloc__(self):
        if self.lo_server is not NULL:
            lo.lo_server_free(self.lo_server)

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
            self._add_route_method(route)

        self.sock = socket.socket(fileno=lo.lo_server_get_socket_fd(self.lo_server))
        loop = asyncio.get_event_loop()
        loop.add_reader(self.sock, self._on_sock_ready)
        logs.logger.debug('%r: started', self)

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

    def route(self, path_or_route: Union[str, routes.Route], lotypes: Union[str, bytes, Iterable] = None) -> routes.Route:
        """
        Create a route for this server
        """
        if isinstance(path_or_route, routes.Route):
            if lotypes:
                raise ValueError("Cannot provide route and lotypes together")
            route = path_or_route
            path = route.path
            lotypes = route.lotypes
        else:
            route = None
            path = path_or_route
            lotypes = utils.ensure_lotypes(lotypes)
        key = route_key(path, lotypes)
        try:
            return self.routing[key]
        except KeyError:
            if route is None:
                route = routes.Route(path, lotypes)
            if self.running:
                self._add_route_method(route)
            self.routing[key] = route
            return route

    def unroute(self, path_or_route: Union[str, routes.Route], lotypes: Union[str, bytes, Iterable] = None) -> None:
        if isinstance(path_or_route, routes.Route):
            if lotypes:
                raise ValueError("Cannot provide route and lotypes together")
            path = path_or_route.path
            lotypes = path_or_route.lotypes
        else:
            path = path_or_route
            lotypes = utils.ensure_lotypes(lotypes)
        key = route_key(path, lotypes)
        try:
            route = self.routing[key]
        except KeyError:
            return None
        else:
            del self.routing[key]
            if self.running:
                self._del_route_method(route)

    def _on_sock_ready(self):
        logs.logger.debug('%r: incoming data on socket', self)
        while True:
            count = lo.lo_server_recv_noblock(self.lo_server, 0)
            if count == 0:
                break
            logs.logger.debug('%r: processed %r bytes', self, count)

    def _add_route_method(self, route: routes.Route):
        Py_INCREF(route)
        lo.lo_server_add_method(
            self.lo_server,
            route.bpath,
            route.blotypes,
            <lo.lo_method_handler>router,
            <void*>route)

    def _del_route_method(self, route: routes.Route):
        lo.lo_server_del_method(self.lo_server, route.bpath, route.blotypes)
        # Unsteal the ref
        Py_DECREF(route)


def route_key(path: Union[str, bytes], lotypes: Union[str, bytes]) -> bytes:
    if isinstance(path, str):
        path = path.encode('utf8')
    if isinstance(lotypes, str):
        lotypes = lotypes.encode('utf8')
    return _route_key(path, lotypes)


def _route_key(path: bytes, lotypes: bytes):
    return b'%s:%s' % (path, lotypes)


cdef void on_error(int num, const char *cmsg, const char *cpath) nogil:
    with gil:
        msg = (<bytes>cmsg).decode('utf8')
        logs.logger.error("liblo server error %s: %s" % (num, msg))


cdef int router(
    const char *path,
    const char *lotypes,
    lo.lo_arg ** argv,
    int argc,
    lo.lo_message raw_msg,
    void *_route
) nogil:
    with gil:
        route = <object>_route
        try:
            data = utils.lomessage_to_pyargs(lotypes, argv, argc)
        except Exception as exc:
            logs.logger.exception(exc)
            route.pub(exc)
        else:
            logs.logger.debug('%r: received message %r', route, data)
            route.pub(data)
