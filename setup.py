
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

LIBLO_DIR = os.path.join(DIR, 'liblo')

# Version of liblo optionally compiled and included with this Python package,
# To use a bundled liblo, run:
#       python setup.py install --use-bundled-liblo
BUNDLED_LO_VERSION = '0.31'

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


def have_install_name_tool():
    try:
        subprocess.check_call(['which', 'install_name_tool'])
    except subprocess.CalledProcessError:
        return False
    return True


def have_patchelf():
    try:
        subprocess.check_call(['which', 'patchelf'])
    except subprocess.CalledProcessError:
        return False
    return True


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


def get_cython_compile_time_env(use_bundled_liblo=False, defaults=None):
    env = dict(**defaults or {})
    if use_bundled_liblo:
        env['_LO_VERSION'] = BUNDLED_LO_VERSION
    else:
        env['_LO_VERSION'] = get_system_lo_version()
    env.update({
        'PYPY': __pypy__ is not None
    })
    return env


class build_ext(_build_ext):
    user_options = _build_ext.user_options + [
        ('use-bundled-liblo', None, 'Install a bundled version of liblo with this package'),
    ]
    boolean_options = _build_ext.boolean_options + ['use-bundled-liblo']

    def initialize_options(self):
        super(build_ext, self).initialize_options()
        self.use_bundled_liblo = '--use-bundled-liblo' in sys.argv
        self.debug = '--debug' in sys.argv

    def finalize_options(self):
        from Cython.Build.Dependencies import cythonize
        for item in itertools.chain(
                glob.glob(os.path.join(DIR, 'src', 'aiolo', '*.c')),
                glob.glob(os.path.join(DIR, 'src', 'aiolo', '*.h'))):
            os.remove(item)

        compile_time_env = get_cython_compile_time_env(
            use_bundled_liblo=self.use_bundled_liblo,
            defaults=dict(DEBUG=self.debug))

        if not self.use_bundled_liblo:
            for extn in self.distribution.ext_modules:
                extn.libraries = ['lo']

        self.distribution.ext_modules[:] = cythonize(
            self.distribution.ext_modules,
            gdb_debug=self.debug,
            compile_time_env=compile_time_env,
        )

        super(build_ext, self).finalize_options()

        # Never install as an egg
        self.single_version_externally_managed = False

    def run(self):
        if self.use_bundled_liblo:
            # Sanity checks for installation
            if SYSTEM == 'darwin':
                if not have_install_name_tool():
                    raise RuntimeError(
                        'install_name_tool not found, install Xcode tools or install aiolo without --use-bundled-liblo')
            elif SYSTEM not in ('win32', 'cygwin') and not have_patchelf():
                raise RuntimeError(
                    'patchelf not found, install patchelf with your system package manager '
                    '(apt/rpm/apk/etc) or install aiolo without --use-bundled-liblo')

            print('\n*** building liblo ***')
            liblo_prefix = os.path.abspath(os.path.join(DIR, self.build_lib, 'aiolo', 'liblo'))
            library_dir = os.path.join(liblo_prefix, 'lib')
            include_dir = os.path.join(liblo_prefix, 'include')

            # Look for the custom library rather than system
            extra_link_args = ['-L%s' % library_dir, '-llo.custom']
            for extn in self.distribution.ext_modules:
                extn.extra_link_args += extra_link_args

            for extn in self.distribution.ext_modules:
                extn.library_dirs.append(library_dir)
                extn.include_dirs.append(include_dir)

            self.library_dirs.append(library_dir)
            self.include_dirs.append(include_dir)

            # Build custom liblo to install alongside aiolo
            try:
                subprocess.check_call(['make', 'clean'])
            except subprocess.CalledProcessError:
                pass
            cmds = [
                ['./autogen.sh',
                 '--prefix=%s' % liblo_prefix,
                 '--disable-tests',
                 '--disable-network-tests',
                 '--disable-tools',
                 '--disable-examples'],
                ['make'],
                ['make', 'install'],  # Install to the build directory
            ]
            if self.debug:
                # Build liblo with debug symbols too
                cmds[0].append('--enable-debug')
            for cmd in cmds:
                subprocess.check_call(
                    cmd, stdin=sys.stdin, stdout=sys.stdout, stderr=sys.stderr, cwd=LIBLO_DIR)

            os.rename(os.path.join(library_dir, 'liblo.7.dylib'), os.path.join(library_dir, 'liblo.7.custom.dylib'))
            os.unlink(os.path.join(library_dir, 'liblo.dylib'))
            os.symlink(os.path.join(library_dir, 'liblo.7.custom.dylib'), os.path.join(library_dir, 'liblo.custom.dylib'))

            print('*** built liblo ***')
        super(build_ext, self).run()


class install(_install):
    user_options = _install.user_options + [
        ('use-bundled-liblo', None, 'Install a bundled version of liblo with this package'),
        ('debug', None, 'Build with debug symbols'),
    ]
    boolean_options = _install.boolean_options + ['use-bundled-liblo']

    def initialize_options(self):
        super(install, self).initialize_options()
        self.use_bundled_liblo = '--use-bundled-liblo' in sys.argv
        self.debug = '--debug' in sys.argv

    def finalize_options(self):
        super(install, self).finalize_options()
        # Never install as an egg
        self.single_version_externally_managed = False

    def run(self):
        super(install, self).run()
        if self.use_bundled_liblo:
            # Adjust the link to the shared library from the build directory to the install directory
            source_library_path = os.path.abspath(
                os.path.join(self.build_lib, 'aiolo', 'liblo', 'lib', 'liblo.7.custom.%s' % LIBRARY_SUFFIX))
            destination_library_dir = os.path.abspath(
                os.path.join(self.install_platlib, 'aiolo', 'liblo', 'lib'))
            destination_library_path = os.path.join(destination_library_dir, 'liblo.7.custom.%s' % LIBRARY_SUFFIX)
            if have_install_name_tool():
                cmds = [
                    ['install_name_tool', '-change', source_library_path, destination_library_path],
                    ['install_name_tool', '-add_rpath', destination_library_dir],
                ]
            elif have_patchelf():
                cmds = [
                    # ['patchelf', '--replace-needed', source_library_path, destination_library_path],
                    ['patchelf', '--set-rpath', destination_library_dir],
                ]
            else:
                # Presumably, a no-op on windows
                cmds = []
            for mod in glob.glob(os.path.join(self.install_platlib, 'aiolo', '*.so')):
                for cmd in cmds:
                    c = cmd + [mod]
                    print(' '.join(c))
                    subprocess.check_call(c)
            print('\naiolo installed successfully\n')


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
            # include built liblo if --use-bundled-liblo was passed
            'liblo/*',
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
