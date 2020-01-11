# cython: language_level=3

import asyncio
from typing import Union, Iterable

from . import exceptions, logs, utils


class Route:
    def __init__(
        self,
        path: Union[str, bytes],
        lotypes: Union[str, bytes, Iterable] = None
    ):
        if isinstance(path, bytes):
            path = path.decode('utf8')
        self.path = path
        lotypes = utils.ensure_lotypes(lotypes)
        self.lotypes = lotypes.decode('utf8')
        self.subs = []

    def __repr__(self):
        return 'Route(%r, %r)' % (self.path, self.lotypes)

    def __hash__(self):
        return hash('%s:%s' % (self.path, self.lotypes))

    def pub(self, item):
        for sub in self.subs:
            sub.pub(item)

    def sub(self):
        sub = Sub(self)
        self.subs.append(sub)
        return sub

    def unsub(self, sub):
        self.subs.remove(sub)

    @property
    def bpath(self):
        return self.path.encode('utf8')

    @property
    def blotypes(self):
        return self.lotypes.encode('utf8')


class Sub:
    __slots__ = ('inbox', 'route', 'loop')

    def __init__(self, route: Route):
        self.route = route
        self.inbox = asyncio.Queue()
        logs.logger.debug('%r: created', self)

    def __repr__(self):
        return 'Sub(%r)' % self.route

    def pub(self, item):
        logs.logger.debug('%r: publishing %r', self, item)
        self.inbox.put_nowait(item)

    def unsub(self):
        self.route.unsub(self)
        self.pub(exceptions.Unsubscribed())

    def __aiter__(self):
        return self

    async def __anext__(self):
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
            return msg
