
import faulthandler

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
    parser.addoption("--dump-logs", action="store", help="Dump logs to a file")


def pytest_configure(config):
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

