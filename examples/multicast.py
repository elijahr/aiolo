import asyncio
import random

from aiolo import MultiCast, MultiCastAddress, Route, Server


async def sub(foo):
    """
    Listen for incoming strings at /foo on any server in the cluster
    """
    messages = []
    subscription = foo.sub()
    async for (msg,) in subscription:
        print(f'/foo got message: {msg}')
        messages.append(msg)
        if len(messages) == 10:
            break
    return messages


async def main():
    loop = asyncio.get_event_loop()

    # Create a multicast group
    multicast = MultiCast('224.0.1.1', port=15432)

    # Create an endpoint for receiving a single string of data at /foo
    foo = Route('/foo', str)

    # Subscribe to incoming messages
    task = loop.create_task(sub(foo))

    # Create a cluster of servers in the same multicast group
    cluster = []
    for i in range(10):
        server = Server(multicast=multicast)
        # Have them all handle the same route
        server.route(foo)
        server.start()
        cluster.append(server)

    # Send a single message from any one server to the entire cluster.
    # The message will be received by each server.
    address = MultiCastAddress(server=random.choice(cluster))
    address.send(foo, 'foo')

    # Wait for results
    messages = await task
    try:
        # The message will have been received once by each server in the cluster
        assert messages == ['foo'] * len(cluster)
    finally:
        for server in cluster:
            server.stop()


if __name__ == '__main__':
    asyncio.get_event_loop().run_until_complete(main())
