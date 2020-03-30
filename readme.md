## rpi-debian-installer
### version 1.1
This is `rpi-debian-installer`, a script to install mainline [Debian](http://debian.org) onto the [Raspberry Pi](https://raspberrypi.org) 4 model B single-board computer.
This *is* an interactive installer, and cannot really be run in an unattended way.
The user interface was stolen in part from the [OpenBSD](https://openbsd.org/) installer.
### Requirements
`rpi-debian-installer` depends on the following things, all of which it will check for at startup:

* The `debootstrap`, `dpkg`, `dosfstools`, `e2fsprogs`, and `parted` packages.
* The existence of Debian Archive keyrings in `/etc/apt/trusted.gpg`, though this is often satisfied by the installation of debootstrap.
* Qemu-aarch64-static installed (either qemu-user-static in debian or qemu-user-static (AUR) in arch linux)
* binfmt_misc support in your kernel (as well as a mounted `/proc/sys/fs/binfmt_misc`)
* the `qemu-user-binfmt` (Debian) or `binfmt-qemu-static-all-arch (AUR)` (on Arch Linux) packages.

### Usage
Simply run `./installer.sh`. You can alternatively run `./installer.sh verbose` to see more info about dependancy checks.

### License
This software is licensed under the GNU General Public License (version 3) and is copyright (C) 2020 Saoirse Ó Catháin.