

__all__ = [
    'AIOLoError', 'PathSyntaxError', 'RouteError', 'SendError', 'StartError', 'StopError', 'Unsubscribed']


class AIOLoError(Exception):
    pass


class PathSyntaxError(AIOLoError):
    pass


class RouteError(AIOLoError):
    pass


class SendError(AIOLoError):
    pass


class StartError(AIOLoError):
    pass


class StopError(AIOLoError):
    pass


class Unsubscribed(AIOLoError):
    pass
