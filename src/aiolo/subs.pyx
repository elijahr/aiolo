# cython: language_level=3

import asyncio
from typing import Union, Iterable, Iterator, TYPE_CHECKING, Generator, Awaitable

from . import exceptions, logs, subsasynciterators, types


if TYPE_CHECKING:
    from . import routes


__all__ = ['Sub', 'Subs']


cdef class Sub:
    def __cinit__(self, route: 'routes.Route'):
        self.route = route
        self.inbox = asyncio.Queue()
        IF DEBUG: logs.logger.debug('%r: created', self)

    def __init__(self, route: 'routes.Route'):
        pass

    def __repr__(Sub self):
        return 'Sub(%r)' % self.route

    def __hash__(Sub self):
        return hash(repr(self))

    def __eq__(Sub self, Sub other: Sub) -> bool:
        return self.route == other.route

    def __lt__(Sub self, Sub other: Sub) -> bool:
        return self.route < other.route

    def __or__(Sub self, other: Union['Sub', 'Subs', 'routes.Route']) -> 'Subs':
        from . import routes
        if isinstance(other, routes.Route):
            return Subs(other.sub())
        elif isinstance(other, Sub):
            return Subs(self, other)
        elif isinstance(other, Subs):
            return Subs(*tuple({self} | set(other)))
        else:
            raise TypeError('Invalid value for Sub.__or__: %s' % repr(other))

    def __aiter__(Sub self) -> subsasynciterators.SubsAsyncIterator:
        return subsasynciterators.SubsAsyncIterator(self, as_tuple=False)

    def pub_nowait(Sub self, items: Iterable[types.PubTypes]):
        IF DEBUG: logs.logger.debug('%r: publishing %r', self, items)
        self.inbox.put_nowait(items)

    IF PYPY:

        @asyncio.coroutine
        def next(Sub self) -> Generator[Awaitable, None, Union[types.PubTypes, exceptions.Unsubscribed]]:
            IF DEBUG: logs.logger.debug('%r: waiting for next item in inbox...', self)
            msg = yield from self.inbox.get()
            self.inbox.task_done()
            IF DEBUG: logs.logger.debug('%r: got item from inbox %r', self, msg)
            return msg

        def pub(Sub self, items: Iterable[types.PubTypes]):
            IF DEBUG: logs.logger.debug('%r: publishing %r', self, items)
            return self.inbox.put(items)

        def unsub(self):
            return self.route.unsub(self)

    ELSE:
        async def next(Sub self) -> Union[types.PubTypes, exceptions.Unsubscribed]:
            IF DEBUG: logs.logger.debug('%r: waiting for next item in inbox...', self)
            msg = await self.inbox.get()
            self.inbox.task_done()
            IF DEBUG: logs.logger.debug('%r: got item from inbox %r', self, msg)
            return msg

        async def pub(Sub self, items: Iterable[types.PubTypes]):
            IF DEBUG: logs.logger.debug('%r: publishing %r', self, items)
            await self.inbox.put(items)

        async def unsub(self):
            await self.route.unsub(self)


cdef class Subs:
    def __cinit__(self, *subs: Sub):
        self._subs = set(subs)
        IF DEBUG: logs.logger.debug('%r: created', self)

    def __init__(self, *subs: Sub):
        pass

    def __repr__(Subs self):
        return 'Subs(%s)' % ', '.join([repr(s) for s in sorted(self._subs)])

    def __len__(Subs self):
        return len(self._subs)

    def __hash__(self):
        return hash(repr(self))

    def __eq__(Subs self, Subs other: Subs) -> bool:
        if not isinstance(other, Subs):
            raise TypeError('Invalid value for Subs.__eq__: %s' % repr(other))
        return self._subs == other._subs

    def __lt__(Subs self, Subs other: Subs) -> bool:
        return self._subs < other._subs

    def __contains__(Subs self, other: Union['Sub', 'Subs', 'routes.Route']) -> bool:
        from . import routes
        if isinstance(other, routes.Route):
            return any(other == sub.route for sub in self._subs)
        elif isinstance(other, Sub):
            return any(other == sub for sub in self._subs)
        elif isinstance(other, Subs):
            return (<Subs>other)._subs.issubset(self._subs)
        raise TypeError('Invalid value for Subs.__contains__: %s' % repr(other))

    def __ior__(Subs self, other: Union[Sub, 'Subs', 'routes.Route']) -> 'Subs':
        from . import routes
        if isinstance(other, routes.Route):
            self._subs.add(other.sub())
        elif isinstance(other, Sub):
            self._subs.add(other)
        elif isinstance(other, Subs):
            self._subs |= (<Subs>other)._subs
        else:
            raise TypeError('Invalid value for Subs.__ior__: %s' % repr(other))
        return self

    def __or__(Subs self, other: Union[Sub, 'Subs', 'routes.Route']) -> 'Subs':
        from . import routes
        sub_set = set(self._subs)
        if isinstance(other, routes.Route):
            sub_set.add(other.sub())
        elif isinstance(other, Sub):
            sub_set.add(other)
        elif isinstance(other, Subs):
            sub_set |= (<Subs>other)._subs
        else:
            raise TypeError('Invalid value for Subs.__or__: %s' % repr(other))
        return self.__class__(*tuple(sub_set))

    def __iter__(Subs self) -> Iterator[Sub]:
        return iter(self._subs)

    def __aiter__(Subs self) -> subsasynciterators.SubsAsyncIterator:
        return subsasynciterators.SubsAsyncIterator(*self._subs, as_tuple=True)

    def pub_nowait(Subs self, items: Iterable[types.PubTypes]):
        for s in self._subs:
            s.pub_nowait(items)

    IF PYPY:
        def pub(Subs self, items: Iterable[types.PubTypes]):
            return asyncio.gather(*[
                s.pub(items)
                for s in self._subs
            ])

        def unsub(Subs self):
            return asyncio.gather(*[
                s.unsub()
                for s in self._subs
            ])
    ELSE:
        async def pub(Subs self, items: Iterable[types.PubTypes]):
            await asyncio.gather(*[
                s.pub(items)
                for s in self._subs
            ])

        async def unsub(Subs self):
            await asyncio.gather(*[
                s.unsub()
                for s in self._subs
            ])

