
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
