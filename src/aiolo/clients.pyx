# cython: language_level=3

import datetime
from typing import Union, Iterable

from . cimport bundles, lo, messages, timetags
from . import exceptions, logs, routes


cdef class Client:

    def __cinit__(self, *, url: str):
        burl = url.encode('utf8')
        self.lo_address = lo.lo_address_new_from_url(burl)
        if self.lo_address is NULL:
            raise MemoryError

    def __init__(self, *, url :str):
        pass

    def __dealloc__(self):
        lo.lo_address_free(self.lo_address)
        self.lo_address = NULL

    def __repr__(self):
        return 'Client(%r)' % self.url.decode('utf8')

    @property
    def url(self):
        return lo.lo_address_get_url(self.lo_address)

    def pub(self, route: routes.Route, *data) -> None:
        message = messages.Message(route, *data)
        try:
            self.pubm(message)
        finally:
            del message

    def pubm(self, message: messages.Message) -> None:
        logs.logger.debug('%r: publishing %r', self, message)
        count = lo.lo_send_message(self.lo_address, message.route.bpath, message.lo_message())
        if count <= 0:
            raise exceptions.SendError(count)
        logs.logger.debug('%r: sent %s bytes', self, count)

    def bundle(
            self,
            msgs: Iterable[messages.Message, None] = None,
            timetag: Union[timetags.TimeTag, datetime.datetime, float, None] = None
    ) -> None:
        bundle = bundles.Bundle(msgs, timetag=timetag)
        try:
            self.bundleb(bundle)
        finally:
            del bundle

    def bundleb(self, bundle: bundles.Bundle):
        logs.logger.debug('%r: publishing %r', self, bundle)
        count = lo.lo_send_bundle(self.lo_address, bundle.lo_bundle)
        if count <= 0:
            raise exceptions.SendError(count)
        logs.logger.debug('%r: sent %s bytes', self, count)


