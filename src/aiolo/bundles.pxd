# cython: language_level=3

from . import typedefs
from . cimport addresses, lo, messages, servers

cdef class Bundle:
    cdef object timetag
    cdef lo.lo_bundle lo_bundle
    cdef list msgs
    cpdef object add(Bundle self, msg: typedefs.BundleTypes)
    cpdef object add_message(Bundle self, messages.Message message)
    cpdef object add_bundle(Bundle self, Bundle bundle)
    cpdef int send_from(Bundle self, addresses.Address address, servers.Server server)
    cpdef int send(Bundle self, addresses.Address address)
