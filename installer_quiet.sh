#!/bin/bash
function main() {

clear
reset
clear
echo 'Welcome to the Debian GNU/Linux (stable) Raspberry Pi Installation Program.'
read -n 1 -p "(I)nstall, (S)hell or (Q)uit? " isq
printf "\n"
if [[ ${isq} = s ]]; then
echo 'type exit to return to the installer.'
sh
main
fi
if [[ ${isq} = q ]]; then
echo Exiting.
exit 255
fi
if [[ ${isq} = i ]]; then
RunInstaller
fi
main
}

function RunInstaller() {
echo "Default answers are shown at the end of the line (where availlable), and are selected by
pressing RETURN.  You can exit this program at any time by pressing
Control-C, but this can leave your system in an inconsistent state."
read -e -i ${TERM} -p "Terminal Type? " INSTALLER_TERMTYPE
export TERM=${INSTALLER_TERMTYPE}

printf "\n"
until [[ -n ${INSTALLER_HOSTNAME} ]]; do read -e -p "System hostname? (short form, e.g. 'foo') " INSTALLER_HOSTNAME; done
export INSTALLER_HOSTNAME
echo 'note: network configuration postponed for now'

rootpw
read -n 1 -e -p "Start sshd(8) by default? (y/n)" yn
printf "\n"
if [[ ${yn} = y ]]; then
export START_SSHD=1
fi

read -e -p "Setup a user? (enter a lower-case loginname, or 'no')  " -i "no" INSTALLER_USER_NAME
if [[ ${INSTALLER_USER_NAME} = no ]]; then
export SKIP_USER=1
else
until [[ -n ${INSTALLER_USER_FULL_NAME} ]]; do read -e -p "Full name for user ${INSTALLER_USER_NAME}? " INSTALLER_USER_FULL_NAME; done
userpw ${INSTALLER_USER_NAME}
fi
if [[ ${START_SSHD} = 1 ]]; then
echo 'WARNING: root is targeted by password guessing attacks, pubkeys are safer.'
read -e -p "Allow root ssh login? (yes, no, prohibit-password) " -i prohibit-password INSTALLER_SSH_ROOT_LOGIN_POLICY
fi
until [[ -n $INSTALLER_TIME_ZONE ]]; do read -e -i 'UTC' -p "What timezone are you in? ('?' for list)  " INSTALLER_TIME_ZONE; done
until [[ ${INSTALLER_ROOT_DISK_IS_SELECTED} = 1 ]]; do
DiskPrompt
parted /dev/${INSTALLER_ROOT_DISK_NAME} print
read -e -n 1 -p "Use this disk? (y/n) " yn
if [[ ${yn} = y ]]; then
export INSTALLER_ROOT_DISK_IS_SELECTED=1
else
export INSTALLER_ROOT_DISK_IS_SELECTED=0
fi
done
echo using disk: ${INSTALLER_ROOT_DISK_NAME}
printf "Creating MBR: "
parted --script /dev/${INSTALLER_ROOT_DISK_NAME} mklabel msdos
printf " done.\n"
printf "Creating Boot partition: "
parted --script /dev/${INSTALLER_ROOT_DISK_NAME} mkpart p fat32 1M 129M
printf " done.\n"
printf "Creating Root partition: "
parted --script /dev/${INSTALLER_ROOT_DISK_NAME} mkpart p ext4 130M 100%
printf " done.\n"
printf "Formatting Boot partition: "
mkfs.vfat /dev/${INSTALLER_ROOT_DISK_NAME}1 >/dev/null
printf " done.\n"
printf "Formatting Root partition: "
mkfs.ext4 /dev/${INSTALLER_ROOT_DISK_NAME}2 2>&1 >/dev/null
printf " done.\n"
printf "Mounting Root partition: "
mount /dev/${INSTALLER_ROOT_DISK_NAME}2 /mnt
printf " done.\n"
mkdir /mnt/boot
printf "Mounting Boot partition: "
mount /dev/${INSTALLER_ROOT_DISK_NAME}1 /mnt/boot
printf " done.\n"


echo 'Disk setup completed!'
echo "Let's install the base files!"
echo 'Location of base files is http'
read -e -p "HTTP proxy URL? (e.g. 'http://proxy:8080', or 'none') " HTTP_PROXY
read -e -i "ftp.nz" -p "HTTP server prefix? (ftp.country_name or 'httpredir')" INSTALLER_DEBIAN_INSTALL_SERVER_PREFIX
read -e -i "stable" -p "Distribution code-name? ('stable', 'testing', 'unstable', or a release name) " INSTALLER_DEBIAN_RELEASE
echo Fetching ${INSTALLER_DEBIAN_RELEASE} from ${INSTALLER_DEBIAN_INSTALL_SERVER_PREFIX}.debian.org. This might take a while
debootstrap --foreign --arch=arm64 ${INSTALLER_DEBIAN_RELEASE} /mnt http://${INSTALLER_DEBIAN_INSTALL_SERVER_PREFIX}.debian.org/debian >/dev/null
printf 'Creating basic system structure: '

mount -o bind /proc /mnt/proc
mount -o bind /dev /mnt/dev
mount -o bind /dev/pts /mnt/dev/pts
mount -o bind /sys /mnt/sys
cp /etc/resolv.conf /mnt/etc/resolv.conf
rm /mnt/etc/fstab
rm /mnt/etc/hostname
rm /mnt/etc/apt/sources.list

echo "proc            /proc           proc    defaults          0       0
/dev/mmcblk0p1  /boot           vfat    defaults          0       2
/dev/mmcblk0p2  /               ext4    defaults,noatime  0       1" >> /mnt/etc/fstab

echo "${INSTALLER_HOSTNAME}" >> /mnt/etc/hostname

echo "deb http://${INSTALLER_DEBIAN_INSTALL_SERVER_PREFIX}.debian.org/debian ${INSTALLER_DEBIAN_RELEASE} main contrib non-free
#deb-src http://${INSTALLER_DEBIAN_INSTALL_SERVER_PREFIX}.debian.org/debian ${INSTALLER_DEBIAN_RELEASE} main contrib non-free " >> /mnt/etc/apt/sources.list
printf ' done.\n'

printf 'Installing bootloader: '

wget -q http://archive.raspberrypi.org/debian/pool/main/r/raspberrypi-firmware/raspberrypi-bootloader_1.20190925-2_armhf.deb
mkdir /tmp/pi-bootloader/
dpkg-deb -x raspberrypi-bootloader_1.20190925-2_armhf.deb /tmp/pi-bootloader/
cp /tmp/pi-bootloader/boot/* /mnt/boot/
rm raspberrypi-bootloader_1.20190925-2_armhf.deb
printf ' done.\n'
printf 'Installing kernel: '

wget -q https://github.com/sakaki-/bcm2711-kernel-bis/releases/download/4.19.108.20200324/bcm2711-kernel-bis-4.19.108.20200324.tar.xz
mkdir /tmp/pi-kernel
tar xf bcm2711-kernel-bis-4.19.108.20200324.tar.xz -C /tmp/pi-kernel/
cp -r /tmp/pi-kernel/boot/* /mnt/boot/
mv /mnt/boot/kernel*.img /mnt/boot/kernel8.img
mkdir /mnt/lib/modules
cp -r /tmp/pi-kernel/lib/modules /mnt/lib/
rm bcm2711-kernel-bis-4.19.108.20200324.tar.xz
rm -r /tmp/pi-kernel
printf ' done.\n'

printf 'Configuring bootloader: '
echo "disable_overscan=1
#dtoverlay=vc4-fkms-v3d" >> /mnt/boot/config.txt
printf ' done.\n'
printf 'Configuring kernel: '

echo "dwc_otg.lpm_enable=0 console=ttyAMA0,115200 console=tty1 root=/dev/mmcblk0p2 rootfstype=ext4 elevator=deadline rootwait" >> /mnt/boot/cmdline.txt

printf ' done.\n'
printf 'Preparing the system: '
chroot /mnt /debootstrap/debootstrap --second-stage >/dev/null
printf ' done.\n'
printf 'Checking for updates: '

chroot /mnt apt update -yq >/dev/null
printf ' done.\n'
printf 'Installing updates: '

chroot /mnt apt upgrade -yq >/dev/null
printf ' done.\n'
printf 'Installing additional packages: '

chroot /mnt apt install sudo ssh curl wget dbus usbutils ca-certificates crda less fbset debconf-utils avahi-daemon fake-hwclock nfs-common apt-utils man-db pciutils ntfs-3g apt-listchanges -yq
printf ' done.\n'
printf 'Installing firmware: '

chroot /mnt apt install wpasupplicant wireless-tools firmware-atheros firmware-brcm80211 firmware-libertas firmware-misc-nonfree firmware-realtek dhcpcd5 net-tools -yq

printf ' done.\n'
if [[ ${RUNMODE} = debug ]]; then
printf '(DEBUG) installing telnet daemon: '
chroot /mnt apt install telnetd >/dev/null
printf ' done.\n'
fi
printf 'Configuring users: '

echo -e "${INSTALLER_ROOTPW}\n${INSTALLER_ROOTPW}" | chroot /mnt passwd root
if [[ ! ${SKIP_USER} = 1 ]]; then
chroot /mnt /usr/sbin/useradd --create-home --user-group ${INSTALLER_USER_NAME}
chroot /mnt /usr/sbin/usermod -aG sudo,video,audio,cdrom ${INSTALLER_USER_NAME}
echo -e "${INSTALLER_USERPW}\n${INSTALLER_USERPW}" | chroot /mnt passwd ${INSTALLER_USER_NAME}
fi
printf ' done.\n'
if [[ ${START_SSHD} = 1 ]]; then
printf 'Configuring remote access: '
chroot /mnt systemctl enable ssh
printf ' done.\n'
fi
printf 'Cleaning up: '
#umount /mnt/proc
#umount /mnt/sys
#umount /mnt/dev/pts
#umount /mnt/dev -l
umount /mnt/boot
umount /mnt -l
printf ' done.\n'

echo "congratulations, your Debian system is successfully installed!"

exit 0



}
function DiskPrompt() {
read -e  -p "Which disk is the root disk? ('?' for details) " INSTALLER_ROOT_DISK_NAME
if [[ -z ${INSTALLER_ROOT_DISK_NAME} ]]; then
DiskPrompt
fi
if [[ ${INSTALLER_ROOT_DISK_NAME} = '?' ]]; then
DiskInfo
DiskPrompt
fi

if [[ ! -e /dev/${INSTALLER_ROOT_DISK_NAME} ]]; then
echo "error: invalid disk name ${INSTALLER_ROOT_DISK_NAME}"
DiskPrompt
fi
export INSTALLER_ROOT_DISK_NAME

}


function DiskInfo() {
for each in /dev/sd?; do parted ${each} print 2>/dev/null|head -n 2|tail -n1; parted ${each} print 2>/dev/null|head -n 1|sed -e 's/Model:\ //g'; done
}

function userpw() {
read -e -s -p "Password for user $1? (will not echo) " INSTALLER_USERPW
printf "\n"
read -e -s -p "Password for user $1? (again) " INSTALLER_USERPW_VERIFY
printf "\n"
if [[ ${INSTALLER_USERPW_VERIFY} = ${INSTALLER_USERPW} ]]; then
export INSTALLER_USERPW
else
echo passwords do not match
userpw $1
fi
}

function rootpw() {
read -e -s -p "Password for root account? (will not echo) " INSTALLER_ROOTPW
printf "\n"
read -e -s -p "Password for root account? (again) " INSTALLER_ROOTPW_VERIFY
printf "\n"
if [[ ${INSTALLER_ROOTPW_VERIFY} = ${INSTALLER_ROOTPW} ]]; then
export INSTALLER_ROOTPW
else
echo passwords do not match
rootpw
fi
}

## Raspberry Pi 4 Debian install Script
## Copyright (C) 2020 - Saoirse Ó Catháin
## version 1.0
progressorhash() {
if [[ ${RUNMODE} = debug ]]; then
printf "$@"
else
printf " # "
fi
}

export RUNMODE=$1

if [[ ! ${EUID} = 0
 ]]; then

echo you are not root.
exit 254
fi
printf "Checking dependancies... "

if [[ ! $(uname -m) = x86_64 ]]; then
printf "\n"
echo Depcheck 1 failed: architecture unsupported.
exit 1
fi
progressorhash " architecture ok. "

if [[ ! -e /usr/bin/debootstrap ]]; then
printf "\n"
echo 'depchec 2 failed: please install both debootstrap and the debian-archive-keyring'
exit 2
fi
progressorhash " debootstrap found. "

if [[ ! -e /usr/bin/qemu-aarch64-static ]]; then
printf "\n"
echo 'depcheck 3 failed: please install qemu-user-static (or a similar package) on your system.'
exit 3
fi
progressorhash " qemu static binaries installed. "
mount|grep binfmt_misc\ on 2>&1 >/dev/null
if [[  $? = 1 ]]; then
printf "\n"
echo 'depcheck 4 failed: the system does not appear to have binfmt_misc configured. Please do so.'
exit 4
fi
progressorhash " binfmt_misc ok. "
if [[ ! -e /proc/sys/fs/binfmt_misc/qemu-aarch64 ]]; then
printf "\n"
echo 'depcheck 5 failed: qemu ARM64 binfmt support is not correctly configured. Please fix this, then re-run the script.'
exit 5
fi
progressorhash " arm64 binfmt ok. "
main
