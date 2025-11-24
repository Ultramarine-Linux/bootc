#!/bin/bash -x
# Set up initial setup, might be redundant idk

# Note from Cappy:
# This script may fail if the system is not properly configured, we need to ensure that packages are installed and configured correctly.

assert_svc() {
    local svc=$1
    if systemctl is-enabled $svc >/dev/null 2>&1; then
        echo "$svc is properly enabled"
    else
        echo "$svc is not enabled"
    fi
}

enable_svc() {
    local pkg=$1
    local svc=$2
    systemctl enable -f $svc || echo "WARNING: Failed to enable $svc: $?"
}

echo "==== Initial Setup ===="
setup_found=false

# Check for taidan package
if rpm -q taidan >/dev/null 2>&1; then
    echo "Enabling taidan Initial Setup"
    enable_svc "taidan" "taidan-initial-setup-reconfiguration"
    touch /.unconfigured
    setup_found=true
# Handle gnome-initial-setup as the second check
elif rpm -q gnome-initial-setup >/dev/null 2>&1; then
    mkdir -p /var/lib/gdm
    echo "Creating initial setup file for GNOME"
    touch /var/lib/gdm/run-initial-setup
    sed '/[daemon]/a InitialSetupEnable=True' /etc/gdm/custom.conf
    setup_found=true
# Check for kiss package
elif rpm -q kiss >/dev/null 2>&1; then
    echo "Enabling kiss Initial Setup"
    enable_svc "kiss" "org.kde.initialsystemsetup.service"
    setup_found=true
# Check for initial-setup-gui package
elif rpm -q initial-setup-gui >/dev/null 2>&1; then
    echo "Enabling initial-setup-gui Initial Setup"
    enable_svc "initial-setup-gui" "initial-setup"
    setup_found=true
fi

if [ "$setup_found" = false ]; then
    echo "WARNING: No initial setup module found!? Please check the system configuration."
fi

# Set default target to graphical
systemctl set-default graphical.target

# Verify that services are actually enabled based on installed packages
echo "==== Verifying Initial Setup Services ===="
found_pkg_svc=false

# Verify taidan package
if rpm -q taidan >/dev/null 2>&1; then
    assert_svc "taidan-initial-setup-reconfiguration"
    if ! systemctl is-enabled "taidan-initial-setup-reconfiguration" >/dev/null 2>&1; then
        echo "ERROR: taidan Initial Setup is not enabled"
        exit 1
    fi
    if [ -f /.unconfigured ]; then
        echo "/.unconfigured file exists, taidan will run on next boot"
    else
        echo "ERROR: /.unconfigured file not created properly"
        exit 1
    fi
    found_pkg_svc=true
# Verify GNOME Initial Setup (special case)
elif rpm -q gnome-initial-setup >/dev/null 2>&1; then
    if [ -f /var/lib/gdm/run-initial-setup ]; then
        echo "GNOME Initial Setup is properly configured"
        found_pkg_svc=true
    else
        echo "ERROR: GNOME Initial Setup file not created properly"
        exit 1
    fi
# Verify kiss package
elif rpm -q kiss >/dev/null 2>&1; then
    assert_svc "org.kde.initialsystemsetup.service"
    if ! systemctl is-enabled "org.kde.initialsystemsetup.service" >/dev/null 2>&1; then
        echo "ERROR: kiss Initial Setup is not enabled"
        exit 1
    fi
    found_pkg_svc=true
# Verify initial-setup-gui package
elif rpm -q initial-setup-gui >/dev/null 2>&1; then
    assert_svc "initial-setup"
    if ! systemctl is-enabled "initial-setup" >/dev/null 2>&1; then
        echo "ERROR: initial-setup-gui Initial Setup is not enabled"
        exit 1
    fi
    found_pkg_svc=true
fi

if [ "$setup_found" = false ] && [ "$found_pkg_svc" = false ]; then
    echo "WARNING: No initial setup package was found, skipping verification"
fi