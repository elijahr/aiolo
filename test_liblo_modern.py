import array
import asyncio
import socket
import pytest

from aiolo import (
    AioServer,
    Address,
    Message,
    Bundle,
    TimeTag,
    TypeSpec,
    ServerConfig,
    PROTO_UDP,
    pattern_match,
    servers_recv_noblock,
    servers_wait,
    LO_VERSION,
)


def get_free_port() -> int:
    with socket.socket(socket.AF_INET, socket.SOCK_DGRAM) as s:
        s.bind(("", 0))
        return s.getsockname()[1]


@pytest.mark.asyncio
async def test_bundle_clear():
    b = Bundle()
    msg1 = Message("/test/1", "hello")
    msg2 = Message("/test/2", "world")
    b.add(msg1)
    b.add(msg2)
    assert len(b) == 2
    assert list(b) == [msg1, msg2]

    # Clear bundle for reuse
    b.clear()
    assert len(b) == 0
    assert list(b) == []

    # Can reuse cleared bundle
    msg3 = Message("/test/3", "reused")
    b.add(msg3)
    assert len(b) == 1
    assert list(b) == [msg3]


@pytest.mark.asyncio
async def test_bundle_set_timetag():
    tt1 = TimeTag(100.0)
    tt2 = TimeTag(200.0)
    b = Bundle(timetag=tt1)
    assert b.timetag == tt1

    b.set_timetag(tt2)
    assert b.timetag == tt2


@pytest.mark.asyncio
async def test_zero_length_blob():
    port = get_free_port()
    if LO_VERSION < "0.32":
        addr = Address(port=port)
        with pytest.raises(ValueError, match="must have length >= 1 in liblo < 0.32"):
            addr.send("/empty_blob", b"")
        return

    server = AioServer(port=port)
    route = server.route("/empty_blob", array.array)
    sub = route.sub()

    server.start()
    try:
        addr = Address(port=port)
        # Send zero-length bytes as blob
        addr.send("/empty_blob", b"")

        args = await asyncio.wait_for(sub.next(), timeout=2.0)
        assert len(args) == 1
        blob = args[0]
        assert len(blob) == 0
        if isinstance(blob, array.array):
            assert blob.tobytes() == b""
        else:
            assert bytes(blob) == b""
    finally:
        await sub.unsub()
        server.stop()


def test_native_pattern_match():
    # Basic wildcards
    assert pattern_match("/foo/bar", "/foo/*") is True
    assert pattern_match("/foo/bar", "/foo/bar") is True
    assert pattern_match("/foo/bar", "/foo/baz") is False

    # Multi-choice braces
    assert pattern_match("/cmd/cut", "/cmd/{cut,copy,paste}") is True
    assert pattern_match("/cmd/copy", "/cmd/{cut,copy,paste}") is True
    assert pattern_match("/cmd/delete", "/cmd/{cut,copy,paste}") is False

    # Character classes
    assert pattern_match("/item/3", "/item/[0-9]") is True
    assert pattern_match("/item/a", "/item/[0-9]") is False

    # Double slash wildcard (OSC 1.1)
    assert pattern_match("/a/b/c", "//c") is True
    assert pattern_match("/x/y/z", "//z") is True


@pytest.mark.asyncio
async def test_server_config_initialization():
    port = get_free_port()
    cfg = ServerConfig(port=port, proto=PROTO_UDP)
    server = AioServer(config=cfg)
    assert server.config == cfg
    assert server.port == str(port)

    server.start()
    try:
        assert server.running is True
    finally:
        server.stop()


@pytest.mark.asyncio
async def test_multi_server_polling():
    port1 = get_free_port()
    port2 = get_free_port()

    s1 = AioServer(port=port1)
    s2 = AioServer(port=port2)

    r1 = s1.route("/s1", str)
    r2 = s2.route("/s2", str)

    sub1 = r1.sub()
    sub2 = r2.sub()

    s1.start()
    s2.start()

    try:
        # Initially no events waiting
        assert len(servers_wait([s1, s2], timeout=0)) == 0
        recvd = servers_recv_noblock([s1, s2], timeout=0)
        assert len(recvd) == 0

        # Send to s1
        addr1 = Address(port=port1)
        addr1.send("/s1", "hello s1")

        # Check multi-server wait/recv immediately
        active = servers_wait([s1, s2], timeout=100)
        assert s1 in active

        recvd = servers_recv_noblock([s1, s2], timeout=100)
        assert s1 in recvd
        assert recvd[s1] > 0
    finally:
        await sub1.unsub()
        await sub2.unsub()
        s1.stop()
        s2.stop()
