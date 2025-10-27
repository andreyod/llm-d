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

# ln -s /usr/local/cuda/lib64/stubs/libcuda.so /usr/lib64/ && \

git clone "${NIXL_REPO}" nixl && cd nixl
git checkout -q "${NIXL_VERSION}"

if [ "${USE_SCCACHE}" = "true" ]; then
    export CC="sccache gcc" CXX="sccache g++" NVCC="sccache nvcc"
fi

# EFA_LIBDIR=""
# if [ -d "${EFA_PREFIX}/lib64" ]; then
#   EFA_LIBDIR="${EFA_PREFIX}/lib64"
# elif [ -d "${EFA_PREFIX}/lib" ]; then
#   EFA_LIBDIR="${EFA_PREFIX}/lib"
# fi

# pass flag explicitly if targeting rhel
LIBFABRIC_PATH_FLAG=""
# if [ "${TARGETOS}" = "rhel" ] && [ -n "${EFA_LIBDIR}" ]; then
#     LIBFABRIC_PATH_FLAG="-Dlibfabric_path=${EFA_LIBDIR}"
# fi

meson setup build \
    --prefix=${NIXL_PREFIX} \
    -Dbuildtype=release \
    -Ducx_path=${UCX_PREFIX} \
    ${LIBFABRIC_PATH_FLAG} \
    -Dinstall_headers=true

cd build
ninja
ninja install
cd ..
. ${VIRTUAL_ENV}/bin/activate
python -m build --no-isolation --wheel -o /wheels
rm -rf build

cd /tmp && rm -rf /tmp/nixl 

