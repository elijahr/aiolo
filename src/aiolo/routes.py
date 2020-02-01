import asyncio
import collections.abc
from typing import Union, Tuple, Iterable, Iterator

from . import typespecs, exceptions, logs, paths, types


__all__ = ['Route', 'Sub', 'Subs']


class Route:
    __slots__ = ('path', 'typespec', 'subs', 'loop')

    def __init__(
        self,
        path: types.PathTypes,
        typespec: types.TypeSpecTypes = None,
    ):
        self.subs = []
        self.path = path if isinstance(path, paths.Path) else paths.Path(path)
        self.typespec = typespec if isinstance(typespec, typespecs.TypeSpec) else typespecs.TypeSpec(typespec)
        try:
            self.loop = asyncio.get_event_loop()
        except RuntimeError:
            self.loop = None

    def __repr__(self):
        return 'Route(%s, %s)' % (self.path.simplerepr, self.typespec.simplerepr)

    def __hash__(self):
        return hash('Route:%s,%s' % (hash(self.path), hash(self.typespec)))

    def __contains__(self, other: Union['Route', Iterable['Route']]) -> bool:
        if isinstance(other, Route):
            routes = {other}
        else:
            routes = other
        if not all(isinstance(r, Route) for r in routes):
            raise TypeError('Invalid value for Route.__contains__: %s' % repr(routes))
        if self.matches_any_path or all(r.path in self.path for r in routes):
            if self.matches_any_args or all(self.typespec == r.typespec for r in routes):
                return True
        return False

    def __eq__(self, other: 'Route') -> bool:
        if not isinstance(other, Route):
            raise TypeError('Invalid value for Route.__eq__: %s' % repr(other))
        return self.path == other.path and self.typespec == other.typespec

    def __lt__(self, other: 'Route') -> bool:
        if not isinstance(other, Route):
            raise TypeError('Invalid value for Route.__lt__: %s' % repr(other))
        return self.path < other.path and self.typespec < other.typespec

    @property
    def is_pattern(self) -> bool:
        return self.path.is_pattern

    @property
    def matches_any(self):
        return self.matches_any_path and self.matches_any_args

    @property
    def matches_any_path(self):
        return self.path.matches_any

    @property
    def matches_any_args(self):
        return self.typespec.matches_any

    @property
    def matches_no_args(self):
        return self.typespec.matches_no

    def pub_soon_threadsafe(self, item: types.PubTypes):
        if self.loop is None:
            raise RuntimeError('Cannot call pub_soon_threadsafe() on a Route which was not constructed in a running event loop')
        self.loop.call_soon_threadsafe(self.pub_nowait, item)

    def pub_nowait(self, item: types.PubTypes):
        for s in self.subs:
            s.pub_nowait(item)

    async def pub(self, item: types.PubTypes):
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
        logs.debug('%r: created', self)

    def __repr__(self):
        return 'Sub(%r)' % self.route

    def __hash__(self):
        return hash('Sub:%s' % hash(self.route))

    def __eq__(self, other: Union['Sub', 'Subs']) -> bool:
        if isinstance(other, Sub):
            return self.route == other.route
        elif isinstance(other, Subs):
            return len(other) == 1 and list(other)[0] == self
        else:
            raise TypeError('Invalid value for Sub.__eq__: %s' % repr(other))

    def __lt__(self, other: Union['Sub', 'Subs']) -> bool:
        if isinstance(other, Sub):
            return self.route < other.route
        elif isinstance(other, Subs):
            return hash(self.route) < hash(other)
        else:
            raise TypeError('Invalid value for Sub.__lt__: %s' % repr(other))

    def __len__(self):
        return 1

    def __contains__(self, other: Union['Sub', 'Subs', Route]) -> bool:
        if isinstance(other, Route):
            return self.route == other
        elif isinstance(other, Sub):
            return self.route == other.route
        elif isinstance(other, Subs):
            return len(other) == 1 and list(other)[0] == self
        raise TypeError('Invalid value for Sub.__contains__: %s' % repr(other))

    def __or__(self, other: Union['Sub', 'Subs']) -> 'Subs':
        if isinstance(other, Sub):
            return Subs(self, other)
        return other | self

    def __aiter__(self) -> 'Sub':
        return self

    async def __anext__(self, as_tuple: bool = False) -> Union[types.PubTypes, Tuple[Route, types.PubTypes]]:
        try:
            logs.debug('%r: waiting for next item in inbox...', self)
            msg = await self.inbox.get()
            logs.debug('%r: got item from inbox %r', self, msg)
            self.inbox.task_done()
            if isinstance(msg, Exception):
                raise msg
        except (exceptions.Unsubscribed, GeneratorExit):
            raise StopAsyncIteration
        else:
            if as_tuple:
                return self.route, msg
            return msg

    def pub_nowait(self, item: types.PubTypes):
        logs.debug('%r: publishing %r', self, item)
        self.inbox.put_nowait(item)

    async def pub(self, item: types.PubTypes):
        logs.debug('%r: publishing %r', self, item)
        await self.inbox.put(item)

    async def unsub(self):
        await self.route.unsub(self)


class Subs(collections.abc.AsyncIterator):
    __slots__ = ('_subs', '_buffer')

    def __init__(self, *subs: Sub):
        self._subs = set(subs)
        self._buffer = []

    def __repr__(self):
        return 'Subs(%s)' % ', '.join([repr(s) for s in sorted(self._subs)])

    def __len__(self):
        return len(self._subs)

    def __hash__(self):
        return hash('Subs:' + ('|'.join([str(hash(s)) for s in sorted(self._subs)])))

    def __eq__(self, other: Union['Sub', 'Subs']) -> bool:
        if isinstance(other, Sub):
            other = Subs(other)
        if not isinstance(other, Subs):
            raise TypeError('Invalid value for Subs.__eq__: %s' % repr(other))
        return hash(self) == hash(other)

    def __contains__(self, other: Union['Sub', 'Subs', Route]) -> bool:
        if isinstance(other, Route):
            return any(other in sub for sub in self._subs)
        elif isinstance(other, Sub):
            return any(other == sub for sub in self._subs)
        elif isinstance(other, Subs):
            return other._subs.issubset(self._subs)
        raise TypeError('Invalid value for Subs.__contains__: %s' % repr(other))

    def __ior__(self, other: Union[Sub, 'Subs']) -> 'Subs':
        if isinstance(other, Sub):
            self._subs.add(other)
        else:
            self._subs |= other._subs
        return self

    def __or__(self, other: Union[Sub, 'Subs']) -> 'Subs':
        sub_set = set(self._subs)
        if isinstance(other, Sub):
            sub_set.add(other)
        else:
            sub_set |= other._subs
        return self.__class__(*tuple(sub_set))

    def __iter__(self, item) -> Iterator[Sub]:
        return iter(self._subs)

    def __aiter__(self) -> 'Subs':
        return self

    async def __anext__(self) -> Tuple[Route, types.PubTypes]:
        logs.debug('%r: waiting for next item in inbox...', self)
        if not self._buffer:
            done, _ = await asyncio.wait([
                asyncio.ensure_future(sub.__anext__(as_tuple=True))
                for sub in self._subs
            ], return_when=asyncio.FIRST_COMPLETED)
            for task in done:
                self._buffer.append(task)
        msg = await self._buffer.pop(0)
        # this sleep wakes up the loop
        # TODO: is this really true/necessary?
        await asyncio.sleep(1e-32)
        logs.debug('%r: got item from inbox %r', self, msg)
        return msg

    def pub_nowait(self, item: types.PubTypes):
        for s in self._subs:
            s.pub_nowait(item)

    async def pub(self, item: types.PubTypes):
        await asyncio.gather(*[
            s.pub(item)
            for s in self._subs
        ])

    async def unsub(self):
        await asyncio.gather(*[
            s.unsub()
            for s in self._subs
        ])


ANY_ROUTE = Route(paths.ANY_PATH, typespecs.ANY_ARGS)
