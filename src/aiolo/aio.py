import asyncio
import sys


PY_VERSION = sys.version_info[:2]


def create_task(coro):
    if PY_VERSION >= (3, 7):
        task = asyncio.create_task(coro)
    else:
        task = asyncio.get_event_loop().create_task(coro)
    return task


def run_coro(coro):
    if PY_VERSION >= (3, 7):
        return asyncio.run(coro)
    else:
        return asyncio.get_event_loop().run_until_complete(coro)
