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
import random
import time
import warnings

import aiolo
import numpy as np
import pyaudio
import scipy.io.wavfile
import scipy.signal

ESC = '\x1b'

PATH = os.path.dirname(os.path.abspath(__file__))

OSC_SERVER = 'osc.udp://:10033'

RATE = 44100
BPM = 120
BPS = BPM / 60
# 16th note
STEP = 4 / 16 * (60 / BPM)
FRAMES_PER_STEP = int(RATE * STEP)

KICK = aiolo.Route('/kick', 'f')
C_HAT = aiolo.Route('/c_hat', 'f')
O_HAT = aiolo.Route('/o_hat', 'f')
SNARE = aiolo.Route('/snare', 'f')
CLAP = aiolo.Route('/clap', 'f')
COWBELL = aiolo.Route('/cowbell', 'f')
AIRHORN = aiolo.Route('/airhorn', 'f')
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
        self.server.add_route(EXIT)
        for route in ROUTES.keys():
            self.server.add_route(route)
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
        self.seqlock = asyncio.Lock(loop=self.loop)

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
        samplerate, wav = scipy.io.wavfile.read(filepath)
        async for (ratio,) in sub:
            # sub will yield anytime it receives a trigger
            data = scipy.signal.resample(wav, int(len(wav) * ratio))
            data = data[:FRAMES_PER_STEP] / 10
            self.stream.write(data.astype(np.int16))


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
            if route == COWBELL:
                # pitch variance for cowbell
                ratio = random.uniform(0.5, 3.2)
            else:
                ratio = 1.0
            client.pubm(aiolo.Message(route, ratio))
            time.sleep(STEP)
    finally:
        client.pubm(aiolo.Message(EXIT, [True]))


def config_logging():
    import logging
    from aiolo.logs import logger
    ch = logging.StreamHandler()
    ch.setLevel(logging.DEBUG)
    logger.addHandler(ch)
    logger.setLevel(logging.DEBUG)


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
