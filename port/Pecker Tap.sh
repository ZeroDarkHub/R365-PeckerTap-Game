#!/bin/bash
set -e

GAMEDIR="${GAMEDIR:-/roms/ports}"
APP="$GAMEDIR/peckertap"

export HOME="$APP/save"
export XDG_DATA_HOME="$APP/save"
export SDL_AUDIODRIVER=alsa
export SDL_NOMOUSE=1
export SDL_GAMECONTROLLERCONFIG_FILE="$APP/gamecontrollerdb.txt"
export LD_LIBRARY_PATH="$APP/runtime/libs.aarch64${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}"

mkdir -p "$APP/save"
cd "$APP"
exec "$APP/runtime/love.aarch64" "$APP/game/peckertap.love"
