#!/bin/bash -x
: ${QEMU_MEM:="4G"}
: ${QEMU_CPU:="4"}

: ${ARCH:="x86_64"}

qemu-system-"$ARCH" \
    -M accel=kvm \
    -cpu host \
    -smp "$QEMU_CPU" \
    -m "$QEMU_MEM" \
    -bios /usr/share/OVMF/OVMF_CODE.fd \
    -serial stdio \
    -drive file=output/qcow2/disk.qcow2,format=qcow2,if=virtio