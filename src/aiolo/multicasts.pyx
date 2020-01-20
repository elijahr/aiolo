# cython: language_level=3

from typing import Union


from . import ips


cdef class MultiCast:
    def __cinit__(
        self,
        group: Union[bytes, str],
        port: Union[bytes, str, int, None],
        *,
        iface: Union[bytes, str, None] = None,
        ip: Union[bytes, str] = None
    ):
        if isinstance(port, str):
            port = port.encode('utf8')
        if isinstance(port, int):
            port = str(port).encode('utf8')
        if isinstance(iface, str):
            iface = iface.encode('utf8')
        if isinstance(ip, str):
            ip = ip.encode('utf8')
        self.group = group
        self.port = port
        self.iface = iface
        self.ip = ip

    def __init__(
        self,
        group: Union[bytes, str],
        port: Union[bytes, str, int],
        *,
        iface: Union[bytes, str, None] = None,
        ip: Union[bytes, str] = None
    ):
        pass

    @property
    def group(self):
        return (<bytes>self._group).decode('utf8') if self._group is not NULL else None

    @group.setter
    def group(self, value):
        cdef char * val = NULL
        if isinstance(value, str):
            value = value.encode('utf8')
        if isinstance(value, bytes):
            val = <char*>value
        else:
            raise ValueError('Invalid value for group %s' % repr(value))
        if not ips.is_valid_ip_address(value):
            raise ValueError('Invalid value for group %s, not an IP address' % repr(value))
        self._group = val

    @property
    def port(self):
        return (<bytes>self._port).decode('utf8') if self._port is not NULL else None

    @port.setter
    def port(self, value):
        cdef char * val = NULL
        if isinstance(value, str):
            value = value.encode('utf8')
        if isinstance(value, bytes):
            val = <char*>value
        elif value is not None:
            raise ValueError('Invalid value for port %s' % repr(value))
        self._port = val

    @property
    def iface(self):
        return (<bytes>self._iface).decode('utf8') if self._iface is not NULL else None

    @iface.setter
    def iface(self, value):
        cdef char * val = NULL
        if isinstance(value, str):
            value = value.encode('utf8')
        if isinstance(value, bytes):
            val = <char*>value
        elif value is not None:
            raise ValueError('Invalid value for iface %s' % repr(value))
        self._iface = val

    @property
    def ip(self):
        return (<bytes>self._ip).decode('utf8') if self._ip is not NULL else None

    @ip.setter
    def ip(self, value):
        cdef char * val = NULL
        if isinstance(value, str):
            value = value.encode('utf8')
        if isinstance(value, bytes):
            val = <char*>value
        elif value is not None:
            raise ValueError('Invalid value for ip %s' % repr(value))
        if value is not None and not ips.is_valid_ip_address(value):
            raise ValueError('Invalid value for group %s, not an IP address' % repr(value))
        self._ip = val

    def __repr__(self):
        return 'MultiCast(%r, %r, iface=%r, ip=%r)' % (self.group, self.port, self.iface, self.ip)
