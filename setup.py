
import glob
import itertools
import os
import subprocess
import sys

from setuptools import setup, Extension
from setuptools.command.build_ext import build_ext as _build_ext
from setuptools.command.install import install as _install


try:
    import __pypy__
except ImportError:
    __pypy__ = None


DIR = os.path.dirname(__file__)

# At the time of this writing, homebrew and ubuntu are using 0.29
DEFAULT_SYSTEM_LO_VERSION = '0.29'

SYSTEM = sys.platform

IS_WINDOWS = SYSTEM in ('win32', 'cygwin')

if SYSTEM == 'darwin':
    LIBRARY_SUFFIX = 'dylib'
elif IS_WINDOWS:
    # I don't know if windows actually works with this python package but I won't
    # specifically exclude it. If it doesn't work for you, patches are welcome!
    LIBRARY_SUFFIX = 'dll'
else:
    LIBRARY_SUFFIX = 'so'


def get_system_lo_version():
    """
    Use pkg-config to get the installed version of liblo
    """
    cmd = ['pkg-config', '--modversion', 'liblo']
    try:
        output = subprocess.check_output(cmd)
    except (subprocess.CalledProcessError, FileNotFoundError):
        # Either pkg-config isn't used on this system or an error occurred while calling it,
        # so default to a common version
        return DEFAULT_SYSTEM_LO_VERSION
    else:
        return output.strip().decode('utf8') or DEFAULT_SYSTEM_LO_VERSION


def get_cython_compile_time_env(defaults=None):
    env = dict(**defaults or {})
    env['_LO_VERSION'] = get_system_lo_version()
    env.update({
        'PYPY': __pypy__ is not None
    })
    return env


class build_ext(_build_ext):
    def initialize_options(self):
        super(build_ext, self).initialize_options()
        self.debug = '--debug' in sys.argv

    def finalize_options(self):
        from Cython.Build.Dependencies import cythonize
        for item in itertools.chain(
                glob.glob(os.path.join(DIR, 'src', 'aiolo', '*.c')),
                glob.glob(os.path.join(DIR, 'src', 'aiolo', '*.h'))):
            os.remove(item)

        compile_time_env = get_cython_compile_time_env(
            defaults=dict(DEBUG=self.debug))

        self.distribution.ext_modules[:] = cythonize(
            self.distribution.ext_modules,
            gdb_debug=self.debug,
            compile_time_env=compile_time_env,
        )

        super(build_ext, self).finalize_options()

        # Never install as an egg
        self.single_version_externally_managed = False


class install(_install):
    user_options = _install.user_options + [
        ('debug', None, 'Build with debug symbols'),
    ]

    def initialize_options(self):
        super(install, self).initialize_options()
        self.debug = '--debug' in sys.argv

    def finalize_options(self):
        super(install, self).finalize_options()
        # Never install as an egg
        self.single_version_externally_managed = False


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
    data_files=['README.md', 'LICENSE'],
    package_data={
        'aiolo': [
            # Include cython source
            '*.pyx',
            '*.pxd',
        ],
    },
    cmdclass={
        'build_ext': build_ext,
        'install': install
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
        ],
        'dev': [
            'uvloop',
            'netifaces',
            'pytest',
            'pytest-asyncio',
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
