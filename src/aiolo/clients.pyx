# cython: language_level=3

import asyncio

try:
    import __pypy__
except ImportError:
    __pypy__ = None

from typing import Union, Awaitable

from . import ips, typedefs
from . cimport bundles, lo, messages


cdef class Client:
    def __cinit__(self, url: str, no_delay: bool = False, stream_slip: bool = False, ttl: int = 0):
        burl = url.encode('utf8')
        self.lo_address = lo.lo_address_new_from_url(burl)
        if self.lo_address is NULL:
            raise MemoryError
        self.no_delay = no_delay
        self.stream_slip = stream_slip
        self.ttl = ttl

    def __init__(self, url: str, no_delay: bool = False, stream_slip: bool = False, ttl: int = 0):
        pass

    def __dealloc__(self):
        lo.lo_address_free(self.lo_address)
        self.lo_address = NULL

    def __repr__(self):
        return 'Client(%r)' % self.url.decode('utf8')

    @property
    def url(self):
        return lo.lo_address_get_url(self.lo_address)

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

    # if __pypy__:
    # PyPy doesn't correctly detect Cython coroutines so we have to do some hackry
    # and return futures from vanilla functions.
    def pub(self, route: Union[typedefs.RouteTypes], *data: typedefs.MessageTypes) -> Awaitable[int]:
        return self.pub_message(messages.Message(route, *data))

    def pub_message(self, message: messages.Message) -> Awaitable[int]:
        cdef:
            object fut = asyncio.Future()
            int retval
        try:
            retval = (<messages.Message>message).send(self.lo_address)
        except Exception as exc:
            fut.set_exception(exc)
        else:
            fut.set_result(retval)
        return fut

    def bundle(self, bundle: typedefs.BundleTypes, timetag: typedefs.TimeTagTypes = None) -> Awaitable[int]:
        cdef:
            object fut = asyncio.Future()
            int retval
        try:
            if not isinstance(bundle, bundles.Bundle):
                bundle = bundles.Bundle(bundle, timetag)
            elif timetag is not None:
                raise ValueError('Cannot provide Bundle instance and timetag together')
            retval = (<bundles.Bundle>bundle).send(self.lo_address)
        except Exception as exc:
            fut.set_exception(exc)
        else:
            fut.set_result(retval)
        return fut

    # else:
    #     async def pub(self, route: Union[typedefs.RouteTypes], *data: typedefs.MessageTypes) -> int:
    #         retval = await self.pub_message(messages.Message(route, *data))
    #         return retval
    #
    #     async def pub_message(self, message: messages.Message) -> int:
    #         # This sleep is necessary for ... reasons, or the server doesn't receive any messages
    #         # beyond the first. A sleep of 0 is not sufficient. Not sure if its a bug in my code,
    #         # liblo, or CPython/asyncio. May only be an issue if the client and server are
    #         # running in the same thread/event loop, as is the case with the unit tests.
    #         retval = (<messages.Message>message).send(self.lo_address)
    #         # This sleep is necessary for ... reasons, or the server doesn't receive any messages
    #         # beyond the first. A sleep of 0 is not sufficient. Not sure if its a bug in my code,
    #         # liblo, or CPython/asyncio. May only be an issue if the client and server are
    #         # running in the same thread/event loop, as is the case with the unit tests.
    #         await asyncio.sleep(0.01)
    #         return retval
    #
    #     async def bundle(self, bundle: typedefs.BundleTypes, timetag: typedefs.TimeTagTypes = None) -> int:
    #         if not isinstance(bundle, bundles.Bundle):
    #             bundle = bundles.Bundle(bundle, timetag)
    #         elif timetag is not None:
    #             raise ValueError('Cannot provide Bundle instance and timetag together')
    #         # This sleep is necessary for ... reasons, or the server doesn't receive any messages
    #         # beyond the first. A sleep of 0 is not sufficient. Not sure if its a bug in my code,
    #         # liblo, or CPython/asyncio. May only be an issue if the client and server are
    #         # running in the same thread/event loop, as is the case with the unit tests.
    #         retval = (<bundles.Bundle>bundle).send(self.lo_address)
    #         # This sleep is necessary for ... reasons, or the server doesn't receive any messages
    #         # beyond the first. A sleep of 0 is not sufficient. Not sure if its a bug in my code,
    #         # liblo, or CPython/asyncio. May only be an issue if the client and server are
    #         # running in the same thread/event loop, as is the case with the unit tests.
    #         await asyncio.sleep(0.01)
    #         return retval
