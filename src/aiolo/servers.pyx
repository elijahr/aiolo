# cython: language_level=3

import asyncio
import socket
import threading
from typing import Union, Awaitable

from cpython.ref cimport Py_INCREF, Py_DECREF


from . import exceptions, logs, routes, typedefs
from . cimport addresses, argdefs, bundles, clients, lo, messages, multicasts, paths


_SERVER_ERROR = threading.local()


cdef char * NO_IFACE = <char*>0
cdef char * NO_IP = <char*>0


def pop_server_error():
    try:
        return getattr(_SERVER_ERROR, 'error')
    except AttributeError:
        return None
    finally:
        try:
            delattr(_SERVER_ERROR, 'errors')
        except AttributeError:
            pass

def set_server_error(msg: str):
    setattr(_SERVER_ERROR, 'error', msg)


cdef class Server:
    def __cinit__(self, *, url: str = None, multicast: multicasts.MultiCast = None):
        if url and multicast:
            raise ValueError('Provide either url or multicast, not both (got %r, %r)' % (url, multicast))
        self.url = url
        self.multicast = multicast
        self.routing = {}
        self.lo_server = NULL

    def __init__(self, *, url: str = None, multicast: multicasts.MultiCast = None):
        pass

    def __dealloc__(self):
        if self.lo_server is not NULL:
            lo.lo_server_free(self.lo_server)
            self.lo_server = NULL

    def __repr__(self):
        if self.url:
            return 'Server(url=%r)' % self.url
        return 'Server(multicast=%r)' % self.multicast

    def multicast_address(self, no_delay: bool = False, stream_slip: bool = False, ttl: int = 1):
        if self.url:
            return addresses.Address(
                url=self.url, no_delay=no_delay, stream_slip=stream_slip, ttl=ttl)
        return addresses.Address(
            protocol=self.protocol,
            host=self.multicast.group,
            port=self.multicast.port,
            no_delay=no_delay,
            stream_slip=stream_slip,
            ttl=ttl)
    #
    # def client(self, no_delay: bool = False, stream_slip: bool = False, ttl: int = 1):
    #     if self.url:
    #         return clients.Client(url=self.url, no_delay=no_delay, stream_slip=stream_slip, ttl=ttl)
    #     return clients.Client(
    #         protocol=self.protocol,
    #         host=self.multicast.group,
    #         port=self.multicast.port,
    #         no_delay=no_delay,
    #         stream_slip=stream_slip,
    #         ttl=ttl)

    @property
    def running(self):
        return self.lo_server is not NULL

    @property
    def port(self):
        if self.lo_server is not NULL:
            return lo.lo_server_get_port(self.lo_server)
        burl = self.url.encode('utf8')
        return lo.lo_url_get_port(burl)

    @property
    def protocol(self):
        if self.lo_server is not NULL:
            return lo.lo_server_get_protocol(self.lo_server)
        burl = self.url.encode('utf8')
        return lo.lo_url_get_protocol(burl)

    # @property
    # def host(self):
    #     if self.lo_server is not NULL:
    #         return lo.lo_server_get_hostname()

    def start(self):
        cdef:
            char * iface
            char * ip
            multicasts.MultiCast multicast
        if self.running:
            raise exceptions.StartError('Server already running, cannot start again')

        # Clear any previous errors for this thread, to ensure correct exception output.
        # The error should have been logged already anyways.
        pop_server_error()

        if self.url:
            burl = self.url.encode('utf8')
            self.lo_server = lo.lo_server_new_from_url(burl, on_error)
        elif self.multicast:
            multicast = <multicasts.MultiCast>self.multicast
            if multicast._iface:
                iface = multicast._iface
            else:
                iface = NO_IFACE
            if multicast._ip:
                ip = multicast._ip
            else:
                ip = NO_IP
            self.lo_server = lo.lo_server_new_multicast_iface(multicast._group, multicast._port, iface, ip, on_error)
        else:
            # Shouldn't get here, but JIC
            raise ValueError('Server cannot be started without a url or multicast')

        if self.lo_server is NULL:
            # Hackery, since the error is propagated to a callback which has no reference to
            # the server instance.
            server_error = pop_server_error()
            if server_error is not None:
                if self.url:
                    msg = '%s (url=%r)' % (server_error, self.url)
                else:
                    msg = '%s (multicast=%r)' % (server_error, self.multicast)
                raise exceptions.StartError(msg)
            raise MemoryError

        lo.lo_server_enable_queue(self.lo_server, 1, 0)

        for route in self.routing.values():
            self._add_route(route)

        self.sock = socket.socket(fileno=lo.lo_server_get_socket_fd(self.lo_server))
        loop = asyncio.get_event_loop()
        loop.add_reader(self.sock, self._on_sock_readable, loop)
        logs.logger.debug('%r: started, listening on %r', self, loop)

    def stop(self):
        if not self.running:
            raise exceptions.StopError('Server not started, cannot stop')
        lo.lo_server_free(self.lo_server)
        self.lo_server = NULL
        for route in self.routing.values():
            Py_DECREF(route)
        try:
            self.sock.detach()
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

    def _on_sock_readable(self, loop):
        logs.logger.debug('%r: incoming data on socket', self)
        self._server_recv_noblock(loop, True)

    cdef void _server_recv_noblock(Server self, object loop, bint retry):
        cdef:
            int count = -1
            double delay

        while count != 0:
            count = lo.lo_server_recv_noblock(self.lo_server, 0)
            logs.logger.debug('%r: processed %r bytes', self, count)
            if count == 0:
                break

        if retry:
            delay = 0.5

        # Check for scheduled bundles
        if retry or lo.lo_server_events_pending(self.lo_server):
            if not delay:
                delay = lo.lo_server_next_event_delay(self.lo_server)
                logs.logger.debug('%r: pending server events, will check in %ss', self, delay)
            # I am verklempt that passing a cdef void function to call_later actually works,
            # but it does! I'll just go with it because it is faster.
            loop.call_later(0.1, self._server_recv_noblock, self, loop, True)

    @property
    def events_pending(self) -> bool:
        return bool(lo.lo_server_events_pending(self.lo_server))

    @property
    def next_event_delay(self) -> float:
        return lo.lo_server_next_event_delay(self.lo_server)

    def _add_route(self, route: routes.Route):
        cdef:
            char * path = (<paths.Path>route.path).charp()
            char * argdef = (<argdefs.Argdef>route.argdef).charp()
        # Steal ref
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
            argdef)
        # Unsteal ref
        Py_DECREF(route)
        logs.logger.debug('%r: removed route %r' % (self, route))

    def pub_from(
        self,
        route: Union[typedefs.RouteTypes],
        *data: typedefs.MessageTypes
    ) -> Awaitable[int]:
        return self.pub_message_from(messages.Message(route, *data))

    def pub_message_from(
        self,
        message: messages.Message,
        address: Union[addresses.Address, None] = None,
    ) -> Awaitable[int]:
        cdef:
            object fut = asyncio.Future()
            int retval
        if address is None:
            address = self.multicast_address()
        try:
            retval = (<messages.Message>message).send_from(address, self)
        except Exception as exc:
            fut.set_exception(exc)
        else:
            fut.set_result(retval)
        return fut

    def bundle_from(
        self,
        bundle: typedefs.BundleTypes,
        timetag: typedefs.TimeTagTypes = None,
        address: Union[addresses.Address, None] = None
    ) -> Awaitable[int]:
        cdef:
            object fut = asyncio.Future()
            int retval
        if address is None:
            address = self.multicast_address()
        try:
            if not isinstance(bundle, bundles.Bundle):
                bundle = bundles.Bundle(bundle, timetag)
            elif timetag is not None:
                raise ValueError('Cannot provide Bundle instance and timetag together')
            retval = (<bundles.Bundle>bundle).send_from(address, self)
        except Exception as exc:
            fut.set_exception(exc)
        else:
            fut.set_result(retval)
        return fut


def route_key(path: paths.Path, argdef: argdefs.Argdef):
    return '%r:%r' % (path, argdef)


cdef void on_error(int num, const char *m, const char *path) nogil:
    with gil:
        msg = (<bytes>m).decode('utf8')
        msg = "liblo server error %s: %s" % (num, msg)
        logs.logger.error(msg)
        set_server_error(msg)


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
            asyncio.get_event_loop().create_task(route.pub(data))
        except BaseException as exc:
            logs.logger.exception(exc)
            retval = 1
            raise
    return retval