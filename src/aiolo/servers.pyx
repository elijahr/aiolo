# cython: language_level=3

from typing import Union, Iterable, Tuple

# Importing cython.parallel ensures CPython's thread state is initialized properly
# See https://bugs.python.org/issue20891 and https://github.com/python/cpython/pull/5425
# and https://github.com/opensocdebug/osd-sw/issues/37
cimport cython.parallel


from cpython.ref cimport Py_INCREF, Py_DECREF


from . import exceptions
from . cimport lo
from . import logs
from . cimport routes
from . cimport utils


cdef class Server:
    def __cinit__(self, *, url: str):
        burl = url.encode('utf8')
        self.routes = {}
        self.lo_server_thread = lo.lo_server_thread_new_from_url(burl, on_error)

        if self.lo_server_thread is NULL:
            raise MemoryError

    def __init__(self, *, url: str):
        pass

    def __dealloc__(self):
        lo.lo_server_thread_free(self.lo_server_thread)

    def __repr__(self):
        return 'Server(%r)' % self.url.decode('utf8')

    @property
    def url(self):
        return lo.lo_server_thread_get_url(self.lo_server_thread)

    @property
    def port(self):
        return lo.lo_server_thread_get_port(self.lo_server_thread)

    def start(self):
        if self.running:
            raise exceptions.StartError('Server already running, cannot start again')
        lo.lo_server_thread_start(self.lo_server_thread)
        self.running = True

    def stop(self):
        if not self.running:
            raise exceptions.StopError('Server not started, cannot stop')
        lo.lo_server_thread_stop(self.lo_server_thread)
        self.running = False

    def route(self, path: str, lotypes: Union[str, bytes, Iterable] = None):
        """
        Create a route for this server

        :param path: The route path
        :param lotypes: The tuple of types the route expects
        :return: decorated function
        """
        route, created = self.get_or_create_route(path, lotypes)
        if created:
            self.add_route(route)
        return route

    def add_route(self, route: routes.Route):
        # Steal a ref to the sub object since we're passing the object to a callback in another thread
        Py_INCREF(route)
        lo.lo_server_thread_add_method(
            self.lo_server_thread, route.bpath, route.blotypes, <lo.lo_method_handler>router, <void*>route)
        logs.logger.debug('%r: added route %r' % (self, route))

    def get_or_create_route(
            self,
            path: Union[str, bytes],
            lotypes: Union[str, bytes, Iterable] = None
    ) -> Tuple[routes.Route, bool]:
        lotypes = utils.ensure_lotypes(lotypes)
        key = route_key(path, lotypes)
        try:
            return self.routes[key], False
        except KeyError:
            route = routes.Route(path, lotypes)
            self.routes[key] = route
            return route, True

    def unroute(self, path: str, lotypes: Union[str, bytes, Iterable] = None) -> None:
        lotypes = utils.ensure_lotypes(lotypes)
        key = route_key(path, lotypes)
        try:
            route = self.routes[key]
        except KeyError:
            return None
        else:
            del self.routes[key]
            lo.lo_server_thread_del_method(self.lo_server_thread, route.bpath, route.blotypes)
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


cdef int router(const char *path, const char *lotypes, lo.lo_arg ** argv, int argc, lo.lo_message raw_msg, void *_route) nogil:
    with gil:
        route = <object>_route
        try:
            data = utils.lomessage_to_pyargs(lotypes, argv, argc)
        except Exception as exc:
            logs.logger.exception(exc)
            route.pub(exc)
        else:
            logs.logger.debug('%r: received message %r' % (route, data))
            route.pub(data)
    return 0
