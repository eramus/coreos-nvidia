#!/bin/sh

set -e

ARTIFACT_DIR=$1
VERSION=$2
COMBINED_VERSION=$3

TOOLS="nvidia-debugdump nvidia-cuda-mps-control nvidia-xconfig nvidia-modprobe nvidia-smi nvidia-cuda-mps-server
nvidia-persistenced nvidia-settings"

# Create archives with no paths
tar -C ${ARTIFACT_DIR} -cvj $(basename -a ${ARTIFACT_DIR}/*.so.*) > libraries-${VERSION}.tar.bz2
tar -C ${ARTIFACT_DIR}/tls -cvj $(basename -a ${ARTIFACT_DIR}/tls/*.so.*) > libraries-tls-${VERSION}.tar.bz2
tar -C ${ARTIFACT_DIR} -cvj ${TOOLS} > tools-${VERSION}.tar.bz2
tar -C ${ARTIFACT_DIR}/kernel -cvj $(basename -a ${ARTIFACT_DIR}/kernel/*.ko) > modules-${COMBINED_VERSION}.tar.bz2

ASSETS="71-nvidia.rules create-uvm-dev-node.sh libraries-${VERSION}.tar.bz2 libraries-tls-${VERSION}.tar.bz2
modules-${COMBINED_VERSION}.tar.bz2 nvidia-docker.service nvidia-insmod.sh nvidia-persistenced.service
nvidia-start.service nvidia-start.sh nvidia_install.sh tools-${VERSION}.tar.bz2"

# Create full archive
echo "made it here"
tar -C ${ARTIFACT_DIR} -cvj ${ASSETS} > coreos-nvidia-${COMBINED_VERSION}.tar.bz2
echo "tar -C ${ARTIFACT_DIR} -cvj ${ASSETS} > coreos-nvidia-${COMBINED_VERSION}.tar.bz2"

# Clean-up
#rm libraries-${VERSION}.tar.bz2 libraries-tls-${VERSION}.tar.bz2 tools-${VERSION}.tar.bz2 modules-${COMBINED_VERSION}.tar.bz2
