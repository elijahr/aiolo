import re
import socket
from typing import Union


__all__ = ['is_valid_ip_address', 'is_valid_ipv4_address', 'is_valid_ipv6_address']


IPV4_REGEX = re.compile(r'^((25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)\.){3}(25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)$')

IPV6_PATTERN = (
    r'(([0-9a-fA-F]{1,4}:){7,7}[0-9a-fA-F]{1,4}|([0-9a-fA-F]{1,4}:){1,7}:|([0-9a-fA-F]{1,4}:){1,6}:[0-9a-fA-F]{1,4}|(['
    r'0-9a-fA-F]{1,4}:){1,5}(:[0-9a-fA-F]{1,4}){1,2}|([0-9a-fA-F]{1,4}:){1,4}(:[0-9a-fA-F]{1,4}){1,3}|([0-9a-fA-F]{1,4'
    r'}:){1,3}(:[0-9a-fA-F]{1,4}){1,4}|([0-9a-fA-F]{1,4}:){1,2}(:[0-9a-fA-F]{1,4}){1,5}|[0-9a-fA-F]{1,4}:((:[0-9a-fA-F'
    r']{1,4}){1,6})|:((:[0-9a-fA-F]{1,4}){1,7}|:)|fe80:(:[0-9a-fA-F]{0,4}){0,4}%[0-9a-zA-Z]{1,}|::(ffff(:0{1,4}){0,1}:'
    r'){0,1}((25[0-5]|(2[0-4]|1{0,1}[0-9]){0,1}[0-9])\.){3,3}(25[0-5]|(2[0-4]|1{0,1}[0-9]){0,1}[0-9])|([0-9a-fA-F]{1,4'
    r'}:){1,4}:((25[0-5]|(2[0-4]|1{0,1}[0-9]){0,1}[0-9])\.){3,3}(25[0-5]|(2[0-4]|1{0,1}[0-9]){0,1}[0-9]))')

IPV6_REGEX = re.compile(r'^' + IPV6_PATTERN + '$')


IPV6_NETLOC_REGEX = re.compile(r'^\[(' + IPV6_PATTERN + r')\](?:(:[\d]+))?$')


def is_valid_ip_address(address: Union[str, bytes]) -> bool:
    return is_valid_ipv4_address(address) or is_valid_ipv6_address(address)


def is_valid_ipv4_address(address: Union[str, bytes]) -> bool:
    if isinstance(address, bytes):
        address = address.decode('utf8')
    try:
        socket.inet_pton(socket.AF_INET, address)
    except AttributeError:  # no inet_pton here, sorry
        try:
            socket.inet_aton(address)
        except socket.error:
            return False
        try:
            return bool(IPV4_REGEX.match(address))
        except TypeError:
            return False
    except socket.error:  # not a valid address
        return False
    return True


def is_valid_ipv6_address(address: Union[str, bytes]) -> bool:
    if isinstance(address, bytes):
        address = address.decode('utf8')
    try:
        socket.inet_pton(socket.AF_INET6, address)
    except AttributeError:  # no inet_pton here, sorry
        try:
            socket.inet_aton(address)
        except socket.error:
            return False
        try:
            return bool(IPV6_REGEX.match(address))
        except TypeError:
            return False
    except socket.error:  # not a valid address
        return False
    return True
