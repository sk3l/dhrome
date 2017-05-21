#!/bin/bash
# On a desktop machine (does not need to be ARM):
#
# cpgt root size in sectors; applies to 32Gb sd card

DEV=/dev/mmcblk0
MNT=/mnt/sdcard
# Partitioning the device:
parted --script ${DEV} mklabel gpt

if [[ $? -ne 0 ]]; then
   echo "Could not label blockdev; exiting."
   exit 1
fi

cgpt create ${DEV}
if [[ $? -ne 0 ]]; then
   echo "Could not create chrome part header; exiting."
   exit 1
fi

cgpt add -t kernel -l kernel -b 34 -s 32768 ${DEV}
if [[ $? -ne 0 ]]; then
   echo "Could not add kernel partition; exiting."
   exit 1
fi

cgpt add -t data -l / -b 32802 -s 62300000 ${DEV}
if [[ $? -ne 0 ]]; then
   echo "Could not create chrome part header; exiting."
   exit 1
fi

blockdev --rereadpt ${DEV}
# Create the root filesystem:
mkfs.ext4 ${DEV}p2
if [[ $? -ne 0 ]]; then
   echo "Could not create ext4 FS; exiting."
   exit 1
fi


# Install the bootstrap packages in the root filesystem:
mkdir -p ${MNT}
mount ${DEV}p2 ${MNT}
if [[ $? -ne 0 ]]; then
   echo "Could not mount data partition for debootstrap; exiting."
   exit 1
fi

debootstrap --arch=armhf --foreign jessie ${MNT} http://http.debian.net/debian
# Unmount the filesystems:
umount ${MNT}
