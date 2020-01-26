# cython: language_level=3
from typing import Union

from libc.stdint cimport UINT8_MAX


__all__ = ['Midi']


cdef class Midi:
    def __cinit__(self, arg1: int, arg2: int, arg3: int, arg4: int):
        if not (
            0 <= arg1 <= UINT8_MAX
            and 0 <= arg2 <= UINT8_MAX
            and 0 <= arg3 <= UINT8_MAX
            and 0 <= arg4 <= UINT8_MAX
        ):
            raise ValueError('Invalid Midi values %r, must be between 0 and %r' % (
                (arg1, arg2, arg3, arg4), UINT8_MAX))
        self.data[:] = (arg1, arg2, arg3, arg4)

    def __init__(self, arg1: int, arg2: int, arg3: int, arg4: int):
        pass

    def __repr__(self):
        return 'Midi(%r, %r, %r, %r)' % (self.data[0], self.data[1], self.data[2], self.data[3])

    def __len__(self):
        return 4

    def __iter__(Midi self):
        return iter(self.data[:])

    def __eq__(Midi self, Midi other: Midi) -> bool:
        return self.data[:] == other.data[:]

    def __lt__(Midi self, Midi other: Midi) -> bool:
        return self.data[:] < other.data[:]

    def __getitem__(self, item):
        if 0 <= item < 4:
            return self.data[item]
        raise IndexError

    def __setitem__(self, item, value):
        if 0 <= item < 4:
            self.data[item] = value
        raise IndexError