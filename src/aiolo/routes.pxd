
from . cimport typespecs, paths


cdef class Route:
    cdef public paths.Path path
    cdef public typespecs.TypeSpec typespec
    cdef set _subs
    cdef object loop


cpdef Route _ANY_ROUTE