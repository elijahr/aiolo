# cython: language_level=3

from libc.stdint cimport uint8_t

cdef class Midi:
    cdef uint8_t data[4]
