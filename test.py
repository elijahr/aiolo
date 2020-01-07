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

from aiolo import Client, Midi, Server, TimeTag
from aiolo.logs import logger

ch = logging.StreamHandler()
ch.setLevel(logging.DEBUG)
logger.addHandler(ch)
logger.setLevel(logging.DEBUG)


class AIOLoTestCase(unittest.TestCase):
    def setUp(self):
        self.maxDiff = 3600
        self.loop = asyncio.new_event_loop()
        asyncio.set_event_loop(self.loop)

    def tearDown(self) -> None:
        self.loop.close()

    def test_types(self):
        self.loop.run_until_complete(self._test_types())
        self.assertListEqual(self.items, [
            [1, '1', '1', b'1', b'\x01', b'1', 1000000000000000000, 1000000000000000000, (1, 3), (1, 3), 0.0, 0.0,
             (1, 2, 3, 4), (1, 2, 3, 4), True, True, False, False, None, None, float('inf'), float('inf')],
            [2, '2', '2', b'2', b'\x02', b'2', 2000000000000000000, 2000000000000000000, (2, 6), (2, 6), 0.0, 0.0,
             (2, 4, 6, 8), (2, 4, 6, 8), True, True, False, False, None, None, float('inf'), float('inf')],
            [3, '3', '3', b'3', b'\x03', b'3', 3000000000000000000, 3000000000000000000, (3, 9), (3, 9), 0.0, 0.0,
             (3, 6, 9, 12), (3, 6, 9, 12), True, True, False, False, None, None, float('inf'), float('inf')]
        ])

    async def _test_types(self):
        server = Server(url='osc.udp://:10021')
        client = Client(url='osc.udp://:%s' % server.port)
        sub = server.sub(
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
                TimeTag,  # LO_TIMETAG
                't',  # LO_TIMETAG
                float,  # LO_DOUBLE,
                'd',  # LO_DOUBLE
                # 'S',  # LO_SYMBOL
                # 'c',  # LO_CHAR
                Midi,  # LO_MIDI
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
        task = self.create_task(self.sub(sub, 3))
        for i in range(1, 4):
            client.pub(
                '/foo',
                'issbbbhhttddmmTTFFNNII',
                i,  # LO_INT32
                # float(i),  # LO_FLOAT
                str(i),  # LO_STRING
                str(i),  # LO_STRING
                b'%i' % i,  # LO_BLOB
                bytearray([i]),  # LO_BLOB
                b'%i' % i,  # LO_BLOB
                i * 1000000000000000000,  # LO_INT64
                i * 1000000000000000000,  # LO_INT64
                TimeTag(i, i * 3),  # LO_TIMETAG
                TimeTag(i, i * 3),  # LO_TIMETAG
                float(i),  # LO_DOUBLE,
                float(i),  # LO_DOUBLE
                # str(i),  # LO_SYMBOL
                # bytes(i),  # LO_CHAR
                Midi(i, i * 2, i * 3, i * 4),  # LO_MIDI
                Midi(i, i * 2, i * 3, i * 4),  # LO_MIDI
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
        self.items = await task
        server.stop()

    def test_duplicate_subs(self):
        self.loop.run_until_complete(self._test_duplicate_subs())
        self.assertListEqual(self.sub1_items, [[1]])
        self.assertListEqual(self.sub2_items, [[1]])

    async def _test_duplicate_subs(self):
        server = Server(url='osc.udp://:10020')
        client = Client(url='osc.udp://:%s' % server.port)
        sub1 = server.sub('/foo', 'i')
        sub2 = server.sub('/foo', 'i')
        server.start()
        tasks = asyncio.gather(
            self.create_task(self.sub(sub1, 1)),
            self.create_task(self.sub(sub2, 1)),
        )
        client.pub('/foo', 'i', 1)
        sub1_items, sub2_items = await tasks
        server.stop()
        self.sub1_items = sub1_items
        self.sub2_items = sub2_items

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
            return asyncio.create_task(coro)
        else:
            return self.loop.create_task(coro)


if __name__ == '__main__':
    unittest.main()
