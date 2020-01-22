# cython: language_level=3

from cpython.ref cimport Py_INCREF, Py_DECREF

# This unused import is necessary to initialize threads such that non-Python threads
# can acquire the GIL
cimport cython.parallel


from . import  exceptions, logs
from . cimport lo, multicasts

from .abstractservers cimport on_error, pop_server_start_error, AbstractServer, NO_IFACE, NO_IP


__all__ = ['ThreadedServer']


cdef class ThreadedServer(AbstractServer):

    def __dealloc__(self):
        if self._lo_server_thread is not NULL:
            with nogil:
                lo.lo_server_thread_free(self._lo_server_thread)
            self._lo_server_thread = NULL

    cdef lo.lo_server lo_server(self):
        if self._lo_server_thread is not NULL:
            return lo.lo_server_thread_get_server(self._lo_server_thread)
        return NULL

    cdef void lo_server_start(self):
        cdef:
            char * iface
            char * ip
            multicasts.MultiCast multicast
            lo.lo_server_thread lo_server_thread = NULL

        if self.url:
            burl = self.url.encode('utf8')
            lo_server_thread = lo.lo_server_thread_new_from_url(burl, on_error)
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
            IF LO_VERSION < "0.30":
                if iface != NO_IFACE or ip != NO_IP:
                    raise exceptions.StartError(
                        'liblo < 0.30 does not support setting multicast interface for a server thread. '
                        'You are using %s' % (<bytes>LO_VERSION).decode('utf8'))
                else:
                    lo_server_thread = lo.lo_server_thread_new_multicast(
                        multicast._group, multicast._port, on_error)
            ELSE:
                lo_server_thread = lo.lo_server_thread_new_multicast_iface(
                    multicast._group, multicast._port, iface, ip, on_error)
        else:
            # Shouldn't get here, but JIC
            raise exceptions.StartError('%s cannot be started without a url or multicast' % self.__class__.__name__)

        if lo_server_thread is NULL:
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
        else:
            self._lo_server_thread = lo_server_thread
            # Steal a ref
            Py_INCREF(self)
            lo.lo_server_thread_set_callbacks(
                self._lo_server_thread,
                server_thread_init,
                server_thread_cleanup,
                <void*>self)
            status = lo.lo_server_thread_start(self._lo_server_thread)
            if status != 0:
                self.lo_server_stop()
                raise exceptions.StartError(
                    '%r: could not start server thread: lo_server_thread_start returned %s' % (self, status))

        logs.logger.debug('%r: started, listening on thread', self)

    cdef void lo_server_stop(self):
        if self._lo_server_thread is not NULL:
            with nogil:
                lo.lo_server_thread_free(self._lo_server_thread)
            self._lo_server_thread = NULL


cdef int server_thread_init(lo.lo_server_thread s, void* user_data) nogil:
    with gil:
        server_thread = <ThreadedServer>user_data
        logs.logger.debug('%r: initialized thread', server_thread)


cdef void server_thread_cleanup(lo.lo_server_thread s, void* user_data) nogil:
    with gil:
        server_thread = <ThreadedServer>user_data
        logs.logger.debug('%r: cleaned up thread', server_thread)
        Py_DECREF(server_thread)