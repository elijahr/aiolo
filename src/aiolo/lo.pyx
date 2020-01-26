# cython: language_level=3

__all__ = ['LO_VERSION']

LO_VERSION = _LO_VERSION

# This is only needed so the module gets an init
cdef class Nothing:
    pass