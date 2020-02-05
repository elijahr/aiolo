# cython: language_level=3

import datetime
from typing import Union

from . import exceptions, ips, logs, protos, types
from . cimport lo, messages, paths, timetags


__all__ = ['Address']


cdef class Address:
    def __init__(
        self,
        *,
        url: Union[str, None] = None,
        proto: Union[int, str, None] = None,
        host: Union[str, None] = None,
        port: Union[str, int, None] = None,
        no_delay: bool = False,
        stream_slip: bool = False,
        ttl: int = -1,
    ):
        cdef char * chost = NULL

        if url and (host or port or (proto is not None)):
            raise ValueError('Must provide either only url or host/port with optional proto')
        elif url:
            url = url.encode('utf8')
            self.lo_address = lo.lo_address_new_from_url(url)
        elif port:
            if host:
                host = host.encode('utf8')
                chost = host
            port = str(port).encode('utf8')
            if proto is not None:
                if proto not in protos.PROTOS_VALID:
                    raise ValueError('Invalid protocol, must be one of PROTO_UNIX, PROTO_TCP, or PROTO_UDP')
                proto = protos.get_proto_id(proto)
                self.lo_address = lo.lo_address_new_with_proto(proto, chost, port)
            else:
                self.lo_address = lo.lo_address_new(chost, port)
        else:
            raise ValueError('Must provide either url or host/port with optional proto')

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
        elif self.proto:
            return '%s(proto=%r, host=%r, port=%r%s)' % (
                self.__class__.__name__, self.proto, self.host, self.port, rest)

    def __eq__(self, other: Address):
        return self.url == other.url \
               and self.proto == other.proto \
               and self.host == other.host \
               and self.port == other.port

    @property
    def url(self):
        return (<bytes>lo.lo_address_get_url(self.lo_address)).decode('utf8')

    @property
    def proto(self):
        return protos.PROTOS_BY_NAME[(<bytes>lo.lo_address_get_protocol(self.lo_address))]

    @property
    def proto_name(self):
        return protos.PROTOS[(<bytes>lo.lo_address_get_protocol(self.lo_address))]

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
    def interface(self, interface: Union[str, None]):
        cdef char * iface = <char*>0
        if interface is not None:
            interface = interface.encode('utf8')
            iface = interface
        if lo.lo_address_set_iface(self.lo_address, iface, NULL) != 0:
            raise ValueError('Could not set interface to %s' % repr(interface))

    def set_ip(self, ip: Union[str, None]):
        cdef:
            char * iface = <char*>0
            char * i = NULL

        if ip not in ('', b'', None) and not ips.is_valid_ip_address_or_hostname(ip):
            raise ValueError('Invalid value for ip %s, not an IP address' % repr(ip))

        if isinstance(ip, str):
            ip = ip.encode('utf8')
            i = ip
        elif ip is not None:
            raise ValueError('Invalid ip value %s' % repr(ip))
        if lo.lo_address_set_iface(self.lo_address, iface, i) != 0:
            raise ValueError('Could not set ip to %s' % repr(ip))

    def check_send_error(Address self):
        if lo.lo_address_errno(self.lo_address):
            raise exceptions.SendError(
                '%s (%s)' % ((<bytes>lo.lo_address_errstr(self.lo_address)).decode('utf8'),
                             str(lo.lo_address_errno(self.lo_address))))

    def send(self, route: Union[types.RouteTypes], *data: types.MessageTypes) -> int:
        message = messages.Message(route, *data)
        return self.message(message)

    def message(self, message: messages.Message) -> int:
        if message.route.path.matches_any:
            raise ValueError('Message must be sent to a specific path or pattern')
        return self._message(message)

    def delay(self, delay: Union[int, float, datetime.timedelta], route: types.RouteTypes, *args: types.MessageTypes):
        message = messages.Message(route, *args)
        timetag = timetags.TimeTag(datetime.datetime.now(datetime.timezone.utc))
        timetag += delay
        bundle = messages.Bundle(message, timetag)
        return self._bundle(bundle)

    def bundle(self, bundle: types.BundleTypes, timetag: types.TimeTagTypes = None) -> int:
        if not isinstance(bundle, messages.Bundle):
            bundle = messages.Bundle(bundle, timetag)
        elif timetag is not None:
            raise ValueError('Cannot provide Bundle instance and timetag together')
        count = self._bundle(bundle)
        return count

    cdef int _message(self, messages.Message message) except -1:
        path = (<paths.Path>message.route.path).as_bytes
        cdef:
            int count
            char * p = path
            lo.lo_message lo_message = message.lo_message

        IF DEBUG: logs.logger.debug('%r: sending %r', self, message)

        count = lo.lo_send_message(self.lo_address, p, lo_message)

        self.check_send_error()
        if count <= 0:
            raise exceptions.SendError(count)
        IF DEBUG: logs.logger.debug('%r: sent %s bytes', self, count)
        return count

    cdef int _bundle(self, messages.Bundle bundle) except -1:
        cdef:
            int count
            lo.lo_bundle lo_bundle = (<messages.Bundle>bundle).lo_bundle

        IF DEBUG: logs.logger.debug('%r: sending %r', self, bundle)

        with nogil:
            count = lo.lo_send_bundle(self.lo_address, lo_bundle)

        self.check_send_error()
        if count <= 0:
            raise exceptions.SendError(count)
        IF DEBUG: logs.logger.debug('%r: sent %s bytes', self, count)
        return count


cdef Address lo_address_to_address(lo.lo_address lo_address):
    url = (<bytes>lo.lo_address_get_url(lo_address)).decode('utf8')
    proto = protos.PROTOS_BY_NAME[(<bytes>lo.lo_address_get_protocol(lo_address))]
    host = (<bytes>lo.lo_address_get_hostname(lo_address)).decode('utf8') or None
    port = (<bytes>lo.lo_address_get_port(lo_address)).decode('utf8') or None
    ttl = lo.lo_address_get_ttl(lo_address) or None
    init = {}
    if url:
        init['url'] = url
    if proto:
        init['proto'] = proto
    if host:
        init['host'] = host
    if port:
        init['port'] = port
    if ttl:
        init['ttl'] = ttl
    return Address(**init)
