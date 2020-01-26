# cython: language_level=3

from typing import Union


from . import ips


__all__ = ['MultiCast']


cdef class MultiCast:
    def __cinit__(
        self,
        group: str,
        port: Union[str, int, None],
        *,
        iface: Union[str, None] = None,
        ip: Union[str, None] = None
    ):
        self.group = group
        self.port = port
        self.iface = iface
        self.ip = ip

    def __init__(
        self,
        group: str,
        port: Union[str, int],
        *,
        iface: Union[str, None] = None,
        ip: Union[str, None] = None
    ):
        pass

    def __repr__(self):
        parts = [repr(self.group), repr(self.port)]
        if self.iface:
            parts += ['iface=%r' % self.iface]
        if self.ip:
            parts += ['ip=%r' % self.ip]
        return 'MultiCast(%s)' % ', '.join(parts)

    @property
    def group(self):
        return (<bytes>self._group).decode('utf8') if self._group is not None else None

    @group.setter
    def group(self, value):
        if not isinstance(value, str):
            raise ValueError('Invalid value for group %s' % repr(value))
        if not ips.is_valid_ip_address_or_hostname(value):
            raise ValueError('Invalid value for group %s, not an IP address or hostname' % repr(value))
        self._group = value.encode('utf8')

    @property
    def port(self):
        return self._port.decode('utf8') if self._port is not None else None

    @port.setter
    def port(self, value):
        cdef char * val = NULL
        if isinstance(value, int):
            value = str(value)
        if isinstance(value, str):
            value = value.encode('utf8')
        elif value is not None:
            raise ValueError('Invalid value for port %s' % repr(value))
        self._port = value

    @property
    def iface(self):
        return self._iface.decode('utf8') if self._iface is not None else None

    @iface.setter
    def iface(self, value):
        if isinstance(value, str):
            value = value.encode('utf8')
        elif value is not None:
            raise ValueError('Invalid value for iface %s' % repr(value))
        self._iface = value

    @property
    def ip(self):
        return self._ip.decode('utf8') if self._ip is not None else None

    @ip.setter
    def ip(self, value):
        if value is not None:
            if isinstance(value, str) and ips.is_valid_ip_address_or_hostname(value):
                value = value.encode('utf8')
            else:
                raise ValueError('Invalid value for ip %s' % repr(value))
        self._ip = value
