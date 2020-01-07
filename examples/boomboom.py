#!/usr/bin/env python -W ignore::DeprecationWarning

"""
boomboom: laptop keyboard drum machine

To use (install the requirements):

    $ pip install aiolo[dev]
    $ ./boomboom.py

Clack away!

"""
import asyncio
import multiprocessing

import sounddevice
import soundfile
import uvloop

import os
import sys
import select
import tty
import termios

import aiolo


ESC = '\x1b'

_TRIGGERS = {
    'kick': 'zxcvb',
    'snar': 'nm,./',
    'clap': 'asdfg',
    'bell': 'hjkl;',
    'chat': 'qwert',
    'ohat': 'yuiop',
}

TRIGGERS = {
    key: name
    for name, keys in _TRIGGERS.items()
    for key in keys
}

PATH = os.path.dirname(os.path.abspath(__file__))


def getch():
    while True:
        if select.select([sys.stdin], [], [], 10000) == ([sys.stdin], [], []):
            ch = sys.stdin.read(1)
            if ch == ESC:
                break
            yield ch


class Machine:
    def __init__(self):
        self.loop = uvloop.new_event_loop()
        self.server = aiolo.Server(url='osc.udp://:10022', loop=self.loop)
        self.subs = {
            # set up some boolean trigger routes on the server
            'kick': self.server.sub('/kick', 'T'),
            'snar': self.server.sub('/snar', 'T'),
            'chat': self.server.sub('/chat', 'T'),
            'ohat': self.server.sub('/ohat', 'T'),
            'bell': self.server.sub('/bell', 'T'),
            'clap': self.server.sub('/clap', 'T'),
        }

    def run(self):
        self.server.start()
        self.loop.run_until_complete(self.serve())
        self.loop.close()
        self.server.stop()

    async def serve(self):
        await asyncio.gather(*[
            self.loop.create_task(self.handle_exit())
        ] + [
            self.loop.create_task(self.handle_drum(drum, sub))
            for drum, sub in self.subs.items()
        ])

    async def handle_exit(self):
        async for _ in self.server.sub('/exit', 'T'):
            for sub in self.subs:
                sub.unsub()
            break

    async def handle_drum(self, drum, sub):
        filepath = os.path.join(PATH, 'drums/%s.wav' % drum)
        data, fs = soundfile.read(filepath, dtype='float32')
        async for _ in sub:
            sounddevice.play(data, fs)


def serve():
    machine = Machine()
    machine.run()


def main():
    serve_process = multiprocessing.Process(target=serve)
    serve_process.start()

    client = aiolo.Client(url='osc.udp://:10022')
    prev = termios.tcgetattr(sys.stdin)
    try:
        print('Pump up the volume and start clackin that keyboard')
        tty.setcbreak(sys.stdin.fileno())
        for ch in getch():
            try:
                drum = TRIGGERS[ch]
            except KeyError:
                pass
            else:
                client.pub('/%s' % drum, 'T', True)
    finally:
        client.pub('/exit', 'T', True)
        serve_process.join()
        termios.tcsetattr(sys.stdin, termios.TCSADRAIN, prev)


if __name__ == '__main__':
    main()
