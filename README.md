# Browsercore

## Build

### Prerequisites

Browsercore is written with [Zig](https://ziglang.org/) `0.12`. You have to
install it with the right version in order to build the project.

Browsercore also depends on
[js-runtimelib](https://github.com/francisbouvier/jsruntime-lib/),
[Netsurf libs](https://www.netsurf-browser.org/) and
[Mimalloc](https://microsoft.github.io/mimalloc) libs.

To be able to build the v8 engine for js-runtimelib, you have to install some libs:

For Debian/Ubuntu based Linux:
```
sudo apt install xz-utils \
    python3 ca-certificates git \
    pkg-config libglib2.0-dev \
    gperf libexpat1-dev \
    cmake clang
```

For MacOS, you only need Python 3 and cmake.

### Install and build dependencies

The project uses git submodule for dependencies.
The `make install-submodule` will init and update the submodules in the `vendor/`
directory.

```
make install-submodule
```

### Build Netsurf

The command `make install-netsurf` will build Netsurf libs used by browsercore.
```
make install-netsurf
```

For dev env, use `make install-netsurf-dev`.

### Build Mimalloc

The command `make install-mimalloc` will build Mimalloc lib used by browsercore.
```
make install-mimalloc
```

For dev env, use `make install-mimalloc-dev`.

Note, when Mimalloc is built in dev mode, you can dump memory stats with the
env var `MIMALLOC_SHOW_STATS=1`. See
https://microsoft.github.io/mimalloc/environment.html

### Build jsruntime-lib

The command `make install-jsruntime-dev` uses jsruntime-lib's `zig-v8` dependency to build v8 engine lib.
Be aware the build task is very long and cpu consuming.

Build v8 engine for debug/dev version, it creates
`vendor/jsruntime-lib/vendor/v8/$ARCH/debug/libc_v8.a` file.

```
make install-jsruntime-dev
```

You should also build a release vesion of v8 with:

```
make install-jsruntime
```

### All in one build

You can run `make intall` and `make install-dev` to install deps all in one.

## Test

### Unit Tests

You can test browsercore by running `make test`.

### Web Platform Tests

Browsercore is tested against the standardized [Web Platform
Tests](https://web-platform-tests.org/).

The relevant tests cases for Browsercore are commit with the project.
All the tests cases executed are located in `tests/wpt` dir and come from an
external repository: https://github.com/lightpanda-io/wpt

For reference, you can easily execute a WPT test case with your browser via
[wpt.live](https://wpt.live).

*Run WPT test suite*

You can run all the test.
The runner execute all the tests ending with `.html`.
```
make wpt
```

Or one specific test by using a suffix.
```
make wpt Node-childNodes.html
```

*Add a new WPT test case*

We add new tests cases files with implemented changes in Browsercore.

Copy the test case you want to add from the [WPT
repo](https://github.com/web-platform-tests/wpt) into `tests/wpt` dir, commit
the files in the https://github.com/lightpanda-io/wpt repository and update the
git submodule in browsercore.

:warning: Please keep the original directory tree structure into `tests/wpt`.
