#!/usr/bin/env bash
# SPDX-License-Identifier: Apache-2.0
#
# Materialise a container image into a directory for use as an mkosi
# BaseTrees= source, printing its path on stdout.
#
# Usage: mkosi-basetree.sh [--copy] <image-ref> [dest]
#
# Mounting rather than exporting because `podman export` drops user.* xattrs,
# and the base image marks /usr/lib/ostree-boot and the initramfs with
# user.component. Mounting needs no extra setup when rootful (as CI runs); when
# rootless we re-exec under `podman unshare`, which means the printed path is
# only valid inside that namespace -- use --copy to get a path that is not.
#
# With a dest argument the tree is copied there, replacing anything already
# there, and dest must not be "/" or a prefix of "/".

set -euo pipefail

MODE=mount
IMAGE=""
DEST=""

for arg in "$@"; do
    case "$arg" in
        --copy) MODE=copy ;;
        -h|--help)
            sed -n '2,20p' "$0" | sed 's/^# \{0,1\}//'
            exit 0
            ;;
        -*)
            echo "mkosi-basetree.sh: unknown option '$arg'" >&2
            exit 2
            ;;
        *)
            if [ -z "$IMAGE" ]; then
                IMAGE="$arg"
            elif [ -z "$DEST" ]; then
                DEST="$arg"
                MODE=copy
            else
                echo "mkosi-basetree.sh: expected at most <image-ref> [dest]" >&2
                exit 2
            fi
            ;;
    esac
done

if [ -z "$IMAGE" ]; then
    echo "mkosi-basetree.sh: missing <image-ref>" >&2
    exit 2
fi

# `podman image mount` fails outright in a rootless session unless the caller is
# inside the podman user namespace, so re-exec ourselves under `unshare` there.
# Rootful invocations (CI) are left alone.
if [ "$(id -u)" -ne 0 ] && [ "${MKOSI_BASETREE_UNSHARED:-}" != "1" ]; then
    exec podman unshare env MKOSI_BASETREE_UNSHARED=1 "$0" ${1+"$@"}
fi

cleanup() {
    if [ -n "${MOUNTPOINT:-}" ]; then
        podman image umount "$IMAGE" >/dev/null 2>&1 || true
    fi
    if [ -n "${COPYDIR:-}" ] && [ -z "$DEST" ]; then
        rm -rf "$COPYDIR"
    fi
}
trap cleanup EXIT

# Skip the pull when we already have the image: a `localhost/...` reference has
# no registry to talk to.
if ! podman image exists "$IMAGE"; then
    podman pull --quiet "$IMAGE" >/dev/null
fi

MOUNTPOINT=$(podman image mount "$IMAGE")
if [ -z "$MOUNTPOINT" ] || [ ! -d "$MOUNTPOINT" ]; then
    echo "mkosi-basetree.sh: failed to mount $IMAGE" >&2
    exit 1
fi

if [ "$MODE" != "copy" ]; then
    trap - EXIT
    printf '%s\n' "$MOUNTPOINT"
    exit 0
fi

# Copy out so the path stays valid outside this mount namespace.
if [ -n "$DEST" ]; then
    case "$DEST" in
        /|/usr|/var|/etc|/boot|/lib|/bin|/sbin)
            echo "mkosi-basetree.sh: refusing to use '$DEST' as a destination" >&2
            exit 2
            ;;
    esac
    rm -rf "$DEST"
    mkdir -p "$DEST"
    cp -a --reflink=auto "$MOUNTPOINT/." "$DEST/"
    podman image umount "$IMAGE" >/dev/null 2>&1 || true
    trap - EXIT
    printf '%s\n' "$DEST"
else
    COPYDIR=$(mktemp -d "${TMPDIR:-/tmp}/mkosi-basetree.XXXXXXXX")
    cp -a --reflink=auto "$MOUNTPOINT/." "$COPYDIR/"
    podman image umount "$IMAGE" >/dev/null 2>&1 || true
    MOUNTPOINT=""
    trap - EXIT
    printf '%s\n' "$COPYDIR"
fi
