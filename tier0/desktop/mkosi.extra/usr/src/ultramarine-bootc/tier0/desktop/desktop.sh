#!/bin/bash
set -xeuo pipefail
source /usr/src/ultramarine-bootc/base/common.sh

# TODO: Write a preset instead
# this is a hack, remind self to fix later -cappy


systemctl --global enable xdg-user-dirs.service || true
systemctl disable sssd-kcm.service sssd-kcm.socket || true
systemctl enable flatpak-add-flathub-repos.service

setfattr -n user.component -v "packagekit-config" /etc/PackageKit/PackageKit.conf

echo ntsync | tee /usr/lib/modules-load.d/ntsync.conf

dracut_rebuild