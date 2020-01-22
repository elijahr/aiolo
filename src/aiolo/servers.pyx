# cython: language_level=3

import asyncio
import socket


from . import exceptions, logs
from . cimport lo, multicasts


from .abstractservers cimport on_error, pop_server_start_error, AbstractServer, NO_IFACE, NO_IP


__all__ = ['Server']


cdef class Server(AbstractServer):

    def __dealloc__(self):
        if self._lo_server is not NULL:
            lo.lo_server_free(self._lo_server)
            self._lo_server = NULL

    cdef lo.lo_server lo_server(self):
        return self._lo_server

    cdef void lo_server_start(self):
        cdef:
            char * iface
            char * ip
            multicasts.MultiCast multicast
            lo.lo_server lo_server = NULL
        if self.url:
            burl = self.url.encode('utf8')
            lo_server = lo.lo_server_new_from_url(burl, on_error)
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
            if iface == NO_IFACE and ip == NO_IP:
                lo_server = lo.lo_server_new_multicast(multicast._group, multicast._port, on_error)
            lo_server = lo.lo_server_new_multicast_iface(
                multicast._group, multicast._port, iface, ip, on_error)
        else:
            # Shouldn't get here, but JIC
            raise exceptions.StartError('Server cannot be started without a url or multicast')

        if lo_server is NULL:
            # Hackery, since the error is propagated to a callback which does not yet have a reference to
            # the server instance.
            server_error = pop_server_start_error()
            if server_error is not None:
                if self.url:
                    msg = '%s (url=%r)' % (server_error, self.url)
                else:
                    msg = '%s (multicast=%r)' % (server_error, self.multicast)
                raise exceptions.StartError(msg)
            raise MemoryError

        self._lo_server = lo_server
        self.sock = socket.socket(fileno=lo.lo_server_get_socket_fd(self._lo_server))
        loop = asyncio.get_event_loop()
        loop.add_reader(self.sock, self._on_sock_readable, self, loop)
        logs.logger.debug('%r: started, polling on %r', self, loop)

    cdef void lo_server_stop(self):
        if self.sock is not None:
            try:
                self.sock.detach()
            except OSError:
                pass
            self.sock = None
        if self._lo_server is not NULL:
            lo.lo_server_free(self._lo_server)
            self._lo_server = NULL

    cdef void _on_sock_readable(Server self, object loop):
        logs.logger.debug('%r: incoming or scheduled data', self)
        cdef:
            int count = -1
            double delay

        while count != 0:
            count = lo.lo_server_recv_noblock(self._lo_server, 0)
            logs.logger.debug('%r: processed %r bytes', self, count)
            if count == 0:
                break

        # Check for scheduled bundles
        if lo.lo_server_events_pending(self._lo_server):
            delay = lo.lo_server_next_event_delay(self._lo_server)
            logs.logger.debug('%r: pending server events, will check in %ss', self, delay)
            # I am verklempt that passing a cdef void function to call_later actually works,
            # but it does! I'll just go with it because it is faster.
            loop.call_later(delay, self._on_sock_readable, self, loop)
