# cython: language_level=3
import threading
from typing import Union

from cpython.ref cimport Py_INCREF, Py_DECREF

# This unused cimport is necessary to initialize threads such that non-Python threads
# can acquire the GIL
cimport cython.parallel


from . import  exceptions, logs
from . cimport lo, multicasts

from .abstractservers cimport on_error, pop_server_start_error, AbstractServer, NO_IFACE, NO_IP


__all__ = ['ThreadedServer']


cdef class ThreadedServer(AbstractServer):

    def __cinit__(
        self,
        *,
        url: Union[str, None] = None,
        port: Union[str, int, None] = None,
        proto: Union[str, int, None] = None,
        multicast: Union[multicasts.MultiCast, None] = None,
        **kwargs
    ):
        self.initialized_event = threading.Event()

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
        if self.lo_server_thread is not NULL:
            with nogil:
                lo.lo_server_thread_free(self.lo_server_thread)
            self.lo_server_thread = NULL
            self.lo_server = NULL

    cdef int lo_server_start(self) except -1:
        cdef:
            char * iface
            char * ip
            multicasts.MultiCast multicast
            lo.lo_server_thread lo_server_thread = NULL

        if self._url:
            burl = self._url.encode('utf8')
            lo_server_thread = lo.lo_server_thread_new_from_url(burl, on_error)
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
            IF _LO_VERSION >= "0.30":
                lo_server_thread = lo.lo_server_thread_new_multicast_iface(
                    multicast._group, multicast._port, iface, ip, on_error)
            ELSE:
                if iface != NO_IFACE or ip != NO_IP:
                    raise exceptions.StartError(
                        'liblo < 0.30 does not support setting multicast interface for a server thread. '
                        'You are using %s' % (<bytes>_LO_VERSION).decode('utf8'))
                else:
                    lo_server_thread = lo.lo_server_thread_new_multicast(
                        multicast._group, multicast._port, on_error)
        elif self._proto:
            port = self._port.encode('utf8')
            lo_server_thread = lo.lo_server_thread_new_with_proto(port, self._proto, on_error)
        elif self._port is not None:
            port = self._port.encode('utf8')
            lo_server_thread = lo.lo_server_thread_new(port, on_error)
        else:
            lo_server_thread = lo.lo_server_thread_new(NULL, on_error)

        if lo_server_thread is NULL:
            # Hackery, since the error is propagated to a callback which does not yet have a reference to
            # the server instance.
            server_error = pop_server_start_error()
            if server_error is not None:
                msg = '%r: %s' % (self, server_error)
                raise exceptions.StartError(msg)
            raise exceptions.StartError('Unknown error')
        else:
            self.lo_server_thread = lo_server_thread
            self.lo_server = lo.lo_server_thread_get_server(lo_server_thread)
            # Steal a ref
            Py_INCREF(self)
            lo.lo_server_thread_set_callbacks(
                self.lo_server_thread,
                server_thread_init,
                server_thread_cleanup,
                <void*>self)
            status = lo.lo_server_thread_start(self.lo_server_thread)
            if status != 0:
                self.lo_server_stop()
                raise exceptions.StartError(
                    '%r: could not start server thread: lo_server_thread_start returned %s' % (self, status))
            else:
                if not self.initialized_event.wait(timeout=4):
                    self.lo_server_stop()
                    raise exceptions.StartError(
                        '%r: could not start server thread: timed out waiting for initialization event' % self)


        IF DEBUG: logs.logger.debug('%r: started, listening on thread', self)

    cdef int lo_server_stop(self) except -1:
        if self.lo_server_thread is not NULL:
            with nogil:
                lo.lo_server_thread_free(self.lo_server_thread)
            self.lo_server_thread = NULL
            self.lo_server = NULL


cdef int server_thread_init(lo.lo_server_thread s, void* user_data) nogil:
    with gil:
        server_thread = <ThreadedServer>user_data
        server_thread.initialized_event.set()
        IF DEBUG: logs.logger.debug('%r: initialized thread', server_thread)


cdef void server_thread_cleanup(lo.lo_server_thread s, void* user_data) nogil:
    with gil:
        server_thread = <ThreadedServer>user_data
        try:
            server_thread.stop(timeout=3)
        except exceptions.StopError:
            pass
        IF DEBUG: logs.logger.debug('%r: cleaned up thread', server_thread)
        server_thread.initialized_event.clear()
        Py_DECREF(server_thread)