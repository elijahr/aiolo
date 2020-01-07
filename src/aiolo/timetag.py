
class TimeTag(tuple):
    def __new__(cls, *args):
        if len(args) != 2:
            raise ValueError('TimeTag requires 2 positional arguments')
        return tuple.__new__(TimeTag, args)
