import datetime

import aiolo


TYPE_TEST_DATA = {
    '/lo_int32': {
        'argdefs': (aiolo.INT32, ),
        'valid': (
            (42, [[42]]),
            (-42, [[-42]]),
            (42.0, [[42]]),
            (True, [[1]]),
            (False, [[0]]),
            ('42', [[42]]),
            (b'42', [[42]]),
            (aiolo.INT32_MAX, [[aiolo.INT32_MAX]]),
            (aiolo.INT32_MIN, [[aiolo.INT32_MIN]]),
        ),
        'invalid': (None, 'f00', b'\x09', aiolo.INT32_MAX+1, aiolo.INT32_MIN-1,)
    },
    '/lo_int64': {
        'argdefs': (aiolo.INT64, int),
        'valid': (
            (42, [[42]]),
            (-42, [[-42]]),
            (42.0, [[42]]),
            (True, [[1]]),
            (False, [[0]]),
            ('42', [[42]]),
            (b'42', [[42]]),
            (aiolo.INT64_MAX, [[aiolo.INT64_MAX]]),
            (aiolo.INT64_MIN, [[aiolo.INT64_MIN]]),
        ),
        'invalid': (None, 'f00', b'\x09', aiolo.INT64_MAX+1, aiolo.INT64_MIN-1,)
    },
    '/lo_float': {
        'argdefs': (aiolo.FLOAT,),
        'valid': (
            (42, [[42.0]]),
            (-42, [[-42.0]]),
            (42.0, [[42.0]]),
            (-42.0, [[-42.0]]),
            (True, [[1.0]]),
            (False, [[0.0]]),
        ),
        'invalid': (None, ),
    },
    '/lo_double': {
        'argdefs': (aiolo.DOUBLE, float),
        'valid': (
            (42, [[42.0]]),
            (-42, [[-42.0]]),
            (42.0, [[42.0]]),
            (-42.0, [[-42.0]]),
            (True, [[1.0]]),
            (False, [[0.0]]),
        ),
        'invalid': (None, ),
    },
    '/lo_string': {
        'argdefs': (aiolo.STRING, str),
        'valid': (
            ('', [['']]),
            (42, [['42']]),
            (42.0, [['42.0']]),
            ('42', [['42']]),
            (b'***', [['***']]),
            (bytearray([42, 42, 42]), [['***']]),
        ),
        'invalid': tuple(),
    },
    '/lo_symbol': {
        'argdefs': (aiolo.SYMBOL, ),
        'valid': (
            ('', [['']]),
            (42, [['42']]),
            (42.0, [['42.0']]),
            ('42', [['42']]),
            (b'***', [['***']]),
            (bytearray([42, 42, 42]), [['***']]),
        ),
        'invalid': tuple(),
    },
    '/lo_char': {
        'argdefs': (aiolo.CHAR, ),
        'valid': (
            (42, [[b'*']]),
            (42.0, [[b'*']]),
            (1, [[b'\x01']]),
            ('1', [[b'1']]),
            (b'1', [[b'1']]),
            (bytearray([1]), [[b'\x01']]),
            (True, [[b'\x01']]),
            (False, [[b'\x00']]),
        ),
        'invalid': (
            '',
            '42',
            bytearray([42, 42]),
            None,
        ),
    },
    '/lo_blob': {
        'argdefs': (aiolo.BLOB, bytes, bytearray),
        'valid': (
            (42, [[b'42']]),
            (42.0, [[b'42.0']]),
            ('999', [[b'999']]),
            (b'999', [[b'999']]),
            (b'***', [[b'***']]),
            (bytearray([42, 42, 42]), [[b'***']]),
        ),
        'invalid': (b'', '', bytearray()),
    },
    '/lo_timetag': {
        'argdefs': (aiolo.TIMETAG, aiolo.TimeTag),
        'valid': (
            (42, [[aiolo.TimeTag(42)]]),
            (42.1, [[aiolo.TimeTag(42.1)]]),
            (aiolo.TimeTag(aiolo.EPOCH + datetime.timedelta(seconds=42)),
             [[aiolo.TimeTag(aiolo.EPOCH + datetime.timedelta(seconds=42))]]),
            (aiolo.EPOCH + datetime.timedelta(seconds=42),
             [[aiolo.TimeTag(aiolo.EPOCH + datetime.timedelta(seconds=42))]]),
            (True, [[aiolo.TimeTag(1)]]),
            (False, [[aiolo.TimeTag(0)]]),
        ),
        'invalid': (None, (1, 2, 3)),
    },
    '/lo_midi': {
        'argdefs': (aiolo.MIDI, aiolo.Midi),
        'valid': (
            (aiolo.Midi(1, 2, 3, 4),
             [[aiolo.Midi(1, 2, 3, 4)]]),
            (bytearray([1, 2, 3, 4]),
             [[aiolo.Midi(1, 2, 3, 4)]]),
        ),
        'invalid': (
            bytearray([42]),
            bytearray([42, 42, 42, 42, 42]),
        )
    },
    '/lo_true': {
        'argdefs': (aiolo.TRUE, True),
        'valid': ((True, [[True]]), (1, [[True]]), ('foo', [[True]]), ),
        'invalid': (False, None, 0, '')
    },
    '/lo_false': {
        'argdefs': (aiolo.FALSE, False),
        'valid': ((False, [[False]]), (0, [[False]]), ('', [[False]]), (None, [[False]]), ),
        'invalid': (True, 1, 'foo')
    },
    '/lo_nil': {
        'argdefs': (aiolo.NIL, None, type(None)),
        'valid': ((None, [[None]]), ),
        'invalid': (True, False, 1, 0, 'foo')
    },
    '/lo_infinitum': {
        'argdefs': (aiolo.INFINITUM, aiolo.INFINITY),
        'valid': ((aiolo.INFINITY, [[aiolo.INFINITY]]), ),
        'invalid': (42.0, -aiolo.INFINITY, True, False, None, 1, 0, 'foo')
    }
}