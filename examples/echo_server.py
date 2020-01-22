import asyncio
import datetime
import logging
import multiprocessing
import sys

from aiolo import logger, Address, Bundle, Message, Server, ANY_ARGS, NO_ARGS, Midi


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
