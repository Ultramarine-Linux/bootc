#!/bin/bash -x

echo max_parallel_downloads=20 >> /etc/dnf/dnf.conf
echo defaultyes=True >> /etc/dnf/dnf.conf

# if aarch64
	
arch=$(uname -m)
if [[ $arch == "aarch64" ]]; then
cp -P /usr/share/uboot/rpi_arm64/u-boot.bin /boot/efi/rpi-u-boot.bin
cp -P /usr/share/uboot/rpi_3/u-boot.bin /boot/efi/rpi3-u-boot.bin
cp -P /usr/share/uboot/rpi_4/u-boot.bin /boot/efi/rpi4-u-boot.bin
fi
rm -f /var/lib/systemd/random-seed
rm -f /etc/NetworkManager/system-connections/*.nmconnection

rm -f /etc/machine-id
touch /etc/machine-id

rm -f /var/lib/rpm/__db*
