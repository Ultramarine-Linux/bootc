#!/usr/bin/env bash

set -xeuo pipefail

dnf config-manager setopt keepcache=1
trap 'dnf config-manager setopt keepcache=0' EXIT

dnf -y install gcc-c++

dnf install -y --enablerepo=terra terra-release-nvidia
dnf config-manager setopt terra-nvidia.enabled=0
dnf -y install --enablerepo=terra-nvidia akmod-nvidia
dnf -y install --enablerepo=terra-nvidia --enablerepo=terra \
    nvidia-driver-cuda libnvidia-fbc libva-nvidia-driver nvidia-driver nvidia-modprobe nvidia-persistenced nvidia-settings

dnf config-manager setopt terra-nvidia.enabled=0
sed -i '/^enabled=/a\priority=90' /etc/yum.repos.d/terra-nvidia.repo
dnf -y install --enablerepo=terra-nvidia \
    nvidia-container-toolkit

curl --retry 3 -L "https://raw.githubusercontent.com/NVIDIA/dgx-selinux/master/bin/RHEL9/nvidia-container.pp" -o nvidia-container.pp
semodule -i nvidia-container.pp
rm -f nvidia-container.pp

KERNEL_VERSION="$(find "/usr/lib/modules" -maxdepth 1 -type d ! -path "/usr/lib/modules" -exec basename '{}' ';' | sort | tail -n 1)"

mkdir -p /var/tmp # for akmods
mkdir -p /var/log/akmods
mkdir -p /run/akmods
chmod 1777 /var/tmp
akmods --force --kernels "${KERNEL_VERSION}" --kmod "nvidia"
find /usr/lib/modules -iname "nvidia*.ko*"
stat "/usr/lib/modules/${KERNEL_VERSION}"/extra/nvidia/nvidia*.ko* # We actually need the kernel objects after build LOL

tee /usr/lib/modprobe.d/00-nouveau-blacklist.conf <<'EOF'
blacklist nouveau
blacklist nova-core
options nouveau modeset=0
EOF

tee /usr/lib/bootc/kargs.d/00-nvidia.toml <<'EOF'
kargs = ["rd.driver.blacklist=nouveau", "modprobe.blacklist=nouveau", "nvidia-drm.modeset=1"]
EOF

# Universal Blue specific Initramfs fixes
mv /etc/modprobe.d/nvidia-modeset.conf /usr/lib/modprobe.d/nvidia-modeset.conf
# we must force driver load to fix black screen on boot for nvidia desktops
sed -i 's/omit_drivers/force_drivers/g' /usr/lib/dracut/dracut.conf.d/99-nvidia.conf
# as we need forced load, also must pre-load intel/amd iGPU else chromium web browsers fail to use hardware acceleration
sed -i 's/ nvidia / i915 amdgpu nvidia /g' /usr/lib/dracut/dracut.conf.d/99-nvidia.conf

tee /usr/lib/systemd/system/nvctk-cdi.service <<'EOF'
[Unit]
Description=nvidia container toolkit CDI auto-generation
ConditionFileIsExecutable=/usr/bin/nvidia-ctk
After=local-fs.target

[Service]
Type=oneshot
ExecStart=/usr/bin/nvidia-ctk cdi generate --output=/etc/cdi/nvidia.yaml

[Install]
WantedBy=multi-user.target
EOF

systemctl enable nvctk-cdi.service
systemctl disable akmods-keygen@akmods-keygen.service
systemctl mask akmods-keygen@akmods-keygen.service
systemctl disable akmods-keygen.target
systemctl mask akmods-keygen.target

source /usr/src/ultramarine-bootc/base/common.sh
dracut_rebuild
