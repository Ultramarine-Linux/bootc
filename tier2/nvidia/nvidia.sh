#!/usr/bin/env bash

# HACK: Copied from 
# https://github.com/zirconium-dev/zirconium/blob/main/build_files/03-nvidia.sh

# TOOD: Probably use terra-nvidia repo instead

set -xeuo pipefail
source /usr/src/ultramarine-bootc/base/common.sh

export DRACUT_NO_XATTR=1
KERNEL_VERSION="$(find "/usr/lib/modules" -maxdepth 1 -type d ! -path "/usr/lib/modules" -exec basename '{}' ';' | sort | tail -n 1)"


# dnf config-manager addrepo --from-repofile=https://negativo17.org/repos/fedora-nvidia.repo

dnf -y install --enablerepo=terra-nvidia akmod-nvidia --exclude=nvidia-container-toolkit
mkdir -p /var/tmp # for akmods
chmod 1777 /var/tmp
# sed -i "s/^MODULE_VARIANT=.*/MODULE_VARIANT=kernel-open/" /etc/nvidia/kernel.conf
akmods --force --kernels "${KERNEL_VERSION}" --kmod "nvidia"
cat /var/cache/akmods/nvidia/*.failed.log || true

dnf -y install --enablerepo=terra-nvidia --exclude=nvidia-container-toolkit \
    nvidia-driver-cuda libnvidia-fbc libva-nvidia-driver nvidia-driver nvidia-modprobe nvidia-persistenced nvidia-settings

dnf -y install \
    nvidia-container-toolkit

curl --retry 3 -L https://raw.githubusercontent.com/NVIDIA/dgx-selinux/master/bin/RHEL9/nvidia-container.pp -o nvidia-container.pp
semodule -i nvidia-container.pp
rm -f nvidia-container.pp

tee /usr/lib/modprobe.d/00-nouveau-nova-blacklist.conf <<'EOF'
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
ConditionKernelCommandLine=!nomodeset
ConditionPathExists=/proc/driver/nvidia/version

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

# todo: refactor to dedicated file

dracut_rebuild
