#!/bin/bash

if [[ $(uname -r) != *"-coreos"* ]]; then
    echo "OS is not CoreOS"
    exit 1
fi

COREOS_TRACK_DEFAULT=stable
COREOS_VERSION_DEFAULT=1353.7.0
# If we are on CoreOS by default use the current CoreOS version
if [[ -f /etc/lsb-release && -f /etc/coreos/update.conf ]]; then
    source /etc/lsb-release
    source /etc/coreos/update.conf

    COREOS_TRACK_DEFAULT=$GROUP
    COREOS_VERSION_DEFAULT=$DISTRIB_RELEASE
    if [[ $DISTRIB_ID != *"CoreOS"* ]]; then
        echo "Distribution is not CoreOS"
        exit 1
    fi
fi

DRIVER_VERSION=${1:-375.66}
COREOS_TRACK=${2:-$COREOS_TRACK_DEFAULT}
COREOS_VERSION=${3:-$COREOS_VERSION_DEFAULT}

# this is where the modules go
release=$(uname -r)

mkdir -p /opt/nvidia/lib64 2>/dev/null
mkdir -p /opt/nvidia/bin 2>/dev/null
ln -sfT lib64 /opt/nvidia/lib 2>/dev/null
mkdir -p /opt/nvidia/lib64/modules/$release/video/

tar xvf libraries-$DRIVER_VERSION.tar.bz2 -C /opt/nvidia/lib64/
tar xvf modules-$COREOS_VERSION-$DRIVER_VERSION.tar.bz2 -C /opt/nvidia/lib64/modules/$release/video/
tar xvf tools-$DRIVER_VERSION.tar.bz2 -C /opt/nvidia/bin/

install -m 755 create-uvm-dev-node.sh /opt/nvidia/bin/
install -m 755 nvidia-start.sh /opt/nvidia/bin/
install -m 755 nvidia-insmod.sh /opt/nvidia/bin/
cp -f 71-nvidia.rules /etc/udev/rules.d/
udevadm control --reload-rules

mkdir -p /etc/ld.so.conf.d/ 2>/dev/null
echo "/opt/nvidia/lib64" > /etc/ld.so.conf.d/nvidia.conf
ldconfig

echo "Configuring nvidia persistence user"
id -u nvidia-persistenced >/dev/null 2>&1 || \
useradd --system --home '/' --shell '/sbin/nologin' -c 'NVIDIA Persistence Daemon' nvidia-persistenced

cp *.service /etc/systemd/system/
systemctl daemon-reload
systemctl enable nvidia-start.service
systemctl start nvidia-start.service
