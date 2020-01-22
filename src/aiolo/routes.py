import asyncio
import collections.abc
from typing import Union, Tuple

from . import argdefs, exceptions, logs, paths, typedefs


__all__ = ['Route', 'Sub', 'Subs']


class Route:
    __slots__ = ('path', 'argdef', 'subs', 'loop')

    def __init__(
        self,
        path: typedefs.PathTypes,
        argdef: typedefs.ArgdefTypes = None,
        loop: asyncio.AbstractEventLoop = None,
    ):
        self.subs = []
        self.path = path if isinstance(path, paths.Path) else paths.Path(path)
        self.argdef = argdef if isinstance(argdef, argdefs.Argdef) else argdefs.Argdef(argdef)
        if loop is None:
            loop = asyncio.get_event_loop()
        self.loop = loop

    def __repr__(self):
        return 'Route(%r, %r)' % (self.path, self.argdef)

    def __hash__(self):
        return hash('%s:%s' % (self.path, self.argdef))

    def __or__(self, other: 'Route') -> 'Route':
        if self.argdef != other.argdef:
            raise ValueError('Cannot join routes with mismatched argdefs (%r != %r)' % (self.argdef, other.argdef))
        path = self.path | other.path
        return self.__class__(path, self.argdef)

    def __and__(self, other: 'Route') -> 'Route':
        return self.__or__(other)

    @property
    def is_pattern(self) -> bool:
        return self.path.is_pattern

    def pub_soon_threadsafe(self, item: typedefs.PubTypes):
        self.loop.call_soon_threadsafe(self.pub_nowait, item)

    def pub_nowait(self, item: typedefs.PubTypes):
        for s in self.subs:
            s.pub_nowait(item)

    async def pub(self, item: typedefs.PubTypes):
        await asyncio.gather(*[
            s.pub(item)
            for s in self.subs
        ])

    def sub(self):
        sub = Sub(self)
        self.subs.append(sub)
        return sub

    async def unsub(self, sub):
        if sub in self.subs:
            self.subs.remove(sub)
            await sub.pub(exceptions.Unsubscribed())


class Sub(collections.abc.AsyncIterator):
    __slots__ = ('inbox', 'route')

    def __init__(self, route: Route):
        self.route = route
        self.inbox = asyncio.Queue()
        logs.logger.debug('%r: created', self)

    def __repr__(self):
        return 'Sub(%r)' % self.route

    def __or__(self, other: Union['Sub', 'Subs']) -> 'Subs':
        if isinstance(other, Sub):
            return Subs(self, other)
        return other | self

    def __and__(self, other: Union['Sub', 'Subs']) -> 'Subs':
        return self.__or__(other)

    def __aiter__(self) -> 'Sub':
        return self

    async def __anext__(self, as_tuple: bool = False) -> Union[typedefs.PubTypes, Tuple[Route, typedefs.PubTypes]]:
        try:
            logs.logger.debug('%r: waiting for next item in inbox...', self)
            msg = await self.inbox.get()
            logs.logger.debug('%r: got item from inbox %r', self, msg)
            self.inbox.task_done()
            if isinstance(msg, Exception):
                raise msg
        except (exceptions.Unsubscribed, GeneratorExit):
            raise StopAsyncIteration
        else:
            if as_tuple:
                return self.route, msg
            return msg

    def pub_nowait(self, item: typedefs.PubTypes):
        logs.logger.debug('%r: publishing %r', self, item)
        self.inbox.put_nowait(item)

    async def pub(self, item: typedefs.PubTypes):
        logs.logger.debug('%r: publishing %r', self, item)
        await self.inbox.put(item)

    async def unsub(self):
        await self.route.unsub(self)


class Subs(collections.abc.AsyncIterator):
    __slots__ = ('_subs', '_buffer')

    def __init__(self, *subs: Sub):
        self._subs = list(subs)
        self._buffer = []

    def __repr__(self):
        return 'Subs(%s)' % ', '.join([repr(s) for s in self._subs])

    def __or__(self, other: Union[Sub, 'Subs']) -> 'Subs':
        subs = list(self._subs)
        if isinstance(other, Sub):
            subs.append(other)
        else:
            subs += other._subs
        return self.__class__(*subs)

    def __and__(self, other: Union['Sub', 'Subs']) -> 'Subs':
        return self.__or__(other)

    def __aiter__(self) -> 'Subs':
        return self

    async def __anext__(self) -> Tuple[Route, typedefs.PubTypes]:
        logs.logger.debug('%r: waiting for next item in typedefs.PubTypes inbox...', self)
        if not self._buffer:
            done, _ = await asyncio.wait([
                asyncio.ensure_future(sub.__anext__(as_tuple=True))
                for sub in self._subs
            ], return_when=asyncio.FIRST_COMPLETED)
            for task in done:
                self._buffer.append(task)
        msg = await self._buffer.pop(0)
        # this sleep wakes up the loop, and OSC only offers 1/32 timetag granularity, so sleeping for less
        # than that ensures we don't lose any granularity
        await asyncio.sleep(1/33)
        logs.logger.debug('%r: got item from inbox %r', self, msg)
        return msg

    def pub_nowait(self, item: typedefs.PubTypes):
        for s in self._subs:
            s.pub_nowait(item)

    async def pub(self, item: typedefs.PubTypes):
        await asyncio.gather(*[
            s.pub(item)
            for s in self._subs
        ])

    async def unsub(self):
        await asyncio.gather(*[
            s.unsub()
            for s in self._subs
        ])
