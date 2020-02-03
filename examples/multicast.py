import asyncio
import datetime
import random

from aiolo import MultiCast, MultiCastAddress, Route, Server, Message


async def main():
    # Create endpoints for receiving data
    foo = Route('/foo', str)
    ex = Route('/exit')

    # Create a multicast group
    multicast = MultiCast('224.0.1.1', port=15432)

    # Create a cluster of servers in the same multicast group
    cluster = []
    for i in range(10):
        server = Server(multicast=multicast)
        # Have them all handle the same route
        server.route(foo)
        server.route(ex)
        server.start()
        cluster.append(server)

    address = MultiCastAddress(server=random.choice(cluster))

    # Send a single message from any one server to the entire cluster.
    # The message will be received by each server.
    address.delay(datetime.datetime.now(datetime.timezone.utc) + datetime.timedelta(seconds=1), Message(foo, 'foo'))

    # Notify subscriptions to exit in 1 sec
    address.delay(datetime.datetime.now(datetime.timezone.utc) + datetime.timedelta(seconds=2), Message(ex))

    # Listen for incoming strings at /foo on any server in the cluster
    async for route, data in foo.sub() | ex.sub():
        print(f'{route} got data: {data}')
        if route == ex:
            break

    for server in cluster:
        server.stop()


if __name__ == '__main__':
    asyncio.get_event_loop().run_until_complete(main())
