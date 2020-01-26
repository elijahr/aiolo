# cython: language_level=3

from typing import Union, Iterable, Set

from cpython cimport array
import array


from . import types
from . cimport abstractspecs, lo


__all__ = ['Path', 'ANY_PATH', 'pattern_match']


cdef array.array PATH_ARRAY_TEMPLATE = array.array('b')


PATTERN_CHARS = ' #{}[]!?*,-^\\'

ANY_PATH = Path(None)


cdef class Path(abstractspecs.AbstractSpec):
    def __cinit__(self, path: types.PathTypes):
        self.array = array.copy(PATH_ARRAY_TEMPLATE)
        self.none = False

        if isinstance(path, Path):
            p = (<Path>path)
            if p.none:
                self.none = True
            else:
                array.extend(self.array, p.array)
        elif isinstance(path, str):
            array.extend(self.array, array.array('b', path.encode('utf8')))
        elif path is None:
            self.none = True
        else:
            raise ValueError('Invalid value for %s: %s' % (self.__class__.__name__, repr(path)))

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
        return self.array == other.array and self.matches_any == other.matches_any

    def __lt__(self, other: Union[str, 'Path']) -> bool:
        if not isinstance(other, Path):
            other = Path(other)
        if self.matches_any:
            return False
        elif other.matches_any:
            return True
        return self.array < other.array

    def __contains__(self, other: Union[str, 'Path', Iterable[str, 'Path']]) -> bool:
        if isinstance(other, str):
            other_paths = {Path(other)}
        elif isinstance(other, Path):
            other_paths = {other}
        else:
            other_paths = other

        # Flatten, or raise ValueError if any of the paths are a non-simple pattern
        other_paths = {p for path in other_paths for p in path.paths}

        print('SELF.PATHS=%r, OTHER_PATHS=%r' % (self.paths, other_paths))
        if self.matches_any:
            return True

        # Check for exact matches
        if other_paths.issubset(self.paths):
            return True

        if self.is_pattern:
            # Check if all of the paths match any of the patterns in self
            if set(self.filter_matching(other_paths)) == other_paths:
                return True
            else:
                print('wat %r, %r' % (set(self.filter_matching(other_paths)), other_paths))

        return False

    def filter_matching(self, paths) -> Set[Path]:
        print('HALLO %s' % repr(paths))
        for string_path in paths:
            print('HALLO 2 %r' % string_path)
            string = string_path.as_bytes
            print('HALLO 3 %r' % string)
            for pattern_path in self.paths:
                print('HALLO 4 %r' % pattern_path)
                pattern = pattern_path.as_bytes
                print('HALLO 5 %r' % pattern)
                print('TESTING %r against %r' % (string, pattern))
                if lo.lo_pattern_match(string, pattern):
                    print("TWAS A MATCH!!!!")
                    yield string_path
                else:
                    print("TWAS NOT A MATCH!!!!")

    def __or__(self, other: types.PathTypes) -> Path:
        if not isinstance(other, Path):
            other = self.__class__(other)

        # TODO: Allow joining sets/lists etc, using similar logic to __contains__
        # TODO: Even better, allow passing string, path, array, or Iterable[] of any of those
        # to constructor, so that we can automatically build the joined pattern.
        # YEAH!!!

        if self.matches_any or other.matches_any:
            raise ValueError('Cannot join a match_any pattern')

        if self.is_pattern:
            if self.is_simple_pattern and (other.is_simple_pattern or not other.is_pattern):
                parts = self.as_str[1:-1].split(',')
            else:
                raise ValueError('Cannot join non simple patterns %s and %s' % (self.as_str, other.as_str))
        else:
            parts = [self.as_str]

        if other.is_pattern:
            if other.is_simple_pattern and (self.is_simple_pattern or not self.is_pattern):
                other_parts = other.as_str[1:-1].split(',')
            else:
                raise ValueError('Cannot join non-simple patterns %s and %s' % (other.as_str, self.as_str))
        else:
            other_parts = [other.as_str]

        parts = sorted(set(parts + other_parts))

        if len(parts) == 1:
            # No need to make a pattern when joining with self
            pattern = parts[0]
        else:
            pattern = '{%s}' % ','.join(parts)
        return self.__class__(pattern)

    @property
    def matches_any(self):
        return self.none

    @property
    def is_pattern(self):
        string = self.as_str
        return any(
            c in string for c in PATTERN_CHARS
        ) if not self.matches_any else False

    @property
    def is_simple_pattern(self):
        string = self.as_str
        try:
            return string[0] == '{' and string[-1] == '}' and string.count('{') and string.count('}') == 1
        except IndexError:
            return False

    @property
    def paths(self):
        if self.is_simple_pattern:
            parts = self.as_str[1:-1].split(',')
            return {self.__class__(p) for p in parts}
        return {self}


cpdef bint pattern_match(string, pattern):
    s = string.encode('utf8')
    p = pattern.encode('utf8')
    return lo.lo_pattern_match(s, p)