# cython: language_level=3

import asyncio
import socket
from typing import Union

from . import exceptions, logs
from . cimport lo, multicasts


from .abstractservers cimport on_error, pop_server_start_error, AbstractServer, NO_IFACE, NO_IP


__all__ = ['AioServer', 'Server']


cdef class AioServer(AbstractServer):

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

    def __dealloc__(self):
        if self.lo_server is not NULL:
            lo.lo_server_free(self.lo_server)
            self.lo_server = NULL

    cdef int lo_server_start(self) except -1:
        cdef:
            char * iface
            char * ip
            multicasts.MultiCast multicast
            lo.lo_server lo_server = NULL
        if self._url:
            burl = self._url.encode('utf8')
            lo_server = lo.lo_server_new_from_url(burl, on_error)
        elif self._multicast:
            multicast = <multicasts.MultiCast>self._multicast
            if multicast._iface:
                iface = multicast._iface
            else:
                iface = NO_IFACE
            if multicast._ip:
                ip = multicast._ip
            else:
                ip = NO_IP
            IF _LO_VERSION < "0.30":
                if iface != NO_IFACE or ip != NO_IP:
                    raise exceptions.StartError(
                        'liblo < 0.30 does not support setting multicast interface for a server. '
                        'You are using %s' % (<bytes>_LO_VERSION).decode('utf8'))
                else:
                    lo_server = lo.lo_server_new_multicast(multicast._group, multicast._port, on_error)
            ELSE:
                lo_server = lo.lo_server_new_multicast_iface(
                multicast._group, multicast._port, iface, ip, on_error)

        elif self._proto:
            port = self._port.encode('utf8')
            lo_server = lo.lo_server_new_with_proto(port, self._proto, on_error)
        elif self._port is not None:
            port = self._port.encode('utf8')
            lo_server = lo.lo_server_new(port, on_error)
        else:
            lo_server = lo.lo_server_new(NULL, on_error)

        if lo_server is NULL:
            # Hackery, since the error is propagated to a callback which does not yet have a reference to
            # the server instance.
            server_error = pop_server_start_error()
            if server_error is not None:
                msg = '%r: %s' % (self, server_error)
                raise exceptions.StartError(msg)
            raise exceptions.StartError('Unknown error')

        self.lo_server = lo_server

        # Create a Python socket reference for the server's existing socket fd
        # and poll for read events on the event loop
        self.sock = socket.socket(fileno=lo.lo_server_get_socket_fd(self.lo_server))
        asyncio.get_event_loop().add_reader(self.sock, self._on_sock_readable, self)
        IF DEBUG: logs.logger.debug('%r: started, polling on loop', self)

    cdef int lo_server_stop(self) except -1:
        if self.sock is not None:
            asyncio.get_event_loop().remove_reader(self.sock)
            try:
                self.sock.detach()
            except OSError:
                pass
            self.sock = None
        if self.lo_server is not NULL:
            lo.lo_server_free(self.lo_server)
            self.lo_server = NULL

    cdef void _on_sock_readable(AioServer self):
        IF DEBUG: logs.logger.debug('%r: incoming or scheduled data', self)
        cdef:
            int total = 0
            int count = -1
            double delay

        with nogil:
            while True:
                count = lo.lo_server_recv_noblock(self.lo_server, 0)
                if count == 0:
                    break
                total += count

        IF DEBUG: logs.logger.debug('%r: processed %r bytes', self, total)

        with nogil:
            # Check for scheduled bundles
            if lo.lo_server_events_pending(self.lo_server):
                delay = lo.lo_server_next_event_delay(self.lo_server)
                with gil:
                    IF DEBUG: logs.logger.debug('%r: pending server events, will check in %ss', self, delay)
                    # I am verklempt that passing a cdef void function to call_later actually works,
                    # but it does! I'll just go with it because it is faster.
                    asyncio.get_event_loop().call_later(delay, self._on_sock_readable, self)
            else:
                IF DEBUG:
                    with gil:
                        logs.logger.debug('%r: no pending server events', self)


# Server is an alias for AioServer
Server = AioServer