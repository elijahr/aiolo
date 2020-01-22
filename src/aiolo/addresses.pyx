# cython: language_level=3

from typing import Union

from . import exceptions, ips, logs, typedefs
from . cimport bundles, lo, messages, paths


__all__ = ['Address', 'PROTO_DEFAULT', 'PROTO_UDP', 'PROTO_UNIX', 'PROTO_TCP']

PROTO_DEFAULT = 0x0
PROTO_UDP = 0x1
PROTO_UNIX = 0x2
PROTO_TCP = 0x4

PROTOCOL_NAMES = {
    PROTO_DEFAULT: 'PROTO_DEFAULT',
    PROTO_UDP: 'PROTO_UDP',
    PROTO_UNIX: 'PROTO_UNIX',
    PROTO_TCP: 'PROTO_TCP',
}

PROTOCOLS_BY_NAME = {
    'PROTO_DEFAULT': PROTO_DEFAULT,
    'PROTO_UDP': PROTO_UDP,
    'PROTO_UNIX': PROTO_UNIX,
    'PROTO_TCP': PROTO_TCP,
    b'PROTO_DEFAULT': PROTO_DEFAULT,
    b'PROTO_UDP': PROTO_UDP,
    b'PROTO_UNIX': PROTO_UNIX,
    b'PROTO_TCP': PROTO_TCP,
}


cdef class Address:
    def __init__(
        self,
        *,
        url: Union[str, bytes, None] = None,
        protocol: Union[int, str, bytes, None] = None,
        host: Union[str, bytes, None] = None,
        port: Union[str, bytes, int, None] = None,
        no_delay: bool = False,
        stream_slip: bool = False,
        ttl: int = -1
    ):
        if url and (host or port or (protocol is not None)):
            raise ValueError('Must provide either only url or host/port with optional protocol')
        elif url:
            if isinstance(url, str):
                url = url.encode('utf8')
            self.lo_address = lo.lo_address_new_from_url(url)
        elif port:
            if isinstance(host, str):
                host = host.encode('utf8')
            if isinstance(port, str):
                port = port.encode('utf8')
            elif isinstance(port, int):
                port = str(port).encode('utf8')
            if protocol is not None:
                if isinstance(protocol, (str, bytes)):
                    protocol = PROTOCOLS_BY_NAME[protocol]
                self.lo_address = lo.lo_address_new_with_proto(protocol, host, port)
            else:
                self.lo_address = lo.lo_address_new(host, port)
        else:
            raise ValueError('Must provide either url or host/port with optional protocol')

        if self.lo_address is NULL:
            raise MemoryError
        self.no_delay = no_delay
        self.stream_slip = stream_slip
        self.ttl = ttl

    def __dealloc__(self):
        lo.lo_address_free(self.lo_address)
        self.lo_address = NULL

    def __repr__(self):
        rest = []
        # Don't print defaults
        if self.no_delay:
            rest.append('no_delay=%r' % self.no_delay)
        if self.stream_slip:
            rest.append('stream_slip=%r' % self.stream_slip)
        if self.ttl != -1:
            rest.append('ttl=%r' % self.ttl)
        if rest:
            rest = ', '.join([''] + rest)
        else:
            rest = ''
        if self.url:
            return '%s(url=%r%s)' % (self.__class__.__name__, self.url, rest)
        elif self.protocol:
            return '%s(protocol=%r, host=%r, port=%r%s)' % (
                self.__class__.__name__, self.protocol, self.host, self.port, rest)

    @property
    def url(self):
        return (<bytes>lo.lo_address_get_url(self.lo_address)).decode('utf8')

    @property
    def protocol(self):
        return (<bytes>lo.lo_address_get_protocol(self.lo_address)).decode('utf8')

    @property
    def protocol_name(self):
        return PROTOCOL_NAMES[lo.lo_address_get_protocol(self.lo_address)]

    @property
    def host(self):
        return (<bytes>lo.lo_address_get_hostname(self.lo_address)).decode('utf8')

    @property
    def port(self):
        return (<bytes>lo.lo_address_get_port(self.lo_address)).decode('utf8')

    @property
    def no_delay(self):
        return self._no_delay

    @no_delay.setter
    def no_delay(self, value):
        lo.lo_address_set_tcp_nodelay(self.lo_address, value)
        self._no_delay = value

    @property
    def stream_slip(self):
        return self._stream_slip

    @stream_slip.setter
    def stream_slip(self, value):
        lo.lo_address_set_stream_slip(self.lo_address, value)
        self._stream_slip = value

    @property
    def ttl(self):
        return lo.lo_address_get_ttl(self.lo_address)

    @ttl.setter
    def ttl(self, value: int):
        value = int(value)
        lo.lo_address_set_ttl(self.lo_address, value)

    @property
    def interface(self):
        cdef char * iface = lo.lo_address_get_iface(self.lo_address)
        if iface is NULL:
            return None
        return (<bytes>iface).decode('utf8')

    @interface.setter
    def interface(self, interface: Union[str, bytes]):
        cdef char * iface = NULL
        if isinstance(interface, str):
            interface = interface.encode('utf8')
        if isinstance(interface, bytes):
            iface = interface
        elif interface is not None:
            raise ValueError('Invalid interface value %s' % repr(interface))
        if lo.lo_address_set_iface(self.lo_address, iface, NULL) != 0:
            raise ValueError('Could not set interface to %s' % repr(interface))

    def set_ip(self, ip: Union[str, bytes]):
        cdef:
            char * iface = <char*>0
            char * i = NULL
        if isinstance(ip, str):
            ip = ip.encode('utf8')
        if isinstance(ip, bytes):
            i = ip
        elif ip is not None:
            raise ValueError('Invalid ip value %s' % repr(ip))
        if not ips.is_valid_ip_address(ip):
            raise ValueError('Invalid value for ip %s, not an IP address' % repr(ip))
        if lo.lo_address_set_iface(self.lo_address, iface, i) != 0:
            raise ValueError('Could not set ip to %s' % repr(ip))

    def check_send_error(Address self):
        if lo.lo_address_errno(self.lo_address):
            raise exceptions.SendError(
                '%s (%s)' % ((<bytes>lo.lo_address_errstr(self.lo_address)).decode('utf8'),
                             str(lo.lo_address_errno(self.lo_address))))

    def send(self, route: Union[typedefs.RouteTypes], *data: typedefs.MessageTypes) -> int:
        message = messages.Message(route, *data)
        return self.message(message)

    def message(self, message: messages.Message) -> int:
        if message.route.path.matches_any:
            raise ValueError('Message must be sent to a specific path or pattern')
        return self._message(message)

    def bundle(self, bundle: typedefs.BundleTypes, timetag: typedefs.TimeTagTypes = None) -> int:
        if not isinstance(bundle, bundles.Bundle):
            bundle = bundles.Bundle(bundle, timetag)
        elif timetag is not None:
            raise ValueError('Cannot provide Bundle instance and timetag together')
        return self._bundle(bundle)

    cdef int _message(self, messages.Message message):
        cdef:
            char * path = (<paths.Path>message.route.path).charp()
            lo.lo_message lo_message = message.lo_message
        logs.logger.debug('%r: sending %r', self, message)
        count = lo.lo_send_message(self.lo_address, path, lo_message)

        self.check_send_error()
        if count <= 0:
            raise exceptions.SendError(count)
        logs.logger.debug('%r: sent %s bytes', self, count)
        return count

    cdef int _bundle(self, bundles.Bundle bundle):
        logs.logger.debug('%r: sending %r', self, bundle)
        count = lo.lo_send_bundle(self.lo_address, (<bundles.Bundle>bundle).lo_bundle)
        self.check_send_error()
        if count <= 0:
            raise exceptions.SendError(count)
        logs.logger.debug('%r: sent %s bytes', self, count)
        return count

