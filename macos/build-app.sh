#!/bin/bash
# Assembles a signed .app bundle. Xcode is not required — the Command Line
# Tools SDK is enough, but UNUserNotificationCenter needs a real bundle with a
# stable identifier, so a bare `swift build` binary will not do.
set -euo pipefail

cd "$(dirname "$0")"

CONFIG="${1:-debug}"
APP_NAME="Chotki"
BUNDLE_ID="info.chotki.app"
VERSION="0.1.0"
DIST="dist"
APP="$DIST/$APP_NAME.app"

echo "==> building ($CONFIG)"
swift build -c "$CONFIG"
BIN="$(swift build -c "$CONFIG" --show-bin-path)/$APP_NAME"

echo "==> assembling bundle"
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp "$BIN" "$APP/Contents/MacOS/$APP_NAME"

cat > "$APP/Contents/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleName</key><string>$APP_NAME</string>
    <key>CFBundleDisplayName</key><string>$APP_NAME</string>
    <key>CFBundleIdentifier</key><string>$BUNDLE_ID</string>
    <key>CFBundleExecutable</key><string>$APP_NAME</string>
    <key>CFBundlePackageType</key><string>APPL</string>
    <key>CFBundleShortVersionString</key><string>$VERSION</string>
    <key>CFBundleVersion</key><string>$VERSION</string>
    <key>LSMinimumSystemVersion</key><string>13.0</string>
    <!-- Menu bar app: no Dock icon, no menu bar menus of its own. -->
    <key>LSUIElement</key><true/>
    <key>NSHumanReadableCopyright</key><string>© 2026 Ryan Macfarlane. All rights reserved.</string>
</dict>
</plist>
PLIST

echo "==> signing (ad-hoc)"
codesign --force --sign - --timestamp=none "$APP"
codesign --verify --verbose=1 "$APP" 2>&1 | sed 's/^/    /'

echo "==> built $APP"
