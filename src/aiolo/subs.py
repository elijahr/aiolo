import asyncio

import janus

from . import exceptions
from . import logs
from . import routes


class Sub:
    __slots__ = ('inbox', 'route')

    def __init__(self, route: routes.Route, loop: asyncio.AbstractEventLoop = None):
        self.route = route
        if loop is None:
            loop = asyncio.get_event_loop()
        self.inbox = janus.Queue(loop=loop)
        logs.logger.debug('%r: created' % self)

    def __repr__(self):
        return 'Sub(%r)' % self.route

    def pub(self, item):
        self.inbox.sync_q.put(item)

    def unsub(self):
        self.route.unsub(self)
        self.pub(exceptions.Unsubscribed())

    def __aiter__(self):
        return self

    async def __anext__(self):
        try:
            msg = await self.inbox.async_q.get()
            self.inbox.async_q.task_done()
            if isinstance(msg, Exception):
                raise msg
        except exceptions.Unsubscribed:
            raise StopAsyncIteration
        else:
            return msg
