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
