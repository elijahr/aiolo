# aiolo
asyncio-friendly Python bindings for [liblo](http://liblo.sourceforge.net/), an implementation of the Open Sound Control (OSC) protocol for POSIX systems.

![build_status](https://travis-ci.org/elijahr/aiolo.svg?branch=master)

## Installation

```shell
pip install aiolo
```

By default, aiolo will install alongside a [fork of liblo]() containing unreleased bugfixes. To use system liblo installed via apt or homebrew, install aiolo with:

```shell
pip install aiolo --use-system-liblo
``` 

## Examples

One of the many beautiful things in Python is support for operator overloading. aiolo embraces this enthusiastically to offer the would-be OSC hacker an intuitive programming experience for objects such as `Message`, `Bundle`, `Route`, `Path`, and `ArgSpec`.

### [Simple echo server](https://github.com/elijahr/aiolo/blob/master/examples/echo_server.py)
```python
import asyncio
import datetime
import logging
import sys

from aiolo import logger, Address, Message, Midi, Server


def pub():
    address = Address(port=12001)
    now = datetime.datetime.now(datetime.timezone.utc)

    # Send some delayed data; the server will receive it immediately but enqueue it for processing
    # at the specified bundle timetag
    for i in range(5):
        address.delay(now + datetime.timedelta(seconds=i), Message('/foo', i, float(i), Midi(i, i, i, i)))

    address.delay(now + datetime.timedelta(seconds=6), Message('/exit'))


async def main(verbose):
    if verbose:
        h = logging.StreamHandler()
        h.setLevel(logging.DEBUG)
        logger.addHandler(h)
        logger.setLevel(logging.DEBUG)

    server = Server(port=12001)
    server.start()

    # Create endpoints

    # /foo accepts an int, a float, and a MIDI packet
    foo = server.route('/foo', [int, float, Midi])
    ex = server.route('/exit')

    # Subscribe to messages for any of the routes
    subs = foo.sub() | ex.sub()

    pub()

    async for route, data in subs:
        print(f'echo_server: {str(route.path)} received {data}')
        if route == ex:
            await subs.unsub()
            break

    server.stop()


if __name__ == '__main__':
    asyncio.get_event_loop().run_until_complete(main(verbose='--verbose' in sys.argv))

```


### [MultiCast](https://github.com/elijahr/aiolo/blob/master/examples/multicast.py)
```python
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

```

For additional usage see the [examples](https://github.com/elijahr/aiolo/blob/master/examples) and [tests](https://github.com/elijahr/aiolo/blob/master/test.py).

## Supported platforms

Travis CI tests with the following configurations:
* Ubuntu 18.04 Bionic Beaver + liblo 0.29 + [CPython3.6, CPython3.7, CPython3.8, PyPy7.3.0 (3.6.9)]
* OS X + liblo 0.29 + [CPython3.6, CPython3.7, CPython3.8, PyPy7.3.0 (3.6.9)]

## Contributing

Pull requests are welcome, please file any issues you encounter.

## Changelog

### 4.0.0

* Support bundling a newer liblo via `python setup.py --use-bundled-liblo`
* Use Python-based OSC address pattern matching rather than liblo's, supports escaped special characters
* Ensure ThreadedServer.start() waits for thread to be initialized
* Fix bug where subscribers might not receive pending data
* Fix bug where loop.remove_reader() was not being called on AioServer.stop()
