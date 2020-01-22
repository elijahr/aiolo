# cython: language_level=3

from typing import Union


__all__ = ['Def']


cdef class Def:
    def __repr__(self):
        return '%s(%r)' % (self.__class__.__name__, self._bytes)

    def __hash__(self):
        return hash(self._bytes)

    def __str__(self):
        return self._str

    def __bytes__(self):
        return self._bytes

    def __bytearray__(self):
        return bytearray(self._bytes)

    def __iter__(self):
        try:
            return iter(self._bytes)
        except TypeError:
            return iter([])

    def __getitem__(self, item):
        return self._bytes[item]

    def __eq__(self, other: Union[str, bytes, Def, None]) -> bool:
        if isinstance(other, Def):
            return self._bytes == (<Def>other)._bytes
        elif isinstance(other, bytes):
            return self._bytes == other
        elif isinstance(other, str):
            return self._str == other
        elif other is None:
            return self._bytes is None
        return False

    def __neq__(self, other: Union[str, bytes, Def, None]) -> bool:
        return not self.__eq__(other)

    def __add__(self, other: Union[str, bytes, Def, None]) -> Def:
        if isinstance(other, Def):
            return self.__class__((self._bytes or b'') + (<Def>other)._bytes)
        elif isinstance(other, bytes):
            return self.__class__((self._bytes or b'') + other)
        elif isinstance(other, str):
            return self.__class__((self._str or '') + other)
        elif other is None:
            return self.__class__(self._bytes)
        raise TypeError('Cannot concatenate %s and %r' % (self.__class__.__name__, other))

    def __bool__(self):
        return bool(self._bytes)

    def __len__(self):
        return len(self._bytes)

    cdef char * charp(self):
        cdef char * ch = NULL
        if self._bytes is not None:
            ch = <char*>self._bytes
        return ch

