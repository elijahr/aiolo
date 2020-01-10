import asyncio

from . import exceptions
from . import logs
from . import routes


class Sub:
    __slots__ = ('inbox', 'route', 'loop')

    def __init__(self, route: routes.Route):
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
