# cython: language_level=3

from typing import Union

from . import ips
from . cimport lo


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
    def __cinit__(
        self,
        *,
        url: Union[str, bytes, None] = None,
        protocol: Union[int, str, bytes, None] = None,
        host: Union[str, bytes, None] = None,
        port: Union[str, bytes, int, None] = None,
        no_delay: bool = False,
        stream_slip: bool = False,
        ttl: int = 1
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

    def __init__(
        self,
        *,
        url: Union[str, bytes, None] = None,
        protocol: Union[int, str, bytes, None] = None,
        host: Union[str, bytes, None] = None,
        port: Union[str, bytes, int, None] = None,
        no_delay: bool = False,
        stream_slip: bool = False,
        ttl: int = 1
    ):
        pass

    def __dealloc__(self):
        lo.lo_address_free(self.lo_address)
        self.lo_address = NULL

    def __repr__(self):
        rest = 'no_delay=%r, stream_slip=%r, ttl=%r' % (self.no_delay, self.stream_slip, self.ttl)
        if self.url:
            return '%s(url=%r, %s)' % (self.__class__.__name__, self.url, rest)
        elif self.protocol:
            return '%s(protocol=%r, host=%r, port=%r, %s)' % (
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
