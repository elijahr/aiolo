# cython: language_level=3

from typing import Iterable

from . import types
from . cimport lo, typespecs

cdef list unpack_args(typespecs.TypeSpec typespec, lo.lo_arg ** argv, int argc)
cdef lo.lo_message pack_lo_message(typespecs.TypeSpec typespec, object args: Iterable[types.MessageTypes]) except NULL