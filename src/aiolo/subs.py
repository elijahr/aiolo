import janus

from . import exceptions


class Sub:
    __slots__ = ('inbox', 'route')

    def __init__(self, route, loop):
        self.route = route
        self.inbox = janus.Queue(loop=loop)

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
