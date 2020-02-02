import array
import asyncio
import contextlib
import datetime
import functools
import random
import sys
from typing import Union

import netifaces
import pytest
import uvloop as uvloop

import test_data
from aiolo import MultiCast, AioServer, Address, Message, PROTO_UDP, PROTO_UNIX, TimeTag, FRAC_PER_SEC, \
    NO_ARGS, Route, unix_timestamp_to_osc_timestamp, TT_IMMEDIATE, Sub, MultiCastAddress, Bundle, ANY_PATH, TypeSpec, \
    Subs, StartError, PROTO_DEFAULT, EPOCH_UTC, ANY_ARGS, JAN_1970, ThreadedServer, Midi, PROTO_TCP, INFINITY, \
    INFINITUM, TIMETAG, MIDI, NIL, FALSE, TRUE, BLOB, STRING, DOUBLE, INT64, Path, \
    compile_osc_address_pattern


CANCEL_TIMEOUT = 6


def create_task(coro, cancel_timeout=CANCEL_TIMEOUT):
    loop = asyncio.get_event_loop()
    if sys.version_info[:2] >= (3, 7):
        task = asyncio.create_task(coro)
    else:
        task = loop.create_task(coro)
    if cancel_timeout >= 0:
        loop.call_later(cancel_timeout, task.cancel)
    return task


def get_ipv4(iface):
    try:
        return netifaces.ifaddresses(iface)[netifaces.AF_INET][0]['addr']
    except KeyError:
        return None


def now():
    return datetime.datetime.now(datetime.timezone.utc)


@pytest.fixture(params=[
    iface
    for iface in netifaces.interfaces()
    if get_ipv4(iface) and get_ipv4(iface) != '127.0.0.1'
])
def ip_interface(request):
    iface = request.param
    return get_ipv4(iface), iface


@pytest.fixture(params=[
    asyncio,
    uvloop
])
def event_loop(request):
    loop_mod = request.param
    loop = loop_mod.new_event_loop()
    asyncio.set_event_loop(loop)
    loop.set_debug(True)
    with contextlib.closing(loop):
        yield loop


@pytest.fixture(params=[
    AioServer,
    ThreadedServer
])
def any_server_class(request, event_loop):
    return request.param


@pytest.fixture
async def any_server(any_server_class, unused_tcp_port_factory):
    tries = 0

    exc = None
    server = any_server_class(port=unused_tcp_port_factory())
    while tries < 3:
        try:
            server.start()
        except StartError as exc:
            await asyncio.sleep(0.1)
            server = any_server_class(port=unused_tcp_port_factory())
        else:
            break
        tries += 1
    if not server.running:
        raise StartError from exc
    yield server
    server.stop()


@pytest.fixture
async def server(event_loop, unused_tcp_port_factory):
    tries = 0
    while tries < 3:
        try:
            server = AioServer(port=unused_tcp_port_factory())
            server.start()
        except StartError:
            await asyncio.sleep(0.1)
        else:
            break
        tries += 1
    yield server
    server.stop()


@pytest.fixture(params=[
    lambda cls, port: cls(),
    lambda cls, port: cls(port=port()),
    lambda cls, port: cls(url='osc.udp://:%s' % port()),
    lambda cls, port: cls(url='osc.unix:///tmp/test-aiolo-%s.osc' % port()),
    lambda cls, port: cls(proto=PROTO_TCP, port=port()),
    lambda cls, port: cls(proto=PROTO_UDP, port=port()),
    lambda cls, port: cls(proto=PROTO_UNIX, port='/tmp/test-aiolo-%s.osc' % port()),
    lambda cls, port: cls(multicast=MultiCast('224.0.1.1', port=port())),
])
def server_init_factory(request, any_server_class, unused_tcp_port_factory):
    return functools.partial(request.param, any_server_class, unused_tcp_port_factory)


def test_server_init(server_init_factory):
    """
    Test that servers can be constructed and started with various call patterns.
    """
    server = server_init_factory()
    server.start()
    assert server.running
    assert server.port is not None
    server.stop()


def test_server_init_proto_default_udp_port(any_server_class, unused_tcp_port):
    server = any_server_class(proto=PROTO_DEFAULT, port=unused_tcp_port)
    server.start()
    assert server.running
    assert server.proto == PROTO_UDP
    assert server.port is not None
    server.stop()


def test_server_init_proto_default_unix_port(any_server_class, unused_tcp_port):
    server = any_server_class(proto=PROTO_DEFAULT, port='/tmp/test-aiolo-%s.osc' % unused_tcp_port)
    server.start()
    assert server.running
    assert server.proto == PROTO_UNIX
    assert server.port is not None
    server.stop()


@pytest.fixture(params=[
    lambda cls, port: cls(port='/foo'),
    lambda cls, port: cls(port=-1),
    lambda cls, port: cls(url='osc.foo://:%s' % port()),
])
def server_start_error_factory(request, any_server_class, unused_tcp_port_factory):
    return functools.partial(request.param, any_server_class, unused_tcp_port_factory)


def test_server_start_error(server_start_error_factory):
    server = server_start_error_factory()
    with pytest.raises(StartError):
        server.start()


def server_init_error_multicast_factory(any_server_class, unused_tcp_port_factory):
    port = unused_tcp_port_factory()
    return any_server_class(
        url='osc.tcp://:%s' % port,
        multicast=MultiCast('224.0.1.1', port=port()))


@pytest.fixture(params=[
    lambda cls, port: cls(multicast='foo'),
    lambda cls, port: cls(proto=-1, port=port()),
    lambda cls, port: cls(proto='foo', port=port()),
    lambda cls, port: cls(url='osc.tcp://:%s' % port(), port='10'),
    lambda cls, port: cls(url='osc.tcp://:%s' % port(), proto=PROTO_UDP),
    server_init_error_multicast_factory,
    lambda cls, port: cls(proto=PROTO_TCP, multicast=MultiCast('224.0.1.1', port=port())),
    lambda cls, port: cls(port='10', multicast=MultiCast('224.0.1.1', port=port())),
])
def server_init_error_factory(request, any_server_class, unused_tcp_port_factory):
    return functools.partial(request.param, any_server_class, unused_tcp_port_factory)


def test_server_init_error(server_init_error_factory):
    with pytest.raises((ValueError, TypeError)):
        server_init_error_factory()


@pytest.mark.asyncio
async def test_subs_unsub(event_loop):
    foo = Sub(Route('/foo', ANY_ARGS))
    bar = Sub(Route('/bar', ANY_ARGS))
    subs = foo | bar
    task = create_task(subscribe(subs, 3))
    await foo.pub('1')
    await bar.pub('2')
    await bar.unsub()
    await foo.pub('3')
    results = await task
    assert_results(results, {bar.route: ['2'], foo.route: ['1', '3']})


@pytest.mark.asyncio
async def test_multiple_addresses(any_server):
    """
    Test that multiple clients can send data to a single server
    """
    foo = any_server.route('/foo', int)
    addresses = [Address(port=any_server.port) for i in range(3)]
    task = create_task(subscribe(foo.sub(), 3))
    for i, address in enumerate(addresses):
        address.send(foo, i)
        await asyncio.sleep(0.1)
    results = await task
    assert results == [[0], [1], [2]]


@pytest.fixture(params=[
    lambda port, ip, iface: (
        Address(url='osc.tcp://%s:%s' % (ip, port())),
        ip, iface),
    lambda port, ip, iface: (
        Address(url='osc.udp://%s:%s' % (ip, port())),
        ip, iface),
    lambda port, ip, iface: (
        Address(url='osc.unix:///aiolo-test-%s.osc' % port()),
        ip, iface),
    lambda port, ip, iface: (
        Address(proto=PROTO_TCP, host=ip, port=port()),
        ip, iface),
    lambda port, ip, iface: (
        Address(proto=PROTO_UDP, host=ip, port=port()),
        ip, iface),
    lambda port, ip, iface: (
        Address(proto=PROTO_UNIX, host=ip, port='/tmp/aiolo-test-%s.osc' % port()),
        ip, iface),
])
def address_init_factory(request, ip_interface, unused_tcp_port_factory):
    ip, iface = ip_interface
    return functools.partial(request.param, unused_tcp_port_factory, ip, iface)


def test_address_init(address_init_factory):
    """
    Test Address initialization and state.
    """
    address, ip, iface = address_init_factory()

    if iface is None or address.proto in (PROTO_UNIX, PROTO_DEFAULT):
        with pytest.raises(ValueError):
            address.interface = iface
    else:
        address.interface = iface
        assert address.interface == iface

    address, ip, iface = address_init_factory()
    if not ip or address.proto == PROTO_UNIX:
        with pytest.raises(ValueError):
            address.set_ip(ip)
    else:
        assert address.interface is None
        address.set_ip(ip)
        assert address.interface == iface

    address, ip, iface = address_init_factory()
    with pytest.raises(ValueError):
        address.interface = 'foobar0'
    with pytest.raises(ValueError):
        address.set_ip('foo.bar')
    with pytest.raises(ValueError):
        address.set_ip('1.2.3.4')


@pytest.mark.asyncio
async def test_multicast(any_server_class, unused_tcp_port):
    """
    Test multicast send/receive.
    """
    cluster = []
    multicast = MultiCast('224.0.1.1', port=unused_tcp_port)
    for i in range(3):
        server = any_server_class(multicast=multicast)
        server.start()
        cluster.append(server)

    address = MultiCastAddress(server=random.choice(cluster))
    foo = Route('/foo', str)

    for s in cluster:
        s.route(foo)

    task = create_task(
        subscribe(foo.sub(), 3 * len(cluster)),
        cancel_timeout=CANCEL_TIMEOUT * len(cluster))

    for d in ['foo', 'bar', 'baz']:
        address.send(foo, d)
        await asyncio.sleep(1)

    results = await task

    assert results.count(['foo']) == len(cluster)
    assert results.count(['bar']) == len(cluster)
    assert results.count(['baz']) == len(cluster)
    for s in cluster:
        s.stop()


@pytest.mark.asyncio
async def test_multiple_servers(any_server_class, unused_tcp_port_factory):
    """
    Test that multiple servers can run okay in the same process.
    """
    servers = []
    addresses = []
    foo = Route('/foo', int)

    for i in range(3):
        server = any_server_class(url='osc.tcp://:%s' % unused_tcp_port_factory())
        server.route(foo)
        server.start()
        servers.append(server)
        address = Address(url=server.url)
        addresses.append(address)

    task = create_task(subscribe(foo.sub(), 3))
    for i, address in enumerate(addresses):
        address.send(foo, i)

    try:
        results = await task
        assert set([r[0] for r in results]) == {0, 1, 2}
    finally:
        for server in servers:
            server.stop()


def typespec_unpack_message_data():
    for t in test_data.ARGDEF_TEST_DATA:
        for typespec in t.typespecs:
            for value, expected in t.valid:
                if isinstance(typespec, int) and not isinstance(typespec, bool):
                    # Test unicode typespec like 'h'
                    yield t.path, chr(typespec), value, [expected]
                yield t.path, typespec, value, [expected]
                yield t.path, [typespec, typespec], [value, value], [expected, expected]


@pytest.mark.parametrize('path, typespec, data, expected', typespec_unpack_message_data())
def test_typespec_unpack_message(path, typespec, data, expected):
    """
    Test that types get parsed correctly
    """
    route = Route(path, typespec)
    message = Message(route, data)
    assert message.unpack() == expected

def typespec_unpack_message_type_error_data():
    for typespec_test_data in test_data.ARGDEF_TEST_DATA:
        for typespec in typespec_test_data.typespecs:
            for value in typespec_test_data.type_error:
                yield typespec_test_data.path, typespec, [value]


@pytest.mark.parametrize('path, typespec, data', typespec_unpack_message_type_error_data())
def test_typespec_unpack_message_type_error(path, typespec, data):
    """
    Test that TypeError is raised for invalid data types
    """
    route = Route(path, typespec)
    with pytest.raises(TypeError):
        message = Message(route, data)
        message.unpack()


def typespec_unpack_message_overflow_error_data():
    for t in test_data.ARGDEF_TEST_DATA:
        for typespec in t.typespecs:
            for value in t.overflow_error:
                yield t.path, typespec, [value]


@pytest.mark.parametrize('path, typespec, data', typespec_unpack_message_overflow_error_data())
def test_typespec_unpack_message_overflow_error(path, typespec, data):
    """
    Test that OverflowError is raised for invalid data types
    """
    route = Route(path, typespec)
    with pytest.raises(OverflowError):
        message = Message(route, data)
        message.unpack()


def typespec_unpack_message_value_error_data():
    for t in test_data.ARGDEF_TEST_DATA:
        for typespec in t.typespecs:
            for value in t.value_error:
                yield t.path, typespec, [value]


@pytest.mark.parametrize('path, typespec, data', typespec_unpack_message_value_error_data())
def test_typespec_unpack_message_value_error(path, typespec, data):
    """
    Test that ValueError is raised for invalid data values
    """
    route = Route(path, typespec)
    with pytest.raises(ValueError):
        message = Message(route, data)
        message.unpack()


@pytest.mark.parametrize('value, typespec', [
    [1, INT64],
    [1.0, DOUBLE],
    [0, INT64],
    [0.0, DOUBLE],
    [42, INT64],
    [42.0, DOUBLE],
    ['foo', STRING],
    [b'foo', BLOB],
    [array.array('b', b'foo'), BLOB],
    [True, TRUE],
    [False, FALSE],
    [None, NIL],
    [Midi(1, 2, 3, 4), MIDI],
    [now(), TIMETAG],
    [TimeTag(), TIMETAG],
    [INFINITY, INFINITUM],
])
def test_typespec_guess(value, typespec):
    assert TypeSpec.guess([value]) == TypeSpec(typespec)


@pytest.mark.parametrize('value', [
    {},
    [],
])
def test_typespec_guess_type_error(value):
    with pytest.raises(TypeError):
        TypeSpec.guess([value])


@pytest.mark.asyncio
async def test_multiple_subs(any_server):
    address = Address(url=any_server.url)
    foo = any_server.route('/foo', 's')
    tasks = asyncio.gather(
        create_task(subscribe(foo.sub(), 1)),
        create_task(subscribe(foo.sub(), 1)),
    )
    address.send(foo, 'bar')
    results = list(await tasks)
    assert results == [[['bar']], [['bar']]]


@pytest.mark.asyncio
async def test_unroute(server):
    address = Address(url=server.url)
    foo = server.route('/foo', 's')
    task = create_task(subscribe(foo.sub(), 1))
    server.unroute(foo)
    address.send(foo, 'bar')
    with pytest.raises(asyncio.CancelledError):
        await task


@pytest.mark.asyncio
async def test_bundle(server):
    address = Address(url=server.url)
    foo = server.route('/foo', 's')
    bar = server.route('/bar', 's')
    baz = server.route('/baz', 's')
    subs = foo.sub() | bar.sub() | baz.sub()
    task = create_task(subscribe(subs, 3))
    address.bundle([
        Message(foo, 'foo'),
        Message(bar, 'bar'),
        Message(baz, 'baz'),
    ])
    results = await task
    assert_results(results, {foo: [['foo']], bar: [['bar']], baz: [['baz']]})


@pytest.mark.asyncio
async def test_bundle_delayed(server):
    address = Address(url=server.url)
    foo = server.route('/foo', 's')
    task = create_task(subscribe(foo.sub(), 1), cancel_timeout=2)
    address.bundle([
        Message(foo, 'now'),
        Bundle(
            [Message(foo, 'later')],
            timetag=now() + datetime.timedelta(seconds=1))
    ])
    results = list(await task)
    assert results == [['now']]
    assert server.events_pending
    assert 0 < server.next_event_delay < 1
    task = create_task(subscribe(foo.sub(), 1))
    results = list(await task)
    assert results == [['later']]


def test_bundle_and_message_ops():
    foo = Route('/foo', 's')
    bar = Route('/bar', 's')
    baz = Route('/baz', 's')
    spaz = Route('/spaz', 's')
    bundle = Bundle()
    assert bundle == Bundle()

    with pytest.raises(IndexError):
        assert bundle[0]

    message = Message(foo, 'foo')
    assert message == Message(foo, 'foo')
    assert bundle != Bundle(message)

    # Test hashable
    items = {bundle, message}
    assert len(items) == 2
    assert bundle in items
    assert message in items
    items.add(Bundle())
    assert len(items) == 2
    items.add(Message(foo, 'foo'))
    assert len(items) == 2
    items.add(Bundle(timetag=now()))
    assert len(items) == 3
    items.add(Message(bar, 'bar'))
    assert len(items) == 4

    # Test adding a message to a bundle via __iadd__
    orig = bundle
    bundle += Message(foo, 'foo')
    assert bundle[0] == Message(foo, 'foo')
    assert bundle is orig

    # Test adding several messages at once
    bundle += [Message(bar, 'bar'), Message(baz, 'baz')]
    assert bundle[1] == Message(bar, 'bar')
    assert bundle[2] == Message(baz, 'baz')

    # Test adding a nested bundle
    bundle += Bundle(Message(spaz, 'spaz'))
    assert bundle[3] == Bundle(Message(spaz, 'spaz'))

    # Test __add__ instead of __iadd__
    other = Message(foo, 'foo') + Message(bar, 'bar') + Message(baz, 'baz')
    assert bundle != other
    assert bundle != other + Message(spaz, 'spaz')
    assert bundle == other + Bundle(Message(spaz, 'spaz'))

    # test sorting bundles
    timetag = TimeTag(now())
    bundles = (
        Bundle(timetag=timetag + 2),
        Bundle(timetag=timetag + 1),
        Bundle(timetag=timetag + 4),
        Bundle(timetag=timetag + 3))
    bundle2, bundle1, bundle4, bundle3 = bundles

    assert sorted(bundles) == [bundle1, bundle2, bundle3, bundle4]


def test_message_arglength_mismatch():
    foo = Route('/foo', 's')
    with pytest.raises(ValueError, match=r'Argument length does not match typespec .*'):
        Message(foo, 'foo', 'bar')


@pytest.mark.asyncio
async def test_route_pattern(server):
    address = Address(url=server.url)
    foo = server.route('/aaa/foo', 's')
    bar = server.route('/bbb/foo', 's')
    sub = foo.sub() | bar.sub()
    task = create_task(subscribe(sub, 4))
    address.send(Route('//foo', 's'), ['xpath'])
    address.send(Route('/{aaa,bbb}/foo', 's'), ['array'])
    results = await task
    assert_results(results, {foo: [['xpath'], ['array']], bar: [['xpath'], ['array']]})


@pytest.mark.parametrize('path,pattern,expect_match', [
    ('/x1y', '/x{1,10,11}y', True),
    ('/x10y', '/x{1,10,11}y', True),
    ('/x11y', '/x{1,10,11}y', True),
    ('/x2y', '/x{1,10,11}y', False),
    ('/x12y', '/x{1,10,11}y', False),
    ('/x12y', '/x{11}y', False),
    ('/x12y', '/x{12}y', True),
    ('/x1,2y', r'/x{1\,2}y', True),
    ('/xy', r'/x{,}y', True),
    ('/aaa/foo', '/{aaa,bbb}/foo', True),

    # Test [] pattern
    ('/x1y', '/x[321]y', True),
    ('/x4y', '/x[321]y', False),
    ('/x2y', '/x[1-3]y', True),
    ('/x3y', '/x[2-3]y', True),
    ('/xzy', '/x[2-3z]y', True),
    ('/x1y', '/x[!a-z]y', True),
    ('/x1y', '/x[a-z]y', False),
    ('/xby', '/x[a-z]y', True),
    # spec 1.0: "A - at the end of the string has no special meaning"
    ('/x-y', '/x[23-]y', True),
    # spec 1.0: "An ! anywhere besides the first character after the
    # open bracket has no special meaning"
    ('/x!y', '/x[a-z!]y', True),

    # Test * pattern
    ('/x123y', '/x*y', True),
    ('/x123y', '/x*z', False),

    # Test ? pattern
    ('/x1y', '/x?y', True),
    ('/x?y', '/x?y', True),

    # Test ?, *, and [] with multiple /
    ('/xy/z', '/*/?', True),
    ('/xy/z', '/?/*', False),
    ('/w/xy/z', '/[xyzw]/*/?', True),

    # Test '//' from spec 1.1
    ('/z', '//z', True),
    ('/xy/z', '//z', True),
    ('/xy/z/w/u', '///w/u', True),
    ('/xy/z/w/u', '///z/w', False),

    # Now some more tests for special pattern characters
    ('/xy/z/w/u?', '///w/u[?]', True),
    ('/xy/z/w/u?', '///w/u[!?]', False),
    ('/xy/z/w/u{1,2}', r'///w/u\{1,2\}', True),
    ('/xy/z/w/u2', r'///w/u\{1,2\}', False),
    (r'/xy/z/w/u-', r'///w/u[-]', True),
    (r'/xy/z/w/u-', r'///w/u[\\-]', True),
    (r'/xy/z/w/ua-', r'///w/u[a-][-]', True),
])
def test_compile_osc_address_pattern(path, pattern, expect_match):
    regex = compile_osc_address_pattern(pattern)
    if expect_match:
        assert regex.match(path) is not None
    else:
        assert regex.match(path) is None


@pytest.mark.parametrize('char', '#{}[]!?*,-^\\'.split())
def test_cannot_serve_pattern(server, char):
    with pytest.raises(ValueError):
        server.route(char, 's')
    with pytest.raises(ValueError):
        route = Route(char, 's')
        assert route.is_pattern
        server.route(route)


@pytest.mark.asyncio
async def test_route_any_path(server):
    address = Address(url=server.url)
    any_path = server.route(ANY_PATH, 's')
    task = create_task(subscribe(any_path.sub(), 1))
    with pytest.raises(ValueError):
        address.send(any_path, ['foo'])
    address.send(Route('/foo', 's'), ['foo'])
    results = list(await task)
    assert results == [['foo']]


@pytest.mark.asyncio
async def test_route_no_args(server):
    address = Address(url=server.url)
    foo = server.route('/foo', NO_ARGS)
    task = create_task(subscribe(foo.sub(), 1))
    address.send(foo)
    results = list(await task)
    assert results == [[]]


@pytest.mark.asyncio
async def test_route_any_args(server):
    address = Address(url=server.url)
    foo = server.route('/foo', ANY_ARGS)
    task = create_task(subscribe(foo.sub(), 1))
    address.send(foo, 'foo')
    results = list(await task)
    assert results == [['foo']]


@pytest.mark.asyncio
async def test_sub_join(server):
    address = Address(url=server.url)
    foo = server.route('/foo', 's')
    bar = server.route('/bar', 's')
    baz = server.route('/baz', 's')
    foo_sub = foo.sub()
    bar_sub = bar.sub()
    baz_sub = baz.sub()
    sub = foo_sub | bar_sub
    assert foo in sub
    assert foo_sub in sub
    assert baz not in sub
    sub |= baz_sub
    sub |= sub  # no-op
    assert len(sub) == 3
    assert sub == foo_sub | bar_sub | baz_sub
    assert sub == foo.sub() | bar.sub() | baz.sub()
    assert sub != foo.sub() | bar.sub()
    assert sub not in foo.sub() | bar.sub()
    assert sub in foo.sub() | bar.sub() | baz.sub()
    assert (foo.sub() | bar.sub()) in sub

    task = create_task(subscribe(sub, 6))

    for route, data in {
        foo: ['foo1', 'foo2'],
        bar: ['bar1', 'bar2'],
        baz: ['baz1', 'baz2']
    }.items():
        for d in data:
            address.send(route, d)

    results = await task
    assert_results(results, {
        foo: [['foo1'], ['foo2']],
        bar: [['bar1'], ['bar2']],
        baz: [['baz1'], ['baz2']],
    })


def test_typespec_ops():
    typespec = TypeSpec(str)
    assert typespec == 's'
    assert typespec == (str, )
    typespec = TypeSpec(str) + TypeSpec(int)
    assert typespec == 'sh'
    assert typespec == (str, int)
    typespec += 'h'
    assert typespec == 'shh'
    assert typespec == (str, int, int)
    assert typespec == TypeSpec('shh')
    with pytest.raises(ValueError):
        typespec += ANY_ARGS
    with pytest.raises(ValueError):
        typespec += NO_ARGS
    assert ANY_ARGS + ANY_ARGS == ANY_ARGS
    assert NO_ARGS + NO_ARGS == NO_ARGS
    assert NO_ARGS == NO_ARGS
    assert NO_ARGS != ANY_ARGS
    assert ANY_ARGS != NO_ARGS
    assert typespec in ANY_ARGS
    assert typespec not in NO_ARGS
    assert NO_ARGS in NO_ARGS
    assert NO_ARGS not in typespec
    assert NO_ARGS in ANY_ARGS
    assert ANY_ARGS not in NO_ARGS
    assert ANY_ARGS in ANY_ARGS


def test_path_ops():
    foo = Path('/foo')
    assert not foo.is_pattern
    assert foo in foo
    assert foo in ANY_PATH
    assert ANY_PATH not in foo
    barfoo = Path('/bar/foo')
    pattern = Path('//foo')
    assert pattern.is_pattern
    assert barfoo in pattern
    assert foo in pattern


def test_timetag():
    # assert that constants are sane
    assert TT_IMMEDIATE == (0, 1)
    assert TimeTag(EPOCH_UTC) == (JAN_1970, 0)

    # Test TT_IMMEDIATE is frozen
    tt = TT_IMMEDIATE
    assert tt is TT_IMMEDIATE
    tt += 1
    # FrozenTimeTag does not implement __iadd__ so a new instance is created for the name tt
    assert tt is not TT_IMMEDIATE
    assert tt == (1, 1)
    assert TT_IMMEDIATE == (0, 1)

    # Test operations
    tt = TimeTag((0, 1))
    orig = tt
    tt = tt + 3
    assert tt == (3, 1)
    assert tt is not orig
    tt = tt - 2.1
    assert tt == (0, .9 * FRAC_PER_SEC)
    assert tt is not orig

    # Test inplace operations
    tt = TimeTag((0, 1))
    orig = tt
    tt += 3
    assert tt == (3, 1)
    assert tt is orig
    tt -= 2.1
    assert tt == (0, .9 * FRAC_PER_SEC)
    assert tt is orig

    for dt in (
            EPOCH_UTC,
            datetime.datetime(1905, 5, 5, 5, 5, 5, 5, datetime.timezone.utc),
            datetime.datetime(2026, 6, 6, 6, 6, 6, 6, datetime.timezone.utc),
    ):
        tt = TimeTag(dt)
        assert tt == dt and tt <= dt <= tt
        assert tt.dt == dt and tt <= dt <= tt
        assert tt.osc_timestamp == unix_timestamp_to_osc_timestamp(dt.timestamp())
        assert int(dt.timestamp()) == int(tt.unix_timestamp)
        assert pytest.approx(float(dt.timestamp()), rel=1e-6) == tt.unix_timestamp
        assert tuple(tt) == (tt.sec, tt.frac)

        for other in (
                TimeTag(tt),
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


def assert_results(results_dict, expected):
    assert set(results_dict.keys()) == set(expected.keys())
    for route, results in expected.items():
        for result in results:
            assert result in results_dict[route]


async def subscribe(sub: Union[Sub, Subs], count: int):
    if isinstance(sub, Subs):
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


if __name__ == '__main__':
    pytest.main()
