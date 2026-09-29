#!/bin/bash -x
systemctl set-default graphical.target
systemctl enable livesys.service
systemctl enable livesys-late.service
systemctl enable tmp.mount
# make it so that we don't do writing to the overlay for things which
# are just tmpdirs/caches
# note https://bugzilla.redhat.com/show_bug.cgi?id=1135475
cat >> /etc/fstab << EOF
vartmp   /var/tmp    tmpfs   defaults   0  0
EOF

# Set the timezone explicitly to UTC
# so Plasma won't complain about it not being set
ln -sf /usr/share/zoneinfo/Etc/UTC /etc/localtime

# work around for poor key import UI in PackageKit
rm -f /var/lib/rpm/__db*

# go ahead and pre-make the man -k cache (#455968)
/usr/bin/mandb

# make sure there aren't core files lying around
rm -f /core*

# remove random seed, the newly installed instance should make it's own
rm -f /var/lib/systemd/random-seed

echo 'File created by ultramarine-bootc. See systemd-update-done.service(8).' |
    tee /etc/.updated >/var/.updated

# Drop the rescue kernel and initramfs, we don't need them on the live media itself.
# See bug 1317709
rm -f /boot/*-rescue*

systemctl disable network
systemctl disable systemd-networkd
systemctl disable systemd-networkd.socket
systemctl disable systemd-networkd-wait-online
systemctl disable openvpn-client@\*.service
systemctl disable openvpn-server@\*.service


# Remove machine-id on pre generated images
rm -f /etc/machine-id
touch /etc/machine-id

touch /.unconfigured
systemctl enable taidan-initial-setup-reconfiguration || true
systemctl enable systemd-timesyncd


# Set locales in chroot
cat >/etc/locale.conf <<EOF
LANG=en_US.UTF-8
LANGUAGE=en_US.UTF-8
LC_ALL=en_US.UTF-8
EOF



cat >>/var/lib/livesys/livesys-session-extra <<EOF
# Remove the initial setup configs, we actually don't need them for now
rm -rf /.unconfigured
systemctl disable initial-setup || true
systemctl disable taidan-initial-setup-reconfiguration || true

# Disable polycrystal, so it doesn't attempt to fill the ramdisk with Flatpaks
# on live images
systemctl disable --now polycrystal.service || true
EOF

# Delete the firefox redhat configs, debranding
rm -rf /usr/lib64/firefox/browser/defaults/preferences/firefox-redhat-default-prefs.js
