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
