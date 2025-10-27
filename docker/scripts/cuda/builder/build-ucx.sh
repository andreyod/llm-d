#!/bin/bash
set -Eeu

# purpose: builds and installs UCX from source
# --------------------------------------------
# Optional docker secret mounts:
# - /run/secrets/aws_access_key_id: AWS access key ID for role that can only interact with SCCache S3 Bucket
# - /run/secrets/aws_secret_access_key: AWS secret access key for role that can only interact with SCCache S3 Bucket
# --------------------------------------------
# Required environment variables:
# - TARGETOS: OS type (ubuntu or rhel)
# - UCX_REPO: git remote to build UCX from
# - UCX_VERSION: git ref to build UCX from
# - UCX_PREFIX: prefix dir that contains installation path
# - USE_SCCACHE: whether to use sccache (true/false)

cd /tmp

. /usr/local/bin/setup-sccache

git clone "${UCX_REPO}" ucx && cd ucx
git checkout -q "${UCX_VERSION}" 

if [ "${USE_SCCACHE}" = "true" ]; then
    export CC="sccache gcc" CXX="sccache g++" 
fi

# Temporary workaround - EFA does not support Ubuntu 20.04, and we have to use this in the builder image for Ubuntu for glibc compatiblility.
# See: https://github.com/vllm-project/vllm/blob/v0.11.0/docker/Dockerfile#L18-L24 and
# https://docs.aws.amazon.com/AWSEC2/latest/UserGuide/efa.html#efa-os for more information.
if [ "$TARGETOS" = "ubuntu" ]; then
    # EFA_SUPPORT_FLAG=""
    EFA_SUPPORT_FLAG="--with-efa"
elif [ "$TARGETOS" = "rhel" ]; then
    EFA_SUPPORT_FLAG="--with-efa"
else
    echo "ERROR: Unsupported TARGETOS='$TARGETOS'. Must be 'ubuntu' or 'rhel'." >&2
    exit 1
fi

./autogen.sh 
./contrib/configure-release \
    --prefix="${UCX_PREFIX}" \
    --libdir="${UCX_PREFIX}/lib" \
    "${EFA_SUPPORT_FLAG}" \
    --enable-shared \
    --disable-static \
    --disable-doxygen-doc \
    --enable-cma \
    --enable-devel-headers \
    --with-cuda=/usr/local/cuda \
    --with-verbs \
    --with-dm \
    --with-gdrcopy=/usr/local \
    --enable-mt

make -j$(nproc) 
make install-strip 
ldconfig 

cd /tmp && rm -rf /tmp/ucx 

if [ "${USE_SCCACHE}" = "true" ]; then
    echo "=== UCX build complete - sccache stats ==="
    sccache --show-stats
fi

echo "${UCX_PREFIX}/lib" > /etc/ld.so.conf.d/ucx.conf && ldconfig
