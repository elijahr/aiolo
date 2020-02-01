
__all__ = ['get_proto_id', 'PROTO_DEFAULT', 'PROTO_UDP', 'PROTO_UNIX', 'PROTO_TCP', 'PROTOS', 'PROTOS_VALID']

PROTO_DEFAULT = 0x0
PROTO_UDP = 0x1
PROTO_UNIX = 0x2
PROTO_TCP = 0x4

PROTOS = {
    PROTO_DEFAULT: 'osc.default',
    PROTO_UDP: 'osc.udp',
    PROTO_UNIX: 'osc.unix',
    PROTO_TCP: 'osc.tcp',
}

PROTOS_VALID = {
    PROTO_UDP,
    PROTO_UNIX,
    PROTO_TCP
}

# Possible values returned by lo_address_get_protocol
PROTOS_BY_NAME = {
    '': PROTO_DEFAULT,
    '\x00': PROTO_DEFAULT,
    '\x01': PROTO_UDP,
    '\x02': PROTO_UNIX,
    '\x04': PROTO_TCP,

    'osc.default': PROTO_DEFAULT,
    'osc.udp': PROTO_UDP,
    'osc.unix': PROTO_UNIX,
    'osc.tcp': PROTO_TCP,

    'default': PROTO_DEFAULT,
    'udp': PROTO_UDP,
    'unix': PROTO_UNIX,
    'tcp': PROTO_TCP,

    b'': PROTO_DEFAULT,
    b'\x00': PROTO_DEFAULT,
    b'\x01': PROTO_UDP,
    b'\x02': PROTO_UNIX,
    b'\x04': PROTO_TCP,

    b'osc.default': PROTO_DEFAULT,
    b'osc.udp': PROTO_UDP,
    b'osc.unix': PROTO_UNIX,
    b'osc.tcp': PROTO_TCP,

    b'default': PROTO_DEFAULT,
    b'udp': PROTO_UDP,
    b'unix': PROTO_UNIX,
    b'tcp': PROTO_TCP,
}


def get_proto_id(proto):
    if not isinstance(proto, int):
        try:
            return PROTOS_BY_NAME[proto]
        except (KeyError, TypeError):
            pass
    elif proto in PROTOS:
        return proto
    raise ValueError('Invalid protocol %s' % repr(proto))
