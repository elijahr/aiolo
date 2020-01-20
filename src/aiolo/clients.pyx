# cython: language_level=3

import asyncio

try:
    import __pypy__
except ImportError:
    __pypy__ = None

from typing import Union, Awaitable

from . import typedefs
from . cimport addresses, bundles, messages


cdef class Client(addresses.Address):

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
        # Just here for stubs, see Address.__cinit__ for implementation
        pass

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
        # Just here for stubs
        pass

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
            retval = (<messages.Message>message).send(self)
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
            retval = (<bundles.Bundle>bundle).send(self)
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
    #         retval = (<messages.Message>message).send(self)
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
    #         retval = (<bundles.Bundle>bundle).send(self)
    #         # This sleep is necessary for ... reasons, or the server doesn't receive any messages
    #         # beyond the first. A sleep of 0 is not sufficient. Not sure if its a bug in my code,
    #         # liblo, or CPython/asyncio. May only be an issue if the client and server are
    #         # running in the same thread/event loop, as is the case with the unit tests.
    #         await asyncio.sleep(0.01)
    #         return retval
