# cython: language_level=3

from typing import Union


from . import ips


__all__ = ['MultiCast']


cdef class MultiCast:
    def __cinit__(
        self,
        group: Union[bytes, str],
        port: Union[bytes, str, int, None],
        *,
        iface: Union[bytes, str, None] = None,
        ip: Union[bytes, str] = None
    ):
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

    def __repr__(self):
        return 'MultiCast(%r, %r, iface=%r, ip=%r)' % (self.group, self.port, self.iface, self.ip)

    @property
    def group(self):
        return (<bytes>self._group).decode('utf8') if self._group is not None else None

    @group.setter
    def group(self, value):
        if isinstance(value, str):
            value = value.encode('utf8')
        if not isinstance(value, bytes):
            raise ValueError('Invalid value for group %s' % repr(value))
        if not ips.is_valid_ip_address(value):
            raise ValueError('Invalid value for group %s, not an IP address' % repr(value))
        self._group = value

    @property
    def port(self):
        return self._port.decode('utf8') if self._port is not None else None

    @port.setter
    def port(self, value):
        cdef char * val = NULL
        if isinstance(value, str):
            value = value.encode('utf8')
        elif isinstance(value, int):
            value = str(value).encode('utf8')
        if value is not None and not isinstance(value, bytes):
            raise ValueError('Invalid value for port %s' % repr(value))
        self._port = value

    @property
    def iface(self):
        return self._iface.decode('utf8') if self._iface is not None else None

    @iface.setter
    def iface(self, value):
        if isinstance(value, str):
            value = value.encode('utf8')
        if value is not None and not isinstance(value, bytes):
            raise ValueError('Invalid value for iface %s' % repr(value))
        self._iface = value

    @property
    def ip(self):
        return self._ip.decode('utf8') if self._ip is not None else None

    @ip.setter
    def ip(self, value):
        if isinstance(value, str):
            value = value.encode('utf8')
        if value is not None and not isinstance(value, bytes) and not ips.is_valid_ip_address(value):
            raise ValueError('Invalid value for ip %s' % repr(value))
        self._ip = value
