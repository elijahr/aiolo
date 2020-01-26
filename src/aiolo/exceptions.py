

__all__ = [
    'AIOLoError', 'Unsubscribed', 'StartError', 'StopError', 'SendError', 'RouteError']


class AIOLoError(Exception):
    pass


class Unsubscribed(AIOLoError):
    pass


class StartError(AIOLoError):
    pass


class StopError(AIOLoError):
    pass


class SendError(AIOLoError):
    pass


class RouteError(AIOLoError):
    pass
