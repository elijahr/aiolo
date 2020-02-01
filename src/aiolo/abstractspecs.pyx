# cython: language_level=3

from typing import Union

IF not PYPY:
    from cpython cimport array

import array


__all__ = ['AbstractSpec']


cdef class AbstractSpec:
    def __repr__(self):
        return '%s(%r)' % (self.__class__.__name__, self.as_str)

    @property
    def simplerepr(self):
        return 'None' if self.none else repr(self.as_str)

    @property
    def as_str(self) -> str:
        if self.none:
            return None
        return self.array.tobytes().decode('utf8')

    @property
    def as_bytes(self) -> bytes:
        if self.none:
            return None
        return self.array.tobytes()

    def __iter__(self):
        try:
            return iter(self.array)
        except TypeError:
            return iter([])

    def __len__(self):
        if self.none:
            return 0
        return len(self.array)

    def __getitem__(self, item):
        return self.array[item]

    def __eq__(self, other: Union[array.array, str, AbstractSpec, None]) -> bool:
        if isinstance(other, AbstractSpec):
            return self.array == (<AbstractSpec>other).array
        elif isinstance(other, array.array):
            return self.array == other
        elif isinstance(other, str):
            return self.as_str == other
        elif other is None:
            return self.none
        return False

    def __lt__(self, other: Union[array, str, AbstractSpec]) -> bool:
        if isinstance(other, AbstractSpec):
            return self.array < (<AbstractSpec>other).array
        elif isinstance(other, array.array):
            return self.array < other
        elif isinstance(other, str):
            return self.as_str < other
        elif other is None:
            return False
        else:
            raise TypeError('Invalid value for %s.__contains__: %s' % (self.__class__.__name__, repr(other)))

    def __add__(self, other: Union[array, str, AbstractSpec, None]) -> AbstractSpec:
        if isinstance(other, AbstractSpec):
            if self.none and other.none:
                other_array = None
            elif self.none or other.none:
                raise ValueError('Cannot combine %r and %r' % (self, other))
            else:
                other_array = other.array
        elif isinstance(other, str):
            other_array = array.array('b', other.encode('utf8'))
        elif other is None:
            other_array = None
        else:
            raise TypeError('Cannot combine %r and %r' % (self, other))
        if other_array is None and not self.none:
            raise ValueError('Cannot combine %r and %r' % (self, other))
        return self.__class__(other_array)

    def __bool__(self):
        return bool(self.array)

    def __len__(self):
        return len(self.array)
