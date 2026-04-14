#!/usr/bin/env sh
# smart-chroot - Interactive script for mounting partitions and entering the chroot.
# POSIX compliant, no bashisms
# Project: https://github.com/williamcanin/smart-chroot
# Target distro: Arch Linux
# Config format: INI-style .conf file

set -e

# Version current
VERSION="0.2.0"

# Output colors and utilities
# -----------------------------------------------------------------------------
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
BOLD='\033[1m'
RESET='\033[0m'

info() { printf "${CYAN}[INFO]${RESET}  %s\n" "$1"; }
success() { printf "${GREEN}[OK]${RESET}    %s\n" "$1"; }
warn() { printf "${YELLOW}[WARN]${RESET}  %s\n" "$1"; }
error() { printf "${RED}[ERROR]${RESET}  %s\n" "$1" >&2; }
die() {
  error "$1"
  exit 1
}

header() {
  printf "\n%s%s" "$BOLD" "$CYAN"
  printf "╔══════════════════════════════════════════════╗\n"
  printf "             smart-chroot v%s              \n" "$VERSION"
  printf "            Arch Linux chroot helper             \n"
  printf "╚══════════════════════════════════════════════╝\n"
  printf "%s\n" "$RESET"
}

# Initial checks
# -----------------------------------------------------------------------------
check_root() {
  if [ "$(id -u)" -ne 0 ]; then
    die "This script needs to be run as root (use sudo)."
  fi
}

check_dependencies() {
  for cmd in mount cryptsetup arch-chroot curl; do
    if ! command -v "$cmd" >/dev/null 2>&1; then
      warn "Missing dependency: $cmd"
    fi
  done
}

# -----------------------------------------------------------------------------
# INI parser — pure shell using grep and sed, no external dependencies
#
# Usage: ini_get <file_content> <section> <key>
#
# Extracts the value of <key> inside [<section>] from an INI-formatted string.
# Lines starting with # are treated as comments and ignored.
# Inline comments (# after value) are also stripped.
# -----------------------------------------------------------------------------
ini_get() {
  _content="$1"
  _section="$2"
  _key="$3"

  echo "$_content" | awk -F= -v section="$_section" -v key="$_key" '
        /^[[:space:]]*#/ { next }
        /^[[:space:]]*\[/ {
            current = $0
            gsub(/[[:space:]\[\]]/, "", current)
        }
        current == section && $1 ~ "^[[:space:]]*" key "[[:space:]]*$" {
            val = $2
            sub(/#.*$/, "", val)      # strip inline comments
            gsub(/^[[:space:]]+|[[:space:]]+$/, "", val)  # trim whitespace
            print val
            exit
        }
    '
}

# -----------------------------------------------------------------------------
# Downloads and validates a .conf (INI) config file from a given URL
# -----------------------------------------------------------------------------
load_config_from_url() {
  _url="$1"
  info "Downloading configuration from: $_url"

  _config=$(curl -fsSL "$_url" 2>/dev/null) ||
    die "Failed to download the configuration file. Please check the URL."

  # Basic validation: must contain at least one [section] header
  echo "$_config" | grep -qE '^\[.+\]' ||
    die "The downloaded file does not appear to be a valid INI config."

  success "Configuration loaded successfully."
  echo "$_config"
}

# -----------------------------------------------------------------------------
# Mounts a partition with optional LUKS support
# Arguments:
#   $1 = label        (e.g. "root", "home")
#   $2 = device       (e.g. /dev/sda2 or /dev/mapper/linux-root)
#   $3 = mountpoint   (e.g. /mnt or /mnt/home)
#   $4 = luks_enabled (true/false)
#   $5 = luks_name    (e.g. linux-root)
#   $6 = luks_device  (physical device to open LUKS, e.g. /dev/sda2)
# -----------------------------------------------------------------------------
mount_partition() {
  _label="$1"
  _device="$2"
  _mountpoint="$3"
  _luks="$4"
  _luks_name="$5"
  _luks_device="$6"

  printf "\n${BOLD}>> Mounting partition: %s${RESET}\n" "$_label"

  if [ "$_luks" = "true" ]; then
    info "Partition '$_label' is LUKS-encrypted."
    info "Running: cryptsetup open $_luks_device $_luks_name"
    cryptsetup open "$_luks_device" "$_luks_name" ||
      die "Failed to open LUKS partition '$_luks_name'."
    success "LUKS partition '$_luks_name' opened."
  fi

  mkdir -p "$_mountpoint"
  mount "$_device" "$_mountpoint" ||
    die "Failed to mount $_device at $_mountpoint."
  success "$_device mounted at $_mountpoint."
}

# -----------------------------------------------------------------------------
# Automated flow using an INI configuration file
# -----------------------------------------------------------------------------
flow_with_config() {
  _config="$1"

  # --- ROOT ---
  _root_mount=$(ini_get "$_config" "system" "mount")
  _root_luks=$(ini_get "$_config" "system" "luks")
  _root_luks_name=$(ini_get "$_config" "system" "luks_name")
  _root_luks_device=$(ini_get "$_config" "system" "luks_device")

  [ -z "$_root_mount" ] && die "Missing 'mount' key under [system] in config."

  if [ "$_root_luks" = "true" ] && [ -z "$_root_luks_device" ]; then
    die "LUKS enabled for system but 'luks_device' is not specified in the config."
  fi

  # If LUKS is enabled, the mount device is /dev/mapper/<name>;
  # the physical device to unlock comes from luks_device
  if [ "$_root_luks" = "true" ]; then
    mount_partition "root" "$_root_mount" "/mnt" "true" "$_root_luks_name" "$_root_luks_device"
  else
    mount_partition "root" "$_root_mount" "/mnt" "false" "" ""
  fi

  # --- HOME ---
  _home_mount=$(ini_get "$_config" "home" "mount")
  _home_luks=$(ini_get "$_config" "home" "luks")
  _home_luks_name=$(ini_get "$_config" "home" "luks_name")
  _home_luks_device=$(ini_get "$_config" "home" "luks_device")

  [ -z "$_home_mount" ] && die "Missing 'mount' key under [home] in config."

  if [ "$_home_luks" = "true" ] && [ -z "$_home_luks_device" ]; then
    die "LUKS enabled for home but 'luks_device' is not specified in the config."
  fi

  if [ "$_home_luks" = "true" ]; then
    mount_partition "home" "$_home_mount" "/mnt/home" "true" "$_home_luks_name" "$_home_luks_device"
  else
    mount_partition "home" "$_home_mount" "/mnt/home" "false" "" ""
  fi

  # --- BOOT ---
  _boot_mount=$(ini_get "$_config" "boot" "mount")

  [ -z "$_boot_mount" ] && die "Missing 'mount' key under [boot] in config."

  printf "\ns%>> Mounting partition: boot s%\n" "${BOLD}" "${RESET}"
  mkdir -p /mnt/boot
  mount "$_boot_mount" /mnt/boot ||
    die "Failed to mount $_boot_mount at /mnt/boot."
  success "$_boot_mount mounted at /mnt/boot."
}

# -----------------------------------------------------------------------------
# Interactive flow (no configuration file)
# -----------------------------------------------------------------------------
ask_yn() {
  # Returns 0 for "y", 1 for "n"
  while true; do
    printf "%s [y/n]: " "$1"
    read -r _answer
    case "$_answer" in
    y | Y) return 0 ;;
    n | N) return 1 ;;
    *) warn "Please answer with 'y' or 'n'." ;;
    esac
  done
}

ask_device() {
  _prompt="$1"
  _val=""
  while [ -z "$_val" ]; do
    printf "%s\n> " "$_prompt"
    read -r _val
    if [ -z "$_val" ]; then
      warn "Value cannot be empty."
    fi
  done
  echo "$_val"
}

flow_interactive() {
  # --- ROOT ---
  printf "\ns%=== ROOT Partition ===s%\n" "${BOLD}" "${RESET}"
  _root_device=$(ask_device "Enter the root partition (e.g. /dev/sda2):")

  if ask_yn "Is the root partition LUKS-encrypted?"; then
    _root_luks_name=$(ask_device "Enter a name for the encrypted partition (e.g. linux-root):")
    info "Opening LUKS partition..."
    cryptsetup open "$_root_device" "$_root_luks_name" ||
      die "Failed to open the LUKS partition."
    success "LUKS '$_root_luks_name' opened."
    _root_final_device="/dev/mapper/$_root_luks_name"
  else
    _root_final_device="$_root_device"
  fi

  mkdir -p /mnt
  mount "$_root_final_device" /mnt ||
    die "Failed to mount root at /mnt."
  success "$_root_final_device mounted at /mnt."

  # --- HOME ---
  printf "\ns%=== HOME Partition ===s%\n" "${BOLD}" "${RESET}"
  _home_device=$(ask_device "Enter the home partition (e.g. /dev/sdb1):")

  if ask_yn "Is the home partition LUKS-encrypted?"; then
    _home_luks_name=$(ask_device "Enter a name for the encrypted partition (e.g. home):")
    info "Opening LUKS partition..."
    cryptsetup open "$_home_device" "$_home_luks_name" ||
      die "Failed to open the LUKS partition for home."
    success "LUKS '$_home_luks_name' opened."
    _home_final_device="/dev/mapper/$_home_luks_name"
  else
    _home_final_device="$_home_device"
  fi

  mkdir -p /mnt/home
  mount "$_home_final_device" /mnt/home ||
    die "Failed to mount home at /mnt/home."
  success "$_home_final_device mounted at /mnt/home."

  # --- BOOT ---
  printf "\ns%=== BOOT Partition ===s%\n" "${BOLD}" "${RESET}"
  _boot_device=$(ask_device "Enter the boot partition (e.g. /dev/sda1):")

  mkdir -p /mnt/boot
  mount "$_boot_device" /mnt/boot ||
    die "Failed to mount boot at /mnt/boot."
  success "$_boot_device mounted at /mnt/boot."
}

# -----------------------------------------------------------------------------
# Enter the chroot environment
# -----------------------------------------------------------------------------
do_chroot() {
  printf "\ns%${GREEN}=== Entering chroot ===s%\n" "${BOLD}" "${RESET}"
  info "Running: arch-chroot /mnt"
  arch-chroot /mnt
  success "chroot session ended."
}

# -----------------------------------------------------------------------------
# Main entry point
# -----------------------------------------------------------------------------
main() {
  header
  check_root
  check_dependencies

  printf "s%Do you have a configuration file (.conf)? s% [y/n]: " "${BOLD}" "${RESET}"
  read -r _has_config

  case "$_has_config" in
  y | Y)
    printf "Enter the URL of your configuration file:\n> "
    read -r _config_url
    [ -z "$_config_url" ] && die "URL cannot be empty."
    _config_data=$(load_config_from_url "$_config_url")
    flow_with_config "$_config_data"
    ;;
  n | N)
    flow_interactive
    ;;
  *)
    die "Invalid answer. Please run the script again and answer 'y' or 'n'."
    ;;
  esac

  do_chroot
}

main "$@"
