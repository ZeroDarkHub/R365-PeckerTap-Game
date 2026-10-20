#!/bin/bash
set -euo pipefail

ROOT=$(cd "$(dirname "$0")/.." && pwd)
STAGE="$ROOT/build/rootfs-overlay"
RUNTIME="$ROOT/cache/love_11.5"

rm -rf "$STAGE"
mkdir -p "$STAGE"
cp -R "$ROOT/system-overlay/". "$STAGE/"
mkdir -p "$STAGE/opt/peckertap/game" "$STAGE/opt/peckertap/runtime/libs.aarch64" "$STAGE/etc/systemd/system/multi-user.target.wants"

(
  cd "$ROOT/game"
  zip -q -9 -r "$STAGE/opt/peckertap/game/peckertap.love" main.lua conf.lua assets
)

cp "$RUNTIME/love.aarch64" "$STAGE/opt/peckertap/runtime/love.aarch64"
cp "$RUNTIME/libs.aarch64/"* "$STAGE/opt/peckertap/runtime/libs.aarch64/"
cp "$ROOT/cache/gamecontrollerdb.txt" "$STAGE/opt/peckertap/gamecontrollerdb.txt"
ln -s /etc/systemd/system/peckertap.service "$STAGE/etc/systemd/system/multi-user.target.wants/peckertap.service"
ln -s /etc/systemd/system/peckertap-recovery.service "$STAGE/etc/systemd/system/multi-user.target.wants/peckertap-recovery.service"
chmod 755 "$STAGE/opt/peckertap/bin/launch.sh" "$STAGE/opt/peckertap/runtime/love.aarch64"

tar --numeric-owner --owner=0 --group=0 -C "$STAGE" -czf "$ROOT/dist/peckertap-rootfs-overlay.tar.gz" .
(
  cd "$ROOT/dist"
  shasum -a 256 peckertap-rootfs-overlay.tar.gz > peckertap-rootfs-overlay.tar.gz.sha256
)
echo "Built $ROOT/dist/peckertap-rootfs-overlay.tar.gz"
