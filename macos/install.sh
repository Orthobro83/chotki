#!/bin/bash
# Installs Chotki into /Applications and starts it from there.
#
# Why this matters: the development bundle lives on an external drive, and a
# login item pointing at an unmounted volume simply fails to start. For daily
# use the app belongs on the internal disk; the repo copy is for development.
set -euo pipefail

cd "$(dirname "$0")"

DEST="/Applications/Chotki.app"

# Always install and launch the copy that was just built. Building into dist/
# and then launching /Applications leaves someone testing a stale binary and
# reporting a feature as missing when it is simply not in the build they are
# running. That happened.
echo "==> stopping any running copy"
pkill -f "Chotki.app/Contents/MacOS/Chotki" 2>/dev/null || true

echo "==> building release"
# Not masked. `>/dev/null` here once hid a failing build and installed a stale
# bundle, which is in CLAUDE.md as a rule; it also hides the architecture line,
# and a quietly single-arch install is the exact thing that check exists for.
# Trimmed to the lines worth reading rather than silenced.
./build-app.sh release | grep -E "^==>|Architectures|error|warning: " || true

echo "==> installing to $DEST"
rm -rf "$DEST"
cp -R dist/Chotki.app "$DEST"

echo "==> verifying signature at the new location"
codesign --verify --verbose=1 "$DEST" 2>&1 | sed 's/^/    /'

echo "==> launching from /Applications"
open "$DEST"

cat <<'NOTE'

Installed.

The app re-registers its login item from wherever it is actually running, so
opening at login now points at /Applications rather than the external drive.
If a stale entry lingers, System Settings › General › Login Items will show it.
NOTE
