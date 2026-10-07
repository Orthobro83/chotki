#!/usr/bin/env bash
set -euo pipefail

# Run inside the Ubuntu guest. The UTM share stays read-only; all compiler
# output lives in the guest's home directory. Never build against a live record.
source_root=${CHOTKI_SOURCE_ROOT:-/mnt/utm/chotki-1}
stage_root=${CHOTKI_STAGE_ROOT:-"$HOME/chotki-linux-build"}

if [[ ! -f "$source_root/core/Package.swift" || ! -f "$source_root/linux/app/ui/CMakeLists.txt" ]]; then
    echo "Chotki source is not mounted at $source_root" >&2
    exit 1
fi
if [[ "$stage_root" == "$source_root" || "$stage_root" == /mnt/utm* ]]; then
    echo "Build stage must not be the UTM shared source" >&2
    exit 1
fi
command -v rsync >/dev/null || { echo "Install rsync in the guest" >&2; exit 1; }
command -v swift >/dev/null || { echo "Install Swift in the guest" >&2; exit 1; }

mkdir -p "$stage_root/core" "$stage_root/linux/app"
rsync -a --delete --exclude=.build --exclude=.swiftpm \
    "$source_root/core/" "$stage_root/core/"
rsync -a --delete --exclude=build \
    "$source_root/linux/app/" "$stage_root/linux/app/"

swift build --package-path "$stage_root/linux/app/bridge" -j 1
cmake -S "$stage_root/linux/app/ui" -B "$stage_root/linux/app/ui/build" -G Ninja
cmake --build "$stage_root/linux/app/ui/build" -j 2

echo "Built Qt shell: $stage_root/linux/app/ui/build/chotki-linux"
echo "Built Swift helper: $(swift build --show-bin-path --package-path "$stage_root/linux/app/bridge")/ChotkiLinuxBridge"
