#!/bin/bash
set -Eeu

# purpose: builds NIXL from source, gated by `BUILD_NIXL_FROM_SOURCE`
#
# Required environment variables:
# - BUILD_NIXL_FROM_SOURCE: if nixl should be installed by vLLM or has been built from source in the builder stages
# - NIXL_REPO: Git repo to use for NIXL
# - NIXL_VERSION: Git ref to use for NIXL
# - NIXL_PREFIX: Path to install NIXL to
# - EFA_PREFIX: Path to Libfabric installation
# - UCX_PREFIX: Path to UCX installation
# - VIRTUAL_ENV: Path to the virtual environment
# - USE_SCCACHE: whether to use sccache (true/false)
# - TARGETOS: OS type (ubuntu or rhel)

if [ "${BUILD_NIXL_FROM_SOURCE}" = "false" ]; then
    echo "NIXL will be installed be vLLM and not built from source."
    exit 0
fi

cd /tmp

. /usr/local/bin/setup-sccache
. "${VIRTUAL_ENV}/bin/activate"

git clone "${NIXL_REPO}" nixl && cd nixl
git checkout -q "${NIXL_VERSION}"

if [ "${USE_SCCACHE}" = "true" ]; then
    export CC="sccache gcc" CXX="sccache g++" NVCC="sccache nvcc"
fi

# DEBUG
ls -l /opt/amazon/efa/lib/libfabric.so /opt/amazon/efa/lib/libfabric.so.1.27.0 || true
file /opt/amazon/efa/lib/libfabric.so.1.27.0 || true   # must say aarch64/ARM64
g++ -x c++ - -o /tmp/t \
  -L/opt/amazon/efa/lib -lfabric \
  -Wl,-rpath,/opt/amazon/efa/lib <<<'int main(){return 0;}' || true

export PKG_CONFIG_PATH=/opt/amazon/efa/lib/pkgconfig:${PKG_CONFIG_PATH}
export LIBRARY_PATH=/opt/amazon/efa/lib:${LIBRARY_PATH}
export LD_LIBRARY_PATH=/opt/amazon/efa/lib:${LD_LIBRARY_PATH}

pkg-config --modversion libfabric || true
pkg-config --modversion hwloc || true
# END DEBUG

meson setup build \
    --prefix=${NIXL_PREFIX} \
    -Dbuildtype=release \
    -Ducx_path=${UCX_PREFIX} \
    -Dlibfabric_path=${EFA_PREFIX} \
    -Dinstall_headers=true

cd build
ninja
ninja install
cd ..
. ${VIRTUAL_ENV}/bin/activate
python -m build --no-isolation --wheel -o /wheels
rm -rf build

cd /tmp && rm -rf /tmp/nixl 

