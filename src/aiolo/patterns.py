import re
from itertools import groupby, count
from typing import Union, Generator


from . import logs


__all__ = ['compile_osc_address_pattern', 'is_osc_address_pattern']


ODD_NUM_SLASHES = r'(?<!\\)(?:\\{2})*\\(?!\\)'

EVEN_NUM_SLASHES = r'(?<!\\)(?:\\{2})*(?!\\)'


def any_chars(chars: str) -> str:
    """
    Collapse a string of chars to a regex that would match any string of chars from that string.
    """
    collapsed = collapse(chars)
    return r'(?:' + (
        ('(?:(?:' + EVEN_NUM_SLASHES + r'[' + collapsed + r'])+)')
        if collapsed
        else r''
    ) + r')'


def any_char(chars: str) -> str:
    """
    Collapse a string of chars to a regex that would match any single char from that string.
    """
    collapsed = collapse(chars)
    return r'(?:' + (
        ('(?:' + EVEN_NUM_SLASHES + r'[' + collapsed + r'])')
        if collapsed
        else r''
    ) + r')'


def chz(c):
    return chr(c).replace(']', r'\]').replace('-', r'\-').replace('^', r'\^')


def collapse(chars: str) -> str:
    ords = sorted(set(map(ord, chars)))
    collapsed = r''
    for _, g in groupby(ords, key=lambda n, c=count(): n - next(c)):
        g = list(g)
        if len(g) > 1:
            # It's a range
            collapsed += r'{0}-{1}'.format(chz(g[0]), chz(g[-1]))
        else:
            collapsed += r'{0}'.format(chz(g[0]))
    return collapsed


def join(*pats: str, sep: str = '') -> str:
    if all(len(p) == 1 for p in pats):
        if sep == '|':
            pats = [r'[' + (''.join(pats)) + ']']
        else:
            pats = [''.join(pats)]
    inner = (r')' + sep + r'(?:').join(pats)
    joined = r'(?:(?:' + inner + r'))'
    return joined


def capture(name: str, group: str) -> str:
    # return r'(' + group + r')'
    return r'(?P<' + re.escape(name) + r'>' + group + r')'


def listed(pat: str, *, sep: str):
    return r'(?:(?:(?:(?:' + pat + r')*)(?:(?:' + sep + r'(?:' + pat + r'))*))|' + sep + r')'


def finalize(pat: str) -> str:
    return r'^' + pat + r'$'


def escaped(chars: str, *, sep: str = '') -> str:
    return join(*(r'(?:' + ODD_NUM_SLASHES + re.escape(c) + r')' for c in chars), sep=sep)


def unescaped(chars: str, *, sep: str = '') -> str:
    return join(*(r'(?:' + EVEN_NUM_SLASHES + re.escape(c) + r')' for c in chars), sep=sep)


# Characters between / that are not pattern symbols
BASE_ADDRESS_CHARS = r'''0123456789abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ"#$%&'()+.:;<=>@^_`|~ '''

# Characters that are allowed inside of {}, with no special meaning in that context
ARRAY_MEMBER_PATTERN = join(any_chars(BASE_ADDRESS_CHARS + r'!?*-[]'),
                            escaped(',{}/', sep='|'),
                            sep='|')

ARRAY_PATTERN = unescaped(r'{') \
                + listed(ARRAY_MEMBER_PATTERN, sep=unescaped(',')) \
                + unescaped('}')

# Characters that are allowed inside of []
CHARS_MEMBER_PATTERN = join(any_chars(BASE_ADDRESS_CHARS + r',!?*-{}'),
                            escaped('-[]/', sep='|'),
                            sep='|')

CHARS_PATTERN = unescaped(r'[') \
                + CHARS_MEMBER_PATTERN \
                + unescaped(r']')

WILDCARD_PATTERN = re.escape(r'*')
MAYBE_PATTERN = re.escape(r'?')

# Characters that are allowed outside of a {} or [], with no special meaning in that context
STRING_PATTERN = r'(?:(?:' \
                 + join(any_chars(BASE_ADDRESS_CHARS + r',!-'), escaped('{}[]/', sep='|'), sep='|') \
                 + r')+)'

PATH_PART_PATTERN = join(
    capture('array', ARRAY_PATTERN),
    capture('chars', CHARS_PATTERN),
    capture('wildcard', WILDCARD_PATTERN),
    capture('maybe', MAYBE_PATTERN),
    capture('string', STRING_PATTERN),
    sep='|',
)

PATH_PART_REGEX = re.compile(PATH_PART_PATTERN)

# Characters that are allowed between /, may be pattern symbols
PATH_PART_UNCAPTURED_PATTERN = join(any_char(BASE_ADDRESS_CHARS + r',!?*-[]{}') + '*', r'\\', sep='|')

PATH_PATTERN = r'(?:(?:' + unescaped('/') + PATH_PART_UNCAPTURED_PATTERN + ')*)'

PATH = 0
ARRAY = 1
CHARS = 2
WILDCARD = 3
MAYBE = 4
STRING = 5


def compile_osc_address_pattern(path_string: Union[str, None]):
    if path_string is None:
        path_string = '//*'
    path_part_strings = path_string.split('/')[1:]
    if not len(path_part_strings):
        raise ValueError('Invalid pattern %r' % path_string)
    patterns = []
    for path_part_string in path_part_strings:
        patterns.append(r''.join(parse_osc_address_pattern_path_part(path_part_string)))
    finalized = finalize(join(*patterns))
    logs.logger.debug('compile_osc_address_pattern(%r) => %r', path_string, finalized)
    return re.compile(finalized)


def parse_osc_address_pattern_path_part(path_part_string: str) -> Generator[str, None, None]:
    if path_part_string == '':
        # double-slash indicates a path-traversing wildcard, from OSC 1.1
        # see https://www.semanticscholar.org/paper/Features-and-Future-of-Open-Sound-Control-version-Freed-Schmeder/ec27bf1e63e692705c5993859dccac522330269a
        yield PATH_PATTERN
        return

    yield '/'
    prev_end = 0
    for match in PATH_PART_REGEX.finditer(path_part_string):
        (array,
         chars,
         wildcard,
         maybe,
         string) = match.groups()
        if match.start() != prev_end:
            raise ValueError('Invalid address pattern at position %s of %r' % (prev_end, path_part_string))
        elif array:
            # Strip {}
            array = array[1:-1]
            items = re.split(unescaped(r','), array)
            escaped_items = map(
                lambda i: re.escape(i)
                    .replace(r'\\,', ',')
                    .replace(r'\\}', '}')
                    .replace(r'\\{', '{')
                    .replace(r'\\/', '/'),
                items)
            pat = join(*escaped_items, sep='|')
            yield pat
        elif chars:
            negate = False
            # strip []
            chars = chars[1:-1]
            if chars[0] == '!':
                negate = True
                chars = chars[1:]
            pat = re.escape(chars) \
                .replace(r'\-', '-') \
                .replace(r'\\]', ']') \
                .replace(r'\\[', '[') \
                .replace(r'\\/', '/')
            if negate:
                pat = '^' + pat
            yield r'[' + pat + r']'
        elif wildcard:
            yield r'(' + PATH_PART_UNCAPTURED_PATTERN + '+)'
        elif maybe:
            yield r'(' + join(any_char(BASE_ADDRESS_CHARS + r'\,!?*-[]{}'), sep='|') + '?)'
        elif string:
            pat = re.escape(string) \
                .replace(r'\\{', r'{') \
                .replace(r'\\}', '}') \
                .replace(r'\\[', r'[') \
                .replace(r'\\]', ']') \
                .replace(r'\\/', '/')
            yield pat
        prev_end = match.end()
    if len(path_part_string) != prev_end:
        raise ValueError('Invalid address pattern at position %s of %r' % (prev_end, path_part_string))


def is_osc_address_pattern(path_string: Union[str, None]):
    if path_string is None:
        return True
    parts = path_string.split('/')[1:]
    if not len(parts):
        raise ValueError('Invalid pattern %r' % path_string)
    for p in parts:
        if p == '':
            return True
        prev_end = 0
        for match in PATH_PART_REGEX.finditer(p):
            (array,
             chars,
             wildcard,
             maybe,
             string) = match.groups()
            if match.start() != prev_end:
                raise ValueError('Invalid address pattern at position %s of %r' % (prev_end, p))
            elif array or chars or wildcard or maybe:
                return True
            prev_end = match.end()
        if len(p) != prev_end:
            raise ValueError('Invalid address pattern at position %s of %r' % (prev_end, p))
    return False