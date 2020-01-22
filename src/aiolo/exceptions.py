

__all__ = [
    'AIOLoError', 'Unsubscribed', 'StartError', 'StopError', 'DuplicateRoute', 'RouteDoesNotExist', 'SendError',
    'RouteError', 'ServeError']


class AIOLoError(Exception):
    pass


class Unsubscribed(AIOLoError):
    pass


class StartError(AIOLoError):
    pass


class StopError(AIOLoError):
    pass


class DuplicateRoute(AIOLoError):
    pass


class RouteDoesNotExist(AIOLoError):
    pass


class SendError(AIOLoError):
    pass


class RouteError(AIOLoError):
    pass


class ServeError(AIOLoError):
    pass
