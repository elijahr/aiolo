import asyncio
import collections.abc
from typing import Union, Any

from . import argdefs, exceptions, logs, paths, typedefs


class Route:
    __slots__ = ('path', 'argdef', 'subs')

    def __init__(
        self,
        path: typedefs.PathTypes,
        argdef: typedefs.ArgdefTypes = None
    ):
        self.subs = []
        self.path = path if isinstance(path, paths.Path) else paths.Path(path)
        self.argdef = argdef if isinstance(argdef, argdefs.Argdef) else argdefs.Argdef(argdef)

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

    async def pub(self, item: Any):
        await asyncio.gather(*[
            s.pub(item)
            for s in self.subs
        ])

    def sub(self):
        sub = Sub(self)
        self.subs.append(sub)
        return sub

    async def unsub(self, sub):
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

    async def __anext__(self) -> Any:
        try:
            logs.logger.debug('%r: waiting for next item in inbox...', self)
            msg = await self.inbox.get()
            logs.logger.debug('%r: got item from inbox %r', self, msg)
            self.inbox.task_done()
            await asyncio.sleep(0.01)
            if isinstance(msg, Exception):
                raise msg
        except (exceptions.Unsubscribed, GeneratorExit):
            raise StopAsyncIteration
        else:
            return msg

    async def pub(self, item: Any):
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

    async def __anext__(self) -> Any:
        logs.logger.debug('%r: waiting for next item in any inbox...', self)
        if not self._buffer:
            done, _ = await asyncio.wait([
                asyncio.ensure_future(sub.__anext__())
                for sub in self._subs
            ], return_when=asyncio.FIRST_COMPLETED)
            for task in done:
                self._buffer.append(task)
        msg = await self._buffer.pop(0)
        logs.logger.debug('%r: got item from inbox %r', self, msg)
        return msg

    async def pub(self, item: Any):
        await asyncio.gather(*[
            s.pub(item)
            for s in self._subs
        ])

    async def unsub(self):
        await asyncio.gather(*[
            s.unsub()
            for s in self._subs
        ])
