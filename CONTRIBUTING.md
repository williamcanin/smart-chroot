# Contributing to init.sh tool

Thank you for your interest in contributing to this project.

This project provides a POSIX-compliant shell tool to automatically detect, mount, and enter an Arch Linux installation via `arch-chroot`.

---

## Project Goals

* Fully automatic detection of Linux root partitions
* Support for LUKS encrypted volumes
* Safe mounting of system partitions
* Minimal dependencies
* POSIX-compliant shell script (`/usr/bin/env sh`)

---

## Development Requirements

To contribute or test this project locally, you need:

### Required packages

On Arch Linux:

```sh
pacman -S --needed \
    util-linux \
    cryptsetup \
    coreutils \
    bash \
    sh \
		shfmt
```

On Debian/Ubuntu:

```sh
apt install \
    cryptsetup \
    util-linux \
    mount \
    e2fsprogs \
		shfmt
```

---

## Runtime Dependencies

The script relies only on:

* sh (POSIX shell)
* lsblk
* mount / umount
* cryptsetup (optional, for LUKS support)
* arch-chroot (from arch-install-scripts)

---

## Testing locally

You can simulate execution safely using a container or VM:

```sh
sh init.sh.sh
```

For testing logic only (without real mounts), use a disposable container environment.

---

## Code style

* Must be POSIX compliant (`/usr/bin/env sh`)
* No bashisms allowed
* Avoid arrays, use `set --`
* Avoid subshell-heavy logic when possible
* Prefer readability over micro-optimizations

---

## Safety rules

This tool operates on block devices and mounts filesystems.

Do NOT:

* add destructive commands (rm, mkfs, wipefs)
* auto-format disks
* assume partition layouts
* hardcode device names

---

## Pull Requests

Before submitting:

* Ensure script runs with `sh`
* Ensure no bash-only syntax
* Ensure no external dependencies introduced
* Test with multiple disk layouts if possible

---

## Testing checklist

* [ ] Detects root partition correctly
* [ ] Detects LUKS and prompts unlock
* [ ] Mounts EFI if present
* [ ] Mounts /home if separate
* [ ] Enters arch-chroot successfully

---

## License

Same license as repository.




