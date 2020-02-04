
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


CANCEL_TIMEOUT = None


def pytest_addoption(parser):
    parser.addoption("--dump-logs", action="store", help="Dump logs to a file")
    parser.addoption("--cancel-timeout", action="store", type=float, default=6,
                     help="The number of seconds to wait before cancelling pending tasks")


def pytest_configure(config):
    global CANCEL_TIMEOUT
    CANCEL_TIMEOUT = config.getoption('cancel_timeout')

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

