#!/usr/bin/env bash
set -euo pipefail

# Run in the guest after build-guest.sh. A review launch always selects the
# isolated sample record, even if the normal app data directory already exists.
stage_root=${CHOTKI_STAGE_ROOT:-"$HOME/chotki-linux-build"}
helper="$(swift build --show-bin-path --package-path "$stage_root/linux/app/bridge")/ChotkiLinuxBridge"
window="$stage_root/linux/app/ui/build/chotki-linux"

if [[ ! -x "$helper" || ! -x "$window" ]]; then
    echo "Build the Linux app first" >&2
    exit 1
fi

if [[ -z ${XDG_RUNTIME_DIR:-} && -d "/run/user/$(id -u)" ]]; then
    export XDG_RUNTIME_DIR="/run/user/$(id -u)"
fi
if [[ -n ${XDG_RUNTIME_DIR:-} && -z ${WAYLAND_DISPLAY:-} && -S "$XDG_RUNTIME_DIR/wayland-0" ]]; then
    export WAYLAND_DISPLAY=wayland-0
fi
if [[ -n ${XDG_RUNTIME_DIR:-} && -z ${DBUS_SESSION_BUS_ADDRESS:-} && -S "$XDG_RUNTIME_DIR/bus" ]]; then
    export DBUS_SESSION_BUS_ADDRESS="unix:path=$XDG_RUNTIME_DIR/bus"
fi

source_root=${CHOTKI_SOURCE_ROOT:-/mnt/utm/chotki-1}
export CHOTKI_ARTWORK_ROOT="$source_root/macos/Sources/Chotki/Resources"

exec "$window" --review "$helper"
