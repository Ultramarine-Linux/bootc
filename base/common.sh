#!/bin/bash
# Common shell functions for use in other desktop scripts

# Usage: source /usr/src/ultramarine-bootc/base/common.sh

dracut_rebuild() {
    KERNEL_VERSION="$(find "/usr/lib/modules" -maxdepth 1 -type d ! -path "/usr/lib/modules" -exec basename '{}' ';' | sort | tail -n 1)"
    export DRACUT_NO_XATTR=1
    echo "Rebuilding initramfs for kernel version: $KERNEL_VERSION"
    dracut --no-hostonly --kver "$KERNEL_VERSION" --reproducible --zstd -v --add ostree -f "/usr/lib/modules/$KERNEL_VERSION/initramfs.img"
    chmod 0600 "/usr/lib/modules/${KERNEL_VERSION}/initramfs.img"
}