# cython: language_level=3
from typing import Union

from libc.stdint cimport UINT8_MAX


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

    def __eq__(Midi self, object other: Union[Midi, bytearray]) -> bool:
        return (
            self.data[0] == other[0]
            and self.data[1] == other[1]
            and self.data[2] == other[2]
            and self.data[3] == other[3]
        )

    def __getitem__(self, item):
        if 0 <= item < 4:
            return self.data[item]
        raise IndexError