# cython: language_level=3


from . cimport lo
from . import logs
from . cimport utils

cdef class Client:

    def __cinit__(self, *, url: str):
        burl = url.encode('utf8')
        self._lo_address = lo.lo_address_new_from_url(burl)
        if self._lo_address is NULL:
            raise MemoryError

    def __init__(self, *, url :str):
        pass

    def __dealloc__(self):
        lo.lo_address_free(self._lo_address)
        self._lo_address = NULL

    @property
    def url(self):
        return lo.lo_address_get_url(self._lo_address)

    def pub(self, path, lotypes, *args):
        cdef:
            lo.lo_message lo_msg = utils.pyargs_to_lomessage(lotypes, args)
            char * cpath
        bpath = path.encode('utf8')
        cpath = <char*>bpath
        logs.logger.debug('Client.pub: sending %s to %s' % (lotypes, bpath.decode('utf8')))
        try:
            return lo.lo_send_message(self._lo_address, cpath, lo_msg)
        finally:
            lo.lo_message_free(lo_msg)
