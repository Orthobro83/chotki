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

# The icon is generated from the app itself, not checked in, so it cannot fall
# out of step with the drawing. Without a real .icns in the bundle, Launchpad
# and Finder show the generic placeholder however the Dock icon is set at
# runtime — setting NSApp.applicationIconImage only affects the running app.
echo "==> generating the icon"
ICONSET="$(mktemp -d)/$APP_NAME.iconset"
CHOTKI_EXPORT_ICON="$ICONSET" "$BIN" >/dev/null
iconutil -c icns "$ICONSET" -o "$APP/Contents/Resources/$APP_NAME.icns"

cat > "$APP/Contents/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleName</key><string>$APP_NAME</string>
    <key>CFBundleDisplayName</key><string>$APP_NAME</string>
    <key>CFBundleIdentifier</key><string>$BUNDLE_ID</string>
    <key>CFBundleExecutable</key><string>$APP_NAME</string>
    <key>CFBundleIconFile</key><string>$APP_NAME</string>
    <key>CFBundleIconName</key><string>$APP_NAME</string>
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

# Strip extended attributes before signing. macOS adds provenance attributes to
# anything it builds, and `ditto` archives those as AppleDouble `._` files — which
# a command-line `unzip` then materialises, breaking the signature seal and making
# the app look damaged. Finder is unaffected, but the failure is baffling when it
# happens, so remove the cause.
xattr -cr "$APP"

echo "==> signing (ad-hoc)"
codesign --force --sign - --timestamp=none "$APP"
codesign --verify --verbose=1 "$APP" 2>&1 | sed 's/^/    /'

echo "==> packaging"
rm -f "$DIST/$APP_NAME.zip"
ditto -c -k --keepParent --noextattr --norsrc "$APP" "$DIST/$APP_NAME.zip"

echo "==> built $APP and $DIST/$APP_NAME.zip"
