#!/bin/bash
set -euo pipefail

ROOT=$(cd "$(dirname "$0")/.." && pwd)
BASE=https://raw.githubusercontent.com/PortsMaster/PortMaster-GUI/main/PortMaster/runtimes/love_11.5
RUNTIME="$ROOT/cache/love_11.5"

mkdir -p "$RUNTIME/libs.aarch64" "$ROOT/game/assets" "$ROOT/cache"

fetch() {
  local url=$1 dest=$2
  if [ ! -s "$dest" ]; then
    curl --fail --location --retry 3 --output "$dest.tmp" "$url"
    mv "$dest.tmp" "$dest"
  fi
}

fetch "$BASE/love.aarch64" "$RUNTIME/love.aarch64"
for lib in liblove-11.5.so libluajit-5.1.so.2 libmodplug.so.1 libogg.so.0; do
  fetch "$BASE/libs.aarch64/$lib" "$RUNTIME/libs.aarch64/$lib"
done
fetch https://raw.githubusercontent.com/google/fonts/main/ofl/pressstart2p/PressStart2P-Regular.ttf "$ROOT/game/assets/PressStart2P-Regular.ttf"
fetch https://raw.githubusercontent.com/google/fonts/main/ofl/pressstart2p/OFL.txt "$ROOT/game/assets/OFL-PressStart2P.txt"
fetch https://raw.githubusercontent.com/mdqinc/SDL_GameControllerDB/master/gamecontrollerdb.txt "$ROOT/cache/gamecontrollerdb.txt"

chmod +x "$RUNTIME/love.aarch64"
file "$RUNTIME/love.aarch64" | grep -q 'ARM aarch64' || { echo "Unexpected LÖVE runtime architecture" >&2; exit 1; }
(
  cd "$ROOT"
  shasum -a 256 \
    cache/love_11.5/love.aarch64 \
    cache/love_11.5/libs.aarch64/libmodplug.so.1 \
    cache/love_11.5/libs.aarch64/liblove-11.5.so \
    cache/love_11.5/libs.aarch64/libluajit-5.1.so.2 \
    cache/love_11.5/libs.aarch64/libogg.so.0 \
    game/assets/OFL-PressStart2P.txt \
    game/assets/PressStart2P-Regular.ttf \
    cache/gamecontrollerdb.txt
) > "$ROOT/cache/DEPENDENCIES.sha256"
echo "Dependencies ready in $ROOT/cache"
