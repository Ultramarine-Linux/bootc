#!/bin/bash
set -x
# Disable os-prober for now

echo "Disabling os-prober..."

echo "GRUB_DISABLE_OS_PROBER=true" > /etc/default/grub
grub2-mkconfig > /boot/grub2/grub.cfg
rm /etc/default/grub


# get /dev/ of /boot, or / if /boot is not a separate partition
function find_bootdev {
    # try findmnt /boot
    if findmnt -n -o SOURCE /boot; then
        bootdev=$(findmnt -n -o SOURCE /boot)
    else
        bootdev=$(findmnt -n -o SOURCE /)
    fi
}


find_bootdev
# get blkid of /boot
bootid=$(blkid -s UUID -o value $bootdev)

cat << EOF > /boot/efi/EFI/fedora/grub.cfg
search --no-floppy --fs-uuid --set=dev $bootid
set prefix=(\$dev)/grub2

export \$prefix
configfile \$prefix/grub.cfg
EOF

# -v will fill up the logs and make it hard to debug
dracut -fN --add-drivers "virtio virtio_blk virtio_scsi xchi_pci mmc" --regenerate-all

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
