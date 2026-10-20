#!/bin/bash
set -u

APP_ROOT=/opt/peckertap
STATE_ROOT=/var/lib/peckertap
LOG_TAG=peckertap

mkdir -p "$STATE_ROOT"
export HOME="$STATE_ROOT"
export XDG_DATA_HOME="$STATE_ROOT"
export SDL_AUDIODRIVER=alsa
export SDL_NOMOUSE=1
export SDL_GAMECONTROLLERCONFIG_FILE="$APP_ROOT/gamecontrollerdb.txt"
export LD_LIBRARY_PATH="$APP_ROOT/runtime/libs.aarch64${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}"

if [ -e /dev/tty1 ]; then
  chvt 1 2>/dev/null || true
  setterm --term linux --blank 0 --powersave off --cursor off > /dev/tty1 2>/dev/null || true
fi

echo "event=launcher_start arch=$(uname -m) kernel=$(uname -r)" | systemd-cat -t "$LOG_TAG" 2>/dev/null || true
exec "$APP_ROOT/runtime/love.aarch64" "$APP_ROOT/game/peckertap.love"
