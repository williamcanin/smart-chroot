# auto-chroot (Arch Linux Rescue Tool)

[![License: MIT](https://img.shields.io/badge/license-MIT-blue.svg)](LICENSE)
[![Shell](https://img.shields.io/badge/shell-POSIX%20sh-green.svg)](https://pubs.opengroup.org/onlinepubs/9699919799/utilities/sh.html)
[![Arch Linux](https://img.shields.io/badge/Arch%20Linux-supported-blue)](https://archlinux.org)

A POSIX-compliant automatic Arch Linux chroot rescue tool that detects, mounts, and enters an installed Linux system with minimal or no user interaction.

It is designed for use in Arch Linux live environments (archiso), system recovery, and automated rescue workflows.

---

## CI Status

[![Auto-chroot real environment tests](https://github.com/williamcanin/auto-chroot/actions/workflows/ci.yml/badge.svg)](https://github.com/williamcanin/auto-chroot/actions/workflows/ci.yml)

[![Auto Release (auto-chroot)](https://github.com/williamcanin/auto-chroot/actions/workflows/release.yml/badge.svg)](https://github.com/williamcanin/auto-chroot/actions/workflows/release.yml)

## Features

* Automatic root partition detection via `/etc/os-release`
* LUKS encrypted volume detection and unlocking (interactive password prompt only when needed)
* Automatic EFI partition detection and mounting
* Optional `/home` partition detection and mounting
* Safe temporary probing mounts
* Fully POSIX-compliant (`/usr/bin/env sh`)
* No hardcoded device paths
* Works with NVMe, SATA, USB, LVM (basic), and LUKS setups

---

## Requirements

The following tools must be available in the live environment:

* `sh`
* `lsblk` (util-linux)
* `mount` / `umount`
* `cryptsetup` (for LUKS support)
* `arch-chroot` (from `arch-install-scripts`)

These are already available in official Arch Linux ISO.

---

## Usage (Arch Linux Live ISO)

Boot into an Arch Linux live environment and run:

```sh
sh <(curl -fsSL https://williamcanin.github.io/installers/auto-chroot/latest)
```

Alternatively:

```sh
curl -fsSL https://raw.githubusercontent.com/williamcanin/auto-chroot/main/auto-chroot.sh -o auto-chroot.sh
chmod +x auto-chroot.sh
sh auto-chroot.sh
```

---

## What it does

1. Scans all block devices
2. Detects and unlocks LUKS volumes (if present)
3. Searches for a valid Linux root filesystem
4. Mounts root to `/mnt`
5. Detects and mounts EFI partition (if available)
6. Detects and mounts separate `/home` partition (if available)
7. Mounts system pseudo-filesystems (`/proc`, `/dev`, `/sys`, `/run`)
8. Executes `arch-chroot /mnt`

---

## Safety

This tool is read-focused and does NOT:

* Format disks
* Modify partitions
* Delete data

It only mounts existing filesystems and enters a chroot environment.

However, it operates on block devices, so use with caution.

---

## Supported System Layouts

This tool supports common Linux installation layouts:

* ext4 root filesystem
* xfs root filesystem (detected via mount support)
* btrfs (basic detection, no subvolume handling)
* LUKS encrypted root partitions
* Separate /home partitions (optional)
* EFI System Partition (FAT32)

Advanced configurations such as full LVM + LUKS + Btrfs subvolumes are partially supported.

---

## Boot Flow (Detection Logic)

```
[ Block Devices Scan ]
          |
          v
[ Detect LUKS? ] ---> yes ---> unlock cryptsetup
          |
          v
[ Scan partitions ]
          |
          v
[ mount probe ]
          |
          v
[ /etc/os-release found? ] ---> YES => ROOT selected
          |
          v
[ Detect EFI (/EFI or /boot/efi) ]
          |
          v
[ Detect /home partition (optional) ]
          |
          v
[ mount system fs (/proc /dev /sys /run) ]
          |
          v
[ arch-chroot /mnt ]
```

---

## Limitations

* Multiple Linux installations may require manual selection
* Advanced Btrfs subvolume layouts are not fully handled
* LVM detection is minimal
* Requires correct `/etc/os-release` in root filesystem

---

## Development

See `CONTRIBUTING.md` for development guidelines and environment setup.

---

## License

MIT License © William Canin

See `LICENSE` file for details.
