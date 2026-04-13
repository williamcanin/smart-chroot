#!/usr/bin/env sh

# Auto Arch Linux chroot environment
# POSIX compliant, no bashisms
# by: William C. Canin <https://williamcanin.github.io>

VERSION="0.1.4"
MNT="/mnt"
PROBE="/mnt/.probe"

echo "auto-chroot - v$VERSION"

ARCH="$(uname -m)"

case "$ARCH" in
x86_64) ARCH_OK=1 ;;
aarch64) ARCH_OK=1 ;;
*)
  echo "Unsupported architecture: $ARCH"
  exit 1
  ;;
esac

[ "$ARCH_OK" = 1 ] && echo "Architecture detected: $ARCH"

echo "Step 1: Detecting and unlocking LUKS containers..."

lsblk -rpno NAME,FSTYPE | awk '$2=="crypto_LUKS"{print $1}' | while read -r dev; do
  base="$(basename "$dev")"

  if lsblk "$dev" -rno TYPE | grep -q "crypt"; then
    echo "LUKS already unlocked: $dev"
    continue
  fi

  echo "LUKS found (locked) on $dev, opening..."
  cryptsetup open "$dev" "luks-$base"
done

echo "Step 2: Activating LVM volumes..."
vgchange -ay >/dev/null 2>&1 || true

echo "Step 3: Searching for ROOT filesystem..."

ROOT=""

for dev in $(lsblk -rpno NAME,FSTYPE | awk '$2~/^(ext[234]|btrfs|xfs)$/{print $1}'); do
  if mount "$dev" "$PROBE" 2>/dev/null; then
    if [ -f "$PROBE/etc/os-release" ] && [ -d "$PROBE/bin" ] && [ -d "$PROBE/etc" ]; then
      ROOT="$dev"
      umount "$PROBE"
      break
    fi
    umount "$PROBE"
  fi
done

[ -z "$ROOT" ] && {
  echo "Root not found"
  exit 1
}

echo "ROOT: $ROOT"
mount "$ROOT" "$MNT"

echo "Step 4: Detecting EFI partition..."

# Try via PARTTYPE (GPT)
EFI=$(lsblk -rpno NAME,PARTTYPE | awk '$2=="c12a7328-f81f-11d2-ba4b-00a0c93ec93b"{print $1; exit}')

# Fallback: mount and verify (MBR or edge cases)
if [ -z "$EFI" ]; then
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
fi

if [ -n "$EFI" ]; then
  echo "EFI: $EFI"
  mkdir -p "$MNT/boot"
  mount "$EFI" "$MNT/boot"
fi

echo "Step 5: Detecting separate /home..."
HOME_DEV=""

for dev in $(lsblk -rpno NAME,FSTYPE | awk '$2~/^(ext[234]|btrfs|xfs)$/{print $1}'); do
  [ "$dev" = "$ROOT" ] && continue

  if mount -o ro "$dev" "$PROBE" 2>/dev/null; then
    # It has user directories but is not root.
    if [ -d "$PROBE/lost+found" ] && [ ! -f "$PROBE/etc/os-release" ] && [ ! -d "$PROBE/bin" ]; then
      HOME_DEV="$dev"
      umount "$PROBE"
      break
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
