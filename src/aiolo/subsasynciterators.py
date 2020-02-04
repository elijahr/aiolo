import asyncio
import collections.abc
import sys
from typing import Union, List, Tuple, TYPE_CHECKING, FrozenSet

from . import exceptions, types

if TYPE_CHECKING:
    from . import routes, subs as _subs


__all__ = ['SubsAsyncIterator']


class SubsAsyncIterator(collections.abc.AsyncIterator):
    __slots__ = ('as_tuple', '_tasks')

    def __init__(self, *subs, as_tuple: bool = False):
        self.as_tuple = as_tuple
        self._tasks = {sub: set() for sub in subs}

    def __repr__(self):
        return 'SubsAsyncIterator(*%r, %r)' % (tuple(self.subs), self.as_tuple)

    async def __anext__(self) -> Union[List[types.PubTypes], Tuple['routes.Route', List[types.PubTypes]]]:
        while True:
            if not self.subs:
                raise StopAsyncIteration

            for sub, tasks in self._tasks.items():
                # If the sub does not have a done or pending task, add one
                if not tasks:
                    self._tasks[sub].add(next_task(sub))

            await asyncio.wait(self.futures, return_when=asyncio.FIRST_COMPLETED)

            try:
                sub, task = self.popdone()
            except StopIteration:
                await asyncio.sleep(0)
            else:
                msg = await task
                if isinstance(msg, exceptions.Unsubscribed):
                    self.unsub(sub)
                    await asyncio.sleep(0)
                else:
                    break

        if self.as_tuple:
            return sub.route, msg
        else:
            return msg

    @property
    def subs(self) -> FrozenSet['_subs.Sub']:
        return frozenset(self._tasks.keys())

    def sub(self, sub: '_subs.Sub'):
        if sub not in self._tasks:
            self._tasks[sub] = set()

    def unsub(self, sub: '_subs.Sub'):
        tasks = self._tasks[sub]
        del self._tasks[sub]
        for task in tasks:
            task.cancel()

    def popdone(self) -> Tuple['_subs.Sub', asyncio.Future]:
        for sub, tasks in self._tasks.items():
            for task in tasks:
                if task.done():
                    tasks.remove(task)
                    return sub, task
        raise StopIteration

    @property
    def futures(self) -> FrozenSet[asyncio.Future]:
        return frozenset({task for tasks in self._tasks.values() for task in tasks})


def next_task(sub):
    coro = sub.next()
    if sys.version_info[:2] >= (3, 7):
        task = asyncio.create_task(coro)
    else:
        loop = sub.route.loop
        task = loop.create_task(coro)
    return task