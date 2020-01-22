# aiolo
asyncio-friendly Python bindings for [liblo](http://liblo.sourceforge.net/), an implementation of the Open Sound Control (OSC) protocol for POSIX systems.

![build_status](https://travis-ci.org/elijahr/aiolo.svg?branch=master)

## Installation

OS X: `brew install liblo`

Ubuntu: `apt-get install liblo7 liblo-dev`

Then:
```shell
pip install aiolo
```

## Supported platforms

Travis CI tests with the following configurations:
* Ubuntu 18.04 Bionic Beaver + liblo 0.29 + [CPython3.6, CPython3.7, CPython3.8, PyPy7.3.0 (3.6.9)]
* OS X + liblo 0.29 + [CPython3.6, CPython3.7, CPython3.8, PyPy7.3.0 (3.6.9)]

## Examples

### [Simple echo server](https://github.com/elijahr/aiolo/blob/master/examples/echo_server.py)
```python
import asyncio
import datetime
import logging
import multiprocessing
import sys

from aiolo import logger, Address, Bundle, Message, Server, ANY_ARGS, NO_ARGS, Midi


def pub():
    address = Address(url='osc.tcp://:10001')

    now = datetime.datetime.now(datetime.timezone.utc)

    print(f'{address}: sending messages...')
    for i in range(3):
        address.send('/foo', i, float(i), Midi(i, i, i, i))
        # alternatively, same behavior
        # address.send(Route('/foo', 'hdm'), 1, 2.0, Midi(1, 2, 3, 4))
        address.send('/bar', 'hello', 'world')

    # Send some delayed data; the server will receive it immediately but enqueue it for processing
    # at the specified bundle timetag
    bundle = Bundle()
    for i in range(3):
        bundle.add_bundle(Bundle([
            Message('/foo', i*10, float(i*10), Midi(i*10, i*10, i*10, i*10)),
        ], timetag=now + datetime.timedelta(seconds=i/4)))

    # send the bundle
    print(f'{address}: sending bundle {bundle}')
    address.bundle(bundle)

    # exit in 1 second
    print(f'{address}: notifying subscription to exit...')
    address.send('/exit')


async def main(verbose):
    if verbose:
        h = logging.StreamHandler()
        h.setLevel(logging.DEBUG)
        logger.addHandler(h)
        logger.setLevel(logging.DEBUG)

    server = Server(url='osc.tcp://:10001')
    server.start()

    # Create endpoints

    # /foo accepts an int, a float, and MIDI data
    foo = server.route('/foo', [int, float, Midi])

    # alternatively, same behavior:
    # foo = server.route('/foo', 'hdm')  # liblo syntax: h=64 bit int, d=double precision float, m=MIDI

    # /bar accepts any arguments
    bar = server.route('/bar', ANY_ARGS)

    # /exit accepts no arguments
    exit = server.route('/exit', NO_ARGS)

    # Subscribe to messages for any of the routes
    subscriptions = foo.sub() | bar.sub() | exit.sub()

    # Send data from another process
    proc = multiprocessing.Process(target=pub)
    proc.start()
    proc.join()

    async for route, data in subscriptions:
        print(f'{str(route.path)}: received {data}')
        if route == exit:
            # Unsubscribing isn't necessary but is good practice
            await subscriptions.unsub()
            break

    server.stop()


if __name__ == '__main__':
    asyncio.get_event_loop().run_until_complete(main(verbose='--verbose' in sys.argv))

```


### [MultiCast](https://github.com/elijahr/aiolo/blob/master/examples/multicast.py)
```python
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

```

For additional usage see the [examples](https://github.com/elijahr/aiolo/blob/master/examples) and [tests](https://github.com/elijahr/aiolo/blob/master/test.py).

## Contributing

Pull requests are welcome, please file any issues you encounter.