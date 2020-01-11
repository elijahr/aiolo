#!/usr/bin/env python -W ignore::DeprecationWarning

"""
boomboom: laptop keyboard drum machine

To use (install the requirements):

    $ pipenv install aiolo[dev]
    $ python boomboom.py

"""
import asyncio
import multiprocessing
import os
import time
import warnings
import wave

import aiolo
import pyaudio

PATH = os.path.dirname(os.path.abspath(__file__))

OSC_SERVER = 'osc.udp://:10033'

RATE = 44100
BPM = 120
BPS = BPM / 60
# 16th note
STEP = 4 / 16 * (60 / BPM)
FRAMES_PER_STEP = int(RATE * STEP)

KICK = aiolo.Route('/kick', 'T')
C_HAT = aiolo.Route('/c_hat', 'T')
O_HAT = aiolo.Route('/o_hat', 'T')
SNARE = aiolo.Route('/snare', 'T')
CLAP = aiolo.Route('/clap', 'T')
COWBELL = aiolo.Route('/cowbell', 'T')
AIRHORN = aiolo.Route('/airhorn', 'T')
EXIT = aiolo.Route('/exit', 'T')

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
) * 4)

ROUTES = {
    route: os.path.join(PATH, 'drums%s.wav' % route.path)
    for route in (KICK, C_HAT, O_HAT, SNARE, CLAP, COWBELL, AIRHORN)
}


class Machine:
    def __init__(self):
        self.loop = asyncio.get_event_loop()
        asyncio.set_event_loop(self.loop)
        self.server = aiolo.Server(url=OSC_SERVER)
        self.server.route(EXIT)
        for route in ROUTES.keys():
            self.server.route(route)
        self.subs = {
            route: route.sub()
            for route in ROUTES.keys()
        }
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
        async for _ in EXIT.sub():
            for sub in self.subs.values():
                sub.unsub()
            break

        self.stream.stop_stream()
        self.stream.close()
        self.pyaudio.terminate()

    async def sub_drum(self, route, sub):
        filepath = ROUTES[route]
        wav = wave.open(filepath)
        data = b''
        while True:
            chunk = wav.readframes(1024)
            if not chunk:
                break
            data += chunk
        data = data[:FRAMES_PER_STEP]
        async for _ in sub:
            # sub will yield anytime it receives a trigger
            self.stream.write(data)


def subscribe():
    with warnings.catch_warnings():
        warnings.filterwarnings("ignore", category=DeprecationWarning)
        machine = Machine()
        machine.run()


def publish():
    # Give the server some time to start
    time.sleep(0.25)
    client = aiolo.Client(url=OSC_SERVER)
    try:
        for i, route in enumerate(SEQUENCE):
            client.pubm(aiolo.Message(route, True))
            time.sleep(STEP)
    finally:
        client.pubm(aiolo.Message(EXIT, True))


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
