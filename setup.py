
import glob
import os
import subprocess


from setuptools import setup, Extension
from setuptools.command.build_ext import build_ext as _build_ext


class build_ext(_build_ext):
    def finalize_options(self):
        from Cython.Build.Dependencies import cythonize
        self.distribution.ext_modules[:] = cythonize(
            self.distribution.ext_modules,
            gdb_debug=self.debug,
            compile_time_env=get_cython_compile_time_env(DEBUG=self.debug),
        )
        super(build_ext, self).finalize_options()


def get_cython_compile_time_env(**env):
    try:
        lo_version = subprocess.check_output(
            ['pkg-config', '--modversion', 'liblo'],
        ).strip().decode('utf8') or '0.29'
    except (subprocess.CalledProcessError, FileNotFoundError):
        lo_version = '0.29'
    e = dict(_LO_VERSION=lo_version)
    e.update(env)
    return e


DIR = os.path.dirname(__file__)


about = {}
with open(os.path.join(DIR, 'src', 'aiolo', '__version__.py'), 'r') as f:
    exec(f.read(), about)


with open("README.md", "r") as fh:
    readme = fh.read()


def get_pyx():
    for path in glob.glob(os.path.join(DIR, 'src', 'aiolo', '*.pyx')):
        module = 'aiolo.%s' % os.path.splitext(os.path.basename(path))[0]
        source = os.path.join('src', 'aiolo', os.path.basename(path))
        yield module, source


setup(
    name=about['__title__'],
    version=about['__version__'],
    description=about['__description__'],
    long_description=readme,
    long_description_content_type="text/markdown",
    url=about['__url__'],
    author=about['__author__'],
    author_email=about['__author_email__'],
    packages=['aiolo'],
    package_dir={
      'aiolo': os.path.join('src', 'aiolo'),
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
            'uvloop',
            'netifaces',
            'pytest',
            'pytest-asyncio',
            'pytest-xdist',
            'pytest-lazy-fixture',
        ],
        'dev': [
            'uvloop',
            'netifaces',
            'pytest',
            'pytest-asyncio',
            'pytest-xdist',
            'pytest-lazy-fixture',
            'pytest-watch',
            'pytest-instafail',
        ]
    },
    classifiers=[
        'Topic :: Multimedia :: Sound/Audio',
        'Framework :: AsyncIO',
        'Operating System :: MacOS :: MacOS X',
        'Operating System :: POSIX :: Linux',
        'Programming Language :: Python :: 3',
        'Programming Language :: Python :: Implementation :: PyPy',
        'Programming Language :: Python :: Implementation :: CPython',
        'License :: OSI Approved :: BSD License',
    ],
)
