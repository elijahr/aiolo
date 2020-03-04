# aiolo
asyncio-friendly Python bindings for [liblo](http://liblo.sourceforge.net/), an implementation of the Open Sound Control (OSC) protocol for POSIX systems.

![build_status](https://travis-ci.org/elijahr/aiolo.svg?branch=master)

## Installation

Install liblo:

OS X: `brew install liblo`

Ubuntu: `apt-get install liblo7 liblo-dev`

Then:

```shell
pip install aiolo
```

## Examples

One of the many beautiful things in Python is support for operator overloading. aiolo embraces this enthusiastically to offer the would-be OSC hacker an intuitive programming experience for objects such as `Message`, `Bundle`, `Route`, and `Sub`.

### [Simple echo server](https://github.com/elijahr/aiolo/blob/master/examples/echo_server.py)

```python
import asyncio

from aiolo import Address, Midi, Server


async def main():

    server = Server(port=12001)
    server.start()

    # Create endpoints

    # /foo accepts an int, a float, and a MIDI packet
    foo = server.route('/foo', [int, float, Midi])
    ex = server.route('/exit')

    address = Address(port=12001)

    for i in range(5):
        address.send(foo, i, float(i), Midi(i, i, i, i))

    # Notify subscriptions to exit in 1 sec
    address.delay(1, ex)

    # Subscribe to messages for any of the routes
    subs = foo.sub() | ex.sub()

    async for route, data in subs:
        print(f'echo_server: {str(route.path)} received {data}')
        if route == ex:
            await subs.unsub()

    server.stop()


if __name__ == '__main__':
    asyncio.get_event_loop().run_until_complete(main())
```


### [MultiCast](https://github.com/elijahr/aiolo/blob/master/examples/multicast.py)

```python
import asyncio
import random

from aiolo import MultiCast, MultiCastAddress, Route, Server


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
    address.send(foo, 'hello cluster')

    # Notify subscriptions to exit in 1 sec
    address.delay(1, ex)

    # Listen for incoming strings at /foo on any server in the cluster
    subs = foo.sub() | ex.sub()
    async for route, data in subs:
        print(f'{route} got data: {data}')
        if route == ex:
            await subs.unsub()

    for server in cluster:
        server.stop()


if __name__ == '__main__':
    asyncio.get_event_loop().run_until_complete(main())

```

For additional usage see the [examples](https://github.com/elijahr/aiolo/blob/master/examples) and [tests](https://github.com/elijahr/aiolo/blob/master/test.py).

## Supported platforms

Travis CI tests with the following configurations:
* Ubuntu 18.04 Bionic Beaver + liblo 0.29 + [CPython3.6, CPython3.7, CPython3.8, PyPy7.3.0 (3.6.9)]
* OS X + liblo 0.29 + [CPython3.6, CPython3.7, CPython3.8, PyPy7.3.0 (3.6.9)]

## Contributing

Pull requests are welcome, please file any issues you encounter.

## Changelog

### 4.1.0

* Rectify some `__hash__` issues.

### 4.0.0

* Use Python-based OSC address pattern matching rather than liblo's, supports escaped special characters
* Ensure ThreadedServer.start() waits for thread to be initialized
* Fix bug where subscribers might not receive pending data
* Fix bug where loop.remove_reader() was not being called on AioServer.stop()
