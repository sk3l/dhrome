#!/bin/bash

# On the Chromebook:
#
DEV=/dev/mmcblk1
MNT=/media/sdcard
# Unmount from wherever ChromeOS decided to mount the device,
# remount where we want:
umount ${DEV}p2
mount ${DEV}p2 ${MNT}
# Complete the bootstrap:
chroot ${MNT} /debootstrap/debootstrap --second-stage
# Set up fstab:
cat > ${MNT}/etc/fstab <<EOF
${DEV}p2 / ext4 errors=remount-ro 0 1
EOF
# Set up the apt sources and update:
cat > ${MNT}/etc/apt/sources.list <<EOF
deb http://http.debian.net/debian jessie main non-free contrib
deb-src http://http.debian.net/debian jessie main non-free contrib
EOF
# Copy the resolv.conf file in a chroot env, so files can be fetched
cp /etc/resolv.conf ${MNT}/etc/resolv.conf
# Update the package list:
chroot ${MNT} apt-get update
# Install useful packages:
chroot ${MNT} apt-get install -y cgpt vboot-utils \
           vboot-kernel-utils
chroot ${MNT} apt-get install -y wicd-daemon wicd-cli \
      wicd-curses console-setup
# Set the root password to blank:
chroot ${MNT} passwd -d root
# Set the hostname:
echo "lynx" > ${MNT}/etc/hostname
# Guess which kernel partition is the latest.  Run cgpt show and see
# which one (KERN-A or KERN-B) has the highest priority.
cgpt show /dev/mmcblk0
# Copy the ChromeOS kernel to the root filesystem,
# In this example we'll assume it was KERN-B:
dd if=/dev/mmcblk0p4 of=${MNT}/boot/chromeos.kernel.signed
cp ${MNT}/boot/chromeos.kernel.signed ${MNT}/boot/vmlinuz
# Declare the kernel flags:
cat > ${MNT}/boot/kernel.flags <<EOF
console=tty1 printk.time=1 nosplash rootwait root=${DEV}p2 ro rootfstype=ext4 lsm.module_locking=0
EOF
# Sign the kernel:
cat > ${MNT}/boot/sign-kernel.sh <<EOF
vbutil_kernel --repack /boot/vmlinuz.signed --keyblock \
     /usr/share/vboot/devkeys/kernel.keyblock --version 1 \
       --signprivate /usr/share/vboot/devkeys/kernel_data_key.vbprivk \
         --config /boot/kernel.flags --oldblob /boot/chromeos.kernel.signed \
           --arch arm
EOF
chroot ${MNT} sh /boot/sign-kernel.sh
# Write the signed kernel to the kernel partition:
dd if=${MNT}/boot/vmlinuz.signed of=${DEV}p1
# Mark the newly written kernel partition as good and set the
# priority:
cgpt add -i 1 -S 1 -T 5 -P 12 ${DEV}
# Copy the ChromeOS kernel modules into the root filesystem:
mkdir -p ${MNT}/lib/modules
cp -r /lib/modules/* ${MNT}/lib/modules
# Copy the non-free firmware for the wifi device:
mkdir -p ${MNT}/lib/firmware/
cp -r /lib/firmware/* ${MNT}/lib/firmware
# Umount the filesystems:
umount ${MNT}
