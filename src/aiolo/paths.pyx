# cython: language_level=3

import re
from typing import Union

IF not PYPY:
    from cpython cimport array

import array


from . import patterns, types
from . cimport abstractspecs


__all__ = ['Path', 'ANY_PATH']


IF not PYPY:
    cdef array.array PATH_ARRAY_TEMPLATE = array.array('b')


PATTERN_REGEX = re.compile(r'([#{}[\]!?*,\-^])|(//)')


cdef class Path(abstractspecs.AbstractSpec):
    def __cinit__(self, path: types.PathTypes):
        IF PYPY:
            self.array = array.array('b')
        ELSE:
            self.array = array.copy(PATH_ARRAY_TEMPLATE)
        self.none = False

        if isinstance(path, Path):
            p = (<Path>path)
            if p.none:
                self.none = True
            else:
                IF PYPY:
                    self.array.extend(p.array)
                ELSE:
                    array.extend(self.array, p.array)
        elif isinstance(path, str):
            IF PYPY:
                self.array.extend(array.array('b', path.encode('utf8')))
            ELSE:
                array.extend(self.array, array.array('b', path.encode('utf8')))
        elif path is None:
            self.none = True
        else:
            raise ValueError('Invalid value for %s: %s' % (self.__class__.__name__, repr(path)))

        self.pattern = patterns.compile_osc_address_pattern(self.as_str)

    def __init__(self, path: types.PathTypes):
        pass

    def __hash__(self):
        return hash('Path:%s' % self.simplerepr)

    def __repr__(self):
        if self.matches_any:
            return 'ANY_PATH'
        return '%s(%r)' % (self.__class__.__name__, self.as_str)

    @property
    def simplerepr(self):
        if self.matches_any:
            return 'ANY_PATH'
        return repr(self.as_str)

    def __eq__(self, other: types.PathTypes) -> bool:
        if not isinstance(other, Path):
            other = self.__class__(other)
        return self.as_str == other.as_str

    def __lt__(self, other: Union[str, 'Path']) -> bool:
        if not isinstance(other, Path):
            other = Path(other)
        return self.as_str or -1 < other.as_str or -1

    def __contains__(self, other: Union[str, 'Path']) -> bool:
        if self.matches_any:
            return True

        if isinstance(other, str):
            other = Path(other)

        if other.matches_any:
            return False

        return self.pattern.match(other.as_str) is not None

    @property
    def matches_any(self):
        return self.none

    @property
    def is_pattern(self):
        return self.matches_any or patterns.is_osc_address_pattern(self.as_str)


cpdef Path _ANY_PATH = Path(None)
ANY_PATH = _ANY_PATH
