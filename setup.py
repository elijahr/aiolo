
import glob
import os

from setuptools import setup, Extension


with open("README.md", "r") as fh:
    long_description = fh.read()


DIR = os.path.dirname(__file__)


def get_pyx():
    for path in glob.glob(os.path.join(DIR, 'src/aiolo/*.pyx')):
        module = 'aiolo.%s' % os.path.splitext(os.path.basename(path))[0]
        source = os.path.join('src/aiolo', os.path.basename(path))
        yield module, source


setup(
    name='aiolo',
    version='3.0.0',
    description='asyncio-friendly Python bindings for liblo',
    long_description=long_description,
    long_description_content_type="text/markdown",
    author='Elijah Shaw-Rutschman',
    author_email='elijahr+aiolo@gmail.com',
    packages=['aiolo'],
    package_dir={
      'aiolo': 'src/aiolo',
    },
    package_data={
        'aiolo': [
            # Include cython source
            '*.pyx',
            '*.pxd',
        ],
    },
    ext_modules=[
        Extension(
            module,
            sources=[source],
            libraries=['lo'],
        )
        for module, source in get_pyx()
    ],
    setup_requires=['cython'],
    extras_require={
        'examples': [
            'pyaudio',
        ],
        'test': [
            'pytest',
            'pytest-asyncio',
        ],
        'dev': [
            'sphinx',
        ]
    },
    classifiers=[
        'Development Status :: 3 - Alpha',
        'Environment :: Console',
        'Intended Audience :: Developers',
        'License :: OSI Approved :: BSD License',
        'Operating System :: MacOS :: MacOS X',
        'Operating System :: POSIX :: Linux',
        'Programming Language :: Python :: 3',
        'Topic :: Multimedia :: Sound/Audio',
        'Topic :: Multimedia :: Sound/Audio :: Sound Synthesis',
        'Framework :: AsyncIO',
    ],
)
