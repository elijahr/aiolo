
from . cimport typespecs, paths


cdef class Route:
    cdef public paths.Path path
    cdef public typespecs.TypeSpec typespec
    cdef public object loop
    cdef set _subs


cpdef Route _ANY_ROUTE