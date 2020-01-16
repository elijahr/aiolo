
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


def pytest_configure(config):
    if config.getoption("verbose") > 0:
        ch = logging.StreamHandler()
        ch.setLevel(logging.DEBUG)

        aiolo.logger.addHandler(ch)
        aiolo.logger.setLevel(logging.DEBUG)

        logging.getLogger('asyncio').addHandler(ch)
        logging.getLogger('asyncio').setLevel(logging.DEBUG)
