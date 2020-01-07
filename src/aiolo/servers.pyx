# cython: language_level=3

import asyncio
from typing import Union, Iterable


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
    def __cinit__(self, *, url: str, loop: asyncio.AbstractEventLoop = None):
        burl = url.encode('utf8')
        self.routes = {}
        if loop is None:
            loop = asyncio.get_event_loop()
        self.loop = loop
        self._lo_server_thread = lo.lo_server_thread_new_from_url(burl, on_error)

        if self._lo_server_thread is NULL:
            raise MemoryError

    def __init__(self, *, url: str, loop: asyncio.AbstractEventLoop = None):
        pass

    def __dealloc__(self):
        lo.lo_server_thread_free(self._lo_server_thread)

    @property
    def url(self):
        return lo.lo_server_thread_get_url(self._lo_server_thread)

    @property
    def port(self):
        return lo.lo_server_thread_get_port(self._lo_server_thread)

    def start(self):
        if self.running:
            raise exceptions.StartError('Server already running, cannot start again')
        lo.lo_server_thread_start(self._lo_server_thread)
        self.running = True

    def stop(self):
        if not self.running:
            raise exceptions.StopError('Server not started, cannot stop')
        lo.lo_server_thread_stop(self._lo_server_thread)
        self.running = False

    def sub(self, path: str, pytypes: Union[str, bytes, Iterable] = None):
        """
        Decorate a function to handle a route for this server

        :param path: The route path
        :param pytypes: The tuple of python types the route expects
        :return: decorated function
        """
        route, created = routes.Route.get_or_create(path, pytypes, loop=self.loop)
        if created:
            # Steal a ref to the sub object since we're passing the object to a callback in another thread
            Py_INCREF(route)
            logs.logger.debug('Server.sub: adding route: %s, %s' % (route.path, route.lotypes))
            lo.lo_server_thread_add_method(self._lo_server_thread, route.bpath, route.blotypes, <lo.lo_method_handler>router, <void*>route)
        return route.sub()

    def unroute(self, path: str, pytypes: Union[str, bytes, Iterable] = None):
        route = routes.Route.unroute(path, pytypes)
        if route:
            lo.lo_server_thread_del_method(self._lo_server_thread, route.bpath, route.blotypes)
            # Unsteal the ref
            Py_DECREF(route)


cdef void on_error(int num, const char *cmsg, const char *cpath) nogil:
    with gil:
        msg = (<bytes>cmsg).decode('utf8')
        logs.logger.error("liblo server error %s: %s" % (num, msg))


cdef int router(const char *path, const char *lotypes, lo.lo_arg ** argv, int argc, lo.lo_message raw_msg, void *_route) nogil:
    with gil:
        logs.logger.debug((b'router received: %s, %s' % (<bytes>path, <bytes>lotypes)).decode('utf8'))
        route = <object>_route
        try:
            data = utils.lomessage_to_pyargs(lotypes, argv, argc)
        except Exception as exc:
            route.pub(exc)
        else:
            route.pub(data)
    return 0
