import logging


__all__ = ['logger']


logger = logging.getLogger('aiolo')


def debug(*args, **kwargs):
    IF DEBUG:
        logger.debug(*args, **kwargs)
