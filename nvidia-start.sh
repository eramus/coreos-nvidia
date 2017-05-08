#!/bin/sh

/opt/nvidia/bin/nvidia-insmod.sh nvidia.ko

# Start the first devices
/usr/bin/mknod -m 666 /dev/nvidiactl c 195 255 2>/dev/null
NVDEVS=`lspci | grep -i NVIDIA`
N3D=`echo "$NVDEVS" | grep "3D controller" | wc -l`
NVGA=`echo "$NVDEVS" | grep "VGA compatible controller" | wc -l`
N=`expr $N3D + $NVGA - 1`
for i in `seq 0 $N`; do
  mknod -m 666 /dev/nvidia$i c 195 $i
done
