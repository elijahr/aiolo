# cython: language_level: 3

import asyncio
from typing import Union, Iterable

from . import subs
from . cimport utils


cdef class Route:
    def __cinit__(
            self,
            path: Union[str, bytes],
            lotypes: Union[str, bytes, Iterable] = None
    ):
        if isinstance(path, bytes):
            path = path.decode('utf8')
        self.path = path
        lotypes = utils.ensure_lotypes(lotypes)
        self.lotypes = lotypes.decode('utf8')
        self.subs = []

    def __init__(
            self,
            path: Union[str, bytes],
            lotypes: Union[str, bytes, Iterable] = None
    ):
        pass

    def __repr__(self):
        return 'Route(%r, %r)' % (self.path, self.lotypes)

    def __hash__(self):
        return hash('%s:%s' % (self.path, self.lotypes))

    def pub(self, item):
        for sub in self.subs:
            sub.pub(item)

    def sub(self, loop: asyncio.AbstractEventLoop = None) -> subs.Sub:
        sub = subs.Sub(self, loop=loop)
        self.subs.append(sub)
        return sub

    def unsub(self, sub):
        self.subs.remove(sub)

    @property
    def bpath(self):
        return self.path.encode('utf8')

    @property
    def blotypes(self):
        return self.lotypes.encode('utf8')
