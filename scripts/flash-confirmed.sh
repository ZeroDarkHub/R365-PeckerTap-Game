#!/bin/bash
set -euo pipefail

ROOT=$(cd "$(dirname "$0")/.." && pwd)
IMAGE=${IMAGE:-"$ROOT/dist/PeckerTap-R36S.img"}
TARGET=${1:-}

if [ -z "$TARGET" ]; then echo "Usage: $0 /dev/diskN" >&2; exit 2; fi
case "$TARGET" in /dev/disk[0-9]*) ;; *) echo "Refusing invalid disk identifier: $TARGET" >&2; exit 2 ;; esac
if [ ! -s "$IMAGE" ]; then echo "Image not found: $IMAGE" >&2; exit 1; fi

INFO=$(diskutil info "$TARGET")
printf '%s\n' "$INFO"
printf '%s\n' "$INFO" | grep -q 'Removable Media:.*Removable' || { echo "Refusing non-removable target" >&2; exit 1; }
printf '%s\n' "$INFO" | grep -q 'Internal:.*Yes' && { echo "Refusing internal target" >&2; exit 1; }

echo "THIS WILL ERASE ALL DATA ON $TARGET"
read -r -p "Type ERASE $TARGET to continue: " answer
if [ "$answer" != "ERASE $TARGET" ]; then echo "Cancelled"; exit 1; fi

diskutil unmountDisk "$TARGET"
sudo dd if="$IMAGE" of="/dev/r${TARGET#/dev/}" bs=4m
sync
sudo cmp -n "$(stat -f%z "$IMAGE")" "$IMAGE" "/dev/r${TARGET#/dev/}"
diskutil eject "$TARGET"
echo "Flash verified and card ejected"
