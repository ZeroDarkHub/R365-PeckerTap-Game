#!/bin/bash
set -euo pipefail

ROOT=$(cd "$(dirname "$0")/.." && pwd)
BASE_IMAGE=${1:-"$ROOT/cache/ArkOS_R35S-R36S_v2.0_11072025_MultiPanel.img"}
OUT_IMAGE=${2:-"$ROOT/dist/PeckerTap-R36S.img"}
DEBUGFS=${DEBUGFS:-/opt/homebrew/opt/e2fsprogs/sbin/debugfs}

if [ ! -s "$BASE_IMAGE" ]; then echo "Base image not found: $BASE_IMAGE" >&2; exit 1; fi
if [ ! -x "$DEBUGFS" ]; then echo "debugfs is required (brew install e2fsprogs)" >&2; exit 1; fi

bash "$ROOT/scripts/build-bootstrap.sh"
rm -f "$OUT_IMAGE"
cp -c "$BASE_IMAGE" "$OUT_IMAGE"

ATTACH_OUTPUT=$(hdiutil attach -nomount -imagekey diskimage-class=CRawDiskImage "$OUT_IMAGE")
DISK=$(printf '%s\n' "$ATTACH_OUTPUT" | awk 'NR==1 {sub(/s[0-9]+$/, "", $1); print $1}')
if [ -z "$DISK" ] || [ ! -e "$DISK" ]; then echo "Unable to identify attached image device" >&2; exit 1; fi
trap 'hdiutil detach "$DISK" >/dev/null 2>&1 || true' EXIT

ROOT_PART=$(printf '%s\n' "$ATTACH_OUTPUT" | awk '$0 ~ /Linux/ {print $1; exit}')
BOOT_PART=$(printf '%s\n' "$ATTACH_OUTPUT" | awk '$0 ~ /Windows_FAT_32|DOS_FAT_32/ {print $1; exit}')
if [ -z "$ROOT_PART" ] || [ -z "$BOOT_PART" ]; then
  diskutil list "$DISK" >&2
  echo "Expected ArkOS boot and Linux root partitions were not found" >&2
  exit 1
fi

COMMANDS="$ROOT/build/debugfs.commands"
cat > "$COMMANDS" <<EOF
mkdir /opt/peckertap-staging
write $ROOT/build/bootstrap/peckertap-rootfs-overlay.tar.gz /opt/peckertap-staging/peckertap-rootfs-overlay.tar.gz
write $ROOT/build/bootstrap/peckertap-firstboot /usr/local/sbin/peckertap-firstboot
set_inode_field /usr/local/sbin/peckertap-firstboot mode 0100755
write $ROOT/build/bootstrap/peckertap-firstboot.service /etc/systemd/system/peckertap-firstboot.service
set_inode_field /etc/systemd/system/peckertap-firstboot.service mode 0100644
symlink /etc/systemd/system/multi-user.target.wants/peckertap-firstboot.service /etc/systemd/system/peckertap-firstboot.service
EOF

"$DEBUGFS" -w -f "$COMMANDS" "$ROOT_PART"

diskutil mount "$BOOT_PART" >/dev/null
BOOT_MOUNT=$(diskutil info "$BOOT_PART" | sed -n 's/^ *Mount Point: *//p')
if [ -z "$BOOT_MOUNT" ] || [ ! -d "$BOOT_MOUNT" ]; then
  echo "Unable to mount the image BOOT partition" >&2
  exit 1
fi

if [ -d "$BOOT_MOUNT" ]; then
  # Keep the exact boot configuration that is already proven on this R36S.
  # The stock multipanel boot.ini differs from the inserted card's working
  # configuration even though its kernel and active DTBs are identical.
  cp "$ROOT/hardware-backup/BOOT/boot.ini" "$BOOT_MOUNT/boot.ini"
  cp "$ROOT/hardware-backup/BOOT/rg351mp-kernel.dtb" "$BOOT_MOUNT/rg351mp-kernel.dtb"
  cp "$ROOT/hardware-backup/BOOT/rk3326-r35s-linux.dtb" "$BOOT_MOUNT/rk3326-r35s-linux.dtb"
  cp "$ROOT/dist/peckertap-boot-logo.bmp" "$BOOT_MOUNT/logo.bmp"
  cp "$ROOT/docs/RECOVERY.txt" "$BOOT_MOUNT/PECKERTAP_RECOVERY_README.txt"
  mkdir -p "$BOOT_MOUNT/PeckerTap-Hardware-Backup"
  cp "$ROOT/hardware-backup/BOOT/boot.ini" "$BOOT_MOUNT/PeckerTap-Hardware-Backup/boot.ini.current-card"
  cp "$ROOT/hardware-backup/BOOT/rg351mp-kernel.dtb" "$BOOT_MOUNT/PeckerTap-Hardware-Backup/rg351mp-kernel.dtb.current-card"
  cp "$ROOT/hardware-backup/BOOT/rk3326-r35s-linux.dtb" "$BOOT_MOUNT/PeckerTap-Hardware-Backup/rk3326-r35s-linux.dtb.current-card"
  sync
  diskutil unmount "$BOOT_PART" >/dev/null
fi

hdiutil detach "$DISK" >/dev/null
trap - EXIT
(
  cd "$(dirname "$OUT_IMAGE")"
  shasum -a 256 "$(basename "$OUT_IMAGE")" > "$(basename "$OUT_IMAGE").sha256"
)
echo "Customized image: $OUT_IMAGE"
