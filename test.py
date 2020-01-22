import asyncio
import datetime
import multiprocessing
import random
import sys
from typing import Union

import netifaces

import aiolo
import pytest

import test_data


CANCEL_TIMEOUT = 3


def create_task(coro):
    if sys.version_info[:2] >= (3, 7):
        task = asyncio.create_task(coro)
    else:
        task = asyncio.get_event_loop().create_task(coro)
    return task


@pytest.fixture
def event_loop():
    loop = asyncio.new_event_loop()
    asyncio.set_event_loop(loop)
    loop.set_debug(True)
    yield loop
    loop.close()


@pytest.fixture
@pytest.mark.asyncio
async def server(event_loop):
    server = aiolo.Server(url='osc.tcp://:10000')
    server.start()
    yield server
    server.stop()


@pytest.fixture
async def address(server):
    return aiolo.Address(url=server.url)


@pytest.fixture
@pytest.mark.asyncio
async def threaded_server(event_loop):
    threaded_server = aiolo.ThreadedServer(url='osc.tcp://:10001')
    threaded_server.start()
    # Give the thread some time to boot
    await asyncio.sleep(1)
    yield threaded_server
    threaded_server.stop()


@pytest.fixture
@pytest.mark.asyncio
async def multicast_cluster(event_loop):
    multicast = aiolo.MultiCast('224.0.1.1', port=10001)
    cluster = []
    for i in range(3):
        server = aiolo.Server(multicast=multicast)
        server.start()
        cluster.append(server)
    yield cluster
    for server in cluster:
        server.stop()


@pytest.fixture
async def multicast_address(multicast_cluster):
    return aiolo.MultiCastAddress(server=random.choice(multicast_cluster))


@pytest.fixture
def interfaces_by_ipv4():
    def get_ipv4(iface):
        try:
            return netifaces.ifaddresses(iface)[netifaces.AF_INET][0]['addr']
        except KeyError:
            return None

    return {
        get_ipv4(iface): iface
        for iface in netifaces.interfaces()
        if get_ipv4(iface)
    }


def get_interfaces_by_ipv6():
    def get_ipv6(iface):
        try:
            print(iface, netifaces.ifaddresses(iface)[netifaces.AF_INET6])
            return netifaces.ifaddresses(iface)[netifaces.AF_INET6][0]['addr']
        except KeyError:
            return None
    return {
        get_ipv6(iface): iface
        for iface in netifaces.interfaces()
        if get_ipv6(iface)
    }


@pytest.fixture
def interfaces_by_ipv6():
    return get_interfaces_by_ipv6()


def ipv6_servers():
    if '--ipv6' not in sys.argv:
        return
    for ip, iface in get_interfaces_by_ipv6().items():
        server = aiolo.Server(url='osc.tcp://[%s]:10000' % ip)
        server.start()
        yield server
        server.stop()


@pytest.mark.asyncio
async def test_multiple_addresses_and_threaded_server(event_loop, threaded_server):
    foo = threaded_server.route('/foo', str)
    address1 = aiolo.Address(url=threaded_server.url)
    address2 = aiolo.Address(url=threaded_server.url)
    address3 = aiolo.Address(url=threaded_server.url)
    task = create_task(subscribe(foo.sub(), 3))
    event_loop.call_later(CANCEL_TIMEOUT, task.cancel)
    address1.send(foo, 'address1')
    await asyncio.sleep(0.1)
    address2.send(foo, 'address2')
    await asyncio.sleep(0.1)
    address3.send(foo, 'address3')
    results = await task
    assert results == [['address1'], ['address2'], ['address3']]


def test_address_interface_ipv4(server, interfaces_by_ipv4):
    assert any(interfaces_by_ipv4)

    for iface in interfaces_by_ipv4.values():
        address = aiolo.Address(url=server.url)
        address.interface = iface
        assert address.interface == iface

    for ipv4, iface in interfaces_by_ipv4.items():
        address = aiolo.Address(url=server.url)
        assert address.interface is None
        address.set_ip(ipv4)
        assert address.interface == iface

    address = aiolo.Address(url=server.url)
    with pytest.raises(ValueError):
        address.interface = 'foobar0'
    with pytest.raises(ValueError):
        address.set_ip('foo.bar')
    with pytest.raises(ValueError):
        address.set_ip('1.2.3.4')


@pytest.mark.no_ipv6
@pytest.mark.asyncio
async def test_multicast(event_loop, multicast_cluster, multicast_address):
    foo = aiolo.Route('/foo', str)
    for s in multicast_cluster:
        s.route(foo)
    task = create_task(subscribe(foo.sub(), 3 * len(multicast_cluster)))
    event_loop.call_later(CANCEL_TIMEOUT, task.cancel)
    multicast_address.send(foo, 'foo')
    multicast_address.send(foo, 'bar')
    multicast_address.send(foo, 'baz')
    results = await task
    assert results == [['foo'], ['bar'], ['baz']] * len(multicast_cluster)


@pytest.mark.ipv6
@pytest.mark.parametrize('ipv6_server', ipv6_servers())
def test_address_interface_ipv6(ipv6_server, interfaces_by_ipv6):
    assert any(interfaces_by_ipv6)

    for ipv6, iface in interfaces_by_ipv6.items():
        address = aiolo.Address(url=ipv6_server.url)
        assert address.interface is None
        try:
            address.set_ip(ipv6)
        except Exception as exc:
            aiolo.logger.exception(exc)
        else:
            print("SET THE IP")
        assert address.interface == iface


@pytest.mark.asyncio
async def test_multiple_servers(event_loop):
    server1 = aiolo.Server(url='osc.tcp://:10002')
    server2 = aiolo.Server(url='osc.tcp://:10003')
    server3 = aiolo.Server(url='osc.tcp://:10004')
    server1.start()
    server2.start()
    server3.start()
    try:
        foo = server1.route('/foo', str)
        server2.route(foo)
        server3.route(foo)
        address1 = aiolo.Address(url=server1.url)
        address2 = aiolo.Address(url=server2.url)
        address3 = aiolo.Address(url=server3.url)
        task = create_task(subscribe(foo.sub(), 3))
        event_loop.call_later(CANCEL_TIMEOUT, task.cancel)
        address1.send(foo, 'address1')
        address2.send(foo, 'address2')
        address3.send(foo, 'address3')
        results = await task
        assert results == [['address1'], ['address2'], ['address3']]
    finally:
        server1.stop()
        server2.stop()
        server3.stop()


def valid_types_params():
    for path, test_case in test_data.TYPE_TEST_DATA.items():
        for argdef in test_case['argdefs']:
            for publish, expected in test_case['valid']:
                yield path, argdef, publish, expected
                yield path, [argdef, argdef], [publish, publish], [[expected[0][0], expected[0][0]]]
                yield path, aiolo.Argdef(argdef), [publish], expected


@pytest.mark.parametrize('path, argdef, publish, expected', valid_types_params())
@pytest.mark.asyncio
async def test_valid_types(event_loop, server, address, path, argdef, publish, expected):
    route = server.route(path, argdef)
    task = create_task(subscribe(route.sub(), 1))
    address.send(route, publish)
    event_loop.call_later(CANCEL_TIMEOUT, task.cancel)
    try:
        result = await task
    except asyncio.CancelledError:
        pytest.fail('%r: argdef=%r, publish=%r, never received data' % (route, argdef, publish))
    else:
        msg = '%r: argdef=%r, publish=%r, %r != %r' % (route, argdef, publish, result, expected)
        assert result == expected, msg


def invalid_types_params():
    for path, test_case in test_data.TYPE_TEST_DATA.items():
        for argdef in test_case['argdefs']:
            for invalid in test_case['invalid']:
                yield path, argdef, [invalid]
                yield path, aiolo.Argdef(argdef), [invalid]


@pytest.mark.parametrize('path, argdef, invalid', invalid_types_params())
@pytest.mark.asyncio
async def test_invalid_types(server, address, path, argdef, invalid):
    route = server.route(path, [argdef])
    with pytest.raises(ValueError):
        address.send(route, invalid)


@pytest.mark.parametrize('argdef,value', [
    (float, 42.0),
    (int, 42),
    (True, True),
    (False, False),
    (None, None),
])
def test_guess_argtypes(argdef, value):
    assert aiolo.guess_argtypes([value]) == bytes(aiolo.Argdef([argdef]))


@pytest.mark.asyncio
async def test_multiple_subs(event_loop, server, address):
    foo = server.route('/foo', 's')
    tasks = asyncio.gather(
        create_task(subscribe(foo.sub(), 1)),
        create_task(subscribe(foo.sub(), 1)),
    )
    event_loop.call_later(CANCEL_TIMEOUT, tasks.cancel)
    address.send(foo, 'bar')
    results = list(await tasks)
    assert results == [[['bar']], [['bar']]]


@pytest.mark.asyncio
async def test_unroute(event_loop, server, address):
    foo = server.route('/foo', 's')
    task = create_task(subscribe(foo.sub(), 1))
    event_loop.call_later(CANCEL_TIMEOUT, task.cancel)
    server.unroute(foo)
    address.send(foo, 'bar')
    with pytest.raises(asyncio.CancelledError):
        await task


@pytest.mark.asyncio
async def test_bundle(event_loop, server, address):
    routes = [
        server.route(path, 's')
        for path in ('/foo', '/bar', '/baz')
    ]
    tasks = asyncio.gather(*[
        create_task(subscribe(route.sub(), 1))
        for route in routes
    ])
    event_loop.call_later(CANCEL_TIMEOUT, tasks.cancel)
    address.bundle([
        aiolo.Message(route, str(route.path))
        for route in routes
    ])
    results = list(await tasks)
    assert results == [[['/foo']], [['/bar']], [['/baz']]]


@pytest.mark.asyncio
async def test_bundle_delayed(event_loop):
    server = aiolo.Server(url='osc.tcp://:10000')
    server.start()
    try:
        address = aiolo.Address(url=server.url)
        foo = server.route('/foo', 's')
        task = create_task(subscribe(foo.sub(), 1))
        event_loop.call_later(2, task.cancel)
        address.bundle([
            aiolo.Message(foo, 'now'),
            aiolo.Bundle(
                [aiolo.Message(foo, 'later')],
                timetag=datetime.datetime.now(datetime.timezone.utc) + datetime.timedelta(seconds=1))
        ])
        results = list(await task)
        assert results == [['now']]
        assert server.events_pending
        assert 0 < server.next_event_delay < 1
        task = create_task(subscribe(foo.sub(), 1))
        results = list(await task)
        assert results == [['later']]
    finally:
        server.stop()


@pytest.mark.asyncio
async def test_bundle_join(event_loop, server, address):
    foo = server.route('/foo', 's')
    bar = server.route('/bar', 's')
    bundle = aiolo.Bundle([aiolo.Message(foo, 'foo')])
    bundle &= aiolo.Bundle([aiolo.Message(bar, 'bar')])
    tasks = asyncio.gather(
        create_task(subscribe(foo.sub(), 1)),
        create_task(subscribe(bar.sub(), 1)),
    )
    address.bundle(bundle)
    event_loop.call_later(CANCEL_TIMEOUT, tasks.cancel)
    results = list(await tasks)
    assert results == [[['foo']], [['bar']]]


@pytest.mark.asyncio
async def test_route_pattern(event_loop, server, address):
    foo = server.route('/foo', 's')
    bar = server.route('/bar', 's')
    tasks = asyncio.gather(
        create_task(subscribe(foo.sub(), 1)),
        create_task(subscribe(bar.sub(), 1)),
    )
    event_loop.call_later(CANCEL_TIMEOUT, tasks.cancel)
    wildcard = aiolo.Route('/[a-z]*', 's')
    address.send(wildcard, ['baz'])
    results = list(await tasks)
    assert results == [[['baz']], [['baz']]]


@pytest.mark.asyncio
async def test_route_join(event_loop, server, address):
    foo = server.route('/foo', 's')
    bar = server.route('/bar', 's')
    baz = server.route('/baz', 's')
    spaz = server.route('/spaz', 's')
    tasks = asyncio.gather(
        create_task(subscribe(foo.sub(), 1)),
        create_task(subscribe(bar.sub(), 1)),
        create_task(subscribe(baz.sub(), 1)),
        create_task(subscribe(spaz.sub(), 1)),
    )
    event_loop.call_later(CANCEL_TIMEOUT, tasks.cancel)
    route = foo & bar
    assert route.is_pattern
    route &= baz
    route &= spaz
    assert route.is_pattern
    address.send(route, 'hello')
    results = list(await tasks)
    assert results == [[['hello']], [['hello']], [['hello']], [['hello']]]


def test_cannot_serve_pattern(server):
    with pytest.raises(ValueError):
        server.route('/[a-z]*', 's')
    with pytest.raises(ValueError):
        server.route(aiolo.Route('/[a-z]*', 's'))


@pytest.mark.asyncio
async def test_any_path(event_loop, server, address):
    any_path = server.route(aiolo.ANY_PATH, 's')
    task = create_task(subscribe(any_path.sub(), 1))
    event_loop.call_later(CANCEL_TIMEOUT, task.cancel)
    with pytest.raises(ValueError):
        address.send(any_path, ['foo'])
    address.send(aiolo.Route('/foo', 's'), ['foo'])
    results = list(await task)
    assert results == [['foo']]


@pytest.mark.asyncio
async def test_no_args(event_loop, server, address):
    foo = server.route('/foo', aiolo.NO_ARGS)
    task = create_task(subscribe(foo.sub(), 1))
    event_loop.call_later(CANCEL_TIMEOUT, task.cancel)
    address.send(foo)
    results = list(await task)
    assert results == [[]]


@pytest.mark.asyncio
async def test_any_args(event_loop, server, address):
    foo = server.route('/foo', aiolo.ANY_ARGS)
    task = create_task(subscribe(foo.sub(), 1))
    event_loop.call_later(CANCEL_TIMEOUT, task.cancel)
    address.send(foo, 'foo')
    results = list(await task)
    assert results == [['foo']]


@pytest.mark.asyncio
async def test_sub_join(event_loop, server, address):
    foo = server.route('/foo', 's')
    bar = server.route('/bar', 's')
    baz = server.route('/baz', 's')
    sub = foo.sub() | bar.sub() | baz.sub()
    task = create_task(subscribe(sub, 6))
    event_loop.call_later(CANCEL_TIMEOUT, task.cancel)
    address.send(foo, 'foo1')
    address.send(foo, 'foo2')
    address.send(bar, 'bar1')
    address.send(bar, 'bar2')
    address.send(baz, 'baz1')
    address.send(baz, 'baz2')
    results = await task
    assert results == {
        foo: [['foo1'], ['foo2']],
        bar: [['bar1'], ['bar2']],
        baz: [['baz1'], ['baz2']],
    }


def test_timetag():
    # assert that constants are sane
    assert aiolo.TT_IMMEDIATE == (0, 1)
    assert aiolo.TimeTag(aiolo.EPOCH_UTC) == (aiolo.JAN_1970, 0)

    # Test TT_IMMEDIATE is frozen
    tt = aiolo.TT_IMMEDIATE
    assert tt is aiolo.TT_IMMEDIATE
    tt += 1
    # FrozenTimeTag does not implement __iadd__ so a new instance is created for the name tt
    assert tt is not aiolo.TT_IMMEDIATE
    assert tt == (1, 1)
    assert aiolo.TT_IMMEDIATE == (0, 1)

    # Test operations
    tt = aiolo.TimeTag((0, 1))
    orig = tt
    tt = tt + 3
    assert tt == (3, 1)
    assert tt is not orig
    tt = tt - 2.1
    assert tt == (0, .9 * aiolo.FRAC_PER_SEC)
    assert tt is not orig

    # Test inplace operations
    tt = aiolo.TimeTag((0, 1))
    orig = tt
    tt += 3
    assert tt == (3, 1)
    assert tt is orig
    tt -= 2.1
    assert tt == (0, .9 * aiolo.FRAC_PER_SEC)
    assert tt is orig

    for dt in (
        aiolo.EPOCH_UTC,
        datetime.datetime(1905, 5, 5, 5, 5, 5, 5, datetime.timezone.utc),
        datetime.datetime(2026, 6, 6, 6, 6, 6, 6, datetime.timezone.utc),
    ):
        tt = aiolo.TimeTag(dt)
        assert tt == dt and tt <= dt <= tt
        assert tt.dt == dt and tt <= dt <= tt
        assert tt.osc_timestamp == aiolo.unix_timestamp_to_osc_timestamp(dt.timestamp())
        assert int(dt.timestamp()) == int(tt.unix_timestamp)
        assert pytest.approx(float(dt.timestamp()), rel=1e-6) == tt.unix_timestamp
        assert tuple(tt) == (tt.sec, tt.frac)

        for other in (
            aiolo.TimeTag(tt),
            dt,
            int(tt),
            float(tt),
            tuple(tt)
        ):
            # test comparison operators
            if isinstance(other, int):
                assert int(tt) == other
                assert tt >= other
                assert other <= tt
            else:
                assert tt == other
                assert tt <= other
                assert tt >= other
                assert not tt < other
                assert not other > tt
                assert not other != tt

        # frac precision is lost when comparing to datetime or int
        assert (tt + 0.000000001).unix_timestamp == tt.unix_timestamp
        assert (tt + 0.000000001).dt == tt.dt

        # frac precision is not lost when comparing to tuple or timetag
        assert tt + 0.1 != tt
        assert tt + 0.1 != tuple(tt)


async def subscribe(sub: Union[aiolo.Sub, aiolo.Subs], count: int):
    if isinstance(sub, aiolo.Subs):
        results = {}
        async for route, item in sub:
            results.setdefault(route, []).append(item)
            if len([v for values in results.values() for v in values]) == count:
                await sub.unsub()
                break
        return results
    else:
        items = []
        async for item in sub:
            items.append(item)
            if len(items) == count:
                await sub.unsub()
                break
        return items
