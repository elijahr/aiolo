
# from Cython.Build import cythonize
from setuptools import setup, Extension


with open("README.md", "r") as fh:
    long_description = fh.read()


setup(
    name='aiolo',
    version='2.0.0',
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
            'aiolo.bundles',
            sources=['src/aiolo/bundles.pyx'],
            libraries=['lo'],
        ),
        Extension(
            'aiolo.clients',
            sources=['src/aiolo/clients.pyx'],
            libraries=['lo'],
        ),
        Extension(
            'aiolo.lo',
            sources=['src/aiolo/lo.pyx'],
            libraries=['lo'],
        ),
        Extension(
            'aiolo.messages',
            sources=['src/aiolo/messages.pyx'],
            libraries=['lo'],
        ),
        Extension(
            'aiolo.servers',
            sources=['src/aiolo/servers.pyx'],
            libraries=['lo'],
        ),
        Extension(
            'aiolo.timetags',
            sources=['src/aiolo/timetags.pyx'],
            libraries=['lo'],
        ),
        Extension(
            'aiolo.utils',
            sources=['src/aiolo/utils.pyx'],
            libraries=['lo'],
        ),
    ],
    setup_requires=['cython'],
    extras_require={
        'dev': [
            'pyaudio',
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
