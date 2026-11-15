#!/usr/bin/env bash
set -euo pipefail

STAGE_DIR="/home/sschiavon/Developer/dual-boot/grubz-staging"
DEST_DIR="/boot/efi/EFI/grubz"
BACKUP_FILE="$STAGE_DIR/efibootmgr-backup.txt"

if [[ $EUID -ne 0 ]]; then
  echo "Requesting root privileges..."
  exec sudo "$0" "$@"
fi

echo "1. Backing up current UEFI boot configuration to $BACKUP_FILE..."
efibootmgr -v > "$BACKUP_FILE"
chown sschiavon:sschiavon "$BACKUP_FILE"

echo "2. Installing Grubz rEFInd files to $DEST_DIR..."
mkdir -p "$DEST_DIR"
cp -rf "$STAGE_DIR/EFI/grubz/." "$DEST_DIR/"

echo "3. Checking/creating UEFI boot entry for Grubz..."
EXISTING_NUM=$(efibootmgr | awk '/\* Grubz([[:space:]]|$)/ { gsub(/Boot|\*/, "", $1); print $1; exit }')

if [[ -z "$EXISTING_NUM" ]]; then
  efibootmgr --create-only --disk /dev/nvme0n1 --part 1 --label "Grubz" --loader '\EFI\grubz\refind_x64.efi' >/dev/null
  EXISTING_NUM=$(efibootmgr | awk '/\* Grubz([[:space:]]|$)/ { gsub(/Boot|\*/, "", $1); print $1; exit }')
fi

CURRENT_ORDER=$(efibootmgr | awk -F': ' '/^BootOrder:/ { print $2 }')

# Remove EXISTING_NUM from CURRENT_ORDER if present, then place it first as default
CLEAN_ORDER=$(echo "$CURRENT_ORDER" | sed -E "s/(^|,)${EXISTING_NUM}(,|$)/,/g; s/^,//; s/,$//; s/,,/,/g")
NEW_ORDER="${EXISTING_NUM},${CLEAN_ORDER}"

efibootmgr -o "$NEW_ORDER" >/dev/null
efibootmgr -n "$EXISTING_NUM" >/dev/null

echo ""
echo "=== Grubz rEFInd Installed Successfully ==="
ls -la "$DEST_DIR"
echo ""
efibootmgr
