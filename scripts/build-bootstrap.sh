#!/bin/bash
set -euo pipefail

ROOT=$(cd "$(dirname "$0")/.." && pwd)
OUT="$ROOT/build/bootstrap"

bash "$ROOT/scripts/build-overlay.sh"
rm -rf "$OUT"
mkdir -p "$OUT"
cp "$ROOT/dist/peckertap-rootfs-overlay.tar.gz" "$OUT/peckertap-rootfs-overlay.tar.gz"
cp "$ROOT/system-overlay/usr/local/sbin/peckertap-firstboot" "$OUT/peckertap-firstboot"
cp "$ROOT/system-overlay/etc/systemd/system/peckertap-firstboot.service" "$OUT/peckertap-firstboot.service"
chmod 755 "$OUT/peckertap-firstboot"
echo "Bootstrap ready in $OUT"
