#!/bin/bash
set -xeuo pipefail
source /usr/src/ultramarine-bootc/base/common.sh

# TODO: Write a preset instead
# this is a hack, remind self to fix later -cappy


systemctl --global enable xdg-user-dirs.service || true
systemctl disable sssd-kcm.service sssd-kcm.socket || true
systemctl enable flatpak-add-flathub-repos.service

# edit /etc/PacageKit/PackageKit.conf to use bootc backend
sed -i 's/#DefaultBackend=.*/DefaultBackend=bootc/' /etc/PackageKit/PackageKit.conf

setfattr -n user.component -v "packagekit-config" /etc/PackageKit/PackageKit.conf

# Remove DNF backend from PackageKit for good measure, this will be re-installed on `standard`
rm -f /usr/lib64/packagekit-backend/libpk_backend_dnf.so

echo ntsync | tee /usr/lib/modules-load.d/ntsync.conf

dracut_rebuild