#!/usr/bin/env sh

# Auto Arch Linux chroot environment
# POSIX compliant, no bashisms
# by: William C. Canin <https://williamcanin.github.io>

VERSION="0.1.2"
MNT="/mnt"
PROBE="/mnt/.probe"

echo "auto-chroot - v$VERSION"

ARCH="$(uname -m)"

case "$ARCH" in
    x86_64)  ARCH_OK=1 ;;
    aarch64) ARCH_OK=1 ;;
    *)
        echo "Unsupported architecture: $ARCH"
        exit 1
        ;;
esac

[ "$ARCH_OK" = 1 ] && echo "Architecture detected: $ARCH"

echo "Step 1: Detecting and unlocking LUKS containers..."

# Only check REAL block devices (no mapper, no loop)
lsblk -rpno NAME,TYPE | awk '$2=="part" || $2=="disk"{print $1}' | while read -r dev; do
    if cryptsetup isLuks "$dev" 2>/dev/null; then
        name="luks_$(basename "$dev")"
        echo "LUKS found on $dev"
        cryptsetup open "$dev" "$name"
    fi
done

echo "Step 2: Activating LVM volumes..."
vgchange -ay 2>/dev/null || true

echo "Step 3: Searching for ROOT filesystem..."

ROOT=""

for dev in $(lsblk -rpno NAME); do
    if mount "$dev" "$PROBE" 2>/dev/null; then
        if [ -f "$PROBE/etc/os-release" ]; then
            ROOT="$dev"
            umount "$PROBE"
            break
        fi
        umount "$PROBE"
    fi
done

[ -z "$ROOT" ] && { echo "Root not found"; exit 1; }

echo "ROOT: $ROOT"
mount "$ROOT" "$MNT"

echo "Step 4: Detecting EFI partition..."

for dev in $(lsblk -rpno NAME,FSTYPE | awk '$2=="vfat"{print $1}'); do
    if mount "$dev" "$PROBE" 2>/dev/null; then
        if [ -d "$PROBE/EFI" ]; then
            EFI="$dev"
            umount "$PROBE"
            break
        fi
        umount "$PROBE"
    fi
done

if [ -n "$EFI" ]; then
    echo "EFI: $EFI"
    mkdir -p "$MNT/boot"
    mount "$EFI" "$MNT/boot"
fi

echo "Step 5: Detecting separate /home..."

for dev in $(lsblk -rpno NAME); do
    [ "$dev" = "$ROOT" ] && continue

    if mount "$dev" "$PROBE" 2>/dev/null; then
        if [ -d "$PROBE" ] && [ ! -f "$PROBE/etc/os-release" ]; then
            if [ -d "$PROBE/lost+found" ]; then
                HOME_DEV="$dev"
                umount "$PROBE"
                break
            fi
        fi
        umount "$PROBE"
    fi
done

if [ -n "$HOME_DEV" ]; then
    echo "HOME: $HOME_DEV"
    mkdir -p "$MNT/home"
    mount "$HOME_DEV" "$MNT/home"
fi

echo "Step 6: Mounting system filesystems..."

mount -t proc proc "$MNT/proc"
mount --rbind /dev "$MNT/dev"
mount --rbind /sys "$MNT/sys"
mount --rbind /run "$MNT/run"

echo "Entering chroot..."
arch-chroot "$MNT"
