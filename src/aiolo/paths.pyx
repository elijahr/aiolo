# cython: language_level=3

from . import typedefs
from . cimport defs


__all__ = ['Path', 'ANY_PATH']


PATH_PATTERN_CHARS = b'{}[]!?*,-^\\'

ANY_PATH = Path(None)


cdef class Path(defs.Def):
    def __cinit__(self, path: typedefs.PathTypes):
        if isinstance(path, Path):
            _str = (<Path>path)._str
            _bytes = (<Path>path)._bytes
        elif isinstance(path, str):
            _str = path
            _bytes = path.encode('utf8')
        elif isinstance(path, bytes):
            _str = path.decode('utf8')
            _bytes = path
        elif isinstance(path, bytearray):
            path = bytes(path)
            _str = path.decode('utf8')
            _bytes = path
        elif path is None:
            _str = None
            _bytes = None
        else:
            raise ValueError('Invalid value for %s: %s' % (self.__class__.__name__, repr(path)))
        self._str = _str
        self._bytes = _bytes

    def __init__(self, path: typedefs.PathTypes):
        pass

    def __or__(self, other: typedefs.PathTypes) -> Path:
        if not isinstance(other, Path):
            other = Path(other)
        parts = sorted(set(self.pattern_parts + other.pattern_parts))
        pattern = b'{%s}' % b','.join(parts)
        return self.__class__(pattern)

    def __and__(self, other: typedefs.PathTypes) -> Path:
        return self.__or__(other)

    @property
    def matches_any(self):
        return self._bytes is None

    @property
    def is_pattern(self):
        return any(
            c in self._bytes for c in PATH_PATTERN_CHARS
        ) if self != ANY_PATH else False

    @property
    def pattern_parts(self) -> str:
        if self.matches_any:
            return []
        return self._bytes.replace(b'{', b'').replace(b'}', b'').split(b',')
