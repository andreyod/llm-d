#!/bin/bash
set -Eeu

# purpose: Install EFA
# -------------------------------
# Required docker secret mounts:
# - /run/secrets/subman_org: Subscription Manager Organization - used if on a ubi based image for entitlement
# - /run/secrets/subman_activation_key: Subscription Manager Activation key - used if on a ubi based image for entitlement
# -------------------------------
# Required environment variables:
# - TARGETOS: Target OS - either 'ubuntu' or 'rhel' (default: rhel)
# - EFA_PREFIX: Path to include ld linkers to ensure that UCX and NVSHMEM can build against EFA and Libfacbric successfully

TARGETOS="${TARGETOS:-rhel}"

if [ "${TARGETOS}" = "ubuntu" ]; then
    echo "Temporary workaround - EFA does not support Ubuntu 20.04, and we have to use this in the builder image for Ubuntu for glibc compatiblility."
    echo "See https://github.com/vllm-project/vllm/blob/v0.11.0/docker/Dockerfile#L18-L24 and"
    echo "https://docs.aws.amazon.com/AWSEC2/latest/UserGuide/efa.html#efa-os for more information."
    # create empty directory so copy doesn't fail
    mkdir -p /opt/amazon/efa
    exit 0
fi

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# source shared utilities (check script dir first, fallback to /tmp for docker builds)
UTILS_SCRIPT="${SCRIPT_DIR}/../common/package-utils.sh"
[ ! -f "$UTILS_SCRIPT" ] && UTILS_SCRIPT="/tmp/package-utils.sh"
if [ ! -f "$UTILS_SCRIPT" ]; then
    echo "ERROR: package-utils.sh not found" >&2
    exit 1
fi
. "$UTILS_SCRIPT"

if [ "${TARGETOS}" = "rhel" ]; then
    ensure_registered
fi

mkdir -p /tmp/efa
cd /tmp/efa
curl -O https://efa-installer.amazonaws.com/aws-efa-installer-1.43.3.tar.gz
tar -xf aws-efa-installer-1.43.3.tar.gz && cd aws-efa-installer
# ./efa_installer.sh --skip-kmod --skip-plugin --skip-limit-conf -d --no-verify -y
./efa_installer.sh --skip-plugin --skip-limit-conf -d --no-verify -y
mkdir -p /etc/ld.so.conf.d/
ldconfig
cd /tmp
rm -rf /tmp/efa

# - TARGETOS: Target OS - either 'ubuntu' or 'rhel' (default: rhel)

if [ "$TARGETOS" = "ubuntu" ]; then
    cleanup_packages ubuntu
elif [ "$TARGETOS" = "rhel" ]; then
    cleanup_packages rhel
    ensure_unregistered
else
    echo "ERROR: Unsupported TARGETOS='$TARGETOS'. Must be 'ubuntu' or 'rhel'." >&2
    exit 1
fi

echo "${EFA_PREFIX}/lib64" >  /etc/ld.so.conf.d/efa.conf && \
echo "${EFA_PREFIX}/lib"   >> /etc/ld.so.conf.d/efa.conf && ldconfig
