# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [4.2.0] - 2026-10-20

### Added
- **Modern liblo features** (liblo 0.30–0.36 support):
  - Bundle memory reuse and timetag updating: `Bundle.clear()` (`lo_bundle_clear`) and `Bundle.set_timetag()` (`lo_bundle_set_timestamp`).
  - Zero-length OSC blob support: allowed packing empty bytes (`b""`) and empty bytearrays; guarded `memcpy` in `unpack_args` against dereferencing 0-sized blobs with NULL pointers.
  - Native OSC pattern matching: added `pattern_match(target, pattern) -> bool` in `aiolo.paths` backed by native `lo.lo_pattern_match`.
  - Granular server configuration: added `ServerConfig` dataclass in `aiolo.types` and bound `lo_server_config` across `AioServer` and `ThreadedServer`.
  - Multi-server polling: added `servers_recv_noblock` and `servers_wait` to poll multiple servers in a single native syscall.
- **CI & Testing**:
  - Added GitHub Actions CI matrix testing across Ubuntu and macOS on Python 3.10–3.13.
  - Added modern liblo test suite in `test_liblo_modern.py`.

### Changed
- **Cython 3.x Modernization**:
  - Full compatibility with Cython 3.0+ (resolved bound method callback wrapper arity in `AioServer`).
  - Automatic `pkg-config` discovery for `liblo` include and library paths in `setup.py`.
  - Modernized Cython directives and type specifications.

## [4.1.1] - 2020-07-22

### Fixed
- Prevent egg installation errors by passing `zip_safe=False`.

## [4.1.0] - 2020-03-03

### Fixed
- Rectify `__hash__` issues across core objects.

## [4.0.0] - 2020-03-03

### Changed
- Use Python-based OSC address pattern matching rather than liblo's, supporting escaped special characters.

### Fixed
- Ensure `ThreadedServer.start()` waits for thread to be initialized.
- Fix bug where subscribers might not receive pending data.
- Fix bug where `loop.remove_reader()` was not being called on `AioServer.stop()`.
