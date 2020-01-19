# cython: language_level=3

import asyncio

try:
    import __pypy__
except ImportError:
    __pypy__ = None

from typing import Union, Awaitable

from . import typedefs
from . cimport bundles, lo, messages


cdef class Client:
    def __cinit__(self, *, url: str, no_delay: bool = True):
        burl = url.encode('utf8')
        self.lo_address = lo.lo_address_new_from_url(burl)
        if self.lo_address is NULL:
            raise MemoryError
        if no_delay:
            lo.lo_address_set_tcp_nodelay(self.lo_address, 1)

    def __init__(self, *, url :str):
        pass

    def __dealloc__(self):
        lo.lo_address_free(self.lo_address)
        self.lo_address = NULL

    def __repr__(self):
        return 'Client(%r)' % self.url.decode('utf8')

    @property
    def url(self):
        return lo.lo_address_get_url(self.lo_address)

    if __pypy__:
        # PyPy doesn't correctly detect Cython coroutines so we have to do some hackry
        # and return futures.
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

    else:
        async def pub(self, route: Union[typedefs.RouteTypes], *data: typedefs.MessageTypes) -> int:
            retval = await self.pub_message(messages.Message(route, *data))
            return retval

        async def pub_message(self, message: messages.Message) -> int:
            retval = (<messages.Message>message).send(self.lo_address)
            # This sleep is necessary for ... reasons, or the server doesn't receive any messages
            # beyond the first. A sleep of 0 is not sufficient. Not sure if its a bug in my code,
            # liblo, or CPython/asyncio. May only be an issue if the client and server are
            # running in the same thread/event loop, as is the case with the unit tests.
            await asyncio.sleep(0.0000000000000000000000000001)
            return retval

        async def bundle(self, bundle: typedefs.BundleTypes, timetag: typedefs.TimeTagTypes = None) -> int:
            if not isinstance(bundle, bundles.Bundle):
                bundle = bundles.Bundle(bundle, timetag)
            elif timetag is not None:
                raise ValueError('Cannot provide Bundle instance and timetag together')
            retval = (<bundles.Bundle>bundle).send(self.lo_address)
            # This sleep is necessary for ... reasons, or the server doesn't receive any messages
            # beyond the first. A sleep of 0 is not sufficient. Not sure if its a bug in my code,
            # liblo, or CPython/asyncio. May only be an issue if the client and server are
            # running in the same thread/event loop, as is the case with the unit tests.
            await asyncio.sleep(0.0000000000000000000000000001)
            return retval
