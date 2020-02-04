import asyncio
from typing import Union, Iterable

from . import exceptions, subs, types, typespecs, paths


__all__ = ['Route', 'ANY_ROUTE']


class Route:
    def __init__(
        self,
        path: types.PathTypes,
        typespec: types.TypeSpecTypes = None,
    ):
        self._subs = set()
        self.path = path if isinstance(path, paths.Path) else paths.Path(path)
        self.typespec = typespec if isinstance(typespec, typespecs.TypeSpec) else typespecs.TypeSpec(typespec)
        try:
            self.loop = asyncio.get_event_loop()
        except RuntimeError:
            self.loop = None

    def __repr__(self):
        return 'Route(%s, %s)' % (self.path.simplerepr, self.typespec.simplerepr)

    def __hash__(self):
        return hash(repr(self))

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

    def pub_soon_threadsafe(self, items: Iterable[types.PubTypes]):
        if self.loop is None:
            raise RuntimeError('Cannot call pub_soon_threadsafe() on a Route which was not constructed in a running '
                               'event loop')
        self.loop.call_soon_threadsafe(self.pub_nowait, items)

    def pub_nowait(self, items: Iterable[types.PubTypes]):
        for s in self._subs:
            s.pub_nowait(items)

    def sub(self, sub: Union[subs.Sub, None] = None) -> subs.Sub:
        if sub is None:
            sub = subs.Sub(self)
        self._subs.add(sub)
        return sub

    async def pub(self, items: Iterable[types.PubTypes]):
        await asyncio.gather(*[
            s.pub(items)
            for s in self._subs
        ])

    async def unsub(self, sub):
        if sub in self._subs:
            self._subs.remove(sub)
            await sub.pub(exceptions.Unsubscribed())


ANY_ROUTE = Route(paths.ANY_PATH, typespecs.ANY_ARGS)
