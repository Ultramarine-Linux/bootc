#!/usr/bin/env bash
# SPDX-License-Identifier: Apache-2.0
#
# Materialise a container image into a directory that can be used as an
# mkosi `BaseTrees=` source.
#
# Usage:
#   mkosi-basetree.sh [--copy] <image-ref>
#
# Prints the absolute path of a directory containing the image root filesystem
# on stdout. Nothing else is written to stdout so the output can be captured
# directly:
#
#   BaseTrees=$(scripts/mkosi-basetree.sh ghcr.io/ultramarine-linux/base-bootc:44)
#
# Why `podman image mount` and not `podman export`?
#   `podman export` produces a flat tar that silently drops `user.*` extended
#   attributes. bootc uses `user.component` markers to record which parts of an
#   image came from which component -- base/mkosi.postinst.chroot sets them on
#   /usr/lib/ostree-boot and on the initramfs, and the tier payloads set them on
#   their own files. Dropping them changes the image we ship, so the base tree
#   has to come from a real mount, which preserves xattrs.
#
#   `podman image mount` only exposes the mount inside the caller's mount
#   namespace. Rootful (how CI runs, via `sudo`) needs nothing extra. Rootless
#   needs `podman unshare`, which this script applies automatically -- but note
#   that a path printed from inside `podman unshare` is only valid for callers
#   that are themselves inside that namespace. Use --copy to sidestep this.

set -euo pipefail

MODE=mount
IMAGE=""

for arg in "$@"; do
    case "$arg" in
        --copy) MODE=copy ;;
        -h|--help)
            sed -n '2,25p' "$0" | sed 's/^# \{0,1\}//'
            exit 0
            ;;
        -*)
            echo "mkosi-basetree.sh: unknown option '$arg'" >&2
            exit 2
            ;;
        *)
            if [ -n "$IMAGE" ]; then
                echo "mkosi-basetree.sh: expected exactly one image reference" >&2
                exit 2
            fi
            IMAGE="$arg"
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
    if [ -n "${COPYDIR:-}" ]; then
        rm -rf "$COPYDIR"
    fi
}
trap cleanup EXIT

# Only reach for the network when the reference is not already in local storage.
# CI hands us a remote digest reference, local development usually already has
# the image pulled, and pulling a `localhost/...` reference would try (and fail)
# to talk to a registry that does not exist.
if ! podman image exists "$IMAGE"; then
    podman pull --quiet "$IMAGE" >/dev/null
fi

MOUNTPOINT=$(podman image mount "$IMAGE")
if [ -z "$MOUNTPOINT" ] || [ ! -d "$MOUNTPOINT" ]; then
    echo "mkosi-basetree.sh: failed to mount $IMAGE" >&2
    exit 1
fi

if [ "$MODE" = "copy" ]; then
    # Snapshot the mount out into an ordinary directory so the path stays valid
    # outside this mount namespace. -a keeps xattrs/ACLs; --reflink=auto avoids
    # the copy entirely on btrfs/xfs.
    COPYDIR=$(mktemp -d "${TMPDIR:-/tmp}/mkosi-basetree.XXXXXXXX")
    cp -a --reflink=auto "$MOUNTPOINT/." "$COPYDIR/"
    podman image umount "$IMAGE" >/dev/null 2>&1 || true
    MOUNTPOINT=""
    # The caller owns the copy now, so stop the trap from deleting it.
    trap - EXIT
    printf '%s\n' "$COPYDIR"
else
    # Trap only the mount; the caller owns the directory from here on.
    trap - EXIT
    printf '%s\n' "$MOUNTPOINT"
fi
