#!/bin/bash -x
set -euo pipefail

# Hack from https://gist.github.com/jlebon/fb6e7c6dcc3ce17d3e2a86f5938ec033

cleanup() {
    chmod u-s /mnt/mock-mount/usr/bin/bwrap
    for mnt in sys proc dev/pts dev; do
        umount /mnt/mock-mount/$mnt
    done
    umount /mnt/mock-mount
    umount /mnt/mock-mount
    # HACK: /github is created for some reason when katsu is run in GitHub Actions
    # I'm not sure why, I think it has to do with the default github user used, and flatpak creating the xdg dirs
    rm -rf /mnt/mock-mount /run/mount /github
}

if [ -x "$(command -v polycrystal)" ]; then
    trap cleanup EXIT
    mkdir -p /mnt/mock-mount
    mount --bind / /mnt/mock-mount
    mount --make-private /mnt/mock-mount
    mount --bind /mnt/mock-mount /mnt/mock-mount
    for mnt in proc sys dev dev/pts; do
        mount --bind /$mnt /mnt/mock-mount/$mnt
    done

    # For some reason, our hack to get bwrap to work in a chroot also breaks user namespaces
    # I can't figure out why, so we'll just setuid bwrap for now
    # YOU MUST REMOVE THE SETUID BIT AFTER RUNNING THIS SCRIPT WHICH WE DO IN THE CLEANUP FUNCTION AND HERE
    chmod u+s /mnt/mock-mount/usr/bin/bwrap
    chroot /mnt/mock-mount bash -c 'polycrystal'
    chmod u-s /mnt/mock-mount/usr/bin/bwrap
fi
