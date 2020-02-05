# cython: language_level=3

from . import types
from . cimport lo, messages, typespecs


cdef class Message:
    cdef public object route
    cdef public typespecs.TypeSpec typespec
    cdef lo.lo_message lo_message


cdef class Bundle:
    cdef public object timetag
    cdef lo.lo_bundle lo_bundle
    cdef list msgs
    cpdef object add(Bundle self, msg: types.BundleTypes)
    cpdef object add_message(Bundle self, messages.Message message)
    cpdef object add_bundle(Bundle self, Bundle bundle)
