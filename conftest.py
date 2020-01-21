
import faulthandler

import pytest

faulthandler.enable(all_threads=True)

try:
    import tracemalloc
    tracemalloc.start()
except ImportError:
    # Not available in pypy
    pass

import logging

import aiolo


def pytest_addoption(parser):
    parser.addoption("--ipv6", action="store_true", help="Run tests for IPv6 support")
    parser.addoption("--dump-logs", action="store", help="Run tests for IPv6 support")


def pytest_configure(config):
    config.addinivalue_line(
        "markers", "ipv6: mark test to only run if --ipv6 is passed"
    )
    config.addinivalue_line(
        "markers", "no_ipv6: mark test to not run if --ipv6 is passed"
    )
    if config.getoption('verbose') > 0:
        h = logging.StreamHandler()
        h.setLevel(logging.DEBUG)
        aiolo.logger.addHandler(h)
        aiolo.logger.setLevel(logging.DEBUG)
    if config.getoption('dump_logs'):
        # create file handler which logs even debug messages
        h = logging.FileHandler(config.getoption('dump_logs'))
        h.setLevel(logging.DEBUG)
        aiolo.logger.addHandler(h)
        aiolo.logger.setLevel(logging.DEBUG)


def pytest_runtest_setup(item):
    if any(item.iter_markers(name="ipv6")) and not item.config.getoption('ipv6'):
        pytest.skip('Not running IPv6 test')
    if any(item.iter_markers(name="no_ipv6")) and item.config.getoption('ipv6'):
        pytest.skip('Not running non-IPv6 test')
