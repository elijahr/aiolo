# cython: language_level=3

import asyncio
from typing import Union, Iterable, Iterator, TYPE_CHECKING

from . import exceptions, logs, subsasynciterators, types


if TYPE_CHECKING:
    from . import routes


__all__ = ['Sub', 'Subs']


class Sub:
    __slots__ = ('inbox', 'route')

    def __init__(self, route: 'routes.Route'):
        self.route = route
        self.inbox = asyncio.Queue()
        logs.logger.debug('%r: created', self)

    def __repr__(self):
        return 'Sub(%r)' % self.route

    def __hash__(self):
        return hash(repr(self))

    def __eq__(self, other: 'Sub') -> bool:
        return self.route == other.route

    def __lt__(self, other: 'Sub') -> bool:
        return self.route < other.route

    def __or__(self, other: Union['Sub', 'Subs', 'routes.Route']) -> 'Subs':
        from . import routes
        if isinstance(other, routes.Route):
            return Subs(other.sub())
        elif isinstance(other, Sub):
            return Subs(self, other)
        elif isinstance(other, Subs):
            return Subs(*tuple({self} | set(other)))
        else:
            raise TypeError('Invalid value for Sub.__or__: %s' % repr(other))

    def __aiter__(self) -> subsasynciterators.SubsAsyncIterator:
        return subsasynciterators.SubsAsyncIterator(self, as_tuple=False)

    def pub_nowait(self, items: Iterable[types.PubTypes]):
        logs.logger.debug('%r: publishing %r', self, items)
        self.inbox.put_nowait(items)

    async def next(self) -> Union[types.PubTypes, exceptions.Unsubscribed]:
        logs.logger.debug('%r: waiting for next item in inbox...', self)
        msg = await self.inbox.get()
        self.inbox.task_done()
        logs.logger.debug('%r: got item from inbox %r', self, msg)
        return msg

    async def pub(self, items: Iterable[types.PubTypes]):
        logs.logger.debug('%r: publishing %r', self, items)
        await self.inbox.put(items)

    async def unsub(self):
        await self.route.unsub(self)


class Subs:
    __slots__ = ('_subs', )

    def __init__(self, *subs: Sub):
        self._subs = set(subs)
        logs.logger.debug('%r: created', self)

    def __repr__(self):
        return 'Subs(%s)' % ', '.join([repr(s) for s in sorted(self._subs)])

    def __len__(self):
        return len(self._subs)

    def __eq__(self, other: 'Subs') -> bool:
        if not isinstance(other, Subs):
            raise TypeError('Invalid value for Subs.__eq__: %s' % repr(other))
        return self._subs == other._subs

    def __lt__(self, other: 'Subs') -> bool:
        return self._subs < other._subs

    def __contains__(self, other: Union['Sub', 'Subs', 'routes.Route']) -> bool:
        from . import routes
        if isinstance(other, routes.Route):
            return any(other == sub.route for sub in self._subs)
        elif isinstance(other, Sub):
            return any(other == sub for sub in self._subs)
        elif isinstance(other, Subs):
            return other._subs.issubset(self._subs)
        raise TypeError('Invalid value for Subs.__contains__: %s' % repr(other))

    def __ior__(self, other: Union[Sub, 'Subs', 'routes.Route']) -> 'Subs':
        from . import routes
        if isinstance(other, routes.Route):
            self._subs.add(other.sub())
        elif isinstance(other, Sub):
            self._subs.add(other)
        elif isinstance(other, Subs):
            self._subs |= other._subs
        else:
            raise TypeError('Invalid value for Subs.__ior__: %s' % repr(other))
        return self

    def __or__(self, other: Union[Sub, 'Subs', 'routes.Route']) -> 'Subs':
        from . import routes
        sub_set = set(self._subs)
        if isinstance(other, routes.Route):
            sub_set.add(other.sub())
        elif isinstance(other, Sub):
            sub_set.add(other)
        elif isinstance(other, Subs):
            sub_set |= other._subs
        else:
            raise TypeError('Invalid value for Subs.__or__: %s' % repr(other))
        return self.__class__(*tuple(sub_set))

    def __iter__(self) -> Iterator[Sub]:
        return iter(self._subs)

    def __aiter__(self) -> subsasynciterators.SubsAsyncIterator:
        return subsasynciterators.SubsAsyncIterator(*self._subs, as_tuple=True)

    def pub_nowait(self, items: Iterable[types.PubTypes]):
        for s in self._subs:
            s.pub_nowait(items)

    async def pub(self, items: Iterable[types.PubTypes]):
        await asyncio.gather(*[
            s.pub(items)
            for s in self._subs
        ])

    async def unsub(self):
        await asyncio.gather(*[
            s.unsub()
            for s in self._subs
        ])

