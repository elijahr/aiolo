# cython: language_level=3

from . import exceptions, logs
from . cimport abstractservers, addresses, lo, messages, paths


__all__ = ['MultiCastAddress']


cdef class MultiCastAddress(addresses.Address):
    def __init__(self, server: abstractservers.AbstractServer, no_delay: bool = False, stream_slip: bool = False, ttl: int = 1):
        self.server = server
        super(MultiCastAddress, self).__init__(
            proto=self.server.proto,
            host=self.server.multicast.group,
            port=self.server.multicast.port,
            no_delay=no_delay,
            stream_slip=stream_slip,
            ttl=ttl)

    cdef int _message(self, messages.Message message) except -1:
        path = (<paths.Path>message.route.path).as_bytes
        cdef:
            int count
            char * p = path
            lo.lo_message lo_message = (<messages.Message>message).lo_message
            lo.lo_server lo_server = self.server.lo_server

        IF DEBUG: logs.logger.debug('%r: sending %r from %r', self, message, self.server)

        with nogil:
            count = lo.lo_send_message_from(self.lo_address, lo_server, p, lo_message)

        self.check_send_error()
        if count <= 0:
            raise exceptions.SendError(count)
        IF DEBUG: logs.logger.debug('%r: sent %s bytes', self, count)
        return count

    cdef int _bundle(self, messages.Bundle bundle) except -1:
        cdef:
            int count
            lo.lo_bundle lo_bundle = (<messages.Bundle>bundle).lo_bundle
            lo.lo_server lo_server = self.server.lo_server

        IF DEBUG: logs.logger.debug('%r: sending %r from %r', self, bundle, self.server)

        with nogil:
            count = lo.lo_send_bundle_from(self.lo_address, lo_server, lo_bundle)

        self.check_send_error()
        if count <= 0:
            raise exceptions.SendError(count)
        IF DEBUG: logs.logger.debug('%r: sent %s bytes', self, count)
        return count
