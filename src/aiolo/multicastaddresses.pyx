# cython: language_level=3

from . import exceptions, logs
from . cimport abstractservers, addresses, bundles, lo, messages, paths


__all__ = ['MultiCastAddress']


cdef class MultiCastAddress(addresses.Address):
    def __init__(self, server: abstractservers.AbstractServer, no_delay: bool = False, stream_slip: bool = False, ttl: int = 1):
        self.server = server
        super(MultiCastAddress, self).__init__(
            protocol=self.server.protocol,
            host=self.server.multicast.group,
            port=self.server.multicast.port,
            no_delay=no_delay,
            stream_slip=stream_slip,
            ttl=ttl)

    cdef int _message(self, messages.Message message):
        cdef:
            char * path = (<paths.Path>message.route.path).charp()
            lo.lo_message lo_message = (<messages.Message>message).lo_message
            lo.lo_server lo_server = self.server.lo_server()

        logs.logger.debug('%r: sending %r from %r', self, message, self.server)
        count = lo.lo_send_message_from(self.lo_address, lo_server, path, lo_message)

        self.check_send_error()
        if count <= 0:
            raise exceptions.SendError(count)
        logs.logger.debug('%r: sent %s bytes', self, count)
        return count

    cdef int _bundle(self, bundles.Bundle bundle):
        cdef:
            lo.lo_bundle lo_bundle = (<bundles.Bundle>bundle).lo_bundle
        logs.logger.debug('%r: sending %r from %r', self, bundle, self.server)
        count = lo.lo_send_bundle_from(self.lo_address, self.server.lo_server(), lo_bundle)
        self.check_send_error()
        if count <= 0:
            raise exceptions.SendError(count)
        logs.logger.debug('%r: sent %s bytes', self, count)
        return count
