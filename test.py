import asyncio
import sys
from typing import Union

import aiolo
import pytest

from test_data import TYPE_TEST_DATA


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
def server(event_loop):
    server = aiolo.Server(url='osc.tcp://:10000')
    server.start()
    yield server
    server.stop()


@pytest.fixture
def client(server):
    for route in set(server.routing.values()):
        server.unroute(route)
    return aiolo.Client(url=server.url)


def valid_types_params():
    for path, test_case in TYPE_TEST_DATA.items():
        for argdef in test_case['argdefs']:
            for publish, expected in test_case['valid']:
                yield path, argdef, publish, expected
                yield path, [argdef, argdef], [publish, publish], [[expected[0][0], expected[0][0]]]
                yield path, aiolo.Argdef(argdef), [publish], expected


@pytest.mark.parametrize('path, argdef, publish, expected', valid_types_params())
@pytest.mark.asyncio
async def test_valid_types(event_loop, server, client, path, argdef, publish, expected):
    route = server.route(path, argdef)
    task = create_task(subscribe(route.sub(), 1))
    client.pub(route, publish)
    event_loop.call_later(0.05, task.cancel)
    try:
        result = await task
    except asyncio.CancelledError:
        pytest.fail('%r: argdef=%r, publish=%r, never received data' % (route, argdef, publish))
    else:
        msg = '%r: argdef=%r, publish=%r, %r != %r' % (route, argdef, publish, result, expected)
        assert result == expected, msg


def invalid_types_params():
    for path, test_case in TYPE_TEST_DATA.items():
        for argdef in test_case['argdefs']:
            for invalid in test_case['invalid']:
                yield path, argdef, [invalid]
                yield path, aiolo.Argdef(argdef), [invalid]


@pytest.mark.parametrize('path, argdef, invalid', invalid_types_params())
@pytest.mark.asyncio
async def test_invalid_types(server, client, path, argdef, invalid):
    route = server.route(path, [argdef])
    with pytest.raises(ValueError):
        client.pub(route, invalid)


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
async def test_multiple_subs(event_loop, server, client):
    foo = server.route('/foo', 's')
    tasks = asyncio.gather(
        create_task(subscribe(foo.sub(), 1)),
        create_task(subscribe(foo.sub(), 1)),
    )
    event_loop.call_later(0.05, tasks.cancel)
    client.pub(foo, 'bar')
    results = list(await tasks)
    assert results == [[['bar']], [['bar']]]


@pytest.mark.asyncio
async def test_unroute(event_loop, server, client):
    foo = server.route('/foo', 's')
    task = create_task(subscribe(foo.sub(), 1))
    event_loop.call_later(0.05, task.cancel)
    server.unroute(foo)
    client.pub(foo, 'bar')
    with pytest.raises(asyncio.CancelledError):
        await task


@pytest.mark.asyncio
async def test_bundle(event_loop, server, client):
    routes = [
        server.route(path, 's')
        for path in ('/foo', '/bar', '/baz')
    ]
    tasks = asyncio.gather(*[
        create_task(subscribe(route.sub(), 1))
        for route in routes
    ])
    event_loop.call_later(0.05, tasks.cancel)
    client.bundle([
        aiolo.Message(route, str(route.path))
        for route in routes
    ])
    results = list(await tasks)
    assert results == [[['/foo']], [['/bar']], [['/baz']]]


@pytest.mark.asyncio
async def test_bundle_join(event_loop, server, client):
    foo = server.route('/foo', 's')
    bar = server.route('/bar', 's')
    bundle = aiolo.Bundle([aiolo.Message(foo, 'foo')])
    bundle &= aiolo.Bundle([aiolo.Message(bar, 'bar')])
    tasks = asyncio.gather(
        create_task(subscribe(foo.sub(), 1)),
        create_task(subscribe(bar.sub(), 1)),
    )
    client.bundle(bundle)
    event_loop.call_later(0.05, tasks.cancel)
    results = list(await tasks)
    assert results == [[['foo']], [['bar']]]


@pytest.mark.asyncio
async def test_route_pattern(event_loop, server, client):
    foo = server.route('/foo', 's')
    bar = server.route('/bar', 's')
    tasks = asyncio.gather(
        create_task(subscribe(foo.sub(), 1)),
        create_task(subscribe(bar.sub(), 1)),
    )
    event_loop.call_later(0.05, tasks.cancel)
    wildcard = aiolo.Route('/[a-z]*', 's')
    client.pub(wildcard, ['baz'])
    results = list(await tasks)
    assert results == [[['baz']], [['baz']]]


@pytest.mark.asyncio
async def test_route_join(event_loop, server, client):
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
    event_loop.call_later(0.05, tasks.cancel)
    route = foo & bar
    assert route.is_pattern
    route &= baz
    route &= spaz
    assert route.is_pattern
    client.pub(route, 'hello')
    results = list(await tasks)
    assert results == [[['hello']], [['hello']], [['hello']], [['hello']]]


def test_cannot_serve_pattern(server):
    with pytest.raises(ValueError):
        server.route('/[a-z]*', 's')
    with pytest.raises(ValueError):
        server.route(aiolo.Route('/[a-z]*', 's'))


@pytest.mark.asyncio
async def test_any_path(event_loop, server, client):
    any_path = server.route(aiolo.ANY_PATH, 's')
    task = create_task(subscribe(any_path.sub(), 1))
    event_loop.call_later(0.05, task.cancel)
    with pytest.raises(ValueError):
        client.pub(any_path, ['foo'])
    client.pub(aiolo.Route('/foo', 's'), ['foo'])
    results = list(await task)
    assert results == [['foo']]


@pytest.mark.asyncio
async def test_no_args(event_loop, server, client):
    foo = server.route('/foo', aiolo.NO_ARGS)
    task = create_task(subscribe(foo.sub(), 1))
    event_loop.call_later(0.05, task.cancel)
    client.pub(foo)
    results = list(await task)
    assert results == [[]]


@pytest.mark.asyncio
async def test_any_args(event_loop, server, client):
    foo = server.route('/foo', aiolo.ANY_ARGS)
    task = create_task(subscribe(foo.sub(), 1))
    event_loop.call_later(0.05, task.cancel)
    client.pub(foo, 'foo')
    results = list(await task)
    assert results == [['foo']]


@pytest.mark.asyncio
async def test_sub_join(event_loop, server, client):
    foo = server.route('/foo', 's')
    bar = server.route('/bar', 's')
    sub = foo.sub() | bar.sub()
    task = create_task(subscribe(sub, 2))
    event_loop.call_later(0.1, task.cancel)
    client.pub(foo, 'foo')
    client.pub(bar, 'bar')
    results = list(await task)
    assert sorted(results) == [['bar'], ['foo']]


async def subscribe(sub: Union[aiolo.Sub, aiolo.Subs], count: int):
    items = []
    async for item in sub:
        items.append(item)
        if len(items) == count:
            sub.unsub()
            break
    return items
