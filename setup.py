
import glob
import os
import subprocess


from setuptools import setup, Extension
from setuptools.command.build_ext import build_ext as _build_ext


class build_ext(_build_ext):
    def finalize_options(self):
        from Cython.Build.Dependencies import cythonize
        gdb_debug = bool(self.debug)
        self.distribution.ext_modules[:] = cythonize(
            self.distribution.ext_modules,
            gdb_debug=gdb_debug,
            compile_time_env=get_cython_compile_time_env(),
        )
        super(build_ext, self).finalize_options()


def get_cython_compile_time_env():
    try:
        lo_version = subprocess.check_output(
            ['pkg-config', '--modversion', 'liblo'],
        ).strip().decode('utf8') or '0.29'
    except (subprocess.CalledProcessError, FileNotFoundError):
        lo_version = '0.29'
    return dict(LO_VERSION=lo_version)


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
    version='3.1.0',
    description='asyncio-friendly Python bindings for liblo',
    long_description=long_description,
    long_description_content_type="text/markdown",
    url='https://github.com/elijahr/aiolo',
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
    cmdclass={
        'build_ext': build_ext,
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
            'netifaces',
            'pytest',
            'pytest-asyncio',
        ],
        'dev': [
            'netifaces',
            'pytest',
            'pytest-asyncio',
            'pytest-watch',
        ]
    },
    classifiers=[
        'Environment :: Console',
        'Intended Audience :: Developers',
        'License :: OSI Approved :: BSD License',
        'Operating System :: MacOS :: MacOS X',
        'Operating System :: POSIX :: Linux',
        'Programming Language :: Python :: 3',
        'Topic :: Multimedia :: Sound/Audio',
        'Framework :: AsyncIO',
    ],
)
