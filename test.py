import datetime
import logging

import faulthandler

faulthandler.enable(all_threads=True)

try:
    import tracemalloc
except ImportError:
    # Not available in pypy
    pass
else:
    tracemalloc.start()

import asyncio
import sys
import unittest

import aiolo
from aiolo.logs import logger

ch = logging.StreamHandler()
ch.setLevel(logging.DEBUG)
logger.addHandler(ch)
logger.setLevel(logging.DEBUG)


EPOCH = datetime.datetime.utcfromtimestamp(0)


class AIOLoTestCase(unittest.TestCase):
    def setUp(self):
        self.maxDiff = 3600
        self.loop = asyncio.new_event_loop()
        asyncio.set_event_loop(self.loop)
        self.results = []

    def tearDown(self) -> None:
        self.loop.close()

    def test_types(self):
        self.loop.run_until_complete(self._test_types())
        self.assertListEqual(self.results, [
            [1, '1', '1', b'1', b'\x01', b'1', 1000000000000000000, 1000000000000000000,
             aiolo.TimeTag(1), aiolo.TimeTag(1), aiolo.TimeTag(1), aiolo.TimeTag(1.1),
             0.0, 0.0,
             (1, 2, 3, 4), (1, 2, 3, 4), True, True, False, False, None, None, float('inf'), float('inf')],
            [2, '2', '2', b'2', b'\x02', b'2', 2000000000000000000, 2000000000000000000,
             aiolo.TimeTag(2), aiolo.TimeTag(2), aiolo.TimeTag(2), aiolo.TimeTag(2.1),
             0.0, 0.0,
             (2, 4, 6, 8), (2, 4, 6, 8), True, True, False, False, None, None, float('inf'), float('inf')],
            [3, '3', '3', b'3', b'\x03', b'3', 3000000000000000000, 3000000000000000000,
             aiolo.TimeTag(3), aiolo.TimeTag(3), aiolo.TimeTag(3), aiolo.TimeTag(3.1),
             0.0, 0.0,
             (3, 6, 9, 12), (3, 6, 9, 12), True, True, False, False, None, None, float('inf'), float('inf')]
        ])

    async def _test_types(self):
        server = aiolo.Server(url='osc.udp://:10000')
        client = aiolo.Client(url='osc.udp://:%s' % server.port)
        route = server.route(
            '/foo',
            [
                'i',  # LO_INT32
                # 'f',  # LO_FLOAT
                str,  # LO_STRING
                's',  # LO_STRING
                bytes,  # LO_BLOB
                bytearray,  # LO_BLOB
                'b',  # LO_BLOB
                'h',  # LO_INT64
                int,  # LO_INT64
                aiolo.TimeTag,  # LO_TIMETAG
                datetime.datetime,  # LO_TIMETAG
                't',  # LO_TIMETAG
                't',  # LO_TIMETAG
                float,  # LO_DOUBLE,
                'd',  # LO_DOUBLE
                # 'S',  # LO_SYMBOL
                # 'c',  # LO_CHAR
                aiolo.Midi,  # LO_MIDI
                'm',  # LO_MIDI
                True,  # LO_TRUE
                'T',  # LO_TRUE
                False,  # LO_FALSE
                'F',  # LO_FALSE
                None,  # LO_NIL
                'N',  # LO_NIL,
                float('inf'),  # LO_INFINITUM
                'I',  # LO_INFINITUM
            ]
        )
        server.start()
        task = self.create_task(self.sub(route.sub(), 3))
        for i in range(1, 4):
            client.pub(
                route,
                i,  # LO_INT32
                # float(i),  # LO_FLOAT
                str(i),  # LO_STRING
                str(i),  # LO_STRING
                b'%i' % i,  # LO_BLOB
                bytearray([i]),  # LO_BLOB
                b'%i' % i,  # LO_BLOB
                i * 1000000000000000000,  # LO_INT64
                i * 1000000000000000000,  # LO_INT64
                aiolo.TimeTag.from_datetime(EPOCH + datetime.timedelta(seconds=i)),  # LO_TIMETAG
                EPOCH + datetime.timedelta(seconds=i),  # LO_TIMETAG
                i,  # LO_TIMETAG
                float(i) + 0.1,  # LO_TIMETAG
                float(i),  # LO_DOUBLE,
                float(i),  # LO_DOUBLE
                # str(i),  # LO_SYMBOL
                # bytes(i),  # LO_CHAR
                aiolo.Midi(i, i * 2, i * 3, i * 4),  # LO_MIDI
                aiolo.Midi(i, i * 2, i * 3, i * 4),  # LO_MIDI
                True,  # LO_TRUE
                True,  # LO_TRUE
                False,  # LO_FALSE
                False,  # LO_FALSE
                None,  # LO_NIL
                None,  # LO_NIL,
                float('inf'),  # LO_INFINITUM
                float('inf'),  # LO_INFINITUM
            )
            await asyncio.sleep(0.001)
        self.results = list(await task)
        server.stop()

    def test_multiple_subs(self):
        self.loop.run_until_complete(self._test_multiple_subs())
        self.assertListEqual(self.results, [[['bar']], [['bar']]])

    async def _test_multiple_subs(self):
        server = aiolo.Server(url='osc.udp://:10001')
        client = aiolo.Client(url='osc.udp://:%s' % server.port)
        foo = server.route('/foo', 's')
        server.start()
        tasks = asyncio.gather(
            self.create_task(self.sub(foo.sub(), 1)),
            self.create_task(self.sub(foo.sub(), 1)),
        )
        client.pub(foo, 'bar')
        self.results = list(await tasks)
        server.stop()

    def test_bundle(self):
        self.loop.run_until_complete(self._test_bundle())
        self.assertListEqual(self.results, [[['foo']], [['bar']], [['baz']]])

    async def _test_bundle(self):
        server = aiolo.Server(url='osc.udp://:10002')
        client = aiolo.Client(url='osc.udp://:%s' % server.port)
        foo = server.route('/foo', 's')
        bar = server.route('/bar', 's')
        baz = server.route('/baz', 's')
        server.start()
        tasks = asyncio.gather(
            self.create_task(self.sub(foo.sub(), 1)),
            self.create_task(self.sub(bar.sub(), 1)),
            self.create_task(self.sub(baz.sub(), 1)),
        )
        client.bundle([
            aiolo.Message(foo, 'foo'),
            aiolo.Message(bar, 'bar'),
            aiolo.Message(baz, 'baz'),
        ])
        self.results = list(await tasks)
        server.stop()

    async def sub(self, sub, count):
        items = []
        async for item in sub:
            items.append(item)
            if len(items) == count:
                break
        sub.unsub()
        return items

    def create_task(self, coro):
        if sys.version_info[:2] >= (3, 8):
            task = asyncio.create_task(coro)
        else:
            task = self.loop.create_task(coro)
        self.loop.call_later(10, task.cancel)
        return task


if __name__ == '__main__':
    unittest.main()
