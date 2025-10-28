#!/bin/bash
set -Eeu

# purpose: install cmake 3.19.3 as a workaround for building nvshmem from source
#
# Required environment variables:
# - CMAKE_VERSION

ARCH="$(uname -m)"
case "$ARCH" in
    x86_64)  CMAKE_ARCH=Linux-x86_64 ;;
    aarch64) CMAKE_ARCH=Linux-aarch64 ;;
    *) echo "Unsupported arch: $ARCH" >&2; exit 1 ;;
esac

# Install to /usr/local without prompts
curl -fsSL "https://github.com/Kitware/CMake/releases/download/v${CMAKE_VERSION}/cmake-${CMAKE_VERSION}-${CMAKE_ARCH}.sh" \
-o /tmp/cmake.sh
chmod +x /tmp/cmake.sh
/tmp/cmake.sh --skip-license --prefix=/usr/local --exclude-subdir
