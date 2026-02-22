#!/bin/bash
# Common shell functions for use in other scripts

# Usage: source /usr/src/ultramarine-bootc/base/common.sh

get_kernel_version() {
    KERNEL_VERSION="$(find "/usr/lib/modules" -maxdepth 1 -type d ! -path "/usr/lib/modules" -exec basename '{}' ';' | sort | tail -n 1)"
    echo "$KERNEL_VERSION"
}

dracut_rebuild() {
    KERNEL_VERSION="$(get_kernel_version)"
    export DRACUT_NO_XATTR=1
    echo "Rebuilding initramfs for kernel version: $KERNEL_VERSION"
    dracut --no-hostonly --kver "$KERNEL_VERSION" --reproducible --zstd -v --add ostree -f "/usr/lib/modules/$KERNEL_VERSION/initramfs.img"
    chmod 0600 "/usr/lib/modules/${KERNEL_VERSION}/initramfs.img"

    setfattr -n user.component -v "initramfs" "/usr/lib/modules/${KERNEL_VERSION}/initramfs.img"
}