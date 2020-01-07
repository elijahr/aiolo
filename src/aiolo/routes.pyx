# cython: language_level: 3
import asyncio
from typing import Union, Iterable

from . import subs
from . cimport utils


ROUTES = {}


cdef class Route:
    def __cinit__(self, path: str, lotypes: str, loop: asyncio.AbstractEventLoop = None):
        self.path = path
        self.lotypes = lotypes
        self.subs = []
        if loop is None:
            loop = asyncio.get_event_loop()
        self.loop = loop

    def __init__(self, path: str, lotypes: str, loop: asyncio.AbstractEventLoop = None):
        pass

    def pub(self, item):
        for sub in self.subs:
            sub.pub(item)

    def sub(self):
        sub = subs.Sub(self, loop=self.loop)
        self.subs.append(sub)
        return sub

    def unsub(self, sub):
        self.subs.remove(sub)

    @classmethod
    def get_or_create(cls, path: str, pytypes: Union[str, bytes, Iterable] = None, loop: asyncio.AbstractEventLoop = None):
        if isinstance(pytypes, bytes):
            lotypes = pytypes.decode('utf8')
        elif isinstance(pytypes, str):
            lotypes = pytypes
        else:
            lotypes = utils.pytypes_to_lotypes(pytypes).decode('utf8')
        try:
            return ROUTES[route_key(path, lotypes)], False
        except KeyError:
            route = cls(path, lotypes, loop)
            ROUTES[route.key] = route
            return route, True

    @classmethod
    def unroute(cls, path: str, pytypes: Union[str, bytes, Iterable] = None):
        if isinstance(pytypes, bytes):
            lotypes = pytypes.decode('utf8')
        elif isinstance(pytypes, str):
            lotypes = pytypes
        else:
            lotypes = utils.pytypes_to_lotypes(pytypes).decode('utf8')
        try:
            route = ROUTES[route_key(path, lotypes)]
        except KeyError:
            return None
        else:
            del ROUTES[route.key]
            return route

    @property
    def key(self):
        return route_key(self.path, self.lotypes)

    @property
    def bpath(self):
        return self.path.encode('utf8')

    @property
    def blotypes(self):
        return self.lotypes.encode('utf8')


def route_key(path, lotypes):
    return '%s:%s' % (path, lotypes)
