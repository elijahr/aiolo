#!/usr/bin/env python -W ignore::DeprecationWarning

"""
drum_machine: a simple drum machine

To use (install the requirements):

    $ pipenv install aiolo[examples]
    $ python drum_machine.py

"""
import asyncio
import multiprocessing
import os
import warnings
import wave

import aiolo
import pyaudio

PATH = os.path.dirname(os.path.abspath(__file__))

OSC_SERVER = 'osc.udp://:10033'

RATE = 44100
BPM = 120
# 16th note
STEP = 4 / 16 * (60 / BPM)
FRAMES_PER_STEP = int(RATE * STEP)

KICK = aiolo.Route('/kick', aiolo.TIMETAG)
C_HAT = aiolo.Route('/c_hat', aiolo.TIMETAG)
O_HAT = aiolo.Route('/o_hat', aiolo.TIMETAG)
SNARE = aiolo.Route('/snare', aiolo.TIMETAG)
CLAP = aiolo.Route('/clap', aiolo.TIMETAG)
COWBELL = aiolo.Route('/cowbell', aiolo.TIMETAG)
AIRHORN = aiolo.Route('/airhorn', aiolo.TIMETAG)
EXIT = aiolo.Route('/exit', aiolo.TIMETAG)

SEQUENCE = ((
    KICK, C_HAT, O_HAT, C_HAT,
    KICK, C_HAT, O_HAT, C_HAT,
    KICK, C_HAT, O_HAT, C_HAT,
    KICK, C_HAT, O_HAT, C_HAT,
) * 2) + ((
    KICK, C_HAT, CLAP, C_HAT,
    KICK, CLAP, O_HAT, C_HAT,
    KICK, C_HAT, CLAP, C_HAT,
    KICK, CLAP, O_HAT, C_HAT,
) * 2) + ((
    KICK, C_HAT, CLAP, SNARE,
    KICK, CLAP, O_HAT, C_HAT,
    KICK, C_HAT, CLAP, SNARE,
    KICK, CLAP, O_HAT, C_HAT,
) * 2) + ((
    KICK, C_HAT, CLAP, SNARE,
    KICK, CLAP, O_HAT, COWBELL,
    KICK, C_HAT, CLAP, SNARE,
    KICK, CLAP, O_HAT, COWBELL,
) * 2) + ((
    AIRHORN, C_HAT, CLAP, SNARE,
    KICK, CLAP, O_HAT, COWBELL,
    KICK, C_HAT, CLAP, SNARE,
    KICK, CLAP, O_HAT, COWBELL,
    KICK, C_HAT, CLAP, SNARE,
    KICK, CLAP, O_HAT, COWBELL,
    KICK, C_HAT, CLAP, SNARE,
    KICK, CLAP, O_HAT, COWBELL,
) * 4) + (EXIT, )


DRUM_ROUTES = (KICK, C_HAT, O_HAT, SNARE, CLAP, COWBELL, AIRHORN)


WAVS_BY_ROUTE = {
    route: os.path.join(PATH, 'drums%s.wav' % route.path)
    for route in DRUM_ROUTES
}


class Machine:
    def __init__(self):
        self.loop = asyncio.get_event_loop()
        asyncio.set_event_loop(self.loop)
        self.server = aiolo.Server(url=OSC_SERVER)
        self.server.route(EXIT)
        self.subs = {}
        for route in DRUM_ROUTES:
            self.server.route(route)
            self.subs[route] = route.sub()
        self.pyaudio = pyaudio.PyAudio()
        self.stream = self.pyaudio.open(
            format=pyaudio.paInt16,
            channels=1,
            rate=RATE,
            output=True)

    def run(self):
        self.server.start()
        self.loop.run_until_complete(self.serve())
        self.loop.close()
        self.server.stop()

    async def serve(self):
        await asyncio.gather(*[
            self.loop.create_task(self.sub_drum(route, sub))
            for route, sub in self.subs.items()
        ] + [
            self.loop.create_task(self.sub_exit())
        ])

    async def sub_exit(self):
        async for (timetag, ) in EXIT.sub():
            self.loop.call_at(timetag.timestamp, self.exit_task)
            break

    def exit_task(self):
        self.loop.create_task(self.exit())

    async def exit(self):
        for sub in self.subs.values():
            await sub.unsub()

        self.stream.stop_stream()
        self.stream.close()
        self.pyaudio.terminate()

    async def sub_drum(self, route, sub):
        wav = get_wav(route)

        def play():
            self.stream.write(wav)

        async for (timetag, ) in sub:
            # sub will yield anytime it receives a trigger
            self.loop.call_at(timetag.timestamp, play)


def get_wav(route):
    filepath = WAVS_BY_ROUTE[route]
    f = wave.open(filepath)
    wav = b''
    while True:
        chunk = f.readframes(1024)
        if not chunk:
            break
        wav += chunk
    return wav[:FRAMES_PER_STEP]


def subscribe():
    with warnings.catch_warnings():
        warnings.filterwarnings("ignore", category=DeprecationWarning)
        machine = Machine()
        machine.run()


def publish():
    timetag = aiolo.TimeTag(asyncio.get_event_loop().time()+5)
    address = aiolo.Address(url=OSC_SERVER)
    # send the sequence as a timestamped bundle
    address.bundle(
        aiolo.Message(route, timetag + (STEP * i))
        for i, route in enumerate(SEQUENCE)
    )


def config_logging():
    import logging
    ch = logging.StreamHandler()
    ch.setLevel(logging.DEBUG)
    aiolo.logger.addHandler(ch)
    aiolo.logger.setLevel(logging.DEBUG)


def main():
    config_logging()
    print("===\nAdjust your speakers to a safe volume and hit enter to start the music. Press CTRL-C to exit.\n===")
    input()
    proc = multiprocessing.Process(target=publish)
    proc.start()
    try:
        subscribe()
    finally:
        proc.join()


if __name__ == '__main__':
    main()
