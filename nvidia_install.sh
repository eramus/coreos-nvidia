#!/bin/bash

if [[ $(uname -r) != *"-coreos"* ]]; then
    echo "OS is not CoreOS"
    exit 1
fi

WITH_DOCKER=true
while :; do
    case $1 in
        --without-docker)
            WITH_DOCKER=false
            ;;
        -?*)
            echo Unknown flag $1
            exit 1
            ;;
        *)
            break
    esac
    shift
done

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

DRIVER_VERSION=${1:-381.22}
COREOS_TRACK=${2:-$COREOS_TRACK_DEFAULT}
COREOS_VERSION=${3:-$COREOS_VERSION_DEFAULT}
NVIDIA_DOCKER_VERSION=${4:-1.0.1}

# this is where the modules go
release=$(uname -r)

mkdir -p /opt/bin
rm /opt/bin/nvidia-*

if [ $WITH_DOCKER ]; then
    mkdir -p /opt/nvidia/$DRIVER_VERSION/lib64/tls 2>/dev/null
else
    mkdir -p /opt/nvidia/$DRIVER_VERSION/lib64 2>/dev/null
fi

mkdir -p /opt/nvidia/$DRIVER_VERSION/bin 2>/dev/null
mkdir -p /opt/nvidia/$DRIVER_VERSION/lib64/modules/$release/video/

ln -sfT lib64 /opt/nvidia/$DRIVER_VERSION/lib 2>/dev/null

tar xvf libraries-$DRIVER_VERSION.tar.bz2 -C /opt/nvidia/$DRIVER_VERSION/lib64/
tar xvf modules-$COREOS_VERSION-$DRIVER_VERSION.tar.bz2 -C /opt/nvidia/$DRIVER_VERSION/lib64/modules/$release/video/
tar xvf tools-$DRIVER_VERSION.tar.bz2 -C /opt/nvidia/$DRIVER_VERSION/bin/

if [ $WITH_DOCKER ]; then
    tar xvf libraries-tls-$DRIVER_VERSION.tar.bz2 -C /opt/nvidia/$DRIVER_VERSION/lib64/tls/
fi

install -m 755 create-uvm-dev-node.sh /opt/nvidia/$DRIVER_VERSION/bin/
install -m 755 nvidia-start.sh /opt/nvidia/$DRIVER_VERSION/bin/
install -m 755 nvidia-insmod.sh /opt/nvidia/$DRIVER_VERSION/bin/
ln -sfT $DRIVER_VERSION /opt/nvidia/current 2>/dev/null
for f in $(ls -d /opt/nvidia/current/bin/nvidia-*); do ln -sf $f /opt/bin/; done

if [ $WITH_DOCKER ]; then
    mkdir -p /opt/nvidia-docker/$NVIDIA_DOCKER_VERSION/bin 2>/dev/null
    wget -P /tmp https://github.com/NVIDIA/nvidia-docker/releases/download/v${NVIDIA_DOCKER_VERSION}/nvidia-docker_${NVIDIA_DOCKER_VERSION}_amd64.tar.xz
    tar --strip-components=1 -C /opt/nvidia-docker/$NVIDIA_DOCKER_VERSION/bin -xvf /tmp/nvidia-docker*.tar.xz && rm /tmp/nvidia-docker*.tar.xz
    echo "Setting up permissions"
    chown root:root /opt/nvidia-docker/$NVIDIA_DOCKER_VERSION/bin/nvidia-docker*
    setcap cap_fowner+pe /opt/nvidia-docker/$NVIDIA_DOCKER_VERSION/bin/nvidia-docker-plugin
    ln -sfT $NVIDIA_DOCKER_VERSION /opt/nvidia-docker/current 2>/dev/null
    for f in $(ls -d /opt/nvidia-docker/current/bin/nvidia-*); do ln -sf $f /opt/bin/; done
fi

cp -f 71-nvidia.rules /etc/udev/rules.d/
udevadm control --reload-rules

mkdir -p /etc/ld.so.conf.d/ 2>/dev/null
echo "/opt/nvidia/current/lib64" > /etc/ld.so.conf.d/nvidia.conf
ldconfig

echo "Configuring nvidia persistence user"
id -u nvidia-persistenced >/dev/null 2>&1 || \
useradd --system --home '/' --shell '/sbin/nologin' -c 'NVIDIA Persistence Daemon' nvidia-persistenced

if [ $WITH_DOCKER ]; then
    echo "Configuring nvidia user"
    id -u nvidia-docker >/dev/null 2>&1 || \
    useradd -r -M -d /var/lib/nvidia-docker -s /usr/sbin/nologin -c "NVIDIA Docker plugin" nvidia-docker
    mkdir -p /var/lib/nvidia-docker 2>/dev/null
    chown nvidia-docker: /var/lib/nvidia-docker
fi

cp nvidia-persistenced.service /etc/systemd/system/
cp nvidia-start.service /etc/systemd/system/

if [ $WITH_DOCKER ]; then
    cp nvidia-docker.service /etc/systemd/system/
fi

systemctl daemon-reload
systemctl enable nvidia-start.service
systemctl start nvidia-start.service

if [ $WITH_DOCKER ]; then
    systemctl enable nvidia-docker.service
    systemctl start nvidia-docker.service
fi
