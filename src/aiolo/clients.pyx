# cython: language_level=3

cimport cython

from typing import Union

from . import typedefs
from . cimport bundles, lo, messages


@cython.no_gc
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

    def pub(self, route: Union[typedefs.RouteTypes], *data: typedefs.MessageTypes) -> int:
        return self.pub_message(messages.Message(route, *data))

    def pub_message(self, message: messages.Message) -> int:
        return (<messages.Message>message).send(self.lo_address)

    def bundle(self, bundle: typedefs.BundleTypes, timetag: typedefs.TimeTagTypes = None) -> int:
        if not isinstance(bundle, bundles.Bundle):
            bundle = bundles.Bundle(bundle, timetag)
        elif timetag is not None:
            raise ValueError('Cannot provide Bundle instance and timetag together')
        return (<bundles.Bundle>bundle).send(self.lo_address)
