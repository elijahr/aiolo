# cython: language_level=3

from . import exceptions, logs
from . cimport addresses, bundles, lo, messages, paths, servers


cdef class MultiCastAddress(addresses.Address):
    def __init__(self, server: servers.Server, no_delay: bool = False, stream_slip: bool = False, ttl: int = -1):
        self.server = server
        super(MultiCastAddress, self).__init__(
            protocol=self.server.protocol,
            host=self.server.multicast.group,
            port=self.server.multicast.port,
            no_delay=no_delay,
            stream_slip=stream_slip,
            ttl=ttl)

    cpdef int send_bundle(MultiCastAddress self, bundles.Bundle bundle):
        cdef:
            lo.lo_bundle lo_bundle = (<bundles.Bundle>bundle).lo_bundle
            lo.lo_server lo_server = (<servers.Server>self.server).lo_server
        logs.logger.debug('%r: sending %r from %r', self, bundle, self.server)
        count = lo.lo_send_bundle_from(self.lo_address, lo_server, lo_bundle)
        self.check_send_error()
        if count <= 0:
            raise exceptions.SendError(count)
        logs.logger.debug('%r: sent %s bytes', self, count)

    cpdef int send_message(MultiCastAddress self, messages.Message message):
        if message.route.path.matches_any:
            raise ValueError('Message must be sent to a specific path or pattern')

        cdef:
            char * path = (<paths.Path>message.route.path).charp()
            lo.lo_message lo_message = (<messages.Message>message).lo_message
            lo.lo_server lo_server = (<servers.Server>self.server).lo_server

        logs.logger.debug('%r: sending %r from %r', self, message, self.server)
        count = lo.lo_send_message_from(self.lo_address, lo_server, path, lo_message)

        self.check_send_error()
        if count <= 0:
            raise exceptions.SendError(count)
        logs.logger.debug('%r: sent %s bytes', self, count)
