
class Midi(tuple):
    def __new__(cls, *args):
        if len(args) != 4:
            raise ValueError('Midi requires 4 positional arguments')
        return tuple.__new__(Midi, args)
