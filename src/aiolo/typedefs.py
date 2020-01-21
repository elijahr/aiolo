import datetime
from typing import Type, List, Union, TYPE_CHECKING, Tuple

if TYPE_CHECKING:
    from . import argdefs, bundles, midis, paths, routes, timetags


ArgdefTypes = Union[
    'argdefs.Argdef',
    str, bytes, bytearray,  # strings where each char represents a LO_* type. This is what liblo interfaces expect.
    int,  # a raw char ordinal representing one of the LO_* types
    bool,  # True -> LO_TRUE, False -> LO_FALSE
    None,  # None -> Any arguments, unless nested in an iterable, which then indicates LO_NIL.
           # i.e. Route('/foo', None) matches any arguments, Route('/foo', [None]) expects only LO_NIL
    float,  # float('inf') -> LO_INFINITUM
    Type[int],  # int -> LO_INT64
    Type[float],  # float -> LO_DOUBLE
    Type['timetags.TimeTag'],  # LO_TIMETAG
    Type['midis.Midi'],  # LO_MIDI
    List['ArgdefTypes'],  # any of the above, nested in a list. This allows us to do things like:
                          # [str, float, int] which is more readable than the format that lo expects ('sdh')
]


BundleTypes = Union[
    'messages.Message',
    'bundles.Bundle',
]


PathTypes = Union[
    'paths.Path',
    str,
    bytes,
    bytearray,
    None
]


RouteTypes = Union[
    'routes.Route',
    str,
    bytes,
    bytearray,
]


MessageTypes = Union[
    'messages.Message',
    str,
    bytes,
    bytearray,
    int,
    bool,
    float,
    None,
    'timetags.TimeTag',
    'midis.Midi',
]


PubTypes = Union[
    str,
    bytes,
    bytearray,
    int,
    bool,
    float,
    None,
    'timetags.TimeTag',
    'midis.Midi',
    Exception,
]


TimeTagTypes = Union[
    'timetags.TimeTag',
    datetime.datetime,
    float,
    int,
    None
]
