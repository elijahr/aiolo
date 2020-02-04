import array
import datetime
from typing import Type, Union, TYPE_CHECKING, Iterable, Tuple, List, Callable

if TYPE_CHECKING:
    from . import messages, midis, paths, routes, timetags, typespecs


__all__ = ['TypeSpecTypes', 'BundleTypes', 'PathTypes', 'RouteTypes', 'MessageTypes', 'PubTypes', 'TimeTagTypes']


# Types that can be used to construct an TypeSpec, which defines the types and order of argument accepted by a Route
TypeSpecTypes = Union[
    'typespecs.TypeSpec',
    str,  # strings where each char represents a LO_* type. This is what liblo interfaces expect.
    int,  # a raw char ordinal representing one of the LO_* type character
    array.array,  # an array of typecode 'b', where each entry corresponds to a LO_* type character
    bool,  # True -> LO_TRUE, False -> LO_FALSE

    # None is a special case;
    # If passed like TypeSpec(None), it indicates the Route will accept any arguments.
    # If passed like TypeSpec([None]), it indicates the Route handles the LO_NIL type.
    None,

    float,  # float('inf') -> LO_INFINITUM
    Type[int],  # int -> LO_INT64
    Type[float],  # float -> LO_DOUBLE
    Type[array.array],  # LO_BLOB
    Type[str],  # LO_STRING
    Type['timetags.TimeTag'],  # LO_TIMETAG
    Type['midis.Midi'],  # LO_MIDI

    # Any of the above, nested in a list/tuple. This allows us to do things like:
    # [str, float, int] which is more readable than the string format that liblo expects ('sdh')
    List['TypeSpecTypes'], Tuple['TypeSpecTypes'],
]

# Types that can be used to construct a Bundle
BundleTypes = Union[
    'messages.Message',
    'messages.Bundle',
    Iterable['messages.Message'],
    Iterable['messages.Bundle'],
    # An empty Bundle
    None
]

# Types that can be used to construct a Path
PathTypes = Union[
    'paths.Path',
    str,
    # A Path which will match any Path
    None
]

# Types that can be used to construct a Route
RouteTypes = Union[
    'routes.Route',
    str,
]

# Types that can be used to construct a Message
MessageTypes = Union[
    'messages.Message',
    str,
    array.array,
    int,
    bool,
    float,
    None,
    'timetags.TimeTag',
    'midis.Midi',
]

# Types that can be used for publishing data on a Route
PubTypes = Union[
    str,
    array.array,
    int,
    bool,
    float,
    None,
    'timetags.TimeTag',
    'midis.Midi',
    Exception,
]

# Types that can be used to construct a TimeTag
TimeTagTypes = Union[
    'timetags.TimeTag',
    datetime.datetime,  # An exact time
    float,  # An OSC timestamp; seconds since midnight JAN 1 1900 UTC. NOT A UNIX TIMESTAMP
    int,  # An OSC timestamp; seconds since midnight JAN 1 1900 UTC. NOT A UNIX TIMESTAMP

    # (sec, frac) where
    # sec is the number of seconds since midnight JAN 1 1900 UTC and
    # frac is the number of (approximately) 200 picoseconds beyond that.
    # See http://opensoundcontrol.org/node/3/#timetags
    Tuple[int, int],

    # Will default to TT_IMMEDIATE
    None
]
