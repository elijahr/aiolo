import array
import datetime

from aiolo import FLOAT, BLOB, INT64, MIDI, Midi, INT32, CHAR, TRUE, TimeTag, INT64_MAX, INT32_MAX, NIL, INFINITY, \
    SYMBOL, TIMETAG, INT64_MIN, STRING, EPOCH_UTC, FALSE, DOUBLE, INFINITUM, INT32_MIN


class ArgdefTestData:
    path = None
    typespecs = []
    valid = []
    overflow_error = []
    type_error = []
    value_error = []


class Int32TestData(ArgdefTestData):
    path = '/int32'
    typespecs = [INT32]
    valid = [
        [INT32_MAX, INT32_MAX],
        [INT32_MIN, INT32_MIN],
    ]
    overflow_error = [INT32_MAX + 1, INT32_MIN - 1]
    type_error = [None, 42.0, '42', b'42']


class Int64TestData(ArgdefTestData):
    path = '/int64'
    typespecs = [INT64, int]
    valid = [
        [INT64_MAX, INT64_MAX],
        [INT64_MIN, INT64_MIN]
    ]
    overflow_error = [INT64_MAX + 1, INT64_MIN - 1]
    type_error = [None, 42.0, '42', b'42']


class FloatTestData(ArgdefTestData):
    path = '/float'
    typespecs = [FLOAT]
    valid = [
        [42.0, 42.0],
        [-42.0, -42.0],
        [1.199999978106707e-38, 1.199999978106707e-38],
        [3.3999999521443642e+38, 3.3999999521443642e+38],
    ]
    overflow_error = [
        1.7976931348623157e+308,
        2.2250738585072014e-308,
    ]
    value_error = [INFINITY]
    type_error = [None, 1]


class DoubleTestData(FloatTestData):
    path = '/double'
    typespecs = [DOUBLE, float]
    valid = [
        [2.2250738585072014e-308, 2.2250738585072014e-308],
        [1.7976931348623157e+308, 1.7976931348623157e+308],
    ]
    overflow_error = []


class StringTestData(ArgdefTestData):
    path = '/string'
    typespecs = [STRING, str]
    valid = [
        ['', ''],
        ['42', '42'],
    ]
    type_error = [None, b'a', 42, 42.0, True]


class SymbolTestData(StringTestData):
    path = '/symbol'
    typespecs = [SYMBOL]


class CharTestData(ArgdefTestData):
    path = '/char'
    typespecs = [CHAR]
    valid = (
        [42, '*'],
        [1, '\x01'],
        ['1', '1'],
    )
    overflow_error = [
        '',
        1000,
        '42',
    ]
    type_error = [None, 42.0]


class BlobTestData(ArgdefTestData):
    path = '/blob'
    typespecs = [BLOB, bytes, array.array]
    valid = [
        [b'123', array.array('b', b'123')],
        [array.array('b', b'***'), array.array('b', b'***')],
    ]
    value_error = [b'', array.array('b')]
    type_error = [42, 42.0, 'foo']


class TimeTagTestData(ArgdefTestData):
    path = '/timetag'
    typespecs = [TIMETAG, TimeTag]
    valid = [
        [42, TimeTag(42)],
        [42.1, TimeTag(42.1)],
        [TimeTag(EPOCH_UTC + datetime.timedelta(seconds=42)),
         TimeTag(EPOCH_UTC + datetime.timedelta(seconds=42))],
        [EPOCH_UTC + datetime.timedelta(seconds=42),
         TimeTag(EPOCH_UTC + datetime.timedelta(seconds=42))],
    ]
    type_error = [None, '42']


class MidiTestData(ArgdefTestData):
    path = '/midi'
    typespecs = [MIDI, Midi]
    valid = [
        [array.array('b', [1, 2, 3, 4]),
         Midi(1, 2, 3, 4)],
        [Midi(1, 2, 3, 4),
         Midi(1, 2, 3, 4)],
    ]
    type_error = ['42', 42, array.array('b', [1, 2, 3, 4, 5])]


class TrueTestData(ArgdefTestData):
    path = '/true'
    typespecs = [TRUE, True]
    valid = [
        [True, True],
        [1, True],
    ]
    value_error = [False, 0]
    type_error = [None, '', 'foo']


class FalseTestData(ArgdefTestData):
    path = '/false'
    typespecs = [FALSE, False]
    valid = [
        [False, False],
        [0, False],
    ]
    value_error = [True, 1]
    type_error = [None, '', 'foo']


class NilTestData(ArgdefTestData):
    path = '/nil'
    typespecs = [NIL, [None], type(None)]
    valid = [
        [None, None],
    ]
    type_error = [True, False, 1, 0, 'foo']


class InfinitumTestData(ArgdefTestData):
    path = '/infinitum'
    typespecs = [INFINITUM, INFINITY]
    valid = [
        [INFINITY, INFINITY],
    ]
    value_error = [42.0, -INFINITY]
    type_error = [True, False, None, 1, 0, 'foo']


ARGDEF_TEST_DATA = [
    Int32TestData,
    Int64TestData,
    FloatTestData,
    DoubleTestData,
    StringTestData,
    SymbolTestData,
    CharTestData,
    BlobTestData,
    TimeTagTestData,
    MidiTestData,
    TrueTestData,
    FalseTestData,
    NilTestData,
    InfinitumTestData
]
