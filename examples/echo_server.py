"""
Hammer a server with data
"""

import asyncio
import datetime
import logging
import multiprocessing
import sys

from aiolo import logger, Address, Message, AioServer, NO_ARGS


def pub():
    address = Address(url='osc.tcp://:10001')

    now = datetime.datetime.now(datetime.timezone.utc)

    # Send some delayed data; the server will receive it immediately but enqueue it for processing
    # at the specified bundle timetag
    for i in range(10000):
        address.bundle([
            Message('/foo', bytearray([0]*10000)),
        ], timetag=now + datetime.timedelta(microseconds=i))

    address.bundle([
        Message('/exit'),
    ], timetag=now + datetime.timedelta(seconds=10000))


async def main(verbose):
    if verbose:
        h = logging.StreamHandler()
        h.setLevel(logging.DEBUG)
        logger.addHandler(h)
        logger.setLevel(logging.DEBUG)

    server = AioServer(url='osc.tcp://:10001')
    server.start()

    # Create endpoints

    # /foo accepts an int, a float, and MIDI data
    foo = server.route('/foo', bytearray)
    foo = server.route('/exit', NO_ARGS)

    # Subscribe to messages for any of the routes
    subscriptions =  foo.sub() | exit.sub()

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