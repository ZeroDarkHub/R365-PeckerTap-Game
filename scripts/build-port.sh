#!/bin/bash
set -euo pipefail

ROOT=$(cd "$(dirname "$0")/.." && pwd)
GAME="$ROOT/game"
BUILD="$ROOT/build"
DIST="$ROOT/dist"
RUNTIME="$ROOT/cache/love_11.5"

rm -rf "$BUILD/package"
mkdir -p "$BUILD/package/peckertap/game" "$BUILD/package/peckertap/runtime/libs.aarch64" "$DIST"

(
  cd "$GAME"
  zip -q -9 -r "$BUILD/package/peckertap/game/peckertap.love" main.lua conf.lua assets
)

cp "$ROOT/system-overlay/opt/peckertap/bin/launch.sh" "$BUILD/package/peckertap/launch.sh"
cp "$ROOT/port/Pecker Tap.sh" "$BUILD/package/Pecker Tap.sh"
cp "$ROOT/port/port.json" "$BUILD/package/port.json"
cp "$RUNTIME/love.aarch64" "$BUILD/package/peckertap/runtime/love.aarch64"
cp "$RUNTIME/libs.aarch64/"* "$BUILD/package/peckertap/runtime/libs.aarch64/"
cp "$ROOT/cache/gamecontrollerdb.txt" "$BUILD/package/peckertap/gamecontrollerdb.txt"
chmod +x "$BUILD/package/Pecker Tap.sh" "$BUILD/package/peckertap/launch.sh" "$BUILD/package/peckertap/runtime/love.aarch64"

(
  cd "$BUILD/package"
  zip -q -9 -r "$DIST/peckertap-r36s-port.zip" .
)

(
  cd "$DIST"
  shasum -a 256 peckertap-r36s-port.zip > peckertap-r36s-port.zip.sha256
)
echo "Built $DIST/peckertap-r36s-port.zip"
