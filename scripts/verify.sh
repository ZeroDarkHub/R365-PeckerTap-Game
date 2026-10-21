#!/bin/bash
set -euo pipefail

ROOT=$(cd "$(dirname "$0")/.." && pwd)
fail=0

required=(
  game/main.lua game/conf.lua game/assets/PressStart2P-Regular.ttf
  game/assets/duck-quack-quack.wav game/assets/ATTRIBUTION.md
  cache/love_11.5/love.aarch64 cache/love_11.5/libs.aarch64/liblove-11.5.so
  system-overlay/etc/systemd/system/peckertap.service
  system-overlay/opt/peckertap/bin/launch.sh
)
for path in "${required[@]}"; do
  if [ ! -s "$ROOT/$path" ]; then echo "MISSING $path" >&2; fail=1; fi
done

if rg -n 'https?://|fetch\(|XMLHttpRequest|WebSocket' "$ROOT/game" -g '*.lua' -g '*.conf'; then
  echo "Network reference detected in game runtime" >&2; fail=1
fi

file "$ROOT/cache/love_11.5/love.aarch64" 2>/dev/null | grep -q 'ARM aarch64' || { echo "Bad ARM runtime" >&2; fail=1; }
node -e 'JSON.parse(require("fs").readFileSync(process.argv[1],"utf8"))' "$ROOT/port/port.json"
bash -n "$ROOT/scripts/"*.sh "$ROOT/system-overlay/opt/peckertap/bin/launch.sh" "$ROOT/port/Pecker Tap.sh"

if [ "$fail" -ne 0 ]; then exit 1; fi
echo "Static verification passed"
